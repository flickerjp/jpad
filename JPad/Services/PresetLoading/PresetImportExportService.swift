import Foundation
import UniformTypeIdentifiers

/// 共有（Pro）向けのプリセット JSON エンベロープ。
struct PresetExportEnvelope: Codable {
  static let currentFormatVersion = 2
  static let kind = "preset"

  let formatVersion: Int
  let kind: String
  let exportedAt: Date
  let slotName: String
  let origin: PresetSlotOrigin
  let preset: Preset

  init(slotName: String, origin: PresetSlotOrigin, preset: Preset, exportedAt: Date = Date()) {
    formatVersion = Self.currentFormatVersion
    self.kind = Self.kind
    self.exportedAt = exportedAt
    self.slotName = slotName
    self.origin = origin
    self.preset = preset
  }
}

enum PresetImportExportService {
  /// ZIP 内のプリセット本体（`Bossa Nova.jpd`）。
  static let fileExtension = "jpd"
  /// AirDrop 共有用（中身 ZIP・`Bossa Nova.jpd`）。
  static let shareArchiveExtension = "jpd"
  private static let legacyFileSuffixes = [
    ".jpd", ".jch", ".jchord.zip", ".jchord.json", ".jchord", ".json", ".zip",
  ]
  private static let legacyFileNamePrefix = "JPad."

  static func makeExportFileURL(slotName: String, origin: PresetSlotOrigin, preset: Preset) throws -> URL {
    let envelope = PresetExportEnvelope(
      slotName: slotName,
      origin: origin,
      preset: preset
    )
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    encoder.dateEncodingStrategy = .iso8601
    let data = try encoder.encode(envelope)

    let entryName = exportFileName(forSlotName: slotName)
    let tempDir = FileManager.default.temporaryDirectory
    let payloadURL = tempDir.appendingPathComponent(entryName)
    try data.write(to: payloadURL, options: .atomic)

    let archiveName = exportArchiveFileName(forSlotName: slotName)
    let archiveURL = tempDir.appendingPathComponent(archiveName)
    try PresetShareZipArchive.createZip(archiveURL: archiveURL, fileURL: payloadURL, entryName: entryName)
    try? FileManager.default.removeItem(at: payloadURL)
    return archiveURL
  }

  static func loadImportData(from url: URL) throws -> Data {
    if isZipArchive(url) {
      return try PresetShareZipArchive.firstEntryData(from: url)
    }
    return try Data(contentsOf: url)
  }

  private static func isZipArchive(_ url: URL) -> Bool {
    let name = url.lastPathComponent.lowercased()
    if name.hasSuffix(".\(shareArchiveExtension)") { return true }
    if name.hasSuffix(".jch") { return true }
    return name.hasSuffix(".jchord.zip") || name.hasSuffix(".zip")
      || url.pathExtension.lowercased() == "zip"
  }

  static func isJChordPresetFile(_ url: URL) -> Bool {
    if hasRecognizedFileName(url) {
      return containsPresetEnvelope(at: url)
    }
    if let values = try? url.resourceValues(forKeys: [.contentTypeKey]),
       let contentType = values.contentType,
       contentType == .jchordPreset || contentType.conforms(to: .jchordPreset)
    {
      return containsPresetEnvelope(at: url)
    }
    return false
  }

  private static func containsPresetEnvelope(at url: URL) -> Bool {
    guard let data = try? loadImportData(from: url), data.count >= 32 else { return false }
    let prefix = String(decoding: data.prefix(1024), as: UTF8.self)
    return prefix.contains("\"kind\"") && prefix.contains(PresetExportEnvelope.kind)
  }

  static func hasRecognizedFileName(_ url: URL) -> Bool {
    let name = url.lastPathComponent.lowercased()
    return legacyFileSuffixes.contains { name.hasSuffix($0) }
  }

  static func exportFileName(forSlotName slotName: String) -> String {
    let sanitized = slotName
      .replacingOccurrences(of: "/", with: "-")
      .replacingOccurrences(of: ":", with: "-")
      .trimmingCharacters(in: .whitespacesAndNewlines)
    var stem = sanitized
    if stem.hasPrefix(legacyFileNamePrefix) {
      stem = String(stem.dropFirst(legacyFileNamePrefix.count))
    }
    if stem.isEmpty { stem = "Preset" }
    return "\(stem).\(fileExtension)"
  }

  static func exportArchiveFileName(forSlotName slotName: String) -> String {
    let sanitized = slotName
      .replacingOccurrences(of: "/", with: "-")
      .replacingOccurrences(of: ":", with: "-")
      .trimmingCharacters(in: .whitespacesAndNewlines)
    var stem = sanitized
    if stem.hasPrefix(legacyFileNamePrefix) {
      stem = String(stem.dropFirst(legacyFileNamePrefix.count))
    }
    if stem.isEmpty { stem = "Preset" }
    return "\(stem).\(shareArchiveExtension)"
  }

  static func decodeSharedPreset(from data: Data) throws -> Preset {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601

    let envelope = try decoder.decode(PresetExportEnvelope.self, from: data)
    guard envelope.kind == PresetExportEnvelope.kind else {
      throw PresetShareError.unsupportedDocumentKind
    }
    return envelope.preset
  }
}

enum PresetShareError: LocalizedError {
  case proRequired
  case unsupportedDocumentKind

  var errorDescription: String? {
    switch self {
    case .proRequired:
      return L10n.string("alert.share_requires_pro")
    case .unsupportedDocumentKind:
      return L10n.string("alert.import_unsupported_file")
    }
  }
}
