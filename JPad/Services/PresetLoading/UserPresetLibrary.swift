import Foundation

/// ユーザープリセットライブラリ（複数スロット）。
enum UserPresetLibrary {
  private static let appGroupIdentifier = "group.com.flickerproduct.jchord"
  private static let indexFileName = "index.json"
  private static let presetsFolderName = "presets"

  // MARK: - Public API

  static func slotEntries() throws -> [UserPresetSlotEntry] {
    try loadIndex().items
  }

  static func activeSlotID() throws -> String? {
    try loadIndex().activePresetID
  }

  static func entry(id: String) throws -> UserPresetSlotEntry? {
    try loadIndex().items.first { $0.id == id }
  }

  static func loadActivePreset() throws -> Preset {
    let index = try loadIndex()
    guard let activeID = index.activePresetID else {
      throw UserPresetLibraryError.noActiveSlot
    }
    return try loadPreset(slotID: activeID)
  }

  static func loadPreset(slotID: String) throws -> Preset {
    let document = try loadDocument(slotID: slotID)
    return document.preset
  }

  @discardableResult
  static func ensureInitialized(entitlement: Entitlement, presetLoader: PresetLoader = PresetLoader()) throws -> String? {
    try migrateLegacySingleFileIfNeeded(presetLoader: presetLoader)
    try seedBundledTemplatesIfNeeded(
      targetCount: entitlement.maxUserPresetSlots,
      presetLoader: presetLoader
    )

    let index = try loadIndex()
    if let activeID = index.activePresetID, index.items.contains(where: { $0.id == activeID }) {
      return activeID
    }
    guard let firstID = index.items.first?.id else {
      return nil
    }
    try setActiveSlot(id: firstID)
    return firstID
  }

  static func setActiveSlot(id: String) throws {
    var index = try loadIndex()
    guard index.items.contains(where: { $0.id == id }) else {
      throw UserPresetLibraryError.slotNotFound
    }
    index.activePresetID = id
    try saveIndex(index)
  }

  static func saveActiveSlot(preset: Preset, entitlement: Entitlement) throws {
    let index = try loadIndex()
    guard let activeID = index.activePresetID else {
      throw UserPresetLibraryError.noActiveSlot
    }
    try savePreset(preset, slotID: activeID)
  }

  static func savePreset(_ preset: Preset, slotID: String) throws {
    var index = try loadIndex()
    guard let entryIndex = index.items.firstIndex(where: { $0.id == slotID }) else {
      throw UserPresetLibraryError.slotNotFound
    }

    let existing = index.items[entryIndex]
    let resolvedOrigin: PresetSlotOrigin = {
      switch existing.origin {
      case .store:
        return .store
      case .seed:
        return .user
      case .user:
        return .user
      }
    }()
    let document = PresetSlotDocument(
      preset: preset,
      seedTemplateID: existing.seedTemplateID,
      origin: resolvedOrigin
    )
    try writeDocument(document, slotID: slotID)

    index.items[entryIndex].setName = preset.setName
    index.items[entryIndex].savedAt = document.savedAt
    index.items[entryIndex].origin = resolvedOrigin
    try saveIndex(index)
  }

  @discardableResult
  static func createSlot(
    preset: Preset,
    seedTemplateID: String?,
    storeCatalogID: String? = nil,
    origin: PresetSlotOrigin,
    entitlement: Entitlement
  ) throws -> String {
    var index = try loadIndex()
    guard index.items.count < entitlement.maxUserPresetSlots else {
      throw UserPresetLibraryError.slotLimitReached(limit: entitlement.maxUserPresetSlots)
    }

    let slotID = UUID().uuidString.lowercased()
    let entry = UserPresetSlotEntry(
      id: slotID,
      setName: preset.setName,
      savedAt: Date(),
      seedTemplateID: seedTemplateID,
      storeCatalogID: storeCatalogID,
      origin: origin
    )
    let document = PresetSlotDocument(
      preset: preset,
      seedTemplateID: seedTemplateID,
      origin: origin
    )
    try writeDocument(document, slotID: slotID)
    index.items.append(entry)
    index.activePresetID = slotID
    try saveIndex(index)
    return slotID
  }

  static func replaceSlotContent(
    slotID: String,
    preset: Preset,
    seedTemplateID: String?,
    storeCatalogID: String? = nil,
    origin: PresetSlotOrigin
  ) throws {
    var index = try loadIndex()
    guard let entryIndex = index.items.firstIndex(where: { $0.id == slotID }) else {
      throw UserPresetLibraryError.slotNotFound
    }

    let document = PresetSlotDocument(
      preset: preset,
      seedTemplateID: seedTemplateID,
      origin: origin
    )
    try writeDocument(document, slotID: slotID)

    index.items[entryIndex].setName = preset.setName
    index.items[entryIndex].savedAt = document.savedAt
    index.items[entryIndex].seedTemplateID = seedTemplateID
    index.items[entryIndex].storeCatalogID = storeCatalogID
    index.items[entryIndex].origin = origin
    try saveIndex(index)
  }

