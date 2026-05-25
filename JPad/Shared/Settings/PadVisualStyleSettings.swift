import Foundation

/// メインパッドの見た目（ダーク = 現行 / パフォーマンス = 5色＋光演出）。内部音源とは独立。
enum PadVisualStyle: String, CaseIterable, Identifiable {
    case dark
    case performance

    var id: String { rawValue }
}

enum PadVisualStyleSettings {
    static let storageKey = "jpad.padVisualStyle"

    static var defaultStyle: PadVisualStyle { .dark }

    /// パフォーマンスモードの待機／タップ演出パラメータ（差し替えて `MainView` へ渡す）。
    static var performanceAnimation: PadPerformanceAnimationConfig { .standard }
}
