import SwiftUI

struct PadView: View {
    /// EDIT 時のコード名（待機）
    private static let editModeChordColor = Color.white.opacity(0.5)

    let pad: PadDefinition
    let displayPad: PadDefinition
    let visualStyle: PadVisualStyle
    let isMidiReady: Bool
    let isEditMode: Bool
    let isSelected: Bool
    let isPlaying: Bool
    let isHoldPulsing: Bool
    let sideLength: CGFloat
    /// Launchpad 待機演出（親の TimelineView で更新）
    var orbitColorPhase: Double = 0
    var orbitBrightness: Double = 0.65
    var performanceAnimationConfig: PadPerformanceAnimationConfig = .standard
    /// タップリング（親で算出）
    var rippleAppearance: PadPerformanceEffectEngine.RippleAppearance = .none
    var cornerRadius: CGFloat = 18
    var contentPadding: CGFloat = 12
    let onPressChanged: (Bool) -> Void
    var onEditLabelTap: (() -> Void)?
    var onEditNotesTap: (() -> Void)?

    @State private var isPressed = false
    @State private var isPianoPreviewPressed = false

    private var usesPerformanceLook: Bool {
        visualStyle == .performance && !isEditMode
    }

    private var isVisuallyActive: Bool {
        isPlaying || (!isEditMode && isPressed)
    }

