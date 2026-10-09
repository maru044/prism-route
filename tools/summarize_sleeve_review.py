"""Label rendered comparisons and check that sleeve edits preserve humanoid rest."""
import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont, ImageOps

ROOT = Path(__file__).resolve().parents[1]
BUILD = ROOT / '.model_import_build'


def main():
    font = ImageFont.truetype('C:/Windows/Fonts/msyh.ttc', 22)
    validation = json.loads((BUILD / 'sleeves_validation.json').read_text(encoding='utf8'))
    assert not validation['failures']
    rest_checks = []
    for model in ['keqing', 'huahuo']:
        old_path = BUILD / ('huahuo/huahuo_rest.json' if model == 'huahuo' else 'keqing_rest.json')
        old = json.loads(old_path.read_text(encoding='utf8'))
        new = json.loads((BUILD / f'{model}_sleeve_rest.json').read_text(encoding='utf8'))
        assert old['path'] == new['path']
        old_bones = {bone['name']: bone for bone in old['bones']}
        new_bones = {bone['name']: bone for bone in new['bones']}
        assert old_bones.keys() == new_bones.keys()
        def parent_name(data, bone):
            return data['bones'][bone['parent']]['name'] if bone['parent'] >= 0 else None
        changed = []
        for name, bone in old_bones.items():
            other = new_bones[name]
            if parent_name(old, bone) != parent_name(new, other) or any(
                    abs(a-b) > 1e-6 for field in ['position', 'rotation', 'scale']
                    for a, b in zip(bone[field], other[field])):
                changed.append(name)
        assert all(name.startswith(('yxx__', 'zxx_')) for name in changed), changed
        rest_checks.append({'model': model, 'bones': len(new_bones),
                            'changed_local_rest_bones': changed,
                            'humanoid_rest_and_animation_paths_unchanged': True})
        frames = []
        for i in range(40):
            left = Image.open(BUILD / f'sleeve_frames/{model}_off_{i:02d}.png').convert('RGB')
            right = Image.open(BUILD / f'sleeve_frames/{model}_on_{i:02d}.png').convert('RGB')
            frame = Image.new('RGB', (left.width + right.width, left.height + 45), '#202b36')
            frame.paste(left, (0, 45))
            frame.paste(right, (left.width, 45))
            draw = ImageDraw.Draw(frame)
            label = '刻晴' if model == 'keqing' else '花火'
            draw.text((14, 10), label + ' · 袖尾物理关闭', font=font, fill='white')
            draw.text((left.width + 14, 10), label + ' · 袖尾物理开启', font=font, fill='white')
            frames.append(frame)
        frames[0].save(BUILD / f'{model}_sleeves_walk.gif', save_all=True,
                       append_images=frames[1:], duration=67, loop=0)
    comparison = Image.new('RGB', (1800, 1510), '#202b36')
    draw = ImageDraw.Draw(comparison)
    for column, text in enumerate(['刻晴 · 物理关闭', '刻晴 · 物理开启', '花火 · 物理关闭', '花火 · 物理开启']):
        draw.text((column * 450 + 20, 12), text, font=font, fill='white')
    for row, (motion, label) in enumerate([('A01', '放松站立'), ('A05', '女性步行'), ('A30', '坐姿')]):
        for column, (model, mode) in enumerate([('keqing', 'rigid'), ('keqing', 'dynamic'), ('huahuo', 'rigid'), ('huahuo', 'dynamic')]):
            picture = Image.open(BUILD / f'{model}_{motion}_sleeves_{mode}.png').convert('RGB')
            tile = ImageOps.pad(picture.crop((550, 90, 1170, picture.height)), (450, 450), color='#202b36')
            comparison.paste(tile, (column * 450, 65 + row * 480))
            draw.text((column * 450 + 12, 48 + row * 480), motion + ' · ' + label, font=font, fill='white')
    comparison.save(BUILD / 'sleeves_comparison_labeled.png')
    validation['rest_regression'] = rest_checks
    validation['date'] = '2026-10-09'
    (ROOT / 'docs/MMD_VRM_SLEEVE_TEST_REPORT.json').write_text(
        json.dumps(validation, ensure_ascii=False, indent=2) + '\n', encoding='utf8')
    print(json.dumps(rest_checks, ensure_ascii=False))


if __name__ == '__main__':
    main()
