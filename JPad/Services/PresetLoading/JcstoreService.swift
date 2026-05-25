import Foundation

enum JcstoreService {
  static let manifestURL = URL(string: "https://flicker-jp.com/jcstore/manifest.json")!
  /// ブラウザ向けカタログトップ（`index.html`）。アプリの一覧は `manifest.json`。
  static let catalogWebURL = URL(string: "https://flicker-jp.com/jcstore/")!
  static let allowedHostSuffix = "flicker-jp.com"

  static func loadManifest() async throws -> JcstoreManifest {
    if let remote = try? await fetchRemoteManifest() {
      return remote
    }
    return try loadBundledManifest()
  }

  static func loadPreset(
    catalogID: String,
    manifest: JcstoreManifest,
    presetLoader: PresetLoader = PresetLoader()
  ) async throws -> Preset {
    guard let entry = manifest.presets.first(where: { $0.id == catalogID }) else {
      throw JcstoreError.catalogEntryNotFound
    }
    if let remoteURL = manifest.presetURL(for: entry) {
      if let remote = try? await fetchRemotePreset(from: remoteURL) {
        return remote
      }
    }
    return try presetLoader.loadPreset(resourceName: entry.bundledResourceName)
  }

  static func validateRemotePresetURL(_ url: URL) throws {
    guard let host = url.host?.lowercased(), host == allowedHostSuffix || host.hasSuffix(".\(allowedHostSuffix)") else {
      throw JcstoreError.invalidHost
    }
    guard url.path.contains("/jcstore/") else {
      throw JcstoreError.invalidHost
    }
  }

  // MARK: - Private

  private static func fetchRemoteManifest() async throws -> JcstoreManifest {
    let (data, response) = try await URLSession.shared.data(from: manifestURL)
    guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
      throw JcstoreError.manifestUnavailable
    }
    return try decodeManifest(data)
  }

  private static func fetchRemotePreset(from url: URL) async throws -> Preset {
    try validateRemotePresetURL(url)
    let (data, response) = try await URLSession.shared.data(from: url)
    guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
      throw JcstoreError.presetNotAllowed
    }
    do {
      return try JSONDecoder().decode(Preset.self, from: data)
    } catch {
      throw JcstoreError.decodeFailed
    }
  }

  private static func loadBundledManifest() throws -> JcstoreManifest {
    let loader = PresetLoader()
    let bundledPresets = try loader.bundledCatalogItems()
    let catalogEntries: [JcstoreCatalogEntry] = try bundledPresets.map { item in
      let preset = try loader.loadPreset(resourceName: item.resourceName)
      return JcstoreCatalogEntry(
        id: item.id,
        title: item.title,
        description: preset.description.isEmpty ? nil : preset.description,
        publishedAt: nil,
        path: "presets/\(item.resourceName).json",
        resourceName: item.resourceName
      )
    }

    if let url = Bundle.main.url(forResource: "jcstore-manifest", withExtension: "json") {
      let data = try Data(contentsOf: url)
      let fileManifest = try decodeManifest(data)
      return JcstoreManifest(
        version: fileManifest.version,
        updatedAt: fileManifest.updatedAt,
        baseURL: fileManifest.baseURL,
        presets: mergeManifestPresets(file: fileManifest.presets, bundle: catalogEntries)
      )
    }

    return JcstoreManifest(
      version: 1,
      updatedAt: nil,
      baseURL: catalogWebURL.absoluteString,
      presets: catalogEntries
    )
  }

  /// Keeps manifest order/metadata; fills gaps from `PresetBundles` files on disk.
  private static func mergeManifestPresets(
    file: [JcstoreCatalogEntry],
    bundle: [JcstoreCatalogEntry]
  ) -> [JcstoreCatalogEntry] {
    var byID = Dictionary(uniqueKeysWithValues: bundle.map { ($0.id, $0) })
    var merged: [JcstoreCatalogEntry] = []
    merged.reserveCapacity(max(file.count, bundle.count))

    for entry in file {
      if let bundled = byID.removeValue(forKey: entry.id) {
        merged.append(
          JcstoreCatalogEntry(
            id: entry.id,
            title: entry.title,
            description: entry.description ?? bundled.description,
            publishedAt: entry.publishedAt,
            path: entry.path ?? bundled.path,
            resourceName: entry.resourceName ?? bundled.resourceName
          )
        )
      } else if entry.resourceName != nil || entry.path != nil {
        merged.append(entry)
      }
    }
    let extras = bundle.filter { bundled in !merged.contains(where: { $0.id == bundled.id }) }
    merged.append(contentsOf: extras)
    return merged
  }

  private static func decodeManifest(_ data: Data) throws -> JcstoreManifest {
    do {
      return try JSONDecoder().decode(JcstoreManifest.self, from: data)
    } catch {
      throw JcstoreError.decodeFailed
    }
  }
}
