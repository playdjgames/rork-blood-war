//
//  TroopsScreen.swift
//  TheShadow
//
//  Blood War — the Troops tab (train rows, heroes, marches). The Heal tab
//  lives in HealScreen.swift.
//

import SwiftUI

// MARK: - Troops screen

struct TroopsScreen: View {
    @EnvironmentObject var store: GameStore
    @State private var counts: [String: Int] = [:]
    @State private var error: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if let e = error { Text(e).redLine() }
                ForEach(GameStore.troopTypes, id: \.self) { type in
                    TrainRow(type: type,
                             count: counts[type] ?? 0,
                             onChange: { counts[type] = $0 },
                             onTrain: { train(type) })
                }
                heroesPanel
                marchesPanel
            }
            .padding(12)
        }
        .bwScreen()
    }

    private func train(_ type: String) {
        error = store.train(type, count: counts[type] ?? 0)
        if error == nil {
            counts = [:]
        }
    }

    // Heroes: Bram the Stone, Lira the Reed, Holt the Ash.

    private var heroesPanel: some View {
        Panel {
            Text("Heroes")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(BW.text)
            ForEach(store.game.heroes) { hero in
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(hero.name) \(hero.title)")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(BW.text)
                        Text("Level \(hero.level)")
                            .font(.system(size: 12)).foregroundColor(BW.subtext)
                    }
                    Spacer()
                    if hero.assignedMarchId != nil {
                        Text("On march")
                            .font(.system(size: 12)).foregroundColor(BW.subtext)
                    } else if hero.level >= 5 {
                        Text("Max")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(BW.text)
                    } else {
                        SlateButtonSmall(title: "Rank up") {
                            error = store.levelUp(hero: hero.name)
                        }
                        .frame(width: 92)
                    }
                }
                .frame(minHeight: 44)
                if hero.assignedMarchId == nil && hero.level < 5 {
                    Text("Rank cost \(store.comma(store.heroUpCost(hero))) gold")
                        .font(.system(size: 11)).foregroundColor(BW.subtext)
                }
                skillRow(hero)
                if hero.id != store.game.heroes.last?.id {
                    Rectangle().fill(BW.stroke).frame(height: 1).padding(.vertical, 2)
                }
            }
        }
    }

    /// Skill name, level and bonus, with a 100-gold Level Up button.
    @ViewBuilder
    private func skillRow(_ hero: Hero) -> some View {
        if let skill = hero.heroSkill {
            let isMax = hero.skillLevel >= HeroSkill.maxLevel
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(skill.displayName) · Skill Lv \(hero.skillLevel)")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color(hex: 0xD2B56A))
                        .contentTransition(.numericText())
                    Text(skill.effectText(level: hero.skillLevel))
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(BW.text)
                        .contentTransition(.numericText())
                    if !isMax && hero.assignedMarchId == nil {
                        Text("Next: \(skill.effectText(level: hero.skillLevel + 1)) · \(GameStore.skillUpCost) gold")
                            .font(.system(size: 11)).foregroundColor(BW.subtext)
                    }
                }
                .animation(.spring(response: 0.35, dampingFraction: 0.8), value: hero.skillLevel)
                Spacer()
                if isMax {
                    Text("Max")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(BW.text)
                } else if hero.assignedMarchId == nil {
                    SlateButtonSmall(title: "Level Up",
                                     disabled: store.game.resources.gold < GameStore.skillUpCost) {
                        error = store.levelUpSkill(hero: hero.name)
                    }
                    .frame(width: 92)
                    .sensoryFeedback(.success, trigger: hero.skillLevel)
                }
            }
            .frame(minHeight: 44)
            .accessibilityElement(children: .contain)
        }
    }

    // Marches: shown while they are going (and working / returning).

    private var marchesPanel: some View {
        Panel {
            Text("Marches")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(BW.text)
            if store.game.marches.isEmpty {
                Text("No marches out.").bodyLine()
            }
            ForEach(store.game.marches) { march in
                MarchRow(march: march)
            }
        }
    }
}

