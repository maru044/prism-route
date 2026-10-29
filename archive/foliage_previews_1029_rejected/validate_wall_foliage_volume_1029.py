"""Read-only checks of texture-color and GPU parallax comparison renders."""
from pathlib import Path
from PIL import Image
import json
import numpy as np

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'docs/wall_foliage_volume_1029'


def read(name):
    return np.array(Image.open(OUT / (name + '.png')).convert('RGB')).astype(np.int16)


def main():
    report = {}
    failures = []
    for side in ['left', 'front', 'right']:
        row = {}
        for mode in ['off', 'on']:
            image = read(f'single_{side}_{mode}')
            mask = (image[:, :, 1] - image[:, :, 0] > 12) & (image[:, :, 1] - image[:, :, 2] > 4)
            y, x = np.where(mask)
            row[mode] = {'center_x_px': float(x.mean()), 'center_y_px': float(y.mean()),
                         'width_px': int(x.max() - x.min() + 1), 'height_px': int(y.max() - y.min() + 1), 'area': int(mask.sum())}
        row['shift_x_px'] = row['on']['center_x_px'] - row['off']['center_x_px']
        if abs(row['on']['width_px'] - row['off']['width_px']) > 1 or abs(row['on']['height_px'] - row['off']['height_px']) > 1:
            failures.append('Parallax deforms blade silhouette in view ' + side)
        report[side] = row
    if not (report['left']['shift_x_px'] > 10 and report['right']['shift_x_px'] < -10 and abs(report['front']['shift_x_px']) < .5):
        failures.append('Parallax direction or front-view anchoring is incorrect')
    for a, b, threshold in [('textured_close', 'flat_color_close', .2), ('textured_oblique', 'oblique_without_parallax', .01)]:
        fraction = float((np.abs(read(a) - read(b)).max(axis=2) > 4).mean())
        report[a + '_vs_' + b] = {'different_pixel_fraction': fraction}
        if fraction < threshold:
            failures.append('Rendered comparison has no significant effect: ' + a)
    report['passed'] = not failures
    report['failures'] = failures
    (OUT / 'pixel_check.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
    print(json.dumps(report))
    return 0 if not failures else 1


if __name__ == '__main__':
    raise SystemExit(main())
