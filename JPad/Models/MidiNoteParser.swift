import Foundation

enum MidiNoteParser {
    private static let noteOffsets: [Character: Int] = [
        "C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11
    ]

    static func parse(_ value: String) throws -> UInt8 {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw MidiNoteParseError.empty
        }

        if let number = UInt8(trimmed), number <= 127 {
            return number
        }

        guard let letter = trimmed.first?.uppercased().first,
              let base = noteOffsets[letter] else {
            throw MidiNoteParseError.invalid(trimmed)
        }

        var index = trimmed.index(after: trimmed.startIndex)
        var semitone = base

        if index < trimmed.endIndex {
            let accidental = trimmed[index]
            if accidental == "#" || accidental == "♯" {
                semitone += 1
                index = trimmed.index(after: index)
            } else if accidental == "b" || accidental == "♭" {
                semitone -= 1
                index = trimmed.index(after: index)
            }
        }

        guard index < trimmed.endIndex, let octaveDigit = trimmed[index].wholeNumberValue else {
            throw MidiNoteParseError.missingOctave(trimmed)
        }

        let midi = (octaveDigit + 1) * 12 + semitone
        guard (0...127).contains(midi) else {
            throw MidiNoteParseError.outOfRange(trimmed)
        }

        return UInt8(midi)
    }
}

enum MidiNoteParseError: LocalizedError {
    case empty
    case invalid(String)
    case missingOctave(String)
    case outOfRange(String)

    var errorDescription: String? {
        switch self {
        case .empty:
            return "Note value is empty."
        case .invalid(let value):
            return "Could not parse note \"\(value)\"."
        case .missingOctave(let value):
            return "Note \"\(value)\" is missing an octave (e.g. C4)."
        case .outOfRange(let value):
            return "Note \"\(value)\" is outside the MIDI range 0–127."
        }
    }
}
