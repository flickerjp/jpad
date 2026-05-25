import Foundation
import StoreKit

enum ProPurchaseError: LocalizedError {
  case productUnavailable
  case purchaseFailed

  var errorDescription: String? {
    switch self {
    case .productUnavailable:
      return L10n.string("pro.purchase.error.unavailable")
    case .purchaseFailed:
      return L10n.string("pro.purchase.error.failed")
    }
  }
}

enum ProLegalURLs {
  static let privacyPolicy = URL(string: "https://flicker-jp.com/privacy")!
  static let termsOfUse = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
}

/// JPad Pro 年額サブスクリプション。App Store Connect の Product ID と一致させる。
@MainActor
final class ProPurchaseService: ObservableObject {
  static let yearlyProductID = "com.jflickeys.jchord.pro.yearly"
  static let productIDs: Set<String> = [yearlyProductID]
  static let purchasedAppStorageKey = "jchord.presetSavePurchased"

  @Published private(set) var product: Product?
  @Published private(set) var isIntroductoryOfferEligible = false
  @Published private(set) var isLoading = false
  @Published private(set) var lastErrorMessage: String?

  private var transactionListenerTask: Task<Void, Never>?

  deinit {
    transactionListenerTask?.cancel()
  }

  func startTransactionListener() {
    guard transactionListenerTask == nil else { return }
    transactionListenerTask = Task { [weak self] in
      for await result in Transaction.updates {
        guard let self else { return }
        guard case .verified(let transaction) = result else { continue }
        guard Self.productIDs.contains(transaction.productID) else { continue }
        await transaction.finish()
        _ = await self.refreshEntitlement()
      }
    }
  }

  func loadProduct() async {
    do {
      let products = try await Product.products(for: [Self.yearlyProductID])
      product = products.first
      if let subscription = products.first?.subscription {
        isIntroductoryOfferEligible = await subscription.isEligibleForIntroOffer
      } else {
        isIntroductoryOfferEligible = false
      }
    } catch {
      product = nil
      isIntroductoryOfferEligible = false
      lastErrorMessage = error.localizedDescription
    }
  }

  @discardableResult
  func refreshEntitlement() async -> Bool {
    let status = await refreshSubscriptionStatus()
    return status.isActive
  }

  func refreshSubscriptionStatus() async -> ProSubscriptionStatus {
    await ProSubscriptionStatusFetcher.fetch()
  }

  var displayPrice: String {
    product?.displayPrice ?? L10n.string("pro.purchase.price_fallback")
  }

  var subscriptionPresentation: ProSubscriptionPresentation {
    ProSubscriptionPresentationBuilder.make(
      for: product,
      isIntroEligible: isIntroductoryOfferEligible
    )
  }

  func purchase() async throws -> Bool {
    guard let product else {
      throw ProPurchaseError.productUnavailable
    }

    isLoading = true
    lastErrorMessage = nil
    defer { isLoading = false }

    let result = try await product.purchase()
    switch result {
    case .success(let verification):
      let transaction = try Self.checkVerified(verification)
      await transaction.finish()
      return await refreshEntitlement()
    case .userCancelled:
      return false
    case .pending:
      lastErrorMessage = L10n.string("pro.purchase.pending")
      return false
    @unknown default:
      throw ProPurchaseError.purchaseFailed
    }
  }

  func restore() async throws -> Bool {
    isLoading = true
    lastErrorMessage = nil
    defer { isLoading = false }

    try await AppStore.sync()
    return await refreshEntitlement()
  }

  private static func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
    switch result {
    case .unverified:
      throw ProPurchaseError.purchaseFailed
    case .verified(let safe):
      return safe
    }
  }
}
