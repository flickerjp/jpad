import Foundation

/// コード構成音を基準キー以上に絞り、U / M1 / M2 / L の 4 声部へグルーピングする。
enum RiffVoiceGrouper {
    /// 戻り値は `[upper, middle1, middle2, lower]`。基準キーより下の構成音は鳴らさない。
    static func groupedVoices(chordNotes: [UInt8], baseKey: UInt8) -> [[UInt8]] {
        let candidates = Set(chordNotes.filter { $0 >= baseKey }).sorted()
        guard !candidates.isEmpty else { return emptyVoices() }

        switch candidates.count {
        case 1:
            return [[], [candidates[0]], [], []]
        case 2:
            return [[candidates[1]], [], [], [candidates[0]]]
        case 3:
            return [[candidates[2]], [candidates[1]], [], [candidates[0]]]
        case 4:
            return [[candidates[3]], [candidates[2]], [candidates[1]], [candidates[0]]]
        default:
            let lower = candidates[0]
            let upper = candidates[candidates.count - 1]
            let middle = Array(candidates.dropFirst().dropLast())
            let split = bestMiddleSplitIndex(for: middle)
            let lowerMiddle = Array(middle[..<split])
            let upperMiddle = Array(middle[split...])
            return [[upper], upperMiddle, lowerMiddle, [lower]]
        }
    }

    private static func emptyVoices() -> [[UInt8]] {
        Array(repeating: [], count: RiffPatternSlot.voiceCount)
    }

    /// 低い順の中間音を M2 / M1 に分割する。各グループ内の音域幅が小さいほど「近い音どうし」になる。
    private static func bestMiddleSplitIndex(for notes: [UInt8]) -> Int {
        guard notes.count > 1 else { return 1 }

        let candidates = 1 ..< notes.count
        return candidates.min { lhs, rhs in
            let lhsScore = splitScore(notes, at: lhs)
            let rhsScore = splitScore(notes, at: rhs)
            if lhsScore.totalRange != rhsScore.totalRange {
                return lhsScore.totalRange < rhsScore.totalRange
            }
            if lhsScore.balance != rhsScore.balance {
                return lhsScore.balance < rhsScore.balance
            }
            return lhs > rhs
        } ?? max(1, notes.count / 2)
    }

    private static func splitScore(_ notes: [UInt8], at index: Int) -> (totalRange: Int, balance: Int) {
        let lower = Array(notes[..<index])
        let upper = Array(notes[index...])
        let lowerRange = Int(lower.last ?? 0) - Int(lower.first ?? 0)
        let upperRange = Int(upper.last ?? 0) - Int(upper.first ?? 0)
        return (
            totalRange: lowerRange + upperRange,
            balance: abs(lower.count - upper.count)
        )
    }
}

/// SEQ 再生用に解決済みのイベント列。
struct SeqPlaybackEvent: Equatable {
    /// 発音するノート（休符は空）。
    let notes: [UInt8]
    /// 16 分音符単位の長さ（TIE で延長された合計）。
    let stepLength: Int

    static let rest = SeqPlaybackEvent(notes: [], stepLength: 1)
    static let silentLoop = Array(repeating: SeqPlaybackEvent.rest, count: SeqPatternSlot.maxStepCount)
}

private struct PendingRiffPatternChange {
    let pattern: RiffPatternSlot
}

private struct PendingSeqEventChange {
    let events: [SeqPlaybackEvent]
}

enum SeqPatternResolver {
    /// SH-101 式の入力列（pad / tie / rest）を再生イベントへ変換する。
    /// 先頭の tie は休符として扱う。長さの合計は入力ステップ数と一致する。
    static func resolve(
        slot: SeqPatternSlot,
        pads: [PadDefinition],
        transposeSemitones: Int
    ) -> [SeqPlaybackEvent] {
        let padsByIndex = Dictionary(uniqueKeysWithValues: pads.map { ($0.index, $0) })
        var events: [SeqPlaybackEvent] = []

        for step in slot.steps {
            switch step.kind {
            case .pad:
                let notes = step.padIndex
                    .flatMap { padsByIndex[$0] }
                    .map { playbackNotes(for: $0, transposeSemitones: transposeSemitones) } ?? []
                events.append(SeqPlaybackEvent(notes: notes, stepLength: 1))
            case .tie:
                if let last = events.last, !last.notes.isEmpty {
                    events[events.count - 1] = SeqPlaybackEvent(
                        notes: last.notes,
                        stepLength: last.stepLength + 1
                    )
                } else {
                    events.append(SeqPlaybackEvent(notes: [], stepLength: 1))
                }
            case .rest:
                events.append(SeqPlaybackEvent(notes: [], stepLength: 1))
            }
        }
        return events.isEmpty ? SeqPlaybackEvent.silentLoop : events
    }

