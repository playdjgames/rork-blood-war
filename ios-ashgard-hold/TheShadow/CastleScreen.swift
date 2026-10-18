//
//  CastleScreen.swift
//  TheShadow
//
//  Blood War — the HOME screen: the 2.0.8 hold art. The photoreal aerial
//  render of the castle ring and moat is the ground; the freestanding keep
//  and warehouse cutouts stand in the courtyard, the watch tower keeps its
//  lookout on the north-east rise, and every other building sits on its own
//  lot on the great meadow below the moat as a photoreal diorama tile.
//  Drag to pan, pinch to zoom (1×–3×). Tap a building for its upgrade sheet.
//

import SwiftUI

// MARK: - 2.0.8 palette (chrome over the photoreal art)

fileprivate extension Color {
    static let straw = Color(hex: 0xD2B56A)
    static let paper = Color(hex: 0xE8DCC4)
    static let ink = Color(hex: 0x2A241C)
}

// MARK: - Placement on the 1024×1536 hold render

/// One building lot on the hold render, as fractions of its 1024×1536 frame.
fileprivate struct HoldLot: Identifiable {
    let building: String
    let art: String
    let anchor: CGPoint
    var id: String { building }
}

fileprivate enum HoldArt {
    static let imageW: CGFloat = 1024
    static let imageH: CGFloat = 1536

    /// The KEEP hall stands in the open east half of the yard, beside the great castle.
    static let keepAnchor = CGPoint(x: 0.615, y: 0.225)
    /// The courtyard warehouse — the Vault — by the east curtain wall.
    static let vaultAnchor = CGPoint(x: 0.70, y: 0.305)
    /// The watch tower rises from the north-east curtain wall, its footing
    /// melting into the parapet between the painted wall turrets.
    static let towerAnchor = CGPoint(x: 0.815, y: 0.127)

    /// Meadow lots below the moat in staggered village rows — every anchor sits
    /// on open grass: no wall, moat, road, rock or treeline under any building.
    static let lots: [HoldLot] = [
        HoldLot(building: "Farm", art: "medieval_farm_miniature", anchor: CGPoint(x: 0.78, y: 0.675)),
        HoldLot(building: "Timber yard", art: "medieval_lumber_mill", anchor: CGPoint(x: 0.40, y: 0.50)),
        HoldLot(building: "Quarry", art: "medieval_stone_quarry", anchor: CGPoint(x: 0.58, y: 0.50)),
        HoldLot(building: "Mine", art: "medieval_iron_mine_structure", anchor: CGPoint(x: 0.76, y: 0.505)),
        HoldLot(building: "Barracks", art: "medieval_barracks_miniature", anchor: CGPoint(x: 0.19, y: 0.59)),
        HoldLot(building: "Range", art: "archery_range_miniature", anchor: CGPoint(x: 0.36, y: 0.585)),
        HoldLot(building: "Stable", art: "medieval_stable_miniature", anchor: CGPoint(x: 0.53, y: 0.585)),
        // The Workshop stands in the courtyard, on the open yard south-west
        // of the Vault.
        HoldLot(building: "Workshop", art: "siege_workshop_miniature", anchor: CGPoint(x: 0.575, y: 0.315)),
        HoldLot(building: "Hospital", art: "medieval_infirmary_building", anchor: CGPoint(x: 0.27, y: 0.675)),
        HoldLot(building: "Rally yard", art: "medieval_rally_yard", anchor: CGPoint(x: 0.61, y: 0.67)),
    ]

    /// The east land (`aerial_meadow_road`) is drawn at the same scale as the
    /// hold render, starting this fraction of the render's width inside its
    /// right edge and feathering in over it, so the two photos overlap.
    static let eastOverlap: CGFloat = 0.086

    /// The art each plot building stands as — the same photoreal cutouts as
    /// the starting lots. Only the six plot types may ever be built.
    static let plotArt: [String: String] = [
        "Farm": "medieval_farm_miniature",
        "Timber yard": "medieval_lumber_mill",
        "Quarry": "medieval_stone_quarry",
        "Mine": "medieval_iron_mine_structure",
        "Barracks": "medieval_barracks_miniature",
        "Hospital": "medieval_infirmary_building",
    ]

    /// The 33 open build plots — with the 9 standing meadow lots, exactly 42
    /// spaces outside the wall, unlocking with the Keep (12/18/24/30/36/42 of
    /// the 42). Plots unlock in list order: the main meadow fills first, then
    /// the east land as it pans into view. Every anchor is pixel-verified
    /// open grass (scripts/plot_spots.py): no tree, moat, rock or road.
    static let openPlots: [CGPoint] = [
        // Main meadow below the moat.
        CGPoint(x: 0.35, y: 0.755), CGPoint(x: 0.52, y: 0.755), CGPoint(x: 0.69, y: 0.755),
        CGPoint(x: 0.170, y: 0.485), CGPoint(x: 0.685, y: 0.580), CGPoint(x: 0.845, y: 0.575),
        CGPoint(x: 0.435, y: 0.685), CGPoint(x: 0.850, y: 0.750),
        CGPoint(x: 0.590, y: 0.830),
        // East land, revealed by panning.
        CGPoint(x: 1.10, y: 0.56), CGPoint(x: 1.14, y: 0.68),
        CGPoint(x: 1.169, y: 0.185), CGPoint(x: 1.354, y: 0.190),
        CGPoint(x: 1.094, y: 0.275), CGPoint(x: 1.254, y: 0.255),
        CGPoint(x: 1.179, y: 0.345), CGPoint(x: 1.339, y: 0.325), CGPoint(x: 1.489, y: 0.345),
        CGPoint(x: 1.074, y: 0.440), CGPoint(x: 1.249, y: 0.435), CGPoint(x: 1.394, y: 0.470),
        CGPoint(x: 1.239, y: 0.520), CGPoint(x: 1.379, y: 0.555), CGPoint(x: 1.534, y: 0.505),
        CGPoint(x: 1.234, y: 0.605), CGPoint(x: 1.449, y: 0.630), CGPoint(x: 1.579, y: 0.585),
        CGPoint(x: 1.304, y: 0.680), CGPoint(x: 1.494, y: 0.710), CGPoint(x: 1.624, y: 0.665),
        CGPoint(x: 1.214, y: 0.755), CGPoint(x: 1.369, y: 0.760), CGPoint(x: 1.634, y: 0.750),
    ]

    /// 2.0.8 night clock: 0 = full day, 1 = deep night, once per 3 minutes.
    static func nightPhase(_ date: Date) -> CGFloat {
        let t = date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 180) / 180
        return CGFloat(0.5 - 0.5 * cos(t * 2 * .pi))
    }

    /// The Timber yard reads as the Mill, as before.
    static func display(_ name: String) -> String {
        name == "Timber yard" ? "Mill" : name
    }
}

