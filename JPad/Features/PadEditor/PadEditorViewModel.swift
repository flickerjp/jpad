import Foundation

enum PadKeyInputEditorMode: String {
    case add
    case delete
}

/// v1.1 キー入力ポップアップ内の画面
enum PadEditorV11PopupScreen: String {
    case notes
    case label
}

@MainActor
final class PadEditorViewModel: ObservableObject {
    @Published var label: String
    @Published var root: String
    @Published var notes: [UInt8]
    @Published var isShowingNotesEditor = false
    @Published var editingNotes: [UInt8] = []
    /// JSON の `bassNotes` / `chordNotes` を編集用に保持
    @Published var editingBassNotes: [UInt8] = []
    @Published var editingChordNotes: [UInt8] = []
    @Published var selectedNotesForDeletion: Set<UInt8> = []

    /// UI 1.1 キー入力ポップアップ用（v1 では未使用）
    @Published var editingOctave: Int = 2
    var keyInputEditorMode: PadKeyInputEditorMode = .add
    @Published var selectedKeyRoot: String?
    @Published var v11PopupScreen: PadEditorV11PopupScreen = .notes

    let padIndex: Int
    let padDisplayName: String

    let originalPad: PadDefinition
    private let onSave: (PadDefinition) -> Void

    var candidates: [String] {
        guard !isShowingNotesEditor else { return labelEditorCandidates }
        return ChordCandidateRecognizer.candidates(forRoot: root, notes: notes)
    }

    /// v1.1 ラベル編集画面用（ROOT=bass + VOICING=chordNotes から候補算出）
    var labelEditorCandidates: [String] {
        let voicing = v11VoicingNotesForCandidates
        guard !voicing.isEmpty else { return [] }
        return ChordCandidateRecognizer.candidates(forRoot: v11RootForCandidates, notes: voicing)
    }

    init(pad: PadDefinition, onSave: @escaping (PadDefinition) -> Void) {
        self.originalPad = pad
        self.padIndex = pad.index
        self.padDisplayName = "PAD \(String(format: "%02d", pad.index + 1))"
        self.onSave = onSave
        label = pad.label
        root = RootPitch.normalize(pad.displayName.isEmpty ? pad.name : pad.displayName)
        notes = Array(Set(pad.bassNotes + pad.chordNotes)).sorted()
    }