/// One march line: "To x,y, mm:ss" while going, per the spec.
private struct MarchRow: View {
    @EnvironmentObject var store: GameStore
    let march: March

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let now = context.date.timeIntervalSince1970 * 1000
            HStack {
                Text(jobLabel)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(BW.text)
                Spacer()
                Text(detail(now: now))
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(BW.subtext)
            }
            .frame(minHeight: 24)
        }
    }

    private var jobLabel: String {
        switch march.job {
        case .gather: return "Gather"
        case .attack: return "Attack"
        case .attackHold: return "Attack hold"
        case .scout: return "Scout"
        }
    }

    private func detail(now: Double) -> String {
        let total = { (ms: Double) -> String in
            let s = max(0, Int(ceil(ms / 1000)))
            return String(format: "%d:%02d", s / 60, s % 60)
        }
        switch march.state {
        case "going":
            return "To \(march.toX),\(march.toY), \(total(march.arrivesAt - now))"
        case "working":
            return "Working \(march.toX),\(march.toY), \(total(march.arrivesAt + 60_000 - now))"
        default:
            return "Returning, \(total(store.returnsAt(march) - now))"
        }
    }
}

// MARK: - Train row

/// One troop row: photo, idle and wounded counts, stepper, Train.
private struct TrainRow: View {
    @EnvironmentObject var store: GameStore
    let type: String
    let count: Int
    let onChange: (Int) -> Void
    let onTrain: () -> Void

    private var spec: (food: Int, wood: Int, stone: Int, iron: Int, seconds: Double, building: String) {
        GameStore.troopSpecs[type] ?? (0, 0, 0, 0, 5, "")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 10) {
                Image(troopPhoto(type))
                    .resizable()
                    .scaledToFill()
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(BW.stroke, lineWidth: 1))
                VStack(alignment: .leading, spacing: 1) {
                    Text(type.capitalized)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(BW.text)
                    Text("Idle \(store.game.troops.value(type)) · Wounded \(store.game.wounded.value(type))")
                        .font(.system(size: 11)).foregroundColor(BW.subtext)
                    Text(costLine)
                        .font(.system(size: 11)).foregroundColor(BW.subtext)
                }
                Spacer()
                Stepper("", value: Binding(get: { count }, set: { onChange($0) }),
                        in: 0...max(0, store.affordMax(type)))
                    .frame(width: 96)
                    .labelsHidden()
                Text("\(count)")
                    .font(.system(size: 15, weight: .bold, design: .monospaced))
                    .foregroundColor(BW.text)
                    .frame(width: 30)
            }
            .frame(minHeight: 56)
            queueLine
            SlateButton(title: "Train", disabled: queueBusy || count == 0, action: onTrain)
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(BW.panel))
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous)
            .strokeBorder(BW.stroke, lineWidth: 1))
    }

    /// Photoreal side-profile figure per troop type (master spec art rule).
    private func troopPhoto(_ type: String) -> String {
        switch type {
        case "footman": return "medieval_footman_spear_shield"
        case "archer": return "medieval_archer_longbow"
        case "rider": return "medieval_rider_on_horse"
        case "ram": return "battering_ram"
        default: return "medieval_footman_spear_shield"
        }
    }

    private var costLine: String {
        var parts: [String] = []
        if spec.food > 0 { parts.append("\(spec.food) food") }
        if spec.wood > 0 { parts.append("\(spec.wood) wood") }
        if spec.stone > 0 { parts.append("\(spec.stone) stone") }
        if spec.iron > 0 { parts.append("\(spec.iron) iron") }
        return parts.joined(separator: ", ")
    }

    private var queueBusy: Bool { !store.game.training.isEmpty }

    @ViewBuilder private var queueLine: some View {
        if let record = store.game.training.first {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                let left = record.finishAt - context.date.timeIntervalSince1970 * 1000
                let s = max(0, Int(ceil(left / 1000)))
                Text("Training \(record.count), \(String(format: "%d:%02d", s / 60, s % 60))")
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundColor(BW.subtext)
            }
        }
    }
}
