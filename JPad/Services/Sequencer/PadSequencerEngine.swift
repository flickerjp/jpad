import Foundation

/// コード構成音を基準キー以上に絞り、U / M / L の 3 声部へグルーピングする。
enum ArpVoiceGrouper {
    /// 戻り値は `[upper, middle, lower]`。基準キーより下の構成音は鳴らさない。
    static func groupedVoices(chordNotes: [UInt8], baseKey: UInt8) -> [[UInt8]] {
        let candidates = Set(chordNotes.filter { $0 >= baseKey }).sorted()
        guard !candidates.isEmpty else { return [[], [], []] }

        // 3 音以下は高い順に U / M / L へ 1 音ずつ。
        if candidates.count <= 3 {
            let highToLow = candidates.reversed()
            var voices: [[UInt8]] = [[], [], []]
            for (slot, note) in highToLow.enumerated() {
                voices[slot] = [note]
            }
            return voices
        }

        // 4 音以上は音程差の大きい 2 箇所で区切り、近い音域どうしを同じ声部にする。
        var gaps: [(index: Int, size: Int)] = []
        for index in 1 ..< candidates.count {
            gaps.append((index, Int(candidates[index]) - Int(candidates[index - 1])))
        }
        let splitIndices = gaps
            .sorted { lhs, rhs in
                lhs.size != rhs.size ? lhs.size > rhs.size : lhs.index < rhs.index
            }
            .prefix(2)
            .map(\.index)
            .sorted()

        var clusters: [[UInt8]] = []
        var start = 0
        for split in splitIndices {
            clusters.append(Array(candidates[start ..< split]))
            start = split
        }
        clusters.append(Array(candidates[start...]))

        // clusters は低い順 → L, M, U に対応するため反転して [U, M, L] にする。
        return clusters.reversed()
    }
}

/// SEQ 再生用に解決済みのイベント列。
struct SeqPlaybackEvent: Equatable {
    /// 発音するノート（休符は空）。
    let notes: [UInt8]
    /// 16 分音符単位の長さ（TIE で延長された合計）。
    let stepLength: Int
}

enum SeqPatternResolver {
    /// SH-101 式の入力列（pad / tie / rest）を再生イベントへ変換する。
    /// 先頭の tie は休符として扱う。長さの合計は入力ステップ数と一致する。
    static func resolve(
        slot: SeqPatternSlot,
        pads: [PadDefinition],
        transposeSemitones: Int
    ) -> [SeqPlaybackEvent] {
        let padsByIndex = Dictionary(uniqueKeysWithValues: pads.map { ($0.index, $0) })
        var events: [SeqPlaybackEvent] = []

        for step in slot.steps {
            switch step.kind {
            case .pad:
                let notes = step.padIndex
                    .flatMap { padsByIndex[$0] }
                    .map { playbackNotes(for: $0, transposeSemitones: transposeSemitones) } ?? []
                events.append(SeqPlaybackEvent(notes: notes, stepLength: 1))
            case .tie:
                if let last = events.last, !last.notes.isEmpty {
                    events[events.count - 1] = SeqPlaybackEvent(
                        notes: last.notes,
                        stepLength: last.stepLength + 1
                    )
                } else {
                    events.append(SeqPlaybackEvent(notes: [], stepLength: 1))
                }
            case .rest:
                events.append(SeqPlaybackEvent(notes: [], stepLength: 1))
            }
        }
        return events
    }

    static func playbackNotes(for pad: PadDefinition, transposeSemitones: Int) -> [UInt8] {
        var seen = Set<UInt8>()
        var ordered: [UInt8] = []
        for note in pad.bassNotes + pad.chordNotes {
            let shifted = Int(note) + transposeSemitones
            guard (0 ... 127).contains(shifted) else { continue }
            let value = UInt8(shifted)
            guard seen.insert(value).inserted else { continue }
            ordered.append(value)
        }
        return ordered
    }
}

