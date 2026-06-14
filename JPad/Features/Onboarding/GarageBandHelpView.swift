import SwiftUI

/// 設定の HELP から開く GarageBand 連携手順（初回ウェルカムとは別画面）。
struct GarageBandHelpView: View {
    let onClose: () -> Void

    private let tutorialStepKeys = [
        "onboarding.garageband.step1",
        "onboarding.garageband.step2",
        "onboarding.garageband.step3",
        "onboarding.garageband.step4",
        "onboarding.garageband.step5",
    ]

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text(L10n.string("help.garageband.title"))
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(JChordTheme.text)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        garageBandTutorialCard

                        JPadChromeDockButton(
                            title: L10n.string("onboarding.close"),
                            style: .outline,
                            action: onClose
                        )
                        .frame(maxWidth: .infinity)
                        .padding(.top, 4)
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 20)
                    .padding(.bottom, 12)
                }

                Text("TinyRiff © 2026 FLICKER PRODUCT")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(JChordTheme.muted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 18)
                    .padding(.bottom, 12)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .jChordScreenBackground()
    }

    private var garageBandTutorialCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(Array(tutorialStepKeys.enumerated()), id: \.offset) { index, key in
                tutorialStepRow(number: index + 1, text: L10n.string(key))
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
                .foregroundStyle(JPadChromeTheme.accentLight)
                .frame(width: 22, alignment: .trailing)

            Text(text)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(JChordTheme.text)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
