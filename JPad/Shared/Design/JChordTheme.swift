import SwiftUI
import UIKit

enum JChordDeviceTraits {
    /// シート外周の白枠。iPhone（6.5" MAX 含む）ではフルブリードで四隅が切れるため非表示。iPad mini 以上で表示。
    static var showsPopupSheetOuterBorder: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }
}

enum JChordTheme {
    static let backgroundTop = Color(red: 0.05, green: 0.07, blue: 0.11)
    static let backgroundBottom = Color(red: 0.03, green: 0.04, blue: 0.07)
    static let panel = Color(red: 0.08, green: 0.11, blue: 0.17).opacity(0.96)
    /// v1.1 チップ入力欄（面板よりやや明るいがチップとコントラスト確保）
    static let v11ChipTrayBackground = Color.white.opacity(0.10)
    /// v1.1 未選択チップ
    static let v11NoteChipBackground = Color.white.opacity(0.28)
    /// v1.1 ADD / DEL / CLR
    static let v11UtilityButtonBackground = Color.white.opacity(0.16)
    static let v11UtilityButtonBorder = Color.white.opacity(0.28)

    /// ポップアップ面板（panel を白 5% で明るく）
    static let popupPanel = Color(
        red: 0.08 + 0.05 * 0.92,
        green: 0.11 + 0.05 * 0.89,
        blue: 0.17 + 0.05 * 0.83
    ).opacity(0.98)
    static let surface = Color(red: 0.09, green: 0.12, blue: 0.18).opacity(0.82)
    static let text = Color(red: 0.90, green: 0.92, blue: 0.96)
    static let muted = Color(red: 0.90, green: 0.92, blue: 0.96).opacity(0.72)
    static let padBorder = Color.white.opacity(0.5)
    /// フローティングポップアップ枠（全端末で白 50%・1.5pt）
    static func popupPanelBorderStyle() -> (color: Color, lineWidth: CGFloat) {
        (Color.white.opacity(0.5), 1.5)
    }
    /// RESET / HOLD / SHARE / IMPORT のボタン枠（白 35%）
    static let padActionBorder = Color.white.opacity(0.35)
    /// 未購入時の SHARE / IMPORT（ラベル白 40% 相当）
    static let padActionLockedForeground = Color.white.opacity(0.4)
    static let padActionLockedBackground = Color(red: 0.11, green: 0.13, blue: 0.17)
    static let padPressedBorder = Color.white.opacity(0.5)
    static let track = Color(red: 0.16, green: 0.19, blue: 0.25)
    static let trackFill = Color(red: 0.78, green: 0.81, blue: 0.85)
    /// UISlider 標準トラック（約 5–6pt）の半分程度
    static let midiSliderTrackHeight: CGFloat = 3

    // App icon–inspired warm orange (active pad / HOLD)
    static let accentOrangeTop = Color(red: 0.98, green: 0.62, blue: 0.30)
    static let accentOrangeMid = Color(red: 0.92, green: 0.44, blue: 0.16)
    static let accentOrangeBottom = Color(red: 0.76, green: 0.28, blue: 0.08)

    /// JCue 設定の Unlock / add-plugin オレンジ（購入前の LOAD / SAVE / Unlock 共通ベース）
    static let unlockProminentTint = Color(red: 1.0, green: 0.55, blue: 0.12)

    /// 未購入時の有償 UI（LOAD / SAVE / Unlock）
    static let paidFeatureLockedForeground = Color.white.opacity(0.4)
    static let paidFeatureLockedBackground = Color.white.opacity(0.08)
    static let paidFeatureLockedBorder = Color.white.opacity(0.10)

