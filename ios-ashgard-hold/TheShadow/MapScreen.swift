//
//  MapScreen.swift
//  TheShadow
//
//  Blood War — the 50×50 map (72pt photo tiles, drag scroll clamped at the
//  edges), the 320pt tile sheet with its march buttons and pickers, and the
//  log sheet.
//

import SwiftUI

// MARK: - Map screen

struct MapScreen: View {
    @EnvironmentObject var store: GameStore
    @State private var selectedTile: MapTile?
    @State private var showLog = false

    var body: some View {
        GeometryReader { geo in
            MapScroller(tiles: store.game.mapTiles) { tile in
                selectedTile = tile
            }
            .overlay(alignment: .bottomTrailing) {
                Button(action: { showLog = true }) {
                    Text("Log")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(BW.text)
                        .frame(width: 88, height: 48)
                        .background(RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(BW.panel))
                        .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .strokeBorder(BW.stroke, lineWidth: 1))
                        .shadow(color: .black.opacity(0.5), radius: 3, y: 2)
                }
                .padding(12)
                .accessibilityLabel("Log")
            }
        }
        .bwScreen()
        .sheet(item: $selectedTile) { tile in
            TileSheet(tile: tile)
                .presentationDetents([.height(320)])
        }
        .sheet(isPresented: $showLog) {
            LogSheet()
                .presentationDetents([.height(420)])
        }
    }
}

// MARK: - Scroller

/// The 50×50 tile world (3600×3600pt), dragged by finger, clamped so it can
/// never scroll past the edge. Starts centered on the player's castle.
private struct MapScroller: View {
    let tiles: [MapTile]
    let onTap: (MapTile) -> Void

    @State private var offset: CGSize = .zero
    @State private var startOffset: CGSize?
    @State private var didCenter = false

    private let contentSize: CGFloat = 3600

    var body: some View {
        GeometryReader { geo in
            let clampX = min(0, geo.size.width - contentSize)
            let clampY = min(0, geo.size.height - contentSize)
            ZStack(alignment: .topLeading) {
                LazyVGrid(columns: Array(repeating: GridItem(.fixed(72), spacing: 0), count: 50),
                          spacing: 0) {
                    ForEach(yRows, id: \.self) { y in
                        ForEach(0..<50, id: \.self) { x in
                            TileCell(tile: tileAt(x, y)) { onTap(tileAt(x, y)) }
                        }
                    }
                }
                .frame(width: contentSize, height: contentSize, alignment: .topLeading)
                .offset(x: offset.width, y: offset.height)
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
            .clipped()
            .contentShape(Rectangle())
            .gesture(
                DragGesture()
                    .onChanged { value in
                        if startOffset == nil { startOffset = offset }
                        let raw = CGSize(width: (startOffset?.width ?? 0) + value.translation.width,
                                         height: (startOffset?.height ?? 0) + value.translation.height)
                        offset = CGSize(width: min(0, max(clampX, raw.width)),
                                        height: min(0, max(clampY, raw.height)))
                    }
                    .onEnded { _ in startOffset = nil }
            )
            .onAppear { center(geo: geo, clampX: clampX, clampY: clampY) }
            .onChange(of: geo.size) { _, newSize in
                center(geo: geo, clampX: clampX, clampY: clampY)
                _ = newSize
            }
        }
    }

    private var yRows: [Int] { Array(0..<50) }

    private func tileAt(_ x: Int, _ y: Int) -> MapTile {
        tiles.first { $0.x == x && $0.y == y }
            ?? MapTile(type: .plain, x: x, y: y, remaining: nil)
    }

    private func center(geo: GeometryProxy, clampX: CGFloat, clampY: CGFloat) {
        guard !didCenter else { return }
        didCenter = true
        // Center on the player's castle at 25,25.
        let castleCenter = CGFloat(25.5) * 72
        let x = clamp((geo.size.width / 2 - castleCenter), clampX, 0)
        let y = clamp((geo.size.height / 2 - castleCenter), clampY, 0)
        offset = CGSize(width: x, height: y)
    }

    private func clamp(_ v: CGFloat, _ lo: CGFloat, _ hi: CGFloat) -> CGFloat {
        min(hi, max(lo, v))
    }
}

// MARK: - Tile cell

/// One map tile: a 72×72 photo crop with a white label strip on the bottom.
private struct TileCell: View {
    let tile: MapTile
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .bottom) {
                Image(photoName)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 72, height: 72)
                    .clipped()
                Text(tile.title)
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.white)
                    .shadow(color: .black, radius: 2)
                    .frame(width: 72)
                    .padding(.vertical, 1)
                    .background(Color.black.opacity(0.55))
            }
            .frame(width: 72, height: 72)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tile.title)
    }

    private var photoName: String {
        switch tile.type {
        case .plain: return "tile_plain"
        case .food: return "wheat_field_topdown"
        case .wood: return "lumber_mill_topdown"
        case .stone: return "gravel_plot_boulder"
        case .iron: return "iron_mine_diorama"
        case .gold: return "gold_coins_pile"
        case .monster: return "muddy_stone_ruin"
        case .castle: return "photo_keep"
        case .hold: return "tile_hold"
        }
    }
}

