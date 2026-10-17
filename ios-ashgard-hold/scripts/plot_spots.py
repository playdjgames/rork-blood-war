#!/usr/bin/env python3
"""Find open-grass building plots on the hold renders.

Classifies every pixel of a 1024x1536 aerial render as open meadow grass or
not (trees, moat, wall, rock, road), then greedily picks plot anchors in
staggered rows whose whole footprint is open grass and which keep clear of
every existing anchor. Prints anchors as fractions of the render frame and
writes a debug overlay.

Usage:
  python3 scripts/plot_spots.py <render.png> <x_offset> <overlay.png> <y_min> [existing...]
  existing anchors are "x,y" fractions in the CastleScreen frame (x may be
  > 1 for the east extension; x_offset shifts the frame onto this render).
"""
import sys
import numpy as np
from PIL import Image, ImageDraw

# Reference view: land drawn ~467pt wide x ~700pt tall (fill-scaled render).
PT_PER_FRAC_X = 467.0
PT_PER_FRAC_Y = 700.0
PX_PER_PT = 1024.0 / PT_PER_FRAC_X
FOOT_PT = 24.0          # footprint radius that must be open grass
GAP_X_PT = 72.0         # min horizontal spacing between anchors (same row)
GAP_Y_PT = 58.0         # min vertical spacing between anchors (stagger)


def open_mask(img: np.ndarray) -> np.ndarray:
    r, g, b = (img[..., i].astype(np.float32) for i in range(3))
    lum = 0.30 * r + 0.59 * g + 0.11 * b
    # Meadow: mid-bright, warm yellow-green (well above blue). Pine canopy
    # and shadows are dark; moat/river is blue-grey; rock and the sandstone
    # wall are low-saturation or orange-tan (red >> green).
    grass = ((lum > 72) & (lum < 185) & (g - b > 34) & (r - b > 18)
             & (g > r * 0.84))
    return grass


def footprint_ok(mask: np.ndarray, cx: float, cy: float, rad: float) -> float:
    h, w = mask.shape
    x0, x1 = int(cx - rad), int(cx + rad)
    y0, y1 = int(cy - rad * 0.7), int(cy + rad * 0.7)
    if x0 < 0 or y0 < 0 or x1 >= w or y1 >= h:
        return 0.0
    yy, xx = np.mgrid[y0:y1, x0:x1]
    ell = ((xx - cx) / rad) ** 2 + ((yy - cy) / (rad * 0.7)) ** 2 <= 1
    return float(mask[y0:y1, x0:x1][ell].mean())


def clear_of(anchors, x, y):
    for ax, ay in anchors:
        dx = (ax - x) * PT_PER_FRAC_X / GAP_X_PT
        dy = (ay - y) * PT_PER_FRAC_Y / GAP_Y_PT
        if dx * dx + dy * dy < 1:
            return False
    return True


def main():
    path, x_off, overlay = sys.argv[1], float(sys.argv[2]), sys.argv[3]
    y_min = float(sys.argv[4])  # top of the search band (below the moat)
    existing = [tuple(float(v) for v in a.split(",")) for a in sys.argv[5:]]
    img = np.asarray(Image.open(path).convert("RGB"))
    h, w, _ = img.shape
    mask = open_mask(img)
    rad = FOOT_PT * PX_PER_PT
    anchors = list(existing)
    found = []
    # Fine greedy scan, top-to-bottom then west-to-east, so new plots pack
    # into the gaps between existing rows at the same spacing.
    for y in np.arange(y_min, 0.93, 0.005):
        for x in np.arange(x_off + 0.03, x_off + 0.97, 0.005):
            fx, fy = (x - x_off) * w, y * h
            if clear_of(anchors, x, y) and footprint_ok(mask, fx, fy, rad) >= 0.86:
                anchors.append((float(x), float(y)))
                found.append((round(float(x), 3), round(float(y), 3)))

    vis = Image.fromarray(img).convert("RGB")
    tint = Image.new("RGB", vis.size, (255, 0, 0))
    vis = Image.composite(vis, Image.blend(vis, tint, 0.35),
                          Image.fromarray((mask * 255).astype(np.uint8)))
    d = ImageDraw.Draw(vis)
    for (ax, ay), color in [(a, "yellow") for a in existing] + [(a, "cyan") for a in found]:
        px, py = (ax - x_off) * w, ay * h
        if 0 <= px < w:
            d.ellipse([px - rad, py - rad * 0.7, px + rad, py + rad * 0.7], outline=color, width=4)
    vis.save(overlay)
    print(len(found), "new anchors")
    for a in found:
        print(f"CGPoint(x: {a[0]:.3f}, y: {a[1]:.3f}),")


if __name__ == "__main__":
    main()
