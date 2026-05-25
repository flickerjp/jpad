import Foundation

/// 3×4 グリッド上のパッド配置（`displayOrder` の並び = 行優先スロット 0…11）。
enum PadGridLayoutGeometry {
    static let padCount = 12

    /// 時計回り外周＋内側2マス（Orbit Flow の通過順）
    static let portraitOrbitSlotOrder = [0, 1, 2, 5, 8, 11, 10, 9, 6, 3, 4, 7]

    /// 横画面 6×2（外周を時計回り）
    static let landscapeOrbitSlotOrder = [0, 1, 2, 3, 4, 5, 11, 10, 9, 8, 7, 6]

    static func orbitSlotOrder(isLandscape: Bool) -> [Int] {
        isLandscape ? landscapeOrbitSlotOrder : portraitOrbitSlotOrder
    }

    static func gridCoordinate(slot: Int, columnCount: Int) -> (col: Int, row: Int) {
        (col: slot % columnCount, row: slot / columnCount)
    }

    static func orbitIndex(forSlot slot: Int, isLandscape: Bool) -> Int {
        let order = orbitSlotOrder(isLandscape: isLandscape)
        return order.firstIndex(of: slot) ?? slot
    }

    static func manhattanDistance(
        from origin: (col: Int, row: Int),
        to target: (col: Int, row: Int)
    ) -> Int {
        abs(target.col - origin.col) + abs(target.row - origin.row)
    }

    /// 上下左右・斜めの 1 マス先（チェビシェフ距離 1）。
    static func isAdjacentNeighbor(
        origin: (col: Int, row: Int),
        cell: (col: Int, row: Int),
        columnCount: Int,
        rowCount: Int
    ) -> Bool {
        let dc = abs(cell.col - origin.col)
        let dr = abs(cell.row - origin.row)
        guard max(dc, dr) == 1 else { return false }
        return cell.col >= 0
            && cell.col < columnCount
            && cell.row >= 0
            && cell.row < rowCount
    }

    /// 上下左右のみ 1 マス先（斜めは含まない）。
    static func isOrthogonalNeighbor(
        origin: (col: Int, row: Int),
        cell: (col: Int, row: Int),
        columnCount: Int,
        rowCount: Int
    ) -> Bool {
        let dc = abs(cell.col - origin.col)
        let dr = abs(cell.row - origin.row)
        guard dc + dr == 1 else { return false }
        return cell.col >= 0
            && cell.col < columnCount
            && cell.row >= 0
            && cell.row < rowCount
    }

    static func rowCount(columnCount: Int) -> Int {
        (padCount + columnCount - 1) / columnCount
    }

    /// 原点から最も遠いスロットまでのマンハッタン距離（縦 PAD01→PAD12 は 5）。
    static func maxManhattanSpan(
        origin: (col: Int, row: Int),
        columnCount: Int,
        rowCount: Int
    ) -> Int {
        var span = 0
        for col in 0..<columnCount {
            for row in 0..<rowCount {
                span = max(
                    span,
                    manhattanDistance(from: origin, to: (col, row))
                )
            }
        }
        return span
    }

    static func chebyshevDistance(
        from origin: (col: Int, row: Int),
        to cell: (col: Int, row: Int)
    ) -> Int {
        max(abs(cell.col - origin.col), abs(cell.row - origin.row))
    }

    /// HOLD 広がり: チェビシェフ（王手）距離の輪。ホップ n = 距離 n−1（常に 4 ホップまで）。
    static func holdRippleHopIndex(
        cell: (col: Int, row: Int),
        origin: (col: Int, row: Int),
        columnCount: Int,
        rowCount: Int,
        maxHop: Int
    ) -> Int? {
        guard cell.col >= 0, cell.col < columnCount, cell.row >= 0, cell.row < rowCount else {
            return nil
        }

        let hop = chebyshevDistance(from: origin, to: cell) + 1
        guard hop <= maxHop else { return nil }
        return hop
    }
}
