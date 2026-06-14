import Foundation

/// RIFF / SEQ のステップクロックのテンポ源。
/// 外部同期は MIDI Clock (24 ppqn) 受信。アプリ全体の設定（AppStorage）で切り替える。
enum PadClockTempoSource: String, Codable {
    case internalClock = "internal"
    case midiClock = "midiClock"
}

/// RIFF 1 スロットぶんのパターン。16 ステップ × 4 声部 (U/M1/M2/L) と発音ゲート長。
struct RiffPatternSlot: Codable, Equatable {
    static let stepCount = 16
    static let voiceCount = 4
    static let gateRange = 0.05 ... 1.0

    /// `steps[voice][step]`。voice 0 = Upper, 1 = Middle 1, 2 = Middle 2, 3 = Lower。
    var steps: [[Bool]]
    /// `ties[voice][step]`。true のステップは直前ステップから音を伸ばし、再発音しない。
    var ties: [[Bool]]
    /// 1 ステップ長に対する発音長の割合。
    var gate: Double

    static let `default` = RiffPatternSlot()

    init(steps: [[Bool]] = [], ties: [[Bool]] = [], gate: Double = 0.6) {
        self.steps = Self.normalizedSteps(steps)
        self.ties = Self.normalizedTies(ties, steps: self.steps)
        self.gate = Self.gateRange.clampValue(gate)
    }

    enum CodingKeys: String, CodingKey {
        case steps, ties, gate
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let rawSteps = try container.decodeIfPresent([[Bool]].self, forKey: .steps) ?? []
        let rawTies = try container.decodeIfPresent([[Bool]].self, forKey: .ties) ?? []
        let rawGate = try container.decodeIfPresent(Double.self, forKey: .gate) ?? 0.6
        self.init(steps: rawSteps, ties: rawTies, gate: rawGate)
    }

    var isEmpty: Bool {
        steps.allSatisfy { row in row.allSatisfy { !$0 } }
    }

    func toggling(voice: Int, step: Int) -> RiffPatternSlot {
        guard steps.indices.contains(voice), steps[voice].indices.contains(step) else { return self }
        var updated = steps
        updated[voice][step].toggle()
        return RiffPatternSlot(steps: updated, ties: ties, gate: gate)
    }

    func setting(voice: Int, step: Int, isOn: Bool) -> RiffPatternSlot {
        guard steps.indices.contains(voice), steps[voice].indices.contains(step) else { return self }
        guard steps[voice][step] != isOn else { return self }
        var updated = steps
        updated[voice][step] = isOn
        return RiffPatternSlot(steps: updated, ties: ties, gate: gate)
    }

    func settingTie(voice: Int, step: Int, isOn: Bool) -> RiffPatternSlot {
        guard ties.indices.contains(voice), ties[voice].indices.contains(step) else { return self }
        var updated = ties
        updated[voice][step] = isOn
        return RiffPatternSlot(steps: steps, ties: updated, gate: gate)
    }

    func canTie(voice: Int, step: Int) -> Bool {
        guard steps.indices.contains(voice),
              steps[voice].indices.contains(step),
              steps[voice][step]
        else { return false }
        let previousStep = Self.previousStepIndex(for: step)
        return steps[voice][previousStep]
    }

    func isTie(voice: Int, step: Int) -> Bool {
        guard canTie(voice: voice, step: step),
              ties.indices.contains(voice),
              ties[voice].indices.contains(step)
        else { return false }
        return ties[voice][step]
    }

    func tiedStepLength(voice: Int, from step: Int) -> Int {
        guard steps.indices.contains(voice),
              steps[voice].indices.contains(step),
              steps[voice][step]
        else { return 1 }

        var length = 1
        var next = Self.nextStepIndex(for: step)
        while next != step,
              length < Self.stepCount,
              steps[voice][next],
              isTie(voice: voice, step: next) {
            length += 1
            next = Self.nextStepIndex(for: next)
        }
        return length
    }

    func maskedRepeatingFirstHalf() -> RiffPatternSlot {
        let halfCount = Self.stepCount / 2
        var updatedSteps = steps
        var updatedTies = ties

        for voice in 0 ..< Self.voiceCount {
            guard updatedSteps.indices.contains(voice),
                  updatedTies.indices.contains(voice)
            else { continue }
            for step in 0 ..< halfCount {
                let repeatedStep = step + halfCount
                guard updatedSteps[voice].indices.contains(step),
                      updatedSteps[voice].indices.contains(repeatedStep),
                      updatedTies[voice].indices.contains(step),
                      updatedTies[voice].indices.contains(repeatedStep)
                else { continue }
                updatedSteps[voice][repeatedStep] = updatedSteps[voice][step]
                updatedTies[voice][repeatedStep] = updatedTies[voice][step]
            }
        }

        return RiffPatternSlot(steps: updatedSteps, ties: updatedTies, gate: gate)
    }

