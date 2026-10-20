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
        let key = Config.EXPO_PUBLIC_REVENUECAT_TEST_API_KEY
        if !key.isEmpty {
            Purchases.configure(withAPIKey: key)
        }
        // If the key is empty (local/dev/Rork export without env injection),
        // skip configure entirely. PurchaseStore will simply show "Store not ready"
        // and the game will launch and run normally. Real key is still injected
        // at App Store build time when the env is present.
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
