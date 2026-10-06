"""Arrange unmodified Godot capture tiles into labelled comparison sheets."""
from pathlib import Path
import shutil
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
CAPTURES = ROOT / ".road_projection_build/captures"
OUT = ROOT / "screenshots"
FONT = ImageFont.truetype(r"C:\Windows\Fonts\msyh.ttc", 24)


def sheet(name, rows):
    width, height = 640, 360
    header = 46
    result = Image.new("RGB", (width * 3, (height + header) * len(rows)), "#1c242c")
    draw = ImageDraw.Draw(result)
    for row, tiles in enumerate(rows):
        for col, (file, title) in enumerate(tiles):
            x, y = col * width, row * (height + header)
            draw.text((x + 12, y + 8), title, font=FONT, fill="white")
            tile = Image.open(CAPTURES / file).convert("RGB").resize((width, height), Image.Resampling.LANCZOS)
            result.paste(tile, (x, y + header))
    result.save(OUT / name)


def main():
    OUT.mkdir(exist_ok=True)
    sheet("road_projection_1006_overview_comparison.png", [[
        ("view_0_mode_1.png", "原实体路面"),
        ("view_0_mode_0.png", "世界投影 · 道路实体为零"),
        ("view_0_mode_3.png", "混合试验 · 保留高差处 52 面"),
    ]])
    sheet("road_projection_1006_detail_comparison.png", [
        [(f"view_{view}_mode_1.png", f"{title} · 实体"),
         (f"view_{view}_mode_0.png", f"{title} · 投影（4 m）"),
         (f"view_{view}_mode_3.png", f"{title} · 混合（2 m）")]
        for view, title in [(1, "贴地道路"), (2, "坡道"), (3, "高差路段")]
    ])
    sheet("road_projection_1006_height_guard.png", [[
        ("view_3_tolerance_2.png", "2 m 高度保护 · 高差处断开"),
        ("view_3_mode_0.png", "4 m 高度保护 · 沿地形绘制"),
        ("view_3_mode_2.png", "无高度保护 · 仅 XZ 足迹"),
    ]])
    shutil.copy2(CAPTURES / "view_0_mode_0.png", OUT / "road_projection_1006_overview.png")
    print("ROAD_SHEETS_READY 4 images (Godot captures only)")


if __name__ == "__main__":
    main()
