//
//  GameStore.swift
//  TheShadow
//
//  Blood War — the whole engine: save file (bloodWarSave.json), production,
//  training, healing, upgrades, marches, combat, shields, research, heroes,
//  alliance and the log. Views read `game` and call the action methods; every
//  mutation ends in `save()`.
//

import Combine
import Foundation
import SwiftUI

@MainActor
final class GameStore: ObservableObject {
    @Published private(set) var game: SaveRecord

    /// The 14 buildings in their exact spec order.
    static let buildingOrder = ["Keep", "Farm", "Timber yard", "Quarry", "Mine", "Vault",
                                "Barracks", "Range", "Stable", "Workshop", "Wall",
                                "Hospital", "Academy", "Rally yard"]

    static let troopTypes = ["footman", "archer", "rider", "ram"]

    /// Per-head cost and time, and the building that unlocks the type.
    static let troopSpecs: [String: (food: Int, wood: Int, stone: Int, iron: Int,
                                     seconds: Double, building: String)] = [
        "footman": (50, 20, 0, 0, 5, "Barracks"),
        "archer": (40, 40, 0, 0, 5, "Range"),
        "rider": (80, 0, 0, 40, 5, "Stable"),
        "ram": (0, 100, 100, 50, 8, "Workshop"),
    ]

    /// Research rows in display order.
    static let researchRows: [(field: ResearchField, name: String)] = [
        (.gather, "Gather lore"),
        (.train, "Drill"),
        (.march, "Route maps"),
        (.hospital, "Field beds"),
    ]

    private let saveURL: URL
    private let defaults: UserDefaults
    private let lastProductionKey = "bw.lastProductionAt"
    private let lastIncomingKey = "bw.lastIncomingAt"
    private let registryKey = "bw.allianceRegistry"

    /// Milliseconds since 1970. Injectable so tests can drive the clock.
    var now: () -> Double

