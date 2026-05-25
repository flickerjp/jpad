import SwiftUI

struct ProUpgradeSheet: View {
  @ObservedObject var purchaseService: ProPurchaseService
  let onPurchased: () -> Void
  let onRestored: (Bool) -> Void

  @Environment(\.dismiss) private var dismiss
  @State private var statusMessage: String?

  private var presentation: ProSubscriptionPresentation {
    purchaseService.subscriptionPresentation
  }

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 20) {
          Text(L10n.string("pro.upgrade.subtitle"))
            .font(.subheadline)
            .foregroundStyle(JChordTheme.muted)
            .fixedSize(horizontal: false, vertical: true)

          pricingBlock

          VStack(alignment: .leading, spacing: 10) {
            benefitRow(L10n.string("pro.upgrade.benefit.slots"))
            benefitRow(L10n.string("pro.upgrade.benefit.duplicate"))
            benefitRow(L10n.string("pro.upgrade.benefit.share"))
          }

          VStack(spacing: 10) {
            Button {
              Task { await purchase() }
            } label: {
              Group {
                if purchaseService.isLoading {
                  ProgressView()
                    .tint(.white)
                } else {
                  Text(presentation.purchaseButtonTitle)
                }
              }
              .font(.headline.weight(.bold))
              .foregroundStyle(.white)
              .frame(maxWidth: .infinity)
              .frame(height: 48)
              .background(JChordTheme.unlockProminentTint, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(purchaseService.isLoading)

            Button {
              Task { await restore() }
            } label: {
              Text(L10n.string("pro.upgrade.restore"))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(JChordTheme.text)
                .frame(maxWidth: .infinity)
                .frame(height: 40)
            }
            .buttonStyle(.plain)
            .disabled(purchaseService.isLoading)
          }

          Text(L10n.string("pro.upgrade.subscription_footnote"))
            .font(.caption2)
            .foregroundStyle(JChordTheme.muted)
            .fixedSize(horizontal: false, vertical: true)

          legalLinks

          if let statusMessage {
            Text(statusMessage)
              .font(.caption)
              .foregroundStyle(JChordTheme.muted)
              .frame(maxWidth: .infinity, alignment: .leading)
          }
        }
        .padding(20)
      }
      .navigationTitle(L10n.string("pro.upgrade.title"))
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button(L10n.string("alert.cancel")) {
            dismiss()
          }
          .foregroundStyle(JChordTheme.muted)
        }
        .jChordToolbarNoGlassBackground()
      }
    }
    .jChordScreenBackground()
    .jChordSheetOuterBorder()
    .task {
      await purchaseService.loadProduct()
    }
  }

  private var pricingBlock: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(presentation.annualPriceLine)
        .font(.largeTitle.weight(.bold))
        .foregroundStyle(JChordTheme.text)
        .fixedSize(horizontal: false, vertical: true)

      Text(L10n.string("pro.upgrade.subscription_period"))
        .font(.subheadline.weight(.medium))
        .foregroundStyle(JChordTheme.muted)

      if let trialHeadline = presentation.trialHeadline {
        Text(trialHeadline)
          .font(.subheadline)
          .foregroundStyle(JChordTheme.muted)
      }

      if let trialDetailLine = presentation.trialDetailLine {
        Text(trialDetailLine)
          .font(.caption)
          .foregroundStyle(JChordTheme.muted)
          .fixedSize(horizontal: false, vertical: true)
      }

      if let checkoutTrialHint = presentation.checkoutTrialHint {
        Text(checkoutTrialHint)
          .font(.caption)
          .foregroundStyle(JChordTheme.muted)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(16)
    .background(JChordTheme.panel, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
  }

  private var legalLinks: some View {
    HStack(spacing: 16) {
      Link(L10n.string("pro.upgrade.privacy_policy"), destination: ProLegalURLs.privacyPolicy)
      Link(L10n.string("pro.upgrade.terms_of_use"), destination: ProLegalURLs.termsOfUse)
    }
    .font(.caption.weight(.semibold))
    .foregroundStyle(JChordTheme.accentOrangeMid)
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private func benefitRow(_ text: String) -> some View {
    HStack(alignment: .top, spacing: 10) {
      Image(systemName: "checkmark.circle.fill")
        .font(.body)
        .foregroundStyle(JChordTheme.accentOrangeMid)
      Text(text)
        .font(.subheadline.weight(.medium))
        .foregroundStyle(JChordTheme.text)
        .fixedSize(horizontal: false, vertical: true)
    }
  }

  private func purchase() async {
    do {
      let purchased = try await purchaseService.purchase()
      guard purchased else { return }
      onPurchased()
      dismiss()
    } catch {
      statusMessage = error.localizedDescription
    }
  }

  private func restore() async {
    do {
      let restored = try await purchaseService.restore()
      if restored {
        onRestored(true)
        dismiss()
      } else {
        onRestored(false)
        statusMessage = L10n.string("pro.upgrade.restore_none")
      }
    } catch {
      statusMessage = error.localizedDescription
    }
  }
}

private extension ToolbarContent {
  @ToolbarContentBuilder
  func jChordToolbarNoGlassBackground() -> some ToolbarContent {
    if #available(iOS 26.0, *) {
      sharedBackgroundVisibility(.hidden)
    } else {
      self
    }
  }
}
