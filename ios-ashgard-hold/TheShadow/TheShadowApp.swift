//
//  TheShadowApp.swift
//  TheShadow
//
//  Created by Rork on September 17, 2026.
//

import RevenueCat
import SwiftUI

@main
struct TheShadowApp: App {
    init() {
        #if DEBUG
        Purchases.logLevel = .debug
        #endif
        if let key = Self.revenueCatKey() {
            Purchases.configure(withAPIKey: key)
            Task { await PurchaseStore.shared.fetchOfferings() }
        }
        // No usable key: skip configure entirely. PurchaseStore shows
        // "Store not ready" and the game launches and runs normally.
    }

    /// The RevenueCat key this build may use, or nil.
    /// RevenueCat crashes on purpose when a Test Store key ("test_…") is
    /// configured in a Release build (every real-iPhone, TestFlight and App
    /// Store build). So Release builds only accept a real App Store key
    /// ("appl_…"); the test key is used in Debug (simulator) only.
    private static func revenueCatKey() -> String? {
        let key = Config.EXPO_PUBLIC_REVENUECAT_TEST_API_KEY
        guard !key.isEmpty else { return nil }
        #if DEBUG
        return key
        #else
        return key.hasPrefix("test_") ? nil : key
        #endif
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
