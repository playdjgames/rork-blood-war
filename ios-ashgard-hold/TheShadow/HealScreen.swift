//
//  HealScreen.swift
//  TheShadow
//
//  Blood War — the Heal tab: hospital beds, one heal row per troop type with
//  a count stepper, and the healing queue. Healing runs through the existing
//  `GameStore.heal(_:count:)` (half train cost, 3 s per troop, shared queue).
//

import SwiftUI

// MARK: - Heal screen

struct HealScreen: View {
    @EnvironmentObject var store: GameStore
    @State private var counts: [String: Int] = [:]
    @State private var error: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                hospitalPanel
                if let e = error { Text(e).redLine() }
                ForEach(GameStore.troopTypes, id: \.self) { type in
                    HealRow(type: type,
                            count: clamped(type, counts[type]),
                            onChange: { counts[type] = $0 },
                            onHeal: { heal(type) })
                }
                queuePanel
            }
            .padding(12)
        }
        .bwScreen()
    }

    /// The stepper's value for a type: defaults to every wounded troop the
    /// player can afford, and never exceeds what is wounded right now.
    private func clamped(_ type: String, _ value: Int?) -> Int {
        let maxCount = HealRow.maxHealable(type, store: store)
        return min(value ?? maxCount, maxCount)
    }

    private func heal(_ type: String) {
        let n = clamped(type, counts[type])
        error = store.heal(type, count: n)
        if error == nil { counts[type] = nil }
    }

    // Hospital: wounded per type and beds used.

    private var hospitalPanel: some View {
        let full = store.beds > 0 && store.woundedTotal >= store.beds
        return Panel {
            Text("Hospital")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(BW.text)
            HStack(alignment: .firstTextBaseline) {
                Text("Beds used")
                    .font(.system(size: 14)).foregroundColor(BW.subtext)
                Spacer()
                Text("\(store.comma(store.woundedTotal)) / \(store.comma(store.beds))")
                    .font(.system(size: 15, weight: .bold, design: .monospaced))
                    .foregroundColor(full ? BW.red : BW.text)
                    .contentTransition(.numericText())
                    .animation(.default, value: store.woundedTotal)
            }
            GeometryReader { geo in
                let fraction = store.beds > 0
                    ? min(1, Double(store.woundedTotal) / Double(store.beds)) : 0
                ZStack(alignment: .leading) {
                    Capsule().fill(BW.panelDark)
                    Capsule()
                        .fill(full ? BW.red : BW.highlight)
                        .frame(width: geo.size.width * fraction)
                        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: fraction)
                }
            }
            .frame(height: 5)
            HStack(spacing: 0) {
                ForEach(GameStore.troopTypes, id: \.self) { type in
                    VStack(spacing: 1) {
                        Text("\(store.game.wounded.value(type))")
                            .font(.system(size: 15, weight: .bold, design: .monospaced))
                            .foregroundColor(BW.text)
                        Text(type.capitalized)
                            .font(.system(size: 11)).foregroundColor(BW.subtext)
                    }
                    .frame(maxWidth: .infinity)
                    .accessibilityElement(children: .combine)
                }
            }
            .padding(.top, 2)
            if full {
                Text("Hospital full — new wounded die.")
                    .font(.system(size: 12)).foregroundColor(BW.red)
            }
        }
    }

    // Queue: the single training/healing queue with remaining time.

    private var queuePanel: some View {
        Panel {
            Text("Healing queue")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(BW.text)
            if store.game.training.isEmpty {
                Text("No one in the queue.").bodyLine()
            }
            ForEach(Array(store.game.training.enumerated()), id: \.offset) { _, record in
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    let left = record.finishAt - context.date.timeIntervalSince1970 * 1000
                    let s = max(0, Int(ceil(left / 1000)))
                    HStack {
                        Text(record.kind == .heal
                             ? "Healing \(record.count) \(record.type)"
                             : "Training \(record.count) \(record.type)")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(BW.text)
                        Spacer()
                        Text(String(format: "%d:%02d", s / 60, s % 60))
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                            .foregroundColor(BW.subtext)
                    }
                    .frame(minHeight: 24)
                }
            }
            if let record = store.game.training.first, record.kind == .train {
                Text("Training and healing share one queue.")
                    .font(.system(size: 11)).foregroundColor(BW.subtext)
            }
        }
    }
}

