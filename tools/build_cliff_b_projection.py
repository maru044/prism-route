"""Bake current exported geometry roads, in the B scene's local coordinate frame."""
from pathlib import Path
import json
import numpy as np
from build_road_projection_test import raster

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets/world/cliff_b_test'
CACHE = ROOT / '.cliff_b_build'
RESOLUTION = 2048

def main():
    data = json.loads((OUT/'source/rhino_scene.json').read_text(encoding='utf-8'))
    metadata = json.loads((OUT/'build_metadata.json').read_text(encoding='utf-8'))
    center = np.array(metadata['native_center'],dtype=np.float32)
    groups = {'Terrain':[], 'Roads':[]}
    for obj in data['objects']:
        if obj['kind'] not in groups:
            continue
        vertices = np.array(obj['vertices'],dtype=np.float32)-center
        converted = vertices[:,[0,2,1]].copy()
        converted[:,2] *= -1
        groups[obj['kind']].append(converted[np.array(obj['triangles'])])
    terrain,roads = [np.concatenate(groups[key]) for key in ['Terrain','Roads']]
    coords = np.concatenate([terrain.reshape(-1,3),roads.reshape(-1,3)])
    origin = coords[:,[0,2]].min(axis=0)-4
    extent = coords[:,[0,2]].max(axis=0)+4-origin
    land,_ = raster(terrain,origin,extent,RESOLUTION)
    road,_ = raster(roads,origin,extent,RESOLUTION)
    lp,rp = np.isfinite(land),np.isfinite(road)
    packed = np.zeros((RESOLUTION,RESOLUTION,4),dtype='<f2')
    packed[:,:,0] = rp
    packed[:,:,1] = np.where(rp,road,0)
    packed[:,:,2] = np.where(lp,land,0)
    packed[:,:,3] = lp
    packed.tofile(CACHE/'road_projection.rgba16f')
    report = {'resolution':RESOLUTION,'origin_xz':origin.tolist(),'extent_xz':extent.tolist(),
        'ground_road_height_tolerance_m':2.0,'source_native_sha256':metadata['source_native_sha256']}
    (OUT/'road_projection_metadata.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
    print('B_ROAD_PROJECTION',report)

if __name__ == '__main__':
    main()
