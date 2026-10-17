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
        // Release builds switch to the App Store key once App Store Connect
        // is linked and its RevenueCat key is set.
        Purchases.configure(withAPIKey: Config.EXPO_PUBLIC_REVENUECAT_TEST_API_KEY)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
