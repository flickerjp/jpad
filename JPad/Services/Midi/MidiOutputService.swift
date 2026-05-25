import Combine
import CoreMIDI
import Foundation

/// CoreMIDI の入力コールバックは専用スレッドで呼ばれるため、@MainActor から分離して登録する。
private final class MidiInputPortFactory: @unchecked Sendable {
    nonisolated func createInputPort(
        client: MIDIClientRef,
        bridge: MidiNoteCaptureBridge,
        port: inout MIDIPortRef
    ) -> OSStatus {
        MIDIInputPortCreateWithBlock(client, "JPad MIDI Input" as CFString, &port) { packetList, _ in
            bridge.ingest(packetList: packetList)
        }
    }
}

private let midiInputPortFactory = MidiInputPortFactory()

/// 初期版の安定した MIDI 出力をベースに、現在 UI が使う API だけ足したサービス。
/// 設定画面では端末リストの更新のみ。鍵盤入力の接続は Input Notes 編集時だけ。
@MainActor
final class MidiOutputService: ObservableObject {
    @Published private(set) var destinations: [MidiDestinationInfo] = []
    @Published private(set) var sources: [MidiSourceInfo] = []
    @Published private(set) var selectedPadOutput: MidiDestinationInfo?
    @Published private(set) var selectedKeyboardInput: MidiSourceInfo?
    @Published private(set) var outputRoute: MidiOutputRoute = .tinyPiano
    /// 内蔵プレビュー音源が実際に動作中（設定 UI の Active 表示用）。
    @Published private(set) var isInternalPreviewReady = false
    @Published private(set) var lastMidiEventDescription = "—"
    @Published private(set) var lastTinyPianoFallbackReason = ""
    @Published var isTestNoteEnabled = false
    @Published var midiChannel: Int = 1
    @Published private(set) var previewSoundPresetOptions: [PreviewSoundPresetOption] = []
    @Published private(set) var selectedPreviewSoundPresetID = PreviewSoundPresetIDs.tinyPiano

    private var outputChannelIndex: UInt8 = 0
    private var velocity: UInt8
    private var expression: UInt8

    private var midiClient = MIDIClientRef()
    private var outputPort = MIDIPortRef()
    private var inputPort = MIDIPortRef()
    private var captureSourceEndpoint = MIDIEndpointRef()
    private var virtualSource = MIDIEndpointRef()
    private var virtualSourceUsesEventList = false
    private var lastVirtualSourceError: OSStatus = noErr

    private var activeNotesByPad: [PadDefinition.ID: Set<ActiveMidiNote>] = [:]
    private var soundingNoteCounts: [UInt8: Int] = [:]
    private let noteCaptureBridge = MidiNoteCaptureBridge()
    private var noteCaptureConnectTask: Task<Void, Never>?
    /// キャプチャ OFF 直後の MIDIPortDisconnectSource を遅延（コールバック競合で落ちるのを避ける）
    private var captureDisconnectTask: Task<Void, Never>?
    /// Core MIDI の setup 通知は連続で飛ぶため、端末リスト更新を短くまとめる。
    private var endpointRefreshDebounceTask: Task<Void, Never>?
    private var shouldResumePreviewEngineAfterBackground = false
    private let previewEngine: any InternalPreviewSynth = TinyToneEngine()

    private static let virtualSourceName = "JPad"
    /// CoreMIDI 端末 ID と衝突しない内蔵 PAD OUT 用の固定 ID。
    static let tinyPianoUniqueID: MIDIUniqueID = 2_130_741_505
    private static let selectedRouteKey = "selectedMidiOutputRoute"
    private static let selectedPadOutputKey = "selectedMidiOutputUniqueID"
    private static let selectedKeyboardInputKey = "selectedMidiInputUniqueID"
    private static let midiChannelKey = "midiOutputChannel"
    private static let previewSoundPatchDataKey = "previewSoundPatchData"
    private static let previewSoundSelectedPresetIDKey = "previewSoundSelectedPresetID"
    private static let previewSoundCustomPatchDataKey = "previewSoundCustomPatchData"

    init(outputChannel: UInt8 = 0, velocity: UInt8 = 100, expression: UInt8 = 100) {
        self.outputChannelIndex = outputChannel
        self.velocity = velocity
        self.expression = expression
        self.midiChannel = Int(outputChannel) + 1
        applyPreviewExpressionLevel()

        createMidiClientIfNeeded()
        createOutputPortIfNeeded()
        createVirtualSourceIfNeeded()

        if let storedChannel = UserDefaults.standard.object(forKey: Self.midiChannelKey) as? Int {
            updateMidiChannel(storedChannel)
        }

        bootstrapPreviewSoundPresets()
        migrateLegacyMidiSettings()
        refreshDestinations()
        refreshSources()
        restorePersistedRouteIfAvailable()
        restorePersistedPadOutputIfAvailable()
        restorePersistedKeyboardInputIfAvailable()
        applyDefaultRouting()
        finalizeAudioSessionForCurrentRoute()
    }

    static var tinyPianoDestination: MidiDestinationInfo {
        MidiDestinationInfo(
            uniqueID: tinyPianoUniqueID,
            endpointRef: 0,
            displayName: Self.internalPreviewDisplayName,
            isOnline: true
        )
    }

    private static var internalPreviewDisplayName: String {
        L10n.string("settings.pad_out.tiny_piano")
    }

    deinit {
        previewEngine.stop()
        endpointRefreshDebounceTask?.cancel()
        if inputPort != 0, captureSourceEndpoint != 0 {
            MIDIPortDisconnectSource(inputPort, captureSourceEndpoint)
        }
        if inputPort != 0 {
            MIDIPortDispose(inputPort)
        }
        if virtualSource != 0 {
            MIDIEndpointDispose(virtualSource)
        }
        if outputPort != 0 {
            MIDIPortDispose(outputPort)
        }
        if midiClient != 0 {
            MIDIClientDispose(midiClient)
        }
    }

    var hasVirtualSource: Bool {
        virtualSource != 0
    }

    var garageBandDestination: MidiDestinationInfo? {
        destinations.first(where: Self.isGarageBandDestination)
    }

    var filteredPadOutputs: [MidiDestinationInfo] {
        destinations
            .filter { !Self.isExcludedPadOutput($0.displayName) }
            .sorted { Self.sortPadOutputsForDisplay($0.displayName, $1.displayName) }
    }

    /// 設定画面の PAD OUT 一覧（内蔵 TinyTone + 外部端末）。
    var padOutputChoices: [MidiPadOutputChoice] {
        let tinyPianoSelected = outputRoute == .tinyPiano
        let tinyPianoSelectable = !hasOnlineKeyboardInput
        var choices: [MidiPadOutputChoice] = [
            MidiPadOutputChoice(
                uniqueID: Self.tinyPianoUniqueID,
                title: Self.internalPreviewDisplayName,
                subtitle: Self.padOutputStatusLabel(
                    isOnline: true,
                    isActiveRoute: tinyPianoSelected
                ),
                isOnline: true,
                isInternalSynth: true,
                isSelectable: tinyPianoSelectable
            ),
        ]
        for destination in filteredPadOutputs {
            let isSelected = destination.uniqueID == effectiveSelectedPadOutputUniqueID
            let isActiveRoute = isSelected && destination.isOnline
            choices.append(
                MidiPadOutputChoice(
                    uniqueID: destination.uniqueID,
                    title: Self.friendlyListTitle(forPadOutput: destination.displayName),
                    subtitle: Self.padOutputStatusLabel(
                        isOnline: destination.isOnline,
                        isActiveRoute: isActiveRoute
                    ),
                    isOnline: destination.isOnline,
                    isInternalSynth: false,
                    isSelectable: destination.isOnline
                )
            )
        }
        return choices
    }

    var filteredKeyboardInputs: [MidiSourceInfo] {
        sources
            .filter { !Self.isExcludedKeyboardInput($0) }
            .sorted { Self.sortKeyboardInputsForDisplay($0.displayName, $1.displayName) }
    }

    /// UI 用: 実際に PAD OUT 先が選ばれ利用可能（JChord 仮想ソース作成だけでは true にしない）。
    var hasActiveMidiOutput: Bool {
        switch outputRoute {
        case .tinyPiano:
            return true
        case .garageBand:
            return garageBandDestination?.isOnline == true
        case .device:
            guard let selectedPadOutput,
                  selectedPadOutput.isOnline,
                  filteredPadOutputs.contains(where: { $0.uniqueID == selectedPadOutput.uniqueID }) else {
                return false
            }
            return true
        }
    }

