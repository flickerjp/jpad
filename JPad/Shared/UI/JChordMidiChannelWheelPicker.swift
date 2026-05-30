import SwiftUI

/// 中央の CH のみ見えるコンパクトなホイールピッカー。
struct JChordMidiChannelWheelPicker: View {
    @Binding var channel: Int
    var width: CGFloat
    var height: CGFloat

    var body: some View {
        JChordValueWheelPicker(
            values: Array(1 ... 16),
            value: $channel,
            width: width,
            height: height,
            displayText: { "\($0)CH" }
        )
    }
}
