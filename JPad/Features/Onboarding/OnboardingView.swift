import SwiftUI

enum OnboardingPresentationStyle {
    case firstLaunch
    case help
}

struct OnboardingView: View {
    @ObservedObject var midiService: MidiOutputService
    var style: OnboardingPresentationStyle = .firstLaunch
    let onFinish: () -> Void

    private let tutorialStepKeys = [
        "onboarding.garageband.step1",
        "onboarding.garageband.step2",
        "onboarding.garageband.step3",
        "onboarding.garageband.step4",
        "onboarding.garageband.step5",
    ]

    var body: some View {
        GeometryReader { geometry in
            let layout = JChordPadLayout.make(
                size: geometry.size,
                safeArea: geometry.safeAreaInsets
            )
            let testPadWidth = layout.cellSide

            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        headerSection

                        garageBandTutorialCard

                        MidiRoutingSettingsContent(
                            midiService: midiService,
                            testPadWidth: testPadWidth
                        )
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, style == .help ? 52 : 20)
                    .padding(.bottom, 12)
                }

                bottomBar
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .overlay(alignment: .topTrailing) {
                if style == .help {
                    Button(action: finishOnboarding) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(JChordTheme.text)
                            .frame(width: 36, height: 36)
                            .background(Color.white.opacity(0.08), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 12)
                    .padding(.trailing, 18)
                    .accessibilityLabel(L10n.string("settings.close.accessibility"))
                }
            }
        }
        .jChordScreenBackground()
        .onAppear {
            midiService.refreshEndpoints()
            midiService.preparePreviewAudioIfNeeded()
        }
        .onDisappear {
            midiService.setTestNoteEnabled(false)
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(L10n.string("onboarding.title"))
                .font(.system(size: 28, weight: .heavy))
                .foregroundStyle(JChordTheme.text)

            Text(L10n.string("onboarding.subtitle"))
                .font(.subheadline.weight(.medium))
                .foregroundStyle(JChordTheme.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, 4)
    }

    private var garageBandTutorialCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.string("onboarding.garageband.title"))
                .font(.caption.weight(.heavy))
                .foregroundStyle(JChordTheme.muted)

            VStack(alignment: .leading, spacing: 14) {
                ForEach(Array(tutorialStepKeys.enumerated()), id: \.offset) { index, key in
                    tutorialStepRow(number: index + 1, text: L10n.string(key))
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(JChordTheme.panel, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    private func tutorialStepRow(number: Int, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\(number).")
                .font(.subheadline.weight(.heavy))
                .foregroundStyle(JChordTheme.accentOrangeMid)
                .frame(width: 22, alignment: .trailing)

            Text(text)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(JChordTheme.text)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var bottomBar: some View {
        VStack(spacing: 10) {
            Button(action: finishOnboarding) {
                Text(bottomButtonTitle)
                    .font(.system(size: 17, weight: .heavy))
                    .foregroundStyle(JChordTheme.text)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(
                        LinearGradient(
                            colors: [
                                JChordTheme.accentOrangeTop,
                                JChordTheme.accentOrangeMid,
                                JChordTheme.accentOrangeBottom,
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)

            Text("JPad © 2026 FLICKER PRODUCT")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(JChordTheme.muted)
        }
        .padding(.horizontal, 18)
        .padding(.top, 10)
        .padding(.bottom, 12)
        .background(JChordTheme.panel.opacity(0.98))
    }

    private var bottomButtonTitle: String {
        switch style {
        case .firstLaunch:
            L10n.string("onboarding.continue")
        case .help:
            L10n.string("onboarding.close")
        }
    }

    private func finishOnboarding() {
        midiService.warmUpPreviewEngineIfNeeded()
        onFinish()
    }
}