    var effectiveSelectedPadOutputUniqueID: MIDIUniqueID? {
        if outputRoute == .tinyPiano {
            return Self.tinyPianoUniqueID
        }
        guard let selectedPadOutput,
              filteredPadOutputs.contains(where: { $0.uniqueID == selectedPadOutput.uniqueID }) else {
            return nil
        }
        return selectedPadOutput.uniqueID
    }

    var hasAssignedPadOutput: Bool {
        outputRoute == .tinyPiano || effectiveSelectedPadOutputUniqueID != nil
    }

    private var hasOnlineKeyboardInput: Bool {
        filteredKeyboardInputs.contains(where: \.isOnline)
    }

    var effectiveSelectedKeyboardInputUniqueID: MIDIUniqueID? {
        guard let selectedKeyboardInput,
              filteredKeyboardInputs.contains(where: { $0.uniqueID == selectedKeyboardInput.uniqueID }) else {
            return nil
        }
        return selectedKeyboardInput.uniqueID
    }

    var currentOutputName: String {
        switch outputRoute {
        case .tinyPiano:
            return Self.internalPreviewDisplayName
        case .garageBand:
            return garageBandDestination?.displayName ?? (hasVirtualSource ? "GARAGEBAND" : "PAD OUT")
        case .device:
            return selectedPadOutput?.displayName ?? "PAD OUT"
        }
    }

    func handleAppResignActive() {
        isTestNoteEnabled = false
        sendAllNotesOff()
        if outputRoute == .tinyPiano {
            shouldResumePreviewEngineAfterBackground = previewEngine.isEngineRunning
            if previewEngine.isEngineRunning {
                previewEngine.stop()
                clearInternalPreviewReady()
            }
            hasPrimedPreviewDSP = false
        }
    }

    /// セッションだけ整える（起動直後はエンジンを鳴らさない）。
    func preparePreviewAudioIfNeeded() {
        activatePreviewAudioSessionIfNeeded()
    }

    /// フォアグラウンド復帰時: バックグラウンド前に鳴っていたときだけエンジンを再開する。
    func preparePreviewAudioAfterReturningToForeground() {
        activatePreviewAudioSessionIfNeeded()
        guard outputRoute == .tinyPiano, shouldResumePreviewEngineAfterBackground else { return }
        shouldResumePreviewEngineAfterBackground = false
        _ = ensureTinyPianoReady()
    }

    private func activatePreviewAudioSessionIfNeeded() {
        switch outputRoute {
        case .tinyPiano:
            _ = MidiAudioSession.activateForInternalPreview()
        case .garageBand:
            _ = ensureVirtualSourceReady()
        case .device:
            _ = MidiAudioSession.activateForSharedMIDI()
        }
    }

    var hasCustomPreviewSound: Bool {
        UserDefaults.standard.data(forKey: Self.previewSoundCustomPatchDataKey) != nil
    }

    func selectPreviewSoundPreset(id: String) {
        guard previewSoundPresetOptions.contains(where: { $0.id == id }) else { return }
        selectedPreviewSoundPresetID = id
        hasPrimedPreviewDSP = false
        UserDefaults.standard.set(id, forKey: Self.previewSoundSelectedPresetIDKey)

        do {
            let engineRunning = outputRoute == .tinyPiano && previewEngine.isEngineRunning
            try applyPreviewSoundPreset(id: id, startEngineIfNeeded: engineRunning)
            lastMidiEventDescription = "Preset → \(previewDisplayName(for: id))"
        } catch {
            lastMidiEventDescription = error.localizedDescription
        }
    }

    /// 6 番目（ユーザー JSON）の取り込み。
    func importPreviewSound(from url: URL) throws {
        let accessed = url.startAccessingSecurityScopedResource()
        defer {
            if accessed {
                url.stopAccessingSecurityScopedResource()
            }
        }

        let data = try Data(contentsOf: url)
        _ = try TinyToneJSONService.decode(data)

        UserDefaults.standard.set(data, forKey: Self.previewSoundCustomPatchDataKey)
        UserDefaults.standard.removeObject(forKey: Self.previewSoundPatchDataKey)
        refreshPreviewSoundPresetOptions()
        selectPreviewSoundPreset(id: PreviewSoundPresetIDs.custom)

        if outputRoute != .tinyPiano, !hasOnlineKeyboardInput {
            selectTinyPianoOutput(reason: "Loaded preview sound")
        }
    }

    /// ウェルカムで NOTE を試したあと、画面遷移まで待つ時間（設定画面の HOLD 解放と同じ）。
    static let welcomeNoteResetDelayMs: UInt64 = 300

    /// ウェルカム→メイン遷移時。TEST NOTE を止めて残音をクリアする（遷移ポップ音対策）。
    func endWelcomeTransition() {
        setTestNoteEnabled(false)
        sendAllNotesOff()
    }

    /// 内蔵エンジン起動後、無音で FX バッファと出力ゲートを落ち着かせる時間。
    private static func previewEnginePrimeDelayMs(for presetID: String) -> UInt64 {
        if PreviewSoundPresetIDs.usesHeavyDSP(id: presetID) {
            // `TinyToneEngine` outputGateRampSeconds (0.5s) + reverb/delay ライン
            return 520
        }
        return 180
    }

    private var hasPrimedPreviewDSP = false

    /// 初回パッド発音前にエンジン起動＋無音プリーム（重いプリセットほど長め）。
    @MainActor
    func primePreviewEngineForPadPlayback() async {
        guard outputRoute == .tinyPiano else { return }
        if hasPrimedPreviewDSP, previewEngine.isEngineRunning { return }

        do {
            try applyPreviewSoundPreset(id: selectedPreviewSoundPresetID, startEngineIfNeeded: false)
        } catch {
            lastMidiEventDescription = error.localizedDescription
            return
        }

        guard ensureTinyPianoReady() else {
            lastMidiEventDescription = tinyPianoUnavailableDescription()
            return
        }

        let primeMs = Self.previewEnginePrimeDelayMs(for: selectedPreviewSoundPresetID)
        if primeMs > 0 {
            try? await Task.sleep(for: .milliseconds(primeMs))
        }
        previewEngine.allNotesOff()
        hasPrimedPreviewDSP = true
    }

    /// ウェルカム完了: NOTE リセット待ち → DSP プリーム → 画面遷移。
    @MainActor
    func completeWelcomeHandoff(needsNoteSettleDelay: Bool) async {
        endWelcomeTransition()
        if needsNoteSettleDelay {
            try? await Task.sleep(for: .milliseconds(Self.welcomeNoteResetDelayMs))
        }
        await primePreviewEngineForPadPlayback()
    }

    /// 内蔵 TinyTone を初回パッド発音前にウォームアップする（設定クローズ時）。
    @discardableResult
    func warmUpPreviewEngineIfNeeded() -> Bool {
        guard outputRoute == .tinyPiano else { return true }
        do {
            try applyPreviewSoundPreset(id: selectedPreviewSoundPresetID, startEngineIfNeeded: false)
        } catch {
            lastMidiEventDescription = error.localizedDescription
            return false
        }
        let started = ensureTinyPianoReady()
        if !started {
            lastMidiEventDescription = tinyPianoUnavailableDescription()
            return started
        }
        Task { @MainActor in
            await self.primePreviewEngineForPadPlayback()
        }
        return started
    }

    func configure(outputChannel: UInt8, velocity: UInt8, expression: UInt8) {
        outputChannelIndex = min(outputChannel, 15)
        midiChannel = Int(outputChannelIndex) + 1
        self.velocity = velocity
        self.expression = expression
        applyPreviewExpressionLevel()
        transmitExpression()
    }

    func updateVelocity(_ velocity: UInt8) {
        self.velocity = velocity
    }

    func updateExpression(_ expression: UInt8) {
        self.expression = expression
        applyPreviewExpressionLevel()
        transmitExpression()
    }

    func updateMidiChannel(_ channel: Int) {
        let clamped = min(max(channel, 1), 16)
        midiChannel = clamped
        outputChannelIndex = UInt8(clamped - 1)
        UserDefaults.standard.set(clamped, forKey: Self.midiChannelKey)
    }

    func refreshEndpoints() {
        refreshEndpoints(reconfigureSession: true)
    }