  static func moveSlot(fromIndex: Int, toIndex: Int) throws {
    var index = try loadIndex()
    let count = index.items.count
    guard fromIndex != toIndex,
      index.items.indices.contains(fromIndex),
      toIndex >= 0,
      toIndex <= count
    else { return }
    index.items.move(fromOffsets: IndexSet(integer: fromIndex), toOffset: toIndex)
    try saveIndex(index)
  }

  static func deleteSlot(id: String) throws {
    var index = try loadIndex()
    guard let entryIndex = index.items.firstIndex(where: { $0.id == id }) else {
      throw UserPresetLibraryError.slotNotFound
    }
    index.items.remove(at: entryIndex)
    let rootURL = try resolvedLibraryRootURL()
    let fileURL = presetFileURL(slotID: id, rootURL: rootURL)
    if FileManager.default.fileExists(atPath: fileURL.path) {
      try FileManager.default.removeItem(at: fileURL)
    }
    if index.activePresetID == id {
      index.activePresetID = index.items.first?.id
    }
    try saveIndex(index)
  }

  static func slotCount() throws -> Int {
    try loadIndex().items.count
  }

  static func canCreateSlot(entitlement: Entitlement) throws -> Bool {
    try loadIndex().items.count < entitlement.maxUserPresetSlots
  }

  static func storeOriginSlots() throws -> [UserPresetSlotEntry] {
    try loadIndex().items.filter { $0.origin == .store }
  }

  /// 無料枠の store 1 件制限のため、既存 store スロットを user 由来にする（中身は保持）。
  private static func demoteStoreSlotsToUserOrigin() throws {
    var index = try loadIndex()
    var didChange = false
    for entryIndex in index.items.indices where index.items[entryIndex].origin == .store {
      let slotID = index.items[entryIndex].id
      let existing = try loadDocument(slotID: slotID)
      let document = PresetSlotDocument(
        preset: existing.preset,
        seedTemplateID: existing.seedTemplateID,
        origin: .user,
        savedAt: existing.savedAt
      )
      try writeDocument(document, slotID: slotID)
      index.items[entryIndex].setName = existing.preset.setName
      index.items[entryIndex].savedAt = document.savedAt
      index.items[entryIndex].origin = .user
      index.items[entryIndex].storeCatalogID = nil
      didChange = true
    }
    if didChange {
      try saveIndex(index)
    }
  }

  @discardableResult
  static func createBlankSlot(entitlement: Entitlement) throws -> String {
    let blank = Preset.blankUserSet
    let preset = Preset(
      id: UUID().uuidString.lowercased(),
      appName: blank.appName,
      setName: Preset.blankUserSet.setName,
      description: blank.description,
      version: blank.version,
      defaultPlaybackMode: blank.defaultPlaybackMode,
      autoBassOctave: blank.autoBassOctave,
      defaultChannel: blank.defaultChannel,
      defaultVelocity: blank.defaultVelocity,
      defaultExpression: blank.defaultExpression,
      pads: blank.pads
    )
    return try createSlot(
      preset: preset,
      seedTemplateID: nil,
      storeCatalogID: nil,
      origin: .user,
      entitlement: entitlement
    )
  }

  @discardableResult
  static func duplicateActiveSlot(entitlement: Entitlement) throws -> String {
    guard entitlement.canDuplicateSlots else {
      throw UserPresetLibraryError.proRequired
    }
    let activePreset = try loadActivePreset()
    let activeID = try activeSlotID()
    let activeEntry = try loadIndex().items.first { $0.id == activeID }
    let copyName = L10n.format("preset.library.copy_name", activePreset.setName)
    var copied = activePreset
    copied = Preset(
      id: UUID().uuidString.lowercased(),
      appName: copied.appName,
      setName: copyName,
      description: copied.description,
      version: copied.version,
      defaultPlaybackMode: copied.defaultPlaybackMode,
      autoBassOctave: copied.autoBassOctave,
      defaultChannel: copied.defaultChannel,
      defaultVelocity: copied.defaultVelocity,
      defaultExpression: copied.defaultExpression,
      pads: copied.pads
    )
    return try createSlot(
      preset: copied,
      seedTemplateID: activeEntry?.seedTemplateID,
      storeCatalogID: nil,
      origin: .user,
      entitlement: entitlement
    )
  }

