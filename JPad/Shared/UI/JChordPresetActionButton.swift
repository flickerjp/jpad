import SwiftUI

/// 設定画面の LOAD / SAVE / Unlock 共通ボタン。
struct JChordPresetActionButton: View {
    let title: String
    let height: CGFloat
    /// 購入後など、操作可能で強調表示するか
    var isActivated: Bool = false
    var isInteractive: Bool = true
    var fixedWidth: CGFloat?
    var titleFont: Font?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(titleFont ?? .system(size: min(15, height * 0.4), weight: .heavy))
                .foregroundStyle(foregroundColor)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(width: fixedWidth, height: height)
                .frame(maxWidth: fixedWidth == nil ? .infinity : nil)
                .background(backgroundColor, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(borderColor, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .allowsHitTesting(isInteractive)
    }

    private var foregroundColor: Color {
        isActivated ? Color.white.opacity(0.96) : JChordTheme.paidFeatureLockedForeground
    }

    private var backgroundColor: Color {
        isActivated ? JChordTheme.unlockProminentTint : JChordTheme.paidFeatureLockedBackground
    }

    private var borderColor: Color {
        isActivated ? Color.white.opacity(0.28) : JChordTheme.paidFeatureLockedBorder
    }
}
