import Foundation

/// パフォーマンスモード演出のパラメータ一式（ロジックは `PadPerformanceEffectEngine`）。
struct PadPerformanceAnimationConfig: Equatable, Sendable {
    var timing: Timing = Timing()
    var idle: Idle = Idle()
    var patterns: Patterns = Patterns()
    var ripple: Ripple = Ripple()
    var neighborBlink: NeighborBlink = NeighborBlink()

    static let standard = PadPerformanceAnimationConfig()

    // MARK: - Timing

    struct Timing: Equatable, Sendable {
        /// テンポ（BPM）
        var bpm: Double = 120
        /// 色がずれる周期（拍数）。2 = 二分音符（120 BPM で 1 秒）
        var colorShiftBeats: Double = 2
        /// 白フラッシュのマス間遅延（拍数）。0.5 = 8分音符
        var rippleHopBeats: Double = 0.5
        /// 押し続け／HOLD 時の原点 FLASH 周期の目安（拍数）。ループ周期は `holdRippleHopBeats`×4。
        var holdFlashBeats: Double = 2
        /// HOLD 広がりの 1 ホップ間隔（拍数）。2 = 2分音符 @ 120 BPM
        var holdRippleHopBeats: Double = 2
        /// 広がり継続とみなす最短押下（拍数）。1.5 = 2 拍目の半分
        var holdFlashQualificationBeats: Double = 1.5
    }

    var beatDuration: TimeInterval {
        guard timing.bpm > 0 else { return 0.5 }
        return 60 / timing.bpm
    }

    /// 持続 FLASH の間隔（秒）。`holdFlashBeats` 拍ぶん。
    var holdFlashInterval: TimeInterval {
        beatDuration * timing.holdFlashBeats
    }

    /// 広がり継続の判定までの時間（秒）。`holdFlashQualificationBeats` 拍ぶん。
    var holdFlashQualificationInterval: TimeInterval {
        beatDuration * timing.holdFlashQualificationBeats
    }

    var colorShiftDuration: TimeInterval {
        beatDuration * timing.colorShiftBeats
    }

    var rippleHopDuration: TimeInterval {
        beatDuration * timing.rippleHopBeats
    }

    /// HOLD ループ周期（拍）。4 ホップ × `holdRippleHopBeats`（既定 8 拍）。
    var holdLoopRepeatBeats: Double {
        Double(holdLoopHopCount) * timing.holdRippleHopBeats
    }

    /// 1 周のホップ数（チェビシェフ輪 1→4。5 ホップ目は使わない）。
    var holdLoopHopCount: Int = 4

    var holdLoopRepeatInterval: TimeInterval {
        beatDuration * holdLoopRepeatBeats
    }

    /// HOLD 伝播の 1 ホップ（拍）。
    func holdRippleHopBeats(pathHopCount: Int) -> Double {
        timing.holdRippleHopBeats
    }

    func holdRippleHopDuration(pathHopCount: Int) -> TimeInterval {
        beatDuration * timing.holdRippleHopBeats
    }

    // MARK: - Idle

    struct Idle: Equatable, Sendable {
        var baseBrightness: Double = 0.68
    }

    // MARK: - Patterns

    struct Patterns: Equatable, Sendable {
        /// この秒数ごとにプレイリストの次パターンへ
        var cycleDuration: TimeInterval = 4
        var playlist: [PadPerformanceScanPattern] = .defaultPlaylist
        var advance: Advance = .sequential
        var colorSeed: UInt64 = 12_345

        enum Advance: Equatable, Sendable {
            case sequential
            case random
        }

        func epoch(at time: TimeInterval) -> Int {
            Int(floor(time / max(cycleDuration, 0.001)))
        }

        func patternCycle(at time: TimeInterval) -> PatternCycle {
            let epoch = epoch(at: time)
            return PatternCycle(
                epoch: epoch,
                pattern: scanPattern(forEpoch: epoch)
            )
        }

        func pattern(at time: TimeInterval) -> PadPerformanceScanPattern {
            scanPattern(forEpoch: epoch(at: time))
        }

