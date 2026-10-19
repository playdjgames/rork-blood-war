//
//  Tutorial.swift
//  TheShadow
//
//  Blood War — the optional guided start: a short tour that offers itself
//  the first time the game opens, walks the player through every screen,
//  and can be skipped mid-way, replayed or switched off from the player
//  menu (tap the nameplate in the resource bar).
//

import Combine
import SwiftUI

/// One stop on the guided tour. A step switches to its tab (nil keeps the
/// current one) and makes that tab glow in the tab bar while it shows.
struct TutorialStep {
    let title: String
    let text: String
    let tab: BWWallTab?

    /// The full tour, in order. The first card is the welcome; the last one
    /// hands the player the game.
    static let tour: [TutorialStep] = [
        TutorialStep(
            title: "Blood War",
            text: "Welcome, Lord. This is your hold — one castle, a meadow of lots, and a war for five holds. A short tour of the screens follows; you can skip it at any time.",
            tab: .castle
        ),
        TutorialStep(
            title: "Your hold",
            text: "The Castle screen is home. Tap any building — the Keep, the Vault, a farm — to open its sheet and upgrade it. The Keep caps every other building, so raise it first. The staked plots outside the wall take new Farms, Mills, Mines, Training Grounds and Medic Tents.",
            tab: .castle
        ),
        TutorialStep(
            title: "Supplies",
            text: "The bar up top tracks food, wood, stone, iron and gold. The four plot types pile their yield on their lots until you collect — tap the lot, then Collect. The Vault protects storehouse stock from raids; there is no cap on what you can hold.",
            tab: .castle
        ),
        TutorialStep(
            title: "Troops",
            text: "Train Footmen, Archers, Riders and Rams on the Troops screen. Each type comes from its own building — Barracks, Range, Stable, Workshop. One training queue at a time.",
            tab: .troops
        ),
        TutorialStep(
            title: "The map",
            text: "Send up to three marches. Gather from resource nodes, scout rival holds, and attack monsters — or the eight rival holds themselves. Take five holds to win the war.",
            tab: .map
        ),
        TutorialStep(
            title: "Heal",
            text: "Wounded troops fill your hospital beds instead of dying. Heal them on the Heal screen at half the training cost — beds come from the Medic Tent.",
            tab: .heal
        ),
        TutorialStep(
            title: "Research",
            text: "The Academy opens four studies that sharpen gathering, drilling, marching and healing. Each study costs 500 of every resource.",
            tab: .research
        ),
        TutorialStep(
            title: "Alliance",
            text: "Found an alliance or join one with a code. Allies share a board, and holds you take fly your banner.",
            tab: .alliance
        ),
        TutorialStep(
            title: "Daily",
            text: "Claim a reward every day — the streak grows the haul up to day seven, but a gap of more than 28 hours starts it over. Three daily quests pay extra: gather food, train troops, take a hold.",
            tab: .daily
        ),
        TutorialStep(
            title: "To war",
            text: "Raise the Keep, collect your lots, and keep training while your shield holds — Hold 1 raids every three minutes once it ends. The rest is conquest.",
            tab: .castle
        ),
    ]
}

/// Owns the tour's running state and remembers across launches whether the
/// player has seen it and whether they want it at all.
@MainActor
final class TutorialManager: ObservableObject {
    static let shared = TutorialManager()

    @Published private(set) var step = 0
    @Published private(set) var isActive = false

    private static let seenKey = "bw.tutorialSeen"
    private static let autoKey = "bw.tutorialAutoEnabled"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// Whether the tour offers itself on a first launch. Turning it off
    /// mid-tour stops the tour at once.
    var autoEnabled: Bool {
        get {
            defaults.object(forKey: Self.autoKey) == nil ? true : defaults.bool(forKey: Self.autoKey)
        }
        set {
            defaults.set(newValue, forKey: Self.autoKey)
            if !newValue { isActive = false }
        }
    }

    var hasSeenIntro: Bool { defaults.bool(forKey: Self.seenKey) }

    var current: TutorialStep? {
        TutorialStep.tour.indices.contains(step) ? TutorialStep.tour[step] : nil
    }

    /// The tab that should glow in the tab bar right now (nil when idle or
    /// on a step without a tab).
    var glowTab: BWWallTab? {
        guard isActive, let step = current else { return nil }
        return step.tab
    }

    /// Offers the tour exactly once — only on a first launch, and only if
    /// the player has not turned it off.
    func startIfFirstLaunch() {
        guard autoEnabled, !hasSeenIntro else { return }
        start()
    }

    /// Begins (or replays) the tour from the welcome card.
    func start() {
        step = 0
        isActive = true
    }

    func next() {
        guard step + 1 < TutorialStep.tour.count else {
            finish()
            return
        }
        step += 1
    }

    func back() {
        step = max(0, step - 1)
    }

    /// Skips or completes the tour: it never offers itself again on its own
    /// (the player menu can still replay it).
    func finish() {
        isActive = false
        defaults.set(true, forKey: Self.seenKey)
    }
}

/// The tour's chrome: a scrim that blocks the game while a slate card sits
/// just above the tab bar, whose glowing tab shows where the step points.
struct TutorialOverlay: View {
    @ObservedObject var manager: TutorialManager
    @Binding var tab: BWWallTab

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black.opacity(0.62)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture {} // the game waits while the tour speaks

            if let step = manager.current {
                card(step)
            }
        }
        .onChange(of: manager.step) { _, newStep in
            if let t = TutorialStep.tour[newStep].tab { tab = t }
        }
        .onAppear {
            // Replays can begin on any tab — land on the welcome step's tab.
            if let t = manager.current?.tab { tab = t }
        }
        .sensoryFeedback(.selection, trigger: manager.step)
    }

    private func card(_ step: TutorialStep) -> some View {
        let index = manager.step
        let total = TutorialStep.tour.count
        let isLast = index == total - 1
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(index == 0 ? "GUIDED START" : "STEP \(index) OF \(total - 1)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(BW.subtext)
                Spacer()
                Button("Skip") {
                    manager.finish()
                    tab = .castle
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(BW.subtext)
            }
            Text(step.title)
                .font(.system(size: 22, weight: .bold, design: .serif))
                .foregroundColor(BW.text)
            Text(step.text)
                .font(.system(size: 14))
                .foregroundColor(BW.subtext)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 5) {
                ForEach(0..<total, id: \.self) { i in
                    Circle()
                        .fill(i == index ? Color(hex: 0xD2B56A) : BW.stroke)
                        .frame(width: 6, height: 6)
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)
            HStack(spacing: 10) {
                if index > 0 {
                    SlateButtonSmall(title: "Back") { manager.back() }
                }
                SlateButton(title: index == 0 ? "Begin the tour"
                              : isLast ? "Take command" : "Next") {
                    manager.next()
                    if isLast { tab = .castle }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(BW.panelDark))
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous)
            .strokeBorder(BW.stroke, lineWidth: 1))
        .padding(.horizontal, 16)
        .padding(.bottom, 20)
    }
}