/// Identifiable wrapper so a sheet can address one building — by name for
/// the 14 original lots, by name + plot index for an outside plot instance.
struct HoldBuildingRef: Identifiable {
    let name: String
    var plot: Int? = nil
    var id: String { plot.map { "\(name)#\($0)" } ?? name }
}

/// Identifiable wrapper for an open plot's build sheet.
struct PlotRef: Identifiable {
    let index: Int
    var id: Int { index }
}

// MARK: - Home screen

struct CastleScreen: View {
    @EnvironmentObject var store: GameStore
    @State private var selected: HoldBuildingRef?
    @State private var buildPlot: PlotRef?

    var body: some View {
        HoldWorld(selected: selected,
                  onPick: { selected = $0 },
                  onPlotTap: { buildPlot = PlotRef(index: $0) })
        .bwScreen()
        .sheet(item: $selected) { ref in
            BuildingUpgradeSheet(buildingName: ref.name, plot: ref.plot)
                .presentationDetents([.height(380)])
        }
        .sheet(item: $buildPlot) { ref in
            PlotBuildSheet(plot: ref.index)
                .presentationDetents([.height(520)])
        }
    }
}

// MARK: - The pannable, pinchable hold

private struct HoldWorld: View {
    @EnvironmentObject var store: GameStore
    let selected: HoldBuildingRef?
    let onPick: (HoldBuildingRef) -> Void
    let onPlotTap: (Int) -> Void

    @State private var zoom: CGFloat = 1
    @State private var offset: CGSize?
    @State private var dragStart: CGSize?
    @State private var pinchStart: (zoom: CGFloat, offset: CGSize)?

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            let baseScale = max(size.width / HoldArt.imageW, size.height / HoldArt.imageH)
            let landW = HoldArt.imageW * baseScale * zoom
            let landH = HoldArt.imageH * baseScale * zoom
            // The east land matches the render's scale, so it lines up at
            // every zoom; the overlap scales with it.
            let stripW = landW
            let feather = landW * HoldArt.eastOverlap
            let o = clamp(offset ?? CGSize(width: (size.width - landW) / 2 + 48, height: 0),
                          size: size, landW: landW, landH: landH, stripW: stripW - feather)

