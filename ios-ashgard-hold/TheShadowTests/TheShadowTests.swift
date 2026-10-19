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
        store.inject { g in g.troops = TroopCounts(footman: 100, archer: 0, rider: 0, ram: 0) }
        #expect(store.sendMarch(toX: 20, toY: 20, job: .attack,
                                troops: TroopCounts(footman: 100, archer: 0, rider: 0, ram: 0),
                                heroName: nil) == nil)
        // Power 1000 > monster 400 + 10×40 = 800 → win + loot.
        clock.t += 20_000
        store.tick()
        #expect(store.game.resources.gold >= 120 && store.game.resources.gold <= 180)
        #expect(store.game.resources.food >= 200 && store.game.resources.food <= 1600)
        #expect(store.game.resources.wood >= 200)
        #expect(store.game.resources.iron >= 100)
        #expect(store.tile(20, 20)?.type == .plain) // monster gone
        #expect(store.game.log.first?.contains("Defeated monster at 20,20") == true)
        #expect(store.game.wounded.footman == 5)
    }

    @Test func monsterPowerScalesWithDistance() {
        let (store, _, _) = makeStore(Clock(1_000_000_000_000))
        // Castle at 25,25: distance 0 → 400, distance 10 → 800, farther → stronger.
        #expect(store.monsterPower(x: 25, y: 25) == 400)
        #expect(store.monsterPower(x: 20, y: 20) == 800)
        #expect(store.monsterPower(x: 10, y: 10) > store.monsterPower(x: 22, y: 22))
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

    // MARK: Hero skills

    @Test func startingHeroSkills() {
        let (store, _, _) = makeStore(Clock(1_000_000_000_000))
        #expect(store.game.heroes.map(\.skill) == ["attack", "gather", "march"])
        #expect(store.game.heroes.allSatisfy { $0.skillLevel == 1 })
    }

    @Test func bramAddsFifteenPercentPower() {
        let (store, _, _) = makeStore(Clock(1_000_000_000_000))
        let troops = TroopCounts(footman: 100, archer: 0, rider: 0, ram: 0)
        let base = GameStore.power(troops, heroLevel: 1) // 1000 + 50
        #expect(store.power(troops, heroName: "Bram") == Int(Double(base) * 1.15)) // 1207
        // Lira (gather) adds only her level, no multiplier.
        #expect(store.power(troops, heroName: "Lira") == base)
    }

    @Test func liraAddsTwentyPercentGather() {
        func gathered(hero: String?) -> Int {
            let clock = Clock(1_000_000_000_000)
            let (store, _, _) = makeStore(clock)
            let node = store.game.mapTiles.first { $0.type.resourceName == "wood" && ($0.remaining ?? 0) >= 2000 }!
            let before = store.game.resources.wood
            #expect(store.sendMarch(toX: node.x, toY: node.y, job: .gather,
                                    troops: TroopCounts(footman: 5, archer: 0, rider: 0, ram: 0),
                                    heroName: hero) == nil)
            for _ in 0..<60 { clock.t += 10_000; store.tick() } // there, 60 s work, home
            #expect(store.game.marches.isEmpty)
            return store.game.resources.wood - before
        }
        let plain = gathered(hero: nil)
        let lira = gathered(hero: "Lira")
        #expect(plain > 0)
        #expect(lira == Int(Double(plain) * 1.2))
    }

    @Test func holtCutsTravelTime() {
        let (store, _, _) = makeStore(Clock(1_000_000_000_000))
        #expect(store.travelTime(distance: 10, heroName: "Holt") == 17_000) // 20 000 × 0.85
        #expect(store.travelTime(distance: 10, heroName: "Bram") == 20_000)
    }

    @Test func skillLevelUpCostsGoldAndRaisesBonus() {
        let (store, _, _) = makeStore(Clock(1_000_000_000_000))
        let troops = TroopCounts(footman: 100, archer: 0, rider: 0, ram: 0)
        let before = store.power(troops, heroName: "Bram")
        #expect(store.game.resources.gold == 100)
        #expect(store.levelUpSkill(hero: "Bram") == nil)
        #expect(store.game.resources.gold == 0)
        #expect(store.hero("Bram")?.skillLevel == 2)
        #expect(store.power(troops, heroName: "Bram") == Int(1050 * 1.20)) // +20% now
        #expect(store.power(troops, heroName: "Bram") > before)
        #expect(store.levelUpSkill(hero: "Bram") == "Need 100 more gold.")
        #expect(store.hero("Bram")?.skillLevel == 2)
    }

    @Test func oldHeroSaveDecodesSkillByName() throws {
        let json = #"{"name":"Holt","title":"the Ash","level":2}"#
        let h = try JSONDecoder().decode(Hero.self, from: Data(json.utf8))
        #expect(h.skill == "march" && h.skillLevel == 1)
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
        // Two holds sharing this device's defaults share the code registry.
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("bw-test-\(UUID().uuidString).json")
        let defaults = UserDefaults(suiteName: "bw-tests-\(UUID().uuidString)")!
        let store = GameStore(saveURL: url, defaults: defaults, startsTimer: false) { clock.t }
        let twin = GameStore(saveURL: url.appendingPathExtension("twin"),
                             defaults: defaults, startsTimer: false) { clock.t }
        #expect(store.createAlliance(name: "AshLegion") == nil)
        let code = store.game.alliance?.code ?? ""
        #expect(code.count == 5)
        store.post("First message")
        #expect(twin.joinAlliance(code: "ZZZZZ") == "No code match.")
        #expect(twin.joinAlliance(code: code) == nil)
        #expect(twin.game.alliance?.members.contains("Lord") == true)
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

    @Test func productionPilesOnPlotsUntilCollected() {
        let clock = Clock(1_000_000_000_000)
        let (store, _, _) = makeStore(clock)
        clock.t += 60_000
        store.tick()
        // The plots hold their yield; the storehouse is untouched.
        #expect(store.game.resources.food == 1000)
        #expect(store.game.resources.iron == 500)
        #expect(store.game.buildings.first(where: { $0.name == "Farm" })?.pending == 20)
        #expect(store.game.buildings.first(where: { $0.name == "Mine" })?.pending == 20)
        #expect(store.game.resources.gold == 105) // Vault drips straight in
        // Collecting moves the plot yield into the storehouse.
        #expect(store.collect("Farm") == 20)
        #expect(store.game.resources.food == 1020)
        #expect(store.game.buildings.first(where: { $0.name == "Farm" })?.pending == nil)
        #expect(store.collect("Farm") == 0) // lot is empty
    }

    @Test func offlineCatchUpCapsAtFourHours() {
        let clock = Clock(1_000_000_000_000)
        let (store, _, _) = makeStore(clock)
        clock.t += 6 * 3_600_000 // six hours away
        store.tick()
        // Production is clamped to 4 h: 240 minutes of Farm 20 = 4800, piled
        // on the plot, safe from the raid. The raid (defense < 800) plunders
        // 10% of each storehouse material but never below the Vault floor of
        // 500: food 1000 → −100. The plot cap is low: Farm 1 holds only 100.
        #expect(store.game.buildings.first(where: { $0.name == "Farm" })?.pending == 100)
        #expect(store.game.resources.food == 900)
    }

    // MARK: Outside plots (42 spaces, six types, caps)

    @Test func plotUnlockSchedule() {
        let (store, _, _) = makeStore(Clock(1_000_000_000_000))
        for (keep, open) in [(1, 3), (2, 3), (3, 9), (4, 9), (5, 15), (9, 15),
                             (10, 21), (11, 21), (12, 27), (14, 27), (15, 33), (20, 33)] {
            store.inject { g in g.keepLevel = keep }
            #expect(store.unlockedOpenPlots() == open)
        }
    }

    @Test func buildOnPlotCostsAndTakesThirtySeconds() {
        let clock = Clock(1_000_000_000_000)
        let (store, _, _) = makeStore(clock)
        #expect(store.build("Farm", onPlot: 0) == nil)
        #expect(store.game.resources.food == 800) // 1000 − 200
        #expect(store.game.resources.iron == 400) // 500 − 100
        #expect(store.building("Farm", plot: 0)?.level == 0)
        #expect(store.game.upgrade?.plot == 0)
        clock.t += 30_000
        store.tick()
        #expect(store.level("Farm", plot: 0) == 1)
        #expect(store.count("Farm") == 2) // the starting lot plus this one
        #expect(store.game.log.first?.contains("Built Farm") == true)
    }

    @Test func plotsTakeOnlySixTypes() {
        let (store, _, _) = makeStore(Clock(1_000_000_000_000))
        #expect(store.build("Range", onPlot: 0)?.contains("plots") == true)
        #expect(store.build("Stable", onPlot: 0)?.contains("plots") == true)
        #expect(store.build("Rally yard", onPlot: 0)?.contains("plots") == true)
        #expect(store.game.buildings.count == 14) // nothing was added
    }

    @Test func plotCapsCountTheStartingLot() {
        let clock = Clock(1_000_000_000_000)
        let (store, _, _) = makeStore(clock)
        store.inject { g in
            g.keepLevel = 15
            g.resources = Resources(food: 100_000, wood: 100_000, stone: 100_000,
                                    iron: 100_000, gold: 0)
        }
        // Farm cap 10 includes the starting farm: nine more fit, then no more.
        for plot in 0..<9 {
            #expect(store.build("Farm", onPlot: plot) == nil)
            clock.t += 30_000
            store.tick()
        }
        #expect(store.count("Farm") == 10)
        #expect(store.build("Farm", onPlot: 9) == "Farm limit: 10.")
        // Barracks cap 8 includes its starting lot: seven more fit.
        #expect(store.build("Barracks", onPlot: 9) == nil)
        clock.t += 30_000
        store.tick()
        for plot in 10..<16 {
            #expect(store.build("Barracks", onPlot: plot) == nil)
            clock.t += 30_000
            store.tick()
        }
        #expect(store.count("Barracks") == 8)
        #expect(store.build("Barracks", onPlot: 16) == "Barracks limit: 8.")
    }

    @Test func plotLockedBusyAndTaken() {
        let clock = Clock(1_000_000_000_000)
        let (store, _, _) = makeStore(clock)
        // Keep 1 unlocks 3 open plots: 0, 1 and 2.
        #expect(store.build("Farm", onPlot: 3) == "Raise the Keep to unlock this plot.")
        #expect(store.build("Farm", onPlot: 0) == nil)
        #expect(store.build("Farm", onPlot: 1) == "Busy")
        clock.t += 30_000
        store.tick()
        #expect(store.build("Quarry", onPlot: 0) == "That plot is taken.")
    }

    @Test func plotInstanceProducesAndCollects() {
        let clock = Clock(1_000_000_000_000)
        let (store, _, _) = makeStore(clock)
        #expect(store.build("Farm", onPlot: 0) == nil)
        clock.t += 30_000
        store.tick()
        clock.t += 60_000
        store.tick()
        // Both farms pile 20 on their own lots.
        #expect(store.building("Farm", plot: 0)?.pending == 20)
        #expect(store.building("Farm")?.pending == 20)
        #expect(store.collect("Farm", plot: 0) == 20)
        #expect(store.game.resources.food == 820) // 800 after the build, + 20
        // Collect-all sweeps every lot: the other farm plus timber, stone
        // and iron, 20 each — of which 20 food reaches the storehouse.
        #expect(store.collectAll() == 80)
        #expect(store.game.resources.food == 840)
    }

    @Test func secondHospitalAddsBeds() {
        let clock = Clock(1_000_000_000_000)
        let (store, _, _) = makeStore(clock)
        #expect(store.beds == 100) // the starting Hospital, level 1
        #expect(store.build("Hospital", onPlot: 0) == nil)
        clock.t += 30_000
        store.tick()
        store.inject { g in
            if let i = g.buildings.firstIndex(where: { $0.plot == 0 }) {
                g.buildings[i].level = 2
            }
        }
        #expect(store.beds == 300) // 100 + 200
    }
}
