import CoreMIDI
import Foundation

struct MidiSourceInfo: Identifiable, Equatable {
    let uniqueID: MIDIUniqueID
    let endpointRef: MIDIEndpointRef
    let displayName: String
    let isOnline: Bool

    var id: MIDIUniqueID { uniqueID }

    var statusText: String {
        isOnline ? "Available" : "Offline"
    }
}
