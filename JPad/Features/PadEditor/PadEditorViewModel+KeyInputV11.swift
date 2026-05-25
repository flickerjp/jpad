import Foundation

// MARK: - NOTE INPUT: ROOT 表示の基準
//
// | 場所 | データ源 | 意味 |
// |------|----------|------|
// | ROOT 右テキスト | `editingBassNotes` の最低音のピッチクラス | **確定したベース（bass）**。オクターブ番号は出さない。空なら非表示 |
// | 12 鍵・渋オレンジ | 現在 OCT の `bassNotes` ∪ `chordNotes` | そのゾーンに登録済みの音（ベースもボイシングも同じ見た目） |
// | 12 鍵・選択枠 | `selectedKeyRoot` | **未確定の操作対象**（ADD / DEL / ROOT ボタン用）。保存 bass とは別 |
// | 12 鍵・明るいオレンジ | 鍵を押している間の試聴 | `soundingRoot`（MIDI OUT 試聴） |
//
// ここでは出さない: `root` プロパティ・`label` のコード名・他 OCT の音。
// CANDIDATES（ラベル画面）のルート推論は `v11RootForCandidates`（bass → label → root）。

extension PadEditorViewModel {
    static let keyInputOctaveMin = 0
    static let keyInputOctaveMax = 9

    /// 12 鍵ラベルと一致するルート名
    static func keyboardRootName(forMidiNote note: UInt8) -> String {
        RootPitch.normalize(RootPitch.displayName(forPitchClass: Int(note % 12)))
    }

    func resetKeyInputEditorState() {
        keyInputEditorMode = .add
        applyV11StateFromPresetBassNotes()
    }

    /// ROOT 右: 確定ベース（`bassNotes`）のルート名のみ。複数ある場合は最低音を代表表示。
    var v11BassNotesLabel: String? {
        guard let note = editingBassNotes.min() else { return nil }
        return Self.keyboardRootName(forMidiNote: note)
    }

    /// INPUT NOTE 表示 OCT: `chordNotes` が最も多いキーゾーン（同数なら低い方）
    static func preferredOctaveZoneForVoicing(chordNotes: [UInt8]) -> Int {
        var counts: [Int: Int] = [:]
        for note in chordNotes where isNoteInEditableOctaveZones(note) {
            let zone = octaveZone(forMidiNote: note)
            counts[zone, default: 0] += 1
        }
        guard let maxCount = counts.values.max() else { return 2 }
        return counts
            .filter { $0.value == maxCount }
            .map(\.key)
            .min() ?? 2
    }

    func applyV11PreferredOctaveForVoicing() {
        if editingChordNotes.isEmpty {
            if let bass = editingBassNotes.first {
                editingOctave = Self.octaveZone(forMidiNote: bass)
            } else {
                editingOctave = 2
            }
        } else {
            editingOctave = Self.preferredOctaveZoneForVoicing(chordNotes: editingChordNotes)
        }
        clampEditingOctave()
    }

    /// 12 鍵画面を開いたときだけ: ボイシング最多ゾーンへ OCT を合わせる（ADD/DEL 後は移動しない）
    func applyV11StateFromPresetBassNotes() {
        applyV11PreferredOctaveForVoicing()
        selectedKeyRoot = nil
    }

    static func octaveZone(forMidiNote note: UInt8) -> Int {
        max(PadEditorViewModel.keyInputOctaveMin, min(PadEditorViewModel.keyInputOctaveMax, Int(note) / 12 - 1))
    }

    static func midiNotes(inOctaveZone octave: Int, from notes: [UInt8]) -> [UInt8] {
        let start = (octave + 1) * 12
        let end = start + 11
        return notes.filter { $0 >= start && $0 <= end }.sorted()
    }

    /// 編集 UI のキーゾーン C0…C9 に収まる MIDI ノートか
    static func isNoteInEditableOctaveZones(_ note: UInt8) -> Bool {
        let start = (keyInputOctaveMin + 1) * 12
        let end = min(127, (keyInputOctaveMax + 1) * 12 + 11)
        return Int(note) >= start && Int(note) <= end
    }