    /// MIDI 端末一覧を更新する。`reconfigureSession: false` では AVAudioSession を触らない（設定画面 open 用）。
    func refreshEndpoints(reconfigureSession: Bool) {
        refreshDestinations()
        refreshSources()
        applyDefaultRouting()
        if reconfigureSession {
            activatePreviewAudioSessionIfNeeded()
        }
        if noteCaptureBridge.isActive {
            connectKeyboardCaptureIfNeeded()
        }
    }

    func refreshEndpointsIfStale() {
        refreshEndpoints(reconfigureSession: true)
    }

    /// GarageBand 起動などで MIDI グラフが変わったあと、端末リストを再取得する。
    func scheduleEndpointRefreshFromMidiNotification() {
        endpointRefreshDebounceTask?.cancel()
        endpointRefreshDebounceTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(200))
            guard !Task.isCancelled else { return }
            self?.refreshEndpoints()
        }
    }

    func selectPadOutput(uniqueID: MIDIUniqueID) {
        if uniqueID == Self.tinyPianoUniqueID {
            guard !hasOnlineKeyboardInput else { return }
            if outputRoute == .tinyPiano {
                if !ensureTinyPianoReady() {
                    lastMidiEventDescription = tinyPianoUnavailableDescription()
                }
                return
            }
            selectTinyPianoOutput(reason: nil)
            return
        }

        if uniqueID == effectiveSelectedPadOutputUniqueID {
            return
        }

        previewEngine.stop()
        clearInternalPreviewReady()
        _ = MidiAudioSession.activateForSharedMIDI()

        guard let destination = destinations.first(where: { $0.uniqueID == uniqueID }) else { return }
        guard !Self.isExcludedPadOutput(destination.displayName) else { return }

        selectedPadOutput = destination
        UserDefaults.standard.set(destination.uniqueID, forKey: Self.selectedPadOutputKey)

        syncOutputRoute(for: destination)
    }

    var tinyPianoDiagnostics: String {
        let fallback = lastTinyPianoFallbackReason.isEmpty ? "-" : lastTinyPianoFallbackReason
        return "\(Self.internalPreviewDisplayName) voices=\(previewEngine.activeVoiceCount) running=\(previewEngine.isEngineRunning) output=\(currentOutputName) fallback=\(fallback)"
    }

    private func selectTinyPianoOutput(reason: String?) {
        _ = MidiAudioSession.activateForInternalPreview()
        outputRoute = .tinyPiano
        selectedPadOutput = Self.tinyPianoDestination
        lastTinyPianoFallbackReason = reason ?? ""
        UserDefaults.standard.set(MidiOutputRoute.tinyPiano.rawValue, forKey: Self.selectedRouteKey)
        UserDefaults.standard.set(Self.tinyPianoUniqueID, forKey: Self.selectedPadOutputKey)
        clearInternalPreviewReady()
    }

    private func tinyPianoUnavailableDescription() -> String {
        if let detail = previewEngine.lastStartError {
            return L10n.format("error.tiny_piano_unavailable_detail", detail)
        }
        return L10n.string("error.tiny_piano_unavailable")
    }

    private func syncOutputRoute(for destination: MidiDestinationInfo) {
        clearInternalPreviewReady()
        if Self.isGarageBandDestination(destination.displayName) {
            outputRoute = .garageBand
            UserDefaults.standard.set(MidiOutputRoute.garageBand.rawValue, forKey: Self.selectedRouteKey)
        } else {
            outputRoute = .device
            UserDefaults.standard.set(MidiOutputRoute.device.rawValue, forKey: Self.selectedRouteKey)
        }
    }

    func selectKeyboardInput(uniqueID: MIDIUniqueID) {
        guard let source = sources.first(where: { $0.uniqueID == uniqueID }) else { return }
        guard !Self.isExcludedKeyboardInput(source) else { return }
        selectedKeyboardInput = source
        UserDefaults.standard.set(source.uniqueID, forKey: Self.selectedKeyboardInputKey)
        if noteCaptureBridge.isActive, noteCaptureConnectTask == nil {
            connectKeyboardCaptureIfNeeded()
        }
    }

    func startInputActivityMonitoring() {
        // 旧 UI 互換の no-op（接続時クラッシュの原因だったため廃止）
    }

    func stopInputActivityMonitoring() {
        // no-op
    }

    func startNoteCapture(onNoteOn: @escaping @MainActor ([UInt8]) -> Void) {
        captureDisconnectTask?.cancel()
        captureDisconnectTask = nil
        noteCaptureBridge.setHandler { notes in
            Task { @MainActor in onNoteOn(notes) }
        }
        noteCaptureConnectTask?.cancel()
        ensureKeyboardInputSelectedForCapture()

        // ポップアップ表示と MIDI 接続が重なると固まるため少し遅延
        noteCaptureConnectTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(200))
            guard let self, noteCaptureBridge.isActive else { return }
            connectKeyboardCaptureIfNeeded()
        }
    }

    func stopNoteCapture() {
        noteCaptureConnectTask?.cancel()
        noteCaptureConnectTask = nil
        captureDisconnectTask?.cancel()
        noteCaptureBridge.setHandler(nil)

        captureDisconnectTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(100))
            guard let self else { return }
            disconnectKeyboardCapture()
            MidiDiagnostics.captureStopped()
        }
        // 入力ポートは破棄しない（MIDI スレッドのコールバック中に dispose するとクラッシュする）
    }

    func setTestNoteEnabled(_ enabled: Bool) {
        guard enabled != isTestNoteEnabled else { return }
        isTestNoteEnabled = enabled

        if outputRoute == .tinyPiano {
            let testNote = Int(MidiNoteFormatter.testNotePitch)
            if enabled {
                guard ensureTinyPianoReady() else {
                    lastMidiEventDescription = tinyPianoUnavailableDescription()
                    return
                }
                previewEngine.noteOn(noteNumber: testNote, velocity: velocity)
            } else {
                previewEngine.noteOff(noteNumber: testNote)
            }
            lastMidiEventDescription = enabled
                ? "Note On \(testNote) → \(Self.internalPreviewDisplayName)"
                : "Note Off \(testNote) → \(Self.internalPreviewDisplayName)"
            return
        }

        guard ensureMidiOutputReady() else {
            lastMidiEventDescription = unavailableOutputDescription()
            return
        }

        let testNote = Int(MidiNoteFormatter.testNotePitch)
        var messages: [[UInt8]] = []
        if enabled {
            messages.append(MidiMessageBuilder.expression(expression, channel: outputChannelIndex))
            messages.append(
                MidiMessageBuilder.noteOn(
                    note: MidiNoteFormatter.testNotePitch,
                    velocity: velocity,
                    channel: outputChannelIndex
                )
            )
        } else {
            messages.append(
                MidiMessageBuilder.noteOff(note: MidiNoteFormatter.testNotePitch, channel: outputChannelIndex)
            )
        }

        var lastStatus: OSStatus = noErr
        for message in messages {
            lastStatus = transmit(message)
            guard lastStatus == noErr else { break }
        }
        let routeLabel = outputRoute == .garageBand ? "GB" : currentOutputName
        if lastStatus == noErr, let last = messages.last {
            lastMidiEventDescription = "\(describe(last)) → \(routeLabel)"
        } else {
            lastMidiEventDescription = midiErrorDescription(lastStatus)
        }
    }

    func sendPadOn(_ pad: PadDefinition) {
        let orderedNotes = Self.orderedPadNotes(bass: pad.bassNotes, chord: pad.chordNotes)
        guard !orderedNotes.isEmpty else {
            lastMidiEventDescription = "No notes in pad"
            return
        }

        let activeNotes = Set(orderedNotes.map { ActiveMidiNote(noteNumber: $0, channel: outputChannelIndex) })
        activeNotesByPad[pad.id] = activeNotes

        if outputRoute == .tinyPiano {
            guard ensureTinyPianoReady() else {
                lastMidiEventDescription = tinyPianoUnavailableDescription()
                return
            }
            previewEngine.chordOn(
                noteNumbers: orderedNotes.map { Int($0) },
                velocity: velocity
            )
            lastMidiEventDescription = "Pad On → \(Self.internalPreviewDisplayName)"
            return
        }

        guard ensureMidiOutputReady() else {
            lastMidiEventDescription = unavailableOutputDescription()
            return
        }

        var messages: [[UInt8]] = [
            MidiMessageBuilder.expression(expression, channel: outputChannelIndex),
        ]
        for note in orderedNotes {
            acquireNote(note, into: &messages)
        }
        dispatch(messages)
    }

    /// ベース→コードの順で並べ、重複を除く（内蔵プレビューの同時発音順を安定させる）。
    private static func orderedPadNotes(bass: [UInt8], chord: [UInt8]) -> [UInt8] {
        var seen = Set<UInt8>()
        var ordered: [UInt8] = []
        ordered.reserveCapacity(bass.count + chord.count)
        for note in bass + chord where seen.insert(note).inserted {
            ordered.append(note)
        }
        return ordered
    }

    /// キー入力 UI など、単音の短い試聴（パッド ID とは独立した ref count）。
    func sendPreviewNoteOn(_ note: UInt8) {
        guard note <= 127 else { return }

        if outputRoute == .tinyPiano {
            guard ensureTinyPianoReady() else { return }
            previewEngine.noteOn(noteNumber: Int(note), velocity: velocity)
            return
        }

        guard ensureMidiOutputReady() else { return }

        var messages: [[UInt8]] = [
            MidiMessageBuilder.expression(expression, channel: outputChannelIndex),
        ]
        acquireNote(note, into: &messages)
        dispatch(messages)
    }

    func sendPreviewNoteOff(_ note: UInt8) {
        if outputRoute == .tinyPiano {
            previewEngine.noteOff(noteNumber: Int(note))
            return
        }

        guard ensureMidiOutputReady() else { return }

        var messages: [[UInt8]] = []
        releaseNote(note, into: &messages)
        guard !messages.isEmpty else { return }
        dispatch(messages)
    }

    func sendPadOff(_ pad: PadDefinition) {
        let tracked = activeNotesByPad.removeValue(forKey: pad.id)
        let fallbackNotes = Set(
            (pad.bassNotes + pad.chordNotes).map {
                ActiveMidiNote(noteNumber: $0, channel: outputChannelIndex)
            }
        )
        let activeNotes = tracked ?? fallbackNotes
        guard !activeNotes.isEmpty else { return }

        if outputRoute == .tinyPiano {
            previewEngine.chordOff(
                noteNumbers: activeNotes.map { Int($0.noteNumber) }
            )
            return
        }

        guard ensureMidiOutputReady() else { return }

        var messages: [[UInt8]] = []
        for active in activeNotes.sorted(by: { $0.noteNumber < $1.noteNumber }) {
            releaseNote(active.noteNumber, into: &messages)
        }
        dispatch(messages)
    }

    func transitionPad(from oldPad: PadDefinition, to newPad: PadDefinition) {
        sendPadOff(oldPad)
        sendPadOn(newPad)
    }

    func sendUtilityCommand(_ command: MidiUtilityCommand) {
        guard ensureMidiOutputReady() else {
            lastMidiEventDescription = unavailableOutputDescription()
            return
        }

        if command == .panicAllChannels {
            sendAllNotesOff()
            return
        }

        guard outputRoute != .tinyPiano else {
            lastMidiEventDescription = "— → \(Self.internalPreviewDisplayName)"
            return
        }

        let messages = command.messages(channel: outputChannelIndex)
        transmitUtilityMessages(messages)
    }

    func sendAllNotesOff() {
        activeNotesByPad.removeAll()
        previewEngine.allNotesOff()

        guard outputRoute != .tinyPiano else {
            soundingNoteCounts.removeAll()
            return
        }

        guard ensureMidiOutputReady() else {
            soundingNoteCounts.removeAll()
            return
        }

        var messages: [[UInt8]] = []
        for note in soundingNoteCounts.keys.sorted() {
            messages.append(MidiMessageBuilder.noteOff(note: note, channel: outputChannelIndex))
        }
        soundingNoteCounts.removeAll()

        for channel in UInt8(0)..<16 {
            messages.append(MidiMessageBuilder.sustainPedal(false, channel: channel))
            messages.append(MidiMessageBuilder.allSoundOff(channel: channel))
            messages.append(MidiMessageBuilder.allNotesOff(channel: channel))
        }
        messages.append(MidiMessageBuilder.systemRealTime(.stop))

        transmitUtilityMessages(messages)
    }

    private func applyDefaultRouting() {
        if outputRoute == .tinyPiano {
            if hasOnlineKeyboardInput {
                let outputs = filteredPadOutputs.filter(\.isOnline)
                if let preferred = preferredPadOutput(from: outputs) {
                    selectPadOutput(uniqueID: preferred.uniqueID)
                }
            } else {
                selectTinyPianoOutput(reason: nil)
                reconcileKeyboardInputSelection()
                return
            }
        }

        if outputRoute == .garageBand {
            if let garageBand = garageBandDestination {
                selectedPadOutput = garageBand
                UserDefaults.standard.set(garageBand.uniqueID, forKey: Self.selectedPadOutputKey)
            } else if let selectedPadOutput,
                      !Self.isGarageBandDestination(selectedPadOutput.displayName) {
                outputRoute = .device
                UserDefaults.standard.set(MidiOutputRoute.device.rawValue, forKey: Self.selectedRouteKey)
            }
        } else {
            reconcilePadOutputSelection()
        }

        if let selectedPadOutput, outputRoute != .tinyPiano {
            syncOutputRoute(for: selectedPadOutput)
        }

        fallBackToTinyPianoIfNeeded()
        reconcileKeyboardInputSelection()
    }

    private func fallBackToTinyPianoIfNeeded() {
        switch outputRoute {
        case .tinyPiano:
            return
        case .garageBand:
            if garageBandDestination?.isOnline != true {
                selectTinyPianoOutput(reason: "GarageBand unavailable")
            }
        case .device:
            if !hasUsableExternalPadOutput() {
                selectTinyPianoOutput(reason: "External MIDI unavailable")
            }
        }
    }

    private func hasUsableExternalPadOutput() -> Bool {
        guard let selectedPadOutput,
              selectedPadOutput.uniqueID != Self.tinyPianoUniqueID,
              selectedPadOutput.isOnline,
              filteredPadOutputs.contains(where: { $0.uniqueID == selectedPadOutput.uniqueID }) else {
            return false
        }
        return true
    }

    private func reconcilePadOutputSelection() {
        if outputRoute == .tinyPiano {
            selectedPadOutput = Self.tinyPianoDestination
            return
        }

        let outputs = filteredPadOutputs.filter(\.isOnline)
        guard !outputs.isEmpty else {
            selectTinyPianoOutput(reason: "No external MIDI outputs")
            return
        }

        let selectionMissing = selectedPadOutput == nil
            || !outputs.contains(where: { $0.uniqueID == selectedPadOutput?.uniqueID })
        let selectionIsNetwork = selectedPadOutput.map {
            Self.isNetworkMidiEndpoint($0.displayName)
        } ?? false

        guard selectionMissing || selectionIsNetwork else { return }
        guard let preferred = preferredPadOutput(from: outputs) else {
            selectTinyPianoOutput(reason: "No preferred MIDI output")
            return
        }
        selectPadOutput(uniqueID: preferred.uniqueID)
    }

    private func reconcileKeyboardInputSelection() {
        let inputs = filteredKeyboardInputs.filter(\.isOnline)
        guard !inputs.isEmpty else { return }

        let selectionMissing = selectedKeyboardInput == nil
            || !inputs.contains(where: { $0.uniqueID == selectedKeyboardInput?.uniqueID })
        let selectionIsNetwork = selectedKeyboardInput.map {
            Self.isNetworkMidiEndpoint($0.displayName)
        } ?? false

        guard selectionMissing || selectionIsNetwork else { return }
        guard let preferred = preferredKeyboardInput(from: inputs) else { return }
        selectKeyboardInput(uniqueID: preferred.uniqueID)
    }

    private func preferredPadOutput(from outputs: [MidiDestinationInfo]) -> MidiDestinationInfo? {
        let online = outputs.filter(\.isOnline)
        guard !online.isEmpty else { return outputs.first }

        let ck = online.filter { Self.isCKSeriesHardwareEndpoint($0.displayName) }
        if let ckPort1 = ck.first(where: { Self.portNumber(in: $0.displayName) == 1 }) {
            return ckPort1
        }
        if let ckPrimary = ck.first {
            return ckPrimary
        }

        let akai = online.filter { Self.isAkaiMPCEndpoint($0.displayName) }
        if let akaiPort1 = akai.first(where: { Self.portNumber(in: $0.displayName) == 1 }) {
            return akaiPort1
        }
        if let akaiPrimary = akai.first {
            return akaiPrimary
        }

        if let garageBand = online.first(where: { Self.isGarageBandDestination($0) }) {
            return garageBand
        }
        return online.first
    }

    private func migrateLegacyMidiSettings() {
        if UserDefaults.standard.string(forKey: "midiSettingsMode") != nil {
            UserDefaults.standard.removeObject(forKey: "midiSettingsMode")
            UserDefaults.standard.removeObject(forKey: "selectedMidiOutputUniqueID")
            UserDefaults.standard.set(MidiOutputRoute.garageBand.rawValue, forKey: Self.selectedRouteKey)
        }
    }

    private func restorePersistedRouteIfAvailable() {
        guard let rawValue = UserDefaults.standard.string(forKey: Self.selectedRouteKey),
              let route = MidiOutputRoute(rawValue: rawValue) else {
            return
        }
        outputRoute = route
    }

    private func bootstrapPreviewSoundPresets() {
        migrateLegacyPreviewSoundIfNeeded()
        refreshPreviewSoundPresetOptions()

        let stored = UserDefaults.standard.string(forKey: Self.previewSoundSelectedPresetIDKey)
        let resolved: String
        if let stored, previewSoundPresetOptions.contains(where: { $0.id == stored }) {
            resolved = stored
        } else {
            resolved = PreviewSoundPresetIDs.tinyPiano
        }

        selectedPreviewSoundPresetID = resolved
        do {
            try applyPreviewSoundPreset(id: resolved, startEngineIfNeeded: false)
        } catch {
            selectedPreviewSoundPresetID = PreviewSoundPresetIDs.tinyPiano
            UserDefaults.standard.set(PreviewSoundPresetIDs.tinyPiano, forKey: Self.previewSoundSelectedPresetIDKey)
            try? applyPreviewSoundPreset(id: PreviewSoundPresetIDs.tinyPiano, startEngineIfNeeded: false)
        }
    }

    /// ルーティング確定後のセッション整備（内蔵エンジンは初回発音まで起動しない）。
    private func finalizeAudioSessionForCurrentRoute() {
        activatePreviewAudioSessionIfNeeded()
    }

    private func migrateLegacyPreviewSoundIfNeeded() {
        guard let legacy = UserDefaults.standard.data(forKey: Self.previewSoundPatchDataKey) else {
            return
        }
        if UserDefaults.standard.data(forKey: Self.previewSoundCustomPatchDataKey) == nil {
            UserDefaults.standard.set(legacy, forKey: Self.previewSoundCustomPatchDataKey)
        }
        UserDefaults.standard.removeObject(forKey: Self.previewSoundPatchDataKey)
        if UserDefaults.standard.string(forKey: Self.previewSoundSelectedPresetIDKey) == nil {
            UserDefaults.standard.set(PreviewSoundPresetIDs.custom, forKey: Self.previewSoundSelectedPresetIDKey)
        }
    }

    private func refreshPreviewSoundPresetOptions() {
        var options: [PreviewSoundPresetOption] = TinyToneFactoryPresets.orderedResourceNames.map { name in
            PreviewSoundPresetOption(
                id: PreviewSoundPresetIDs.factoryID(resourceName: name),
                displayName: TinyToneFactoryPresets.displayName(for: name),
                isCustom: false
            )
        }

        if let customData = UserDefaults.standard.data(forKey: Self.previewSoundCustomPatchDataKey),
           let patch = try? TinyToneJSONService.decode(customData) {
            options.append(
                PreviewSoundPresetOption(
                    id: PreviewSoundPresetIDs.custom,
                    displayName: patch.patchName,
                    isCustom: true
                )
            )
        }

        previewSoundPresetOptions = options
    }

    private func applyPreviewSoundPreset(id: String, startEngineIfNeeded: Bool) throws {
        let data = try previewSoundPresetData(for: id)
        if startEngineIfNeeded, outputRoute == .tinyPiano {
            try previewEngine.loadSoundPatch(from: data)
            previewEngine.allNotesOff()
        } else if let tinyEngine = previewEngine as? TinyToneEngine {
            try tinyEngine.prepareSoundPatch(from: data)
        } else {
            try previewEngine.loadSoundPatch(from: data)
        }
    }

    private func previewSoundPresetData(for id: String) throws -> Data {
        if id == PreviewSoundPresetIDs.custom {
            guard let custom = UserDefaults.standard.data(forKey: Self.previewSoundCustomPatchDataKey) else {
                throw PreviewSoundImportError.invalidPatch
            }
            return custom
        }
        if let resourceName = PreviewSoundPresetIDs.factoryResourceName(from: id),
           let factoryData = TinyToneFactoryPresets.jsonData(named: resourceName) {
            return factoryData
        }
        throw PreviewSoundImportError.invalidPatch
    }

    private func previewDisplayName(for id: String) -> String {
        previewSoundPresetOptions.first(where: { $0.id == id })?.displayName ?? id
    }

    private func restorePersistedPadOutputIfAvailable() {
        if outputRoute == .tinyPiano {
            selectedPadOutput = Self.tinyPianoDestination
            return
        }

        guard let storedID = UserDefaults.standard.object(forKey: Self.selectedPadOutputKey) as? Int32 else {
            return
        }
        if storedID == Self.tinyPianoUniqueID {
            outputRoute = .tinyPiano
            selectedPadOutput = Self.tinyPianoDestination
            return
        }
        guard let restored = destinations.first(where: { $0.uniqueID == storedID }),
              !Self.isExcludedPadOutput(restored.displayName) else {
            return
        }
        selectedPadOutput = restored
        syncOutputRoute(for: restored)
    }

    private func restorePersistedKeyboardInputIfAvailable() {
        guard let storedID = UserDefaults.standard.object(forKey: Self.selectedKeyboardInputKey) as? Int32,
              let restored = sources.first(where: { $0.uniqueID == storedID }),
              !Self.isExcludedKeyboardInput(restored) else {
            return
        }
        selectedKeyboardInput = restored
    }

    private func ensureKeyboardInputSelectedForCapture() {
        if let selectedKeyboardInput,
           filteredKeyboardInputs.contains(where: { $0.uniqueID == selectedKeyboardInput.uniqueID }) {
            return
        }
        guard let preferred = preferredKeyboardInput(from: filteredKeyboardInputs) else { return }
        selectKeyboardInput(uniqueID: preferred.uniqueID)
    }

    private func preferredKeyboardInput(from inputs: [MidiSourceInfo]) -> MidiSourceInfo? {
        let online = inputs.filter(\.isOnline)
        guard !online.isEmpty else { return inputs.first }

        let controllers = online.filter { Self.isPreferredControllerInput($0.displayName) }
        let pool = controllers.isEmpty ? online : controllers

        let ck = pool.filter { Self.isCKSeriesHardwareEndpoint($0.displayName) }
        if let ckPort1 = ck.first(where: { Self.portNumber(in: $0.displayName) == 1 }) {
            return ckPort1
        }
        if let ckPrimary = ck.first {
            return ckPrimary
        }

        let akai = pool.filter { Self.isAkaiMPCEndpoint($0.displayName) }
        if let akaiPort1 = akai.first(where: { Self.portNumber(in: $0.displayName) == 1 }) {
            return akaiPort1
        }
        if let akaiPrimary = akai.first {
            return akaiPrimary
        }

        if let keys = pool.first(where: { Self.isKeyboardKeysInputPort($0.displayName) }) {
            return keys
        }
        if let port1 = pool.first(where: { Self.portNumber(in: $0.displayName) == 1 }) {
            return port1
        }
        if let primary = pool.first(where: { !Self.isAuxiliaryControllerInputPort($0.displayName) }) {
            return primary
        }
        return pool.first ?? inputs.first
    }

    private func transmitExpression() {
        guard ensureMidiOutputReady() else { return }
        let message = MidiMessageBuilder.expression(expression, channel: outputChannelIndex)
        _ = transmit(message)
    }

    private func applyPreviewExpressionLevel() {
        let normalized = min(Float(expression) / 100.0, 1.0)
        previewEngine.setPreviewLevel(normalized)
    }

    private func acquireNote(_ note: UInt8, into messages: inout [[UInt8]]) {
        let count = soundingNoteCounts[note, default: 0]
        if count == 0 {
            messages.append(
                MidiMessageBuilder.noteOn(note: note, velocity: velocity, channel: outputChannelIndex)
            )
        }
        soundingNoteCounts[note] = count + 1
    }

    private func releaseNote(_ note: UInt8, into messages: inout [[UInt8]]) {
        guard let count = soundingNoteCounts[note], count > 0 else { return }
        if count == 1 {
            soundingNoteCounts.removeValue(forKey: note)
            messages.append(MidiMessageBuilder.noteOff(note: note, channel: outputChannelIndex))
        } else {
            soundingNoteCounts[note] = count - 1
        }
    }

    private func refreshDestinations() {
        let count = MIDIGetNumberOfDestinations()
        var refreshed: [MidiDestinationInfo] = []
        refreshed.reserveCapacity(Int(count))

        for index in 0..<count {
            let endpoint = MIDIGetDestination(index)
            guard endpoint != 0 else { continue }

            refreshed.append(
                MidiDestinationInfo(
                    uniqueID: intProperty(kMIDIPropertyUniqueID, endpoint: endpoint) ?? MIDIUniqueID(index),
                    endpointRef: endpoint,
                    displayName: endpointName(endpoint, fallback: "Output \(index + 1)"),
                    isOnline: (intProperty(kMIDIPropertyOffline, endpoint: endpoint) ?? 0) == 0
                )
            )
        }

        destinations = refreshed.sorted {
            $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
        }

        if let selectedPadOutput,
           let updated = destinations.first(where: { $0.uniqueID == selectedPadOutput.uniqueID }) {
            self.selectedPadOutput = updated
        } else if selectedPadOutput != nil {
            selectedPadOutput = nil
        }
    }

    private func refreshSources() {
        let count = MIDIGetNumberOfSources()
        var refreshed: [MidiSourceInfo] = []
        refreshed.reserveCapacity(Int(count))

        for index in 0..<count {
            let endpoint = MIDIGetSource(index)
            guard endpoint != 0 else { continue }

            refreshed.append(
                MidiSourceInfo(
                    uniqueID: intProperty(kMIDIPropertyUniqueID, endpoint: endpoint) ?? MIDIUniqueID(index + 10_000),
                    endpointRef: endpoint,
                    displayName: endpointName(endpoint, fallback: "Input \(index + 1)"),
                    isOnline: (intProperty(kMIDIPropertyOffline, endpoint: endpoint) ?? 0) == 0
                )
            )
        }

        sources = refreshed.sorted {
            $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
        }

        if let selectedKeyboardInput,
           let updated = sources.first(where: { $0.uniqueID == selectedKeyboardInput.uniqueID }),
           !Self.isExcludedKeyboardInput(updated) {
            self.selectedKeyboardInput = updated
        } else if selectedKeyboardInput != nil {
            selectedKeyboardInput = nil
        }
    }

    private func dispatch(_ messages: [[UInt8]]) {
        for message in messages {
            let status = transmit(message)
            lastMidiEventDescription = status == noErr ? describe(message) : midiErrorDescription(status)
        }
    }

    private func transmitUtilityMessages(_ messages: [[UInt8]]) {
        guard !messages.isEmpty else { return }

        let routeLabel = outputRoute == .garageBand ? "GB" : currentOutputName
        var lastStatus: OSStatus = noErr
        var lastMessage: [UInt8] = []

        for message in messages {
            lastStatus = transmit(message)
            lastMessage = message
            guard lastStatus == noErr else { break }
        }

        if lastStatus == noErr {
            lastMidiEventDescription = "\(describe(lastMessage)) → \(routeLabel)"
        } else {
            lastMidiEventDescription = midiErrorDescription(lastStatus)
        }
    }

    @discardableResult
    private func ensureVirtualSourceReady() -> Bool {
        guard MidiAudioSession.hasBackgroundAudioMode else {
            lastVirtualSourceError = kMIDINotPermitted
            return false
        }

        let audioStatus = MidiAudioSession.activateForVirtualMIDI()
        if audioStatus != noErr {
            lastVirtualSourceError = audioStatus
            return false
        }

        createMidiClientIfNeeded()
        guard midiClient != 0 else {
            lastVirtualSourceError = lastVirtualSourceError == noErr ? errSecParam : lastVirtualSourceError
            return false
        }

        if virtualSource != 0, isLiveEndpoint(virtualSource) {
            return true
        }

        virtualSource = 0
        virtualSourceUsesEventList = false

        if let existing = locateJChordSourceInSystem() {
            virtualSource = existing
            virtualSourceUsesEventList = endpointUsesUMP(existing)
            return true
        }

        createVirtualSourceIfNeeded()
        return virtualSource != 0
    }

    @discardableResult
    private func ensureTinyPianoReady() -> Bool {
        let started = previewEngine.start()
        let ready = started && outputRoute == .tinyPiano && previewEngine.isEngineRunning
        if isInternalPreviewReady != ready {
            isInternalPreviewReady = ready
        }
        return started
    }

    private func clearInternalPreviewReady() {
        if isInternalPreviewReady {
            isInternalPreviewReady = false
        }
    }

    private func ensureMidiOutputReady() -> Bool {
        switch outputRoute {
        case .tinyPiano:
            return ensureTinyPianoReady()
        case .garageBand:
            return ensureVirtualSourceReady()
        case .device:
            createMidiClientIfNeeded()
            createOutputPortIfNeeded()
            guard let selectedPadOutput,
                  selectedPadOutput.isOnline,
                  selectedPadOutput.endpointRef != 0,
                  filteredPadOutputs.contains(where: { $0.uniqueID == selectedPadOutput.uniqueID }) else {
                return false
            }
            return outputPort != 0
        }
    }

    private func transmit(_ message: [UInt8]) -> OSStatus {
        switch outputRoute {
        case .tinyPiano:
            return errSecParam
        case .garageBand:
            guard ensureVirtualSourceReady() else { return lastVirtualSourceError }
            return MidiPacketTransmitter.received(
                message,
                on: virtualSource,
                preferEventList: virtualSourceUsesEventList
            )
        case .device:
            createMidiClientIfNeeded()
            createOutputPortIfNeeded()
            guard let destination = selectedPadOutput?.endpointRef, destination != 0, outputPort != 0 else {
                return errSecParam
            }
            return MidiPacketTransmitter.send(message, to: destination, via: outputPort)
        }
    }

    private func unavailableOutputDescription() -> String {
        switch outputRoute {
        case .tinyPiano:
            return tinyPianoUnavailableDescription()
        case .garageBand:
            return unavailableSourceDescription()
        case .device:
            return L10n.string("error.no_midi_output")
        }
    }

    /// PAD OUT 行: 接続中のみ右ラベル（未選択に「選択中」は出さない）。
    private static func padOutputStatusLabel(isOnline: Bool, isActiveRoute: Bool) -> String {
        if !isOnline {
            return L10n.string("settings.device.offline")
        }
        if isActiveRoute {
            return L10n.string("settings.device.active")
        }
        return ""
    }

    private static func deviceStatusLabel(
        isOnline: Bool,
        isSelected: Bool,
        isActiveRoute: Bool
    ) -> String {
        if !isOnline {
            return L10n.string("settings.device.offline")
        }
        if isActiveRoute {
            return L10n.string("settings.device.active")
        }
        if isSelected {
            return L10n.string("settings.device.connected")
        }
        return ""
    }

    private func unavailableSourceDescription() -> String {
        if !MidiAudioSession.hasBackgroundAudioMode {
            return "Missing audio background mode — delete app, clean build, reinstall"
        }
        if lastVirtualSourceError == kMIDINotPermitted {
            return "MIDI not permitted — open JPad once, then GarageBand"
        }
        if midiClient == 0 {
            return "MIDI client unavailable (\(lastVirtualSourceError))"
        }
        return "JPad MIDI source unavailable (\(lastVirtualSourceError))"
    }

    private func midiErrorDescription(_ status: OSStatus) -> String {
        if status == errSecParam, !hasVirtualSource {
            return unavailableSourceDescription()
        }
        return "MIDI error \(status)"
    }

    private func isLiveEndpoint(_ endpoint: MIDIEndpointRef) -> Bool {
        var uniqueID: Int32 = 0
        return MIDIObjectGetIntegerProperty(endpoint, kMIDIPropertyUniqueID, &uniqueID) == noErr
    }

    private func locateJChordSourceInSystem() -> MIDIEndpointRef? {
        let count = MIDIGetNumberOfSources()
        for index in 0..<count {
            let endpoint = MIDIGetSource(index)
            guard endpoint != 0 else { continue }
            let name = endpointName(endpoint, fallback: "")
            if name.localizedCaseInsensitiveCompare(Self.virtualSourceName) == .orderedSame {
                return endpoint
            }
        }
        return nil
    }

    private func endpointUsesUMP(_ endpoint: MIDIEndpointRef) -> Bool {
        var protocolValue: Int32 = 0
        let status = MIDIObjectGetIntegerProperty(endpoint, kMIDIPropertyProtocolID, &protocolValue)
        if status == noErr {
            return protocolValue == 1
        }
        return false
    }

    private func describe(_ message: [UInt8]) -> String {
        guard let first = message.first else { return "Empty" }

        if message.count == 1 {
            switch MidiMessageBuilder.SystemRealTime(rawValue: first) {
            case .start:
                return "MIDI Start"
            case .continue:
                return "MIDI Continue"
            case .stop:
                return "MIDI Stop"
            case nil:
                return String(format: "Sys 0x%02X", first)
            }
        }

        guard message.count >= 3 else { return "Sent \(message.count) bytes" }
        let status = message[0] & 0xF0
        let channel = (message[0] & 0x0F) + 1
        let note = message[1]
        let value = message[2]

        switch status {
        case 0x90 where value > 0:
            return "Note On \(note) ch\(channel) vel \(value)"
        case 0x80, 0x90:
            return "Note Off \(note) ch\(channel)"
        case 0xB0:
            return ccDescription(controller: message[1], value: value, channel: Int(channel))
        default:
            return "Sent MIDI ch\(channel)"
        }
    }

    private func ccDescription(controller: UInt8, value: UInt8, channel: Int) -> String {
        let name: String
        switch controller {
        case 64:
            name = value >= 64 ? "Sustain On" : "Sustain Off"
        case 120:
            name = "All Sound Off"
        case 121:
            name = "Reset Controllers"
        case 123:
            name = "All Notes Off"
        default:
            name = "CC \(controller)=\(value)"
        }
        return "\(name) ch\(channel)"
    }

    private func connectKeyboardCaptureIfNeeded() {
        guard noteCaptureBridge.isActive,
              let source = selectedKeyboardInput,
              source.isOnline,
              source.endpointRef != 0 else {
            return
        }

        createInputPortIfNeeded()
        guard inputPort != 0 else { return }

        if captureSourceEndpoint == source.endpointRef {
            return
        }

        disconnectKeyboardCapture()

        if MIDIPortConnectSource(inputPort, source.endpointRef, nil) == noErr {
            captureSourceEndpoint = source.endpointRef
            MidiDiagnostics.captureStarted(sourceName: source.displayName)
        }
    }

    private func disconnectKeyboardCapture() {
        guard inputPort != 0, captureSourceEndpoint != 0 else {
            captureSourceEndpoint = 0
            return
        }
        MIDIPortDisconnectSource(inputPort, captureSourceEndpoint)
        captureSourceEndpoint = 0
    }

    private func createMidiClientIfNeeded() {
        guard midiClient == 0 else { return }
        let status = MIDIClientCreateWithBlock("JPad MIDI Client" as CFString, &midiClient) { [weak self] notification in
            switch notification.pointee.messageID {
            case .msgSetupChanged, .msgObjectAdded, .msgObjectRemoved:
                Task { @MainActor [weak self] in
                    self?.scheduleEndpointRefreshFromMidiNotification()
                }
            default:
                break
            }
        }
        if status != noErr {
            midiClient = 0
            lastVirtualSourceError = status
        }
    }

    private func createOutputPortIfNeeded() {
        guard outputPort == 0 else { return }
        MIDIOutputPortCreate(midiClient, "JPad Output Port" as CFString, &outputPort)
    }

    private func createInputPortIfNeeded() {
        guard inputPort == 0, midiClient != 0 else { return }

        let status = midiInputPortFactory.createInputPort(
            client: midiClient,
            bridge: noteCaptureBridge,
            port: &inputPort
        )

        if status != noErr {
            inputPort = 0
        }
    }

    private func createVirtualSourceIfNeeded() {
        guard virtualSource == 0, midiClient != 0 else { return }

        var status = MIDISourceCreate(midiClient, Self.virtualSourceName as CFString, &virtualSource)
        if status == noErr, virtualSource != 0 {
            virtualSourceUsesEventList = false
            lastVirtualSourceError = noErr
            return
        }

        virtualSource = 0
        status = MIDISourceCreateWithProtocol(
            midiClient,
            Self.virtualSourceName as CFString,
            MIDIProtocolID(rawValue: 1)!,
            &virtualSource
        )
        if status == noErr, virtualSource != 0 {
            virtualSourceUsesEventList = true
            lastVirtualSourceError = noErr
            return
        }

        virtualSource = 0
        virtualSourceUsesEventList = false
        lastVirtualSourceError = status
    }

    private func endpointName(_ endpoint: MIDIEndpointRef, fallback: String) -> String {
        stringProperty(kMIDIPropertyDisplayName, endpoint: endpoint)
            ?? stringProperty(kMIDIPropertyName, endpoint: endpoint)
            ?? fallback
    }

    private func stringProperty(_ property: CFString, endpoint: MIDIEndpointRef) -> String? {
        var unmanagedName: Unmanaged<CFString>?
        let status = MIDIObjectGetStringProperty(endpoint, property, &unmanagedName)
        guard status == noErr else { return nil }
        return unmanagedName?.takeRetainedValue() as String?
    }

    private func intProperty(_ property: CFString, endpoint: MIDIEndpointRef) -> MIDIUniqueID? {
        var value: Int32 = 0
        let status = MIDIObjectGetIntegerProperty(endpoint, property, &value)
        guard status == noErr else { return nil }
        return value
    }

    /// 設定リスト用の短い表示名（GarageBand は常に GARAGE BAND）。
    static func friendlyListTitle(forPadOutput displayName: String) -> String {
        if displayName == tinyPianoDestination.displayName {
            return Self.internalPreviewDisplayName
        }
        if isGarageBandDestination(displayName) {
            return "GARAGE BAND"
        }
        if isAkaiMPCEndpoint(displayName) {
            if let port = portNumber(in: displayName) {
                return "AKAI MPC \(port)"
            }
            return "AKAI MPC"
        }
        return displayName
    }

    static func friendlyListTitle(forKeyboardInput displayName: String) -> String {
        if isGarageBandInputName(displayName) {
            return "GARAGE BAND"
        }
        if isAkaiMPCEndpoint(displayName) {
            if let port = portNumber(in: displayName) {
                return "AKAI MPC \(port)"
            }
            return "AKAI MPC"
        }
        return displayName
    }

    private static func isGarageBandDestination(_ destination: MidiDestinationInfo) -> Bool {
        isGarageBandDestination(destination.displayName)
    }

    private static func isGarageBandDestination(_ displayName: String) -> Bool {
        let name = displayName.localizedLowercase
        return name.contains("garageband")
            || name.contains("garage band")
            || (name.contains("garage") && name.contains("仮想"))
    }

    private static func isGarageBandSource(_ source: MidiSourceInfo) -> Bool {
        isGarageBandInputName(source.displayName)
    }

    private static func isGarageBandInputName(_ displayName: String) -> Bool {
        let name = displayName.localizedLowercase
        return name.contains("garageband")
            || name.contains("garage band")
            || (name.contains("garage") && name.contains("仮想"))
    }

    private static func isJChordVirtualSource(_ source: MidiSourceInfo) -> Bool {
        source.displayName.localizedCaseInsensitiveCompare(virtualSourceName) == .orderedSame
    }

    private static func isExcludedKeyboardInput(_ source: MidiSourceInfo) -> Bool {
        isJChordVirtualSource(source)
            || isGarageBandSource(source)
            || isNetworkMidiEndpoint(source.displayName)
            || isCKSeriesKeyboardInputPortToAvoid(source.displayName)
            || isAkaiMPCKeyboardInputPortToAvoid(source.displayName)
            || isAuxiliaryControllerInputPort(source.displayName)
    }

    private static func isNetworkMidiEndpoint(_ displayName: String) -> Bool {
        let name = displayName.localizedLowercase
        if name.contains("ネットワーク") { return true }
        if name.contains("network session") { return true }
        if name.contains("network") && name.contains("session") { return true }
        return false
    }

    private static func isCKSeriesHardwareEndpoint(_ displayName: String) -> Bool {
        let name = displayName.localizedLowercase
        if name.contains("ck series") { return true }
        if name.contains("ck61") { return true }
        if name.contains("yamaha") { return true }
        if name.contains("ck") && name.contains("ポート") { return true }
        return false
    }

    /// CK の Port 2 は KEYBOARD IN では使わない（PAD OUT 側は Port 1 優先）。
    private static func isCKSeriesKeyboardInputPortToAvoid(_ displayName: String) -> Bool {
        guard isCKSeriesHardwareEndpoint(displayName) else { return false }
        return portNumber(in: displayName) == 2
    }

    private static func isAkaiMPCEndpoint(_ displayName: String) -> Bool {
        let name = displayName.localizedLowercase
        return name.contains("mpc") || name.contains("akai")
    }

    /// AKAI MPC の Port 2 は KEYBOARD IN では使わない（PAD OUT 側は Port 1 優先）。
    private static func isAkaiMPCKeyboardInputPortToAvoid(_ displayName: String) -> Bool {
        guard isAkaiMPCEndpoint(displayName) else { return false }
        return portNumber(in: displayName) == 2
    }

    private static func isExcludedPadOutput(_ displayName: String) -> Bool {
        if isNetworkMidiEndpoint(displayName) { return true }
        if isCKSeriesHardwareEndpoint(displayName) { return false }
        if isAkaiMPCEndpoint(displayName) { return false }
        return isAuxiliaryControllerInputPort(displayName)
    }

    private static func isPreferredControllerInput(_ displayName: String) -> Bool {
        let name = displayName.localizedLowercase
        if name.contains("minilab") || name.contains("arturia") { return true }
        if name.contains("keylab") { return true }
        if isCKSeriesHardwareEndpoint(displayName) { return true }
        if isAkaiMPCEndpoint(displayName) { return true }
        return false
    }

    /// ALV / MCU / DIN THRU など鍵盤ノート以外のポート（接続するとクラッシュやフリーズの原因）
    private static func isAuxiliaryControllerInputPort(_ displayName: String) -> Bool {
        let name = displayName.localizedLowercase
        if name.contains("alv") { return true }
        if name.contains("mcu") || name.contains("hui") { return true }
        if name.contains("din") || name.contains("thru") { return true }
        if name.contains("midi in 2") || name.contains("midiin2") { return true }
        return false
    }

    /// 鍵盤ノート用（Minilab3 MIDI など）
    private static func isKeyboardKeysInputPort(_ displayName: String) -> Bool {
        let name = displayName.localizedLowercase
        guard name.contains("midi"), !isAuxiliaryControllerInputPort(displayName) else { return false }
        return name.contains("minilab") || name.contains("arturia") || name.contains("keylab")
            || isCKSeriesHardwareEndpoint(displayName)
            || isAkaiMPCEndpoint(displayName)
    }

    private static func portNumber(in displayName: String) -> Int? {
        let name = displayName.lowercased()
        if name.contains("ポート 2") || name.contains("ポート2") || name.contains("port 2")
            || name.contains("midi 2") || name.contains("midi2") {
            return 2
        }
        if name.contains("ポート 1") || name.contains("ポート1") || name.contains("port 1")
            || name.contains("midi 1") || name.contains("midi1") {
            return 1
        }
        return nil
    }

    private static func sortPadOutputsForDisplay(_ lhs: String, _ rhs: String) -> Bool {
        let left = padOutputSortRank(lhs)
        let right = padOutputSortRank(rhs)
        if left != right { return left < right }
        return lhs.localizedCaseInsensitiveCompare(rhs) == .orderedAscending
    }

    private static func padOutputSortRank(_ displayName: String) -> Int {
        if isGarageBandDestination(displayName) { return 0 }
        if isCKSeriesHardwareEndpoint(displayName) {
            if portNumber(in: displayName) == 1 { return 1 }
            if portNumber(in: displayName) == 2 { return 2 }
            return 3
        }
        if isAkaiMPCEndpoint(displayName) {
            if portNumber(in: displayName) == 1 { return 4 }
            if portNumber(in: displayName) == 2 { return 5 }
            return 6
        }
        return 100
    }

    private static func sortKeyboardInputsForDisplay(_ lhs: String, _ rhs: String) -> Bool {
        let left = keyboardSortRank(lhs)
        let right = keyboardSortRank(rhs)
        if left != right { return left < right }
        return lhs.localizedCaseInsensitiveCompare(rhs) == .orderedAscending
    }

    private static func keyboardSortRank(_ displayName: String) -> Int {
        if isKeyboardKeysInputPort(displayName) { return 0 }
        if isPreferredControllerInput(displayName), !isAuxiliaryControllerInputPort(displayName) { return 1 }
        return 100
    }
}

