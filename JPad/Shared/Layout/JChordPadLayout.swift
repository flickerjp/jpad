import SwiftUI
import UIKit

enum JChordPhoneHeightClass {
    case compact
    case regular
    case large

    init(height: CGFloat) {
        if height < 720 {
            self = .compact
        } else if height >= 880 {
            self = .large
        } else {
            self = .regular
        }
    }
}

struct JChordPadLayout {
    let isLandscape: Bool
    let isPadDevice: Bool
    let columnCount: Int
    let rowCount: Int
    let horizontalPadding: CGFloat
    let gridSpacing: CGFloat

    static let interSectionMinSpacing: CGFloat = 8
    /// ヘッダー直下のみ他セクション間隔の 1/2
    static let headerToPadSpacerWeight: CGFloat = 0.5
    /// 大型 iPhone 横画面は PAD 優先でヘッダー下余白を詰める
    static let headerToPadSpacerWeightPhoneLandscapeBoost: CGFloat = 0.25
    static let standardInterSectionSpacerWeight: CGFloat = 1
    /// iPhone 横画面 PAD 拡大（iPad は幅キャップのみ）
    private static let boostedPhoneLongSideThreshold: CGFloat = 852

    let cellSide: CGFloat
    let topBarHeight: CGFloat
    let gearIconSize: CGFloat
    let midiSliderLabelSize: CGFloat
    let midiSliderLabelWidth: CGFloat
    let midiSliderLabelSpacing: CGFloat
    let midiSliderRowHeight: CGFloat
    let noteOffHeight: CGFloat
    let noteOffFontSize: CGFloat
    let padCornerRadius: CGFloat
    let padContentPadding: CGFloat
    let headerToPadSpacerWeight: CGFloat
    let landscapeControlPanelWidth: CGFloat
    let landscapeDockWidth: CGFloat
    let landscapeTransposeButtonHeight: CGFloat
    let landscapeTransposeLabelFontSize: CGFloat
    let landscapeTransposeValueFontSize: CGFloat

    static func make(size: CGSize, safeArea: EdgeInsets) -> JChordPadLayout {
        let isLandscape = size.width > size.height
        let availableWidth = isLandscape
            ? size.width
            : max(0, size.width - safeArea.leading - safeArea.trailing)
        let availableHeight = isLandscape
            ? size.height
            : max(0, size.height - safeArea.top - safeArea.bottom)
        let heightClass = JChordPhoneHeightClass(height: availableHeight)
        let isPadDevice = UIDevice.current.userInterfaceIdiom == .pad

        if isLandscape {
            return landscape(
                availableWidth: availableWidth,
                availableHeight: availableHeight,
                heightClass: heightClass,
                layoutLongSide: max(size.width, size.height),
                isPadDevice: isPadDevice
            )
        }

        return portrait(
            availableWidth: availableWidth,
            availableHeight: availableHeight,
            heightClass: heightClass,
            isPadDevice: isPadDevice
        )
    }

    private static func portrait(
        availableWidth: CGFloat,
        availableHeight: CGFloat,
        heightClass: JChordPhoneHeightClass,
        isPadDevice: Bool
    ) -> JChordPadLayout {
        let columnCount = 3
        let rowCount = 4
        let metrics = portraitMetrics(for: heightClass)
        let sliderChrome = metrics.midiSliderRowHeight * 2
        let contentAreaHeight = availableHeight - metrics.topBarHeight - metrics.noteOffHeight

        let fit = fitCellAndGap(
            columnCount: columnCount,
            rowCount: rowCount,
            gridSpacing: metrics.gridSpacing,
            widthBudget: max(0, availableWidth - metrics.horizontalPadding * 2),
            availableHeight: contentAreaHeight,
            baseChrome: sliderChrome,
            sectionGapWeight: headerToPadSpacerWeight + standardInterSectionSpacerWeight * 3,
            minCell: metrics.minCell
        )

        let cellSide = isPadDevice
            ? max(max(48, metrics.minCell - 6), floor(fit * 0.91))
            : fit

        return JChordPadLayout(
            isLandscape: false,
            isPadDevice: isPadDevice,
            columnCount: columnCount,
            rowCount: rowCount,
            horizontalPadding: metrics.horizontalPadding,
            gridSpacing: metrics.gridSpacing,
            cellSide: cellSide,
            topBarHeight: metrics.topBarHeight,
            gearIconSize: metrics.gearIconSize,
            midiSliderLabelSize: metrics.midiSliderLabelSize,
            midiSliderLabelWidth: metrics.midiSliderLabelWidth,
            midiSliderLabelSpacing: metrics.midiSliderLabelSpacing,
            midiSliderRowHeight: metrics.midiSliderRowHeight,
            noteOffHeight: metrics.noteOffHeight,
            noteOffFontSize: metrics.noteOffFontSize,
            padCornerRadius: max(14, cellSide * 0.16),
            padContentPadding: max(8, cellSide * 0.11),
            headerToPadSpacerWeight: Self.headerToPadSpacerWeight,
            landscapeControlPanelWidth: 0,
            landscapeDockWidth: 0,
            landscapeTransposeButtonHeight: 0,
            landscapeTransposeLabelFontSize: 0,
            landscapeTransposeValueFontSize: 0
        )
    }

