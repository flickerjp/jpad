import SwiftUI
import UIKit

/// TinyTone tuner 系のグレー＋オレンジ（コントロール／スライダー／アイコンボタン用）。
/// パフォーマンスモードの FLASH／Launchpad 色は `PerformancePadPalette` のまま変更しない。
enum JPadChromeTheme {
    static let appBackground = Color(white: 0.2)
    static let panelBackground = Color(white: 0.24)
    /// リスト行・フローティング面板（`panel` より一段明るい）
    static let popupPanelBackground = Color(white: 0.26)
    static let panelBorder = Color.white.opacity(0.12)
    /// フローティング POPUP 外枠（iPad シート外周など）
    static let popupChromeBorder = Color.white.opacity(0.5)

    // v1.1 キー入力 POPUP（グレー面板上）
    static let chipTrayBackground = Color.white.opacity(0.10)
    static let noteChipBackground = Color.white.opacity(0.22)
    static let utilityButtonBackground = Color.white.opacity(0.12)
    static let utilityButtonBorder = Color.white.opacity(0.28)

    static let primaryLabel = Color.white.opacity(0.9)
    static let secondaryLabel = Color.white.opacity(0.8)
    static let valueAccent = Color(red: 0.96, green: 0.68, blue: 0.32)

    static let accentLight = Color(red: 0.96, green: 0.68, blue: 0.32)
    static let accentMid = Color(red: 0.86, green: 0.48, blue: 0.10)
    static let accentDeep = Color(red: 0.68, green: 0.34, blue: 0.02)

    static let buttonIdleFill = accentMid.opacity(0.32)
    static let buttonIdleBorder = accentMid
    static let buttonLabelFilled = Color.white.opacity(0.95)

    static let sliderTrackFill = Color.white.opacity(0.4)
    static let sliderMaximumTrack = UIColor.white.withAlphaComponent(0.18)
    static let sliderTrackHeight: CGFloat = 1

    static var accentGradient: LinearGradient {
        LinearGradient(
            colors: [accentLight, accentMid, accentDeep],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    static var thumbGradientColors: [UIColor] {
        [
            UIColor(red: 0.96, green: 0.68, blue: 0.32, alpha: 0.98),
            UIColor(red: 0.86, green: 0.48, blue: 0.10, alpha: 0.96),
            UIColor(red: 0.68, green: 0.34, blue: 0.02, alpha: 1),
        ]
    }

    /// メイン画面（ダーク／非パフォーマンス）背景。
    static var mainScreenBackground: LinearGradient {
        LinearGradient(
            colors: [Color(white: 0.26), Color(white: 0.2)],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    /// 待機 PAD 面（グレー）。FLASH 演出色とは別系統。
    static var padIdleBackground: LinearGradient {
        LinearGradient(
            colors: [Color(white: 0.29), Color(white: 0.18)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}
