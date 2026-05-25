import SwiftUI

/// Input Notes / Key Input ポップアップ用の中央配置オーバーレイ。
struct PadEditorPopupOverlay<Content: View>: View {
    /// `nil` のとき外側タップは背面へ通さず、閉じる・フォーカス解除もしない（v1.1 既定）。
    var onBackdropTap: (() -> Void)?
    @ViewBuilder let content: () -> Content

    var body: some View {
        ZStack {
            Color.black.opacity(0.45)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture {
                    onBackdropTap?()
                }

            content()
                .fixedSize(horizontal: true, vertical: true)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
    }
}
