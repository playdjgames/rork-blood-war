//
//  Components.swift
//  TheShadow
//
//  Blood War — shared chrome: the dark slate palette, the 48pt slate button,
//  the metal-stamp resource icons, the 36pt resource bar and the 64pt tab bar.
//

import SwiftUI

// MARK: - Palette

enum BW {
    static let background = Color(hex: 0x171B1F)
    static let panel = Color(hex: 0x2E343B)
    static let panelDark = Color(hex: 0x23282E)
    static let stroke = Color(hex: 0x454E57)
    static let highlight = Color(hex: 0x3E4650)
    static let text = Color.white
    static let subtext = Color(hex: 0xC9CFD5)
    static let red = Color(hex: 0xE0473A)
    static let metal = Color(hex: 0xB9C0C7)
}

// MARK: - Slate button

/// The only button in the game: a dark slate rectangle, 48 points tall,
/// white text, no doodles.
struct SlateButton: View {
    let title: String
    var disabled = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(BW.text)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(disabled ? BW.panelDark : BW.panel))
                .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(disabled ? BW.stroke.opacity(0.4) : BW.stroke, lineWidth: 1))
                .opacity(disabled ? 0.5 : 1)
        }
        .disabled(disabled)
        .accessibilityLabel(title)
    }
}

/// A compact 44pt-tall slate button for tight rows.
struct SlateButtonSmall: View {
    let title: String
    var disabled = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(BW.text)
                .frame(minWidth: 84)
                .frame(height: 44)
                .background(RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(disabled ? BW.panelDark : BW.panel))
                .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(disabled ? BW.stroke.opacity(0.4) : BW.stroke, lineWidth: 1))
                .opacity(disabled ? 0.5 : 1)
        }
        .disabled(disabled)
        .accessibilityLabel(title)
    }
}

// MARK: - Metal-stamp resource icons

/// Simple metal-stamp shapes: wheat sheaf, log, stone block, iron bar, coin.
struct StampIcon: View {
    let name: String
    var size: CGFloat = 13