    private static func normalizedSteps(_ raw: [[Bool]]) -> [[Bool]] {
        if raw.count == 3 {
            return [
                normalizedRow(raw[0]),
                normalizedRow(raw[1]),
                normalizedRow([]),
                normalizedRow(raw[2]),
            ]
        }

        return (0 ..< voiceCount).map { voice in
            normalizedRow(voice < raw.count ? raw[voice] : [])
        }
    }

    private static func normalizedRow(_ raw: [Bool]) -> [Bool] {
        var row = Array(raw.prefix(stepCount))
        while row.count < stepCount {
            row.append(false)
        }
        return row
    }

    private static func normalizedTies(_ raw: [[Bool]], steps: [[Bool]]) -> [[Bool]] {
        let normalized: [[Bool]]
        if raw.count == 3 {
            normalized = [
                normalizedRow(raw[0]),
                normalizedRow(raw[1]),
                normalizedRow([]),
                normalizedRow(raw[2]),
            ]
        } else {
            normalized = (0 ..< voiceCount).map { voice in
                normalizedRow(voice < raw.count ? raw[voice] : [])
            }
        }

        return normalized.enumerated().map { voice, row in
            var normalizedRow = row.enumerated().map { step, isTie in
                let previousStep = previousStepIndex(for: step)
                guard isTie,
                      steps.indices.contains(voice),
                      steps[voice].indices.contains(step),
                      steps[voice][step],
                      steps[voice][previousStep]
                else { return false }
                return true
            }

            let onSteps = steps.indices.contains(voice)
                ? steps[voice].indices.filter { steps[voice][$0] }
                : []
            if !onSteps.isEmpty,
               onSteps.allSatisfy({ normalizedRow[$0] }),
               let firstOnStep = onSteps.first {
                normalizedRow[firstOnStep] = false
            }

            return normalizedRow
        }
    }

    private static func previousStepIndex(for step: Int) -> Int {
        (step - 1 + stepCount) % stepCount
    }

    private static func nextStepIndex(for step: Int) -> Int {
        (step + 1) % stepCount
    }
}

struct PresetRiffSettings: Codable, Equatable {
    static let slotCount = 4
    static let baseKeyRange: ClosedRange<Int> = 12 ... 96
    static let `default` = PresetRiffSettings()

    var slots: [RiffPatternSlot]
    var selectedSlotIndex: Int
    /// 基準キー。このノート以上のコード構成音だけを RIFF の対象にする。
    var baseKey: UInt8

    init(
        slots: [RiffPatternSlot] = [],
        selectedSlotIndex: Int = 0,
        baseKey: UInt8 = 12
    ) {
        self.slots = Self.normalizedSlots(slots)
        self.selectedSlotIndex = max(0, min(selectedSlotIndex, Self.slotCount - 1))
        self.baseKey = UInt8(Self.baseKeyRange.clampValue(Int(baseKey)))
    }

    enum CodingKeys: String, CodingKey {
        case slots, selectedSlotIndex, baseKey
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let slots = try container.decodeIfPresent([RiffPatternSlot].self, forKey: .slots) ?? []
        let index = try container.decodeIfPresent(Int.self, forKey: .selectedSlotIndex) ?? 0
        let baseKey = try container.decodeIfPresent(UInt8.self, forKey: .baseKey) ?? 12
        self.init(slots: slots, selectedSlotIndex: index, baseKey: baseKey)
    }

    var selectedSlot: RiffPatternSlot {
        guard slots.indices.contains(selectedSlotIndex) else { return .default }
        return slots[selectedSlotIndex]
    }

    func replacingSelectedSlot(_ slot: RiffPatternSlot) -> PresetRiffSettings {
        var updated = slots
        guard updated.indices.contains(selectedSlotIndex) else { return self }
        updated[selectedSlotIndex] = slot
        return PresetRiffSettings(slots: updated, selectedSlotIndex: selectedSlotIndex, baseKey: baseKey)
    }

    private static func normalizedSlots(_ raw: [RiffPatternSlot]) -> [RiffPatternSlot] {
        var normalized = Array(raw.prefix(slotCount))
        while normalized.count < slotCount {
            normalized.append(.default)
        }
        return normalized
    }
}

/// SEQ の 1 ステップ。pad はパッド index、tie は直前の音の延長、rest は休符。
struct SeqStep: Codable, Equatable {
    enum Kind: String, Codable {
        case pad, tie, rest
    }

    var kind: Kind
    var padIndex: Int?

    static let tie = SeqStep(kind: .tie)
    static let rest = SeqStep(kind: .rest)

    static func pad(_ index: Int) -> SeqStep {
        SeqStep(kind: .pad, padIndex: index)
    }

    init(kind: Kind, padIndex: Int? = nil) {
        self.kind = kind
        self.padIndex = kind == .pad ? padIndex : nil
    }