  /// jcstore 取り込み。無料は store 由来が同時1件まで。
  /// 空きスロットがあるときは既存 store を user に降格して新規 store スロットを追加する。
  @discardableResult
  static func importStorePreset(
    _ preset: Preset,
    catalogID: String,
    replaceSlotID: String?,
    entitlement: Entitlement
  ) throws -> String {
    if entitlement.maxConcurrentStoreImports != nil, try storeOriginSlots().count >= 1 {
      if let replaceSlotID {
        try replaceSlotContent(
          slotID: replaceSlotID,
          preset: preset,
          seedTemplateID: nil,
          storeCatalogID: catalogID,
          origin: .store
        )
        try setActiveSlot(id: replaceSlotID)
        return replaceSlotID
      }
      if try canCreateSlot(entitlement: entitlement) {
        try demoteStoreSlotsToUserOrigin()
        return try createSlot(
          preset: preset,
          seedTemplateID: nil,
          storeCatalogID: catalogID,
          origin: .store,
          entitlement: entitlement
        )
      }
      throw UserPresetLibraryError.storeImportLimitReached
    }

    if try canCreateSlot(entitlement: entitlement) {
      return try createSlot(
        preset: preset,
        seedTemplateID: nil,
        storeCatalogID: catalogID,
        origin: .store,
        entitlement: entitlement
      )
    }

    guard let replaceSlotID else {
      throw UserPresetLibraryError.slotLimitReached(limit: entitlement.maxUserPresetSlots)
    }
    try replaceSlotContent(
      slotID: replaceSlotID,
      preset: preset,
      seedTemplateID: nil,
      storeCatalogID: catalogID,
      origin: .store
    )
    try setActiveSlot(id: replaceSlotID)
    return replaceSlotID
  }

  @discardableResult
  static func importSharedUserPreset(_ preset: Preset, entitlement: Entitlement) throws -> String {
    if try canCreateSlot(entitlement: entitlement) {
      return try createSlot(
        preset: preset,
        seedTemplateID: nil,
        storeCatalogID: nil,
        origin: .user,
        entitlement: entitlement
      )
    }
    guard let activeID = try activeSlotID() else {
      throw UserPresetLibraryError.noActiveSlot
    }
    try replaceSlotContent(
      slotID: activeID,
      preset: preset,
      seedTemplateID: nil,
      storeCatalogID: nil,
      origin: .user
    )
    return activeID
  }

  // MARK: - Seeding

  private static func seedBundledTemplatesIfNeeded(
    targetCount: Int,
    presetLoader: PresetLoader
  ) throws {
    var index = try loadIndex()
    guard !index.hasCompletedInitialSeed else { return }
    guard index.items.isEmpty else {
      index.hasCompletedInitialSeed = true
      try saveIndex(index)
      return
    }

    let bundled = try PresetCatalog.bundledItems(presetLoader: presetLoader)
    let fillCount = min(targetCount, bundled.count)
    for item in bundled.prefix(fillCount) {
      let loaded = try presetLoader.loadPreset(resourceName: item.resourceName)
      let slotID = UUID().uuidString.lowercased()
      let entry = UserPresetSlotEntry(
        id: slotID,
        setName: loaded.setName,
        savedAt: Date(),
        seedTemplateID: item.id,
        origin: .seed
      )
      let document = PresetSlotDocument(
        preset: loaded,
        seedTemplateID: item.id,
        origin: .seed
      )
      try writeDocument(document, slotID: slotID)
      index.items.append(entry)
      if index.activePresetID == nil {
        index.activePresetID = slotID
      }
    }
    index.hasCompletedInitialSeed = true
    try saveIndex(index)
  }

  // MARK: - Legacy migration

  private static func migrateLegacySingleFileIfNeeded(presetLoader: PresetLoader) throws {
    let rootURL = try resolvedLibraryRootURL()
    guard !FileManager.default.fileExists(atPath: indexURL(for: rootURL).path) else { return }
    guard UserPresetStore.hasSavedPreset else { return }

    let legacyPreset = try UserPresetStore.load()
    let legacySource = try UserPresetStore.loadSourcePresetID()
    guard let legacyPreset else { return }

    let seedID = legacySource.flatMap { PresetCatalog.isBundledPreset($0, presetLoader: presetLoader) ? $0 : nil }
    let slotID = UUID().uuidString.lowercased()
    let entry = UserPresetSlotEntry(
      id: slotID,
      setName: legacyPreset.setName,
      savedAt: Date(),
      seedTemplateID: seedID,
      origin: seedID == nil ? .user : .seed
    )
    let document = PresetSlotDocument(
      preset: legacyPreset,
      seedTemplateID: seedID,
      origin: entry.origin
    )
    try writeDocument(document, slotID: slotID)

    let index = UserPresetLibraryIndex(
      activePresetID: slotID,
      items: [entry],
      hasCompletedInitialSeed: true
    )
    try saveIndex(index)

    _ = presetLoader
  }

