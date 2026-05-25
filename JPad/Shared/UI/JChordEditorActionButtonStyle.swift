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
                    ? AnyShapeStyle(JPadChromeTheme.accentGradient)
                    : AnyShapeStyle(JPadChromeTheme.utilityButtonBackground),
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(
                        primary ? JPadChromeTheme.accentMid.opacity(0.55) : JPadChromeTheme.utilityButtonBorder,
                        lineWidth: 1
                    )
            )
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}
