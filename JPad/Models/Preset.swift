import Foundation

struct Preset: Decodable, Identifiable, Equatable {
    let id: String
    let appName: String
    let setName: String
    let description: String
    let version: Int
    let defaultPlaybackMode: String
    let autoBassOctave: Bool
    let defaultChannel: UInt8
    let defaultVelocity: UInt8
    let defaultExpression: UInt8
    let pads: [PadDefinition]

    var name: String { setName }

    enum CodingKeys: String, CodingKey {
        case id, appName, setName, name, description, version, defaultPlaybackMode, autoBassOctave, defaultChannel, defaultExpression, defaultVelocity, pads
    }

    init(
        id: String,
        appName: String,
        setName: String,
        description: String,
        version: Int,
        defaultPlaybackMode: String,
        autoBassOctave: Bool,
        defaultChannel: UInt8,
        defaultVelocity: UInt8,
        defaultExpression: UInt8,
        pads: [PadDefinition]
    ) {
        self.id = id
        self.appName = appName
        self.setName = setName
        self.description = description
        self.version = version
        self.defaultPlaybackMode = defaultPlaybackMode
        self.autoBassOctave = autoBassOctave
        self.defaultChannel = defaultChannel
        self.defaultVelocity = defaultVelocity
        self.defaultExpression = defaultExpression
        self.pads = pads
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let resolvedSetName = try container.decodeIfPresent(String.self, forKey: .setName)
            ?? container.decodeIfPresent(String.self, forKey: .name)
            ?? "Untitled Preset"
        id = try container.decodeIfPresent(String.self, forKey: .id)
            ?? Self.slug(from: resolvedSetName)
        appName = try container.decodeIfPresent(String.self, forKey: .appName) ?? "JPad"
        setName = resolvedSetName
        description = try container.decodeIfPresent(String.self, forKey: .description) ?? ""
        version = try container.decodeIfPresent(Int.self, forKey: .version) ?? 1
        defaultPlaybackMode = try container.decodeIfPresent(String.self, forKey: .defaultPlaybackMode) ?? "bassChord"
        autoBassOctave = try container.decodeIfPresent(Bool.self, forKey: .autoBassOctave) ?? true
        defaultChannel = try Self.decodeMidiChannel(from: container)
        let resolvedVelocity = try container.decodeIfPresent(UInt8.self, forKey: .defaultVelocity) ?? 100
        defaultVelocity = resolvedVelocity
        defaultExpression = try container.decodeIfPresent(UInt8.self, forKey: .defaultExpression) ?? resolvedVelocity
        pads = try container.decode([PadDefinition].self, forKey: .pads)
    }

    /// JSON uses musician-facing channels 1–16; Core MIDI uses 0–15.
    var midiChannel: UInt8 {
        defaultChannel == 0 ? 0 : defaultChannel - 1
    }

    private static func decodeMidiChannel(from container: KeyedDecodingContainer<CodingKeys>) throws -> UInt8 {
        guard let raw = try container.decodeIfPresent(UInt8.self, forKey: .defaultChannel) else {
            return 0
        }
        guard (1...16).contains(raw) else {
            throw DecodingError.dataCorruptedError(
                forKey: .defaultChannel,
                in: container,
                debugDescription: "defaultChannel must be between 1 and 16."
            )
        }
        return raw
    }

    private static func slug(from setName: String) -> String {
        let lowered = setName.lowercased()
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-"))
        let slug = lowered.unicodeScalars
            .map { allowed.contains($0) ? Character($0) : "-" }
        let normalized = String(slug)
            .replacingOccurrences(of: "--", with: "-")
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        return normalized.isEmpty ? "preset" : normalized
    }
}

extension Preset {
    /// 新規スロット用（MY SETS の +）。各パッドに C2〜B2 の単音コードを割り当てる。
    static let blankUserSet = Preset(
        id: "blank",
        appName: "JPad",
        setName: "Untitled",
        description: "",
        version: 2,
        defaultPlaybackMode: "bassChord",
        autoBassOctave: true,
        defaultChannel: 1,
        defaultVelocity: 100,
        defaultExpression: 100,
        pads: blankStarterPads()
    )

    private static func blankStarterPads() -> [PadDefinition] {
        let firstPitch = MidiNoteFormatter.blankStarterFirstPitch
        return (0..<12).map { index in
            let note = firstPitch + UInt8(index)
            let noteName = MidiNoteFormatter.format(note)
            return PadDefinition(
                index: index,
                name: noteName,
                displayName: noteName,
                label: noteName,
                role: "",
                chordNotes: [note],
                bassNotes: []
            )
        }
    }

    static let fallback = Preset(
        id: "fallback",
        appName: "JPad",
        setName: "Preset",
        description: "",
        version: 1,
        defaultPlaybackMode: "bassChord",
        autoBassOctave: true,
        defaultChannel: 0,
        defaultVelocity: 100,
        defaultExpression: 100,
        pads: (0..<12).map { index in
            PadDefinition(
                index: index,
                name: "Pad \(index + 1)",
                displayName: "Pad \(index + 1)",
                label: "Pad \(index + 1)",
                role: "No Data",
                chordNotes: [],
                bassNotes: []
            )
        }
    )
}
