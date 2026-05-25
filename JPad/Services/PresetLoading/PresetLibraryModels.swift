import Foundation

enum PresetSlotOrigin: String, Codable {
  case seed
  case user
  case store
}

struct UserPresetSlotEntry: Codable, Identifiable, Equatable {
  let id: String
  var setName: String
  var savedAt: Date
  var seedTemplateID: String?
  var storeCatalogID: String?
  var origin: PresetSlotOrigin

  enum CodingKeys: String, CodingKey {
    case id, setName, savedAt, seedTemplateID, storeCatalogID, origin
  }

  init(
    id: String,
    setName: String,
    savedAt: Date,
    seedTemplateID: String?,
    storeCatalogID: String? = nil,
    origin: PresetSlotOrigin
  ) {
    self.id = id
    self.setName = setName
    self.savedAt = savedAt
    self.seedTemplateID = seedTemplateID
    self.storeCatalogID = storeCatalogID
    self.origin = origin
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    id = try container.decode(String.self, forKey: .id)
    setName = try container.decode(String.self, forKey: .setName)
    savedAt = try container.decode(Date.self, forKey: .savedAt)
    seedTemplateID = try container.decodeIfPresent(String.self, forKey: .seedTemplateID)
    storeCatalogID = try container.decodeIfPresent(String.self, forKey: .storeCatalogID)
    origin = try container.decode(PresetSlotOrigin.self, forKey: .origin)
  }
}

struct UserPresetLibraryIndex: Codable {
  var version: Int
  var activePresetID: String?
  var items: [UserPresetSlotEntry]
  /// 初回起動時のバンドル5シードが完了したら true。以降の削除では自動再シードしない。
  var hasCompletedInitialSeed: Bool

  static let currentVersion = 1

  init(
    version: Int = currentVersion,
    activePresetID: String? = nil,
    items: [UserPresetSlotEntry] = [],
    hasCompletedInitialSeed: Bool = false
  ) {
    self.version = version
    self.activePresetID = activePresetID
    self.items = items
    self.hasCompletedInitialSeed = hasCompletedInitialSeed
  }

  enum CodingKeys: String, CodingKey {
    case version, activePresetID, items, hasCompletedInitialSeed
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    version = try container.decodeIfPresent(Int.self, forKey: .version) ?? Self.currentVersion
    activePresetID = try container.decodeIfPresent(String.self, forKey: .activePresetID)
    items = try container.decodeIfPresent([UserPresetSlotEntry].self, forKey: .items) ?? []
    hasCompletedInitialSeed = try container.decodeIfPresent(Bool.self, forKey: .hasCompletedInitialSeed)
      ?? !items.isEmpty
  }
}

struct PresetSlotDocument: Codable {
  static let currentFormatVersion = 2

  let formatVersion: Int
  let savedAt: Date
  let seedTemplateID: String?
  let origin: PresetSlotOrigin
  let preset: Preset

  init(
    preset: Preset,
    seedTemplateID: String?,
    origin: PresetSlotOrigin,
    savedAt: Date = Date()
  ) {
    formatVersion = Self.currentFormatVersion
    self.savedAt = savedAt
    self.seedTemplateID = seedTemplateID
    self.origin = origin
    self.preset = preset
  }
}

enum UserPresetLibraryError: LocalizedError {
  case slotNotFound
  case slotLimitReached(limit: Int)
  case storeImportLimitReached
  case noActiveSlot
  case emptyLibrary
  case proRequired

  var errorDescription: String? {
    switch self {
    case .slotNotFound:
      return "Preset slot not found."
    case .slotLimitReached(let limit):
      return "Up to \(limit) sets can be saved."
    case .storeImportLimitReached:
      return "All slots are full. Choose a set to replace with this store import."
    case .noActiveSlot:
      return "No active preset slot."
    case .emptyLibrary:
      return "Preset library is empty."
    case .proRequired:
      return L10n.string("alert.share_requires_pro")
    }
  }
}

enum PresetDateFormatters {
  static func savedAtText(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale.current
    formatter.dateStyle = .medium
    formatter.timeStyle = .short
    return formatter.string(from: date)
  }

  static func publishedDateText(from raw: String) -> String? {
    let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty, let date = parseCatalogDate(trimmed) else { return nil }

    let formatter = DateFormatter()
    formatter.locale = Locale.current
    formatter.dateStyle = .medium
    formatter.timeStyle = .none
    return formatter.string(from: date)
  }

  private static func parseCatalogDate(_ raw: String) -> Date? {
    let dateOnly = DateFormatter()
    dateOnly.calendar = Calendar(identifier: .gregorian)
    dateOnly.locale = Locale(identifier: "en_US_POSIX")
    dateOnly.timeZone = TimeZone(secondsFromGMT: 0)
    dateOnly.dateFormat = "yyyy-MM-dd"
    if let date = dateOnly.date(from: String(raw.prefix(10))) {
      return date
    }

    let isoWithFraction = ISO8601DateFormatter()
    isoWithFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let date = isoWithFraction.date(from: raw) {
      return date
    }

    let iso = ISO8601DateFormatter()
    iso.formatOptions = [.withInternetDateTime]
    return iso.date(from: raw)
  }
}