    private static func landscape(
        availableWidth: CGFloat,
        availableHeight: CGFloat,
        heightClass: JChordPhoneHeightClass,
        layoutLongSide: CGFloat,
        isPadDevice: Bool
    ) -> JChordPadLayout {
        let columnCount = 4
        let rowCount = 3
        let metrics = landscapeMetrics(for: heightClass)
        let contentAreaHeight = availableHeight
        let panelWidth = metrics.landscapeControlPanelWidth
        let dockWidth = metrics.landscapeDockWidth
        let gridWidthBudget = max(
            0,
            availableWidth
                - metrics.horizontalPadding * 2
                - panelWidth
                - dockWidth
                - metrics.gridSpacing * 2
        )

        let widthCap = floor(
            (gridWidthBudget - metrics.gridSpacing * CGFloat(columnCount - 1)) / CGFloat(columnCount)
        )
        let usesBoost = usesLandscapePadSizeBoost(layoutLongSide: layoutLongSide)
        let headerWeight = usesBoost
            ? Self.headerToPadSpacerWeightPhoneLandscapeBoost
            : Self.headerToPadSpacerWeight
        let fitted = fitCellAndGap(
            columnCount: columnCount,
            rowCount: rowCount,
            gridSpacing: metrics.gridSpacing,
            widthBudget: gridWidthBudget,
            availableHeight: contentAreaHeight,
            baseChrome: 0,
            sectionGapWeight: 0,
            minCell: metrics.minCell
        )
        let cellSide: CGFloat
        if usesBoost {
            let scale = landscapePadSizeScale(for: layoutLongSide)
            let heightSized = floor(fitted * scale)
            // 横方向の余白を減らし、幅上限（widthCap）まで広げる
            let widthSized = min(floor(widthCap * min(scale, 1.08)), widthCap)
            cellSide = max(heightSized, widthSized)
        } else {
            cellSide = min(fitted, widthCap)
        }
        let transposeButtonHeight = floor(
            (CGFloat(rowCount) * cellSide
                + CGFloat(rowCount - 1) * metrics.gridSpacing
                - CGFloat(PresetControlSettings.shiftMemoryCount - 1) * metrics.gridSpacing)
                / CGFloat(PresetControlSettings.shiftMemoryCount)
        )
        return JChordPadLayout(
            isLandscape: true,
            isPadDevice: isPadDevice,
            columnCount: columnCount,
            rowCount: rowCount,
            horizontalPadding: metrics.horizontalPadding,
            gridSpacing: metrics.gridSpacing,
            cellSide: cellSide,
            topBarHeight: metrics.topBarHeight,
            gearIconSize: metrics.gearIconSize,
            midiSliderLabelSize: metrics.midiSliderLabelSize,
            midiSliderLabelWidth: metrics.midiSliderLabelWidth,
            midiSliderLabelSpacing: metrics.midiSliderLabelSpacing,
            midiSliderRowHeight: metrics.midiSliderRowHeight,
            noteOffHeight: metrics.noteOffHeight,
            noteOffFontSize: metrics.noteOffFontSize,
            padCornerRadius: max(12, cellSide * 0.15),
            padContentPadding: max(8, cellSide * 0.1),
            headerToPadSpacerWeight: headerWeight,
            landscapeControlPanelWidth: panelWidth,
            landscapeDockWidth: dockWidth,
            landscapeTransposeButtonHeight: transposeButtonHeight,
            landscapeTransposeLabelFontSize: metrics.landscapeTransposeLabelFontSize,
            landscapeTransposeValueFontSize: metrics.landscapeTransposeValueFontSize
        )
    }

