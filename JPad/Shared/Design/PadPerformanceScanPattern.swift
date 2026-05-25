import Foundation

/// 待機アニメの1パターン（行／列の色シフトロジック）。
enum PadPerformanceScanPattern: String, CaseIterable, Identifiable, Codable, Sendable {
    case columnsLeftToRight
    case columnsRightToLeft
    case rowsTopToBottom
    case rowsBottomToTop

    var id: String { rawValue }

    /// 横画面で PAD 4 グループ色＋明るさ波を使うのは上下（行）パターンのみ。
    var usesLandscapePadGroupColors: Bool {
        switch self {
        case .rowsTopToBottom, .rowsBottomToTop:
            return true
        case .columnsLeftToRight, .columnsRightToLeft:
            return false
        }
    }

    /// 行／列ごとに同色で、step ごとに色インデックスがずれる。
    /// - Parameter padIndex: パッド番号 0…11（1–6 / 7–12 の分割）。未指定時はグリッドスロット。
    func colorIndex(
        col: Int,
        row: Int,
        step: Int,
        colorCount: Int,
        columnCount: Int = PadGridLayoutGeometry.padCount / 2,
        padIndex: Int? = nil
    ) -> Int {
        switch self {
        case .columnsLeftToRight:
            return Self.splitColumnColorIndex(
                col: col,
                row: row,
                padIndex: padIndex,
                step: step,
                colorCount: colorCount,
                columnCount: columnCount,
                firstHalfMovesLeftToRight: true
            )
        case .columnsRightToLeft:
            return Self.splitColumnColorIndex(
                col: col,
                row: row,
                padIndex: padIndex,
                step: step,
                colorCount: colorCount,
                columnCount: columnCount,
                firstHalfMovesLeftToRight: false
            )
        case .rowsTopToBottom:
            return Self.positiveMod(row + step, colorCount)
        case .rowsBottomToTop:
            return Self.positiveMod(row - step, colorCount)
        }
    }

    /// パッド 1–6（index 0…5）と 7–12（6…11）で列シフトの向きを反対にする。
    private static func splitColumnColorIndex(
        col: Int,
        row: Int,
        padIndex: Int?,
        step: Int,
        colorCount: Int,
        columnCount: Int,
        firstHalfMovesLeftToRight: Bool
    ) -> Int {
        let slot = padIndex ?? (row * max(columnCount, 1) + col)
        let isFirstHalf = slot < padCount / 2
        let leftToRight = isFirstHalf ? firstHalfMovesLeftToRight : !firstHalfMovesLeftToRight
        if leftToRight {
            return positiveMod(col - step, colorCount)
        }
        return positiveMod(col + step, colorCount)
    }

    private static var padCount: Int { PadGridLayoutGeometry.padCount }

    private static func positiveMod(_ value: Int, _ modulus: Int) -> Int {
        let m = value % modulus
        return m >= 0 ? m : m + modulus
    }
}

extension [PadPerformanceScanPattern] {
    /// 左右・上下を織り交ぜた既定プレイリスト。
    static let defaultPlaylist: [PadPerformanceScanPattern] = [
        .columnsLeftToRight,
        .rowsTopToBottom,
        .columnsRightToLeft,
        .rowsBottomToTop,
        .columnsLeftToRight,
        .rowsTopToBottom,
        .columnsRightToLeft,
        .rowsBottomToTop
    ]
}
