import SwiftUI

struct PadEditorMetrics {
    let isLandscape: Bool
    let contentWidth: CGFloat
    let controlHeight: CGFloat
    let actionButtonHeight: CGFloat
    let notePopupWidth: CGFloat
    let notePopupPadding: CGFloat
    let rowLabelSpacing: CGFloat = 12
    let sectionLabelSpacing: CGFloat = 8
    let rootKeySpacing: CGFloat = 8
    private let rootNaturalKeyCount: CGFloat = 7

    var rowLabelWidth: CGFloat {
        isLandscape ? 92 : 88
    }

    var outerSpacing: CGFloat {
        isLandscape ? 10 : 14
    }

    var cardOuterPadding: CGFloat {
        isLandscape ? 12 : 18
    }

    var cardInnerPadding: CGFloat {
        isLandscape ? 14 : 18
    }

    var labelFontSize: CGFloat {
        isLandscape ? 20 : 22
    }

    var labelVerticalPadding: CGFloat {
        isLandscape ? 10 : 14
    }

    /// Label 入力（1行固定）の高さ
    var labelFieldHeight: CGFloat {
        let lineHeight = labelFontSize * 1.12
        return ceil(lineHeight) + labelVerticalPadding * 2
    }

    /// v1.1 ポップアップ行間（ノート入力・ラベル編集で共通）
    var v11PopupRowSpacing: CGFloat {
        isLandscape ? 8 : 10
    }

    /// v1.1 12 鍵パネル（黒枠＋上下パディング込み）
    var v11PopupKeyboardHeight: CGFloat {
        controlHeight * 2 + rootRowSpacing + 16
    }

    /// v1.1 鍵盤＋ROOT 行ぶんの中段高さ
    var v11PopupMiddleHeight: CGFloat {
        v11PopupKeyboardHeight + v11PopupRowSpacing + controlHeight
    }

    /// v1.1 LABEL / KEYS 行の高さ（コンパクト）
    var v11CornerChipHeight: CGFloat {
        isLandscape ? 28 : 30
    }

    /// v1.1 ポップアップ本文の高さ（INPUT NOTE と LABEL で同一）
    var v11PopupBodyHeight: CGFloat {
        let spacing = v11PopupRowSpacing
        return v11CornerChipHeight
            + v11PopupMiddleHeight
            + actionButtonHeight
            + spacing * 2
    }

    /// v1.1 ポップアップパネル全体の高さ（パディング込み）
    var v11PopupPanelHeight: CGFloat {
        notePopupPadding * 2 + v11PopupBodyHeight
    }

    var rootRowSpacing: CGFloat {
        isLandscape ? 6 : 8
    }

    var rootKeyWidth: CGFloat {
        let contentArea = contentWidth
            - cardOuterPadding * 2
            - cardInnerPadding * 2
        let keyboardArea = isLandscape
            ? contentArea - rowLabelWidth - rowLabelSpacing
            : contentArea
        return max(
            28,
            floor((keyboardArea - rootKeySpacing * (rootNaturalKeyCount - 1)) / rootNaturalKeyCount)
        )
    }

    static let v11PopupSideMargin: CGFloat = 10
    static let v11PopupMaxWidthPortrait: CGFloat = 360
    static let v11PopupMaxWidthLandscape: CGFloat = 560
    static let v11PopupMinWidth: CGFloat = 300

    init(
        isLandscape: Bool,
        padLayout: JChordPadLayout,
        size: CGSize,
        safeArea: EdgeInsets = EdgeInsets()
    ) {
        self.isLandscape = isLandscape
        contentWidth = size.width
        controlHeight = isLandscape ? 34 : 36
        actionButtonHeight = padLayout.noteOffHeight
        let horizontalSafe = safeArea.leading + safeArea.trailing
        let availableWidth = size.width - horizontalSafe - Self.v11PopupSideMargin * 2
        let maxWidth = isLandscape
            ? Self.v11PopupMaxWidthLandscape
            : Self.v11PopupMaxWidthPortrait
        notePopupWidth = min(maxWidth, max(Self.v11PopupMinWidth, availableWidth))
        notePopupPadding = isLandscape ? 14 : 12
    }

    /// v1.1 左上 LABEL / KEYS（最小幅。実寸は文字に合わせて伸びる）
    var v11CornerChipMinWidth: CGFloat {
        60
    }

    /// v1.1 ROOT チップ幅
    var v11RootChipWidth: CGFloat {
        52
    }

    /// v1.1 ADD / DEL / CLR
    var v11UtilityChipWidth: CGFloat {
        46
    }

    /// v1.1 ラベル画面の見出し列幅（LABEL / CANDIDATES）
    var v11SectionLabelWidth: CGFloat {
        isLandscape ? 96 : 100
    }

    /// v1.1 ポップアップ内 12 鍵の鍵間隔
    var popupRootKeySpacing: CGFloat {
        isLandscape ? 6 : 7
    }

    /// ポップアップ本文の幅（`notePopupWidth` の frame 内。外側 `notePopupPadding` はその外）
    var v11PopupInnerWidth: CGFloat {
        notePopupWidth
    }

    /// CANCEL/SET・CLR/SET の 1 ボタン幅（ポップアップ内幅いっぱいに 2 分割）
    func v11PopupFooterButtonWidth(gridSpacing: CGFloat) -> CGFloat {
        floor((v11PopupInnerWidth - gridSpacing) / 2)
    }

    /// v1.1 ポップアップ内 12 鍵の鍵幅（内側幅いっぱいに配分）
    var popupRootKeyWidth: CGFloat {
        let inner = v11PopupInnerWidth - 16
        let spacing = popupRootKeySpacing
        return max(24, floor((inner - spacing * (rootNaturalKeyCount - 1)) / rootNaturalKeyCount))
    }
}