    static func playbackNotes(for pad: PadDefinition, transposeSemitones: Int) -> [UInt8] {
        var seen = Set<UInt8>()
        var ordered: [UInt8] = []
        for note in pad.bassNotes + pad.chordNotes {
            let shifted = Int(note) + transposeSemitones
            guard (0 ... 127).contains(shifted) else { continue }
            let value = UInt8(shifted)
            guard seen.insert(value).inserted else { continue }
            ordered.append(value)
        }
        return ordered
    }
}

/// RIFF / SEQ の共用ステップクロックエンジン。
/// 発音は noteOn / noteOff クロージャ経由（MidiOutputService の preview note API を想定。
/// 同 API は ref count 管理なので、ゲートの重なりがあってもノートが消えすぎない）。
@MainActor
final class PadSequencerEngine: ObservableObject {
    @Published private(set) var riffActivePadID: Int?
    /// 再生中の RIFF ステップ位置（16 分音符単位、UI 表示用）。
    @Published private(set) var riffCurrentRawStep: Int?
    @Published private(set) var isSeqPlaying = false
    /// 再生中の SEQ ステップ位置（16 分音符単位、UI 表示用）。
    @Published private(set) var seqCurrentRawStep: Int?

    var noteOn: (UInt8) -> Void = { _ in }
    var noteOff: (UInt8) -> Void = { _ in }
    var notesOn: ([UInt8]) -> Void = { _ in }
    var notesOff: ([UInt8]) -> Void = { _ in }
    /// 16 分音符 1 個ぶんの秒数。内部 BPM / MIDI Clock 追従の解決は呼び出し側が行う。
    var stepInterval: () -> TimeInterval = { 0.125 }
    /// SEQ のゲート長。短いほど連打時に音が詰まりにくい。
    var seqGate: () -> Double = { 0.5 }

    // MARK: - RIFF

    private var riffPattern: RiffPatternSlot = .default
    private var riffVoices: [[UInt8]] = Array(repeating: [], count: RiffPatternSlot.voiceCount)
    private var riffStepIndex = 0
    private var riffGeneration = 0
    private var pendingRiffPatternChange: PendingRiffPatternChange?

    func startRiff(padID: Int, voices: [[UInt8]], pattern: RiffPatternSlot) {
        stopRiffNotes()
        riffActivePadID = padID
        riffVoices = voices
        riffPattern = pattern
        riffStepIndex = 0
        riffGeneration += 1
        pendingRiffPatternChange = nil
        riffCurrentRawStep = 0
        let generation = riffGeneration
        fireRiffStep()
        scheduleNextRiffStep(after: ContinuousClock.now, generation: generation)
    }

    /// 演奏中のパターン/スロット差し替え（次のステップから反映）。
    func updateRiffPattern(_ pattern: RiffPatternSlot) {
        riffPattern = pattern
    }

    /// 演奏中の発音対象ボイス差し替え（次のステップから反映）。
    func updateRiffVoices(_ voices: [[UInt8]]) {
        riffVoices = voices
    }

    /// 演奏位置を保ったまま、RIFF の発音対象パッドとボイスだけ差し替える。
    func updateRiffPad(padID: Int, voices: [[UInt8]]) {
        riffActivePadID = padID
        riffVoices = voices
        stopRiffNotes()
    }

    /// 演奏中のスロット差し替え（次の 16 分頭で反映）。
    func queueRiffPatternChange(_ pattern: RiffPatternSlot) {
        pendingRiffPatternChange = PendingRiffPatternChange(pattern: pattern)
    }

    func stopRiff() {
        riffGeneration += 1
        riffActivePadID = nil
        riffCurrentRawStep = nil
        pendingRiffPatternChange = nil
        stopRiffNotes()
    }

    private func scheduleNextRiffStep(after reference: ContinuousClock.Instant, generation: Int) {
        let deadline = reference.advanced(by: .seconds(stepInterval()))
        Task.detached(priority: .userInitiated) { [weak self] in
            try? await Task.sleep(until: deadline, clock: .continuous)
            await MainActor.run {
                guard let self, generation == self.riffGeneration else { return }
                self.riffStepIndex = (self.riffStepIndex + 1) % RiffPatternSlot.stepCount
                self.applyPendingRiffPatternChangeIfNeeded()
                self.fireRiffStep()
                self.scheduleNextRiffStep(after: deadline, generation: generation)
            }
        }
    }

