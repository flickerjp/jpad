import SwiftUI

/// PAD 切り替え対象用。塗りなし・白30%枠・オン時は白チェックのみ。
struct RotationCheckbox: View {
    let isOn: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .strokeBorder(Color.white.opacity(0.3), lineWidth: 1)
            if isOn {
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
        .frame(width: 22, height: 22)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}
