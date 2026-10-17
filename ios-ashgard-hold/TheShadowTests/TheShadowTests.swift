//
//  TheShadowTests.swift
//  TheShadowTests
//
//  Blood War — engine tests against the master spec's acceptance criteria.
//

import Testing
import Foundation
@testable import TheShadow

@MainActor
@Suite("Blood War engine")
struct BloodWarTests {

    /// Mutable test clock; the store reads it through its `now` closure.
    private final class Clock {
        var t: Double
        init(_ t: Double) { self.t = t }
    }

    private func makeStore(_ clock: Clock) -> (store: GameStore, url: URL, defaults: UserDefaults) {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("bw-test-\(UUID().uuidString).json")
        let defaults = UserDefaults(suiteName: "bw-tests-\(UUID().uuidString)")!
        let store = GameStore(saveURL: url, defaults: defaults, startsTimer: false) { clock.t }
        return (store, url, defaults)
    }

    private func zeroBuilding(_ store: GameStore, _ name: String) {
        store.inject { g in
            if let i = g.buildings.firstIndex(where: { $0.name == name }) {
                g.buildings[i].level = 0
            }
        }
    }

    // MARK: 1. New game record

    @Test func newGameMatchesSpec() {
        let (store, _, _) = makeStore(Clock(1_000_000_000_000))
        let g = store.game
        #expect(g.playerName == "Lord")
        #expect(g.keepLevel == 1)
        #expect(g.x == 25 && g.y == 25)
        #expect(g.resources == Resources(food: 1000, wood: 1000, stone: 1000, iron: 500, gold: 100))
        #expect(g.buildings.count == 14)
        #expect(g.buildings.allSatisfy { $0.level == 1 })
        #expect(g.troops == TroopCounts(footman: 20, archer: 10, rider: 0, ram: 0))
        #expect(g.wounded == .zero)
        #expect(g.training.isEmpty)
        #expect(g.upgrade == nil)
        #expect(g.marches.isEmpty)
        #expect(g.research == .allFalse)
        #expect(g.heroes.map(\.name) == ["Bram", "Lira", "Holt"])
        #expect(g.heroes.allSatisfy { $0.level == 1 && $0.assignedMarchId == nil })
        #expect(g.shieldUntil == 0)
        #expect(g.holds.count == 8)
        #expect(g.holds.allSatisfy { $0.power == 800 && $0.food == 2000 && $0.wood == 2000 && $0.shieldUntil == 0 })
        #expect(g.mapTiles.count == 2500)
        #expect(g.alliance == nil)
        #expect(g.log.isEmpty)
    }

    @Test func mapTilePlacement() {
        let (store, _, _) = makeStore(Clock(1_000_000_000_000))
        #expect(store.tile(10, 10)?.type == .food)
        #expect(store.tile(10, 10)?.remaining == 5000)
        #expect(store.tile(14, 30)?.type == .food)
        #expect(store.tile(8, 20)?.type == .wood)
        #expect(store.tile(18, 42)?.type == .stone)
        #expect(store.tile(44, 18)?.type == .iron)
        #expect(store.tile(30, 40)?.type == .gold)
        #expect(store.tile(16, 16)?.type == .gold)
        #expect(store.tile(20, 20)?.type == .monster)
        #expect(store.tile(28, 32)?.type == .monster)
        #expect(store.tile(25, 25)?.type == .castle)
        #expect(store.tile(10, 25)?.type == .hold)
        #expect(store.tile(38, 38)?.type == .hold)
        #expect(store.tile(0, 0)?.type == .plain)
        #expect(store.tile(49, 49)?.type == .plain)
    }

    // MARK: 3. Gather

