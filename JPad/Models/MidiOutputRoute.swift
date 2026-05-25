import Foundation

enum MidiOutputRoute: String, CaseIterable, Identifiable {
    case tinyPiano
    case garageBand
    case device

    var id: String { rawValue }
}
