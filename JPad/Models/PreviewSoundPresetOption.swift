import Foundation

struct PreviewSoundPresetOption: Identifiable, Equatable {
    let id: String
    let displayName: String
    let isCustom: Bool
}

enum PreviewSoundPresetIDs {
    static let factoryPrefix = "factory:"
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
}
