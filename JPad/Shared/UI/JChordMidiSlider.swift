import SwiftUI
import UIKit

/// Velocity / Expression 用。トラックの高さはシステム標準の約半分。
struct JChordMidiSlider: UIViewRepresentable {
    @Binding var value: Double
    var range: ClosedRange<Double> = 1 ... 127

    func makeCoordinator() -> Coordinator {
        Coordinator(value: $value)
    }

    func makeUIView(context: Context) -> UISlider {
        let slider = UISlider(frame: .zero)
        slider.minimumValue = Float(range.lowerBound)
        slider.maximumValue = Float(range.upperBound)
        slider.value = Float(value)

        let trackHeight = JChordTheme.midiSliderTrackHeight
        let fillColor = UIColor(JChordTheme.trackFill)
        let trackColor = UIColor(JChordTheme.track)
        slider.setMinimumTrackImage(
            Self.trackImage(color: fillColor, height: trackHeight),
            for: .normal
        )
        slider.setMaximumTrackImage(
            Self.trackImage(color: trackColor, height: trackHeight),
            for: .normal
        )

        slider.addTarget(
            context.coordinator,
            action: #selector(Coordinator.valueChanged(_:)),
            for: .valueChanged
        )
        return slider
    }

    func updateUIView(_ slider: UISlider, context: Context) {
        let floatValue = Float(value)
        if slider.value != floatValue {
            slider.value = floatValue
        }
    }

    private static func trackImage(color: UIColor, height: CGFloat) -> UIImage {
        let size = CGSize(width: 8, height: height)
        let image = UIGraphicsImageRenderer(size: size).image { context in
            let rect = CGRect(origin: .zero, size: size)
            let path = UIBezierPath(roundedRect: rect, cornerRadius: height / 2)
            color.setFill()
            path.fill()
        }
        return image.resizableImage(withCapInsets: .zero, resizingMode: .stretch)
    }

    final class Coordinator: NSObject {
        private var value: Binding<Double>

        init(value: Binding<Double>) {
            self.value = value
        }

        @objc func valueChanged(_ sender: UISlider) {
            value.wrappedValue = Double(sender.value.rounded())
        }
    }
}
