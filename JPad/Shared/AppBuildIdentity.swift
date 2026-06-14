import Foundation

/// 実機で「今のビルドか」を確認するための識別子（Settings フッターに表示）。
enum AppBuildIdentity {
    /// PAD 横画面ブースト・ポップアップ枠の修正世代。表示が変わればこのビルドが動いている。
    static let layoutRevision = "perf-pads-v1"

    /// 設定フッターのクレジット（マルシー表示）
    static let settingsCreditMarqueeText = "TinyRiff © FLICKER PRODUCT, Tokyo Japan"

    static var settingsFooterLine: String {
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        let marketing = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        return "TinyRiff \(marketing) (\(build)) · \(layoutRevision)"
    }
}
