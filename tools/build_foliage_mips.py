"""Build linear-color mip chains with alpha-test coverage preserved.
Original PNGs stay unchanged. Godot packs the resulting chains as ImageTexture
resources using tools/import_foliage_mips.gd. No new artwork is introduced.
"""
from pathlib import Path
import json
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / ".vegetation_art_build" / "foliage_mips"
SPECS = [
    ("leaf", "leaf_clusters_witness_sparse_flat_v11.png", .50),
    ("clump", "tree_broad_clump_unlit_4var_v1.png", .46),
    ("canopy", "tree_small_canopy_unlit_8view_v1.png", .42),
]

def resize(array, size):
    return np.asarray(Image.fromarray(array.astype(np.float32)).resize(size, Image.Resampling.BOX))

def encode(rgb, alpha, mean):
    rgb = np.where(alpha[:, :, None] > 1e-6, rgb / np.maximum(alpha[:, :, None], 1e-6), mean)
    srgb = np.where(rgb <= .0031308, rgb * 12.92, 1.055 * np.maximum(rgb, 0) ** (1/2.4) - .055)
    return np.concatenate([np.clip(srgb, 0, 1), alpha[:, :, None]], axis=2)

def main():
    OUT.mkdir(parents=True, exist_ok=True)
    manifest = []
    for key, name, cutoff in SPECS:
        pixels = np.asarray(Image.open(ROOT / "assets/vegetation/textures" / name).convert("RGBA"), dtype=np.float32) / 255
        alpha = pixels[:, :, 3]
        srgb = pixels[:, :, :3]
        rgb = np.where(srgb <= .04045, srgb / 12.92, ((srgb + .055) / 1.055) ** 2.4)
        mean = (rgb * alpha[:, :, None]).sum(axis=(0, 1)) / alpha.sum()
        target = float((alpha >= cutoff).mean())
        width, height = pixels.shape[1], pixels.shape[0]
        for preserve in [False, True]:
            rgb_premul = rgb * alpha[:, :, None]
            a = alpha.copy()
            chunks, statistics = [], []
            level = 0
            while True:
                encoded = encode(rgb_premul, a, mean)
                corrected = a.copy()
                scale = 1.0
                if preserve and level > 0:
                    lo, hi = 0.0, 32.0
                    for _ in range(20):
                        scale = (lo + hi) / 2
                        if (np.clip(a * scale, 0, 1) >= cutoff).mean() < target:
                            lo = scale
                        else:
                            hi = scale
                    corrected = np.clip(a * hi, 0, 1)
                    encoded[:, :, 3] = corrected
                encoded = np.rint(encoded * 255).clip(0, 255).astype(np.uint8)
                chunks.append(encoded.tobytes())
                statistics.append({"level": level, "size": [a.shape[1], a.shape[0]],
                    "coverage": float((encoded[:, :, 3] / 255 >= cutoff).mean()), "alpha_scale": scale})
                if a.shape == (1, 1):
                    break
                size = (max(1, a.shape[1] // 2), max(1, a.shape[0] // 2))
                rgb_premul = np.stack([resize(rgb_premul[:, :, c], size) for c in range(3)], axis=2)
                a = resize(a, size)
                level += 1
            stem = key + ("_coverage" if preserve else "_raw")
            (OUT / (stem + ".rgba")).write_bytes(b"".join(chunks))
            manifest.append({"stem": stem, "source": name, "width": width, "height": height,
                "cutoff": cutoff, "target_coverage": target, "levels": statistics})
    (OUT / "manifest.json").write_text(json.dumps(manifest, indent=2), encoding="utf-8")
    print("FOLIAGE_MIP_CHAINS", len(manifest))

if __name__ == "__main__":
    main()