    var gridWidth: CGFloat {
        CGFloat(columnCount) * cellSide + CGFloat(columnCount - 1) * gridSpacing
    }

    var gridHeight: CGFloat {
        CGFloat(rowCount) * cellSide + CGFloat(rowCount - 1) * gridSpacing
    }

    var interSectionSpacerWeightTotal: CGFloat {
        if isLandscape {
            return headerToPadSpacerWeight + Self.standardInterSectionSpacerWeight * 2
        }
        return headerToPadSpacerWeight + Self.standardInterSectionSpacerWeight * 3
    }

    func interSectionSpacerHeights(forAvailableHeight availableHeight: CGFloat) -> (
        headerToPads: CGFloat,
        betweenSections: CGFloat
    ) {
        let sliderChrome = CGFloat(isLandscape ? 1 : 2) * midiSliderRowHeight
        let flex = max(0, availableHeight - gridHeight - sliderChrome)
        let unit = flex / interSectionSpacerWeightTotal
        return (
            headerToPads: max(Self.interSectionMinSpacing * headerToPadSpacerWeight, unit * headerToPadSpacerWeight),
            betweenSections: max(Self.interSectionMinSpacing, unit * Self.standardInterSectionSpacerWeight)
        )
    }

    private struct LayoutMetrics {
        let horizontalPadding: CGFloat
        let gridSpacing: CGFloat
        let topBarHeight: CGFloat
        let gearIconSize: CGFloat
        let midiSliderLabelSize: CGFloat
        let midiSliderLabelWidth: CGFloat
        let midiSliderLabelSpacing: CGFloat
        let midiSliderRowHeight: CGFloat
        let noteOffHeight: CGFloat
        let noteOffFontSize: CGFloat
        let minCell: CGFloat
        let landscapeControlPanelWidth: CGFloat
        let landscapeDockWidth: CGFloat
        let landscapeTransposeButtonHeight: CGFloat
        let landscapeTransposeLabelFontSize: CGFloat
        let landscapeTransposeValueFontSize: CGFloat
    }

    private static let minimumSectionGap: CGFloat = interSectionMinSpacing

    private static func portraitMetrics(for heightClass: JChordPhoneHeightClass) -> LayoutMetrics {
        switch heightClass {
        case .compact:
            return LayoutMetrics(
                horizontalPadding: 12,
                gridSpacing: 7,
                topBarHeight: 44,
                gearIconSize: 22,
                midiSliderLabelSize: 15,
                midiSliderLabelWidth: 88,
                midiSliderLabelSpacing: 10,
                midiSliderRowHeight: 32,
                noteOffHeight: 42,
                noteOffFontSize: 17,
                minCell: 54,
                landscapeControlPanelWidth: 0,
                landscapeDockWidth: 0,
                landscapeTransposeButtonHeight: 0,
                landscapeTransposeLabelFontSize: 0,
                landscapeTransposeValueFontSize: 0
            )
        case .regular:
            return LayoutMetrics(
                horizontalPadding: 14,
                gridSpacing: 9,
                topBarHeight: 50,
                gearIconSize: 24,
                midiSliderLabelSize: 16,
                midiSliderLabelWidth: 92,
                midiSliderLabelSpacing: 10,
                midiSliderRowHeight: 34,
                noteOffHeight: 48,
                noteOffFontSize: 18,
                minCell: 62,
                landscapeControlPanelWidth: 0,
                landscapeDockWidth: 0,
                landscapeTransposeButtonHeight: 0,
                landscapeTransposeLabelFontSize: 0,
                landscapeTransposeValueFontSize: 0
            )
        case .large:
            return LayoutMetrics(
                horizontalPadding: 18,
                gridSpacing: 10,
                topBarHeight: 54,
                gearIconSize: 26,
                midiSliderLabelSize: 17,
                midiSliderLabelWidth: 96,
                midiSliderLabelSpacing: 10,
                midiSliderRowHeight: 36,
                noteOffHeight: 52,
                noteOffFontSize: 20,
                minCell: 72,
                landscapeControlPanelWidth: 0,
                landscapeDockWidth: 0,
                landscapeTransposeButtonHeight: 0,
                landscapeTransposeLabelFontSize: 0,
                landscapeTransposeValueFontSize: 0
            )
        }
    }

