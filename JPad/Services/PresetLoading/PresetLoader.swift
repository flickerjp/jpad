import Foundation

struct PresetLoader {
    func loadInitialPreset() throws -> Preset {
        let catalog = try bundledCatalogItems()
        guard let first = catalog.first else {
            throw PresetLoaderError.bundleEmpty
        }
        let storedID = PresetCatalog.normalizedStoredID(Self.storedSelectedPresetID)
        let item = storedID.flatMap { id in catalog.first(where: { $0.id == id || $0.resourceName == id }) } ?? first
        return try loadPreset(resourceName: item.resourceName)
    }

    func loadPreset(resourceName: String) throws -> Preset {
        let data = try loadPresetData(resourceName: resourceName)
        do {
            return try JSONDecoder().decode(Preset.self, from: data)
        } catch let error as DecodingError {
            throw PresetLoaderError.decodingFailed(Self.describe(error))
        } catch let error as MidiNoteParseError {
            throw PresetLoaderError.decodingFailed(error.localizedDescription)
        }
    }

    /// Lists factory presets shipped in `PresetBundles/*.json` (filename order).
    func bundledCatalogItems() throws -> [BundledPresetItem] {
        var items: [BundledPresetItem] = []
        items.reserveCapacity(Self.bundledPresetURLs().count)

        var seenIDs = Set<String>()
        for url in Self.bundledPresetURLs() {
            let resourceName = url.deletingPathExtension().lastPathComponent
            let preset = try loadPreset(resourceName: resourceName)
            let id = preset.id.isEmpty ? resourceName : preset.id
            guard seenIDs.insert(id).inserted else { continue }
            items.append(
                BundledPresetItem(
                    id: id,
                    resourceName: resourceName,
                    title: preset.setName
                )
            )
        }
        return items
    }

    private func loadPresetData(resourceName: String) throws -> Data {
        if let url = Self.locateBundledPresetURL(resourceName: resourceName) {
            return try Data(contentsOf: url)
        }
        throw PresetLoaderError.fileNotFound(resourceName)
    }

    static func bundledPresetURLs() -> [URL] {
        if let folderURL = Bundle.main.resourceURL?.appendingPathComponent("PresetBundles", isDirectory: true),
           let urls = try? FileManager.default.contentsOfDirectory(
               at: folderURL,
               includingPropertiesForKeys: nil,
               options: [.skipsHiddenFiles]
           ) {
            let jsonFiles = urls.filter { $0.pathExtension.lowercased() == "json" }
            if !jsonFiles.isEmpty {
                return jsonFiles.sorted {
                    $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending
                }
            }
        }

        if let urls = Bundle.main.urls(forResourcesWithExtension: "json", subdirectory: "PresetBundles"),
           !urls.isEmpty {
            return urls.sorted {
                $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending
            }
        }

        let excluded = Set(["jcstore-manifest"])
        return Bundle.main.urls(forResourcesWithExtension: "json", subdirectory: nil)?
            .filter { excluded.contains($0.deletingPathExtension().lastPathComponent) == false }
            .sorted {
                $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending
            } ?? []
    }

    private static func locateBundledPresetURL(resourceName: String) -> URL? {
        bundledPresetURLs().first { $0.deletingPathExtension().lastPathComponent == resourceName }
    }

    static let selectedPresetIDKey = "selectedBundledPresetID"
    static let usesUserPresetKey = "selectedPresetUsesUserSaved"

    static func persistSelectedPresetID(_ id: String) {
        UserDefaults.standard.set(id, forKey: selectedPresetIDKey)
    }

    static var storedSelectedPresetID: String? {
        UserDefaults.standard.string(forKey: selectedPresetIDKey)
    }

    static func persistUsesUserSavedPreset(_ usesUserSaved: Bool) {
        UserDefaults.standard.set(usesUserSaved, forKey: usesUserPresetKey)
    }

    static var storedUsesUserSavedPreset: Bool {
        UserDefaults.standard.bool(forKey: usesUserPresetKey)
    }

    private static func describe(_ error: DecodingError) -> String {
        switch error {
        case .keyNotFound(let key, let context):
            let path = codingPath(context.codingPath)
            return "Missing key \"\(key.stringValue)\" in \(path)."
        case .typeMismatch(let type, let context):
            let path = codingPath(context.codingPath)
            return "Type mismatch for \(type) at \(path): \(context.debugDescription)"
        case .valueNotFound(let type, let context):
            let path = codingPath(context.codingPath)
            return "Missing value for \(type) at \(path)."
        case .dataCorrupted(let context):
            let path = codingPath(context.codingPath)
            return "Invalid JSON at \(path): \(context.debugDescription)"
        @unknown default:
            return error.localizedDescription
        }
    }

    private static func codingPath(_ path: [CodingKey]) -> String {
        guard !path.isEmpty else { return "preset root" }
        return path.map(\.stringValue).joined(separator: " → ")
    }
}

enum PresetLoaderError: LocalizedError {
    case fileNotFound(String)
    case decodingFailed(String)
    case bundleEmpty

    var errorDescription: String? {
        switch self {
        case .fileNotFound(let name):
            return "Could not find bundled preset \"\(name).json\". Rebuild the app so Resources are copied into the bundle."
        case .decodingFailed(let details):
            return "Could not decode the bundled preset.\n\(details)"
        case .bundleEmpty:
            return "No presets found in PresetBundles. Add at least one .json file to the app bundle."
        }
    }
}
