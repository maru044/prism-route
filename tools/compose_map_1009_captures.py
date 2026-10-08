"""Assemble the fixed-camera Godot comparison, without modifying the renders."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
CACHE = ROOT / '.map_1009_build/captures'
OUT = ROOT / 'screenshots'


def main():
    OUT.mkdir(exist_ok=True)
    font = ImageFont.truetype('C:/Windows/Fonts/msyh.ttc', 26)
    pairs = [('overview', '全岛形态'), ('relief', '同机位顶面起伏')]
    sheet = Image.new('RGB', (1920, 1280), '#20282b')
    draw = ImageDraw.Draw(sheet)
    for row, (prefix, title) in enumerate(pairs):
        for variant, label in enumerate(['A：Rhino 平滑版', 'B：Blender 起伏版']):
            image = Image.open(CACHE / ('%s_%d.png' % (prefix, variant))).convert('RGB')
            image = image.resize((960, 600), Image.Resampling.LANCZOS)
            x, y = variant * 960, row * 640
            draw.text((x + 18, y + 5), title + ' · ' + label, fill='white', font=font)
            sheet.paste(image, (x, y + 40))
    sheet.save(OUT / 'map_1009_relief_comparison.png')
    Image.open(CACHE / 'drive_1.png').save(OUT / 'map_1009_drive_test.png')
    Image.open(CACHE / 'wheel_contact_1.png').save(OUT / 'map_1009_wheel_contact.png')


if __name__ == '__main__':
    main()