  // MARK: - IO

  private static func loadIndex() throws -> UserPresetLibraryIndex {
    let rootURL = try resolvedLibraryRootURL()
    try ensureLibraryDirectory(at: rootURL)
    let resolvedIndexURL = indexURL(for: rootURL)
    guard FileManager.default.fileExists(atPath: resolvedIndexURL.path) else {
      return UserPresetLibraryIndex()
    }
    let data = try Data(contentsOf: resolvedIndexURL)
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    return try decoder.decode(UserPresetLibraryIndex.self, from: data)
  }

  private static func saveIndex(_ index: UserPresetLibraryIndex) throws {
    let rootURL = try resolvedLibraryRootURL()
    try ensureLibraryDirectory(at: rootURL)
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    encoder.dateEncodingStrategy = .iso8601
    let data = try encoder.encode(index)
    try data.write(to: indexURL(for: rootURL), options: .atomic)
  }

  private static func loadDocument(slotID: String) throws -> PresetSlotDocument {
    let rootURL = try resolvedLibraryRootURL()
    let data = try Data(contentsOf: presetFileURL(slotID: slotID, rootURL: rootURL))
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    return try decoder.decode(PresetSlotDocument.self, from: data)
  }

  private static func writeDocument(_ document: PresetSlotDocument, slotID: String) throws {
    let rootURL = try resolvedLibraryRootURL()
    try ensureLibraryDirectory(at: rootURL)
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    encoder.dateEncodingStrategy = .iso8601
    let data = try encoder.encode(document)
    try data.write(to: presetFileURL(slotID: slotID, rootURL: rootURL), options: .atomic)
  }

  private static func ensureLibraryDirectory(at rootURL: URL) throws {
    try FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: presetsDirectoryURL(for: rootURL), withIntermediateDirectories: true)
  }

  private static func resolvedLibraryRootURL() throws -> URL {
    if let appGroupRootURL = appGroupLibraryRootURL {
      try migrateLegacyLibraryToAppGroupIfNeeded(appGroupRootURL: appGroupRootURL)
      return appGroupRootURL
    }
    return preferredLegacyLibraryRootURL
  }

  private static var preferredLegacyLibraryRootURL: URL {
    legacyLibraryRootCandidates.first(where: { FileManager.default.fileExists(atPath: indexURL(for: $0).path) })
      ?? legacyLibraryRootCandidates[0]
  }

  private static var appGroupLibraryRootURL: URL? {
    FileManager.default
      .containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)?
      .appendingPathComponent("JPad/library/user", isDirectory: true)
  }

  private static var legacyLibraryRootCandidates: [URL] {
    let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
      ?? FileManager.default.temporaryDirectory
    return [
      base.appendingPathComponent("JChord/library/user", isDirectory: true),
      base.appendingPathComponent("JPad/library/user", isDirectory: true)
    ]
  }

  private static func migrateLegacyLibraryToAppGroupIfNeeded(appGroupRootURL: URL) throws {
    let fileManager = FileManager.default
    let targetIndexURL = indexURL(for: appGroupRootURL)
    guard !fileManager.fileExists(atPath: targetIndexURL.path) else { return }

    guard let sourceRootURL = legacyLibraryRootCandidates.first(where: {
      fileManager.fileExists(atPath: indexURL(for: $0).path)
    }) else { return }

    try ensureLibraryDirectory(at: appGroupRootURL)

    let sourcePresetsURL = presetsDirectoryURL(for: sourceRootURL)
    let targetPresetsURL = presetsDirectoryURL(for: appGroupRootURL)
    if fileManager.fileExists(atPath: sourcePresetsURL.path) {
      let presetFiles = try fileManager.contentsOfDirectory(
        at: sourcePresetsURL,
        includingPropertiesForKeys: nil,
        options: [.skipsHiddenFiles]
      )
      for fileURL in presetFiles {
        let targetFileURL = targetPresetsURL.appendingPathComponent(fileURL.lastPathComponent)
        guard !fileManager.fileExists(atPath: targetFileURL.path) else { continue }
        try fileManager.copyItem(at: fileURL, to: targetFileURL)
      }
    }

    try fileManager.copyItem(at: indexURL(for: sourceRootURL), to: targetIndexURL)
  }

  private static func presetsDirectoryURL(for rootURL: URL) -> URL {
    rootURL.appendingPathComponent(presetsFolderName, isDirectory: true)
  }

  private static func indexURL(for rootURL: URL) -> URL {
    rootURL.appendingPathComponent(indexFileName)
  }

  private static func presetFileURL(slotID: String, rootURL: URL) -> URL {
    presetsDirectoryURL(for: rootURL).appendingPathComponent("\(slotID).json")
  }
}
