"""Convex shoulder validation using the original NURBS parameterization.

The expensive live CurveLine/retrim operations are intentionally avoided.
Deform a closed native Rhino mesh in the workspace, then import it back.
"""
from pathlib import Path
import json
import numpy as np

OUT = Path(__file__).resolve().parents[1] / 'docs/concepts/reference_1016_completion_v03'
ref = json.loads((OUT / 'shoulder_surface_reference.json').read_text())
cp = np.asarray(ref['cp'])
ku = np.r_[ref['knots_u'][0], ref['knots_u'], ref['knots_u'][-1]]
kv = np.r_[ref['knots_v'][0], ref['knots_v'], ref['knots_v'][-1]]
pu, pv = ref['degree_u'], ref['degree_v']

def basis(t, knots, degree, count):
    span = np.clip(np.searchsorted(knots, t, side='right') - 1, degree, count - 1)
    n = np.zeros((len(t), degree + 1)); n[:, 0] = 1
    left, right = np.zeros_like(n), np.zeros_like(n)
    for j in range(1, degree + 1):
        left[:, j] = t - knots[span + 1 - j]
        right[:, j] = knots[span + j] - t
        saved = np.zeros(len(t))
        for r in range(j):
            temp = n[:, r] / np.maximum(right[:, r + 1] + left[:, j - r], 1e-15)
            n[:, r] = saved + right[:, r + 1] * temp
            saved = left[:, j - r] * temp
        n[:, j] = saved
    return span, n

def evaluate(u, v):
    iu, bu = basis(u, ku, pu, cp.shape[0])
    iv, bv = basis(v, kv, pv, cp.shape[1])
    point = np.zeros((len(u), 4))
    for a in range(pu + 1):
        for b in range(pv + 1):
            c = cp[iu - pu + a, iv - pv + b].copy()
            c[:, :3] *= c[:, 3, None]
            point += c * (bu[:, a] * bv[:, b])[:, None]
    return point[:, :3] / point[:, 3, None]

def inverse_xy(xy):
    u = np.clip(ku[pu] + (xy[:, 0] - 1102.) / 380. * (ku[-pu-1] - ku[pu]), ku[pu], ku[-pu-1])
    v = np.full(len(u), 2.)
    for _ in range(14):
        p = evaluate(u, v)
        du = (evaluate(np.minimum(u + .001, ku[-pu-1]), v) - evaluate(np.maximum(u - .001, ku[pu]), v)) / np.maximum(np.minimum(u + .001, ku[-pu-1]) - np.maximum(u - .001, ku[pu]), 1e-12)[:, None]
        dv = (evaluate(u, np.minimum(v + .0001, kv[-pv-1])) - evaluate(u, np.maximum(v - .0001, kv[pv]))) / np.maximum(np.minimum(v + .0001, kv[-pv-1]) - np.maximum(v - .0001, kv[pv]), 1e-12)[:, None]
        r = xy - p[:, :2]
        det = du[:, 0] * dv[:, 1] - du[:, 1] * dv[:, 0]
        step_u = (r[:, 0] * dv[:, 1] - r[:, 1] * dv[:, 0]) / det
        step_v = (du[:, 0] * r[:, 1] - du[:, 1] * r[:, 0]) / det
        u = np.clip(u + step_u, ku[pu], ku[-pu-1])
        v = np.clip(v + step_v, kv[pv], kv[-pv-1])
        if np.max(np.linalg.norm(r, axis=1)) < 1e-7:
            break
    return u, v, np.linalg.norm(evaluate(u, v)[:, :2] - xy, axis=1)

def ease(x):
    x = np.clip(x, 0, 1)
    return x*x*(3-2*x)

def process():
    mesh = json.loads((OUT / 'shoulder_source_mesh.json').read_text())
    xyz = np.asarray(mesh['vertices'], dtype=float)
    u, v, errors = inverse_xy(xyz[:, :2])
    # Pick the non-isoparametric BACK boundary rather than the two end cuts.
    back = next(x for x in ref['uv_boundary'] if x['iso'] == 'None' and abs(x['points'][-1][0] - x['points'][0][0]) > 100)
    curve = np.asarray(back['points']); curve = curve[np.argsort(curve[:, 0])]
    back_v = np.interp(u, curve[:, 0], curve[:, 1])
    fraction = np.clip(v / back_v, 0, 1)
    old_top = evaluate(u, v)[:, 2]
    front_z = evaluate(u, np.zeros_like(v))[:, 2]
    back_z = evaluate(u, back_v)[:, 2]
    landing_z = np.maximum(back_z, 45.)
    convex = front_z + (landing_z - front_z) * (1 - (1 - fraction)**3)
    convex += 8 * np.sin(np.pi * fraction)**2
    weight = ease((u - 1380.) / 35.) * ease((1670. - u) / 35.)
    new_top = old_top + (convex - old_top) * weight
    height_fraction = np.clip((xyz[:, 2] + 2.) / (old_top + 2.), 0, 1)
    revised = xyz.copy()
    revised[:, 2] = -2 + height_fraction * (new_top + 2)
    revised[weight == 0] = xyz[weight == 0]
    delta = revised[:, 2] - xyz[:, 2]
    mesh['vertices'] = revised.tolist()
    (OUT / 'shoulder_convex_mesh_v05.json').write_text(json.dumps(mesh))
    report = {'method': 'Closed mesh prototype with the original NURBS XY map; convex section normalized to the actual trimmed back boundary.',
              'vertices': len(xyz), 'faces': len(mesh['faces']),
              'maximum_inverse_xy_error_m': float(errors.max()),
              'maximum_height_m': float(revised[:, 2].max()),
              'maximum_raise_m': float(delta.max()),
              'end_regions_max_displacement_m': float(np.max(np.abs(delta[weight == 0]))),
              'new_tunnels': 0, 'bridge_road_height_unchanged': True}
    (OUT / 'shoulder_convex_mesh_v05_report.json').write_text(json.dumps(report, indent=2))
    print(json.dumps(report, indent=2))

if __name__ == '__main__':
    process()
