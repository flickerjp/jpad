import Foundation
import SwiftUI

/// パフォーマンスモード演出（`PadPerformanceAnimationConfig` 駆動）。
///
/// 待機色のルール:
/// | 向き | 動きあり | 配色 |
/// |------|----------|------|
/// | 縦   | ○        | 5色（プレイリスト） |
/// | 横・上下パターン | ○ | 4グループ位置固定・4色ローテーション＋行波 |
/// | 横・左右 | ○ | 縦と同じ 5色パターン |
/// | 動きを減らす（縦横共通） | 行ごと固定色 |
enum PadPerformanceEffectEngine {
    struct RippleWave: Equatable, Identifiable {
        let id: UUID
        let originCol: Int
        let originRow: Int
        let startedAt: TimeInterval
        /// HOLD: 5 マス = 2 拍でループする伝播タイミング
        let usesHoldLoopTiming: Bool

        init(
            originCol: Int,
            originRow: Int,
            startedAt: TimeInterval,
            usesHoldLoopTiming: Bool = false
        ) {
            id = UUID()
            self.originCol = originCol
            self.originRow = originRow
            self.startedAt = startedAt
            self.usesHoldLoopTiming = usesHoldLoopTiming
        }
    }

    /// 単タップ時: 上下左右 1 マスだけ点滅＋段階減衰。
    struct NeighborBlinkEffect: Equatable, Identifiable {
        let id: UUID
        let originCol: Int
        let originRow: Int
        let startedAt: TimeInterval

        init(originCol: Int, originRow: Int, startedAt: TimeInterval) {
            id = UUID()
            self.originCol = originCol
            self.originRow = originRow
            self.startedAt = startedAt
        }
    }

    struct IdleAppearance: Equatable {
        let colorPhase: Double
        let brightness: Double
    }

    struct RippleAppearance: Equatable {
        let whiteFlash: CGFloat

        static let none = RippleAppearance(whiteFlash: 0)
    }

    // MARK: - Idle

    static func idleAppearance(
        col: Int,
        row: Int,
        columnCount: Int,
        padIndex: Int,
        isLandscape: Bool,
        config: PadPerformanceAnimationConfig,
        time: TimeInterval
    ) -> IdleAppearance {
        let step = Int(floor(time / config.colorShiftDuration))
        let pattern: PadPerformanceScanPattern = isLandscape ? .columnsLeftToRight : .rowsTopToBottom
        return standardPaletteIdleAppearance(
            col: col,
            row: row,
            columnCount: columnCount,
            padIndex: padIndex,
            step: step,
            pattern: pattern,
            config: config
        )
    }

    private static func standardPaletteIdleAppearance(
        col: Int,
        row: Int,
        columnCount: Int,
        padIndex: Int,
        step: Int,
        pattern: PadPerformanceScanPattern,
        config: PadPerformanceAnimationConfig
    ) -> IdleAppearance {
        let paletteIndex = pattern.colorIndex(
            col: col,
            row: row,
            step: step,
            colorCount: PerformancePadPalette.colorCount,
            columnCount: columnCount,
            padIndex: padIndex
        )
        return IdleAppearance(
            colorPhase: Double(paletteIndex),
            brightness: config.idle.baseBrightness
        )
    }

    /// 横画面・上下パターンのみ: 4 グループ＋色ローテーション＋行波。
    private static func landscapeRowGroupIdleAppearance(
        col: Int,
        row: Int,
        columnCount: Int,
        padIndex: Int,
        step: Int,
        pattern: PadPerformanceScanPattern,
        config: PadPerformanceAnimationConfig
    ) -> IdleAppearance {
        let paletteIndex = PerformancePadPalette.paletteIndexForLandscapeRowGroupAnimation(
            padIndex: padIndex,
            step: step
        )
        let waveBand = pattern.colorIndex(
            col: col,
            row: row,
            step: step,
            colorCount: PerformancePadPalette.landscapeGroupColorCount,
            columnCount: columnCount,
            padIndex: padIndex
        )
        let isAccent = positiveMod(waveBand, PerformancePadPalette.landscapeGroupColorCount) == paletteIndex
        let base = config.idle.baseBrightness
        let brightness = base * (isAccent ? 1.26 : 0.74)
        return IdleAppearance(
            colorPhase: Double(paletteIndex),
            brightness: brightness
        )
    }

    private static func positiveMod(_ value: Int, _ modulus: Int) -> Int {
        let m = value % modulus
        return m >= 0 ? m : m + modulus
    }

