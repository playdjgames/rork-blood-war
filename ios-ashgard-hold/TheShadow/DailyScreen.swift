//
//  DailyScreen.swift
//  TheShadow
//
//  Blood War — the Daily tab: the daily reward with its 7-day streak, and
//  three daily quests that pay out once each per reset.
//

import SwiftUI

struct DailyScreen: View {
    @EnvironmentObject var store: GameStore
    @State private var claimTick = 0

    private static let straw = Color(hex: 0xD2B56A)

    var body: some View {
        // Re-evaluated each second so Claim unlocks and the countdown moves
        // without waiting for a game change.
        TimelineView(.periodic(from: .now, by: 1)) { _ in
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    rewardPanel
                    Text("DAILY QUESTS")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(BW.subtext)
                        .padding(.top, 6)
                    ForEach(GameStore.dailyQuests) { quest in
                        QuestRow(quest: quest) {
                            store.claimQuest(quest.id)
                            claimTick += 1
                        }
                    }
                    Text("Quests reset once a day. Each pays out once per reset.")
                        .font(.system(size: 11))
                        .foregroundColor(BW.subtext)
                }
                .padding(12)
            }
        }
        .bwScreen()
        .sensoryFeedback(.success, trigger: claimTick)
    }

    // MARK: Daily reward

    private var rewardPanel: some View {
        let canClaim = store.canClaimDaily()
        let next = store.nextDailyStreak
        let reward = GameStore.dailyReward(streak: next)
        return Panel {
            HStack(alignment: .firstTextBaseline) {
                Text("Daily Reward")
                    .font(.system(size: 22, weight: .bold, design: .serif))
                    .foregroundColor(BW.text)
                Spacer()
                VStack(alignment: .trailing, spacing: 0) {
                    Text("\(store.game.dailyStreak)")
                        .font(.system(size: 28, weight: .heavy, design: .serif))
                        .foregroundColor(Self.straw)
                        .contentTransition(.numericText())
                        .animation(.spring(response: 0.4, dampingFraction: 0.7),
                                   value: store.game.dailyStreak)
                    Text("DAY STREAK")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(BW.subtext)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Streak \(store.game.dailyStreak)")
            }

            streakStrip(current: store.game.dailyStreak, next: canClaim ? next : nil)

            Text(canClaim ? "Day \(next) reward" : "Next: day \(next) reward")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(BW.text)
            rewardLine(reward)

            if canClaim, store.game.dailyStreak > 1, next == 1 {
                Text("More than 28 hours passed — the streak starts over.")
                    .font(.system(size: 12))
                    .foregroundColor(BW.red)
            }

            SlateButton(title: canClaim ? "Claim" : "Claimed — back in \(timeLeft)",
                        disabled: !canClaim) {
                store.claimDaily()
                claimTick += 1
            }
            .overlay {
                if canClaim {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(Self.straw.opacity(0.8), lineWidth: 1.5)
                        .allowsHitTesting(false)
                }
            }
        }
    }

    /// Seven cells: claimed days filled straw, the claimable day ringed.
    private func streakStrip(current: Int, next: Int?) -> some View {
        HStack(spacing: 6) {
            ForEach(1...7, id: \.self) { day in
                let filled = next == 1 ? false : day <= current
                let isNext = day == next
                VStack(spacing: 3) {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(filled ? Self.straw : BW.panelDark)
                        .overlay(RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .strokeBorder(isNext ? Self.straw : BW.stroke,
                                          lineWidth: isNext ? 1.5 : 1))
                        .frame(height: 22)
                    Text("\(day)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(isNext ? Self.straw : BW.subtext)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.75), value: current)
        .accessibilityHidden(true)
    }

    private var timeLeft: String {
        let unlockAt = store.game.lastDailyClaimAt + 20 * 3_600_000
        let total = max(0, Int(ceil((unlockAt - store.now()) / 1000)))
        return String(format: "%d:%02d:%02d", total / 3600, (total % 3600) / 60, total % 60)
    }

    private func rewardLine(_ r: Resources) -> some View {
        RewardChips(reward: r)
    }
}

// MARK: - Quest row

private struct QuestRow: View {
    @EnvironmentObject var store: GameStore
    let quest: GameStore.DailyQuest
    let onClaim: () -> Void

    var body: some View {
        let progress = store.questProgress(quest.id)
        let claimed = store.isQuestClaimed(quest.id)
        let complete = progress >= quest.goal
        let fraction = min(1, Double(progress) / Double(max(1, quest.goal)))
        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(quest.title)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(BW.text)
                    Text("\(store.comma(min(progress, quest.goal))) / \(store.comma(quest.goal))")
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundColor(complete ? Color(hex: 0xD2B56A) : BW.subtext)
                }
                Spacer()
                if claimed {
                    Text("Claimed")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(BW.subtext)
                        .frame(width: 92, height: 44)
                } else {
                    SlateButtonSmall(title: "Claim", disabled: !complete, action: onClaim)
                        .frame(width: 92)
                }
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(BW.panelDark)
                    Capsule()
                        .fill(Color(hex: 0xD2B56A))
                        .frame(width: geo.size.width * fraction)
                        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: fraction)
                }
            }
            .frame(height: 5)
            RewardChips(reward: quest.reward)
                .opacity(claimed ? 0.5 : 1)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(BW.panel))
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous)
            .strokeBorder(BW.stroke, lineWidth: 1))
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Reward chips

/// "+500 food · +500 wood" as metal-stamp icons and amounts; zero lines skip.
private struct RewardChips: View {
    @EnvironmentObject var store: GameStore
    let reward: Resources

    var body: some View {
        HStack(spacing: 10) {
            ForEach(["food", "wood", "stone", "iron", "gold"], id: \.self) { resource in
                let amount = reward.value(resource)
                if amount > 0 {
                    HStack(spacing: 3) {
                        StampIcon(name: resource, size: 12)
                        Text("+\(store.comma(amount))")
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundColor(BW.text)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(amount) \(resource)")
                }
            }
        }
    }
}
