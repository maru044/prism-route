"""Read-only analysis of controlled GPU captures; does not edit image pixels."""
from pathlib import Path
import hashlib
import json
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'docs/architecture_detail_revision_1029'


def main():
    images = {p.stem: np.array(Image.open(p).convert('RGB')) for p in OUT.glob('*.png') if not p.stem.startswith('map_')}
    failures = []
    coverage = {}
    for name, image in images.items():
        if not name.startswith('plants_'):
            continue
        q = image.astype(np.int16)
        green = (q[:, :, 1] - q[:, :, 0] > 20) & (q[:, :, 1] - q[:, :, 2] > 15)
        coverage[name] = float(green.mean())
    ratio = coverage['plants_new'] / coverage['plants_old']
    if ratio < 3:
        failures.append('Leaf coverage did not substantially increase')
    if coverage['plants_density_zero'] != 0:
        failures.append('Zero density leaves stray blades')
    if coverage['plants_without_loose_blades'] >= coverage['plants_new'] - .002:
        failures.append('Loose blades have no visible contribution')
    if coverage['plants_without_overlap'] >= coverage['plants_new'] - .002:
        failures.append('Overlapping clusters have no visible contribution')
    aspect_equal = np.array_equal(images['plants_aspect_a'], images['plants_aspect_b'])
    if not aspect_equal:
        failures.append('Anisotropic cluster settings squash leaf silhouettes')
    seed_repeat = np.array_equal(images['plants_new'], images['plants_seed_17_again'])
    seed_changes = float((np.abs(images['plants_new'].astype(int) - images['plants_seed_18'].astype(int)).max(axis=2) > 4).mean())
    if not seed_repeat or seed_changes < .02:
        failures.append('Leaf seed is not stable or does not change distribution')

    off_seam_pixels = {}
    for name in ['seams_old_bug', 'seams_fixed']:
        image = images[name]
        height, width = image.shape[:2]
        x = (np.arange(width) + .5) / width * 96. - 48.
        y = 54. - (np.arange(height) + .5) / height * 54.
        xx, yy = np.meshgrid(x, y)
        u = xx * np.cos(.037) + yy * np.sin(.037)
        v = -xx * np.sin(.037) + yy * np.cos(.037)
        true_seam_distance = np.minimum(abs((u + 16) % 32 - 16), abs((v + 9) % 18 - 9))
        background = np.median(image, axis=(0, 1))
        difference = np.abs(image.astype(float) - background).max(axis=2)
        off_seam_pixels[name] = int(((true_seam_distance > .5) & (difference > 3)).sum())
    if off_seam_pixels['seams_old_bug'] < 500 or off_seam_pixels['seams_fixed'] != 0:
        failures.append('Half-panel seam artefact did not reproduce or remains unfixed')

    unchanged_masks = {}
    manifest = json.loads((ROOT / 'assets/world/architecture_details_1029/asset_manifest.json').read_text(encoding='utf-8-sig'))
    for key, filename in [('seam', 'seam_wear_mask_v1.png'), ('plants', 'foliage_leaf_mask_v2.png')]:
        actual = hashlib.sha256((ROOT / 'assets/world/architecture_details_1029' / filename).read_bytes()).hexdigest()
        unchanged_masks[filename] = actual == manifest['sources'][key]['sha256']
    if not all(unchanged_masks.values()):
        failures.append('Approved source masks were edited')
    result = {'passed': not failures, 'failures': failures, 'green_pixel_coverage': coverage, 'coverage_multiplier': ratio,
              'off_seam_dark_pixels': off_seam_pixels, 'aspect_swap_identical': aspect_equal, 'seed_repeat_identical': seed_repeat,
              'seed_change_pixel_fraction': seed_changes, 'approved_masks_unchanged': unchanged_masks,
              'method': 'Actual production fragment functions, unlit orthographic no-UV quad, 1536x864 D3D12 render; read-only image analysis'}
    (OUT / 'shader_checks.json').write_text(json.dumps(result, indent=2), encoding='utf-8')
    print(json.dumps(result))
    return 0 if not failures else 1


if __name__ == '__main__':
    raise SystemExit(main())
