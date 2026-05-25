import SwiftUI

struct JChordDeviceRow: View {
    let title: String
    let subtitle: String
    let isSelected: Bool
    var isReceiving: Bool = false
    var isEnabled: Bool = true

    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline.weight(.heavy))
                .foregroundStyle(foregroundColor)

            Spacer()

            if !subtitle.isEmpty {
                Text(subtitle)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(subtitleColor)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(backgroundStyle, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(borderColor, lineWidth: isHighlighted ? 1.25 : 1)
        )
        .opacity(isEnabled ? 1 : 0.55)
    }

    private var isHighlighted: Bool {
        isSelected || isReceiving
    }

    private var foregroundColor: Color {
        guard isEnabled else { return JChordTheme.muted }
        if isSelected {
            return JChordTheme.midiDeviceSelectedForeground
        }
        if isReceiving {
            return JChordTheme.midiDeviceSelectedForeground
        }
        return JChordTheme.text
    }

    private var subtitleColor: Color {
        if isSelected {
            return JChordTheme.midiDeviceSelectedSubtitle
        }
        if isReceiving {
            return JChordTheme.midiDeviceSelectedSubtitle
        }
        return JChordTheme.muted
    }

    private var backgroundStyle: AnyShapeStyle {
        if isReceiving {
            return AnyShapeStyle(JChordTheme.midiDeviceSelectedBackground)
        }
        if isSelected {
            return AnyShapeStyle(JChordTheme.midiDeviceSelectedBackground)
        }
        return AnyShapeStyle(Color.white.opacity(0.05))
    }

    private var borderColor: Color {
        if isSelected {
            return JChordTheme.midiDeviceSelectedBorder
        }
        if isReceiving {
            return JChordTheme.midiDeviceSelectedBorder
        }
        return Color.white.opacity(0.1)
    }
}
