//
//  GameModels.swift
//  TheShadow
//
//  Blood War — save record and all value types. The JSON file on device is
//  `bloodWarSave.json` and the record fields are exactly the master spec's.
//

import Foundation

// MARK: - Resources

/// The five resource piles. JSON keys are the spec words.
struct Resources: Codable, Equatable {
    var food: Int
    var wood: Int
    var stone: Int
    var iron: Int
    var gold: Int

    static let zero = Resources(food: 0, wood: 0, stone: 0, iron: 0, gold: 0)

    func value(_ name: String) -> Int {
        switch name {
        case "food": return food
        case "wood": return wood
        case "stone": return stone
        case "iron": return iron
        case "gold": return gold
        default: return 0
        }
    }

    mutating func add(_ name: String, _ amount: Int) {
        switch name {
        case "food": food += amount
        case "wood": wood += amount
        case "stone": stone += amount
        case "iron": iron += amount
        case "gold": gold += amount
        default: break
        }
    }

    mutating func subtract(_ name: String, _ amount: Int) {
        add(name, -amount)
    }
}

// MARK: - Troops

/// The four troop piles. JSON keys are footman, archer, rider, ram.
struct TroopCounts: Codable, Equatable {
    var footman: Int
    var archer: Int
    var rider: Int
    var ram: Int

    static let zero = TroopCounts(footman: 0, archer: 0, rider: 0, ram: 0)

    var total: Int { footman + archer + rider + ram }

    func value(_ type: String) -> Int {
        switch type {
        case "footman": return footman
        case "archer": return archer
        case "rider": return rider
        case "ram": return ram
        default: return 0
        }
    }

    mutating func add(_ type: String, _ amount: Int) {
        switch type {
        case "footman": footman += amount
        case "archer": archer += amount
        case "rider": rider += amount
        case "ram": ram += amount
        default: break
        }
    }

    mutating func subtract(_ type: String, _ amount: Int) {
        add(type, -amount)
    }

    mutating func add(_ other: TroopCounts) {
        footman += other.footman
        archer += other.archer
        rider += other.rider
        ram += other.ram
    }

    mutating func subtract(_ other: TroopCounts) {
        footman -= other.footman
        archer -= other.archer
        rider -= other.rider
        ram -= other.ram
    }
}

// MARK: - Buildings

/// One of the 14 buildings. JSON: {name, level} plus `pending` on the four
/// production plots — the yield waiting on the lot until the player collects
/// it. Old saves decode with pending nil.
///
/// `plot` marks an instance built on an outside plot (the index of the open
/// plot it stands on); nil is one of the 14 original singletons. Repeat
/// buildings are only allowed for the six plot types (farm, mill, stone and
/// iron mine, training grounds, medic tent), each with its own cap.
struct Building: Codable, Equatable, Identifiable {
    var name: String
    var level: Int
    var pending: Int?
    var plot: Int?
    var id: String { plot.map { "\(name)#\($0)" } ?? name }
}

// MARK: - Training

enum TrainingKind: String, Codable {
    case train
    case heal
}

/// One training-queue entry. Heals share the single queue (kind marks them).
struct TrainingRecord: Codable, Equatable {
    var type: String
    var count: Int
    var finishAt: Double
    var kind: TrainingKind = .train
}

/// The one running upgrade, stored as {buildingName, finishAt}. `plot` is
/// the outside plot index when the job is a new plot building going up.
struct UpgradeState: Codable, Equatable {
    var buildingName: String
    var finishAt: Double
    var plot: Int?
}

// MARK: - Marches

enum MarchJob: String, Codable {
    case gather
    case attack
    case attackHold = "attackHold"
    case scout
}

/// One march. JSON keys are exactly {id, fromX, fromY, toX, toY, job, troops,
/// heroName, startAt, arrivesAt, state}. state: going | working | returning.
struct March: Codable, Equatable, Identifiable {
    let id: String
    var fromX: Int
    var fromY: Int
    var toX: Int
    var toY: Int
    var job: MarchJob
    var troops: TroopCounts
    var heroName: String?
    var startAt: Double
    var arrivesAt: Double
    var state: String
}

// MARK: - Research

/// The four research fields. JSON keys gather / train / march / hospital.
enum ResearchField: String, Codable, CaseIterable {
    case gather
    case train
    case march
    case hospital
}

/// Four booleans, JSON keys gather / train / march / hospital.
struct ResearchState: Codable, Equatable {
    var gather: Bool
    var train: Bool
    var march: Bool
    var hospital: Bool

