"""Build only the reviewed sand-bed replacement and a shoreline wetness mask."""
from pathlib import Path
import hashlib,json,re
import numpy as np
from scipy.spatial import cKDTree
from PIL import Image
import build_landscape_world_mask as builder

ROOT=Path(__file__).resolve().parents[1]
CACHE=ROOT/'.current_map_build/beach_slope_1107'
OUT=ROOT/'assets/world/beach_slope_1107'

def main():
    OUT.mkdir(parents=True,exist_ok=True)
    source=json.loads((CACHE/'source.json').read_text(encoding='utf8'))
    builder.CACHE=CACHE;builder.OUT=OUT
    builder.build_glb(source)
    (OUT/'current_region.glb').replace(OUT/'beach.glb')
    xy=np.asarray(source['shoreline_xy']);xz=xy-np.array([1450,1150]);xz[:,1]*=-1
    lo=xz.min(axis=0)-20;size=xz.max(axis=0)+20-lo
    resolution=1024
    zz,xx=np.mgrid[:resolution,:resolution]
    q=np.c_[xx.ravel()+.5,zz.ravel()+.5]/resolution*size+lo
    distance=cKDTree(xz).query(q,workers=2)[0].reshape(resolution,resolution)
    Image.fromarray(np.uint8(np.clip(distance/20,0,1)*255)).save(OUT/'shore_distance.png')
    material=ROOT/'assets/environment/beach_sand/beach_sand.tres'
    text=material.read_text(encoding='utf8')
    for key,value in [('shore_origin',lo),('shore_extent',size)]:
        text,count=re.subn(r'shader_parameter/'+key+r' = Vector2\([^\n]*\)',
            'shader_parameter/'+key+' = Vector2(%.9g, %.9g)'%tuple(value),text)
        assert count==1, 'Missing material mapping parameter: '+key
    material.write_text(text,encoding='utf8')
    manifest={k:v for k,v in source.items() if k!='shoreline_xy'}
    manifest.update(geometry_sha256=hashlib.sha256((OUT/'beach.glb').read_bytes()).hexdigest(),
        shoreline_mask={'origin_xz':lo.tolist(),'extent_xz':size.tolist(),'resolution':resolution,
            'distance_range_m':20,'source_sample_spacing_m':.5},
        base_world_geometry_unchanged=True,grass_plantable_geometry_unchanged=True)
    (OUT/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf8')
    print(json.dumps({'glb_bytes':(OUT/'beach.glb').stat().st_size,'triangles':source['objects'][0]['index_count']//3,'mask_origin':lo.tolist(),'mask_extent':size.tolist()}))

if __name__=='__main__':main()