            TimelineView(.periodic(from: .now, by: 1)) { context in
            let night = HoldArt.nightPhase(context.date)
            ZStack(alignment: .topLeading) {
                Color(hex: 0x46522F)
                Image("aerial_castle_keep_moat")
                    .resizable()
                    .frame(width: landW, height: landH)
                    .offset(x: o.width, y: o.height)
                    .allowsHitTesting(false)

                // Open land east of the hold — the same aerial camera, sun,
                // pines and grass as the render — feathered into its edge.
                Image("aerial_meadow_road")
                    .resizable()
                    .frame(width: stripW, height: landH)
                    .mask(
                        LinearGradient(stops: [
                            .init(color: .clear, location: 0),
                            .init(color: .white, location: feather / stripW),
                        ], startPoint: .leading, endPoint: .trailing)
                    )
                    .offset(x: o.width + landW - feather, y: o.height)
                    .allowsHitTesting(false)

                ForEach(HoldArt.openPlots.indices, id: \.self) { i in
                    // An open plot is either empty (tap to build one of the
                    // six plot types) or carries its building cutout.
                    if let b = store.game.buildings.first(where: { $0.plot == i }) {
                        let up = store.game.upgrade
                        LotTile(lot: HoldLot(building: b.name,
                                             art: HoldArt.plotArt[b.name] ?? "",
                                             anchor: HoldArt.openPlots[i]),
                                level: b.level,
                                isPicked: selected?.plot == i,
                                upgradeFinishAt: up?.plot == i ? up?.finishAt : nil) {
                            onPick(HoldBuildingRef(name: b.name, plot: i))
                        }
                        .scaleEffect(zoom)
                        .position(x: o.width + HoldArt.openPlots[i].x * landW,
                                  y: o.height + HoldArt.openPlots[i].y * landH)
                    } else {
                        PlotSite(locked: i >= store.unlockedOpenPlots()) { onPlotTap(i) }
                            .scaleEffect(zoom)
                            .position(x: o.width + HoldArt.openPlots[i].x * landW,
                                      y: o.height + HoldArt.openPlots[i].y * landH)
                    }
                }

                // The KEEP is the painted castle itself — only an invisible
                // tappable region is added over its art.
                CastleKeepTap(level: store.level("Keep")) { onPick(HoldBuildingRef(name: "Keep")) }
                    .frame(width: landW * 0.34, height: landH * 0.27)
                    .position(x: o.width + landW * 0.327, y: o.height + landH * 0.15)

                WatchTowerScenery(night: night)
                    .scaleEffect(zoom)
                    .position(x: o.width + HoldArt.towerAnchor.x * landW,
                              y: o.height + HoldArt.towerAnchor.y * landH)

                KeepCutout(level: store.level("Academy"),
                           isPicked: selected?.name == "Academy" && selected?.plot == nil,
                           isUpgrading: store.game.upgrade?.buildingName == "Academy",
                           night: night) { onPick(HoldBuildingRef(name: "Academy")) }
                    .scaleEffect(zoom)
                    .position(x: o.width + HoldArt.keepAnchor.x * landW,
                              y: o.height + HoldArt.keepAnchor.y * landH)

                VaultCutout(level: store.level("Vault"),
                            isPicked: selected?.name == "Vault" && selected?.plot == nil,
                            isUpgrading: store.game.upgrade?.buildingName == "Vault") {
                    onPick(HoldBuildingRef(name: "Vault"))
                }
                    .scaleEffect(zoom)
                    .position(x: o.width + HoldArt.vaultAnchor.x * landW,
                              y: o.height + HoldArt.vaultAnchor.y * landH)

                ForEach(HoldArt.lots) { lot in
                    LotTile(lot: lot,
                            level: store.level(lot.building),
                            isPicked: selected?.name == lot.building && selected?.plot == nil,
                            upgradeFinishAt: store.game.upgrade?.buildingName == lot.building
                                && store.game.upgrade?.plot == nil
                                ? store.game.upgrade?.finishAt : nil) {
                        onPick(HoldBuildingRef(name: lot.building))
                    }
                    .scaleEffect(zoom)
                    .position(x: o.width + lot.anchor.x * landW,
                              y: o.height + lot.anchor.y * landH)
                }

                // Night ambience: the whole land dims gently while night lasts.
                Color(hex: 0x14213D)
                    .opacity(0.22 * night)
                    .animation(.easeInOut(duration: 1.2), value: night)
                    .allowsHitTesting(false)
            }
            .frame(width: size.width, height: size.height, alignment: .topLeading)
            .clipped()
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 10)
                    .onChanged { value in
                        if dragStart == nil { dragStart = o }
                        let start = dragStart ?? o
                        offset = clamp(CGSize(width: start.width + value.translation.width,
                                              height: start.height + value.translation.height),
                                       size: size, landW: landW, landH: landH, stripW: stripW - feather)
                    }
                    .onEnded { _ in dragStart = nil }
            )
            .simultaneousGesture(
                MagnifyGesture()
                    .onChanged { value in
                        if pinchStart == nil { pinchStart = (zoom, o) }
                        guard let start = pinchStart else { return }
                        let newZoom = min(3, max(1, start.zoom * value.magnification))
                        // Keep the screen center fixed on the same spot of the land.
                        let ratio = newZoom / start.zoom
                        let cx = size.width / 2, cy = size.height / 2
                        let newLandW = HoldArt.imageW * baseScale * newZoom
                        let newLandH = HoldArt.imageH * baseScale * newZoom
                        zoom = newZoom
                        offset = clamp(CGSize(width: cx - (cx - start.offset.width) * ratio,
                                              height: cy - (cy - start.offset.height) * ratio),
                                       size: size, landW: newLandW, landH: newLandH,
                                       stripW: stripW - feather)
                    }
                    .onEnded { _ in pinchStart = nil }
            )
            }
        }
    }

    /// The land can never slide far enough to expose bare fill.
    private func clamp(_ o: CGSize, size: CGSize, landW: CGFloat, landH: CGFloat,
                       stripW: CGFloat) -> CGSize {
        CGSize(width: min(0, max(size.width - landW - stripW, o.width)),
               height: min(0, max(size.height - landH, o.height)))
    }
}