    static func idleAppearance(
        col: Int,
        row: Int,
        columnCount: Int,
        padIndex: Int,
        isLandscape: Bool,
        config: PadPerformanceAnimationConfig,
        reduceMotion: Bool
    ) -> IdleAppearance {
        if reduceMotion {
            let colorIndex = PerformancePadPalette.paletteIndexForReduceMotionRow(row)
            return IdleAppearance(
                colorPhase: Double(colorIndex),
                brightness: config.idle.baseBrightness
            )
        }
        return idleAppearance(
            col: col,
            row: row,
            columnCount: columnCount,
            padIndex: padIndex,
            isLandscape: isLandscape,
            config: config,
            time: Date.timeIntervalSinceReferenceDate
        )
    }

    // MARK: - Tap

    static func rippleAppearance(
        gridCol: Int,
        gridRow: Int,
        waves: [RippleWave],
        neighborBlinks: [NeighborBlinkEffect],
        columnCount: Int,
        rowCount: Int,
        config: PadPerformanceAnimationConfig,
        time: TimeInterval
    ) -> RippleAppearance {
        var peak: Double = 0
        for wave in waves {
            peak = max(
                peak,
                rippleFlashForWave(
                    gridCol: gridCol,
                    gridRow: gridRow,
                    wave: wave,
                    columnCount: columnCount,
                    rowCount: rowCount,
                    config: config,
                    time: time
                )
            )
        }
        for blink in neighborBlinks {
            peak = max(
                peak,
                neighborBlinkFlash(
                    gridCol: gridCol,
                    gridRow: gridRow,
                    blink: blink,
                    columnCount: columnCount,
                    rowCount: rowCount,
                    config: config,
                    time: time
                )
            )
        }
        guard peak > 0.01 else { return .none }
        return RippleAppearance(whiteFlash: CGFloat(peak))
    }

    static func pruneExpiredNeighborBlinks(
        _ blinks: [NeighborBlinkEffect],
        config: PadPerformanceAnimationConfig,
        time: TimeInterval
    ) -> [NeighborBlinkEffect] {
        let lifetime = config.neighborBlinkTotalDuration
        return blinks.filter { time - $0.startedAt < lifetime }
    }

    static func pruneExpiredWaves(
        _ waves: [RippleWave],
        columnCount: Int,
        rowCount: Int,
        config: PadPerformanceAnimationConfig,
        time: TimeInterval
    ) -> [RippleWave] {
        return waves.filter {
            time - $0.startedAt < waveMaxLifetime(
                $0,
                columnCount: columnCount,
                rowCount: rowCount,
                config: config
            )
        }
    }

    private static func holdRippleHopIntervalCount(
        config: PadPerformanceAnimationConfig
    ) -> Int {
        config.holdLoopHopCount
    }

    private static func waveMaxLifetime(
        _ wave: RippleWave,
        columnCount: Int,
        rowCount: Int,
        config: PadPerformanceAnimationConfig
    ) -> TimeInterval {
        if wave.usesHoldLoopTiming {
            return config.holdLoopRepeatInterval + config.rippleFlashDuration
        }
        return Double(config.ripple.maxGridDistance) * config.rippleHopDuration
            + config.rippleFlashDuration
    }

    private static func rippleFlashForWave(
        gridCol: Int,
        gridRow: Int,
        wave: RippleWave,
        columnCount: Int,
        rowCount: Int,
        config: PadPerformanceAnimationConfig,
        time: TimeInterval
    ) -> Double {
        let arrivalTime: TimeInterval
        if wave.usesHoldLoopTiming {
            guard let hop = PadGridLayoutGeometry.holdRippleHopIndex(
                cell: (gridCol, gridRow),
                origin: (wave.originCol, wave.originRow),
                columnCount: columnCount,
                rowCount: rowCount,
                maxHop: config.holdLoopHopCount
            ) else { return 0 }

            let intervalCount = holdRippleHopIntervalCount(config: config)
            let hopDuration = config.holdRippleHopDuration(pathHopCount: intervalCount)
            arrivalTime = wave.startedAt + Double(hop - 1) * hopDuration
        } else {
            let distance = PadGridLayoutGeometry.manhattanDistance(
                from: (wave.originCol, wave.originRow),
                to: (gridCol, gridRow)
            )
            guard distance <= config.ripple.maxGridDistance else { return 0 }
            arrivalTime = wave.startedAt + Double(distance) * config.rippleHopDuration
        }

        let localTime = time - arrivalTime
        guard localTime >= 0, localTime < config.rippleFlashDuration else { return 0 }

        let isOriginCell = gridCol == wave.originCol && gridRow == wave.originRow
        return whiteFlashStrength(
            localTime: localTime,
            config: config,
            isOriginCell: isOriginCell
        )
    }