    private static func landscapeMetrics(for heightClass: JChordPhoneHeightClass) -> LayoutMetrics {
        switch heightClass {
        case .compact:
            return LayoutMetrics(
                horizontalPadding: 4,
                gridSpacing: 8,
                topBarHeight: 40,
                gearIconSize: 22,
                midiSliderLabelSize: 15,
                midiSliderLabelWidth: 88,
                midiSliderLabelSpacing: 10,
                midiSliderRowHeight: 32,
                noteOffHeight: 40,
                noteOffFontSize: 16,
                minCell: 52,
                landscapeControlPanelWidth: 86,
                landscapeDockWidth: 44,
                landscapeTransposeButtonHeight: 90,
                landscapeTransposeLabelFontSize: 13,
                landscapeTransposeValueFontSize: 17
            )
        case .regular, .large:
            return LayoutMetrics(
                horizontalPadding: 6,
                gridSpacing: 10,
                topBarHeight: 46,
                gearIconSize: 26,
                midiSliderLabelSize: 15,
                midiSliderLabelWidth: 88,
                midiSliderLabelSpacing: 10,
                midiSliderRowHeight: 34,
                noteOffHeight: 46,
                noteOffFontSize: 18,
                minCell: 60,
                landscapeControlPanelWidth: isPadDeviceWidth() ? 108 : 92,
                landscapeDockWidth: isPadDeviceWidth() ? 56 : 48,
                landscapeTransposeButtonHeight: isPadDeviceWidth() ? 108 : 96,
                landscapeTransposeLabelFontSize: 13,
                landscapeTransposeValueFontSize: 17
            )
        }
    }

    private static func isPadDeviceWidth() -> Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }

    /// iPad は幅キャップ。iPhone 14 Pro 以上（長辺 852+、16 Pro は 874）を横画面で拡大。
    private static func usesLandscapePadSizeBoost(layoutLongSide: CGFloat) -> Bool {
        guard UIDevice.current.userInterfaceIdiom == .phone else { return false }
        return layoutLongSide >= boostedPhoneLongSideThreshold
    }

    /// 16 Pro / Pro Max クラスほど大きく（理想レイアウトに近づける）
    private static func landscapePadSizeScale(for layoutLongSide: CGFloat) -> CGFloat {
        if layoutLongSide >= 920 { return 1.26 }
        if layoutLongSide >= 870 { return 1.22 }
        if layoutLongSide >= boostedPhoneLongSideThreshold { return 1.16 }
        return 1.1
    }

    private static func fitCellAndGap(
        columnCount: Int,
        rowCount: Int,
        gridSpacing: CGFloat,
        widthBudget: CGFloat,
        availableHeight: CGFloat,
        baseChrome: CGFloat,
        sectionGapWeight: CGFloat,
        minCell: CGFloat
    ) -> CGFloat {
        let gapCount = sectionGapWeight
        let widthLimited = floor(
            (widthBudget - gridSpacing * CGFloat(columnCount - 1)) / CGFloat(columnCount)
        )
        var cell = min(
            widthLimited,
            floor(
                (availableHeight - baseChrome - gapCount * minimumSectionGap
                    - gridSpacing * CGFloat(rowCount - 1)) / CGFloat(rowCount)
            )
        )
        let floorCell = max(48, minCell - 6)
        cell = max(floorCell, cell)

        while cell >= floorCell {
            let gridHeight = CGFloat(rowCount) * cell + CGFloat(rowCount - 1) * gridSpacing
            let total = baseChrome + gridHeight + gapCount * minimumSectionGap
            if total <= availableHeight {
                return fitCellSideForWidth(
                    cell,
                    columnCount: columnCount,
                    gridSpacing: gridSpacing,
                    widthBudget: widthBudget,
                    minCell: minCell
                )
            }
            cell -= 1
        }

        return fitCellSideForWidth(
            floorCell,
            columnCount: columnCount,
            gridSpacing: gridSpacing,
            widthBudget: widthBudget,
            minCell: minCell
        )
    }

    private static func fitCellSideForWidth(
        _ proposed: CGFloat,
        columnCount: Int,
        gridSpacing: CGFloat,
        widthBudget: CGFloat,
        minCell: CGFloat
    ) -> CGFloat {
        var cell = floor(proposed)
        let floorCell = max(48, minCell - 6)

        while cell >= floorCell {
            let gridWidth = CGFloat(columnCount) * cell + CGFloat(columnCount - 1) * gridSpacing
            if gridWidth <= widthBudget {
                return cell
            }
            cell -= 1
        }

        return floorCell
    }
}