// MARK: - Meadow lot: a freestanding building standing on the grass

/// No pad, no frame, no tile: the building's own silhouette stands on the
/// meadow, grounded by a soft contact shadow cast away from the western sun.
private struct LotTile: View {
    let lot: HoldLot
    let level: Int
    let isPicked: Bool
    let upgradeFinishAt: Double?
    let onPick: () -> Void

    private static let side: CGFloat = 62

    var body: some View {
        Button(action: onPick) {
            ZStack {
                Ellipse()
                    .fill(Color.black.opacity(0.32))
                    .frame(width: Self.side * 0.82, height: Self.side * 0.26)
                    .blur(radius: 4)
                    .offset(x: 3, y: Self.side * 0.30)
                if isPicked {
                    Ellipse()
                        .strokeBorder(Color.straw.opacity(0.9), lineWidth: 1.4)
                        .frame(width: Self.side * 0.95, height: Self.side * 0.34)
                        .offset(y: Self.side * 0.30)
                        .transition(.opacity)
                }
                Image(lot.art)
                    .resizable()
                    .scaledToFit()
                    .frame(width: Self.side, height: Self.side)
                    .shadow(color: isPicked ? Color.straw.opacity(0.9) : .clear, radius: 5)
                    .brightness(isPicked ? 0.07 : 0)
                    .saturation(upgradeFinishAt != nil ? 0.6 : 1)
                    .opacity(upgradeFinishAt != nil ? 0.75 : 1)
                if level > 1 {
                    LevelBadge(level: level)
                        .offset(x: -(Self.side / 2 - 6), y: Self.side / 2 - 12)
                }
                if let finish = upgradeFinishAt {
                    HoldCountdown(finishAt: finish)
                }
            }
            .frame(width: Self.side, height: Self.side)
            .contentShape(Ellipse().scale(0.9))
        }
        .buttonStyle(.plain)
        .scaleEffect(isPicked ? 1.05 : 1)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPicked)
        .sensoryFeedback(.selection, trigger: isPicked)
        .accessibilityLabel("\(HoldArt.display(lot.building)), level \(level)")
    }
}

// MARK: - Courtyard cutouts

/// The KEEP — freestanding photoreal cutout on the yard dirt, level on an
/// iron ridge disc, thin day-smoke off the shade-side chimney.
private struct KeepCutout: View {
    let level: Int
    let isPicked: Bool
    let isUpgrading: Bool
    let night: CGFloat
    let onPick: () -> Void

    static let height: CGFloat = 74
    private var side: CGFloat { Self.height }
    private let chimney = CGPoint(x: 0.80, y: 0.02)

