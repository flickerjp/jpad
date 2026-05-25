import SwiftUI

/// 待機: 行／列の色シフト。
struct PadPerformanceOrbitFill: View {
    let colorPhase: Double
    let brightness: Double
    let cornerRadius: CGFloat
    let isActive: Bool

    private var padShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    }

    var body: some View {
        padShape.fill(
            PerformancePadPalette.launchpadGradient(
                colorPhase: colorPhase,
                brightness: brightness,
                pressed: isActive
            )
        )
    }
}

/// タップ: 同一レベルの白フラッシュが16分音符で伝播。
struct PadPerformanceRippleOverlay: View {
    let ripple: PadPerformanceEffectEngine.RippleAppearance
    let cornerRadius: CGFloat

    private var padShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    }

    var body: some View {
        if ripple.whiteFlash > 0.02 {
            padShape.fill(Color.white.opacity(0.81 * ripple.whiteFlash))
            padShape.fill(
                RadialGradient(
                    colors: [
                        Color.white.opacity(0.90 * ripple.whiteFlash),
                        Color.white.opacity(0.665 * ripple.whiteFlash),
                        Color.clear
                    ],
                    center: .center,
                    startRadius: 0,
                    endRadius: 88
                )
            )
            .clipShape(padShape)
            .allowsHitTesting(false)
        }
    }
}

/// HOLD: 4分音符同期グロー。
struct PadPerformanceHoldGlow: ViewModifier {
    let isActive: Bool
    let colorPhase: Double
    var config: PadPerformanceAnimationConfig = .standard

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        Group {
            if isActive, !reduceMotion {
                TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
                    let pulse = PadPerformanceEffectEngine.holdPulsePhase(
                        time: context.date.timeIntervalSinceReferenceDate,
                        config: config
                    )
                    let glow = 0.3 + 0.35 * pulse
                    content
                        .shadow(
                            color: PerformancePadPalette.holdGlowColor(colorPhase: colorPhase).opacity(glow),
                            radius: 12,
                            x: 0,
                            y: 0
                        )
                }
            } else {
                content
            }
        }
    }
}

extension View {
    func padPerformanceHoldGlow(
        isActive: Bool,
        colorPhase: Double,
        config: PadPerformanceAnimationConfig = .standard
    ) -> some View {
        modifier(PadPerformanceHoldGlow(isActive: isActive, colorPhase: colorPhase, config: config))
    }
}
