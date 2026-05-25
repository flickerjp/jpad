import SwiftUI

/// LOAD / SAVE と同じ未解放見た目（購入前のみ表示）。
struct JChordUnlockButton: View {
    static let width: CGFloat = 87

    let height: CGFloat
    let action: () -> Void

    var body: some View {
        JChordPresetActionButton(
            title: L10n.string("settings.unlock"),
            height: height,
            isActivated: false,
            isInteractive: true,
            fixedWidth: Self.width,
            titleFont: .caption.weight(.semibold),
            action: action
        )
        .accessibilityLabel(L10n.string("settings.unlock.accessibility"))
    }
}