    func updateLabel(_ text: String) {
        label = text
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func applyCandidate(_ candidate: String) {
        label = candidate
        if let parsed = ChordLabel.parsedRoot(from: candidate) {
            root = parsed
        }
    }

    func selectRoot(_ newRoot: String) {
        let normalized = RootPitch.normalize(newRoot)
        root = normalized
        label = ChordLabel.replacingRoot(in: label, with: normalized)
    }

    func beginNotesEditor() {
        loadEditingNotesFromPreset()
        selectedNotesForDeletion = []
        keyInputEditorMode = .add
        v11PopupScreen = .notes
        applyV11StateFromPresetBassNotes()
        isShowingNotesEditor = true
    }

    func showV11LabelEditor() {
        syncEditingNotesFromSplit()
        if let parsed = ChordLabel.parsedRoot(from: label) {
            root = parsed
        }
        v11PopupScreen = .label
    }

    /// LABEL から NOTES（12 鍵）へ戻ったとき、表示 OCT をボイシング最多ゾーンに合わせる
    func showV11NotesInput() {
        v11PopupScreen = .notes
        applyV11PreferredOctaveForVoicing()
    }

    func clearLabelForV11() {
        label = ""
    }

    func cancelNotesEditor() {
        v11PopupScreen = .notes
        isShowingNotesEditor = false
        loadEditingNotesFromPreset()
        selectedNotesForDeletion = []
        selectedKeyRoot = nil
        keyInputEditorMode = .add
    }

    /// ポップアップを閉じ、`notes` を同期。`editingBassNotes` / `editingChordNotes` は保持（SET 保存用）。
    func commitNotesEditor() {
        syncEditingNotesFromSplit()
        notes = editingNotes
        isShowingNotesEditor = false
        selectedNotesForDeletion = []
        v11PopupScreen = .notes
    }

    func loadEditingNotesFromPreset() {
        editingBassNotes = originalPad.bassNotes.sorted()
        editingChordNotes = originalPad.chordNotes.sorted()
        syncEditingNotesFromSplit()
    }

    func syncEditingNotesFromSplit() {
        editingNotes = Array(Set(editingBassNotes + editingChordNotes)).sorted()
    }

    func appendEditingNote(_ midiNote: UInt8) {
        appendEditingNotes([midiNote])
    }

    /// MIDI 入力。v1.1 は 60 以下最低音→ルート＋他を chord。v1 は 60 未満→bass / 以上→chord。
    func appendEditingNotes(_ midiNotes: [UInt8]) {
        guard !midiNotes.isEmpty else { return }
        if PadEditorUIVersion.current == .v11 {
            appendMidiNotesToChordKeys(midiNotes)
            return
        }
        var bass = Set(editingBassNotes)
        var chord = Set(editingChordNotes)
        for note in midiNotes where note <= 127 {
            if note < 60 {
                bass.insert(note)
            } else {
                chord.insert(note)
            }
        }
        editingBassNotes = bass.sorted()
        editingChordNotes = chord.sorted()
        syncEditingNotesFromSplit()
    }

    /// 1回目: 削除候補に追加、2回目（囲み状態）: そのノートを削除
    func handleNoteChipTap(_ note: UInt8) {
        if selectedNotesForDeletion.contains(note) {
            deleteEditingNote(note)
        } else {
            selectedNotesForDeletion.insert(note)
        }
    }

    func deleteEditingNote(_ note: UInt8) {
        editingBassNotes.removeAll { $0 == note }
        editingChordNotes.removeAll { $0 == note }
        selectedNotesForDeletion.remove(note)
        syncEditingNotesFromSplit()
    }

    func clearNoteSelection() {
        selectedNotesForDeletion = []
    }

    func isNoteMarkedForDeletion(_ note: UInt8) -> Bool {
        selectedNotesForDeletion.contains(note)
    }

    /// 右端 ×: 選択中があれば選択分をすべて削除。未選択なら全削除。
    func performEditorClear() {
        guard !selectedNotesForDeletion.isEmpty else {
            editingBassNotes = []
            editingChordNotes = []
            editingNotes = []
            return
        }
        editingBassNotes.removeAll { selectedNotesForDeletion.contains($0) }
        editingChordNotes.removeAll { selectedNotesForDeletion.contains($0) }
        selectedNotesForDeletion = []
        syncEditingNotesFromSplit()
    }

    func draftPad(using noteList: [UInt8]) -> PadDefinition {
        if PadEditorUIVersion.current == .v11 {
            return draftPadFromEditing()
        }
        return PadDefinition(
            index: originalPad.index,
            name: root,
            displayName: root,
            label: label.isEmpty ? root : label,
            role: originalPad.role,
            chordNotes: editingChordNotes.isEmpty ? noteList.filter { $0 >= 60 } : editingChordNotes,
            bassNotes: editingBassNotes.isEmpty ? noteList.filter { $0 < 60 } : editingBassNotes,
            playbackMode: originalPad.playbackMode,
            arpeggioPattern: originalPad.arpeggioPattern
        )
    }

    /// SET 保存用（`bassNotes` / `chordNotes` を JSON 構造どおり反映）
    func draftPadFromEditing() -> PadDefinition {
        PadDefinition(
            index: originalPad.index,
            name: root,
            displayName: root,
            label: label.isEmpty ? root : label,
            role: originalPad.role,
            chordNotes: editingChordNotes,
            bassNotes: editingBassNotes,
            playbackMode: originalPad.playbackMode,
            arpeggioPattern: originalPad.arpeggioPattern
        )
    }

    func save() {
        syncEditingNotesFromSplit()
        onSave(draftPadFromEditing())
    }
}