    @Test func gatherTenFootmen() {
        let clock = Clock(1_000_000_000_000)
        let (store, _, _) = makeStore(clock)
        zeroBuilding(store, "Farm") // keep production out of the assertion
        // A strong wall holds the 180 s incoming check, so no troops are wounded.
        store.inject { g in
            if let i = g.buildings.firstIndex(where: { $0.name == "Wall" }) {
                g.buildings[i].level = 12
            }
        }
        let food0 = store.game.resources.food
        let err = store.sendMarch(toX: 10, toY: 10, job: .gather,
                                  troops: TroopCounts(footman: 10, archer: 0, rider: 0, ram: 0),
                                  heroName: nil)
        #expect(err == nil)
        #expect(store.game.troops.footman == 10)
        #expect(store.game.marches.count == 1)
        let m = store.game.marches[0]
        #expect(m.arrivesAt - m.startAt == 60_000) // distance 30 × 2000 ms
        clock.t += 60_000
        store.tick()
        #expect(store.game.marches[0].state == "working")
        clock.t += 60_000
        store.tick()
        #expect(store.game.resources.food == food0 + 2000)
        #expect(store.tile(10, 10)?.remaining == 3000)
        #expect(store.game.marches[0].state == "returning")
        clock.t += 60_000
        store.tick()
        #expect(store.game.marches.isEmpty)
        #expect(store.game.troops.footman == 20)
    }

