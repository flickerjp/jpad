import Foundation

/// PAD 編集 UI 世代。既定は v1.1。UserDefaults で v1 に切り戻し可能。
enum PadEditorUIVersion: String, CaseIterable {
    case v1
    case v11 = "1.1"

    static let storageKey = "jpad.pad_editor.ui_version"

    static var current: PadEditorUIVersion {
        let raw = UserDefaults.standard.string(forKey: storageKey) ?? "1.1"
        return PadEditorUIVersion(rawValue: raw) ?? .v11
    }

    static func setCurrent(_ version: PadEditorUIVersion) {
        UserDefaults.standard.set(version.rawValue == PadEditorUIVersion.v11.rawValue ? "1.1" : "1", forKey: storageKey)
    }
}
