import Foundation

/// MY SETS の PAD 画面用セット切り替え（< / >）対象。
enum PresetRotationSettings {
    static let useAllSlotsKey = "jpad.rotation.use_all_slots"
    static let slotIDsKey = "jpad.rotation.slot_ids"

    static func loadSlotIDs(from storage: String) -> Set<String> {
        guard !storage.isEmpty else { return [] }
        return Set(storage.split(separator: ",").map(String.init))
    }

    static func saveSlotIDs(_ ids: Set<String>) -> String {
        ids.sorted().joined(separator: ",")
    }
}
