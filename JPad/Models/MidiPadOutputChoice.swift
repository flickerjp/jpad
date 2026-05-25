import CoreMIDI
import Foundation

/// PAD OUT 設定一覧の1行（CoreMIDI 端末または内蔵 TinyTone）。
struct MidiPadOutputChoice: Identifiable, Equatable {
    let uniqueID: MIDIUniqueID
    let title: String
    let subtitle: String
    let isOnline: Bool
    let isInternalSynth: Bool
    let isSelectable: Bool

    var id: MIDIUniqueID { uniqueID }
}
