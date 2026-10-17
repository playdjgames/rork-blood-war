//
//  PurchaseStore.swift
//  TheShadow
//
//  Blood War — RevenueCat purchases: the name change ($0.99 after the first
//  free one) and the shop products (supply bundles, speed-ups, instant
//  finish). All products live in the current offering.
//

import Observation
import RevenueCat

/// Product identifiers sold in the shop.
enum ShopProductID {
    static let nameChange = "bw_name_change"
    static let supplySack = "bw_supply_sack"
    static let supplyWagon = "bw_supply_wagon"
    static let speedUp1h = "bw_speedup_1h"
    static let instantFinish = "bw_instant_finish"
    static let fillGap = "bw_fill_gap"
}

/// Shared purchase state: fetches the current offering and sells every
/// product in the shop. One instance for the whole app.
@Observable
@MainActor
final class PurchaseStore {
    static let shared = PurchaseStore()

    private(set) var packages: [String: Package] = [:]
    private(set) var isPurchasing = false
    var error: String?

    private init() {
        Task { await fetchOfferings() }
    }

    func fetchOfferings() async {
        do {
            let offerings = try await Purchases.shared.offerings()
            var map: [String: Package] = [:]
            for package in offerings.current?.availablePackages ?? [] {
                map[package.storeProduct.productIdentifier] = package
            }
            packages = map
        } catch {
            self.error = "Couldn't reach the store. Try again."
        }
    }

    /// The localized price shown on a shop button, or the fallback when the
    /// offering hasn't loaded.
    func priceText(_ productID: String, fallback: String) -> String {
        packages[productID]?.storeProduct.localizedPriceString ?? fallback
    }

    /// Buys a product by identifier. True when the purchase completed;
    /// cancellation is not an error.
    func purchase(_ productID: String) async -> Bool {
        guard let package = packages[productID] else {
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
