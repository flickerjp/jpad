import SwiftUI
import UIKit

enum JChordDeviceTraits {
    /// シート外周の白枠。iPhone（6.5" MAX 含む）ではフルブリードで四隅が切れるため非表示。iPad mini 以上で表示。
    static var showsPopupSheetOuterBorder: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }
}

enum JChordTheme {
    // MARK: - Popup / sheet chrome (TinyTone グレー — レイアウト・サイズは不変)

    static var panel: Color { JPadChromeTheme.panelBackground }
    static var popupPanel: Color { JPadChromeTheme.popupPanelBackground }
    static var surface: Color { JPadChromeTheme.panelBackground.opacity(0.88) }
    static var text: Color { JPadChromeTheme.primaryLabel }
    static var muted: Color { JPadChromeTheme.secondaryLabel }
    static var v11ChipTrayBackground: Color { JPadChromeTheme.chipTrayBackground }
    static var v11NoteChipBackground: Color { JPadChromeTheme.noteChipBackground }
    static var v11UtilityButtonBackground: Color { JPadChromeTheme.utilityButtonBackground }
    static var v11UtilityButtonBorder: Color { JPadChromeTheme.utilityButtonBorder }

    /// 購入・リネーム・STORE 等のシート全面
    static var sheetBackground: LinearGradient { JPadChromeTheme.mainScreenBackground }
    static let padBorder = Color.white.opacity(0.5)
    /// フローティング POPUP 枠（iPad シート外周は従来どおりやや強め）
    static func popupPanelBorderStyle() -> (color: Color, lineWidth: CGFloat) {
        (JPadChromeTheme.popupChromeBorder, 1.5)
    }

    /// シート内 SHARE / IMPORT 等（TinyTone LOAD 枠）
    static var padActionBorder: Color { Color.white.opacity(0.85) }
    static let padActionLockedForeground = Color.white.opacity(0.4)
    static var padActionLockedBackground: Color { JPadChromeTheme.panelBackground }
    static let padPressedBorder = Color.white.opacity(0.5)
    static var track: Color { Color.white.opacity(0.18) }
    static var trackFill: Color { JPadChromeTheme.sliderTrackFill }
    /// UISlider 標準トラック（約 5–6pt）の半分程度
    static let midiSliderTrackHeight: CGFloat = 3

    // レガシー参照用（新規 UI は `JPadChromeTheme` を優先）
    static var accentOrangeTop: Color { JPadChromeTheme.accentLight }
    static var accentOrangeMid: Color { JPadChromeTheme.accentMid }
    static var accentOrangeBottom: Color { JPadChromeTheme.accentDeep }

    static var unlockProminentTint: Color { JPadChromeTheme.accentMid }

    /// 未購入時の有償 UI（LOAD / SAVE / Unlock）
    static let paidFeatureLockedForeground = Color.white.opacity(0.4)
    static let paidFeatureLockedBackground = Color.white.opacity(0.08)
    static let paidFeatureLockedBorder = Color.white.opacity(0.10)

    /// Idle pad (gray gradient — TinyTone 系。FLASH は `PerformancePadPalette` 側を維持)
    static var padIdleBackground: LinearGradient {
        JPadChromeTheme.padIdleBackground
    }

    /// Active / sounding pad (TinyTone オレンジ)
    static var padActiveBackground: LinearGradient {
        JPadChromeTheme.accentGradient
    }

    static var holdButtonActiveBackground: LinearGradient {
        padActiveBackground
    }

    /// 設定シート等: TEST NOTE / MIDI 行の選択（TinyTone オレンジ地）
    static var midiDeviceSelectedBackground: LinearGradient {
        JPadChromeTheme.accentGradient
    }

    /// PAD OUT / KEYBOARD IN の横長行（TEST NOTE と同色）
    static var midiDeviceRowActiveBackground: LinearGradient {
        LinearGradient(
            colors: [
                JPadChromeTheme.accentLight,
                JPadChromeTheme.accentMid,
                JPadChromeTheme.accentDeep,
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    static var midiDeviceSelectedForeground: Color { JPadChromeTheme.buttonLabelFilled }
    static var midiDeviceSelectedSubtitle: Color { JPadChromeTheme.buttonLabelFilled.opacity(0.82) }
    static var midiDeviceSelectedBorder: Color { JPadChromeTheme.accentMid.opacity(0.55) }
    static var midiAccentGlyph: Color { JPadChromeTheme.accentLight }
    /// メイン画面上部: PAD OUT 接続中
    static let midiOutputActiveIndicator = Color(red: 0.36, green: 0.82, blue: 0.48)
    /// OCT SHIFT: ±1 オクターブにノートあり
    static let octaveShiftNearIndicator = midiOutputActiveIndicator
    /// OCT SHIFT: ±2 オクターブにノートあり
    static let octaveShiftFarIndicator = Color(red: 0.95, green: 0.82, blue: 0.22)
    /// メイン画面上部: PAD OUT 未接続
    static let midiOutputInactiveIndicator = JPadChromeTheme.accentMid

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
            .background(JChordTheme.sheetBackground.ignoresSafeArea())
    }
}

/// シート外枠（白枠付き）。`brightPanel` で panel / popupPanel（白 5%）を切り替え。
struct JChordPopupSheetBackground: ViewModifier {
    var cornerRadius: CGFloat = 18
    /// API 互換（色はシート全面で統一）
    var brightPanel: Bool = true

    func body(content: Content) -> some View {
        content
            .background(JPadChromeTheme.appBackground.ignoresSafeArea())
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
