import SwiftUI

struct JChordTopActionStyle: ButtonStyle {
    enum Appearance {
        case neutral
        /// 非アクティブ＝選択 MIDI 同系の渋いオレンジ、アクティブ＝鳴っている PAD と同じ明るいオレンジ
        case midiAccentToggle
    }

    var compact = false
    var isActive = false
    var appearance: Appearance = .neutral

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: compact ? 12 : 13, weight: .heavy))
            .foregroundStyle(foregroundColor)
            .padding(.horizontal, compact ? 10 : 12)
            .frame(height: compact ? 28 : 32)
            .background(backgroundFill, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(borderColor, lineWidth: 1)
            )
            .opacity(configuration.isPressed ? 0.85 : 1)
    }

    private var foregroundColor: Color {
        switch appearance {
        case .neutral:
            return JChordTheme.text
        case .midiAccentToggle:
            return isActive ? .white.opacity(0.96) : JChordTheme.midiDeviceSelectedForeground
        }
    }

    private var backgroundFill: AnyShapeStyle {
        switch appearance {
        case .neutral:
            if isActive {
                return AnyShapeStyle(Color.white.opacity(0.12))
            }
            return AnyShapeStyle(Color.white.opacity(0.04))
        case .midiAccentToggle:
            if isActive {
                return AnyShapeStyle(JChordTheme.padActiveBackground)
            }
            return AnyShapeStyle(JChordTheme.midiDeviceSelectedBackground)
        }
    }

    private var borderColor: Color {
        switch appearance {
        case .neutral:
            return Color.white.opacity(isActive ? 0.18 : 0.1)
        case .midiAccentToggle:
            return isActive ? Color.white.opacity(0.28) : JChordTheme.midiDeviceSelectedBorder
        }
    }
}
