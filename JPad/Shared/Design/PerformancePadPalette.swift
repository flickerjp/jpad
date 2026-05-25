import SwiftUI

/// パフォーマンスモード: Launchpad 系 5 色（元の彩度とポップ寄りの中間）。
enum PerformancePadPalette {
    static let colorCount = 5

    static let colorNames = ["coral", "mango", "sky", "mint", "lavender"]

    /// 動きを減らす時（縦横共通）: 行ごとに別色（1 行目は赤 index 0）。
    private static let reduceMotionRowPalette: [Int] = [0, 1, 2, 3, 4]

    /// 横画面・上下アニメ: 4 グループ（PAD 番号の並びは固定、色は step ごとにローテーション）
    static let landscapeGroupColorCount = 4

    static func paletteIndexForReduceMotionRow(_ row: Int) -> Int {
        let index = row % reduceMotionRowPalette.count
        return reduceMotionRowPalette[index]
    }

    /// 1,3,5 → 0 / 2,4,6 → 1 / 7,9,11 → 2 / 8,10,12 → 3
    static func landscapePadGroupIndex(_ padIndex: Int) -> Int {
        switch padIndex {
        case 0, 2, 4: return 0
        case 1, 3, 5: return 1
        case 6, 8, 10: return 2
        case 7, 9, 11: return 3
        default: return 0
        }
    }

    /// グループ位置は固定のまま、4 色が step ごとにずれる（連続 step で同色は同じグループに残らない）
    static func rotatingPaletteIndexForLandscapeGroup(groupIndex: Int, step: Int) -> Int {
        let shift = positiveMod(step, landscapeGroupColorCount)
        return positiveMod(groupIndex + shift, landscapeGroupColorCount)
    }

    static func paletteIndexForLandscapeRowGroupAnimation(padIndex: Int, step: Int) -> Int {
        rotatingPaletteIndexForLandscapeGroup(
            groupIndex: landscapePadGroupIndex(padIndex),
            step: step
        )
    }

    private static func positiveMod(_ value: Int, _ modulus: Int) -> Int {
        let m = value % modulus
        return m >= 0 ? m : m + modulus
    }

    /// メイン画面背景（ダークより一段暗く、パッドの発光を立たせる）
    static var screenBackground: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.02, green: 0.03, blue: 0.06),
                Color(red: 0.01, green: 0.015, blue: 0.03)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    /// Launchpad 系: 連続位相＋明度（待機スキャナー／ビートパルス）
    static func launchpadGradient(colorPhase: Double, brightness: Double, pressed: Bool = false) -> LinearGradient {
        let (lower, upper, mix) = blendIndices(colorPhase: colorPhase)
        let a = palette[lower]
        let b = palette[upper]
        let level = min(1.1, brightness * (pressed ? 1.15 : 1))
        return LinearGradient(
            colors: [
                lerp(a.top, b.top, mix).color.opacity(0.565 + 0.395 * level),
                lerp(a.mid, b.mid, mix).color.opacity(0.61 + 0.35 * level),
                lerp(a.bottom, b.bottom, mix).color.opacity(0.475 + 0.34 * level)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    /// タップリング用の単色（位相から補間）
    static func rippleColor(colorPhase: Double, intensity: Double) -> Color {
        let (lower, upper, mix) = blendIndices(colorPhase: colorPhase)
        let rgb = lerp(palette[lower].mid, palette[upper].mid, mix)
        return rgb.color.opacity(0.525 + 0.415 * intensity)
    }

    static func borderColor(colorPhase: Double, isSelected: Bool) -> Color {
        if isSelected {
            return Color.white.opacity(0.85)
        }
        let (lower, _, mix) = blendIndices(colorPhase: colorPhase)
        return lerp(palette[lower].top, palette[(lower + 1) % colorCount].top, mix).color.opacity(0.515)
    }

    static let labelForeground = Color.white.opacity(0.96)
    static let labelSubtitle = Color.white.opacity(0.72)

    static func holdGlowColor(colorPhase: Double) -> Color {
        let (lower, upper, mix) = blendIndices(colorPhase: colorPhase)
        return lerp(palette[lower].top, palette[upper].top, mix).color
    }

    private static func blendIndices(colorPhase: Double) -> (lower: Int, upper: Int, mix: Double) {
        let count = Double(colorCount)
        let wrapped = colorPhase.truncatingRemainder(dividingBy: count)
        let positive = wrapped < 0 ? wrapped + count : wrapped
        let lower = Int(floor(positive)) % colorCount
        let upper = (lower + 1) % colorCount
        let mix = positive - floor(positive)
        return (lower, upper, mix)
    }

    private struct RGB {
        let r: Double
        let g: Double
        let b: Double

        func lerp(to other: RGB, t: Double) -> RGB {
            RGB(
                r: r + (other.r - r) * t,
                g: g + (other.g - g) * t,
                b: b + (other.b - b) * t
            )
        }

        var color: Color { Color(red: r, green: g, blue: b) }
    }

    private struct PadColorTriplet {
        let top: RGB
        let mid: RGB
        let bottom: RGB
    }

    private static func lerp(_ a: RGB, _ b: RGB, _ t: Double) -> RGB {
        a.lerp(to: b, t: t)
    }

    private static let palette: [PadColorTriplet] = [
        PadColorTriplet(
            top: RGB(r: 1.0, g: 0.47, b: 0.47),
            mid: RGB(r: 0.95, g: 0.30, b: 0.34),
            bottom: RGB(r: 0.685, g: 0.19, b: 0.26)
        ),
        PadColorTriplet(
            top: RGB(r: 1.0, g: 0.70, b: 0.27),
            mid: RGB(r: 0.965, g: 0.53, b: 0.17),
            bottom: RGB(r: 0.78, g: 0.37, b: 0.12)
        ),
        PadColorTriplet(
            top: RGB(r: 0.465, g: 0.81, b: 1.0),
            mid: RGB(r: 0.27, g: 0.615, b: 0.965),
            bottom: RGB(r: 0.16, g: 0.40, b: 0.74)
        ),
        PadColorTriplet(
            top: RGB(r: 0.565, g: 0.98, b: 0.62),
            mid: RGB(r: 0.34, g: 0.86, b: 0.48),
            bottom: RGB(r: 0.20, g: 0.62, b: 0.35)
        ),
        PadColorTriplet(
            top: RGB(r: 0.86, g: 0.615, b: 1.0),
            mid: RGB(r: 0.68, g: 0.41, b: 0.94),
            bottom: RGB(r: 0.46, g: 0.26, b: 0.70)
        )
    ]
}