/// ARP / SEQ の共用ステップクロックエンジン。
/// 発音は noteOn / noteOff クロージャ経由（MidiOutputService の preview note API を想定。
/// 同 API は ref count 管理なので、ゲートの重なりがあってもノートが消えすぎない）。
@MainActor
final class PadSequencerEngine: ObservableObject {
    @Published private(set) var arpActivePadID: Int?
    @Published private(set) var isSeqPlaying = false
    /// 再生中の SEQ ステップ位置（16 分音符単位、UI 表示用）。
    @Published private(set) var seqCurrentRawStep: Int?

    var noteOn: (UInt8) -> Void = { _ in }
    var noteOff: (UInt8) -> Void = { _ in }
    var notesOn: ([UInt8]) -> Void = { _ in }
    var notesOff: ([UInt8]) -> Void = { _ in }
    /// 16 分音符 1 個ぶんの秒数。内部 BPM / MIDI Clock 追従の解決は呼び出し側が行う。
    var stepInterval: () -> TimeInterval = { 0.125 }
    /// SEQ のゲート長。短いほど連打時に音が詰まりにくい。
    var seqGate: () -> Double = { 0.5 }

    // MARK: - ARP

    private var arpPattern: ArpPatternSlot = .default
    private var arpVoices: [[UInt8]] = [[], [], []]
    private var arpStepIndex = 0
    private var arpGeneration = 0

    func startArp(padID: Int, voices: [[UInt8]], pattern: ArpPatternSlot) {
        stopArpNotes()
        arpActivePadID = padID
        arpVoices = voices
        arpPattern = pattern
        arpStepIndex = 0
        arpGeneration += 1
        let generation = arpGeneration
        fireArpStep()
        scheduleNextArpStep(after: ContinuousClock.now, generation: generation)
    }

    /// 演奏中のパターン/スロット差し替え（次のステップから反映）。
    func updateArpPattern(_ pattern: ArpPatternSlot) {
        arpPattern = pattern
    }

    func stopArp() {
        arpGeneration += 1
        arpActivePadID = nil
        stopArpNotes()
    }

    private func scheduleNextArpStep(after reference: ContinuousClock.Instant, generation: Int) {
        let deadline = reference.advanced(by: .seconds(stepInterval()))
        Task.detached(priority: .userInitiated) { [weak self] in
            try? await Task.sleep(until: deadline, clock: .continuous)
            await MainActor.run {
                guard let self, generation == self.arpGeneration else { return }
                self.arpStepIndex = (self.arpStepIndex + 1) % ArpPatternSlot.stepCount
                self.fireArpStep()
                self.scheduleNextArpStep(after: deadline, generation: generation)
            }
        }
    }

    private func fireArpStep() {
        let step = arpStepIndex
        let interval = stepInterval()
        let gateDuration = max(0.01, interval * arpPattern.gate)
        let generation = arpGeneration

        for voice in 0 ..< ArpPatternSlot.voiceCount {
            guard arpPattern.steps.indices.contains(voice),
                  arpPattern.steps[voice].indices.contains(step),
                  arpPattern.steps[voice][step] else { continue }
            let notes = voice < arpVoices.count ? arpVoices[voice] : []
            guard !notes.isEmpty else { continue }
            playGatedNotes(notes, duration: gateDuration, generation: generation, isArp: true)
        }
    }

    private func stopArpNotes() {
        for note in Array(soundingArpNotes.keys) {
            releaseAll(note: note, counts: &soundingArpNotes)
        }
    }

    // MARK: - SEQ

    private var seqEvents: [SeqPlaybackEvent] = []
    private var seqRawStepCount = 0
    private var seqEventIndex = 0
    private var seqGeneration = 0

    func startSeq(events: [SeqPlaybackEvent]) {
        stopSeq()
        let rawCount = events.reduce(0) { $0 + $1.stepLength }
        guard rawCount > 0 else { return }
        seqEvents = events
        seqRawStepCount = rawCount
        seqEventIndex = 0
        seqGeneration += 1
        isSeqPlaying = true
        seqCurrentRawStep = 0
        let generation = seqGeneration
        fireSeqEvent()
        scheduleNextSeqEvent(after: ContinuousClock.now, generation: generation)
    }