/// MIDI スレッドと UI の境界（パケット単位の main.async 洪水を避け、デバウンス後に MainActor へ）
private final class MidiNoteCaptureBridge: @unchecked Sendable {
    private let lock = NSLock()
    private var handler: (@Sendable ([UInt8]) -> Void)?
    private var isEnabled = false
    private let debouncer = MidiCaptureDebouncer()
    private var pendingNotes = Set<UInt8>()
    private var mainFlushScheduled = false

    var isActive: Bool {
        lock.lock()
        defer { lock.unlock() }
        return isEnabled
    }

    func setHandler(_ handler: (@Sendable ([UInt8]) -> Void)?) {
        lock.lock()
        self.handler = handler
        isEnabled = handler != nil
        pendingNotes.removeAll(keepingCapacity: false)
        mainFlushScheduled = false
        lock.unlock()
        if handler == nil {
            debouncer.reset()
        }
    }

    func ingest(packetList: UnsafePointer<MIDIPacketList>) {
        guard isCaptureEnabled() else { return }
        let notes: [UInt8] = autoreleasepool {
            MidiMessageParser.noteOnNumbers(in: packetList)
        }
        guard !notes.isEmpty else { return }

        lock.lock()
        pendingNotes.formUnion(notes)
        let scheduleMainFlush = !mainFlushScheduled
        if scheduleMainFlush {
            mainFlushScheduled = true
        }
        lock.unlock()

        guard scheduleMainFlush else { return }
        DispatchQueue.main.async { [weak self] in
            self?.flushPendingToDebouncer()
        }
    }