    private func applyPendingRiffPatternChangeIfNeeded() {
        guard let pending = pendingRiffPatternChange else { return }
        pendingRiffPatternChange = nil
        stopRiffNotes()
        riffPattern = pending.pattern
    }

    private func fireRiffStep() {
        let step = riffStepIndex
        riffCurrentRawStep = step
        let interval = stepInterval()
        let gateDuration = max(0.01, interval * riffPattern.gate)
        let generation = riffGeneration

        for voice in 0 ..< RiffPatternSlot.voiceCount {
            guard riffPattern.steps.indices.contains(voice),
                  riffPattern.steps[voice].indices.contains(step),
                  riffPattern.steps[voice][step] else { continue }
            let notes = voice < riffVoices.count ? riffVoices[voice] : []
            guard !notes.isEmpty else { continue }
            playGatedNotes(notes, duration: gateDuration, generation: generation, isRiff: true)
        }
    }

    private func stopRiffNotes() {
        for note in Array(soundingRiffNotes.keys) {
            releaseAll(note: note, counts: &soundingRiffNotes)
        }
    }

    // MARK: - SEQ

    private var seqEvents: [SeqPlaybackEvent] = []
    private var seqRawStepCount = 0
    private var seqEventIndex = 0
    private var seqBarRawStep = 0
    private var seqGeneration = 0
    private var pendingSeqEventChange: PendingSeqEventChange?

    func startSeq(events: [SeqPlaybackEvent]) {
        stopSeq()
        let events = normalizedSeqEvents(events)
        seqEvents = events
        let rawCount = events.reduce(0) { $0 + $1.stepLength }
        seqRawStepCount = rawCount
        seqEventIndex = 0
        seqBarRawStep = 0
        seqGeneration += 1
        pendingSeqEventChange = nil
        isSeqPlaying = true
        seqCurrentRawStep = 0
        let generation = seqGeneration
        fireSeqEvent()
        scheduleNextSeqEvent(after: ContinuousClock.now, generation: generation)
    }

    /// 再生中のパターン差し替え（現在のループ位置は先頭へ戻す）。
    func replaceSeqEvents(_ events: [SeqPlaybackEvent]) {
        guard isSeqPlaying else { return }
        startSeq(events: events)
    }

    /// 再生位置は維持したまま、次のイベントから鳴らす内容を差し替える。
    func updateSeqEvents(_ events: [SeqPlaybackEvent]) {
        guard isSeqPlaying else { return }
        let events = normalizedSeqEvents(events)
        let rawCount = events.reduce(0) { $0 + $1.stepLength }
        seqEvents = events
        seqRawStepCount = rawCount
        seqEventIndex = min(seqEventIndex, events.count - 1)
    }

    /// 再生中のスロット差し替え（次の 4 拍子境界で反映）。
    func queueSeqEvents(_ events: [SeqPlaybackEvent]) {
        guard isSeqPlaying else { return }
        pendingSeqEventChange = PendingSeqEventChange(events: events)
    }

    func stopSeq() {
        seqGeneration += 1
        isSeqPlaying = false
        seqCurrentRawStep = nil
        seqBarRawStep = 0
        pendingSeqEventChange = nil
        stopSeqNotes()
    }

    private func scheduleNextSeqEvent(after reference: ContinuousClock.Instant, generation: Int) {
        guard seqEvents.indices.contains(seqEventIndex) else { return }
        let currentLength = seqEvents[seqEventIndex].stepLength
        scheduleSeqRawStepTicks(
            after: reference,
            startRawStep: seqBarRawStep,
            stepLength: currentLength,
            generation: generation
        )
        let deadline = reference.advanced(by: .seconds(stepInterval() * Double(currentLength)))
        Task.detached(priority: .userInitiated) { [weak self] in
            try? await Task.sleep(until: deadline, clock: .continuous)
            await MainActor.run {
                guard let self, generation == self.seqGeneration else { return }
                self.advanceSeq(by: currentLength)
                guard self.isSeqPlaying else { return }
                self.fireSeqEvent()
                self.scheduleNextSeqEvent(after: deadline, generation: generation)
            }
        }
    }

