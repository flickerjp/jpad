import Foundation

/// 選択ルート + Input Notes からコード名候補を推定する。
/// 全ボイシング由来を先に、ルート音種を除いたボイシング由来を後に並べる。
enum ChordCandidateRecognizer {
    private struct Template {
        let suffix: String
        let required: Set<Int>
        let optional: Set<Int>
        let priority: Int
    }

    private static let templates: [Template] = [
        Template(suffix: "dim7", required: [0, 3, 6, 9], optional: [], priority: 100),
        Template(suffix: "m7b5", required: [0, 3, 6, 10], optional: [], priority: 98),
        Template(suffix: "maj9", required: [0, 4, 7, 11], optional: [2], priority: 94),
        Template(suffix: "m9", required: [0, 3, 7, 10], optional: [2], priority: 94),
        Template(suffix: "9", required: [0, 4, 7, 10], optional: [2], priority: 92),
        Template(suffix: "13", required: [0, 10], optional: [2, 4, 9], priority: 90),
        Template(suffix: "maj7", required: [0, 4, 7, 11], optional: [], priority: 86),
        Template(suffix: "m7", required: [0, 3, 7, 10], optional: [], priority: 86),
        Template(suffix: "7", required: [0, 4, 7, 10], optional: [], priority: 84),
        Template(suffix: "dim", required: [0, 3, 6], optional: [], priority: 78),
        Template(suffix: "aug", required: [0, 4, 8], optional: [], priority: 78),
        Template(suffix: "maj", required: [0, 4, 7], optional: [], priority: 72),
        Template(suffix: "m", required: [0, 3, 7], optional: [], priority: 72),
    ]

    static func candidates(forRoot root: String, notes: [UInt8]) -> [String] {
        guard let rootPitchClass = RootPitch.pitchClass(for: root) else { return [] }
        let normalizedRoot = RootPitch.normalize(root)

        let uniqueNotes = Array(Set(notes)).sorted()
        guard !uniqueNotes.isEmpty else { return [] }

        let fullPitchClasses = Set(uniqueNotes.map { Int($0 % 12) })
        let rootlessPitchClasses = Set(
            uniqueNotes
                .filter { Int($0 % 12) != rootPitchClass }
                .map { Int($0 % 12) }
        )

        let fromFullVoicing = matchFromPitchClasses(
            fullPitchClasses,
            rootPitchClass: rootPitchClass,
            rootName: normalizedRoot
        )
        let fromRootlessVoicing = matchFromPitchClasses(
            rootlessPitchClasses,
            rootPitchClass: rootPitchClass,
            rootName: normalizedRoot
        )

        return mergeCandidates(primary: fromFullVoicing, secondary: fromRootlessVoicing)
    }

    private static func matchFromPitchClasses(
        _ pitchClasses: Set<Int>,
        rootPitchClass: Int,
        rootName: String
    ) -> [String] {
        guard pitchClasses.count >= 2 else { return [] }

        var intervals = Set(pitchClasses.map { ($0 - rootPitchClass + 12) % 12 })
        intervals.insert(0)

        return matchTemplates(rootName: rootName, intervals: intervals)
    }

    private static func mergeCandidates(primary: [String], secondary: [String]) -> [String] {
        var seen = Set<String>()
        var merged: [String] = []
        merged.reserveCapacity(primary.count + secondary.count)

        for name in primary + secondary where seen.insert(name).inserted {
            merged.append(name)
        }
        return merged
    }

    private static func matchTemplates(rootName: String, intervals: Set<Int>) -> [String] {
        let guideBonus = guideToneBonus(intervals: intervals)
        var scored: [(name: String, score: Int)] = []

        for template in templates {
            guard template.required.isSubset(of: intervals) else { continue }
            if template.suffix == "13" {
                guard template.optional.intersection(intervals).count >= 1 else { continue }
            }

            let name = rootName + template.suffix
            let extensionBonus = template.optional.intersection(intervals).count * 4
            let score = template.priority + extensionBonus + guideBonus
            scored.append((name, score))
        }

        var seen = Set<String>()
        return scored
            .sorted { lhs, rhs in
                if lhs.score != rhs.score { return lhs.score > rhs.score }
                return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
            }
            .compactMap { entry in
                guard seen.insert(entry.name).inserted else { return nil }
                return entry.name
            }
    }

    private static func guideToneBonus(intervals: Set<Int>) -> Int {
        if intervals.contains(3), intervals.contains(10) { return 10 }
        if intervals.contains(4), intervals.contains(11) { return 10 }
        if intervals.contains(4), intervals.contains(10) { return 10 }
        return 0
    }
}
