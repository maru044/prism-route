"""Build only the saddle GLB; never rewrite base map, planting or grass caches."""
from pathlib import Path
import hashlib, importlib.util, json, shutil, argparse
ROOT=Path(__file__).resolve().parents[1]
CACHE=ROOT/'.current_map_build'
OUT=ROOT/'assets/world/island_saddle_1031'

def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--protected-hashes',default='.current_map_build/saddle_import_1031_before/hashes.json')
    args=parser.parse_args()
    source=json.loads((CACHE/'island_saddle_1031.json').read_text(encoding='utf-8'))
    assert source['cad_unchanged'] and len(source['objects'])>=171
    OUT.mkdir(parents=True,exist_ok=True)
    work=CACHE/'island_saddle_1031_export';work.mkdir(exist_ok=True)
    shutil.copyfile(CACHE/'island_saddle_1031.bin',work/'source.bin')
    spec=importlib.util.spec_from_file_location('saddle_glb',ROOT/'tools/build_landscape_world_mask.py')
    module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
    module.CACHE=work;module.OUT=OUT;module.build_glb(source)
    (OUT/'current_region.glb').replace(OUT/'saddle.glb')
    def world(p):return [p[0]-1450.,p[2],1150.-p[1]]
    route=json.loads((ROOT/'docs/island_saddle_1030/walking_surface_samples.json').read_text(encoding='utf-8'))
    route=[world(p) for p in route]
    skin=next(r for r in source['objects'] if r['name']==source['walking_surface_name'])
    assert skin['watertight'] and skin['collision']
    raw=(work/'source.bin').read_bytes()
    start=skin['offset'];length=skin['vertex_count']*12+skin['index_count']*4
    collision_sha=hashlib.sha256(raw[start:start+length]).hexdigest()
    collision_snapshot=(ROOT/args.protected_hashes).parent/'collision.json'
    if collision_snapshot.exists():
        assert collision_sha==json.loads(collision_snapshot.read_text(encoding='utf-8'))['sha256'],'Original continuous collision geometry changed'
    direction=[route[14][i]-route[15][i] for i in range(3)];direction[1]=0.
    manifest=dict(source,triangles=sum(r['index_count']//3 for r in source['objects']),
        mesh_sha256=hashlib.sha256((OUT/'saddle.glb').read_bytes()).hexdigest(),
        collision_geometry_sha256=collision_sha,
        route=route,spawn=route[15],look_direction=direction,walking_surface_id=skin['id'],
        review_eye=world([1450.,735.,175.]),review_target=world([1260.,480.,68.]))
    (OUT/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    hashes=json.loads((ROOT/args.protected_hashes).read_text(encoding='utf-8'))
    assert all(hashlib.sha256((ROOT/p).read_bytes()).hexdigest()==v for p,v in hashes.items()),'Protected planting/base asset changed'
    print(json.dumps({'objects':len(source['objects']),'triangles':manifest['triangles'],'protected_files_unchanged':len(hashes)}))

if __name__=='__main__':main()