// MARK: - Tile sheet

/// The 320pt bottom sheet. Title is the tile label; body lists the rules for
/// that tile; buttons are only the legal march ones.
struct TileSheet: View {
    @EnvironmentObject var store: GameStore
    let tile: MapTile
    @Environment(\.dismiss) private var dismiss

    @State private var picking = false
    @State private var counts = TroopCounts.zero
    @State private var heroName: String?
    @State private var error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(tile.title)
                .font(.system(size: 19, weight: .bold))
                .foregroundColor(BW.text)
            if picking {
                pickerBody
            } else {
                rulesBody
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(BW.background)
    }

    // Rules per tile type, plus the legal buttons only.

    @ViewBuilder private var rulesBody: some View {
        switch tile.type {
        case .plain:
            Text("Nothing here.")
                .bodyLine()
        case .castle:
            Text("Your keep. Level \(store.game.keepLevel).")
                .bodyLine()
        case .monster:
            Text("Power \(store.monsterPower(x: tile.x, y: tile.y)). Farther from your castle, stronger. Win: loot of food, wood, iron and gold — the monster falls. Lose: 5% wounded, the monster stays.")
                .bodyLine()
            if store.game.marches.count < 3 {
                SlateButtonSmall(title: "Attack") { picking = true }
            } else {
                Text("Marches allowed: 3").redLine()
            }
        case .hold:
            holdRules
        case .food, .wood, .stone, .iron, .gold:
            Text("Remaining: \(store.comma(tile.remaining ?? 0)). Gather pays \(store.game.research.gather ? 240 : 200) per troop, cap \(store.game.research.gather ? 2400 : 2000).")
                .bodyLine()
            if store.game.marches.count < 3 {
                SlateButtonSmall(title: "Gather") { picking = true }
            } else {
                Text("Marches allowed: 3").redLine()
            }
        }
    }

