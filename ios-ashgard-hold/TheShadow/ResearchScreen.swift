//
//  ResearchScreen.swift
//  TheShadow
//
//  Blood War — the Research tab (four studies). The Alliance tab lives in
//  AllianceScreen.swift.
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
