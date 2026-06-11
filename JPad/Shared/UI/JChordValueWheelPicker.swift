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

    private var valueTextWidth: CGFloat {
        max(28, width - min(8, width * 0.12))
    }

    var body: some View {
        ZStack {
            Picker("", selection: $value) {
                ForEach(values, id: \.self) { item in
                    Text(displayText(item))
                        .font(.system(size: min(17, height * 0.4), weight: .heavy))
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                        .allowsTightening(true)
                        .frame(width: valueTextWidth, alignment: .center)
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
