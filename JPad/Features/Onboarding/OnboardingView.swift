import SwiftUI
import UIKit

struct OnboardingView: View {
    @ObservedObject var midiService: MidiOutputService
    let onFinish: () -> Void

    @State private var isCompletingWelcome = false
    @State private var welcomeNoteWasUsed = false

    var body: some View {
        GeometryReader { geometry in
            let layout = JChordPadLayout.make(
                size: geometry.size,
                safeArea: geometry.safeAreaInsets
            )
            let testPadWidth = layout.cellSide
            let welcomePanelWidth = min(max(testPadWidth * 3.2, 300), 380)
            let continueTitle = L10n.string("onboarding.continue")
            let continueFontSize = JPadOrangeChromeStyle.metrics(for: .standard).fontSize
            let continueButtonWidth = Self.buttonWidth(
                title: continueTitle,
                fontSize: continueFontSize,
                extraWidth: 50
            )

            ZStack(alignment: .topTrailing) {
                VStack(spacing: 0) {
                    Spacer(minLength: 0)

                    VStack(spacing: 20) {
                        headerSection

                        MidiRoutingSettingsContent(
                            midiService: midiService,
                            testPadWidth: testPadWidth,
                            presentation: .welcome
                        )

                        JPadChromeDockButton(
                            title: continueTitle,
                            style: .accentToggle,
                            isOn: true,
                            pillShape: true,
                            fontSize: continueFontSize,
                            width: continueButtonWidth,
                            action: finishOnboarding
                        )
                        .disabled(isCompletingWelcome)
                        .opacity(isCompletingWelcome ? 0.55 : 1)
                    }
                    .frame(width: welcomePanelWidth)
                    .frame(maxWidth: .infinity)

                    Spacer(minLength: 0)

                    Text("TinyTone © 2026 FLICKER PRODUCT")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(JChordTheme.muted)
                        .padding(.bottom, 12)
                }

                Button(action: finishOnboarding) {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(JPadChromeTheme.primaryLabel)
                        .frame(width: 36, height: 36)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(isCompletingWelcome)
                .opacity(isCompletingWelcome ? 0.55 : 1)
                .padding(.top, 12)
                .padding(.trailing, 18)
                .accessibilityLabel(L10n.string("settings.close.accessibility"))
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .jChordScreenBackground()
        .onChange(of: midiService.isTestNoteEnabled) { _, isEnabled in
            if isEnabled {
                welcomeNoteWasUsed = true
            }
        }
        .onAppear {
            midiService.refreshEndpoints()
            midiService.preparePreviewAudioIfNeeded()
            if midiService.selectedPreviewSoundPresetID != PreviewSoundPresetIDs.tinyPiano {
                midiService.selectPreviewSoundPreset(id: PreviewSoundPresetIDs.tinyPiano)
            }
        }
        .onDisappear {
            midiService.setTestNoteEnabled(false)
        }
    }

    private var headerSection: some View {
        VStack(alignment: .center, spacing: 8) {
            Text(L10n.string("onboarding.title"))
                .font(.system(size: 28, weight: .heavy))
                .foregroundStyle(JChordTheme.text)
                .multilineTextAlignment(.center)

            Text(L10n.string("onboarding.subtitle"))
                .font(.subheadline.weight(.medium))
                .foregroundStyle(JChordTheme.muted)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private func finishOnboarding() {
        guard !isCompletingWelcome else { return }
        isCompletingWelcome = true

        let needsNoteSettleDelay = midiService.isTestNoteEnabled || welcomeNoteWasUsed

        Task { @MainActor in
            await midiService.completeWelcomeHandoff(needsNoteSettleDelay: needsNoteSettleDelay)
            isCompletingWelcome = false
            onFinish()
        }
    }

    /// ラベルの描画幅 + 余白（ウェルカムの「TinyTone をはじめる」等）
    private static func buttonWidth(title: String, fontSize: CGFloat, extraWidth: CGFloat) -> CGFloat {
        let font = UIFont.systemFont(ofSize: fontSize, weight: .heavy)
        let textWidth = (title as NSString).size(withAttributes: [.font: font]).width
        return ceil(textWidth) + extraWidth
    }
}
