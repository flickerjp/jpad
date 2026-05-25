import Foundation

struct BundledPresetItem: Identifiable, Equatable {
    let id: String
    let resourceName: String
    let title: String

    var menuTitle: String { title }

    var topBarTitle: String {
        title.truncatedForTopBar(maxLength: 12)
    }
}

enum PresetCatalog {
    static let userSlotID = "user-saved"

    static let userSlotItem = BundledPresetItem(
        id: userSlotID,
        resourceName: "",
        title: L10n.string("preset.my_stage")
    )

    static func bundledItems(presetLoader: PresetLoader = PresetLoader()) throws -> [BundledPresetItem] {
        try presetLoader.bundledCatalogItems()
    }

    static func visibleBundledItems(presetLoader: PresetLoader = PresetLoader()) throws -> [BundledPresetItem] {
        try bundledItems(presetLoader: presetLoader).filter { !BundledPresetDeletionStore.isDeleted($0.id) }
    }

    static func isUserSlot(_ id: String) -> Bool {
        id == userSlotID
    }

    static func isBundledPreset(_ id: String, presetLoader: PresetLoader = PresetLoader()) -> Bool {
        guard let items = try? bundledItems(presetLoader: presetLoader) else { return false }
        return items.contains { $0.id == id || $0.resourceName == id }
    }

    /// Pads are editable only on My Stage (imported presets will use a separate ID later).
    static func isEditablePreset(_ id: String) -> Bool {
        isUserSlot(id)
    }

    static func item(id: String, presetLoader: PresetLoader = PresetLoader()) throws -> BundledPresetItem? {
        if isUserSlot(id) {
            return userSlotItem
        }
        return try bundledItems(presetLoader: presetLoader).first { $0.id == id || $0.resourceName == id }
    }

    static func visibleItem(id: String, presetLoader: PresetLoader = PresetLoader()) throws -> BundledPresetItem? {
        if isUserSlot(id) {
            return userSlotItem
        }
        guard !BundledPresetDeletionStore.isDeleted(id) else { return nil }
        return try item(id: id, presetLoader: presetLoader)
    }

    /// Maps legacy bundled / store IDs from older app versions to a current bundle file when possible.
    static func normalizedStoredID(_ id: String?, presetLoader: PresetLoader = PresetLoader()) -> String? {
        guard let id else { return nil }
        if isUserSlot(id) {
            return userSlotID
        }
        if let items = try? bundledItems(presetLoader: presetLoader),
           items.contains(where: { $0.id == id || $0.resourceName == id }) {
            return id
        }
        switch id {
        case "okinawa", "uk-funk", "jazz-fusion", "bossa-nova", "progressive-rock",
             "jazz-standard", "city-pops", "my-set-default":
            return try? bundledItems(presetLoader: presetLoader).first?.id
        default:
            return id
        }
    }
}

extension String {
    func truncatedForTopBar(maxLength: Int) -> String {
        guard count > maxLength else { return self }
        return String(prefix(maxLength))
    }
}