    private static func neighborBlinkFlash(
        gridCol: Int,
        gridRow: Int,
        blink: NeighborBlinkEffect,
        columnCount: Int,
        rowCount: Int,
        config: PadPerformanceAnimationConfig,
        time: TimeInterval
    ) -> Double {
        guard PadGridLayoutGeometry.isOrthogonalNeighbor(
            origin: (blink.originCol, blink.originRow),
            cell: (gridCol, gridRow),
            columnCount: columnCount,
            rowCount: rowCount
        ) else { return 0 }

        let localTime = time - blink.startedAt
        return neighborDoubleBlinkStrength(localTime: localTime, config: config)
    }

    /// 1 回目点滅 → 2 回目 80% → 20% 刻みで白レイヤーを下げ PAD 色を見せる。
    private static func neighborDoubleBlinkStrength(
        localTime: TimeInterval,
        config: PadPerformanceAnimationConfig
    ) -> Double {
        let total = config.neighborBlinkTotalDuration
        guard total > 0, localTime >= 0, localTime < total else { return 0 }

        let blink = config.neighborBlink
        let blinkDuration = config.beatDuration * blink.blinkDurationBeats
        guard blinkDuration > 0 else { return 0 }

        let attackFraction = blink.attackFractionOfBlink

        if localTime < blinkDuration {
            return neighborBlinkOnStrength(
                localTime: localTime,
                blinkDuration: blinkDuration,
                peak: blink.firstBlinkPeakOpacity,
                attackFraction: attackFraction
            )
        }

        let afterFirst = localTime - blinkDuration
        if afterFirst < blinkDuration {
            return neighborBlinkOnStrength(
                localTime: afterFirst,
                blinkDuration: blinkDuration,
                peak: blink.secondBlinkPeakOpacity,
                attackFraction: attackFraction
            )
        }

        let stepDuration = config.beatDuration * blink.decayStepDurationBeats
        guard stepDuration > 0, blink.decayStepOpacity > 0 else { return 0 }

        var stepStart = blinkDuration * 2
        var level = blink.secondBlinkPeakOpacity - blink.decayStepOpacity
        for _ in 0..<blink.decayStepCount {
            guard level >= 0 else { break }
            if localTime < stepStart + stepDuration {
                return level
            }
            stepStart += stepDuration
            level -= blink.decayStepOpacity
        }
        return 0
    }

    /// 点滅のオン区間（前半オン・後半オフ、アタック付き）。
    private static func neighborBlinkOnStrength(
        localTime: TimeInterval,
        blinkDuration: TimeInterval,
        peak: Double,
        attackFraction: Double
    ) -> Double {
        let phase = localTime / blinkDuration
        guard phase < 0.5 else { return 0 }
        let attackSpan = max(0.001, attackFraction)
        let attack = min(1, phase / attackSpan)
        return peak * attack
    }

    /// 次の HOLD ループ波（5 個先で前波と重なる周期）。
    static func nextHoldLoopFireTime(
        after time: TimeInterval,
        config: PadPerformanceAnimationConfig
    ) -> TimeInterval {
        let interval = config.holdLoopRepeatInterval
        guard interval > 0 else { return time }
        return time + interval
    }

    static func holdPulsePhase(
        time: TimeInterval,
        config: PadPerformanceAnimationConfig
    ) -> Double {
        let beatPhase = time / config.beatDuration
        return 0.5 + 0.5 * sin(beatPhase * 2 * .pi)
    }

    // MARK: - Flash envelope

    private static func whiteFlashStrength(
        localTime: TimeInterval,
        config: PadPerformanceAnimationConfig,
        isOriginCell: Bool
    ) -> Double {
        let hop = config.rippleHopDuration
        let attackEnd = hop * config.ripple.attackFractionOfHop
        let sustainEnd = hop * config.ripple.sustainFractionOfHop
        let peak = config.ripple.peakOpacity

        if localTime < attackEnd {
            guard attackEnd > 0 else { return peak }
            if isOriginCell {
                return 1
            }
            return peak * (localTime / attackEnd)
        }
        if localTime < sustainEnd {
            return peak
        }
        let releaseSpan = config.rippleFlashDuration - sustainEnd
        guard releaseSpan > 0 else { return 0 }
        let release = (localTime - sustainEnd) / releaseSpan
        return peak * max(0, 1 - release)
    }
}
