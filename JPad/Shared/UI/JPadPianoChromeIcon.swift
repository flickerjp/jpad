import SwiftUI

/// KEY INPUT 試聴ボタン／EDIT 時パッド右上の鍵盤アイコン共通配色。
enum JPadPianoChromeStyle {
    static func cornerRadius(for size: CGFloat) -> CGFloat {
        let standard = JPadOrangeChromeStyle.metrics(for: .standard)
        if abs(size - standard.height) < 4 {
            return standard.cornerRadius
        }
        return max(10, size * (standard.cornerRadius / standard.height))
    }

    static let editPadGlyphColor = Color.white.opacity(0.7)

    static func foreground(isPressed: Bool, isEnabled: Bool, editMode: Bool = false) -> Color {
        if isPressed {
            return JPadOrangeChromeStyle.foreground(isPressed: true, isAccentOn: false)
        }
        if editMode {
            return editPadGlyphColor
        }
        if isEnabled {
            return JPadOrangeChromeStyle.foreground(isPressed: false, isAccentOn: false)
        }
        return JPadChromeTheme.secondaryLabel.opacity(0.45)
    }

    static func background(isPressed: Bool, isEnabled: Bool) -> AnyShapeStyle {
        if isPressed {
            return JPadOrangeChromeStyle.background(isPressed: true, isAccentOn: false)
        }
        if isEnabled {
            return JPadOrangeChromeStyle.background(isPressed: false, isAccentOn: false)
        }
        return AnyShapeStyle(Color.clear)
    }

    static func border(isPressed: Bool, isEnabled: Bool) -> Color {
        if isPressed {
            return JPadOrangeChromeStyle.border(isPressed: true, isAccentOn: false)
        }
        if isEnabled {
            return JPadOrangeChromeStyle.border(isPressed: false, isAccentOn: false)
        }
        return Color.clear
    }

    static var borderWidthPressed: CGFloat { 2 }
    static var borderWidthIdle: CGFloat { 1 }
}

struct JPadPianoChromeIcon: View {
    let size: CGFloat
    var isPressed: Bool
    var isEnabled: Bool
    var editMode = false

    var body: some View {
        let shape = RoundedRectangle(
            cornerRadius: JPadPianoChromeStyle.cornerRadius(for: size),
            style: .continuous
        )
        Image(systemName: PadView.editNotesIconName)
            .font(.system(size: size * 0.52, weight: .semibold))
            .foregroundStyle(
                JPadPianoChromeStyle.foreground(
                    isPressed: isPressed,
                    isEnabled: isEnabled,
                    editMode: editMode
                )
            )
            .frame(width: size, height: size)
            .background(
                JPadPianoChromeStyle.background(isPressed: isPressed, isEnabled: isEnabled),
                in: shape
            )
            .overlay(
                shape.strokeBorder(
                    JPadPianoChromeStyle.border(isPressed: isPressed, isEnabled: isEnabled),
                    lineWidth: isPressed
                        ? JPadPianoChromeStyle.borderWidthPressed
                        : JPadPianoChromeStyle.borderWidthIdle
                )
            )
    }
}