    static func defaultSaveURL() -> URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("bloodWarSave.json")
    }

    init(saveURL: URL? = nil,
         defaults: UserDefaults = .standard,
         startsTimer: Bool = true,
         clock: @escaping () -> Double = { Date().timeIntervalSince1970 * 1000 }) {
        self.now = clock
        self.defaults = defaults
        let url = saveURL ?? Self.defaultSaveURL()
        self.saveURL = url

        if let data = try? Data(contentsOf: url),
           let record = try? JSONDecoder().decode(SaveRecord.self, from: data) {
            self.game = record
        } else {
            self.game = Self.newGame(now: clock())
            if let data = try? JSONEncoder().encode(self.game) {
                try? data.write(to: url, options: [.atomic])
            }
        }
        if defaults.double(forKey: lastProductionKey) == 0 {
            defaults.set(clock(), forKey: lastProductionKey)
        }
        if defaults.double(forKey: lastIncomingKey) == 0 {
            defaults.set(clock(), forKey: lastIncomingKey)
        }
        catchUp()
    }

    /// Test/seed hook: mutates the record directly and saves.
    func inject(_ mutate: (inout SaveRecord) -> Void) {
        mutate(&game)
        save()
    }

    // MARK: - New game

    /// The exact new-game record from the master spec.
    static func newGame(now: Double) -> SaveRecord {
        // All 2500 tiles; plain is every tile not assigned below.
        var tiles: [MapTile] = []
        for y in 0..<50 {
            for x in 0..<50 {
                tiles.append(MapTile(type: .plain, x: x, y: y, remaining: nil))
            }
        }
        func assign(_ type: TileType, _ x: Int, _ y: Int, remaining: Int? = nil) {
            if let i = tiles.firstIndex(where: { $0.x == x && $0.y == y }) {
                tiles[i] = MapTile(type: type, x: x, y: y, remaining: remaining)
            }
        }
        let nodes: [(TileType, [(Int, Int)])] = [
            (.food, [(10, 10), (14, 30), (40, 12)]),
            (.wood, [(8, 20), (33, 8), (42, 40)]),
            (.stone, [(18, 42), (36, 22), (6, 36)]),
            (.iron, [(44, 18), (22, 14), (12, 44)]),
            (.gold, [(30, 40), (16, 16)]),
        ]
        for (type, spots) in nodes {
            for (x, y) in spots {
                assign(type, x, y, remaining: 5000)
            }
        }
        for (x, y) in [(20, 20), (28, 32), (38, 14), (11, 27)] {
            assign(.monster, x, y)
        }
        assign(.castle, 25, 25)
        let holdSpots = [(10, 25), (40, 25), (25, 10), (25, 40), (12, 12), (38, 12), (12, 38), (38, 38)]
        for spot in holdSpots {
            assign(.hold, spot.0, spot.1)
        }

        let buildings = buildingOrder.map { Building(name: $0, level: 1) }
        let holds = holdSpots.enumerated().map { i, spot in
            Hold(name: "Hold \(i + 1)", x: spot.0, y: spot.1, power: 800,
                 food: 2000, wood: 2000, shieldUntil: 0, owner: nil)
        }
        let heroes = [
            Hero(name: "Bram", title: "the Stone", level: 1, assignedMarchId: nil),
            Hero(name: "Lira", title: "the Reed", level: 1, assignedMarchId: nil),
            Hero(name: "Holt", title: "the Ash", level: 1, assignedMarchId: nil),
        ]

        return SaveRecord(
            playerName: "Lord",
            keepLevel: 1,
            x: 25,
            y: 25,
            resources: Resources(food: 1000, wood: 1000, stone: 1000, iron: 500, gold: 100),
            storageCap: 5000,
            buildings: buildings,
            troops: TroopCounts(footman: 20, archer: 10, rider: 0, ram: 0),
            wounded: .zero,
            training: [],
            upgrade: nil,
            marches: [],
            research: .allFalse,
            heroes: heroes,
            shieldUntil: 0,
            holds: holds,
            mapTiles: tiles,
            alliance: nil,
            log: [],
            victory: false,
            victoryWinner: nil
        )
    }

    // MARK: - Save / load

    /// Writes the save file. Called after every change.
    func save() {
        if let data = try? JSONEncoder().encode(game) {
            try? data.write(to: saveURL, options: [.atomic])
        }
    }

    // MARK: - Derived values

    func building(_ name: String) -> Building? {
        game.buildings.first { $0.name == name }
    }

    func level(_ name: String) -> Int {
        building(name)?.level ?? 0
    }

    var keepLevel: Int { game.keepLevel }

    var beds: Int { level("Hospital") * 100 + (game.research.hospital ? 100 : 0) }

    var woundedTotal: Int { game.wounded.total }

    var tile: MapTile? { game.mapTiles.first { $0.x == game.x && $0.y == game.y } }

    func tile(_ x: Int, _ y: Int) -> MapTile? {
        game.mapTiles.first { $0.x == x && $0.y == y }
    }

    func hold(at x: Int, y: Int) -> Hold? {
        game.holds.first { $0.x == x && $0.y == y }
    }

    func hero(_ name: String) -> Hero? {
        game.heroes.first { $0.name == name }
    }

    var isShielded: Bool { game.shieldUntil > now() }

    var isBusy: Bool { game.upgrade != nil }

    /// Production per minute for a resource name, from its building level.
    func productionPerMinute(_ resource: String) -> Int {
        switch resource {
        case "food": return level("Farm") * 20
        case "wood": return level("Timber yard") * 20
        case "stone": return level("Quarry") * 20
        case "iron": return level("Mine") * 20
        case "gold": return level("Vault") * 5
        default: return 0
        }
    }

    /// Combat power: footman 10, archer 12, rider 15, ram 20, +50 per hero level.
    static func power(_ troops: TroopCounts, heroLevel: Int) -> Int {
        troops.footman * 10 + troops.archer * 12 + troops.rider * 15 + troops.ram * 20
            + heroLevel * 50
    }

    func power(_ troops: TroopCounts, heroName: String?) -> Int {
        let heroLevel = heroName.flatMap { hero($0)?.level } ?? 0
        return Self.power(troops, heroLevel: heroLevel)
    }

    /// Travel time in ms: 2000 × manhattan distance, minimum 4 s, ×0.8 with Route maps.
    func travelTime(distance: Int) -> Double {
        var ms = max(4000, Double(distance) * 2000)
        if game.research.march { ms *= 0.8 }
        return ms
    }

    /// Upgrade cost at current level L, paid up front.
    func upgradeCost(_ level: Int) -> Resources {
        Resources(food: level * 200, wood: level * 200, stone: level * 150, iron: level * 100, gold: 0)
    }

    func mmss(_ ms: Double) -> String {
        let total = max(0, Int(ceil(ms / 1000)))
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    private static let commaFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.usesGroupingSeparator = true
        f.groupingSeparator = ","
        f.groupingSize = 3
        return f
    }()

    func comma(_ n: Int) -> String {
        Self.commaFormatter.string(from: NSNumber(value: n)) ?? String(n)
    }

    // MARK: - Log

    /// Prepends a time-stamped line, keeping at most 30.
    func addLog(_ text: String) {
        let time = Self.timeString(Date())
        game.log.insert("\(time) \(text)", at: 0)
        if game.log.count > 30 {
            game.log = Array(game.log.prefix(30))
        }
    }

    static func timeString(_ date: Date) -> String {
        let f = DateFormatter()
        f.timeStyle = .medium
        f.dateStyle = .none
        return f.string(from: date)
    }

    // MARK: - The tick (1 s while open; full catch-up on launch)

    func tick() {
        let t = now()
        var changed = false
        changed = runProduction(t) || changed
        changed = resolveTraining(t) || changed
        changed = resolveUpgrade(t) || changed
        changed = resolveMarches(t) || changed
        changed = runIncomingCheck(t) || changed
        if changed { save() }
    }

    /// Full catch-up on launch: production (max 4 h), queues, marches, incoming.
    private func catchUp() {
        tick()
    }

    /// Adds per-minute production for elapsed minutes, capped at 4 h and storageCap.
    private func runProduction(_ t: Double) -> Bool {
        let last = defaults.double(forKey: lastProductionKey)
        guard t >= last + 60_000 else { return false }
        var minutes = Int((t - last) / 60_000)
        if minutes > 240 { minutes = 240 }
        for resource in ["food", "wood", "stone", "iron", "gold"] {
            let gain = productionPerMinute(resource) * minutes
            guard gain > 0 else { continue }
            let room = game.storageCap - game.resources.value(resource)
            if room > 0 { game.resources.add(resource, min(gain, room)) }
        }
        defaults.set(minutes < 240 ? last + Double(minutes) * 60_000 : t, forKey: lastProductionKey)
        return minutes > 0
    }

    /// Completes finished training and healing records.
    private func resolveTraining(_ t: Double) -> Bool {
        var changed = false
        while let first = game.training.min(by: { $0.finishAt < $1.finishAt }), t >= first.finishAt {
            game.training.removeAll { $0 == first }
            switch first.kind {
            case .train:
                game.troops.add(first.type, first.count)
            case .heal:
                let moved = min(first.count, game.wounded.value(first.type))
                game.wounded.subtract(first.type, moved)
                game.troops.add(first.type, moved)
            }
            changed = true
        }
        return changed
    }

    /// Completes the running upgrade.
    private func resolveUpgrade(_ t: Double) -> Bool {
        guard let up = game.upgrade, t >= up.finishAt else { return false }
        if let i = game.buildings.firstIndex(where: { $0.name == up.buildingName }) {
            game.buildings[i].level += 1
        }
        addLog("Upgraded \(up.buildingName)")
        game.upgrade = nil
        if up.buildingName == "Keep" {
            game.keepLevel = level("Keep")
        }
        if up.buildingName == "Vault" {
            game.storageCap = max(5000, level("Vault") * 1000)
        }
        return true
    }

    /// Moves marches through going → working → returning, then removes them.
    private func resolveMarches(_ t: Double) -> Bool {
        var changed = false
        var i = 0
        while i < game.marches.count {
            let m = game.marches[i]
            let travel = m.arrivesAt - m.startAt
            switch m.state {
            case "going":
                if t >= m.arrivesAt {
                    switch m.job {
                    case .gather:
                        game.marches[i].state = "working"
                    case .scout:
                        if let h = hold(at: m.toX, y: m.toY) {
                            addLog("Scout \(h.name) power \(h.power)")
                        }
                        game.marches[i].state = "returning"
                    case .attack, .attackHold:
                        game.marches[i] = resolveCombat(game.marches[i], t: t)
                        game.marches[i].state = "returning"
                    }
                    changed = true
                }
            case "working":
                if t >= m.arrivesAt + 60_000 {
                    applyGather(game.marches[i])
                    game.marches[i].state = "returning"
                    changed = true
                }
            case "returning":
                let backAt = m.arrivesAt + (m.job == .gather ? 60_000 : 0) + travel
                if t >= backAt {
                    game.troops.add(m.troops)
                    if let hn = m.heroName,
                       let hi = game.heroes.firstIndex(where: { $0.name == hn }) {
                        game.heroes[hi].assignedMarchId = nil
                    }
                    game.marches.remove(at: i)
                    changed = true
                    continue
                }
            default:
                break
            }
            i += 1
        }
        return changed
    }

    /// Gather yield on work completion: 200 (240 with Gather lore) per troop,
    /// capped at 2000 (2400 with lore) and at the tile's remaining amount.
    private func applyGather(_ m: March) {
        guard let tile = tile(m.toX, m.toY), let resource = tile.type.resourceName,
              let remaining = tile.remaining, remaining > 0 else { return }
        let perHead = game.research.gather ? 240 : 200
        let cap = game.research.gather ? 2400 : 2000
        let amount = min(m.troops.total * perHead, cap, remaining)
        guard amount > 0 else { return }
        if let i = game.mapTiles.firstIndex(where: { $0.x == m.toX && $0.y == m.toY }) {
            game.mapTiles[i].remaining = remaining - amount
        }
        let room = game.storageCap - game.resources.value(resource)
        game.resources.add(resource, min(amount, max(0, room)))
    }

    /// Combat on arrival: strict-greater wins. Wounds 5% of the sent stack
    /// (rounded up), moved to wounded while beds remain; the rest is deleted.
    /// Returns the march with the wounded removed from the returning stack.
    private func resolveCombat(_ m: March, t: Double) -> March {
        let my = power(m.troops, heroName: m.heroName)
        var holdRef: Hold?
        let target: Int
        if m.job == .attackHold {
            holdRef = hold(at: m.toX, y: m.toY)
            target = holdRef?.power ?? 0
        } else {
            target = 500
        }
        let win = my > target
        if win, m.job == .attack {
            game.resources.gold = min(game.resources.gold + 100, game.storageCap)
        }
        if win, m.job == .attackHold, let h = holdRef,
           let hi = game.holds.firstIndex(where: { $0.id == h.id }) {
            let food = Int(floor(Double(game.holds[hi].food) * 0.1))
            let wood = Int(floor(Double(game.holds[hi].wood) * 0.1))
            game.resources.food = min(game.resources.food + food, game.storageCap)
            game.resources.wood = min(game.resources.wood + wood, game.storageCap)
            game.holds[hi].food -= food
            game.holds[hi].wood -= wood
            game.holds[hi].shieldUntil = t + 300_000
            let newOwner = game.alliance != nil ? game.alliance!.code : game.playerName
            game.holds[hi].owner = newOwner
            addLog("\(game.holds[hi].name) taken by \(newOwner).")
            let owned = game.holds.filter { $0.owner == newOwner }.count
            if owned >= 5 {
                game.victory = true
                game.victoryWinner = newOwner
                addLog("Victory — \(newOwner) controls 5 holds.")
            }
        }
        let woundedOut = applyWounds(m.troops)
        var out = m
        out.troops.subtract(woundedOut)
        return out
    }

    /// Wounds 5% of each troop type (rounded up) while beds remain; extras die.
    /// Returns the counts that actually reached the beds.
    @discardableResult
    private func applyWounds(_ troops: TroopCounts) -> TroopCounts {
        var room = beds - woundedTotal
        var died = 0
        var movedTotal = TroopCounts.zero
        for type in Self.troopTypes {
            let n = troops.value(type)
            guard n > 0 else { continue }
            let hurt = Int(ceil(Double(n) * 0.05))
            let moved = min(hurt, max(0, room))
            game.wounded.add(type, moved)
            movedTotal.add(type, moved)
            room -= moved
            died += hurt - moved
        }
        if died > 0 { addLog("\(died) died, hospital full.") }
        return movedTotal
    }

    /// Every 180 s, if unshielded, Hold 1 attacks with power 800.
    private func runIncomingCheck(_ t: Double) -> Bool {
        let last = defaults.double(forKey: lastIncomingKey)
        guard t - last >= 180_000 else { return false }
        defaults.set(t, forKey: lastIncomingKey)
        guard game.shieldUntil <= t else { return true }
        let defense = Self.power(game.troops, heroLevel: 0) + level("Wall") * 50
        if 800 > defense {
            // Wound 5% of the idle troops: they move out of idle into beds.
            var hurt = TroopCounts.zero
            for type in Self.troopTypes {
                let n = game.troops.value(type)
                if n > 0 { hurt.add(type, Int(ceil(Double(n) * 0.05))) }
            }
            for type in Self.troopTypes {
                let n = hurt.value(type)
                if n > 0 { game.troops.subtract(type, n) }
            }
            applyWoundsFromIdle(hurt)
            addLog("Hold 1 hit the Keep")
        } else {
            addLog("Held the wall")
        }
        return true
    }

    /// Wounded during an incoming attack come out of idle; no beds → deleted.
    private func applyWoundsFromIdle(_ troops: TroopCounts) {
        var room = beds - woundedTotal
        var died = 0
        for type in Self.troopTypes {
            let n = troops.value(type)
            guard n > 0 else { continue }
            let moved = min(n, max(0, room))
            game.wounded.add(type, moved)
            room -= moved
            died += n - moved
        }
        if died > 0 { addLog("\(died) died, hospital full.") }
    }

    // MARK: - Upgrade

    /// Tries to start an upgrade. Returns the red error line, or nil on success.
    @discardableResult
    func upgrade(_ name: String) -> String? {
        guard !game.victory else { return "Game over." }
        let t = now()
        guard game.upgrade == nil else { return "Busy" }
        guard let b = building(name) else { return nil }
        if name == "Keep" {
            if b.level >= 5 { return "Raise the Keep first." }
        } else if b.level >= game.keepLevel {
            return "Raise the Keep first."
        }
        let cost = upgradeCost(b.level)
        for resource in ["food", "wood", "stone", "iron"] {
            if game.resources.value(resource) < cost.value(resource) {
                return "Need \(comma(cost.value(resource) - game.resources.value(resource))) more \(resource)."
            }
        }
        game.resources.food -= cost.food
        game.resources.wood -= cost.wood
        game.resources.stone -= cost.stone
        game.resources.iron -= cost.iron
        game.upgrade = UpgradeState(buildingName: name, finishAt: t + Double(b.level) * 30_000)
        save()
        return nil
    }

    // MARK: - Purchased boosts

    /// Credits a purchased supply bundle, every pile capped at storage.
    func grantBundle(food: Int, wood: Int, stone: Int, iron: Int) {
        for (resource, amount) in [("food", food), ("wood", wood),
                                   ("stone", stone), ("iron", iron)] {
            let room = game.storageCap - game.resources.value(resource)
            guard room > 0 else { continue }
            game.resources.add(resource, min(amount, room))
        }
        addLog("Supplies delivered to the storehouse.")
        save()
    }

    /// Cuts one hour off the running upgrade. Returns a red error line or nil.
    @discardableResult
    func useSpeedUp() -> String? {
        guard !game.victory else { return "Game over." }
        guard var up = game.upgrade else { return "No upgrade running." }
        up.finishAt = max(now(), up.finishAt - 3_600_000)
        game.upgrade = up
        addLog("Upgrade sped up by an hour.")
        save()
        return nil
    }

    /// Finishes the running upgrade immediately (paid power-up).
    @discardableResult
    func finishUpgradeNow() -> String? {
        guard !game.victory else { return "Game over." }
        guard let up = game.upgrade else { return "No upgrade running." }
        if let i = game.buildings.firstIndex(where: { $0.name == up.buildingName }) {
            game.buildings[i].level += 1
        }
        addLog("Upgraded \(up.buildingName)")
        game.upgrade = nil
        if up.buildingName == "Keep" {
            game.keepLevel = level("Keep")
        }
        if up.buildingName == "Vault" {
            game.storageCap = max(5000, level("Vault") * 1000)
        }
        save()
        return nil
    }

    // MARK: - Training & healing

    /// Max count the player can afford of a troop type right now.
    func affordMax(_ type: String) -> Int {
        let spec = Self.troopSpecs[type] ?? (0, 0, 0, 0, 5, "")
        var m = Int.max
        for (resource, cost) in [("food", spec.food), ("wood", spec.wood),
                                 ("stone", spec.stone), ("iron", spec.iron)] where cost > 0 {
            m = min(m, game.resources.value(resource) / cost)
        }
        return m == Int.max ? 0 : m
    }

    func healCost(_ type: String, count: Int) -> Resources {
        let spec = Self.troopSpecs[type] ?? (0, 0, 0, 0, 5, "")
        return Resources(food: spec.food / 2 * count, wood: spec.wood / 2 * count,
                         stone: spec.stone / 2 * count, iron: spec.iron / 2 * count, gold: 0)
    }

    func healShortLine(_ type: String, count: Int) -> String? {
        let cost = healCost(type, count: count)
        for resource in ["food", "wood", "stone", "iron"] {
            if game.resources.value(resource) < cost.value(resource) {
                return "Need \(comma(cost.value(resource) - game.resources.value(resource))) more \(resource)."
            }
        }
        return nil
    }

    /// Trains `count` of a type into the single queue. Returns a red error line or nil.
    @discardableResult
    func train(_ type: String, count: Int) -> String? {
        guard !game.victory else { return "Game over." }
        guard count > 0 else { return nil }
        guard let spec = Self.troopSpecs[type] else { return nil }
        guard level(spec.building) >= 1 else { return nil }
        guard game.training.isEmpty else { return "Busy" }
        guard count <= affordMax(type) else { return nil }
        game.resources.food -= spec.food * count
        game.resources.wood -= spec.wood * count
        game.resources.stone -= spec.stone * count
        game.resources.iron -= spec.iron * count
        let perHead = game.research.train ? spec.seconds * 0.8 : spec.seconds
        game.training.append(TrainingRecord(type: type, count: count,
                                            finishAt: now() + perHead * 1_000 * Double(count),
                                            kind: .train))
        save()
        return nil
    }

    /// Heals `count` wounded of a type (half cost, 3 s each, shared queue).
    @discardableResult
    func heal(_ type: String, count: Int) -> String? {
        guard !game.victory else { return "Game over." }
        guard count > 0 else { return nil }
        guard game.wounded.value(type) >= count else { return nil }
        guard game.training.isEmpty else { return "Busy" }
        if let line = healShortLine(type, count: count) { return line }
        let cost = healCost(type, count: count)
        game.resources.food -= cost.food
        game.resources.wood -= cost.wood
        game.resources.stone -= cost.stone
        game.resources.iron -= cost.iron
        game.training.append(TrainingRecord(type: type, count: count,
                                            finishAt: now() + 3_000 * Double(count),
                                            kind: .heal))
        save()
        return nil
    }

    // MARK: - Research

    @discardableResult
    func study(_ field: ResearchField) -> String? {
        guard !game.victory else { return "Game over." }
        guard level("Academy") >= 1 else { return nil }
        let already: Bool
        switch field {
        case .gather: already = game.research.gather
        case .train: already = game.research.train
        case .march: already = game.research.march
        case .hospital: already = game.research.hospital
        }
        guard !already else { return nil }
        for resource in ["food", "wood", "stone", "iron", "gold"] {
            if game.resources.value(resource) < 500 {
                return "Need \(comma(500 - game.resources.value(resource))) more \(resource)."
            }
        }
        for resource in ["food", "wood", "stone", "iron", "gold"] {
            game.resources.subtract(resource, 500)
        }
        switch field {
        case .gather: game.research.gather = true
        case .train: game.research.train = true
        case .march: game.research.march = true
        case .hospital: game.research.hospital = true
        }
        save()
        return nil
    }

    // MARK: - Heroes

    func heroUpCost(_ h: Hero) -> Int { 100 * h.level }

    @discardableResult
    func levelUp(hero name: String) -> String? {
        guard !game.victory else { return "Game over." }
        guard let i = game.heroes.firstIndex(where: { $0.name == name }) else { return nil }
        guard game.heroes[i].level < 5 else { return "Max" }
        guard game.heroes[i].assignedMarchId == nil else { return nil }
        let cost = heroUpCost(game.heroes[i])
        guard game.resources.gold >= cost else {
            return "Need \(comma(cost - game.resources.gold)) more gold."
        }
        game.resources.gold -= cost
        game.heroes[i].level += 1
        save()
        return nil
    }

    // MARK: - Marches

    /// Sends a march. Returns a red error line, or nil on success.
    @discardableResult
    func sendMarch(toX: Int, toY: Int, job: MarchJob,
                   troops: TroopCounts, heroName: String?) -> String? {
        guard !game.victory else { return "Game over." }
        let t = now()
        guard game.marches.count < 3 else { return "Marches allowed: 3" }
        guard troops.footman <= game.troops.footman,
              troops.archer <= game.troops.archer,
              troops.rider <= game.troops.rider,
              troops.ram <= game.troops.ram else { return nil }
        if let hn = heroName, let hi = game.heroes.firstIndex(where: { $0.name == hn }) {
            guard game.heroes[hi].assignedMarchId == nil else { return nil }
        }
        game.troops.subtract(troops)
        let id = UUID().uuidString
        if let hn = heroName, let hi = game.heroes.firstIndex(where: { $0.name == hn }) {
            game.heroes[hi].assignedMarchId = id
        }
        let distance = abs(toX - game.x) + abs(toY - game.y)
        let march = March(id: id, fromX: game.x, fromY: game.y, toX: toX, toY: toY,
                          job: job, troops: troops, heroName: heroName,
                          startAt: t, arrivesAt: t + travelTime(distance: distance),
                          state: "going")
        game.marches.append(march)
        save()
        return nil
    }

    /// Scout: no troops, no hero, logs on arrival and returns.
    @discardableResult
    func scout(x: Int, y: Int) -> String? {
        guard !game.victory else { return "Game over." }
        guard game.marches.count < 3 else { return "Marches allowed: 3" }
        return sendMarch(toX: x, toY: y, job: .scout, troops: .zero, heroName: nil)
    }

    /// When a returning march comes home (for the Troops screen countdown).
    func returnsAt(_ m: March) -> Double {
        let travel = m.arrivesAt - m.startAt
        return m.arrivesAt + (m.job == .gather ? 60_000 : 0) + travel
    }

    // MARK: - Shield

    func raiseShield() {
        guard !game.victory else { return }
        game.shieldUntil = now() + 900_000
        save()
    }

    func dropShield() {
        guard !game.victory else { return }
        game.shieldUntil = 0
        save()
    }

    // MARK: - Alliance

    private func registry() -> [String: AllianceRecord] {
        guard let data = defaults.data(forKey: registryKey),
              let dict = try? JSONDecoder().decode([String: AllianceRecord].self, from: data) else { return [:] }
        return dict
    }

    private func writeRegistry(_ dict: [String: AllianceRecord]) {
        if let data = try? JSONEncoder().encode(dict) {
            defaults.set(data, forKey: registryKey)
        }
    }

    /// Creates an alliance with a 5-letter code. Returns a red error line or nil.
    @discardableResult
    func createAlliance(name: String) -> String? {
        guard !game.victory else { return "Game over." }
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard trimmed.count >= 3, trimmed.count <= 16, trimmed.allSatisfy({ $0.isLetter }) else {
            return "3 to 16 letters"
        }
        guard game.alliance == nil else { return nil }
        let letters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
        let code = String((0..<5).map { _ in letters.randomElement()! })
        let record = AllianceRecord(name: trimmed, code: code, owner: game.playerName,
                                    members: [game.playerName], board: [])
        game.alliance = record
        var reg = registry()
        reg[code] = record
        writeRegistry(reg)
        save()
        return nil
    }

    /// Joins by code. Only codes created on this device work.
    @discardableResult
    func joinAlliance(code: String) -> String? {
        guard !game.victory else { return "Game over." }
        guard game.alliance == nil else { return nil }
        var reg = registry()
        guard var record = reg[code.uppercased()] else { return "No code match." }
        if !record.members.contains(game.playerName) {
            record.members.append(game.playerName)
        }
        game.alliance = record
        reg[code.uppercased()] = record
        writeRegistry(reg)
        save()
        return nil
    }

    func post(_ text: String) {
        guard !game.victory else { return }
        guard var a = game.alliance, !text.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        a.board.append(AlliancePost(at: now(), author: game.playerName,
                                    text: text.trimmingCharacters(in: .whitespaces)))
        if a.board.count > 20 { a.board = Array(a.board.suffix(20)) }
        game.alliance = a
        syncRegistry(a)
        save()
    }

    func removeMember(_ name: String) {
        guard !game.victory else { return }
        guard var a = game.alliance, a.owner == game.playerName, name != a.owner else { return }
        a.members.removeAll { $0 == name }
        game.alliance = a
        syncRegistry(a)
        save()
    }

    func leaveAlliance() {
        guard let a = game.alliance, a.owner != game.playerName else { return }
        game.alliance = nil
        save()
    }

    func disbandAlliance() {
        guard let a = game.alliance, a.owner == game.playerName else { return }
        var reg = registry()
        reg.removeValue(forKey: a.code)
        writeRegistry(reg)
        game.alliance = nil
        save()
    }

    private func syncRegistry(_ a: AllianceRecord) {
        var reg = registry()
        if reg[a.code] != nil {
            reg[a.code] = a
            writeRegistry(reg)
        }
    }

    // MARK: - Player name

    private let nameClaimsKey = "bw.nameClaims"

    /// Every name in use on this device, lowercased: the player's own, every
    /// name the player has ever claimed, and the rival holds' names.
    private func nameClaims() -> Set<String> {
        var claims = Set(defaults.stringArray(forKey: nameClaimsKey) ?? [])
        claims.insert(game.playerName.lowercased())
        claims.formUnion(["hold 1", "hold 2", "hold 3"])
        return claims
    }

    private func writeNameClaims(_ claims: Set<String>) {
        defaults.set(Array(claims), forKey: nameClaimsKey)
    }

    /// True when `raw` can become the player's name: 2–18 characters after
    /// trimming, not already in use.
    func isNameAvailable(_ raw: String) -> Bool {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2, trimmed.count <= 18 else { return false }
        return !nameClaims().contains(trimmed.lowercased())
    }

    /// Claims a new player name. Returns a red error line, or nil on success.
    /// A name stays claimed after being released, so no name is ever reused
    /// by a different player on this device.
    @discardableResult
    func setName(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2, trimmed.count <= 18 else { return "2 to 18 characters." }
        if trimmed == game.playerName { return nil }
        let key = trimmed.lowercased()
        guard key != game.playerName.lowercased() else {
            game.playerName = trimmed
            save()
            return nil
        }
        guard !nameClaims().contains(key) else { return "That name is already in use." }
        var claims = nameClaims()
        claims.remove(game.playerName.lowercased())
        claims.insert(key)
        writeNameClaims(claims)
        game.playerName = trimmed
        save()
        return nil
    }

    private let freeRenameKey = "bw.freeRenameUsed"

    /// The first rename is free; every later one is a $0.99 purchase.
    var hasFreeRename: Bool { !defaults.bool(forKey: freeRenameKey) }

    func markFreeRenameUsed() {
        defaults.set(true, forKey: freeRenameKey)
    }

    /// Alternates for a taken name — the name with digits or letters appended.
    func suggestNames(for raw: String) -> [String] {
        let base = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        var claims = nameClaims()
        let digits = "0123456789"
        let letters = "abcdefghijkmnpqrstuvwxyz"
        var out: [String] = []
        while out.count < 3 {
            let tail: String
            switch out.count {
            case 0: tail = String((0..<2).map { _ in digits.randomElement()! })
            case 1: tail = String((0..<3).map { _ in letters.randomElement()! })
            default: tail = String((0..<4).map { _ in digits.randomElement()! })
            }
            let s = base + tail
            if !claims.contains(s.lowercased()) {
                claims.insert(s.lowercased())
                out.append(s)
            }
        }
        return out
    }
}