    enum CodingKeys: String, CodingKey {
        case kind, padIndex
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decodeIfPresent(Kind.self, forKey: .kind) ?? .rest
        let padIndex = try container.decodeIfPresent(Int.self, forKey: .padIndex)
        self.init(kind: kind, padIndex: padIndex)
    }
}

struct SeqPatternSlot: Codable, Equatable {
    static let maxStepCount = 16
    static let `default` = SeqPatternSlot()

    var steps: [SeqStep]

    init(steps: [SeqStep] = []) {
        self.steps = Array(steps.prefix(Self.maxStepCount))
    }

    enum CodingKeys: String, CodingKey {
        case steps
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let steps = try container.decodeIfPresent([SeqStep].self, forKey: .steps) ?? []
        self.init(steps: steps)
    }

    var isFull: Bool {
        steps.count >= Self.maxStepCount
    }

    func appending(_ step: SeqStep) -> SeqPatternSlot {
        guard !isFull else { return self }
        return SeqPatternSlot(steps: steps + [step])
    }

    func removingLast() -> SeqPatternSlot {
        guard !steps.isEmpty else { return self }
        return SeqPatternSlot(steps: Array(steps.dropLast()))
    }
}

struct PresetSeqSettings: Codable, Equatable {
    static let slotCount = 4
    static let gateRange: ClosedRange<Double> = 0.05 ... 1.0
    static let `default` = PresetSeqSettings()

    var slots: [SeqPatternSlot]
    var selectedSlotIndex: Int
    /// 1 ステップ長に対する発音長の割合。短めにすると連打が詰まりにくい。
    var gate: Double

    init(slots: [SeqPatternSlot] = [], selectedSlotIndex: Int = 0, gate: Double = 0.5) {
        self.slots = Self.normalizedSlots(slots)
        self.selectedSlotIndex = max(0, min(selectedSlotIndex, Self.slotCount - 1))
        self.gate = Self.gateRange.clampValue(gate)
    }

    enum CodingKeys: String, CodingKey {
        case slots, selectedSlotIndex, gate
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let slots = try container.decodeIfPresent([SeqPatternSlot].self, forKey: .slots) ?? []
        let index = try container.decodeIfPresent(Int.self, forKey: .selectedSlotIndex) ?? 0
        let gate = try container.decodeIfPresent(Double.self, forKey: .gate) ?? 0.5
        self.init(slots: slots, selectedSlotIndex: index, gate: gate)
    }

    var selectedSlot: SeqPatternSlot {
        guard slots.indices.contains(selectedSlotIndex) else { return .default }
        return slots[selectedSlotIndex]
    }

    func replacingSelectedSlot(_ slot: SeqPatternSlot) -> PresetSeqSettings {
        var updated = slots
        guard updated.indices.contains(selectedSlotIndex) else { return self }
        updated[selectedSlotIndex] = slot
        return PresetSeqSettings(slots: updated, selectedSlotIndex: selectedSlotIndex, gate: gate)
    }

    func updatingGate(_ gate: Double) -> PresetSeqSettings {
        PresetSeqSettings(slots: slots, selectedSlotIndex: selectedSlotIndex, gate: gate)
    }

    private static func normalizedSlots(_ raw: [SeqPatternSlot]) -> [SeqPatternSlot] {
        var normalized = Array(raw.prefix(slotCount))
        while normalized.count < slotCount {
            normalized.append(.default)
        }
        return normalized
    }
}

/// セット単位で保存する RIFF / SEQ の設定一式。BPM は RIFF / SEQ で共有する。
struct PresetSequencerSettings: Codable, Equatable {
    static let bpmRange: ClosedRange<Double> = 40 ... 240
    static let `default` = PresetSequencerSettings()

    var bpm: Double
    var riff: PresetRiffSettings
    var seq: PresetSeqSettings

    init(
        bpm: Double = 120,
        riff: PresetRiffSettings = .default,
        seq: PresetSeqSettings = .default
    ) {
        self.bpm = Self.bpmRange.clampValue(bpm)
        self.riff = riff
        self.seq = seq
    }

    enum CodingKeys: String, CodingKey {
        case bpm, riff, seq
        /// 旧称。RIFF へのリネーム前に保存された preset を読むための互換キー。
        case legacyArp = "arp"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let bpm = try container.decodeIfPresent(Double.self, forKey: .bpm) ?? 120
        let riff = try container.decodeIfPresent(PresetRiffSettings.self, forKey: .riff)
            ?? container.decodeIfPresent(PresetRiffSettings.self, forKey: .legacyArp)
            ?? .default
        let seq = try container.decodeIfPresent(PresetSeqSettings.self, forKey: .seq) ?? .default
        self.init(bpm: bpm, riff: riff, seq: seq)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(bpm, forKey: .bpm)
        try container.encode(riff, forKey: .riff)
        try container.encode(seq, forKey: .seq)
    }
}

private extension ClosedRange where Bound: Comparable {
    func clampValue(_ value: Bound) -> Bound {
        Swift.min(Swift.max(value, lowerBound), upperBound)
    }
}
