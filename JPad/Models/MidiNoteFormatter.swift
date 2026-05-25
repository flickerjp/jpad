import Foundation

enum MidiNoteFormatter {
    /// TEST NOTE 用（アプリ内表記の C3 = MIDI 48）
    static let testNotePitch: UInt8 = 48

    /// 新規ブランクセット先頭パッド（アプリ内表記の C2 = MIDI 36）
    static let blankStarterFirstPitch: UInt8 = 36

    static func format(_ noteNumber: UInt8) -> String {
        let value = Int(noteNumber)
        let name = RootPitch.displayName(forPitchClass: value % 12)
        let octave = value / 12 - 1
        return "\(name)\(octave)"
    }

    static func formatList(_ notes: [UInt8]) -> String {
        notes.sorted().map { format($0) }.joined(separator: ", ")
    }

    static func parseList(_ text: String) throws -> [UInt8] {
        let parts = text.split { $0 == "," || $0 == " " || $0 == "\n" || $0 == "\t" || $0 == ";" }
        guard !parts.isEmpty else { return [] }

        var notes: [UInt8] = []
        notes.reserveCapacity(parts.count)
        for part in parts {
            let token = String(part).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !token.isEmpty else { continue }
            notes.append(try MidiNoteParser.parse(token))
        }
        return notes
    }
}
