import SwiftUI

/// PAD 編集画面の Root / Input Notes の開閉状態（アプリ再起動後も維持）。
@MainActor
final class PadEditorSectionExpansionStore: ObservableObject {
    @AppStorage("jpad.pad_editor.root_expanded") var isRootExpanded = false
    @AppStorage("jpad.pad_editor.input_notes_expanded") var isInputNotesExpanded = false
}
