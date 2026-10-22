//
//  AllianceScreen.swift
//  TheShadow
//
//  Blood War — the Alliance tab. Without an alliance: found one (name and
//  a 4-letter code) or join by code. With one: banner, members, the board
//  with a post field, and Leave (Disband for the owner) behind a confirm.
//

import SwiftUI

struct AllianceScreen: View {
    @EnvironmentObject var store: GameStore
    @State private var newName = ""
    @State private var newCode = ""
    @State private var joinCode = ""
    @State private var postText = ""
    @State private var error: String?
    @State private var confirmingLeave = false
    @State private var postedTick = 0
    @FocusState private var postFocused: Bool

    private static let straw = Color(hex: 0xD2B56A)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if let a = store.game.alliance {
                    inAlliance(a)
                } else {
                    createPanel
                    joinPanel
                }
                if let e = error ?? store.syncError { Text(e).redLine() }
                syncStatus
            }
            .padding(12)
            .animation(.spring(response: 0.4, dampingFraction: 0.85), value: store.game.alliance == nil)
        }
        .onChange(of: store.game.alliance == nil) { _, isNil in
            if !isNil { newName = ""; newCode = ""; joinCode = ""; error = nil }
        }
        .scrollDismissesKeyboard(.interactively)
        .bwScreen()
        .sensoryFeedback(.success, trigger: postedTick)
        .confirmationDialog(leaveTitle, isPresented: $confirmingLeave, titleVisibility: .visible) {
            Button(isOwner ? "Disband alliance" : "Leave alliance", role: .destructive) {
                if isOwner { store.disbandAlliance() } else { store.leaveAlliance() }
                error = nil
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(isOwner
                 ? "You founded this alliance. Leaving disbands it and frees its code."
                 : "You can rejoin later with the code.")
        }
    }

    private var isOwner: Bool {
        store.isAllianceOwner
    }

    /// One quiet line: syncing, queued offline, or shared.
    @ViewBuilder private var syncStatus: some View {
        if store.syncBusy {
            HStack(spacing: 6) {
                ProgressView().controlSize(.mini).tint(BW.subtext)
                Text("Syncing…").bodyLine()
            }
        } else if store.pendingSyncCount > 0 {
            Text("Offline — \(store.pendingSyncCount) action\(store.pendingSyncCount == 1 ? "" : "s") queued")
                .bodyLine()
        } else if store.userId != nil, store.game.alliance?.serverId != nil {
            Text(store.isOnline ? "Shared with your allies" : "Reconnecting…").bodyLine()
        }
    }

    private func isMe(_ index: Int, in a: AllianceRecord) -> Bool {
        if let ids = a.memberIds, ids.indices.contains(index), let uid = store.userId {
            return ids[index] == uid
        }
        return a.members[index] == store.game.playerName
    }

    private func isOwnerRow(_ index: Int, in a: AllianceRecord) -> Bool {
        if let ids = a.memberIds, ids.indices.contains(index), let oid = a.ownerId {
            return ids[index] == oid
        }
        return a.members[index] == a.owner
    }

    private var leaveTitle: String {
        "Leave \(store.game.alliance?.name ?? "alliance")?"
    }

    // MARK: No alliance

    private var createPanel: some View {
        Panel {
            Text("Alliance")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(BW.text)
            Text("Found an alliance. Holds you take fly its banner.")
                .bodyLine()
            fieldLabel("Name")
            BWTextField(placeholder: "Iron Wolves", text: $newName)
            Text("3 to 16 letters").bodyLine()
            fieldLabel("Code")
            BWTextField(placeholder: "WOLF", text: $newCode, monospaced: true)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .onChange(of: newCode) { _, value in
                    let cleaned = String(value.uppercased().filter { $0.isASCII && $0.isLetter }.prefix(4))
                    if cleaned != value { newCode = cleaned }
                }
            Text("Exactly 4 letters — allies join with it").bodyLine()
            SlateButton(title: "Create",
                        disabled: store.syncBusy
                            || newName.trimmingCharacters(in: .whitespaces).count < 3 || newCode.count != 4) {
                error = store.createAlliance(name: newName, code: newCode)
            }
        }
    }

    private var joinPanel: some View {
        Panel {
            Text("Join")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(BW.text)
            BWTextField(placeholder: "Code", text: $joinCode, monospaced: true)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
            SlateButton(title: "Join",
                        disabled: store.syncBusy || joinCode.trimmingCharacters(in: .whitespaces).isEmpty) {
                error = store.joinAlliance(code: joinCode.trimmingCharacters(in: .whitespaces))
            }
        }
    }

    // MARK: In an alliance

    @ViewBuilder private func inAlliance(_ a: AllianceRecord) -> some View {
        Panel {
            HStack(alignment: .firstTextBaseline) {
                Text(a.name)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(BW.text)
                Spacer()
                Text(a.code)
                    .font(.system(size: 16, weight: .heavy, design: .monospaced))
                    .foregroundColor(Self.straw)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .overlay(RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .strokeBorder(Self.straw.opacity(0.7), lineWidth: 1))
                    .textSelection(.enabled)
                    .accessibilityLabel("Code \(a.code.map(String.init).joined(separator: " "))")
            }
            HStack {
                Text("Owner").bodyLine()
                Spacer()
                Text(a.owner)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(BW.text)
            }
        }

        Panel {
            HStack {
                Text("Members")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(BW.text)
                Spacer()
                Text("\(a.members.count)")
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundColor(BW.subtext)
            }
            ForEach(Array(a.members.enumerated()), id: \.offset) { index, member in
                let me = isMe(index, in: a)
                let ownerRow = isOwnerRow(index, in: a)
                HStack(spacing: 8) {
                    Text(member)
                        .font(.system(size: 13, weight: me ? .semibold : .regular))
                        .foregroundColor(me ? BW.text : BW.subtext)
                    if ownerRow {
                        Text("OWNER")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(Self.straw)
                    }
                    Spacer()
                    if isOwner, !ownerRow {
                        Button(action: { store.removeMember(at: index) }) {
                            Text("Remove")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(BW.red)
                        }
                        .frame(minWidth: 44, minHeight: 44)
                        .accessibilityLabel("Remove \(member)")
                    }
                }
                .frame(minHeight: 44)
            }
        }

        Panel {
            Text("Board")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(BW.text)
            HStack(spacing: 8) {
                BWTextField(placeholder: "Write to your allies", text: $postText)
                    .focused($postFocused)
                    .submitLabel(.send)
                    .onSubmit(sendPost)
                SlateButtonSmall(title: "Post",
                                 disabled: postText.trimmingCharacters(in: .whitespaces).isEmpty,
                                 action: sendPost)
                    .frame(width: 76)
            }
            if a.board.isEmpty {
                Text("No posts yet.").bodyLine().padding(.top, 4)
            } else {
                TimelineView(.periodic(from: .now, by: 30)) { context in
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(a.board.enumerated().reversed()), id: \.offset) { index, post in
                            BoardRow(post: post,
                                     isMine: post.authorId.flatMap { id in store.userId.map { $0 == id } }
                                        ?? (post.author == store.game.playerName),
                                     nowMs: context.date.timeIntervalSince1970 * 1000)
                            if index != 0 {
                                Rectangle().fill(BW.stroke).frame(height: 1)
                            }
                        }
                    }
                }
            }
        }

        Button { confirmingLeave = true } label: {
            Text(isOwner ? "Leave & disband" : "Leave alliance")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(BW.red)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(BW.panelDark))
                .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(BW.red.opacity(0.6), lineWidth: 1))
        }
        .padding(.top, 4)
    }

    private func sendPost() {
        let text = postText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        store.post(text)
        postText = ""
        postedTick += 1
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(BW.text)
            .padding(.top, 2)
    }
}

