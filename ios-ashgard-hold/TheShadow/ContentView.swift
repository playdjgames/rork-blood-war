//
//  ContentView.swift
//  TheShadow
//
//  Blood War — root: resource bar (36pt, fixed), the six tabs, the tab bar
//  (64pt + safe area), and the 1-second engine tick.
//

import Combine
import SwiftUI

struct ContentView: View {
    @StateObject private var store = GameStore()
    @State private var tab: BWWallTab = .castle // home: the castle yard, opens on launch
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        VStack(spacing: 0) {
            switch tab {
            case .map: MapScreen()
            case .castle: CastleScreen()
            case .troops: TroopsScreen()
            case .heal: HealScreen()
            case .research: ResearchScreen()
            case .alliance: AllianceScreen()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(BW.background)
        .safeAreaInset(edge: .top, spacing: 0) {
            ResourceBar()
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            BWTabBar(tab: $tab)
        }
        .environmentObject(store)
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            store.tick()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { store.save() }
        }
    }
}
