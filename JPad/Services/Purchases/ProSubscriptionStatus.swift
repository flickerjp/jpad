import Foundation
import StoreKit

/// 設定画面などに表示する JPad Pro サブスクリプション状態。
struct ProSubscriptionStatus: Equatable {
  var isActive: Bool
  var expirationDate: Date?
  var willAutoRenew: Bool?

  static let free = ProSubscriptionStatus(isActive: false, expirationDate: nil, willAutoRenew: nil)

  var statusLabel: String {
    isActive
      ? L10n.string("settings.pro.status_purchased")
      : L10n.string("settings.pro.status_free")
  }

  var dateRow: (label: String, date: String)? {
    guard isActive, let expirationDate else { return nil }
    let dateText = Self.formattedDate(expirationDate)
    switch willAutoRenew {
    case true:
      return (L10n.string("settings.pro.renewal_label"), dateText)
    case false, nil:
      return (L10n.string("settings.pro.expiration_label"), dateText)
    }
  }

  var accessibilityLabel: String {
    let section = L10n.string("settings.pro.section_title")
    var parts = ["\(section) - \(statusLabel)"]
    if let dateRow {
      parts.append("\(dateRow.label) \(dateRow.date)")
    }
    return parts.joined(separator: ". ")
  }

  private static func formattedDate(_ date: Date) -> String {
    let calendar = Calendar.autoupdatingCurrent
    let day = calendar.startOfDay(for: date)
    return day.formatted(
      .dateTime
        .year()
        .month()
        .day()
        .locale(.autoupdatingCurrent)
    )
  }
}

enum ProSubscriptionStatusFetcher {
  @MainActor
  static func fetch() async -> ProSubscriptionStatus {
    var best: ProSubscriptionStatus?

    if let fromSubscriptionInfo = await statusFromSubscriptionInfo() {
      best = preferred(best, fromSubscriptionInfo)
    }
    if let fromLatestTransaction = await statusFromLatestTransactions() {
      best = preferred(best, fromLatestTransaction)
    }
    best = preferred(best, await statusFromCurrentEntitlements())

    let result = best ?? .free
    UserDefaults.standard.set(result.isActive, forKey: ProPurchaseService.purchasedAppStorageKey)
    return result
  }

  private static func preferred(
    _ current: ProSubscriptionStatus?,
    _ candidate: ProSubscriptionStatus
  ) -> ProSubscriptionStatus {
    guard let current else { return candidate }
    return shouldPrefer(candidate, over: current) ? candidate : current
  }

  /// 次回更新表示用。`RenewalInfo.renewalDate` を優先（`expirationDate` だけだと現在期間の終端が今日になることがある）。
  private static func nextRenewalDate(
    transaction: Transaction,
    renewalInfo: Product.SubscriptionInfo.RenewalInfo?
  ) -> Date? {
    if let renewalInfo, let renewalDate = renewalInfo.renewalDate {
      return renewalDate
    }
    return transaction.expirationDate
  }

  @MainActor
  private static func statusFromSubscriptionInfo() async -> ProSubscriptionStatus? {
    let products = (try? await Product.products(for: Array(ProPurchaseService.productIDs))) ?? []
    guard !products.isEmpty else { return nil }

    var best: ProSubscriptionStatus?
    var sawStatus = false

    for product in products {
      guard let subscription = product.subscription else { continue }
      guard let statuses = try? await subscription.status else { continue }
      sawStatus = true

      for status in statuses {
        guard case .verified(let transaction) = status.transaction else { continue }
        guard ProPurchaseService.productIDs.contains(transaction.productID) else { continue }

        let isEntitled: Bool
        switch status.state {
        case .subscribed, .inGracePeriod, .inBillingRetryPeriod:
          isEntitled = true
        case .expired, .revoked:
          isEntitled = false
        default:
          isEntitled = false
        }

        guard isEntitled, transaction.revocationDate == nil else { continue }

        let renewalInfo: Product.SubscriptionInfo.RenewalInfo? = {
          guard case .verified(let info) = status.renewalInfo else { return nil }
          return info
        }()

        let candidate = ProSubscriptionStatus(
          isActive: true,
          expirationDate: nextRenewalDate(transaction: transaction, renewalInfo: renewalInfo),
          willAutoRenew: renewalInfo?.willAutoRenew
        )
        if shouldPrefer(candidate, over: best) {
          best = candidate
        }
      }
    }

    if let best {
      return best
    }
    if !sawStatus {
      return nil
    }
    return .free
  }

  @MainActor
  private static func statusFromLatestTransactions() async -> ProSubscriptionStatus? {
    var best: ProSubscriptionStatus?

    for productID in ProPurchaseService.productIDs {
      guard let result = await Transaction.latest(for: productID),
            case .verified(let transaction) = result
      else { continue }
      guard transaction.revocationDate == nil else { continue }

      let candidate = ProSubscriptionStatus(
        isActive: true,
        expirationDate: transaction.expirationDate,
        willAutoRenew: nil
      )
      if shouldPrefer(candidate, over: best) {
        best = candidate
      }
    }

    return best
  }

  @MainActor
  private static func statusFromCurrentEntitlements() async -> ProSubscriptionStatus {
    var best: ProSubscriptionStatus?

    for await result in Transaction.currentEntitlements {
      guard case .verified(let transaction) = result else { continue }
      guard ProPurchaseService.productIDs.contains(transaction.productID) else { continue }
      guard transaction.revocationDate == nil else { continue }

      let candidate = ProSubscriptionStatus(
        isActive: true,
        expirationDate: transaction.expirationDate,
        willAutoRenew: nil
      )
      if shouldPrefer(candidate, over: best) {
        best = candidate
      }
    }

    return best ?? .free
  }

  private static func shouldPrefer(
    _ candidate: ProSubscriptionStatus,
    over current: ProSubscriptionStatus?
  ) -> Bool {
    guard let current else { return true }
    switch (candidate.expirationDate, current.expirationDate) {
    case let (c?, cur?):
      let now = Date()
      let candidateIsFuture = c > now
      let currentIsFuture = cur > now
      if candidateIsFuture != currentIsFuture {
        return candidateIsFuture
      }
      return c > cur
    case (_?, nil):
      return true
    default:
      return false
    }
  }
}
