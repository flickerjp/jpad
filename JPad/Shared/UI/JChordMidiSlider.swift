import SwiftUI
import UIKit

/// Velocity / Expression — TinyTone 系の細いグレーレール＋オレンジグラデーションつまみ。
struct JChordMidiSlider: UIViewRepresentable {
    @Binding var value: Double
    var range: ClosedRange<Double> = 1 ... 127
    var isVertical = false

    func makeCoordinator() -> Coordinator {
        Coordinator(value: $value)
    }

    func makeUIView(context: Context) -> SliderHostView {
        SliderHostView(coordinator: context.coordinator)
    }

    func updateUIView(_ host: SliderHostView, context: Context) {
        host.configure(
            range: range,
            value: value,
            isVertical: isVertical
        )
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

final class SliderHostView: UIView {
    private let slider = UISlider(frame: .zero)
    private weak var coordinator: JChordMidiSlider.Coordinator?
    private var isVertical = false
    private var didApplyChrome = false

    init(coordinator: JChordMidiSlider.Coordinator) {
        self.coordinator = coordinator
        super.init(frame: .zero)
        addSubview(slider)
        slider.addTarget(
            coordinator,
            action: #selector(JChordMidiSlider.Coordinator.valueChanged(_:)),
            for: .valueChanged
        )
        clipsToBounds = false
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(
        range: ClosedRange<Double>,
        value: Double,
        isVertical: Bool
    ) {
        self.isVertical = isVertical
        slider.minimumValue = Float(range.lowerBound)
        slider.maximumValue = Float(range.upperBound)
        let floatValue = Float(value.rounded())
        if slider.value != floatValue {
            slider.value = floatValue
        }
        if !didApplyChrome {
            ThinSliderTrackImage.apply(to: slider)
            let thumb = OrangeGradientSliderThumb.image
            slider.setThumbImage(thumb, for: .normal)
            slider.setThumbImage(thumb, for: .highlighted)
            didApplyChrome = true
        }
        setNeedsLayout()
        layoutIfNeeded()
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        if isVertical {
            let targetSize = CGSize(width: bounds.height, height: bounds.width)
            slider.bounds = CGRect(origin: .zero, size: targetSize)
            slider.center = CGPoint(x: bounds.midX, y: bounds.midY)
            slider.transform = CGAffineTransform(rotationAngle: -.pi / 2)
        } else {
            slider.frame = bounds
            slider.transform = .identity
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