    /// オクターブゾーン表示（12 鍵の選択とは無関係）例: C0 … C9
    var octaveZoneLabel: String {
        "C\(editingOctave)"
    }

    func clampEditingOctave() {
        editingOctave = min(Self.keyInputOctaveMax, max(Self.keyInputOctaveMin, editingOctave))
    }

    /// MIDI 入力バッチの最高音が属する OCT を 12 鍵表示に合わせる
    private func applyEditingOctaveForHighestInputNote(_ notes: [UInt8]) {
        guard let highest = notes.max() else { return }
        editingOctave = Self.octaveZone(forMidiNote: highest)
        clampEditingOctave()
    }

    private var allChordInfoNotes: [UInt8] {
        editingBassNotes + editingChordNotes
    }

    func hasChordInfoNotes(inOctaveZone octave: Int) -> Bool {
        guard octave >= Self.keyInputOctaveMin, octave <= Self.keyInputOctaveMax else { return false }
        return !Self.midiNotes(inOctaveZone: octave, from: allChordInfoNotes).isEmpty
    }

    enum OctaveShiftIndicatorState {
        case inactive
        case oneOctaveAway
        case twoOrMoreOctavesAway
    }

    /// `<` 左: 直下 1 oct に音があれば緑。±1 oct になく 2 oct 以上先にのみあれば黄。
    var lowerOctaveShiftIndicator: OctaveShiftIndicatorState {
        if hasChordInfoNotes(inOctaveZone: editingOctave - 1) {
            return .oneOctaveAway
        }
        if hasChordInfoNotes(inOctaveZonesThrough: editingOctave - 2, downTo: Self.keyInputOctaveMin) {
            return .twoOrMoreOctavesAway
        }
        return .inactive
    }

    /// `>` 右: 直上 1 oct に音があれば緑。±1 oct になく 2 oct 以上先にのみあれば黄。
    var upperOctaveShiftIndicator: OctaveShiftIndicatorState {
        if hasChordInfoNotes(inOctaveZone: editingOctave + 1) {
            return .oneOctaveAway
        }
        if hasChordInfoNotes(inOctaveZonesFrom: editingOctave + 2, upTo: Self.keyInputOctaveMax) {
            return .twoOrMoreOctavesAway
        }
        return .inactive
    }

    private func hasChordInfoNotes(inOctaveZonesFrom start: Int, upTo end: Int) -> Bool {
        guard start <= end else { return false }
        for zone in start...end where zone >= Self.keyInputOctaveMin && zone <= Self.keyInputOctaveMax {
            if hasChordInfoNotes(inOctaveZone: zone) { return true }
        }
        return false
    }

    private func hasChordInfoNotes(inOctaveZonesThrough start: Int, downTo end: Int) -> Bool {
        guard start >= end else { return false }
        for zone in stride(from: start, through: end, by: -1) where zone >= Self.keyInputOctaveMin && zone <= Self.keyInputOctaveMax {
            if hasChordInfoNotes(inOctaveZone: zone) { return true }
        }
        return false
    }

    /// 12 鍵の渋オレンジ: 現在 OCT の `bassNotes` + `chordNotes`（操作対象 OCT の登録音のみ）
    var registeredRootsInCurrentOctave: Set<String> {
        let notesInZone = Self.midiNotes(
            inOctaveZone: editingOctave,
            from: editingBassNotes + editingChordNotes
        )
        return Set(notesInZone.map { Self.keyboardRootName(forMidiNote: $0) })
    }

    func midiNote(forRoot root: String) -> UInt8? {
        guard let pitchClass = RootPitch.pitchClass(for: root) else { return nil }
        let midi = (editingOctave + 1) * 12 + pitchClass
        guard midi >= 0, midi <= 127 else { return nil }
        return UInt8(midi)
    }

    func selectKeyRootOnly(_ root: String) {
        selectedKeyRoot = RootPitch.normalize(root)
    }

