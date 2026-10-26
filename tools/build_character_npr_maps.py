"""Author Ganyu-specific numerical Face SDF and material masks, not color textures.

Run export_character_npr_inputs.gd first. Rasterization uses the imported mesh UVs.
The SDF silhouette is an explicitly designed cheek/nose boundary in face X/Y;
it is not an extraction of an official game LightMap or an inferred BaseColor SDF.
"""
from pathlib import Path
import hashlib
import json
import numpy as np
from PIL import Image
from scipy.ndimage import distance_transform_edt, gaussian_filter, map_coordinates

ROOT = Path(__file__).resolve().parents[1]
INPUT = ROOT / ".godot/character_npr_inputs"
OUT = ROOT / "materials/characters/ganyu_npr"
SIZE = 1024


def uv_raster(surfaces):
    position = np.zeros((SIZE, SIZE, 3), np.float32)
    occupied = np.zeros((SIZE, SIZE), bool)
    for row in surfaces:
        points = np.array(row["positions"])
        uv = np.array(row["uv"]) * SIZE - 0.5
        for tri in np.array(row["indices"]).reshape(-1, 3):
            t = uv[tri]
            lo = np.maximum(0, np.floor(t.min(0)).astype(int))
            hi = np.minimum(SIZE - 1, np.ceil(t.max(0)).astype(int))
            if np.any(lo > hi):
                continue
            x, y = np.meshgrid(np.arange(lo[0], hi[0] + 1), np.arange(lo[1], hi[1] + 1))
            a, b, c = t
            determinant = (b[1] - c[1]) * (a[0] - c[0]) + (c[0] - b[0]) * (a[1] - c[1])
            if abs(determinant) < 1e-9:
                continue
            w0 = ((b[1] - c[1]) * (x - c[0]) + (c[0] - b[0]) * (y - c[1])) / determinant
            w1 = ((c[1] - a[1]) * (x - c[0]) + (a[0] - c[0]) * (y - c[1])) / determinant
            w2 = 1 - w0 - w1
            inside = (w0 >= -1e-5) & (w1 >= -1e-5) & (w2 >= -1e-5)
            p = w0[..., None] * points[tri[0]] + w1[..., None] * points[tri[1]] + w2[..., None] * points[tri[2]]
            position[y[inside], x[inside]] = p[inside]
            occupied[y[inside], x[inside]] = True
    return position, occupied


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    data = json.loads((INPUT / "surfaces.json").read_text(encoding="utf-8"))
    face = [r for r in data["surfaces"] if r["name"] in ("面1", "面2")]
    position, coverage = uv_raster(face)
    # True signed distances to an authored front-projection shadow silhouette.
    axis_x = np.linspace(-0.11, 0.11, SIZE)
    axis_y = np.linspace(1.30, 1.53, SIZE)
    xx, yy = np.meshgrid(axis_x, axis_y)
    boundary = (-0.007 * np.exp(-((yy - 1.389) / 0.020) ** 2)
                + 0.004 * np.exp(-((yy - 1.440) / 0.024) ** 2)
                - 0.002 * np.exp(-((yy - 1.341) / 0.012) ** 2))
    lit = xx > boundary
    scale = (axis_y[1] - axis_y[0], axis_x[1] - axis_x[0])
    distance = distance_transform_edt(lit, sampling=scale) - distance_transform_edt(~lit, sampling=scale)
    signed = np.clip(0.5 + distance / 0.185, 0.015, 0.985)
    sy = (position[..., 1] - axis_y[0]) / (axis_y[-1] - axis_y[0]) * (SIZE - 1)
    sx = (position[..., 0] - axis_x[0]) / (axis_x[-1] - axis_x[0]) * (SIZE - 1)
    rgba = np.ones((SIZE, SIZE, 4), np.float32)
    rgba[..., 0] = map_coordinates(signed, [sy, sx], order=1, mode="nearest")
    rgba[..., 1] = map_coordinates(signed, [sy, SIZE - 1 - sx], order=1, mode="nearest")
    rgba[..., 2] = coverage
    # Extend the nearest occupied texel across unused UV space to avoid seam halos.
    nearest = distance_transform_edt(~coverage, return_distances=False, return_indices=True)
    for channel in (0, 1):
        rgba[..., channel] = rgba[..., channel][tuple(nearest)]
    Image.fromarray(np.round(rgba * 255).astype(np.uint8)).save(OUT / "face_sdf.png")

    source = Image.open(INPUT / "服.png").convert("RGBA").resize((SIZE, SIZE), Image.Resampling.LANCZOS)
    rgb = np.asarray(source).astype(float)[..., :3] / 255
    r, g, b = np.moveaxis(rgb, -1, 0)
    # Atlas-specific, visually reviewed color selections. This authored recipe is
    # intentionally restricted to this exact atlas; not a universal metal classifier.
    gold = ((r > g * 1.05) & (g > b * 1.08) & (r > 0.24) & ((r - b) > 0.08)).astype(float)
    white_cloth = ((rgb.min(-1) > 0.68) & (rgb.max(-1) - rgb.min(-1) < 0.15)).astype(float)
    mask = np.stack([gaussian_filter(gold, 0.6), gaussian_filter(white_cloth, 0.6), np.zeros_like(gold)], -1)
    Image.fromarray(np.round(mask * 255).astype(np.uint8)).save(OUT / "body_material_mask.png")
    report = {"size": SIZE, "source_geometry_sha256": hashlib.sha256((INPUT / "surfaces.json").read_bytes()).hexdigest(),
              "source_atlas_sha256": hashlib.sha256((INPUT / "服.png").read_bytes()).hexdigest(),
              "face_channels": {"R": "+head-right light SDF", "G": "-head-right light SDF", "B": "face UV coverage", "A": "1"},
              "body_channels": {"R": "authored gold selection", "G": "white cloth selection", "B": "reserved"},
              "face_covered_pixels": int(coverage.sum()), "face_sdf_range": [float(rgba[..., :2].min()), float(rgba[..., :2].max())],
              "gold_fraction": float(gold.mean()), "white_cloth_fraction": float(white_cloth.mean()),
              "method": "Authored side-light silhouette -> signed Euclidean distance -> rasterize through actual face UV; dual light sides avoid assuming mirrored UV islands."}
    (OUT / "build_report.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(report, ensure_ascii=False))


if __name__ == "__main__":
    main()
