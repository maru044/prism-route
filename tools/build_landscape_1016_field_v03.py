"""Vectorized height controls for the Rhino 1016 continuous-landscape study.

Geometry stays native NURBS in Rhino. This computes elevations at the refined
control points while retaining their existing XY map and trimming boundaries.
"""
from pathlib import Path
import json
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'docs/concepts/reference_1016_completion_v03'
GUIDES = json.loads((OUT / 'dense_guides.json').read_text())

def ease(t):
    t = np.clip(t, 0, 1)
    return t * t * (3 - 2 * t)

def nearest(xy, guide):
    guide = np.asarray(guide, dtype=float)
    ds, signs, hs = [], [], []
    for start in range(0, len(xy), 800):
        d = xy[start:start + 800, None, :] - guide[None, :, :2]
        dd = (d * d).sum(axis=2)
        j = dd.argmin(axis=1)
        selected = d[np.arange(len(j)), j]
        t = guide[j, 3:5]
        norm = np.sqrt((t * t).sum(axis=1))
        signs.extend((-selected[:, 0] * t[:, 1] + selected[:, 1] * t[:, 0]) / np.maximum(norm, 1e-8))
        ds.extend(np.sqrt(dd[np.arange(len(j)), j]))
        hs.extend(guide[j, 2])
    return np.asarray(ds), np.asarray(signs), np.asarray(hs)

def smooth_max(a, b, softness=.12):
    return .5 * (a + b + np.sqrt((a - b) ** 2 + softness ** 2) - softness)

def target_height(xy):
    d6, side6, h6 = nearest(xy, GUIDES['C6'])
    # C6 travels westward: the short, steep face is toward the existing bridge,
    # while the broad opposite flank unfolds into the inner landscape.
    width6 = np.where(side6 >= 0, 26., 112.)
    bank = h6 * np.exp(-(d6 / width6) ** 2)
    d5, _, h5 = nearest(xy, GUIDES['C5'])
    spine = h5 * np.exp(-(d5 / 76.) ** 2)
    h = smooth_max(bank, spine)
    if 'C7_proposed_returning_ridge' in GUIDES:
        d7, side7, h7 = nearest(xy, GUIDES['C7_proposed_returning_ridge'])
        return_fold = np.maximum(0, h7) * np.exp(-(d7 / np.where(side7 >= 0, 140., 32.)) ** 2)
        h = smooth_max(h, return_fold)
    x, y = xy.T
    # Broad subordinate folds connect the ridge to the lowland. These are
    # ground-connected elevations, not individual leaf-shaped extrusions.
    u = ((x - 1080) * .60 + (y - 870) * .80) / 180.
    v = (-(x - 1080) * .80 + (y - 870) * .60) / 65.
    west = 5.8 * np.exp(-(u * u + v * v))
    u = ((x - 1360) * .40 + (y - 1370) * .9165) / 170.
    v = (-(x - 1360) * .9165 + (y - 1370) * .40) / 66.
    coastal = 5.4 * np.exp(-(u * u + v * v))
    h = smooth_max(smooth_max(h, west), coastal)
    # Keep the original user ridge elevations, including C5's zero-height end.
    w5 = np.exp(-(d5 / 24.) ** 2)
    h = h * (1 - w5) + h5 * w5
    w6 = np.exp(-(d6 / 14.) ** 2)
    h = h * (1 - w6) + h6 * w6
    # Flat landing bands match the user's C2/C4 ground edges, never the top.
    d2, _, _ = nearest(xy, GUIDES['C2'])
    d4, _, _ = nearest(xy, GUIDES['C4'])
    h *= ease(np.minimum(d2, d4) / 24.)
    return np.maximum(h, 0.)

def process():
    grids = json.loads((OUT / 'control_grids.json').read_text())
    output = []
    for row in grids:
        p = np.asarray(row['points'], dtype=float)
        h = target_height(p[:, :2])
        if row['id'] != 'a4adc150-3ba0-4216-b8b5-8d21449e8f69':
            # Limit coastal changes to this study; keep the distant island's
            # previous geometry rather than rebuilding unrelated terrain.
            x, y = p[:, :2].T
            blend = ease((x - 870.) / 180.) * ease((1830. - x) / 140.)
            blend *= ease((y - 520.) / 100.) * ease((1710. - y) / 140.)
            h = p[:, 2] * (1 - blend) + h * blend
        output.append({k: row[k] for k in ('id', 'face', 'nu', 'nv')} | {'z': h.tolist()})
    (OUT / 'elevation_controls.json').write_text(json.dumps(output))
    print(json.dumps([{'source': x['id'], 'face': x['face'], 'controls': len(x['z']),
                       'min_z': min(x['z']), 'max_z': max(x['z'])} for x in output], indent=2))

if __name__ == '__main__':
    process()