// MARK: - Heal row

/// One wounded row: photo, wounded count, stepper, cost and time, Heal button.
private struct HealRow: View {
    @EnvironmentObject var store: GameStore
    let type: String
    let count: Int
    let onChange: (Int) -> Void
    let onHeal: () -> Void

    /// Wounded of this type the player can afford to heal right now.
    static func maxHealable(_ type: String, store: GameStore) -> Int {
        let wounded = store.game.wounded.value(type)
        let unit = store.healCost(type, count: 1)
        var m = wounded
        for resource in ["food", "wood", "stone", "iron"] where unit.value(resource) > 0 {
            m = min(m, store.game.resources.value(resource) / unit.value(resource))
        }
        return max(0, m)
    }

    private var wounded: Int { store.game.wounded.value(type) }
    private var queueBusy: Bool { !store.game.training.isEmpty }

    var body: some View {
        let maxCount = Self.maxHealable(type, store: store)
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 10) {
                Image(troopPhoto(type))
                    .resizable()
                    .scaledToFill()
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(BW.stroke, lineWidth: 1))
                    .opacity(wounded == 0 ? 0.5 : 1)
                VStack(alignment: .leading, spacing: 1) {
                    Text(type.capitalized)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(BW.text)
                    Text("Wounded \(wounded)")
                        .font(.system(size: 11)).foregroundColor(BW.subtext)
                    if wounded > 0 {
                        Text(costLine)
                            .font(.system(size: 11)).foregroundColor(BW.subtext)
                    }
                }
                Spacer()
                if wounded > 0 {
                    Stepper("Heal count", value: Binding(get: { count }, set: { onChange($0) }),
                            in: 0...maxCount)
                        .frame(width: 96)
                        .labelsHidden()
                        .disabled(maxCount == 0)
                    Text("\(count)")
                        .font(.system(size: 15, weight: .bold, design: .monospaced))
                        .foregroundColor(BW.text)
                        .frame(width: 30)
                }
            }
            .frame(minHeight: 56)
            if wounded > 0 {
                if maxCount < wounded {
                    Text(maxCount == 0
                         ? (store.healShortLine(type, count: 1) ?? "Not enough resources.")
                         : "Can afford \(maxCount) of \(wounded).")
                        .font(.system(size: 11)).foregroundColor(BW.red)
                }
                SlateButton(title: count > 0 ? "Heal \(count) · \(timeText)" : "Heal",
                            disabled: queueBusy || count == 0,
                            action: onHeal)
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(BW.panel))
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous)
            .strokeBorder(BW.stroke, lineWidth: 1))
    }

    /// Same formula as `GameStore.heal`: 3 seconds per troop.
    private var timeText: String {
        let s = 3 * count
        return String(format: "%d:%02d", s / 60, s % 60)
    }

    private var costLine: String {
        let cost = store.healCost(type, count: max(count, 1))
        var parts: [String] = []
        if cost.food > 0 { parts.append("\(store.comma(cost.food)) food") }
        if cost.wood > 0 { parts.append("\(store.comma(cost.wood)) wood") }
        if cost.stone > 0 { parts.append("\(store.comma(cost.stone)) stone") }
        if cost.iron > 0 { parts.append("\(store.comma(cost.iron)) iron") }
        let label = count > 1 ? "Cost for \(count): " : "Cost: "
        return parts.isEmpty ? "Free" : label + parts.joined(separator: ", ")
    }

    private func troopPhoto(_ type: String) -> String {
        switch type {
        case "footman": return "medieval_footman_spear_shield"
        case "archer": return "medieval_archer_longbow"
        case "rider": return "medieval_rider_on_horse"
        case "ram": return "battering_ram"
        default: return "medieval_footman_spear_shield"
        }
    }
}
