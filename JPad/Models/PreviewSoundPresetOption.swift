import Foundation

struct PreviewSoundPresetOption: Identifiable, Equatable {
    let id: String
    let displayName: String
    let isCustom: Bool
}

enum PreviewSoundPresetIDs {
    static let factoryPrefix = "factory:"
    static let sharedPrefix = "shared:"
    static let custom = "custom:imported"
    static let tinyTone = factoryID(resourceName: "TinyTone")
    static let tinyPiano = factoryID(resourceName: "TinyPiano")

    static func factoryID(resourceName: String) -> String {
        factoryPrefix + resourceName
    }

    static func factoryResourceName(from id: String) -> String? {
        guard id.hasPrefix(factoryPrefix) else { return nil }
        let name = String(id.dropFirst(factoryPrefix.count))
        return name.isEmpty ? nil : name
    }

    static func sharedID(patchID: String) -> String {
        sharedPrefix + patchID
    }

    static func sharedPatchID(from id: String) -> String? {
        guard id.hasPrefix(sharedPrefix) else { return nil }
        let patchID = String(id.dropFirst(sharedPrefix.count))
        return patchID.isEmpty ? nil : patchID
    }

    /// リバーブ／ディレイが強く、初回 `start()` 直後の無音プリームが長めに必要な工場プリセット。
    private static let heavyDSPFactoryNames: Set<String> = ["TinyPiano", "TinyOrgan", "TinyStrings"]

    static func usesHeavyDSP(id: String) -> Bool {
        if id == custom || sharedPatchID(from: id) != nil { return true }
        guard let name = factoryResourceName(from: id) else { return false }
        return heavyDSPFactoryNames.contains(name)
    }
}
