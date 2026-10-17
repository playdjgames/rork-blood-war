//
//  PurchaseStore.swift
//  TheShadow
//
//  Blood War — RevenueCat purchases. The name change is $0.99 after the
//  first free one; the product (bw_name_change) lives in the current offering.
//

import Observation
import RevenueCat

/// Shared purchase state: fetches the current offering and sells the
/// name-change product. One instance for the whole app.
@Observable
@MainActor
final class PurchaseStore {
    static let shared = PurchaseStore()

    private(set) var nameChangePackage: Package?
    private(set) var isPurchasing = false
    var error: String?

    private init() {
        Task { await fetchOfferings() }
    }

    func fetchOfferings() async {
        do {
            let offerings = try await Purchases.shared.offerings()
            let current = offerings.current
            nameChangePackage =
                current?.availablePackages.first { $0.storeProduct.productIdentifier == "bw_name_change" }
                ?? current?.availablePackages.first
        } catch {
            self.error = "Couldn't reach the store. Try again."
        }
    }

    /// Buys the name-change product. True when the purchase completed;
    /// cancellation is not an error.
    func purchaseNameChange() async -> Bool {
        guard let package = nameChangePackage else {
            error = "Store not ready. Try again."
            return false
        }
        isPurchasing = true
        defer { isPurchasing = false }
        do {
            let result = try await Purchases.shared.purchase(package: package)
            return !result.userCancelled
        } catch ErrorCode.purchaseCancelledError {
            return false
        } catch ErrorCode.paymentPendingError {
            error = "Payment is awaiting approval."
            return false
        } catch {
            self.error = "Purchase failed. Try again."
            return false
        }
    }

    /// App Store review requires a restore path.
    func restore() async {
        do {
            _ = try await Purchases.shared.restorePurchases()
            error = nil
        } catch {
            self.error = "Restore failed. Try again."
        }
    }
}
