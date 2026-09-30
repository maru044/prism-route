"""Summarize the actual rendered diagnostic captures, not generated scenery."""
from pathlib import Path
import json
import numpy as np
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / ".vegetation_art_build/simplification"
OUT = ROOT / "screenshots"
MODES = ["baseline", "no_ssao", "no_sun_shadow", "no_angle_fade", "mip_raw", "mip_coverage", "shader_only", "candidate"]
def main():
    statistics = {}
    # Fixed near-view interior ROI: no silhouette, HUD, trunk or background.
    roi = (820, 540, 1080, 710)
    baseline = np.asarray(Image.open(SOURCE / "near_baseline.png").convert("RGB").crop(roi), dtype=np.float32)
    for mode in MODES:
        pixels = np.asarray(Image.open(SOURCE / f"near_{mode}.png").convert("RGB").crop(roi), dtype=np.float32)
        luma = pixels @ np.array([.299, .587, .114])
        statistics[mode] = {
            "roi": list(roi),
            "mean_absolute_rgb_change": float(np.abs(pixels - baseline).mean()),
            "adjacent_luma_difference": float((np.abs(np.diff(luma, axis=0)).mean() + np.abs(np.diff(luma, axis=1)).mean()) * .5),
            "mean_luma": float(luma.mean()),
        }
    (OUT / "foliage_filtering_diagnostics.json").write_text(json.dumps(statistics, indent=2), encoding="utf-8")
    sheet = Image.new("RGB", (1600, 1040), (32, 34, 37))
    draw = ImageDraw.Draw(sheet)
    font = ImageFont.truetype("C:/Windows/Fonts/arial.ttf", 25)
    for col, mode in enumerate(["baseline", "candidate"]):
        draw.text((col*800+24, 10), "Original" if col == 0 else "Filtered - same original tree", font=font, fill=(240,240,235))
        image = Image.open(SOURCE / f"near_{mode}.png").convert("RGB").crop((430,210,1450,1030)).resize((800,643), Image.Resampling.LANCZOS)
        sheet.paste(image, (col*800, 50))
        image = Image.open(SOURCE / f"player_{mode}.png").convert("RGB").crop((680,330,1230,800)).resize((400,342), Image.Resampling.LANCZOS)
        sheet.paste(image, (col*800+200, 697))
    sheet.save(OUT / "foliage_filtering_small_tree_comparison.png")
    print(json.dumps(statistics, indent=2))

if __name__ == "__main__":
    main()
