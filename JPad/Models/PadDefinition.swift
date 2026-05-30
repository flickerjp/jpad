import Foundation

struct PadDefinition: Decodable, Identifiable, Equatable {
    let index: Int
    let name: String
    let displayName: String
    let label: String
    let labelAllowsTranspose: Bool
    let role: String
    let chordNotes: [UInt8]
    let bassNotes: [UInt8]
    let playbackMode: String?
    let arpeggioPattern: String?

    var id: Int { index }

    var title: String { label }

    var subtitle: String { displayName }

    /// パッド左下に表示するルート名（displayName に品質が含まれていてもルートだけ返す）
    var rootDisplayName: String {
        if let root = ChordLabel.parsedRoot(from: displayName) {
            return root
        }
        if let root = ChordLabel.parsedRoot(from: label) {
            return root
        }
        return RootPitch.normalize(name)
    }

    enum CodingKeys: String, CodingKey {
        case index, id, name, displayName, label, labelAllowsTranspose, role, chordNotes, bassNotes, playbackMode, arpeggioPattern
    }

    init(
        index: Int,
        name: String,
        displayName: String,
        label: String,
        labelAllowsTranspose: Bool = true,
        role: String,
        chordNotes: [UInt8],
        bassNotes: [UInt8],
        playbackMode: String? = nil,
        arpeggioPattern: String? = nil
    ) {
        self.index = index
        self.name = name
        self.displayName = displayName
        self.label = label
        self.labelAllowsTranspose = labelAllowsTranspose
        self.role = role
        self.chordNotes = chordNotes
        self.bassNotes = bassNotes
        self.playbackMode = playbackMode
        self.arpeggioPattern = arpeggioPattern
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let resolvedIndex = try container.decodeIfPresent(Int.self, forKey: .index)
            ?? container.decode(Int.self, forKey: .id)
        let resolvedName = try container.decodeIfPresent(String.self, forKey: .name) ?? "Pad \(resolvedIndex + 1)"
        let resolvedDisplayName = try container.decodeIfPresent(String.self, forKey: .displayName) ?? resolvedName
        let resolvedLabel = try container.decodeIfPresent(String.self, forKey: .label) ?? resolvedDisplayName

        index = resolvedIndex
        name = resolvedName
        displayName = resolvedDisplayName
        label = resolvedLabel
        labelAllowsTranspose = try container.decodeIfPresent(Bool.self, forKey: .labelAllowsTranspose) ?? true
        role = try container.decodeIfPresent(String.self, forKey: .role) ?? ""
        chordNotes = try Self.decodeNotes(forKey: .chordNotes, in: container)
        bassNotes = try Self.decodeNotes(forKey: .bassNotes, in: container)
        playbackMode = try container.decodeIfPresent(String.self, forKey: .playbackMode)
        arpeggioPattern = try container.decodeIfPresent(String.self, forKey: .arpeggioPattern)
    }

    private static func decodeNotes(
        forKey key: CodingKeys,
        in container: KeyedDecodingContainer<CodingKeys>
    ) throws -> [UInt8] {
        guard container.contains(key) else { return [] }

        if let numbers = try? container.decode([UInt8].self, forKey: key) {
            return numbers
        }

        var notesContainer = try container.nestedUnkeyedContainer(forKey: key)
        var notes: [UInt8] = []
        notes.reserveCapacity(notesContainer.count ?? 0)

        while !notesContainer.isAtEnd {
            if let number = try? notesContainer.decode(UInt8.self) {
                notes.append(number)
                continue
            }

            let text = try notesContainer.decode(String.self)
            notes.append(try MidiNoteParser.parse(text))
        }

        return notes
    }
}

extension PadDefinition {
    func shiftedDisplay(by semitones: Int) -> PadDefinition {
        guard semitones != 0 else { return self }
        return PadDefinition(
            index: index,
            name: name,
            displayName: ChordLabel.shiftingRoot(in: displayName, semitones: semitones),
            label: labelAllowsTranspose
                ? ChordLabel.shiftingRoot(in: label, semitones: semitones)
                : label,
            labelAllowsTranspose: labelAllowsTranspose,
            role: role,
            chordNotes: chordNotes,
            bassNotes: bassNotes,
            playbackMode: playbackMode,
            arpeggioPattern: arpeggioPattern
        )
    }
}
