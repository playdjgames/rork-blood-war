//
//  SupabaseSync.swift
//  TheShadow
//
//  Blood War — online layer. Signs in anonymously with Supabase Auth, keeps
//  the players row, sends alliance and hold actions to the server, polls the
//  shared state every 4 s, and queues actions while offline (persisted in
//  UserDefaults) to replay them on reconnect. GameStore owns one instance
//  once `startOnline()` runs; without it the game stays fully local.
//

import Foundation
import Supabase

// MARK: - Queued actions

nonisolated enum SyncAction: Codable, Sendable, Equatable {
    case create(name: String, code: String)
    case join(code: String)
    case post(text: String)
    case leave
    case kick(userId: String)
    case claim(x: Int, y: Int, power: Int)
}

enum SyncOutcome {
    case done
    case queued
    case failed(String)
}

// MARK: - Snapshots handed to GameStore

nonisolated struct ServerMember: Sendable, Equatable {
    let id: String
    let name: String
}

nonisolated struct ServerPost: Sendable, Equatable {
    let at: Double
    let authorId: String
    let authorName: String
    let text: String
}

nonisolated struct ServerAllianceSnapshot: Sendable, Equatable {
    let id: String
    let name: String
    let code: String
    let ownerId: String
    let members: [ServerMember]
    let posts: [ServerPost]
}

nonisolated struct ServerHold: Codable, Sendable, Equatable {
    let x: Int
    let y: Int
    let power: Int
    let shieldUntil: Date?
    let ownerAllianceId: String?
    let ownerName: String?

    enum CodingKeys: String, CodingKey {
        case x, y, power
        case shieldUntil = "shield_until"
        case ownerAllianceId = "owner_alliance_id"
        case ownerName = "owner_name"
    }
}

// MARK: - Wire rows and params

private nonisolated struct PlayerParams: Encodable, Sendable {
    let p_name: String
}

private nonisolated struct CreateParams: Encodable, Sendable {
    let p_name: String
    let p_code: String
    let p_display_name: String
}

private nonisolated struct JoinParams: Encodable, Sendable {
    let p_code: String
    let p_display_name: String
}

private nonisolated struct KickParams: Encodable, Sendable {
    let p_user: String
}

private nonisolated struct ClaimParams: Encodable, Sendable {
    let p_x: Int
    let p_y: Int
    let p_attack_power: Int
}

private nonisolated struct PostInsert: Encodable, Sendable {
    let alliance_id: String
    let author_user_id: String
    let text: String
}

private nonisolated struct MembershipRow: Decodable, Sendable {
    let alliance_id: String
}

private nonisolated struct AllianceRow: Decodable, Sendable {
    let id: String
    let name: String
    let code: String
    let owner_user_id: String
}

private nonisolated struct PlayerName: Decodable, Sendable {
    let display_name: String
}

private nonisolated struct MemberRow: Decodable, Sendable {
    let user_id: String
    let role: String
    let players: PlayerName?
}

private nonisolated struct PostRow: Decodable, Sendable {
    let author_user_id: String
    let text: String
    let created_at: Date
    let players: PlayerName?
}

// MARK: - Sync

@MainActor
final class SupabaseSync {
    private let client: SupabaseClient
    private weak var store: GameStore?
    private let defaults: UserDefaults
    private let queueKey = "bw.syncQueue"
    private var queue: [SyncAction]
    private var pollTask: Task<Void, Never>?
    private var polling = false
    private var inFlight = 0

    static let pollSeconds: Double = 4

    /// Nil when the build has no Supabase keys — the game stays local.
    static func make(store: GameStore, defaults: UserDefaults = .standard) -> SupabaseSync? {
        let urlString = Config.EXPO_PUBLIC_SUPABASE_URL
        let key = Config.EXPO_PUBLIC_SUPABASE_ANON_KEY
        guard !urlString.isEmpty, !key.isEmpty, let url = URL(string: urlString) else { return nil }
        let client = SupabaseClient(supabaseURL: url, supabaseKey: key)
        return SupabaseSync(client: client, store: store, defaults: defaults)
    }

