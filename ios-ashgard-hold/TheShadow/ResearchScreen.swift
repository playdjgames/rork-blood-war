//
//  ResearchScreen.swift
//  TheShadow
//
//  Blood War — the Research tab (four studies) and the Alliance tab
//  (create / join / board).
//

import SwiftUI

// MARK: - Research screen

struct ResearchScreen: View {
    @EnvironmentObject var store: GameStore
    @State private var errors: [ResearchField: String] = [:]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(GameStore.researchRows, id: \.field) { row in
                    ResearchRow(field: row.field, name: row.name,
                                error: errors[row.field]) {
                        errors[row.field] = store.study(row.field)
                    }
                }
            }
            .padding(12)
        }
        .bwScreen()
    }
}

private struct ResearchRow: View {
    @EnvironmentObject var store: GameStore
    let field: ResearchField
    let name: String
    let error: String?
    let onStudy: () -> Void

    private var done: Bool {
        switch field {
        case .gather: return store.game.research.gather
        case .train: return store.game.research.train
        case .march: return store.game.research.march
        case .hospital: return store.game.research.hospital
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(name)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(BW.text)
                    Text("Cost 500 of each resource")
                        .font(.system(size: 11)).foregroundColor(BW.subtext)
                }
                Spacer()
                if done {
                    Text("Done")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(BW.subtext)
                        .frame(width: 92, height: 44)
                } else {
                    SlateButtonSmall(title: "Study",
                                     disabled: store.level("Academy") < 1,
                                     action: onStudy)
                        .frame(width: 92)
                }
            }
            .frame(minHeight: 56)
            if let e = error, !done {
                Text(e).redLine()
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(BW.panel))
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous)
            .strokeBorder(BW.stroke, lineWidth: 1))
    }
}

// MARK: - Alliance screen

struct AllianceScreen: View {
    @EnvironmentObject var store: GameStore
    @State private var newName = ""
    @State private var joinCode = ""
    @State private var postText = ""
    @State private var error: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if let a = store.game.alliance {
                    inAlliance(a)
                } else {
                    Panel {
                        Text("Alliance")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(BW.text)
                        Text("Create")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(BW.text)
                        TextField("Name", text: $newName)
                            .textFieldStyle(.plain)
                            .foregroundColor(BW.text)
                            .padding(8)
                            .background(RoundedRectangle(cornerRadius: 6).fill(BW.panelDark))
                            .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(BW.stroke, lineWidth: 1))
                        Text("3 to 16 letters").bodyLine()
                        SlateButton(title: "Create") {
                            error = store.createAlliance(name: newName)
                            if error == nil { newName = "" }
                        }
                    }
                    Panel {
                        Text("Join")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(BW.text)
                        TextField("Code", text: $joinCode)
                            .textFieldStyle(.plain)
                            .foregroundColor(BW.text)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                            .padding(8)
                            .background(RoundedRectangle(cornerRadius: 6).fill(BW.panelDark))
                            .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(BW.stroke, lineWidth: 1))
                        SlateButton(title: "Join") {
                            error = store.joinAlliance(code: joinCode)
                            if error == nil { joinCode = "" }
                        }
                    }
                    if let e = error { Text(e).redLine() }
                }
            }
            .padding(12)
        }
        .bwScreen()
    }

    @ViewBuilder private func inAlliance(_ a: AllianceRecord) -> some View {
        Panel {
            Text(a.name)
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(BW.text)
            Text("Code \(a.code)")
                .font(.system(size: 14)).foregroundColor(BW.subtext)
        }
        Panel {
            Text("Members")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(BW.text)
            ForEach(a.members, id: \.self) { member in
                HStack {
                    Text(member)
                        .font(.system(size: 13)).foregroundColor(BW.subtext)
                    Spacer()
                    if a.owner == store.game.playerName, member != a.owner {
                        Button(action: { store.removeMember(member) }) {
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
            Text("Post")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(BW.text)
            TextField("Post", text: $postText)
                .textFieldStyle(.plain)
                .foregroundColor(BW.text)
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 6).fill(BW.panelDark))
                .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(BW.stroke, lineWidth: 1))
            SlateButton(title: "Post") {
                store.post(postText)
                postText = ""
            }
            ForEach(Array(a.board.enumerated().reversed()), id: \.offset) { _, post in
                VStack(alignment: .leading, spacing: 2) {
                    Text(post.author)
                        .font(.system(size: 11, weight: .semibold)).foregroundColor(BW.subtext)
                    Text(post.text)
                        .font(.system(size: 13)).foregroundColor(BW.text)
                }
                .padding(.top, 4)
            }
        }
        if a.owner == store.game.playerName {
            SlateButton(title: "Disband") { store.disbandAlliance() }
        } else {
            SlateButton(title: "Leave") { store.leaveAlliance() }
        }
    }
}