    /// 再生中のパターン差し替え（現在のループ位置は先頭へ戻す）。
    func replaceSeqEvents(_ events: [SeqPlaybackEvent]) {
        guard isSeqPlaying else { return }
        startSeq(events: events)
    }

    func stopSeq() {
        seqGeneration += 1
        isSeqPlaying = false
        seqCurrentRawStep = nil
        for note in Array(soundingSeqNotes.keys) {
            releaseAll(note: note, counts: &soundingSeqNotes)
        }
    }

    private func scheduleNextSeqEvent(after reference: ContinuousClock.Instant, generation: Int) {
        guard seqEvents.indices.contains(seqEventIndex) else { return }
        let currentLength = seqEvents[seqEventIndex].stepLength
        let deadline = reference.advanced(by: .seconds(stepInterval() * Double(currentLength)))
        Task.detached(priority: .userInitiated) { [weak self] in
            try? await Task.sleep(until: deadline, clock: .continuous)
            await MainActor.run {
                guard let self, generation == self.seqGeneration else { return }
                self.advanceSeq()
                self.fireSeqEvent()
                self.scheduleNextSeqEvent(after: deadline, generation: generation)
            }
        }
    }

    private func advanceSeq() {
        guard !seqEvents.isEmpty else { return }
        seqEventIndex = (seqEventIndex + 1) % seqEvents.count
        let rawPosition = seqEvents.prefix(seqEventIndex).reduce(0) { $0 + $1.stepLength }
        seqCurrentRawStep = rawPosition
    }

    private func fireSeqEvent() {
        guard seqEvents.indices.contains(seqEventIndex) else { return }
        let event = seqEvents[seqEventIndex]
        if seqEventIndex == 0 {
            seqCurrentRawStep = 0
        }
        guard !event.notes.isEmpty else { return }

        let interval = stepInterval()
        let duration = max(0.01, interval * (Double(event.stepLength - 1) + seqGate()))
        playGatedNotes(event.notes, duration: duration, generation: seqGeneration, isArp: false)
    }

    // MARK: - 共通発音

    /// 同じノートのゲートが重なったときに早すぎる Note Off を出さないための計数。
    private var soundingArpNotes: [UInt8: Int] = [:]
    private var soundingSeqNotes: [UInt8: Int] = [:]

    func stopAll() {
        stopArp()
        stopSeq()
    }

    private func playGatedNotes(
        _ notes: [UInt8],
        duration: TimeInterval,
        generation: Int,
        isArp: Bool
    ) {
        var seenNotes = Set<UInt8>()
        let uniqueNotes = notes.filter { seenNotes.insert($0).inserted }
        guard !uniqueNotes.isEmpty else { return }

        notesOn(uniqueNotes)
        for note in uniqueNotes {
            if isArp {
                soundingArpNotes[note, default: 0] += 1
            } else {
                soundingSeqNotes[note, default: 0] += 1
            }
        }

        Task.detached(priority: .userInitiated) { [weak self, notes = uniqueNotes, duration, generation, isArp] in
            try? await Task.sleep(for: .seconds(duration))
            await MainActor.run {
                guard let self else { return }
                let stillRunning = isArp ? generation == self.arpGeneration : generation == self.seqGeneration
                guard stillRunning else { return }
                self.releaseNotes(notes, isArp: isArp)
            }
        }
    }

    private func releaseNotes(_ notes: [UInt8], isArp: Bool) {
        var notesToRelease: [UInt8] = []
        notesToRelease.reserveCapacity(notes.count)

        for note in notes {
            if isArp {
                guard let count = soundingArpNotes[note], count > 0 else { continue }
                soundingArpNotes[note] = count == 1 ? nil : count - 1
            } else {
                guard let count = soundingSeqNotes[note], count > 0 else { continue }
                soundingSeqNotes[note] = count == 1 ? nil : count - 1
            }
            notesToRelease.append(note)
        }

        guard !notesToRelease.isEmpty else { return }
        notesOff(notesToRelease)
    }

    private func releaseAll(note: UInt8, counts: inout [UInt8: Int]) {
        guard let count = counts[note], count > 0 else { return }
        counts[note] = nil
        notesOff(Array(repeating: note, count: count))
    }
}
