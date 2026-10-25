# Blood War: You Just Die

Post-apocalyptic castle strategy game for iOS.

## How to run

1. Open ios-ashgard-hold/TheShadow.xcodeproj in Xcode.
2. Select the TheShadow scheme.
3. Choose an iOS 18+ simulator or device.
4. Press the Run button.

## Environment

The app expects these values to be injected at build time:
- EXPO_PUBLIC_SUPABASE_URL
- EXPO_PUBLIC_SUPABASE_ANON_KEY
- EXPO_PUBLIC_REVENUECAT_TEST_API_KEY

If they are empty the game still launches and runs fully offline.

## Structure

- ios-ashgard-hold/ — the SwiftUI app
- backend/ — Supabase types
