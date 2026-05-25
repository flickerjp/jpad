import SwiftUI

/// TinyTone ドック／設定／ウェルカム用ボタン（ORANGE-A 待機・ORANGE-G 押下/オン、白枠 outline）。
struct JPadChromeDockButton: View {
    enum Style {
        /// LOAD / RESET / 閉じる — 白枠・透明地
        case outline
        /// HOLD / SET / Continue — 待機=A、オン/押下=G
        case accentToggle
    }

    let title: String
    var style: Style = .outline
    var isOn = false
    var size: JPadOrangeChromeStyle = .standard
    /// 標準寸法でも両端を完全に丸める（Continue 等）
    var pillShape = false
    /// `size` の既定を上書きするときのみ指定
    var fontSize: CGFloat?
    var width: CGFloat?
    var height: CGFloat?
    let action: () -> Void

    private var metrics: JPadOrangeChromeStyle.Metrics {
        let base = JPadOrangeChromeStyle.metrics(for: size)
        let usesCapsule = pillShape || base.usesCapsule
        return JPadOrangeChromeStyle.Metrics(
            height: height ?? base.height,
            fontSize: fontSize ?? base.fontSize,
            fontWeight: base.fontWeight,
            cornerRadius: base.cornerRadius,
            horizontalPadding: base.horizontalPadding,
            usesCapsule: usesCapsule
        )
    }

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: metrics.fontSize, weight: metrics.fontWeight))
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .foregroundStyle(labelColor)
                .padding(.horizontal, metrics.horizontalPadding)
                .padding(.vertical, 6)
                .frame(maxWidth: width == nil ? nil : .infinity)
                .frame(width: width, height: metrics.height)
                .background { buttonBackground }
                .overlay { buttonBorder }
        }
        .buttonStyle(.plain)
    }

    private var isAccentFilled: Bool {
        style == .accentToggle && isOn
    }

    private var showsBorder: Bool {
        style == .outline || !isAccentFilled
    }

    private var labelColor: Color {
        switch style {
        case .outline:
            return JPadChromeTheme.primaryLabel
        case .accentToggle:
            return JPadOrangeChromeStyle.foreground(isPressed: false, isAccentOn: isAccentFilled)
        }
    }

    @ViewBuilder
    private var buttonBackground: some View {
        if metrics.usesCapsule {
            Capsule(style: .continuous)
                .fill(backgroundStyle)
        } else {
            RoundedRectangle(cornerRadius: metrics.cornerRadius, style: .continuous)
                .fill(backgroundStyle)
        }
    }

    @ViewBuilder
    private var buttonBorder: some View {
        if showsBorder {
            let stroke = borderColor
            let lineWidth: CGFloat = 1
            if metrics.usesCapsule {
                Capsule(style: .continuous)
                    .strokeBorder(stroke, lineWidth: lineWidth)
            } else {
                RoundedRectangle(cornerRadius: metrics.cornerRadius, style: .continuous)
                    .strokeBorder(stroke, lineWidth: lineWidth)
            }
        }
    }

    private var backgroundStyle: AnyShapeStyle {
        switch style {
        case .outline:
            return AnyShapeStyle(Color.clear)
        case .accentToggle:
            return JPadOrangeChromeStyle.background(isPressed: false, isAccentOn: isAccentFilled)
        }
    }

    private var borderColor: Color {
        switch style {
        case .outline:
            return Color.white.opacity(0.85)
        case .accentToggle:
            return JPadOrangeChromeStyle.border(isPressed: false, isAccentOn: isAccentFilled)
        }
    }
}

/// セット切替 ‹ › — 背景・枠なし。
struct JPadSetCycleChevronButton: View {
    let systemImage: String
    var isEnabled = true
    var size: CGFloat = 52
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: size * 0.34, weight: .semibold))
                .foregroundStyle(isEnabled ? JPadChromeTheme.primaryLabel : JPadChromeTheme.secondaryLabel.opacity(0.45))
                .frame(width: size, height: size)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }
}
