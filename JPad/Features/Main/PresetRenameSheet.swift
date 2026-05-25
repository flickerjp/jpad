import SwiftUI

/// EDIT 中にプリセット名タップで表示するリネーム用シート。
struct PresetRenameSheet: View {
    @Binding var name: String
    let onSave: () -> Void
    let onCancel: () -> Void

    @FocusState private var isNameFocused: Bool

    var body: some View {
        VStack(spacing: 18) {
            Text(L10n.string("preset.library.rename_title"))
                .font(.headline.weight(.semibold))
                .foregroundStyle(JChordTheme.text)
                .frame(maxWidth: .infinity, alignment: .leading)

            TextField(L10n.string("preset.library.rename_placeholder"), text: $name)
                .font(.body.weight(.semibold))
                .foregroundStyle(JChordTheme.text)
                .textFieldStyle(.plain)
                .submitLabel(.done)
                .focused($isNameFocused)
                .onSubmit(onSave)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
                )

            HStack(spacing: 12) {
                Button(L10n.string("pad_editor.cancel"), action: onCancel)
                    .buttonStyle(JChordEditorActionButtonStyle(primary: false))
                    .frame(maxWidth: .infinity)

                Button(L10n.string("pad_editor.set"), action: onSave)
                    .buttonStyle(JChordEditorActionButtonStyle(primary: true))
                    .frame(maxWidth: .infinity)
            }
            .frame(height: 48)
        }
        .padding(22)
        .jChordScreenBackground()
        .presentationDetents([.height(240)])
        .presentationDragIndicator(.visible)
        .onAppear {
            isNameFocused = true
        }
    }
}