    var body: some View {
        Button(action: onPick) {
            ZStack {
                Ellipse()
                    .fill(Color.black.opacity(0.36))
                    .frame(width: Self.height * 0.80, height: Self.height * 0.22)
                    .blur(radius: 4)
                    .offset(x: 3, y: Self.height / 2 - 8)
                if isPicked {
                    Ellipse()
                        .strokeBorder(Color.straw.opacity(0.9), lineWidth: 1.4)
                        .frame(width: Self.height * 0.92, height: Self.height * 0.28)
                        .offset(y: Self.height / 2 - 8)
                }
                Image("medieval_stone_keep")
                    .resizable()
                    .scaledToFit()
                    .frame(height: Self.height)
                    .shadow(color: isPicked ? Color.straw.opacity(0.95) : .clear, radius: 6)
                    .brightness(isPicked ? 0.08 : 0)
                    .opacity(isUpgrading ? 0.7 : 1)
                RidgeDisc(level: level)
                    .offset(x: -Self.height * 0.38, y: Self.height * 0.36)
                KeepSmoke(night: night)
                    .frame(width: 22, height: 32)
                    .offset(x: (chimney.x - 0.5) * side, y: (chimney.y - 0.5) * Self.height)
            }
            .frame(width: side, height: Self.height)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPicked)
        .sensoryFeedback(.selection, trigger: isPicked)
        .accessibilityLabel("Academy, level \(level)")
    }
}

/// The painted castle is the KEEP: no art is added over it, only an
/// invisible tappable region that opens the Keep sheet.
private struct CastleKeepTap: View {
    let level: Int
    let onPick: () -> Void

    var body: some View {
        Button(action: onPick) {
            Color.clear
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Keep, level \(level)")
    }
}

/// The courtyard warehouse cutout — the Vault, holding the hold's stores.
private struct VaultCutout: View {
    let level: Int
    let isPicked: Bool
    let isUpgrading: Bool
    let onPick: () -> Void

    private static let side: CGFloat = 44

    var body: some View {
        Button(action: onPick) {
            ZStack {
                Ellipse()
                    .fill(Color.black.opacity(0.32))
                    .frame(width: Self.side * 0.86, height: Self.side * 0.30)
                    .blur(radius: 4)
                    .offset(y: Self.side * 0.30)
                Image("medieval_warehouse_isometric")
                    .resizable()
                    .scaledToFit()
                    .frame(width: Self.side, height: Self.side)
                    .shadow(color: isPicked ? Color.straw.opacity(0.95) : .clear, radius: 6)
                    .brightness(isPicked ? 0.10 : 0)
                    .opacity(isUpgrading ? 0.7 : 1)
            }
            .frame(width: Self.side, height: Self.side)
            .scaleEffect(isPicked ? 1.06 : 1)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPicked)
        .overlay(alignment: .topTrailing) {
            if level > 1 {
                LevelBadge(level: level)
                    .offset(x: -2, y: 4)
                    .allowsHitTesting(false)
            }
        }
        .sensoryFeedback(.selection, trigger: isPicked)
        .accessibilityLabel("Vault, level \(level)")
    }
}

/// The watch tower built into the north-east wall — the cutout's base fades
/// across the parapet so the painted wall carries it, with no ground shadow.
private struct WatchTowerScenery: View {
    let night: CGFloat
    private static let height: CGFloat = 128