    @Test func gatherWithLorePays2400() {
        let clock = Clock(1_000_000_000_000)
        let (store, _, _) = makeStore(clock)
        zeroBuilding(store, "Farm")
        store.inject { g in g.resources.gold = 1000 }
        #expect(store.study(.gather) == nil)
        #expect(store.game.research.gather)
        let food0 = store.game.resources.food
        #expect(store.sendMarch(toX: 10, toY: 10, job: .gather,
                                troops: TroopCounts(footman: 10, archer: 0, rider: 0, ram: 0),
                                heroName: nil) == nil)
        clock.t += 60_000
        store.tick()
        clock.t += 60_000
        store.tick()
        #expect(store.game.resources.food == food0 + 2400)
    }

    @Test func gatherCapsAtTwoThousandWithoutLore() {
        let clock = Clock(1_000_000_000_000)
        let (store, _, _) = makeStore(clock)
        zeroBuilding(store, "Farm")
        store.inject { g in g.troops = TroopCounts(footman: 100, archer: 0, rider: 0, ram: 0) }
        let food0 = store.game.resources.food
        #expect(store.sendMarch(toX: 10, toY: 10, job: .gather,
                                troops: TroopCounts(footman: 100, archer: 0, rider: 0, ram: 0),
                                heroName: nil) == nil)
        clock.t += 60_000
        store.tick()
        clock.t += 60_000
        store.tick()
        #expect(store.game.resources.food == food0 + 2000)
    }

    // MARK: 4/5. Upgrades

    @Test func upgradeFarmRunsAndFinishes() {
        let clock = Clock(1_000_000_000_000)
        let (store, _, _) = makeStore(clock)
        // At Keep 1 every level-1 building is capped; raise the Keep first.
        store.inject { g in
            if let i = g.buildings.firstIndex(where: { $0.name == "Keep" }) {
                g.buildings[i].level = 2
            }
            g.keepLevel = 2
        }
        #expect(store.upgrade("Farm") == nil)
        #expect(store.game.resources.food == 800) // 1000 − 200
        #expect(store.game.resources.stone == 850) // 1000 − 150
        #expect(store.game.upgrade?.buildingName == "Farm")
        clock.t += 30_000
        store.tick()
        #expect(store.level("Farm") == 2)
        #expect(store.productionPerMinute("food") == 40)
        #expect(store.game.upgrade == nil)
        #expect(store.game.log.first?.contains("Upgraded Farm") == true)
    }

    @Test func upgradeCappedSaysRaiseTheKeepFirst() {
        let (store, _, _) = makeStore(Clock(1_000_000_000_000))
        #expect(store.upgrade("Barracks") == "Raise the Keep first.")
        store.inject { g in
            if let i = g.buildings.firstIndex(where: { $0.name == "Keep" }) {
                g.buildings[i].level = 5
            }
            g.keepLevel = 5
        }
        #expect(store.upgrade("Keep") == "Raise the Keep first.")
    }

    @Test func upgradeShortResourceSpendsNothing() {
        let clock = Clock(1_000_000_000_000)
        let (store, _, _) = makeStore(clock)
        store.inject { g in
            if let i = g.buildings.firstIndex(where: { $0.name == "Keep" }) {
                g.buildings[i].level = 2
            }
            g.keepLevel = 2
            g.resources.food = 0
        }
        let before = store.game.resources
        #expect(store.upgrade("Quarry") == "Need 200 more food.")
        #expect(store.game.resources == before)
        #expect(store.game.upgrade == nil)
    }

    @Test func vaultLevelSetsStorageCap() {
        let clock = Clock(1_000_000_000_000)
        let (store, _, _) = makeStore(clock)
        store.inject { g in
            if let i = g.buildings.firstIndex(where: { $0.name == "Vault" }) {
                g.buildings[i].level = 6
            }
            g.keepLevel = 8
            g.resources = Resources(food: 5000, wood: 5000, stone: 5000, iron: 5000, gold: 0)
        }
        #expect(store.upgrade("Vault") == nil)
        clock.t += 180_000 // level 6 × 30 s
        store.tick()
        #expect(store.level("Vault") == 7)
    }

    // MARK: 6. Training

    @Test func trainFourArchers() {
        let clock = Clock(1_000_000_000_000)
        let (store, _, _) = makeStore(clock)
        #expect(store.train("archer", count: 4) == nil)
        #expect(store.game.resources.food == 840) // 1000 − 160
        #expect(store.game.resources.wood == 840) // 1000 − 160
        #expect(store.game.training.count == 1)
        clock.t += 20_000
        store.tick()
        #expect(store.game.troops.archer == 14)
        #expect(store.game.training.isEmpty)
    }

    @Test func oneQueueBlocksTraining() {
        let clock = Clock(1_000_000_000_000)
        let (store, _, _) = makeStore(clock)
        #expect(store.train("footman", count: 1) == nil)
        #expect(store.train("footman", count: 1) == "Busy")
    }

    @Test func drillSpeedsTraining() {
        let clock = Clock(1_000_000_000_000)
        let (store, _, _) = makeStore(clock)
        store.inject { g in
            g.research.train = true
            g.resources = Resources(food: 5000, wood: 5000, stone: 5000, iron: 5000, gold: 500)
        }
        #expect(store.train("footman", count: 1) == nil)
        let record = store.game.training[0]
        #expect(record.finishAt - clock.t == 4000) // 5 s × 0.8
    }

    // MARK: 7/8. Monster combat

    @Test func attackMonsterLose() {
        let clock = Clock(1_000_000_000_000)
        let (store, _, _) = makeStore(clock)
        let err = store.sendMarch(toX: 20, toY: 20, job: .attack,
                                  troops: TroopCounts(footman: 20, archer: 0, rider: 0, ram: 0),
                                  heroName: "Bram")
        #expect(err == nil)
        // Power 200 + 50 = 250 ≤ 500 → lose.
        clock.t += 20_000
        store.tick()
        #expect(store.game.resources.gold == 100)
        #expect(store.game.wounded.footman == 1)
        #expect(store.game.marches[0].state == "returning")
        clock.t += 20_000
        store.tick()
        #expect(store.game.marches.isEmpty)
        #expect(store.game.troops.footman == 19)
        #expect(store.game.heroes[0].assignedMarchId == nil)
    }

    @Test func attackMonsterWin() {
        let clock = Clock(1_000_000_000_000)
        let (store, _, _) = makeStore(clock)
        store.inject { g in g.troops = TroopCounts(footman: 60, archer: 0, rider: 0, ram: 0) }
        #expect(store.sendMarch(toX: 20, toY: 20, job: .attack,
                                troops: TroopCounts(footman: 60, archer: 0, rider: 0, ram: 0),
                                heroName: nil) == nil)
        // Power 600 > 500 → win.
        clock.t += 20_000
        store.tick()
        #expect(store.game.resources.gold == 200)
        #expect(store.game.wounded.footman == 3)
    }

    // MARK: 9. Healing

    @Test func healThreeFootmen() {
        let clock = Clock(1_000_000_000_000)
        let (store, _, _) = makeStore(clock)
        store.inject { g in g.wounded = TroopCounts(footman: 3, archer: 0, rider: 0, ram: 0) }
        #expect(store.heal("footman", count: 3) == nil)
        #expect(store.game.resources.food == 925) // 1000 − 75
        #expect(store.game.resources.wood == 970) // 1000 − 30
        clock.t += 9_000
        store.tick()
        #expect(store.game.wounded.footman == 0)
        #expect(store.game.troops.footman == 23)
    }

    // MARK: Marches

    @Test func marchTravelTimes() {
        let (store, _, _) = makeStore(Clock(1_000_000_000_000))
        #expect(store.travelTime(distance: 5) == 10_000)
        #expect(store.travelTime(distance: 1) == 4_000)
        store.inject { g in g.research.march = true }
        #expect(store.travelTime(distance: 5) == 8_000)
        #expect(store.travelTime(distance: 1) == 3_200)
    }

    @Test func maxThreeMarches() {
        let clock = Clock(1_000_000_000_000)
        let (store, _, _) = makeStore(clock)
        for _ in 0..<3 {
            #expect(store.scout(x: 24, y: 25) == nil)
        }
        #expect(store.scout(x: 24, y: 25) == "Marches allowed: 3")
    }

    // MARK: Hold attacks

    @Test func attackHoldWins() {
        let clock = Clock(1_000_000_000_000)
        let (store, _, _) = makeStore(clock)
        store.inject { g in g.troops = TroopCounts(footman: 100, archer: 0, rider: 0, ram: 0) }
        #expect(store.sendMarch(toX: 10, toY: 25, job: .attackHold,
                                troops: TroopCounts(footman: 100, archer: 0, rider: 0, ram: 0),
                                heroName: nil) == nil)
        clock.t += 30_000 // distance 15 → 30 s
        store.tick()
        let hold = store.hold(at: 10, y: 25)!
        #expect(store.game.resources.food == 1200) // + floor(2000 × 0.1)
        #expect(store.game.resources.wood == 1200)
        #expect(hold.food == 1800 && hold.wood == 1800)
        #expect(hold.shieldUntil == clock.t + 300_000)
        #expect(store.game.wounded.footman == 5) // 5% of 100
    }

    // MARK: 10. Incoming attack & shield

    @Test func shieldBlocksIncoming() {
        let clock = Clock(1_000_000_000_000)
        let (store, _, _) = makeStore(clock)
        store.raiseShield()
        clock.t += 181_000
        store.tick()
        #expect(store.game.log.isEmpty) // nothing logged while shielded
        store.dropShield()
        clock.t += 181_000
        store.tick()
        // Defense 20×10 + 10×12 + wall 50 = 370 < 800 → hit.
        #expect(store.game.log.first?.contains("Hold 1 hit the Keep") == true)
        #expect(store.game.wounded.footman == 1)
        #expect(store.game.troops.footman == 19)
    }

    @Test func heldTheWallWhenDefenseWins() {
        let clock = Clock(1_000_000_000_000)
        let (store, _, _) = makeStore(clock)
        store.inject { g in
            g.troops = TroopCounts(footman: 100, archer: 0, rider: 0, ram: 0)
        }
        clock.t += 181_000
        store.tick()
        // Defense 1000 + 50 ≥ 800 → held.
        #expect(store.game.log.first?.contains("Held the wall") == true)
        #expect(store.game.wounded == .zero)
    }

    // MARK: Research

    @Test func studyNeedsAllFiveResources() {
        let (store, _, _) = makeStore(Clock(1_000_000_000_000))
        #expect(store.study(.train) == "Need 400 more gold.") // only 100 gold
        #expect(store.game.research.train == false)
        store.inject { g in
            g.resources = Resources(food: 5000, wood: 5000, stone: 5000, iron: 5000, gold: 500)
        }
        #expect(store.study(.train) == nil)
        #expect(store.game.research.train == true)
        #expect(store.game.resources.gold == 0)
    }

    // MARK: Heroes

    @Test func heroLevelUp() {
        let clock = Clock(1_000_000_000_000)
        let (store, _, _) = makeStore(clock)
        store.inject { g in g.resources.gold = 600 }
        #expect(store.levelUp(hero: "Bram") == nil)
        #expect(store.hero("Bram")?.level == 2)
        #expect(store.game.resources.gold == 500) // 600 − 100×1
        // A hero on a march cannot level up.
        store.inject { g in g.heroes[0].assignedMarchId = "m1" }
        #expect(store.levelUp(hero: "Bram") == nil)
        #expect(store.hero("Bram")?.level == 2)
    }

    // MARK: 11. Persistence

    @Test func saveSurvivesRelaunch() {
        let clock = Clock(1_000_000_000_000)
        let (store, url, defaults) = makeStore(clock)
        #expect(store.createAlliance(name: "IronWolves") == nil)
        let code = store.game.alliance?.code ?? ""
        #expect(code.count == 5)
        store.post("First message")
        store.inject { g in
            if let i = g.buildings.firstIndex(where: { $0.name == "Farm" }) {
                g.buildings[i].level = 3
            }
            g.resources.food = 4321
        }
        // Relaunch from the same file.
        let reborn = GameStore(saveURL: url, defaults: defaults, startsTimer: false) { clock.t }
        #expect(reborn.game.alliance?.code == code)
        #expect(reborn.game.alliance?.board.first?.text == "First message")
        #expect(reborn.level("Farm") == 3)
        #expect(reborn.game.resources.food == 4321)
        #expect(reborn.game.troops == store.game.troops)
    }

    @Test func joinByDeviceCode() {
        let clock = Clock(1_000_000_000_000)
        let (store, _, _) = makeStore(clock)
        #expect(store.createAlliance(name: "AshLegion") == nil)
        let code = store.game.alliance?.code ?? ""
        store.disbandAlliance()
        #expect(store.game.alliance == nil)
        #expect(store.joinAlliance(code: "ZZZZZ") == "No code match.")
        #expect(store.joinAlliance(code: code) == nil)
        #expect(store.game.alliance?.members.contains("Lord") == true)
    }

    @Test func logKeepsThirtyLines() {
        let (store, _, _) = makeStore(Clock(1_000_000_000_000))
        for i in 0..<40 {
            store.addLog("Line \(i)")
        }
        #expect(store.game.log.count == 30)
        #expect(store.game.log.first?.hasSuffix("Line 39") == true)
    }

    // MARK: Production

    @Test func productionTicksAndCaps() {
        let clock = Clock(1_000_000_000_000)
        let (store, _, _) = makeStore(clock)
        clock.t += 60_000
        store.tick()
        #expect(store.game.resources.food == 1020) // Farm 20/min
        #expect(store.game.resources.iron == 520) // Mine 20/min
        #expect(store.game.resources.gold == 105) // Vault 5/min
    }

    @Test func offlineCatchUpCapsAtFourHours() {
        let clock = Clock(1_000_000_000_000)
        let (store, _, _) = makeStore(clock)
        clock.t += 6 * 3_600_000 // six hours away
        store.tick()
        // Production is clamped to 4 h: 240 minutes of Farm 20 = 4800 + 1000.
        #expect(store.game.resources.food == 5800)
    }
}
