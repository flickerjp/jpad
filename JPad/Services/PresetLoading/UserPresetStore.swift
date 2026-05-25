import Foundation

/// One user-owned pad set stored outside the app bundle (survives app updates).
enum UserPresetStore {
    private static let fileName = "user-preset.json"

    static var hasSavedPreset: Bool {
        FileManager.default.fileExists(atPath: fileURL.path)
    }

    static func load() throws -> Preset? {
        guard hasSavedPreset else { return nil }
        let data = try Data(contentsOf: fileURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let document = try decoder.decode(UserPresetDocument.self, from: data)
        return document.preset
    }

    static func loadDefaultBundled() throws -> Preset {
        let loader = PresetLoader()
        guard let first = try loader.bundledCatalogItems().first else {
            throw PresetLoaderError.bundleEmpty
        }
        return try loader.loadPreset(resourceName: first.resourceName)
    }

    /// Saved user file, or the first factory preset in `PresetBundles` when none exists yet.
    static func loadSavedOrDefault() throws -> Preset {
        if let saved = try load() {
            return saved
        }
        return try loadDefaultBundled()
    }

    static func loadSourcePresetID() throws -> String? {
        guard hasSavedPreset else { return nil }
        let data = try Data(contentsOf: fileURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let document = try decoder.decode(UserPresetDocument.self, from: data)
        return document.sourcePresetID
    }

    static func save(_ preset: Preset, sourcePresetID: String?) throws {
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let document = UserPresetDocument(
            savedAt: Date(),
            sourcePresetID: sourcePresetID,
            preset: preset
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(document)
        try data.write(to: fileURL, options: .atomic)
    }

    private static var fileURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base
            .appendingPathComponent("JChord", isDirectory: true)
            .appendingPathComponent(fileName)
    }
}

private struct UserPresetDocument: Codable {
    let savedAt: Date
    let sourcePresetID: String?
    let preset: Preset
}