    @ViewBuilder private var holdRules: some View {
        let hold = store.hold(at: tile.x, y: tile.y)
        Text("Power \(hold?.power ?? 0). Win: take 10% of its food and wood; it is shielded 5 minutes. Lose: 5% wounded, no loot.")
            .bodyLine()
        if let hold {
            HStack {
                Text("Held by").bodyLine()
                Spacer()
                Text(holdOwnerLabel(hold))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(hold.owner == nil ? BW.subtext : BW.text)
            }
        }
        if hold != nil, (hold!.shieldUntil) > store.now() {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                let left = max(0, Int((hold!.shieldUntil - context.date.timeIntervalSince1970 * 1000) / 1000))
                Text(left > 0 ? "Shielded \(left / 60):\(String(format: "%02d", left % 60))" : "Shield down")
                    .redLine()
            }
        }
        if store.isShielded {
            Text("Drop shield to attack").redLine()
            SlateButtonSmall(title: "Scout", disabled: store.game.marches.count >= 3) {
                _ = store.scout(x: tile.x, y: tile.y)
                dismiss()
            }
        } else if store.game.marches.count < 3 {
            HStack(spacing: 8) {
                SlateButtonSmall(title: "Attack hold") { picking = true }
                SlateButtonSmall(title: "Scout") {
                    _ = store.scout(x: tile.x, y: tile.y)
                    dismiss()
                }
            }
        } else {
            Text("Marches allowed: 3").redLine()
        }
    }

    /// Your alliance's own holds read as its name; rivals by their banner.
    private func holdOwnerLabel(_ hold: Hold) -> String {
        guard let owner = hold.owner else { return "Unclaimed" }
        if let a = store.game.alliance, owner == a.code { return "\(a.name) [\(a.code)]" }
        return owner
    }

    // The picker: four steppers capped at idle troops, hero picker, Send.

    private var pickerBody: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let e = error { Text(e).redLine() }
            ForEach(GameStore.troopTypes, id: \.self) { type in
                Stepper(value: Binding(
                            get: { counts.value(type) },
                            set: { counts = capped(type, $0) })) {
                    HStack {
                        Text(type.capitalized).font(.system(size: 13, weight: .medium)).foregroundColor(BW.text)
                        Spacer()
                        Text("\(counts.value(type)) / idle \(store.game.troops.value(type))")
                            .font(.system(size: 12, design: .monospaced)).foregroundColor(BW.subtext)
                    }
                }
                .frame(height: 30)
            }
            Picker("Hero", selection: $heroName) {
                Text("No hero").tag(String?.none)
                ForEach(store.game.heroes.filter { $0.assignedMarchId == nil }) { h in
                    Text("\(h.name) — \(h.heroSkill?.effectText(level: h.skillLevel) ?? h.title)")
                        .tag(String?.some(h.name))
                }
            }
            .pickerStyle(.menu)
            .font(.system(size: 13))
            .foregroundColor(BW.text)
            .frame(height: 30)
            SlateButton(title: "Send", disabled: counts.total == 0) {
                let job: MarchJob = tile.type == .monster ? .attack
                    : (tile.type == .hold ? .attackHold : .gather)
                let err = store.sendMarch(toX: tile.x, toY: tile.y, job: job,
                                          troops: counts, heroName: heroName)
                if err == nil { dismiss() } else { error = err }
            }
        }
    }

    private func capped(_ type: String, _ value: Int) -> TroopCounts {
        var c = counts
        c.subtract(type, c.value(type))
        c.add(type, max(0, min(value, store.game.troops.value(type))))
        return c
    }
}

// MARK: - Log sheet

/// The last 30 log lines, newest first, each starting with the local time.
struct LogSheet: View {
    @EnvironmentObject var store: GameStore

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Log")
                .font(.system(size: 19, weight: .bold))
                .foregroundColor(BW.text)
            if store.game.log.isEmpty {
                Text("Nothing yet.").bodyLine()
            }
            ForEach(Array(store.game.log.enumerated()), id: \.offset) { _, line in
                Text(line)
                    .font(.system(size: 12))
                    .foregroundColor(BW.subtext)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(BW.background)
    }
}

// MARK: - Text helpers

extension Text {
    func bodyLine() -> some View {
        font(.system(size: 13))
            .foregroundColor(BW.subtext)
            .fixedSize(horizontal: false, vertical: true)
    }

    func redLine() -> some View {
        font(.system(size: 12, weight: .semibold))
            .foregroundColor(BW.red)
            .fixedSize(horizontal: false, vertical: true)
    }
}