    private func scheduleSeqRawStepTicks(
        after reference: ContinuousClock.Instant,
        startRawStep: Int,
        stepLength: Int,
        generation: Int
    ) {
        guard stepLength > 1 else { return }
        let interval = stepInterval()
        for offset in 1 ..< stepLength {
            let deadline = reference.advanced(by: .seconds(interval * Double(offset)))
            Task.detached(priority: .userInitiated) { [weak self] in
                try? await Task.sleep(until: deadline, clock: .continuous)
                await MainActor.run {
                    guard let self,
                          generation == self.seqGeneration,
                          self.isSeqPlaying
                    else { return }
                    self.seqCurrentRawStep = (startRawStep + offset) % SeqPatternSlot.maxStepCount
                }
            }
        }
    }

    private func advanceSeq(by rawSteps: Int) {
        guard !seqEvents.isEmpty else { return }
        seqBarRawStep = (seqBarRawStep + rawSteps) % SeqPatternSlot.maxStepCount
        if seqBarRawStep == 0, applyPendingSeqEventChangeIfNeeded() {
            return
        }
        seqEventIndex = (seqEventIndex + 1) % seqEvents.count
        let rawPosition = seqEvents.prefix(seqEventIndex).reduce(0) { $0 + $1.stepLength }
        seqCurrentRawStep = rawPosition
    }

    @discardableResult
    private func applyPendingSeqEventChangeIfNeeded() -> Bool {
        guard let pending = pendingSeqEventChange else { return false }
        pendingSeqEventChange = nil
        stopSeqNotes()

        let events = normalizedSeqEvents(pending.events)
        let rawCount = events.reduce(0) { $0 + $1.stepLength }

        seqEvents = events
        seqRawStepCount = rawCount
        seqEventIndex = 0
        seqCurrentRawStep = 0
        return true
    }

    private func normalizedSeqEvents(_ events: [SeqPlaybackEvent]) -> [SeqPlaybackEvent] {
        events.isEmpty ? SeqPlaybackEvent.silentLoop : events
    }

    private func fireSeqEvent() {
        guard seqEvents.indices.contains(seqEventIndex) else { return }
        let event = seqEvents[seqEventIndex]
        if seqEventIndex == 0 {
            seqCurrentRawStep = 0
        }
        guard !event.notes.isEmpty else { return }

        let interval = stepInterval()
        let duration = max(0.01, interval * (Double(event.stepLength - 1) + seqGate()))
        playGatedNotes(event.notes, duration: duration, generation: seqGeneration, isRiff: false)
    }

    private func stopSeqNotes() {
        for note in Array(soundingSeqNotes.keys) {
            releaseAll(note: note, counts: &soundingSeqNotes)
        }
    }

    // MARK: - 共通発音

    /// 同じノートのゲートが重なったときに早すぎる Note Off を出さないための計数。
    private var soundingRiffNotes: [UInt8: Int] = [:]
    private var soundingSeqNotes: [UInt8: Int] = [:]

    func stopAll() {
        stopRiff()
        stopSeq()
    }

    private func playGatedNotes(
        _ notes: [UInt8],
        duration: TimeInterval,
        generation: Int,
        isRiff: Bool
    ) {
        var seenNotes = Set<UInt8>()
        let uniqueNotes = notes.filter { seenNotes.insert($0).inserted }
        guard !uniqueNotes.isEmpty else { return }

        notesOn(uniqueNotes)
        for note in uniqueNotes {
            if isRiff {
                soundingRiffNotes[note, default: 0] += 1
            } else {
                soundingSeqNotes[note, default: 0] += 1
            }
        }

        Task.detached(priority: .userInitiated) { [weak self, notes = uniqueNotes, duration, generation, isRiff] in
            try? await Task.sleep(for: .seconds(duration))
            await MainActor.run {
                guard let self else { return }
                let stillRunning = isRiff ? generation == self.riffGeneration : generation == self.seqGeneration
                guard stillRunning else { return }
                self.releaseNotes(notes, isRiff: isRiff)
            }
        }
    }

    private func releaseNotes(_ notes: [UInt8], isRiff: Bool) {
        var notesToRelease: [UInt8] = []
        notesToRelease.reserveCapacity(notes.count)

        for note in notes {
            if isRiff {
                guard let count = soundingRiffNotes[note], count > 0 else { continue }
                soundingRiffNotes[note] = count == 1 ? nil : count - 1
            } else {
                guard let count = soundingSeqNotes[note], count > 0 else { continue }
                soundingSeqNotes[note] = count == 1 ? nil : count - 1
            }
            notesToRelease.append(note)
        }

        guard !notesToRelease.isEmpty else { return }
        notesOff(notesToRelease)
    }

    private func releaseAll(note: UInt8, counts: inout [UInt8: Int]) {
        guard let count = counts[note], count > 0 else { return }
        counts[note] = nil
        notesOff(Array(repeating: note, count: count))
    }
}
