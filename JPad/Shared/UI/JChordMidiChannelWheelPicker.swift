import SwiftUI

/// 中央の CH のみ見えるコンパクトなホイールピッカー。
struct JChordMidiChannelWheelPicker: View {
    @Binding var channel: Int
    var width: CGFloat
    var height: CGFloat

    private var maskBandHeight: CGFloat {
        max(12, height * 1.05)
    }

    var body: some View {
        ZStack {
            Picker("Output channel", selection: $channel) {
                ForEach(1 ... 16, id: \.self) { value in
                    Text("\(value)CH")
                        .font(.system(size: min(18, height * 0.44), weight: .heavy))
                        .tag(value)
                }
            }
            .pickerStyle(.wheel)
            .labelsHidden()
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