    static let allFalse = ResearchState(gather: false, train: false, march: false, hospital: false)
}

// MARK: - Heroes

/// One hero. JSON: {name, title, level, assignedMarchId}.
struct Hero: Codable, Equatable, Identifiable {
    var name: String
    var title: String
    var level: Int
    var assignedMarchId: String?
    var id: String { name }
}

// MARK: - Holds

/// One rival hold. JSON: {name, x, y, power, food, wood, shieldUntil}.
struct Hold: Codable, Equatable, Identifiable {
    var name: String
    var x: Int
    var y: Int
    var power: Int
    var food: Int
    var wood: Int
    var shieldUntil: Double
    var owner: String?
    var id: String { name }
}

// MARK: - Alliance

struct AlliancePost: Codable, Equatable {
    var at: Double
    var author: String
    var text: String
}

/// The alliance record, or null. JSON: {name, code, owner, members, board}.
struct AllianceRecord: Codable, Equatable {
    var name: String
    var code: String
    var owner: String
    var members: [String]
    var board: [AlliancePost]
}

// MARK: - Map

enum TileType: String, Codable, CaseIterable {
    case plain
    case food
    case wood
    case stone
    case iron
    case gold
    case monster
    case castle
    case hold

    /// The white label word under the tile photo.
    var label: String {
        switch self {
        case .plain: return "Plain"
        case .food: return "Food"
        case .wood: return "Wood"
        case .stone: return "Stone"
        case .iron: return "Iron"
        case .gold: return "Gold"
        case .monster: return "Monster"
        case .castle: return "Castle"
        case .hold: return "Hold"
        }
    }

    /// The resource a gather march on this tile brings home.
    var resourceName: String? {
        switch self {
        case .food: return "food"
        case .wood: return "wood"
        case .stone: return "stone"
        case .iron: return "iron"
        case .gold: return "gold"
        default: return nil
        }
    }

    /// True for the five gatherable node types.
    var isNode: Bool { resourceName != nil }
}

/// One map tile. JSON: {type, x, y} plus `remaining` on nodes only.
struct MapTile: Codable, Equatable, Identifiable {
    var type: TileType
    var x: Int
    var y: Int
    var remaining: Int?
    var id: String { "\(x),\(y)" }

    /// The sheet/label title, example "Food 10,10".
    var title: String { "\(type.label) \(x),\(y)" }
}

// MARK: - Save record

/// The whole Blood War save. Fields are exactly the master spec's.
struct SaveRecord: Codable, Equatable {
    var playerName: String
    var keepLevel: Int
    var x: Int
    var y: Int
    var resources: Resources
    var buildings: [Building]
    var troops: TroopCounts
    var wounded: TroopCounts
    var training: [TrainingRecord]
    var upgrade: UpgradeState?
    var marches: [March]
    var research: ResearchState
    var heroes: [Hero]
    var shieldUntil: Double
    var holds: [Hold]
    var mapTiles: [MapTile]
    var alliance: AllianceRecord?
    var log: [String]
    var victory: Bool
    var victoryWinner: String?
}

/// Saves written before victory existed load with victory false.
extension SaveRecord {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        playerName = try c.decode(String.self, forKey: .playerName)
        keepLevel = try c.decode(Int.self, forKey: .keepLevel)
        x = try c.decode(Int.self, forKey: .x)
        y = try c.decode(Int.self, forKey: .y)
        resources = try c.decode(Resources.self, forKey: .resources)
        buildings = try c.decode([Building].self, forKey: .buildings)
        troops = try c.decode(TroopCounts.self, forKey: .troops)
        wounded = try c.decode(TroopCounts.self, forKey: .wounded)
        training = try c.decode([TrainingRecord].self, forKey: .training)
        upgrade = try c.decodeIfPresent(UpgradeState.self, forKey: .upgrade)
        marches = try c.decode([March].self, forKey: .marches)
        research = try c.decode(ResearchState.self, forKey: .research)
        heroes = try c.decode([Hero].self, forKey: .heroes)
        shieldUntil = try c.decode(Double.self, forKey: .shieldUntil)
        holds = try c.decode([Hold].self, forKey: .holds)
        mapTiles = try c.decode([MapTile].self, forKey: .mapTiles)
        alliance = try c.decodeIfPresent(AllianceRecord.self, forKey: .alliance)
        log = try c.decode([String].self, forKey: .log)
        victory = try c.decodeIfPresent(Bool.self, forKey: .victory) ?? false
        victoryWinner = try c.decodeIfPresent(String.self, forKey: .victoryWinner)
    }
}