    private var padShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    }

    private var titleFontSize: CGFloat {
        min(22, sideLength * 0.19)
    }

    private var subtitleFontSize: CGFloat {
        min(13, sideLength * 0.11)
    }

    private var titleLineHeight: CGFloat {
        titleFontSize * 1.12
    }

    private var maxTitleLines: Int {
        let verticalPadding = contentPadding * 2
        let subtitleReserve: CGFloat = showsRootSubtitle ? subtitleFontSize + 4 : 0
        let available = sideLength - verticalPadding - subtitleReserve
        return max(1, Int(floor(available / titleLineHeight)))
    }

    private var showsRootSubtitle: Bool {
        !isEditMode
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            if usesPerformanceLook {
                PadPerformanceOrbitFill(
                    colorPhase: orbitColorPhase,
                    brightness: orbitBrightness,
                    cornerRadius: cornerRadius,
                    isActive: isVisuallyActive
                )
            } else {
                padShape
                    .fill(padFill)
            }

            if usesPerformanceLook {
                PadPerformanceRippleOverlay(
                    ripple: rippleAppearance,
                    cornerRadius: cornerRadius
                )
            }

            if isEditMode {
                editModeContent
            } else {
                labelContent
                    .padding(contentPadding)
            }
        }
        .frame(width: sideLength, height: sideLength)
        .modifier(PadPulseModifier(
            usesPerformanceLook: usesPerformanceLook,
            isHoldPulsing: isHoldPulsing,
            colorPhase: orbitColorPhase,
            config: performanceAnimationConfig
        ))
        .overlay(padShape.strokeBorder(borderColor, lineWidth: isSelected ? 2.5 : 1.25))
        .opacity(padOpacity)
        .gesture(isEditMode ? nil : playDragGesture)
        .onDisappear {
            releaseIfNeeded()
            releasePianoPreviewIfNeeded()
        }
    }

    private var padOpacity: Double {
        if isEditMode, isMidiReady { return 1 }
        guard !isMidiReady else { return 1 }
        return usesPerformanceLook ? 0.7 : 0.55
    }

    private var editModeContent: some View {
        ZStack(alignment: .topTrailing) {
            labelContent
                .padding(contentPadding)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                .allowsHitTesting(false)

            Color.clear
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
                .onTapGesture {
                    onEditNotesTap?()
                }
                .accessibilityAddTraits(.isButton)
                .accessibilityLabel(L10n.string("main.edit_pad_notes.accessibility"))

            editPianoPreviewControl
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var editPianoPreviewControl: some View {
        let controlSize = min(52, max(44, sideLength * 0.32))
        let isPressed = isPianoPreviewPressed || isPlaying
        let shape = RoundedRectangle(
            cornerRadius: JPadPianoChromeStyle.cornerRadius(for: controlSize),
            style: .continuous
        )

        JPadPianoChromeIcon(
            size: controlSize,
            isPressed: isPressed,
            isEnabled: isMidiReady,
            editMode: true
        )
        .padding(10)
        .contentShape(shape)
        .gesture(editPianoPreviewGesture)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(L10n.string("main.edit_pad_preview.accessibility"))
    }

    private var labelContent: some View {
        VStack(alignment: .leading, spacing: 2) {
            Spacer(minLength: 0)

            Text(displayPad.title)
                .font(.system(size: titleFontSize, weight: .heavy))
                .foregroundStyle(foregroundColor)
                .multilineTextAlignment(.leading)
                .lineLimit(maxTitleLines)
                .minimumScaleFactor(0.5)
                .frame(maxWidth: .infinity, alignment: .bottomLeading)
                .shadow(
                    color: usesPerformanceLook ? Color.black.opacity(0.45) : .clear,
                    radius: 2,
                    y: 1
                )

            if showsRootSubtitle {
                Text(displayPad.rootDisplayName)
                    .font(.system(size: subtitleFontSize, weight: .semibold))
                    .foregroundStyle(subtitleColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
                    .shadow(
                        color: usesPerformanceLook ? Color.black.opacity(0.4) : .clear,
                        radius: 1,
                        y: 1
                    )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
    }

    private var padFill: some ShapeStyle {
        if isVisuallyActive {
            return AnyShapeStyle(JChordTheme.padActiveBackground)
        }
        return AnyShapeStyle(JChordTheme.padIdleBackground)
    }

    private var playDragGesture: some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .local)
            .onChanged { _ in
                guard !isPressed else { return }
                isPressed = true
                onPressChanged(true)
            }
            .onEnded { _ in
                releaseIfNeeded()
            }
    }

    private var foregroundColor: Color {
        if usesPerformanceLook {
            return PerformancePadPalette.labelForeground
        }
        if isEditMode {
            return isVisuallyActive ? .white.opacity(0.96) : Self.editModeChordColor
        }
        if isVisuallyActive {
            return .white.opacity(0.96)
        }
        return JChordTheme.text
    }

    private var subtitleColor: Color {
        if usesPerformanceLook {
            return PerformancePadPalette.labelSubtitle
        }
        if isVisuallyActive {
            return .white.opacity(0.82)
        }
        return JChordTheme.muted.opacity(0.55)
    }

    private var borderColor: Color {
        if usesPerformanceLook {
            return PerformancePadPalette.borderColor(colorPhase: orbitColorPhase, isSelected: isSelected)
        }
        return JChordTheme.padBorder
    }

    private func releaseIfNeeded() {
        guard isPressed else { return }
        isPressed = false
        onPressChanged(false)
    }

    private var editPianoPreviewGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { _ in
                guard !isPianoPreviewPressed else { return }
                isPianoPreviewPressed = true
                onPressChanged(true)
            }
            .onEnded { _ in
                releasePianoPreviewIfNeeded()
            }
    }

    private func releasePianoPreviewIfNeeded() {
        guard isPianoPreviewPressed else { return }
        isPianoPreviewPressed = false
        onPressChanged(false)
    }
}

private struct PadPulseModifier: ViewModifier {
    let usesPerformanceLook: Bool
    let isHoldPulsing: Bool
    let colorPhase: Double
    let config: PadPerformanceAnimationConfig

    func body(content: Content) -> some View {
        if usesPerformanceLook {
            content.padPerformanceHoldGlow(
                isActive: isHoldPulsing,
                colorPhase: colorPhase,
                config: config
            )
        } else {
            content.jChordGentlePulse(isHoldPulsing)
        }
    }
}

extension PadView {
    static let editNotesIconName = "pianokeys"
}