    var body: some View {
        ZStack {
            // Orange beacon halo that fades in with night.
            Circle()
                .fill(
                    RadialGradient(colors: [Color(hex: 0xFFB347).opacity(0.45),
                                            Color(hex: 0xFF7A1A).opacity(0.16),
                                            .clear],
                                   center: .center, startRadius: 3, endRadius: 58)
                )
                .frame(width: 116, height: 116)
                .offset(y: -Self.height / 2 + 6)
                .opacity(Double(night))
                .animation(.easeInOut(duration: 1.2), value: night)
            Image("watch_tower")
                .resizable()
                .scaledToFit()
                .frame(height: Self.height)
                .mask(
                    LinearGradient(stops: [
                        .init(color: .white, location: 0),
                        .init(color: .white, location: 0.80),
                        .init(color: .clear, location: 1),
                    ], startPoint: .top, endPoint: .bottom)
                )
        }
        .frame(width: 70, height: Self.height)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// MARK: - Small chrome

private struct LevelBadge: View {
    let level: Int

    var body: some View {
        Text("\(level)")
            .font(.system(size: 9, weight: .heavy, design: .serif))
            .foregroundColor(.paper)
            .frame(minWidth: 14, minHeight: 14)
            .background(Circle().fill(Color.ink.opacity(0.85)))
            .overlay(Circle().strokeBorder(Color.straw.opacity(0.8), lineWidth: 0.8))
            .allowsHitTesting(false)
    }
}

private struct RidgeDisc: View {
    let level: Int

    var body: some View {
        ZStack {
            Circle()
                .fill(LinearGradient(colors: [Color(hex: 0xA8ACB2), Color(hex: 0x5C6066)],
                                     startPoint: .top, endPoint: .bottom))
            Circle().strokeBorder(Color(hex: 0x3B3E43), lineWidth: 0.8)
            Text("\(level)")
                .font(.system(size: 7.5, weight: .heavy, design: .serif))
                .foregroundColor(Color(hex: 0xEDEAE2))
        }
        .frame(width: 13, height: 13)
        .shadow(color: .black.opacity(0.45), radius: 1, y: 0.5)
    }
}

/// A cleared, staked build plot — ragged earth, survey stakes and string,
/// foundation stones; its own irregular edge melts into the grass. Tap an
/// open plot to choose what to build; locked plots sit dimmed until the
/// Keep level unlocks them.
private struct PlotSite: View {
    let locked: Bool
    let onTap: () -> Void

    private static let side: CGFloat = 50

    var body: some View {
        Button(action: onTap) {
            Image("medieval_building_plot_aerial")
                .resizable()
                .scaledToFit()
                .frame(width: Self.side, height: Self.side)
                .opacity(locked ? 0.45 : 1)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(locked)
        .accessibilityLabel(locked ? "Plot locked — raise the Keep" : "Empty plot, choose a building")
    }
}

/// Small mm:ss countdown set over a lot while it upgrades.
private struct HoldCountdown: View {
    let finishAt: Double

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let left = finishAt - context.date.timeIntervalSince1970 * 1000
            let total = max(0, Int(ceil(left / 1000)))
            Text(String(format: "%d:%02d", total / 60, total % 60))
                .font(.system(size: 10, weight: .heavy, design: .monospaced))
                .foregroundColor(.paper)
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(Capsule().fill(Color.ink.opacity(0.85)))
        }
        .allowsHitTesting(false)
    }
}

/// Thin white chimney smoke: three staggered puffs drifting right.
private struct KeepSmoke: View {
    let night: CGFloat

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20.0)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            Canvas { ctx, size in
                let base = CGPoint(x: size.width * 0.5, y: size.height - 3)
                for i in 0..<3 {
                    let phase = (t / 4.2 + Double(i) / 3).truncatingRemainder(dividingBy: 1)
                    let rise = CGFloat(phase)
                    let x = base.x + rise * 14
                    let y = base.y - rise * (size.height - 8)
                    let radius = 2.2 + rise * 3.4
                    let alpha = 0.38 * sin(.pi * phase) * (1 - 0.55 * night)
                    guard alpha > 0.01 else { continue }
                    ctx.drawLayer { layer in
                        layer.addFilter(.blur(radius: 1.6))
                        layer.fill(Path(ellipseIn: CGRect(x: x - radius, y: y - radius,
                                                          width: radius * 2, height: radius * 2)),
                                   with: .color(.white.opacity(alpha)))
                    }
                }
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Plot build sheet (the six plot types, capped)

/// Choosing what to build on an open outside plot. Only the six plot
/// building types are offered, each with its maximum count.
struct PlotBuildSheet: View {
    @EnvironmentObject var store: GameStore
    @Environment(\.dismiss) private var dismiss
    let plot: Int
    @State private var error: String?

    private var options: [(name: String, cap: Int)] {
        GameStore.buildingOrder.compactMap { name in
            guard let cap = GameStore.plotBuildings[name] else { return nil }
            return (name, cap)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Empty plot")
                .font(.system(size: 19, weight: .bold))
                .foregroundColor(BW.text)
            Text("Plot \(plot + 1 + GameStore.standingLotCount) of \(GameStore.totalPlotSpaces) — " +
                 "\(store.unlockedOpenPlots()) plots are open at Keep \(store.keepLevel).")
                .font(.system(size: 13)).foregroundColor(BW.subtext)
            ForEach(options, id: \.name) { opt in
                buildRow(opt)
            }
            if let e = error { Text(e).redLine() }
            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(BW.background)
    }

    private func buildRow(_ opt: (name: String, cap: Int)) -> some View {
        let built = store.count(opt.name)
        let full = built >= opt.cap
        return HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(HoldArt.display(opt.name))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(BW.text)
                Text("\(built) of \(opt.cap) built · \(costLine)")
                    .font(.system(size: 12))
                    .foregroundColor(BW.subtext)
            }
            Spacer(minLength: 8)
            SlateButtonSmall(title: full ? "Full" : "Build", disabled: full || store.isBusy) {
                let e = store.build(opt.name, onPlot: plot)
                if e == nil { dismiss() } else { error = e }
            }
        }
    }

    private var costLine: String {
        let c = store.upgradeCost(1)
        return "\(store.comma(c.food)) food · \(store.comma(c.wood)) wood · " +
               "\(store.comma(c.stone)) stone · \(store.comma(c.iron)) iron"
    }
}

// MARK: - Upgrade sheet (unchanged rules and costs)

struct BuildingUpgradeSheet: View {
    @EnvironmentObject var store: GameStore
    private let purchases = PurchaseStore.shared
    let buildingName: String
    var plot: Int? = nil
    @State private var error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(HoldArt.display(buildingName))
                .font(.system(size: 19, weight: .bold))
                .foregroundColor(BW.text)
            Text(store.level(buildingName, plot: plot) == 0 && plot != nil
                 ? "Rising…"
                 : "Level \(store.level(buildingName, plot: plot))")
                .font(.system(size: 14)).foregroundColor(BW.subtext)
            ForEach(lines, id: \.self) { line in
                Text(line)
                    .font(.system(size: 13))
                    .foregroundColor(BW.subtext)
            }
            if buildingName == "Keep" { KeepActions() }
            if isPlot, let pending = store.building(buildingName, plot: plot)?.pending,
               pending > 0 {
                SlateButton(title: "Collect \(store.comma(pending))") {
                    _ = store.collect(buildingName, plot: plot)
                }
            }
            if let e = error { Text(e).redLine() }
            if store.game.upgrade == nil,
               let missing = store.upgradeShortfall(buildingName, plot: plot) {
                // Price off the bundles: the shortfall as a fraction of a
                // Supply Sack decides the tier; the detail line shows the
                // bundle value of what's missing.
                let fraction = store.upgradeShortfallFraction(buildingName, plot: plot) ?? 0
                let big = fraction > 0.4
                let estimate = String(format: "bundle value ≈ $%.2f", fraction * 0.99)
                shopRow(title: big ? "Missing materials (large)" : "Missing materials",
                        detail: "\(missingLine(missing)) — \(estimate)",
                        productID: big ? ShopProductID.fillGapBig : ShopProductID.fillGap,
                        fallback: big ? "$1.99" : "$0.99") {
                    if let e = store.grantUpgradeGap(buildingName, plot: plot) { return e }
                    return store.upgrade(buildingName, plot: plot)
                }
            }
            upgradeButton
            shopSection
            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(BW.background)
    }

