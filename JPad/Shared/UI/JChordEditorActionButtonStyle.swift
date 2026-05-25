import SwiftUI

struct JChordEditorActionButtonStyle: ButtonStyle {
    let primary: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .heavy))
            .foregroundStyle(JChordTheme.text)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                primary
                    ? AnyShapeStyle(JChordTheme.padBackground)
                    : AnyShapeStyle(Color.white.opacity(0.05)),
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.white.opacity(primary ? 0.5 : 0.08), lineWidth: 1)
            )
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}