        func scanPattern(forEpoch epoch: Int) -> PadPerformanceScanPattern {
            guard !playlist.isEmpty else { return .columnsLeftToRight }
            let index: Int
            switch advance {
            case .sequential:
                index = Self.positiveMod(epoch, playlist.count)
            case .random:
                let hash = UInt64(epoch) &* 1_103_515_245 &+ colorSeed
                index = Int(hash % UInt64(playlist.count))
            }
            return playlist[index]
        }

        private static func positiveMod(_ value: Int, _ modulus: Int) -> Int {
            let m = value % modulus
            return m >= 0 ? m : m + modulus
        }
    }

    /// 1 周期分のスキャンパターン
    struct PatternCycle: Equatable, Sendable {
        let epoch: Int
        let pattern: PadPerformanceScanPattern
    }

    // MARK: - Ripple

    struct Ripple: Equatable, Sendable {
        /// 同時に再生するリングの上限（超えたら古い順に削除）
        var maxConcurrentWaves: Int = 24
        /// Oneshot 広がりの最大マンハッタン距離
        var maxGridDistance: Int = 5
        /// 各マスの白フラッシュ長さ（拍数）
        var flashDurationBeats: Double = 0.4
        var peakOpacity: Double = 0.88
        /// 1ホップ内のアタック長さ（ホップに対する比率）
        var attackFractionOfHop: Double = 0.12
        /// 1ホップ内のサステイン終了（ホップに対する比率）
        var sustainFractionOfHop: Double = 0.55
    }

    var rippleFlashDuration: TimeInterval {
        beatDuration * ripple.flashDurationBeats
    }

    // MARK: - Neighbor blink (single tap)

    struct NeighborBlink: Equatable, Sendable {
        /// 1 回の点滅長（拍）。0.5 = 8分音符
        var blinkDurationBeats: Double = 0.5
        /// 1 回目の白レイヤー強度（0…1、下の PAD 色はそのまま透けて見える）
        var firstBlinkPeakOpacity: Double = 0.88
        /// 2 回目
        var secondBlinkPeakOpacity: Double = 0.8
        /// 2 回目以降の減衰：この量ずつ段階的に下げる（0.2 = 20%）
        var decayStepOpacity: Double = 0.2
        /// 減衰 1 段の長さ（拍）
        var decayStepDurationBeats: Double = 0.25
        /// 点滅の立ち上がり（各オン区間の先頭比率）
        var attackFractionOfBlink: Double = 0.12

        var decayStepCount: Int {
            guard decayStepOpacity > 0 else { return 0 }
            return Int(ceil(secondBlinkPeakOpacity / decayStepOpacity))
        }
    }

    /// 点滅 2 回 + 段階減衰までの合計（秒）
    var neighborBlinkTotalDuration: TimeInterval {
        let n = neighborBlink
        let beats = n.blinkDurationBeats * 2
            + Double(n.decayStepCount) * n.decayStepDurationBeats
        return beatDuration * beats
    }

}

extension PadPerformanceAnimationConfig {
    /// プレイリストを差し替えたコピー。
    func withPlaylist(_ playlist: [PadPerformanceScanPattern]) -> Self {
        var copy = self
        copy.patterns.playlist = playlist
        return copy
    }

    /// パターン切替間隔だけ変える。
    func withPatternCycleDuration(_ seconds: TimeInterval) -> Self {
        var copy = self
        copy.patterns.cycleDuration = seconds
        return copy
    }

    /// テンポと伝播・色ずれの拍数をまとめて変える。
    func withTiming(
        bpm: Double,
        colorShiftBeats: Double? = nil,
        rippleHopBeats: Double? = nil
    ) -> Self {
        var copy = self
        copy.timing.bpm = bpm
        if let colorShiftBeats { copy.timing.colorShiftBeats = colorShiftBeats }
        if let rippleHopBeats { copy.timing.rippleHopBeats = rippleHopBeats }
        return copy
    }
}