    var body: some View {
        Canvas { ctx, canvas in
            let w = canvas.width, h = canvas.height
            let ink = GraphicsContext.Shading.color(BW.metal)
            switch name {
            case "food":
                // Wheat sheaf: three grain stems fanning up from a band.
                for (dx, tip) in [(0.0, 0.06), (-0.24, 0.2), (0.24, 0.2)] {
                    var stem = Path()
                    stem.move(to: CGPoint(x: w * 0.5, y: h * 0.92))
                    stem.addLine(to: CGPoint(x: w * (0.5 + dx), y: h * tip))
                    ctx.stroke(stem, with: ink, lineWidth: max(1.2, w * 0.09))
                }
                var band = Path()
                band.move(to: CGPoint(x: w * 0.3, y: h * 0.62))
                band.addLine(to: CGPoint(x: w * 0.7, y: h * 0.62))
                ctx.stroke(band, with: ink, lineWidth: max(1.2, w * 0.09))
            case "wood":
                // Log: one round end ring + body.
                var body = Path()
                body.move(to: CGPoint(x: w * 0.3, y: h * 0.3))
                body.addLine(to: CGPoint(x: w * 0.88, y: h * 0.3))
                body.addLine(to: CGPoint(x: w * 0.88, y: h * 0.7))
                body.addLine(to: CGPoint(x: w * 0.3, y: h * 0.7))
                ctx.stroke(body, with: ink, lineWidth: max(1.2, w * 0.09))
                let r = min(w, h) * 0.2
                ctx.stroke(Path(ellipseIn: CGRect(x: w * 0.1, y: h * 0.3, width: r * 2, height: h * 0.4)),
                           with: ink, lineWidth: max(1.2, w * 0.09))
            case "stone":
                // Stone block: a rough rectangle.
                var block = Path()
                block.move(to: CGPoint(x: w * 0.14, y: h * 0.34))
                block.addLine(to: CGPoint(x: w * 0.86, y: h * 0.22))
                block.addLine(to: CGPoint(x: w * 0.9, y: h * 0.74))
                block.addLine(to: CGPoint(x: w * 0.1, y: h * 0.78))
                block.closeSubpath()
                ctx.stroke(block, with: ink, lineWidth: max(1.2, w * 0.09))
            case "iron":
                // Iron bar: an ingot.
                var ingot = Path()
                ingot.move(to: CGPoint(x: w * 0.22, y: h * 0.28))
                ingot.addLine(to: CGPoint(x: w * 0.78, y: h * 0.28))
                ingot.addLine(to: CGPoint(x: w * 0.92, y: h * 0.72))
                ingot.addLine(to: CGPoint(x: w * 0.08, y: h * 0.72))
                ingot.closeSubpath()
                ctx.stroke(ingot, with: ink, lineWidth: max(1.2, w * 0.09))
            case "gold":
                // Coin: a disc with an inner rim.
                let r = min(w, h) * 0.4
                let c = CGPoint(x: w * 0.5, y: h * 0.5)
                ctx.stroke(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)),
                           with: ink, lineWidth: max(1.2, w * 0.09))
                let r2 = r * 0.55
                ctx.stroke(Path(ellipseIn: CGRect(x: c.x - r2, y: c.y - r2, width: r2 * 2, height: r2 * 2)),
                           with: ink, lineWidth: max(1, w * 0.07))
            default:
                break
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

// MARK: - Resource bar

/// Fixed under the status bar, 36 points tall, never scrolls away.
struct ResourceBar: View {
    @EnvironmentObject var store: GameStore

    var body: some View {
        HStack(spacing: 0) {
            cell("food", "Food")
            cell("wood", "Wood")
            cell("stone", "Stone")
            cell("iron", "Iron")
            cell("gold", "Gold")
        }
        .frame(height: 36)
        .background(BW.panelDark)
        .overlay(alignment: .bottom) { Rectangle().fill(BW.stroke).frame(height: 1) }
    }

    private func cell(_ resource: String, _ label: String) -> some View {
        let amount = store.game.resources.value(resource)
        let atCap = amount >= store.game.storageCap
        return HStack(spacing: 3) {
            StampIcon(name: resource, size: 11)
            Text(label)
                .font(.system(size: 8.5, weight: .medium))
                .foregroundColor(BW.subtext)
            Spacer(minLength: 2)
            Text(store.comma(amount))
                .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                .foregroundColor(atCap ? BW.red : BW.text)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(.horizontal, 5)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label) \(store.comma(amount))")
    }
}

// MARK: - Tab bar

enum BWWallTab: String, CaseIterable {
    case castle = "Castle" // the home screen — the castle yard, opens on launch
    case map = "Map"
    case troops = "Troops"
    case heal = "Heal"
    case research = "Research"
    case alliance = "Alliance"
}

/// Bottom tabs, exact order: Map. Castle. Troops. Heal. Research. Alliance.
/// 64 points tall plus the safe area; the active tab has a slate highlight.
struct BWTabBar: View {
    @Binding var tab: BWWallTab

    var body: some View {
        HStack(spacing: 0) {
            ForEach(BWWallTab.allCases, id: \.self) { t in
                Button(action: { tab = t }) {
                    Text(t.rawValue)
                        .font(.system(size: 12, weight: tab == t ? .bold : .medium))
                        .foregroundColor(BW.text)
                        .frame(maxWidth: .infinity)
                        .frame(height: 64)
                        .background(tab == t ? BW.highlight : BW.panelDark)
                }
                .accessibilityLabel(t.rawValue)
                .accessibilityAddTraits(tab == t ? .isSelected : [])
            }
        }
        .overlay(alignment: .top) { Rectangle().fill(BW.stroke).frame(height: 1) }
    }
}

// MARK: - Small helpers

/// A titled screen section on a slate panel.
struct Panel<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) { content }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(BW.panel))
            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(BW.stroke, lineWidth: 1))
    }
}

extension View {
    func bwScreen() -> some View {
        frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(BW.background)
    }
}

extension Color {
    init(hex: UInt) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0,
            opacity: 1
        )
    }
}
