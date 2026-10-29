"""Package the read-only CAD delta as a separate, world-aligned static feature."""
from pathlib import Path
import hashlib, importlib.util, json, shutil
import numpy as np
from scipy.spatial import ConvexHull

ROOT=Path(__file__).resolve().parents[1]
CACHE=ROOT/'.current_map_build'
OUT=ROOT/'assets/world/initial_ruin_1029'
BASE=ROOT/'assets/world/current_map_validation'

def main():
    OUT.mkdir(parents=True,exist_ok=True)
    source=json.loads((CACHE/'initial_ruin_1029.json').read_text(encoding='utf-8-sig'))
    assert source['cad_unchanged'] and len(source['objects'])==328
    work=CACHE/'initial_ruin_1029_export';work.mkdir(exist_ok=True)
    shutil.copyfile(CACHE/'initial_ruin_1029.bin',work/'source.bin')
    spec=importlib.util.spec_from_file_location('ruin_glb',ROOT/'tools/build_landscape_world_mask.py')
    module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
    module.CACHE=work;module.OUT=OUT
    module.build_glb(source)
    (OUT/'current_region.glb').replace(OUT/'ruin.glb')
    center=np.array(source['native_center'],dtype=np.float32)
    def godot(p):
        q=np.array(p,dtype=np.float32)-center
        return [float(q[0]),float(q[2]),float(-q[1])]
    raw=(work/'source.bin').read_bytes()
    exclusions=[]
    for row in source['objects']:
        if row['category'] not in ['foundation','entry']:continue
        p=np.frombuffer(raw,'<f4',count=row['vertex_count']*3,offset=row['offset']).reshape(-1,3)
        xy=np.unique(p[:,:2],axis=0)
        if len(xy)<3:continue
        polygon=xy[ConvexHull(xy).vertices]
        points=[[float(x-center[0]),float(center[1]-y)] for x,y in polygon]
        arr=np.array(points)
        exclusions.append({'id':row['id'],'polygon':points,'bounds':[arr.min(0).tolist(),arr.max(0).tolist()],
                           'height':[float(p[:,2].min())-.8,float(p[:,2].max())+.8]})
    feature={
        'source_document':source['source'],'cad_unchanged':True,'native_center':source['native_center'],
        'objects':source['objects'],'triangles':sum(r['index_count']//3 for r in source['objects']),
        'mesh_sha256':hashlib.sha256((OUT/'ruin.glb').read_bytes()).hexdigest(),
        'summon_anchor':godot(source['summon_anchor']),
        'forward':[float(source['placement']['long_axis'][0]),0.,float(-source['placement']['long_axis'][1])],
        'spawn':godot([source['placement']['front_center'][0]+source['placement']['long_axis'][0]*18,
                       source['placement']['front_center'][1]+source['placement']['long_axis'][1]*18,61.05]),
        'exclusions':exclusions,
        'probes':[dict(row,samples=[godot(p) for p in row['samples']]) for row in source['probes']],
        'placement':source['placement'],
    }
    (OUT/'manifest.json').write_text(json.dumps(feature,ensure_ascii=False,indent=2),encoding='utf-8')
    olddir=CACHE/'initial_ruin_1029_before';olddir.mkdir(exist_ok=True)
    for name in ['metadata.json','tree_layout.json','tree_layout_metadata.json','grass_bake/manifest.json']:
        dst=olddir/name;dst.parent.mkdir(parents=True,exist_ok=True)
        if not dst.exists():shutil.copyfile(BASE/name,dst)
    metadata=json.loads((BASE/'metadata.json').read_text(encoding='utf-8-sig'))
    metadata.setdefault('static_features',{})['initial_ruin_1029']={
        'manifest':'res://assets/world/initial_ruin_1029/manifest.json',
        'mesh_sha256':feature['mesh_sha256'],
        'manifest_sha256':hashlib.sha256((OUT/'manifest.json').read_bytes()).hexdigest(),
        'objects':328,'triangles':feature['triangles']}
    (BASE/'metadata.json').write_text(json.dumps(metadata,ensure_ascii=False,indent=2),encoding='utf-8')
    assert metadata['mesh_sha256']==hashlib.sha256((BASE/'current_region.glb').read_bytes()).hexdigest()
    print(json.dumps({'objects':328,'triangles':feature['triangles'],'exclusion_polygons':len(exclusions),
                      'summon_anchor':feature['summon_anchor'],'base_mesh_unchanged':True}))

if __name__=='__main__':main()
