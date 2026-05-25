import Foundation

/// 実装済みだが UI を出さない機能（仕様書 `docs/PRESET_LIBRARY.md` 参照）。
enum PresetFeatureAvailability {
  /// AirDrop 等の共有シート（SHARE）とファイル取り込み（IMPORT）。
  static let isShareImportEnabled = true
}

/// プリセットライブラリの件数・機能ゲート（StoreKit 接続前は AppStorage と連携）。
enum Entitlement {
  case free
  case pro

  init(isProPurchased: Bool) {
    self = isProPurchased ? .pro : .free
  }

  var maxUserPresetSlots: Int {
    switch self {
    case .free: 5
    case .pro: 100
    }
  }

  var canSharePresets: Bool {
    PresetFeatureAvailability.isShareImportEnabled && self == .pro
  }

  /// 方針 B: アクティブ SET の複製（ツールバー doc.on.doc）は Pro のみ。＋空白は Free 可。
  var canDuplicateSlots: Bool {
    self == .pro
  }

  /// jcstore 同時取り込み上限（Phase 2）。`nil` = 無制限。
  var maxConcurrentStoreImports: Int? {
    switch self {
    case .free: 1
    case .pro: nil
    }
  }
}
