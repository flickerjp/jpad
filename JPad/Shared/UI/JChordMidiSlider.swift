import SwiftUI
import UIKit

/// Velocity / Expression — TinyTone 系の細いグレーレール＋オレンジグラデーションつまみ。
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
        applyChromeStyle(to: slider)
        slider.addTarget(
            context.coordinator,
            action: #selector(Coordinator.valueChanged(_:)),
            for: .valueChanged
        )
        return slider
    }

    func updateUIView(_ slider: UISlider, context: Context) {
        slider.minimumValue = Float(range.lowerBound)
        slider.maximumValue = Float(range.upperBound)
        let floatValue = Float(value.rounded())
        if slider.value != floatValue {
            slider.value = floatValue
        }
        applyChromeStyle(to: slider)
    }

    private func applyChromeStyle(to slider: UISlider) {
        ThinSliderTrackImage.apply(to: slider)
        let thumb = OrangeGradientSliderThumb.image
        slider.setThumbImage(thumb, for: .normal)
        slider.setThumbImage(thumb, for: .highlighted)
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

private enum ThinSliderTrackImage {
    static let height = JPadChromeTheme.sliderTrackHeight

    private static let minimumTrack = makeTrack(color: UIColor(JPadChromeTheme.sliderTrackFill))
    private static let maximumTrack = makeTrack(color: JPadChromeTheme.sliderMaximumTrack)

    static func apply(to slider: UISlider) {
        for state: UIControl.State in [.normal, .highlighted, .disabled] {
            slider.setMinimumTrackImage(minimumTrack, for: state)
            slider.setMaximumTrackImage(maximumTrack, for: state)
        }
    }

    private static func makeTrack(color: UIColor) -> UIImage {
        let diameter = height
        let size = CGSize(width: 8, height: diameter)
        let image = UIGraphicsImageRenderer(size: size).image { _ in
            let rect = CGRect(origin: .zero, size: size)
            let path = UIBezierPath(roundedRect: rect, cornerRadius: diameter / 2)
            color.setFill()
            path.fill()
        }
        return image.resizableImage(
            withCapInsets: UIEdgeInsets(top: 0, left: 4, bottom: 0, right: 4),
            resizingMode: .stretch
        )
    }
}

private enum OrangeGradientSliderThumb {
    static let image: UIImage = {
        let diameter: CGFloat = 26
        let size = CGSize(width: diameter + 8, height: diameter + 8)
        return UIGraphicsImageRenderer(size: size).image { context in
            let rect = CGRect(
                x: (size.width - diameter) / 2,
                y: (size.height - diameter) / 2,
                width: diameter,
                height: diameter
            )
            let cg = context.cgContext
            cg.setShadow(
                offset: CGSize(width: 0, height: 1),
                blur: 3,
                color: UIColor.black.withAlphaComponent(0.22).cgColor
            )
            let path = UIBezierPath(ovalIn: rect)
            cg.saveGState()
            path.addClip()
            let colors = JPadChromeTheme.thumbGradientColors.map(\.cgColor) as CFArray
            let space = CGColorSpaceCreateDeviceRGB()
            if let gradient = CGGradient(
                colorsSpace: space,
                colors: colors,
                locations: [0, 0.42, 1]
            ) {
                cg.drawLinearGradient(
                    gradient,
                    start: CGPoint(x: rect.midX, y: rect.minY),
                    end: CGPoint(x: rect.midX, y: rect.maxY),
                    options: []
                )
            }
            cg.restoreGState()
        }
    }()
}
