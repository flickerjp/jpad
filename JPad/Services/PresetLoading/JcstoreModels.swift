import Foundation

struct JcstoreManifest: Codable {
  let version: Int
  let updatedAt: String?
  let baseURL: String?
  let presets: [JcstoreCatalogEntry]

  func presetURL(for entry: JcstoreCatalogEntry) -> URL? {
    guard let path = entry.path, !path.isEmpty else { return nil }
    let base = baseURL ?? JcstoreService.manifestURL.deletingLastPathComponent().absoluteString + "/"
    return URL(string: path, relativeTo: URL(string: base))
  }
}

struct JcstoreCatalogEntry: Codable, Identifiable {
  let id: String
  let title: String
  let description: String?
  /// 公開日（`yyyy-MM-dd` または ISO8601）。表示は日付のみ。
  let publishedAt: String?
  /// リモート取得時のパス。未設定時はバンドル `resourceName` を使う。
  let path: String?
  let resourceName: String?

  var bundledResourceName: String {
    resourceName ?? id
  }

  var publishedDateText: String? {
    guard let publishedAt else { return nil }
    return PresetDateFormatters.publishedDateText(from: publishedAt)
  }
}

enum JcstoreError: LocalizedError {
  case manifestUnavailable
  case catalogEntryNotFound
  case presetNotAllowed
  case invalidHost
  case decodeFailed

  var errorDescription: String? {
    switch self {
    case .manifestUnavailable:
      return "jcstore manifest is unavailable."
    case .catalogEntryNotFound:
      return "Preset is not listed in jcstore."
    case .presetNotAllowed:
      return "This preset cannot be imported."
    case .invalidHost:
      return "Only flicker-jp.com jcstore URLs are allowed."
    case .decodeFailed:
      return "Failed to read jcstore preset."
    }
  }
}