// MARK: - Board row

private struct BoardRow: View {
    let post: AlliancePost
    let isMine: Bool
    let nowMs: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(post.author)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(isMine ? Color(hex: 0xD2B56A) : BW.subtext)
                Spacer()
                Text(age)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(BW.subtext)
            }
            Text(post.text)
                .font(.system(size: 13))
                .foregroundColor(BW.text)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
    }

    /// "now", "12m", "3h", "2d", then a date.
    private var age: String {
        let s = max(0, (nowMs - post.at) / 1000)
        switch s {
        case ..<60: return "now"
        case ..<3600: return "\(Int(s / 60))m"
        case ..<86_400: return "\(Int(s / 3600))h"
        case ..<604_800: return "\(Int(s / 86_400))d"
        default:
            return Date(timeIntervalSince1970: post.at / 1000)
                .formatted(.dateTime.month(.abbreviated).day())
        }
    }
}

// MARK: - Text field

/// The screens' slate text field: dark well, 1pt stroke, 6pt corners.
private struct BWTextField: View {
    let placeholder: String
    @Binding var text: String
    var monospaced = false

    var body: some View {
        TextField("", text: $text,
                  prompt: Text(placeholder).foregroundColor(BW.subtext.opacity(0.7)))
            .textFieldStyle(.plain)
            .font(.system(size: 15, weight: monospaced ? .bold : .regular,
                          design: monospaced ? .monospaced : .default))
            .foregroundColor(BW.text)
            .padding(.horizontal, 10)
            .frame(minHeight: 44)
            .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(BW.panelDark))
            .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).strokeBorder(BW.stroke, lineWidth: 1))
            .accessibilityLabel(placeholder)
    }
}
