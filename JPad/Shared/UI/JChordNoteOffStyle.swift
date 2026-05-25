import SwiftUI

/// メイン画面の RESET / HOLD、プリセットピッカーの SHARE / IMPORT 共通。
struct JChordNoteOffStyle: ButtonStyle {
    var primary = false
    var isActive = false
    /// 未購入などで SHARE / IMPORT をグレー表示するとき
    var isLocked = false
    /// `isLocked` 時の文字色（白の不透明度）。未指定なら 0.4。
    var lockedForegroundOpacity: CGFloat?
    var fontSize: CGFloat = 20
    var height: CGFloat = 52
    /// 指定時は横に伸ばさない（設定の Buy など TEST NOTE 幅に揃える）
    var fixedWidth: CGFloat? = nil

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: fontSize, weight: .heavy))
            .foregroundStyle(foregroundColor)
            .frame(width: fixedWidth, height: height)
            .frame(maxWidth: fixedWidth == nil ? .infinity : nil)
            .background(backgroundFill, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(JChordTheme.padActionBorder, lineWidth: 1)
            )
            .opacity(configuration.isPressed ? 0.85 : 1)
    }

    private var foregroundColor: Color {
        if isActive {
            return Color.white.opacity(0.96)
        }
        if isLocked {
            let opacity = lockedForegroundOpacity ?? 0.4
            return Color.white.opacity(opacity)
        }
        return primary ? JChordTheme.text : Color.white.opacity(0.9)
    }

    private var backgroundFill: AnyShapeStyle {
        if isActive {
            return AnyShapeStyle(JChordTheme.holdButtonActiveBackground)
        }
        if isLocked {
            return AnyShapeStyle(JChordTheme.padActionLockedBackground)
        }
        return AnyShapeStyle(Color.clear)
    }
}
