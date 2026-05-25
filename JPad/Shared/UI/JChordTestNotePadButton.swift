import SwiftUI

/// 押している間だけ on。設定の TEST NOTE とパッド編集の Note で見た目を共有。
struct JChordTestNotePadButton: View {
    enum Appearance {
        /// メイン画面パッド風（レガシー）
        case mainPad
        /// 設定画面の選択 MIDI 行と同系の渋いオレンジ
        case midiAccent
    }

    let titleKey: String
    let appearance: Appearance
    let isMidiOutputActive: Bool
    let width: CGFloat
    let height: CGFloat
    let cornerRadius: CGFloat
    let onPressChanged: (Bool) -> Void

    init(
        titleKey: String = "settings.test_note",
        appearance: Appearance = .midiAccent,
        isMidiOutputActive: Bool = false,
        width: CGFloat,
        height: CGFloat,
        cornerRadius: CGFloat? = nil,
        onPressChanged: @escaping (Bool) -> Void
    ) {
        self.titleKey = titleKey
        self.appearance = appearance
        self.isMidiOutputActive = isMidiOutputActive
        self.width = width
        self.height = height
        self.cornerRadius = cornerRadius ?? max(12, width * 0.16)
        self.onPressChanged = onPressChanged
    }

    @State private var isPressed = false

    private var padShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    }

    var body: some View {
        Text(L10n.string(titleKey))
            .font(.system(size: min(fontSize, height * 0.42), weight: .heavy))
            .foregroundStyle(foregroundColor)
            .frame(width: width, height: height)
            .background(fill, in: padShape)
            .overlay(padShape.strokeBorder(borderColor, lineWidth: isPressed ? 2 : 1.25))
            .contentShape(padShape)
            .gesture(dragGesture)
            .onDisappear {
                releaseIfNeeded()
            }
    }

    private var fontSize: CGFloat {
        switch appearance {
        case .mainPad:
            return 18
        case .midiAccent:
            return 15
        }
    }

    private var usesMidiAccentIdle: Bool {
        appearance == .midiAccent && isMidiOutputActive
    }

    private var foregroundColor: Color {
        if isPressed {
            return .white.opacity(0.96)
        }
        if usesMidiAccentIdle {
            return JChordTheme.midiDeviceSelectedForeground
        }
        return JChordTheme.text
    }

    private var fill: some ShapeStyle {
        if isPressed {
            return AnyShapeStyle(JChordTheme.padActiveBackground)
        }
        if usesMidiAccentIdle {
            return AnyShapeStyle(JChordTheme.midiDeviceSelectedBackground)
        }
        return AnyShapeStyle(JChordTheme.padIdleBackground)
    }

    private var borderColor: Color {
        if isPressed {
            return Color.white.opacity(0.28)
        }
        if usesMidiAccentIdle {
            return JChordTheme.midiDeviceSelectedBorder
        }
        return JChordTheme.padBorder
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { _ in
                guard !isPressed else { return }
                isPressed = true
                onPressChanged(true)
            }
            .onEnded { _ in
                releaseIfNeeded()
            }
    }

    private func releaseIfNeeded() {
        guard isPressed else { return }
        isPressed = false
        onPressChanged(false)
    }
}