    static var background: LinearGradient {
        LinearGradient(
            colors: [backgroundTop, backgroundBottom],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    /// Idle pad (gray gradient)
    static var padIdleBackground: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.17, green: 0.20, blue: 0.28),
                Color(red: 0.10, green: 0.13, blue: 0.20),
                Color(red: 0.07, green: 0.09, blue: 0.15)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    /// Active / sounding pad (orange gradient)
    static var padActiveBackground: LinearGradient {
        LinearGradient(
            colors: [accentOrangeTop, accentOrangeMid, accentOrangeBottom],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var holdButtonActiveBackground: LinearGradient {
        padActiveBackground
    }

    /// Selected MIDI device row / TEST NOTE idle / Input Note preview idle.
    /// Warm orange accent that stays visible on dark panels without looking as hot as the active pad state.
    static var midiDeviceSelectedBackground: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.74, green: 0.45, blue: 0.25),
                Color(red: 0.64, green: 0.31, blue: 0.13),
                Color(red: 0.58, green: 0.28, blue: 0.13),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    /// PAD OUT / KEYBOARD IN の横長行専用。TEST NOTE と同じ温度感で、横に伸びても暗く沈みにくい。
    static var midiDeviceRowActiveBackground: LinearGradient {
        LinearGradient(
            stops: [
                .init(color: Color(red: 0.98, green: 0.62, blue: 0.30), location: 0.0),
                .init(color: Color(red: 0.92, green: 0.44, blue: 0.16), location: 0.56),
                .init(color: Color(red: 0.85, green: 0.33, blue: 0.12), location: 1.0),
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    static let midiDeviceSelectedForeground = Color(red: 1.00, green: 0.96, blue: 0.92)
    static let midiDeviceSelectedSubtitle = Color(red: 1.00, green: 0.96, blue: 0.92).opacity(0.79)
    static let midiDeviceSelectedBorder = Color(red: 1.00, green: 0.79, blue: 0.63).opacity(0.54)
    /// Input Note の鍵盤アイコン用。白鍵を見やすくするため、本文よりやや明るいオフホワイト。
    static let midiAccentGlyph = Color(red: 0.98, green: 0.95, blue: 0.91)
    /// メイン画面上部: PAD OUT 接続中
    static let midiOutputActiveIndicator = Color(red: 0.36, green: 0.82, blue: 0.48)
    /// OCT SHIFT: ±1 オクターブにノートあり
    static let octaveShiftNearIndicator = midiOutputActiveIndicator
    /// OCT SHIFT: ±2 オクターブにノートあり
    static let octaveShiftFarIndicator = Color(red: 0.95, green: 0.82, blue: 0.22)
    /// メイン画面上部: PAD OUT 未接続
    static let midiOutputInactiveIndicator = accentOrangeMid

    static var padBackground: LinearGradient { padIdleBackground }

    static var padPressedBackground: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.22, green: 0.25, blue: 0.31),
                Color(red: 0.14, green: 0.16, blue: 0.21)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

struct JChordGentlePulse: ViewModifier {
    let isActive: Bool

    func body(content: Content) -> some View {
        Group {
            if isActive {
                TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
                    let phase = sin(context.date.timeIntervalSinceReferenceDate * 2 * .pi / 1.35)
                    content.opacity(0.78 + 0.22 * (0.5 + 0.5 * phase))
                }
            } else {
                content
            }
        }
    }
}

extension View {
    func jChordGentlePulse(_ isActive: Bool) -> some View {
        modifier(JChordGentlePulse(isActive: isActive))
    }
}

struct JChordScreenBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(JChordTheme.background.ignoresSafeArea())
    }
}

/// シート外枠（白枠付き）。`brightPanel` で panel / popupPanel（白 5%）を切り替え。
struct JChordPopupSheetBackground: ViewModifier {
    var cornerRadius: CGFloat = 18
    var brightPanel: Bool = true

    private var fill: Color {
        brightPanel ? JChordTheme.popupPanel : JChordTheme.panel
    }

    func body(content: Content) -> some View {
        content
            .background(fill.ignoresSafeArea())
    }
}

extension View {
    func jChordScreenBackground() -> some View {
        modifier(JChordScreenBackground())
    }

    func jChordPopupSheetBackground(cornerRadius: CGFloat = 18, brightPanel: Bool = true) -> some View {
        modifier(JChordPopupSheetBackground(cornerRadius: cornerRadius, brightPanel: brightPanel))
    }

    func jChordPopupPanelBorder(cornerRadius: CGFloat) -> some View {
        modifier(JChordPopupPanelBorder(cornerRadius: cornerRadius))
    }

    /// シートの外周（ナビバー含む）に白枠。`jChordPopupPanelBorder` はコンテンツ内側に寄ることがある。
    func jChordSheetOuterBorder(cornerRadius: CGFloat = 18) -> some View {
        modifier(JChordSheetOuterBorder(cornerRadius: cornerRadius))
    }

    /// 明るい面板 + 影 + 白枠（Input Notes などのフローティング POPUP 用）
    func jChordPopupPanelChrome(cornerRadius: CGFloat) -> some View {
        modifier(JChordPopupPanelChrome(cornerRadius: cornerRadius))
    }
}

private struct JChordPopupPanelBorder: ViewModifier {
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        let style = JChordTheme.popupPanelBorderStyle()
        content.overlay {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(style.color, lineWidth: style.lineWidth)
        }
    }
}

private struct JChordSheetOuterBorder: ViewModifier {
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        if JChordDeviceTraits.showsPopupSheetOuterBorder {
            let style = JChordTheme.popupPanelBorderStyle()
            content.overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(style.color, lineWidth: style.lineWidth)
                    .ignoresSafeArea()
            }
        } else {
            content
        }
    }
}

private struct JChordPopupPanelChrome: ViewModifier {
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        content
            .background(JChordTheme.popupPanel, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .shadow(color: .black.opacity(0.32), radius: 20, y: 10)
            .jChordPopupPanelBorder(cornerRadius: cornerRadius)
    }
}
