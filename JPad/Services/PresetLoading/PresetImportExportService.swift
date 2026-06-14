import Foundation
import UniformTypeIdentifiers

/// 共有（Pro）向けのプリセット JSON エンベロープ。
struct PresetExportEnvelope: Codable {
  static let currentFormatVersion = 3
  static let kind = "preset"

  let formatVersion: Int
  let kind: String
  let exportedAt: Date
  let slotName: String
  let origin: PresetSlotOrigin
  /// RIFF / SEQ 情報を共有 envelope 上にも明示して、IMPORT / EXPORT / AirDrop の往復で保持する。
  let sequencerSettings: PresetSequencerSettings?
  let preset: Preset

  init(slotName: String, origin: PresetSlotOrigin, preset: Preset, exportedAt: Date = Date()) {
    formatVersion = Self.currentFormatVersion
    self.kind = Self.kind
    self.exportedAt = exportedAt
    self.slotName = slotName
    self.origin = origin
    sequencerSettings = preset.sequencerSettings
    self.preset = preset
  }
}

enum PresetImportExportService {
  /// ZIP 内エントリ名と AirDrop 共有用拡張子（`Bossa Nova.jpd`）。
  static let fileExtension = "jpd"
  /// AirDrop 共有用（中身 ZIP・`Bossa Nova.jpd`）。
  static let shareArchiveExtension = "jpd"
  /// Files へ直接保存する JSON エクスポート拡張子。
  static let exportJSONExtension = "json"
  private static let legacyFileSuffixes = [
    ".jpd", ".jch", ".jchord.zip", ".jchord.json", ".jchord", ".json", ".zip",
  ]
  private static let exportFileNamePrefixes = ["TinyRiff.", "TinyTone.", "JPad."]

  static func makeExportEnvelope(slotName: String, origin: PresetSlotOrigin, preset: Preset) -> PresetExportEnvelope {
    PresetExportEnvelope(
      slotName: slotName,
      origin: origin,
      preset: preset
    )
  }

  static func encodeExportEnvelope(_ envelope: PresetExportEnvelope) throws -> Data {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    encoder.dateEncodingStrategy = .iso8601
    return try encoder.encode(envelope)
  }

  static func makeExportJSON(slotName: String, origin: PresetSlotOrigin, preset: Preset) throws -> (fileName: String, data: Data) {
    let envelope = makeExportEnvelope(
      slotName: slotName,
      origin: origin,
      preset: preset
    )
    let data = try encodeExportEnvelope(envelope)
    let fileName = exportJSONFileName(forSlotName: slotName)
    return (fileName, data)
  }

  static func makeExportArchive(slotName: String, origin: PresetSlotOrigin, preset: Preset) throws -> (fileName: String, data: Data) {
    let data = try makeExportJSON(slotName: slotName, origin: origin, preset: preset).data
    let entryName = exportFileName(forSlotName: slotName)
    let archiveName = exportArchiveFileName(forSlotName: slotName)
    let archiveData = PresetShareZipArchive.createZipData(fileData: data, entryName: entryName)
    return (archiveName, archiveData)
  }

  static func makeExportFileURL(slotName: String, origin: PresetSlotOrigin, preset: Preset) throws -> URL {
    let export = try makeExportArchive(slotName: slotName, origin: origin, preset: preset)
    let tempDir = FileManager.default.temporaryDirectory
    let archiveURL = tempDir.appendingPathComponent(export.fileName)
    try export.data.write(to: archiveURL, options: .atomic)
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
    stem = droppingKnownFileNamePrefix(from: stem)
    if stem.isEmpty { stem = "Preset" }
    return "\(stem).\(fileExtension)"
  }

  static func exportArchiveFileName(forSlotName slotName: String) -> String {
    "\(sanitizedExportStem(forSlotName: slotName)).\(shareArchiveExtension)"
  }

  static func exportJSONFileName(forSlotName slotName: String) -> String {
    "\(sanitizedExportStem(forSlotName: slotName)).\(exportJSONExtension)"
  }

  private static func sanitizedExportStem(forSlotName slotName: String) -> String {
    let sanitized = slotName
      .replacingOccurrences(of: "/", with: "-")
      .replacingOccurrences(of: ":", with: "-")
      .trimmingCharacters(in: .whitespacesAndNewlines)
    var stem = sanitized
    stem = droppingKnownFileNamePrefix(from: stem)
    if stem.isEmpty { stem = "Preset" }
    return stem
  }

  private static func droppingKnownFileNamePrefix(from stem: String) -> String {
    for prefix in exportFileNamePrefixes where stem.hasPrefix(prefix) {
      return String(stem.dropFirst(prefix.count))
    }
    return stem
  }

  static func decodeSharedPreset(from data: Data) throws -> Preset {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601

    let envelope = try decoder.decode(PresetExportEnvelope.self, from: data)
    guard envelope.kind == PresetExportEnvelope.kind else {
      throw PresetShareError.unsupportedDocumentKind
    }
    guard let sequencerSettings = envelope.sequencerSettings else {
      return envelope.preset
    }
    return envelope.preset.replacingSequencerSettings(sequencerSettings)
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