    private init(client: SupabaseClient, store: GameStore, defaults: UserDefaults) {
        self.client = client
        self.store = store
        self.defaults = defaults
        if let data = defaults.data(forKey: queueKey),
           let saved = try? JSONDecoder().decode([SyncAction].self, from: data) {
            queue = saved
        } else {
            queue = []
        }
        store.pendingSyncCount = queue.count
    }

    var hasQueue: Bool { !queue.isEmpty }

    func start() {
        guard pollTask == nil else { return }
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.poll()
                try? await Task.sleep(for: .seconds(Self.pollSeconds))
            }
        }
    }

    // MARK: Auth

    private var userId: String? { store?.userId }

    /// Restores or creates the anonymous session and the players row.
    @discardableResult
    private func ensureSignedIn() async -> Bool {
        if userId != nil { return true }
        do {
            let session: Session
            if let existing = try? await client.auth.session {
                session = existing
            } else {
                session = try await client.auth.signInAnonymously()
            }
            let id = session.user.id.uuidString.lowercased()
            try await client.rpc("ensure_player", params: PlayerParams(p_name: store?.game.playerName ?? "Lord")).execute()
            store?.userId = id
            store?.isOnline = true
            return true
        } catch {
            print("[sync] sign-in failed: \(error)")
            store?.isOnline = false
            return false
        }
    }

    // MARK: Sending

    /// Sends one action now; queues it when offline or behind queued work.
    func send(_ action: SyncAction) async -> SyncOutcome {
        inFlight += 1
        defer { inFlight -= 1 }
        guard queue.isEmpty, await ensureSignedIn() else {
            enqueue(action)
            return .queued
        }
        do {
            try await perform(action)
            store?.isOnline = true
            await refresh()
            return .done
        } catch let error as PostgrestError {
            print("[sync] \(action) refused: \(error.message)")
            return .failed(Self.friendly(error.message, action: action))
        } catch {
            print("[sync] \(action) offline: \(error)")
            store?.isOnline = false
            enqueue(action)
            return .queued
        }
    }

    private func perform(_ action: SyncAction) async throws {
        let name = store?.game.playerName ?? "Lord"
        switch action {
        case let .create(allianceName, code):
            try await client.rpc("create_alliance",
                                 params: CreateParams(p_name: allianceName, p_code: code, p_display_name: name)).execute()
        case let .join(code):
            try await client.rpc("join_alliance",
                                 params: JoinParams(p_code: code, p_display_name: name)).execute()
        case let .post(text):
            guard let uid = userId else { throw URLError(.userAuthenticationRequired) }
            let membership: [MembershipRow] = try await client.from("alliance_members")
                .select("alliance_id").eq("user_id", value: uid).limit(1).execute().value
            guard let aid = membership.first?.alliance_id else {
                throw PostgrestError(message: "not_in_alliance")
            }
            try await client.from("alliance_posts")
                .insert(PostInsert(alliance_id: aid, author_user_id: uid, text: text)).execute()
        case .leave:
            try await client.rpc("leave_alliance").execute()
        case let .kick(target):
            try await client.rpc("kick_member", params: KickParams(p_user: target)).execute()
        case let .claim(x, y, power):
            try await client.rpc("claim_hold", params: ClaimParams(p_x: x, p_y: y, p_attack_power: power)).execute()
        }
    }

    private func enqueue(_ action: SyncAction) {
        queue.append(action)
        persistQueue()
    }

    private func persistQueue() {
        if let data = try? JSONEncoder().encode(queue) {
            defaults.set(data, forKey: queueKey)
        }
        store?.pendingSyncCount = queue.count
    }

    /// Replays queued actions in order. Stops at the first network failure;
    /// drops actions the server refuses and reports why.
    private func replayQueue() async -> Bool {
        while let action = queue.first {
            do {
                try await perform(action)
            } catch let error as PostgrestError {
                print("[sync] queued \(action) refused: \(error.message)")
                store?.syncError = Self.friendly(error.message, action: action)
            } catch {
                print("[sync] replay paused: \(error)")
                store?.isOnline = false
                return false
            }
            queue.removeFirst()
            persistQueue()
        }
        return true
    }

    // MARK: Polling

    private func poll() async {
        guard !polling, inFlight == 0 else { return }
        polling = true
        defer { polling = false }
        guard await ensureSignedIn() else { return }
        guard await replayQueue() else { return }
        await refresh()
    }

    /// Pulls the shared holds and the player's alliance into GameStore.
    func refresh() async {
        guard let uid = userId else { return }
        do {
            let holds: [ServerHold] = try await client.rpc("list_holds").execute().value
            let snapshot = try await fetchAlliance(uid: uid)
            store?.isOnline = true
            store?.applyServerAlliance(snapshot, queueEmpty: queue.isEmpty)
            store?.applyServerHolds(holds)
        } catch {
            print("[sync] refresh failed: \(error)")
            if !(error is PostgrestError) { store?.isOnline = false }
        }
    }

    private func fetchAlliance(uid: String) async throws -> ServerAllianceSnapshot? {
        let membership: [MembershipRow] = try await client.from("alliance_members")
            .select("alliance_id").eq("user_id", value: uid).limit(1).execute().value
        guard let aid = membership.first?.alliance_id else { return nil }

        async let allianceReq: [AllianceRow] = client.from("alliances")
            .select("id,name,code,owner_user_id").eq("id", value: aid).limit(1).execute().value
        async let membersReq: [MemberRow] = client.from("alliance_members")
            .select("user_id,role,players(display_name)").eq("alliance_id", value: aid)
            .order("joined_at", ascending: true).execute().value
        async let postsReq: [PostRow] = client.from("alliance_posts")
            .select("author_user_id,text,created_at,players(display_name)").eq("alliance_id", value: aid)
            .order("created_at", ascending: false).limit(30).execute().value

        let (alliances, memberRows, postRows) = try await (allianceReq, membersReq, postsReq)
        guard let a = alliances.first else { return nil }

        // Two players may share a display name; tag repeats so lists stay distinct.
        var seen: [String: Int] = [:]
        var nameFor: [String: String] = [:]
        let members: [ServerMember] = memberRows.map { row in
            let base = row.players?.display_name ?? "Lord"
            let n = seen[base, default: 0]
            seen[base] = n + 1
            let name = n == 0 ? base : "\(base) #\(row.user_id.prefix(4).uppercased())"
            nameFor[row.user_id] = name
            return ServerMember(id: row.user_id, name: name)
        }
        let posts: [ServerPost] = postRows.reversed().map { row in
            ServerPost(at: row.created_at.timeIntervalSince1970 * 1000,
                       authorId: row.author_user_id,
                       authorName: nameFor[row.author_user_id] ?? row.players?.display_name ?? "Former ally",
                       text: row.text)
        }
        return ServerAllianceSnapshot(id: a.id, name: a.name, code: a.code, ownerId: a.owner_user_id,
                                      members: members, posts: posts)
    }

    // MARK: Errors

    static func friendly(_ message: String, action: SyncAction) -> String {
        if message.contains("code_taken") {
            if case let .create(_, code) = action { return "Code \(code) is taken." }
            return "Code is taken."
        }
        if message.contains("no_code_match") { return "No code match." }
        if message.contains("already_in_alliance") { return "You are already in an alliance." }
        if message.contains("hold_shielded") { return "That hold is shielded." }
        if message.contains("not_in_alliance") { return "Join an alliance to hold territory." }
        if message.contains("too_weak") { return "Your army was too weak to hold it." }
        if message.contains("already_yours") { return "Your alliance already holds it." }
        if message.contains("not_owner") { return "Only the owner can do that." }
        if message.contains("row-level security") { return "Not allowed for your alliance." }
        return "Server: \(message)"
    }
}
