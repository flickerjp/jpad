import Foundation

enum MidiOutputRoute: String, CaseIterable, Identifiable {
    case tinyPiano
    case garageBand
    case device

    var id: String { rawValue }
}

/// 内蔵 PAD OUT（TinyTone / GarageBand）。外部 MIDI 端末とは排他。
enum PrimaryPadOutputMode: String, CaseIterable, Identifiable {
    case tinyTone
    case garageBand

    var id: String { rawValue }

    var outputRoute: MidiOutputRoute {
        switch self {
        case .tinyTone:
            return .tinyPiano
        case .garageBand:
            return .garageBand
        }
    }
}