    func clearKeySelection() {
        selectedKeyRoot = nil
    }

    /// v1.1 MIDI: ≦60 の最低音をルート代理。受信音はすべてキーゾーンのまま `chordNotes`（input key）へ。
    static let midiProxyRootMaxNote: UInt8 = 60

    func appendMidiNotesToChordKeys(_ midiNotes: [UInt8]) {
        guard !midiNotes.isEmpty else { return }
        let validNotes = midiNotes
            .filter { $0 <= 127 && Self.isNoteInEditableOctaveZones($0) }
            .sorted()
        guard !validNotes.isEmpty else { return }

        let proxyRoot = validNotes.filter { $0 <= Self.midiProxyRootMaxNote }.min()
        if let proxyRoot {
            applyBassRootFromMidiNote(proxyRoot)
        }

        var chord = Set(editingChordNotes)
        for note in validNotes {
            chord.insert(note)
        }
        editingChordNotes = chord.sorted()
        applyEditingOctaveForHighestInputNote(validNotes)
        syncEditingNotesFromSplit()
    }

    /// MIDI 60 ルール用: 受信ベース音を `bassNotes` / `root` / `label` に反映
    private func applyBassRootFromMidiNote(_ note: UInt8) {
        editingBassNotes = [note]
        let bassRoot = Self.keyboardRootName(forMidiNote: note)
        root = bassRoot
        if !label.isEmpty {
            label = ChordLabel.replacingRoot(in: label, with: bassRoot)
        }
    }

    /// 最後に選択した 12 鍵を現在 OCT のコード音として登録（ADD 押下）
    func registerSelectedKeyAtCurrentOctave() {
        guard let key = selectedKeyRoot,
              let note = midiNote(forRoot: key) else { return }
        editingChordNotes.removeAll { $0 == note }
        editingChordNotes.append(note)
        editingChordNotes.sort()
        syncEditingNotesFromSplit()
        clearKeySelection()
    }

    /// 最後に選択した 12 鍵を現在 OCT から削除（DEL 押下）→ 鍵選択解除
    func deleteSelectedKeyAtCurrentOctave() {
        guard let key = selectedKeyRoot else { return }
        removeNoteAtCurrentOctave(forRoot: key)
        clearKeySelection()
    }

    func removeNoteAtCurrentOctave(forRoot root: String) {
        guard let note = midiNote(forRoot: root) else { return }
        editingBassNotes.removeAll { $0 == note }
        editingChordNotes.removeAll { $0 == note }
        syncEditingNotesFromSplit()
    }

    /// 候補推論用ルート（`bassNotes` → ラベル → `root`）
    var v11RootForCandidates: String {
        if let bass = editingBassNotes.first {
            return Self.keyboardRootName(forMidiNote: bass)
        }
        if let parsed = ChordLabel.parsedRoot(from: label) {
            return parsed
        }
        return root
    }

    /// 候補推論用ボイシング（`chordNotes`。未設定時は bass 以外の編集中ノート）
    var v11VoicingNotesForCandidates: [UInt8] {
        if !editingChordNotes.isEmpty {
            return editingChordNotes
        }
        let bassPitchClasses = Set(editingBassNotes.map { Int($0 % 12) })
        return editingNotes.filter { !bassPitchClasses.contains(Int($0 % 12)) }
    }

    /// ROOT: 選択鍵を現在 OCT の `bassNotes` として反映（SET で保存）
    func assignRootFromSelectedKey() {
        guard let key = selectedKeyRoot,
              let note = midiNote(forRoot: key) else { return }
        applyBassRootFromMidiNote(note)
        syncEditingNotesFromSplit()
    }

    var previewNotesForHold: [UInt8] {
        editingNotes
    }

    func clearAllEditingNotes() {
        editingBassNotes = []
        editingChordNotes = []
        editingNotes = []
        selectedNotesForDeletion = []
        keyInputEditorMode = .add
        clearKeySelection()
        applyV11PreferredOctaveForVoicing()
    }
}
