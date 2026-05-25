import Foundation

enum RootPitch {
    static let pitchClassNames = ["C", "C#", "D", "Eb", "E", "F", "F#", "G", "Ab", "A", "Bb", "B"]

    /// UI 上のルート名（D# / G# / A# はフラット表記に統一）
    static func normalize(_ root: String) -> String {
        switch root {
        case "D#": return "Eb"
        case "G#": return "Ab"
        case "A#": return "Bb"
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
}

enum ChordLabel {
    private static let knownRoots = ["C#", "D#", "F#", "G#", "A#", "Eb", "Ab", "Bb", "C", "D", "E", "F", "G", "A", "B"]

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
}
