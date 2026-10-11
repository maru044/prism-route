"""Bake the road footprint plus actual terrain height for the 1012 review.

Ground-level roads become terrain colour; suspended roads keep their mesh.
The authored glTF, water, collision and vegetation layout are not rewritten.
"""
from pathlib import Path
import json
import hashlib
import numpy as np
from build_road_projection_test import layers, raster

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets/world/map_1012_test'
CACHE = ROOT / '.map_1012_build'
SOURCE = ROOT.parent / 'map/model_1012.gltf'
RESOLUTION = 4096


def main():
    metadata = json.loads((OUT / 'build_metadata.json').read_text(encoding='utf-8'))
    source_hash = hashlib.sha256(SOURCE.read_bytes()).hexdigest()
    if source_hash != metadata['source_sha256']:
        raise RuntimeError('Rebuild the 1012 geometry first; source has changed')
    groups = layers(json.loads(SOURCE.read_text(encoding='utf-8-sig')))
    terrain, roads = groups['地形'], groups['路面']
    translation = np.array(metadata['model_translation'], dtype=np.float32)
    terrain += translation
    roads += translation
    all_points = np.concatenate([terrain.reshape(-1, 3), roads.reshape(-1, 3)])
    origin = all_points[:, [0, 2]].min(axis=0) - 4
    extent = all_points[:, [0, 2]].max(axis=0) + 4 - origin
    land, _ = raster(terrain, origin, extent, RESOLUTION)
    road, _ = raster(roads, origin, extent, RESOLUTION)
    land_present, road_present = np.isfinite(land), np.isfinite(road)
    gap = road[land_present & road_present] - land[land_present & road_present]
    # Coverage-weighted heights avoid interpolation towards zero at boundaries.
    # Use level zero in the shaders: averaging disconnected stacked layers in
    # mip levels would give a fictitious surface height.
    packed = np.zeros((RESOLUTION, RESOLUTION, 4), dtype='<f2')
    packed[:, :, 0] = road_present
    packed[:, :, 1] = np.where(road_present, road, 0)
    packed[:, :, 2] = np.where(land_present, land, 0)
    packed[:, :, 3] = land_present
    CACHE.mkdir(exist_ok=True)
    packed.tofile(CACHE / 'road_projection.rgba16f')
    report = {'source_sha256': source_hash, 'resolution': RESOLUTION,
              'origin_xz': origin.tolist(), 'extent_xz': extent.tolist(),
              'meters_per_texel': (extent / RESOLUTION).tolist(),
              'ground_road_height_tolerance_m': 2.0,
              'overlap_pixels': len(gap),
              'overlap_within_2cm_pixels': int((np.abs(gap) < .02).sum()),
              'overlap_within_2m_pixels': int((np.abs(gap) < 2).sum()),
              'signed_road_minus_terrain_percentiles_m': np.percentile(gap, [0, 5, 50, 95, 100]).tolist()}
    spawn = np.array(metadata['road_spawn'])
    px = np.floor((spawn[[0, 2]] - origin) / extent * RESOLUTION).astype(int)
    report['spawn_road_minus_terrain_m'] = float(road[px[1], px[0]] - land[px[1], px[0]])
    (OUT / 'road_projection_metadata.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
    print('MAP_1012_ROAD_AUDIT', json.dumps(report), flush=True)


if __name__ == '__main__':
    main()
