import Foundation
import StoreKit

struct ProSubscriptionPresentation {
  let trialHeadline: String?
  let annualPriceLine: String
  let trialDetailLine: String?
  let checkoutTrialHint: String?
  let purchaseButtonTitle: String
}

enum ProSubscriptionPresentationBuilder {
  static func make(for product: Product?, isIntroEligible: Bool) -> ProSubscriptionPresentation {
    guard let product else {
      return ProSubscriptionPresentation(
        trialHeadline: nil,
        annualPriceLine: L10n.string("pro.upgrade.annual_label"),
        trialDetailLine: nil,
        checkoutTrialHint: nil,
        purchaseButtonTitle: L10n.string("pro.upgrade.purchase_button_no_price")
      )
    }

    let annualPrice = product.displayPrice
    let annualPriceLine = L10n.format("pro.upgrade.annual_price", annualPrice)

    if isIntroEligible, let intro = product.subscription?.introductoryOffer {
      switch intro.paymentMode {
      case .freeTrial:
        let trialPeriod = localizedOfferDuration(period: intro.period, periodCount: intro.periodCount)
        return ProSubscriptionPresentation(
          trialHeadline: L10n.format("pro.upgrade.trial_headline", trialPeriod),
          annualPriceLine: annualPriceLine,
          trialDetailLine: L10n.format("pro.upgrade.trial_detail", trialPeriod, annualPrice),
          checkoutTrialHint: nil,
          purchaseButtonTitle: L10n.format("pro.upgrade.purchase_button", annualPrice)
        )
      case .payAsYouGo, .payUpFront:
        break
      default:
        break
      }
    }

    return ProSubscriptionPresentation(
      trialHeadline: nil,
      annualPriceLine: annualPriceLine,
      trialDetailLine: nil,
      checkoutTrialHint: product.subscription == nil
        ? nil
        : L10n.string("pro.upgrade.trial_checkout_hint"),
      purchaseButtonTitle: L10n.format("pro.upgrade.purchase_button", annualPrice)
    )
  }

  private static func localizedOfferDuration(
    period: Product.SubscriptionPeriod,
    periodCount: Int
  ) -> String {
    let count = max(1, periodCount) * max(1, period.value)
    switch period.unit {
    case .day:
      if count == 30 {
        return L10n.string("pro.period.30days")
      }
      if count == 1 {
        return L10n.string("pro.period.1day")
      }
      return L10n.format("pro.period.days", count)
    case .week:
      if count == 1 {
        return L10n.string("pro.period.1week")
      }
      return L10n.format("pro.period.weeks", count)
    case .month:
      if count == 1 {
        return L10n.string("pro.period.1month")
      }
      return L10n.format("pro.period.months", count)
    case .year:
      if count == 1 {
        return L10n.string("pro.period.1year")
      }
      return L10n.format("pro.period.years", count)
    @unknown default:
      return L10n.format("pro.period.days", count)
    }
  }
}
