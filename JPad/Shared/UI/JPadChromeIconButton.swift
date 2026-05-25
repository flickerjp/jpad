import SwiftUI

/// メイン画面下部など、TinyTone 系のアウトライン／オレンジ塗りアイコンボタン（ラベルなし）。
struct JPadChromeIconButton: View {
    var systemImage: String
    var isActive = false
    var isEnabled = true
    var size: CGFloat = 52
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: iconPointSize, weight: .semibold))
                .foregroundStyle(foregroundColor)
                .frame(width: size, height: size)
                .background { backgroundShape }
                .overlay {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(borderColor, lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.42)
        .accessibilityAddTraits(isActive ? [.isSelected] : [])
    }

    private var cornerRadius: CGFloat {
        min(18, size * 0.36)
    }

    private var iconPointSize: CGFloat {
        size * 0.36
    }

    private var foregroundColor: Color {
        if isActive {
            return JPadChromeTheme.buttonLabelFilled
        }
        return JPadChromeTheme.primaryLabel
    }

    private var borderColor: Color {
        if isActive {
            return JPadChromeTheme.accentMid.opacity(0.55)
        }
        return Color.white.opacity(0.85)
    }

    @ViewBuilder
    private var backgroundShape: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        if isActive {
            shape.fill(JPadChromeTheme.accentGradient)
        } else {
            shape.fill(Color.clear)
        }
    }
}