    /// The exact production/role lines from the master spec.
    private var lines: [String] {
        let lvl = store.level(buildingName, plot: plot)
        switch buildingName {
        case "Farm": return plotLines("food", lvl)
        case "Timber yard": return plotLines("wood", lvl)
        case "Quarry": return plotLines("stone", lvl)
        case "Mine": return plotLines("iron", lvl)
        case "Vault": return ["Gold per minute: \(lvl * 5)",
                              "Protects \(store.comma(lvl * 500)) of each material from raids"]
        case "Barracks": return ["Trains Footmen"]
        case "Range": return ["Trains Archers"]
        case "Stable": return ["Trains Riders"]
        case "Workshop": return ["Trains Rams"]
        case "Wall": return ["Wall points: \(lvl * 500)"]
        case "Hospital": return ["Beds: \(lvl * 100)"]
        case "Academy": return ["Opens research"]
        case "Rally yard": return ["Marches allowed: 3"]
        case "Keep": return ["Caps all buildings"]
        default: return []
        }
    }

    /// The four production plots hold their yield on the lot until collected.
    private var isPlot: Bool { GameStore.plotResource[buildingName] != nil }

    private func plotLines(_ resource: String, _ lvl: Int) -> [String] {
        let waiting = store.building(buildingName, plot: plot)?.pending ?? 0
        return ["\(resource.capitalized) per minute: \(lvl * 20)",
                "Lot cap: \(store.comma(store.plotCap(lvl))) — it stops piling when full",
                "Safe on the lot until collected — raids only take storehouse stock."]
            + (waiting > 0 ? ["Waiting on the lot: \(store.comma(waiting)) / \(store.comma(store.plotCap(lvl)))"] : [])
    }

    @ViewBuilder private var upgradeButton: some View {
        if let up = store.game.upgrade, up.buildingName == buildingName, up.plot == plot {
            UpgradeCountdown(finishAt: up.finishAt)
            HStack(spacing: 8) {
                SlateButtonSmall(title: "Speed up 1h — \(purchases.priceText(ShopProductID.speedUp1h, fallback: "$0.99"))") {
                    buy(ShopProductID.speedUp1h) { store.useSpeedUp() }
                }
                SlateButtonSmall(title: "Finish now — \(purchases.priceText(ShopProductID.instantFinish, fallback: "$1.99"))") {
                    buy(ShopProductID.instantFinish) { store.finishUpgradeNow() }
                }
            }
            SlateButton(title: "Busy", disabled: true) {}
        } else if store.game.upgrade != nil {
            SlateButton(title: "Busy", disabled: true) {}
        } else {
            SlateButton(title: "Upgrade") {
                error = store.upgrade(buildingName, plot: plot)
            }
        }
    }

