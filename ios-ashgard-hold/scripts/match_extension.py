#!/usr/bin/env python3
"""Colour-match the east land extension to the hold render.

The generated `aerial_meadow_road` came out slightly brighter and punchier
than `aerial_castle_keep_moat`. A per-channel linear grade (gain 0.86 on R/G,
offset chosen so the open-meadow means match; gentle lift on B for the shade)
makes the two photos read as one continuous landscape. Run once on the raw
generation; the original is kept beside it as *_raw.png outside the bundle.
"""
import sys
import numpy as np
from PIL import Image

src, dst = sys.argv[1], sys.argv[2]
img = np.asarray(Image.open(src).convert("RGB")).astype(np.float32)
img[..., 0] = img[..., 0] * 0.86 + 7.9
img[..., 1] = img[..., 1] * 0.86 + 10.4
img[..., 2] = img[..., 2] * 0.80 + 12.0
Image.fromarray(np.clip(img, 0, 255).astype(np.uint8)).save(dst)
print("graded", dst)
