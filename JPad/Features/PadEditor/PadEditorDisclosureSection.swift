import SwiftUI

struct PadEditorDisclosureSection<Content: View>: View {
    let title: String
    @Binding var isExpanded: Bool
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                withAnimation(.easeOut(duration: 0.18)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption.weight(.heavy))
                        .foregroundStyle(JChordTheme.muted)
                        .frame(width: 14, alignment: .center)

                    Text(title)
                        .font(.caption.weight(.heavy))
                        .foregroundStyle(JChordTheme.muted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(title)
            .accessibilityValue(
                isExpanded
                    ? L10n.string("pad_editor.section.expanded.accessibility")
                    : L10n.string("pad_editor.section.collapsed.accessibility")
            )

            if isExpanded {
                content()
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}