    private func isCaptureEnabled() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return isEnabled
    }

    private func flushPendingToDebouncer() {
        lock.lock()
        let batch = pendingNotes.sorted()
        pendingNotes.removeAll(keepingCapacity: true)
        mainFlushScheduled = false
        let enabled = isEnabled
        let handler = handler
        lock.unlock()

        guard enabled, let handler, !batch.isEmpty else { return }
        MidiDiagnostics.notesReceived(batch)
        debouncer.submit(batch, deliver: handler)
    }
}

/// MIDI 受信スレッドからのノートをまとめて MainActor へ渡す（UI 固まり防止）
private final class MidiCaptureDebouncer: @unchecked Sendable {
    private let lock = NSLock()
    private var pending = Set<UInt8>()
    private var workItem: DispatchWorkItem?
    private var generation = 0
    private let delay: TimeInterval

    init(delay: TimeInterval = 0.05) {
        self.delay = delay
    }

    func submit(_ notes: [UInt8], deliver: @escaping @Sendable ([UInt8]) -> Void) {
        lock.lock()
        pending.formUnion(notes)
        workItem?.cancel()
        generation += 1
        let generationAtSchedule = generation
        let item = DispatchWorkItem { [weak self] in
            guard let self else { return }
            let batch = self.drainIfGeneration(generationAtSchedule)
            guard !batch.isEmpty else { return }
            deliver(batch)
        }
        workItem = item
        lock.unlock()
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: item)
    }

    func reset() {
        lock.lock()
        generation += 1
        pending.removeAll(keepingCapacity: false)
        workItem?.cancel()
        workItem = nil
        lock.unlock()
    }

    private func drainIfGeneration(_ expected: Int) -> [UInt8] {
        lock.lock()
        defer { lock.unlock() }
        guard generation == expected, !pending.isEmpty else { return [] }
        let batch = pending.sorted()
        pending.removeAll(keepingCapacity: true)
        workItem = nil
        return batch
    }
}
