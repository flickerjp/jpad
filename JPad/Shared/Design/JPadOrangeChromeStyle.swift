import SwiftUI

/// オレンジ系ボタンの共通寸法・色（ウェルカム DARK / NOTE 押下 / OCT+ を基準）。
enum JPadOrangeChromeStyle {
    /// 標準（ウェルカム DARK・NOTE）— 高さ 44・角 14・16pt heavy
    case standard
    /// 小（OCT+ 相当）— 高さ 28・カプセル・12pt heavy
    case compact

    struct Metrics {
        let height: CGFloat
        let fontSize: CGFloat
        let fontWeight: Font.Weight
        let cornerRadius: CGFloat
        let horizontalPadding: CGFloat
        let usesCapsule: Bool
    }

    static func metrics(for size: Self) -> Metrics {
        switch size {
        case .standard:
            return Metrics(
                height: 44,
                fontSize: 16,
                fontWeight: .heavy,
                cornerRadius: 14,
                horizontalPadding: 12,
                usesCapsule: false
            )
        case .compact:
            return Metrics(
                height: 28,
                fontSize: 12,
                fontWeight: .heavy,
                cornerRadius: 14,
                horizontalPadding: 10,
                usesCapsule: true
            )
        }
    }

    // MARK: - Colors (ORANGE-A idle / ORANGE-G pressed)

    static func foreground(isPressed: Bool, isAccentOn: Bool) -> Color {
        if isPressed || isAccentOn {
            return JPadChromeTheme.buttonLabelFilled
        }
        return JPadChromeTheme.primaryLabel
    }

    static func background(isPressed: Bool, isAccentOn: Bool) -> AnyShapeStyle {
        if isPressed || isAccentOn {
            return AnyShapeStyle(JPadChromeTheme.accentGradient)
        }
        return AnyShapeStyle(JPadChromeTheme.buttonIdleFill)
    }

    static func border(isPressed: Bool, isAccentOn: Bool) -> Color {
        if isPressed || isAccentOn {
            return Color.white.opacity(0.28)
        }
        return JPadChromeTheme.buttonIdleBorder
    }

    static func unselectedGreyBackground() -> AnyShapeStyle {
        AnyShapeStyle(JChordTheme.padIdleBackground)
    }

    static func unselectedGreyForeground() -> Color {
        JPadChromeTheme.secondaryLabel.opacity(0.65)
    }

    static func unselectedGreyBorder() -> Color {
        JPadChromeTheme.panelBorder
    }
}
