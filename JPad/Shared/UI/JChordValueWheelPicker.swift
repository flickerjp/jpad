import SwiftUI

/// 中央の1つだけが見えるコンパクトなホイールピッカー。
struct JChordValueWheelPicker: View {
    let values: [Int]
    @Binding var value: Int
    var width: CGFloat
    var height: CGFloat
    var displayText: (Int) -> String

    private var maskBandHeight: CGFloat {
        max(12, height * 1.05)
    }

    var body: some View {
        ZStack {
            Picker("", selection: $value) {
                ForEach(values, id: \.self) { item in
                    Text(displayText(item))
                        .font(.system(size: min(18, height * 0.44), weight: .heavy))
                        .scaleEffect(x: 1, y: -1)
                        .tag(item)
                }
            }
            .pickerStyle(.wheel)
            .labelsHidden()
            .scaleEffect(x: 1, y: -1)
            .frame(width: width, height: height * 3)

            VStack(spacing: 0) {
                JChordTheme.panel.opacity(0.98)
                    .frame(height: maskBandHeight)
                Spacer(minLength: 0)
                JChordTheme.panel.opacity(0.98)
                    .frame(height: maskBandHeight)
            }
            .allowsHitTesting(false)
        }
        .frame(width: width, height: height)
        .clipped()
        .contentShape(Rectangle())
    }
}