    /// "400 food · 200 wood" — the exact shortfall for the next upgrade.
    private func missingLine(_ missing: Resources) -> String {
        ["food", "wood", "stone", "iron"].compactMap { resource -> String? in
            let gap = missing.value(resource)
            return gap > 0 ? "\(store.comma(gap)) \(resource)" : nil
        }.joined(separator: " · ")
    }

    /// Supply bundles, purchasable any time.
    private var shopSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("SUPPLY SHOP")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(BW.subtext)
            shopRow(title: "Supply Sack",
                    detail: "1,000 food · 1,000 wood · 750 stone · 500 iron",
                    productID: ShopProductID.supplySack, fallback: "$0.99") {
                store.grantBundle(food: 1000, wood: 1000, stone: 750, iron: 500)
                return nil
            }
            shopRow(title: "Supply Wagon",
                    detail: "3,000 food · 3,000 wood · 2,250 stone · 1,500 iron",
                    productID: ShopProductID.supplyWagon, fallback: "$2.99") {
                store.grantBundle(food: 3000, wood: 3000, stone: 2250, iron: 1500)
                return nil
            }
            shopRow(title: "Supply Cart",
                    detail: "6,000 food · 6,000 wood · 4,500 stone · 3,000 iron",
                    productID: ShopProductID.supplyCart, fallback: "$4.99") {
                store.grantBundle(food: 6000, wood: 6000, stone: 4500, iron: 3000)
                return nil
            }
            shopRow(title: "Supply Convoy",
                    detail: "14,000 food · 14,000 wood · 10,500 stone · 7,000 iron",
                    productID: ShopProductID.supplyConvoy, fallback: "$9.99") {
                store.grantBundle(food: 14000, wood: 14000, stone: 10500, iron: 7000)
                return nil
            }
            shopRow(title: "Supply Fleet",
                    detail: "30,000 food · 30,000 wood · 22,500 stone · 15,000 iron",
                    productID: ShopProductID.supplyFleet, fallback: "$19.99") {
                store.grantBundle(food: 30000, wood: 30000, stone: 22500, iron: 15000)
                return nil
            }
            shopRow(title: "Supply Armada",
                    detail: "66,000 food · 66,000 wood · 49,500 stone · 33,000 iron",
                    productID: ShopProductID.supplyArmada, fallback: "$39.99") {
                store.grantBundle(food: 66000, wood: 66000, stone: 49500, iron: 33000)
                return nil
            }
            Button {
                Task { await purchases.restore() }
            } label: {
                Text("Restore Purchases")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(BW.subtext)
            }
        }
    }

    private func shopRow(title: String, detail: String,
                         productID: String, fallback: String,
                         apply: @escaping () -> String?) -> some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(BW.text)
                Text(detail)
                    .font(.system(size: 12))
                    .foregroundColor(BW.subtext)
            }
            Spacer(minLength: 8)
            SlateButtonSmall(title: purchases.priceText(productID, fallback: fallback)) {
                buy(productID, apply: apply)
            }
        }
    }

    /// Charges the product, then applies the boost. Cancellation is silent.
    private func buy(_ productID: String, apply: @escaping () -> String?) {
        Task {
            let bought = await purchases.purchase(productID)
            if bought {
                error = apply()
            } else if let purchaseError = purchases.error {
                error = purchaseError
                purchases.error = nil
            }
        }
    }
}

// MARK: - Keep actions (shield)

struct KeepActions: View {
    @EnvironmentObject var store: GameStore

    var body: some View {
        if store.isShielded {
            SlateButton(title: "Drop shield") { store.dropShield() }
            ShieldCountdown(until: store.game.shieldUntil)
        } else {
            SlateButton(title: "Raise shield") { store.raiseShield() }
        }
    }
}

// MARK: - Countdowns

/// Live mm:ss countdown on the upgrading building.
struct UpgradeCountdown: View {
    let finishAt: Double

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let left = finishAt - context.date.timeIntervalSince1970 * 1000
            let total = max(0, Int(ceil(left / 1000)))
            Text(String(format: "%d:%02d", total / 60, total % 60))
                .font(.system(size: 15, weight: .bold, design: .monospaced))
                .foregroundColor(BW.text)
        }
    }
}

/// Live shield countdown line.
struct ShieldCountdown: View {
    let until: Double

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let left = until - context.date.timeIntervalSince1970 * 1000
            let total = max(0, Int(ceil(left / 1000)))
            Text("Shielded \(String(format: "%d:%02d", total / 60, total % 60))")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(BW.subtext)
        }
    }
}
