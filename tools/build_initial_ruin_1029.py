"""Package the read-only CAD delta as a separate, world-aligned static feature."""
from pathlib import Path
import hashlib, importlib.util, json, shutil, struct
import numpy as np

ROOT=Path(__file__).resolve().parents[1]
CACHE=ROOT/'.current_map_build'
OUT=ROOT/'assets/world/initial_ruin_1029'
BASE=ROOT/'assets/world/current_map_validation'

def geometry_streams(raw):
    size=struct.unpack_from('<I',raw,12)[0];doc=json.loads(raw[20:20+size]);blob=raw[28+size:]
    def array(index):
        accessor=doc['accessors'][index];view=doc['bufferViews'][accessor['bufferView']]
        offset=view.get('byteOffset',0)
        return blob[offset:offset+view['byteLength']]
    result={}
    for node in doc['nodes']:
        primitive=doc['meshes'][node['mesh']]['primitives'][0]
        result[node['extras']['source_id']]=hashlib.sha256(array(primitive['attributes']['POSITION'])+array(primitive['indices'])).hexdigest()
    return result

def main():
    OUT.mkdir(parents=True,exist_ok=True)
    source=json.loads((CACHE/'initial_ruin_1029.json').read_text(encoding='utf-8-sig'))
    assert source['cad_unchanged'] and source.get('interactions',{}).get('version')==1
    previous=json.loads((OUT/'manifest.json').read_text(encoding='utf-8-sig'))
    previous_streams=geometry_streams((OUT/'ruin.glb').read_bytes())
    metadata=json.loads((BASE/'metadata.json').read_text(encoding='utf-8-sig'))
    previous_feature=metadata['static_features']['initial_ruin_1029'].copy()
    previous_override=metadata.get('grass_render_only_overrides',{}).get('initial_ruin_1029',{})
    generation_feature=previous_override.get('generation_feature',previous_feature)
    work=CACHE/'initial_ruin_1029_export';work.mkdir(exist_ok=True)
    shutil.copyfile(CACHE/'initial_ruin_1029.bin',work/'source.bin')
    spec=importlib.util.spec_from_file_location('ruin_glb',ROOT/'tools/build_landscape_world_mask.py')
    module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
    module.CACHE=work;module.OUT=work
    module.build_glb(source)
    old_by_id={r['id']:r for r in previous['objects']}
    current_streams=geometry_streams((work/'current_region.glb').read_bytes())
    retained_keys={k for k in previous_streams.keys() & current_streams.keys() if old_by_id.get(k,{}).get('category')!='furniture'}
    assert all(previous_streams[k]==current_streams[k] for k in retained_keys), 'Retained architecture changed; planting equivalence must be reevaluated'
    shutil.copyfile(work/'current_region.glb',OUT/'ruin.glb')
    center=np.array(source['native_center'],dtype=np.float32)
    def godot(p):
        q=np.array(p,dtype=np.float32)-center
        return [float(q[0]),float(q[2]),float(-q[1])]
    # The accepted foundation/entry footprints also cover the user's deleted
    # redundant landing bases. Preserve this unchanged planting contract.
    exclusions=previous['exclusions']
    current_by_id={r['id']:r for r in source['objects']}
    removed=[r for r in previous['objects'] if r['id'] not in current_by_id]
    assert all(r['category'] in ('dais','furniture') for r in removed)
    for row in source['objects']:
        if row['id'] in old_by_id and row['category']!='furniture':
            old=old_by_id[row['id']]
            assert row['category']==old['category'] and np.allclose(row['bounds'],old['bounds'],atol=.0001)
        else:
            assert row['category']=='furniture' and row['bounds'][0][2]>=61.049
    interactions=source['interactions']
    for item in interactions['furniture']+[interactions['npc_idle']]:
        item['position']=godot(item.pop('root_position_cad'))
        direction=item.pop('forward_cad');item['forward']=[direction[0],direction[2],-direction[1]]
        for anchor in item['anchors']:
            anchor['position']=godot(anchor.pop('position_cad'))
            direction=anchor.pop('forward_cad');anchor['forward']=[direction[0],direction[2],-direction[1]]
    feature={
        'source_document':source['source'],'cad_unchanged':True,'native_center':source['native_center'],
        'objects':source['objects'],'triangles':sum(r['index_count']//3 for r in source['objects']),
        'mesh_sha256':hashlib.sha256((OUT/'ruin.glb').read_bytes()).hexdigest(),
        'interactions':interactions,
        'forward':[float(source['placement']['long_axis'][0]),0.,float(-source['placement']['long_axis'][1])],
        'spawn':godot([source['placement']['front_center'][0]+source['placement']['long_axis'][0]*18,
                       source['placement']['front_center'][1]+source['placement']['long_axis'][1]*18,61.05]),
        'exclusions':exclusions,
        'probes':[dict(row,samples=[godot(p) for p in row['samples']]) for row in source['probes']],
        'placement':source['placement'],
    }
    (OUT/'manifest.json').write_text(json.dumps(feature,ensure_ascii=False,indent=2),encoding='utf-8')
    metadata.setdefault('static_features',{})['initial_ruin_1029']={
        'manifest':'res://assets/world/initial_ruin_1029/manifest.json',
        'mesh_sha256':feature['mesh_sha256'],
        'manifest_sha256':hashlib.sha256((OUT/'manifest.json').read_bytes()).hexdigest(),
        'objects':len(source['objects']),'triangles':feature['triangles']}
    # Furniture and the removed devices sit on the retained non-plantable
    # hall floor. Terrain, foundation/entry masks and their collision stay put.
    # This exact-revision rule expires automatically on any subsequent edit.
    metadata.setdefault('grass_render_only_overrides',{})['initial_ruin_1029']={
        'render_mesh_sha256':feature['mesh_sha256'],
        'render_manifest_sha256':hashlib.sha256((OUT/'manifest.json').read_bytes()).hexdigest(),
        'generation_feature':generation_feature,
        'reason':'NPC/furniture revision on unchanged sealed temple floor; original terrain and planting exclusion volumes retained.'}
    (BASE/'metadata.json').write_text(json.dumps(metadata,ensure_ascii=False,indent=2),encoding='utf-8')
    assert metadata['mesh_sha256']==hashlib.sha256((BASE/'current_region.glb').read_bytes()).hexdigest()
    print(json.dumps({'objects':len(source['objects']),'triangles':feature['triangles'],'exclusion_polygons':len(exclusions),
                      'furniture':len(interactions['furniture']),'base_mesh_unchanged':True}))

if __name__=='__main__':main()
