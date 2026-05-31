import Foundation

enum RootPitch {
    static let pitchClassNames = ["C", "C#", "D", "Eb", "E", "F", "F#", "G", "Ab", "A", "Bb", "B"]

    /// UI 上のルート名。異名同音は Canonical 表記へ統一し、以降この表記を使わない。
    static func normalize(_ root: String) -> String {
        switch root {
        case "Cb": return "B"
        case "Db": return "C#"
        case "D#": return "Eb"
        case "E#": return "F"
        case "Fb": return "E"
        case "G#": return "Ab"
        case "A#": return "Bb"
        case "B#": return "C"
        default: return root
        }
    }

    static func displayName(forPitchClass pitchClass: Int) -> String {
        pitchClassNames[((pitchClass % 12) + 12) % 12]
    }

    static func pitchClass(for root: String) -> Int? {
        let normalized = normalize(root)
        return pitchClassNames.firstIndex(of: normalized)
    }

    static func transposed(_ root: String, semitones: Int) -> String? {
        guard let pitchClass = pitchClass(for: root) else { return nil }
        return displayName(forPitchClass: pitchClass + semitones)
    }
}

enum ChordLabel {
    private static let knownRoots = [
        "C#", "Db",
        "D#", "Eb",
        "E#", "Fb",
        "F#",
        "G#", "Ab",
        "A#", "Bb",
        "B#", "Cb",
        "C", "D", "E", "F", "G", "A", "B"
    ]

    static func parsedRoot(from label: String) -> String? {
        let trimmed = label.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        for root in knownRoots {
            if trimmed.uppercased().hasPrefix(root.uppercased()) {
                return RootPitch.normalize(root)
            }
        }
        return nil
    }

    static func replacingRoot(in label: String, with newRoot: String) -> String {
        let trimmed = label.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return RootPitch.normalize(newRoot) }

        for root in knownRoots {
            if trimmed.uppercased().hasPrefix(root.uppercased()) {
                let suffix = String(trimmed.dropFirst(root.count))
                return RootPitch.normalize(newRoot) + suffix
            }
        }
        return trimmed
    }

    static func shiftingRoot(in label: String, semitones: Int) -> String {
        guard semitones != 0,
              let root = parsedRoot(from: label),
              let shiftedRoot = RootPitch.transposed(root, semitones: semitones) else {
            return label
        }
        return replacingRoot(in: label, with: shiftedRoot)
    }
}
