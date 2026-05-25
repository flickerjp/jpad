import SwiftUI

/// 押している間だけ on。NOTE / TEST NOTE 用（ORANGE-A 待機・ORANGE-G 押下）。
struct JChordTestNotePadButton: View {
    enum Appearance {
        /// メイン画面パッド風（レガシー）
        case mainPad
        /// 設定の TEST NOTE（小=compact）
        case midiAccent
        /// ウェルカム NOTE（標準寸法）
        case holdIdle
        /// ウェルカム NOTE（COMPACT・待機 ORANGE-A）
        case welcomeCompact
    }

    let titleKey: String
    let appearance: Appearance
    let isMidiOutputActive: Bool
    var width: CGFloat?
    let height: CGFloat?
    let onPressChanged: (Bool) -> Void

    init(
        titleKey: String = "settings.test_note",
        appearance: Appearance = .midiAccent,
        isMidiOutputActive: Bool = false,
        width: CGFloat? = nil,
        height: CGFloat? = nil,
        onPressChanged: @escaping (Bool) -> Void
    ) {
        self.titleKey = titleKey
        self.appearance = appearance
        self.isMidiOutputActive = isMidiOutputActive
        self.width = width
        self.height = height
        self.onPressChanged = onPressChanged
    }

    @State private var isPressed = false

    private var chromeSize: JPadOrangeChromeStyle {
        switch appearance {
        case .holdIdle:
            return .standard
        case .midiAccent, .welcomeCompact:
            return .compact
        case .mainPad:
            return .standard
        }
    }

    private var metrics: JPadOrangeChromeStyle.Metrics {
        let base = JPadOrangeChromeStyle.metrics(for: chromeSize)
        return JPadOrangeChromeStyle.Metrics(
            height: height ?? base.height,
            fontSize: base.fontSize,
            fontWeight: base.fontWeight,
            cornerRadius: base.cornerRadius,
            horizontalPadding: base.horizontalPadding,
            usesCapsule: base.usesCapsule
        )
    }

    var body: some View {
        Text(L10n.string(titleKey))
            .font(.system(size: metrics.fontSize, weight: metrics.fontWeight))
            .foregroundStyle(foregroundColor)
            .padding(.horizontal, width == nil ? metrics.horizontalPadding : 0)
            .frame(width: width, height: metrics.height)
            .background { chromeBackground }
            .overlay { chromeBorder }
            .contentShape(chromeContentShape)
            .gesture(dragGesture)
            .onDisappear { releaseIfNeeded() }
    }

    @ViewBuilder
    private var chromeBackground: some View {
        if metrics.usesCapsule {
            Capsule(style: .continuous).fill(backgroundFill)
        } else {
            RoundedRectangle(cornerRadius: metrics.cornerRadius, style: .continuous)
                .fill(backgroundFill)
        }
    }

    @ViewBuilder
    private var chromeBorder: some View {
        if metrics.usesCapsule {
            Capsule(style: .continuous).strokeBorder(borderColor, lineWidth: borderWidth)
        } else {
            RoundedRectangle(cornerRadius: metrics.cornerRadius, style: .continuous)
                .strokeBorder(borderColor, lineWidth: borderWidth)
        }
    }

    private var chromeContentShape: AnyShape {
        if metrics.usesCapsule {
            return AnyShape(Capsule(style: .continuous))
        }
        return AnyShape(RoundedRectangle(cornerRadius: metrics.cornerRadius, style: .continuous))
    }

    private var usesOrangeChrome: Bool {
        appearance == .holdIdle
            || appearance == .welcomeCompact
            || (appearance == .midiAccent && isMidiOutputActive)
    }

    private var foregroundColor: Color {
        if appearance == .mainPad {
            return isPressed ? .white.opacity(0.96) : JChordTheme.text
        }
        if isPressed {
            return JPadOrangeChromeStyle.foreground(isPressed: true, isAccentOn: false)
        }
        if usesOrangeChrome {
            return JPadOrangeChromeStyle.foreground(isPressed: false, isAccentOn: false)
        }
        return JChordTheme.text
    }

    private var backgroundFill: AnyShapeStyle {
        if appearance == .mainPad {
            if isPressed { return AnyShapeStyle(JChordTheme.padActiveBackground) }
            return AnyShapeStyle(JChordTheme.padIdleBackground)
        }
        if isPressed {
            return JPadOrangeChromeStyle.background(isPressed: true, isAccentOn: false)
        }
        if usesOrangeChrome {
            return JPadOrangeChromeStyle.background(isPressed: false, isAccentOn: false)
        }
        return AnyShapeStyle(JChordTheme.padIdleBackground)
    }

    private var borderColor: Color {
        if appearance == .mainPad {
            return isPressed ? Color.white.opacity(0.28) : JChordTheme.padBorder
        }
        if isPressed {
            return JPadOrangeChromeStyle.border(isPressed: true, isAccentOn: false)
        }
        if usesOrangeChrome {
            return JPadOrangeChromeStyle.border(isPressed: false, isAccentOn: false)
        }
        return JChordTheme.padBorder
    }

    private var borderWidth: CGFloat {
        isPressed ? 1.5 : 1
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { _ in
                guard !isPressed else { return }
                isPressed = true
                onPressChanged(true)
            }
            .onEnded { _ in releaseIfNeeded() }
    }

    private func releaseIfNeeded() {
        guard isPressed else { return }
        isPressed = false
        onPressChanged(false)
    }
}
