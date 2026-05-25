import SwiftUI

struct JChordTopActionStyle: ButtonStyle {
    enum Appearance {
        case neutral
        case midiAccentToggle
    }

    var compact = false
    var isActive = false
    var appearance: Appearance = .neutral

    private var chromeSize: JPadOrangeChromeStyle {
        compact ? .compact : .standard
    }

    private var metrics: JPadOrangeChromeStyle.Metrics {
        JPadOrangeChromeStyle.metrics(for: chromeSize)
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: metrics.fontSize, weight: metrics.fontWeight))
            .foregroundStyle(foregroundColor)
            .padding(.horizontal, metrics.horizontalPadding)
            .frame(height: metrics.height)
            .background { backgroundView }
            .overlay { borderView }
            .opacity(configuration.isPressed ? 0.85 : 1)
    }

    @ViewBuilder
    private var backgroundView: some View {
        let fill = backgroundFill
        if metrics.usesCapsule {
            Capsule(style: .continuous).fill(fill)
        } else {
            RoundedRectangle(cornerRadius: metrics.cornerRadius, style: .continuous).fill(fill)
        }
    }

    @ViewBuilder
    private var borderView: some View {
        let stroke = borderColor
        if metrics.usesCapsule {
            Capsule(style: .continuous).strokeBorder(stroke, lineWidth: 1)
        } else {
            RoundedRectangle(cornerRadius: metrics.cornerRadius, style: .continuous)
                .strokeBorder(stroke, lineWidth: 1)
        }
    }

    private var foregroundColor: Color {
        switch appearance {
        case .neutral:
            return isActive
                ? JPadOrangeChromeStyle.foreground(isPressed: false, isAccentOn: false)
                : JChordTheme.text
        case .midiAccentToggle:
            if isActive {
                return JPadOrangeChromeStyle.foreground(isPressed: true, isAccentOn: false)
            }
            return JPadOrangeChromeStyle.foreground(isPressed: false, isAccentOn: false)
        }
    }

    private var backgroundFill: AnyShapeStyle {
        switch appearance {
        case .neutral:
            if isActive {
                return JPadOrangeChromeStyle.background(isPressed: false, isAccentOn: false)
            }
            return AnyShapeStyle(Color.clear)
        case .midiAccentToggle:
            if isActive {
                return JPadOrangeChromeStyle.background(isPressed: true, isAccentOn: false)
            }
            return JPadOrangeChromeStyle.background(isPressed: false, isAccentOn: false)
        }
    }

    private var borderColor: Color {
        switch appearance {
        case .neutral:
            return isActive
                ? JPadOrangeChromeStyle.border(isPressed: false, isAccentOn: false)
                : Color.white.opacity(0.85)
        case .midiAccentToggle:
            if isActive {
                return JPadOrangeChromeStyle.border(isPressed: true, isAccentOn: false)
            }
            return JPadOrangeChromeStyle.border(isPressed: false, isAccentOn: false)
        }
    }
}
