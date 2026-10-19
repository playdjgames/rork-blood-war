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
    @ObservedObject private var tutorial = TutorialManager.shared
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
            case .daily: DailyScreen()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(BW.background)
        .safeAreaInset(edge: .top, spacing: 0) {
            ResourceBar()
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            BWTabBar(tab: $tab, glowTab: tutorial.glowTab,
                     badgeTab: store.canClaimDaily() ? .daily : nil)
        }
        .overlay {
            if store.game.victory {
                VictoryOverlay()
            }
            if tutorial.isActive {
                TutorialOverlay(manager: tutorial, tab: $tab)
            }
        }
        .environmentObject(store)
        .onAppear {
            // Let the hold art settle for a beat before the tour speaks.
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(0.6))
                tutorial.startIfFirstLaunch()
            }
        }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            store.tick()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { store.save() }
        }
    }
}

/// Full-screen victory: the winner and every hold's owner. No buttons, no dismiss.
struct VictoryOverlay: View {
    @EnvironmentObject var store: GameStore

    var body: some View {
        ZStack {
            Color.black.opacity(0.94)
                .ignoresSafeArea()
            VStack(spacing: 20) {
                Text("Victory — \(store.game.victoryWinner ?? "") controls 5 holds")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                VStack(spacing: 8) {
                    ForEach(store.game.holds) { hold in
                        HStack {
                            Text(hold.name)
                                .font(.system(size: 16, weight: .semibold))
                            Spacer()
                            Text(hold.owner ?? "Unclaimed")
                                .font(.system(size: 16, weight: .regular))
                        }
                        .foregroundColor(.white)
                    }
                }
            }
            .padding(24)
        }
        .contentShape(Rectangle())
    }
}
