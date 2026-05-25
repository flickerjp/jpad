import Foundation

/// Bundled preset IDs the user removed (survives app updates; cleared on reinstall).
enum BundledPresetDeletionStore {
    private static let userDefaultsKey = "jpad.deletedBundledPresetIDs"

    static var deletedIDs: Set<String> {
        get {
            Set(UserDefaults.standard.stringArray(forKey: userDefaultsKey) ?? [])
        }
        set {
            UserDefaults.standard.set(Array(newValue).sorted(), forKey: userDefaultsKey)
        }
    }

    static func isDeleted(_ id: String) -> Bool {
        deletedIDs.contains(id)
    }

    static func markDeleted(_ id: String) {
        var ids = deletedIDs
        ids.insert(id)
        deletedIDs = ids
    }
}
