"""Build the unchanged current CAD map and reuse its eight-stroke SDF mask."""
from pathlib import Path
import importlib.util,json,hashlib
import numpy as np
import map_1021_surface_roles as surface_roles
import build_map_1021_grass_cells as grass_cells
from current_map_mesh_repairs import ExportRepairs
ROOT=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('mask',ROOT/'tools/build_landscape_world_mask.py')
m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
m.CACHE=ROOT/'.current_map_build';m.OUT=ROOT/'assets/world/current_map_validation'

def main():
    m.OUT.mkdir(parents=True,exist_ok=True)
    source=json.loads((m.CACHE/'source.json').read_text(encoding='utf-8-sig'))
    surface_roles.apply(source['objects'])
    (m.CACHE/'source.json').write_text(json.dumps(source,ensure_ascii=False,indent=2),encoding='utf-8')
    repairs=ExportRepairs(source,(m.CACHE/'source.bin').read_bytes())
    terrain=m.build_glb(source,repairs.mask)
    repairs.write_report(m.OUT/'review/mesh_repairs.json')
    print('FULL_MAP_GLB_READY',flush=True)
    meta,sdf,height=m.build_mask(source,4096);print('FULL_MAP_MASK_READY',flush=True)
    center=np.asarray(source['native_center'],float)
    def godot(p):
        q=np.asarray(p,float)-center
        return [float(q[0]),float(q[2]),float(-q[1])]
    objects={r['id']:dict(r,index_count=r.get('export_index_count',r['index_count']),source_index_count=r['index_count']) for r in source['objects']}
    proposals=[
      {'name':'南部上层 · 屋顶花园','key':'south_roof','native':[1035,240,63],'direction':[1,0,0]},
      {'name':'南部上层 · 环塔主桥','key':'south_bridge','native':[1276.7261,-50.302,60.14184],'direction':[1,0,0]},
      {'name':'南部中层 · 开放隧道','key':'south_gallery','native':[550,16.8,35.25],'direction':[1,-0.12,0],'required_floor_kind':'Road','minimum_edge_clearance_m':3.5},
      {'name':'南部中层 · 台地道路','key':'south_middle','native':[1195.7728,500.7555,35.0],'direction':[1,0.3,0]},
      {'name':'南部底层 · 临水平台','key':'south_waterfront','native':[1277,256,1.6],'direction':[0,-1,0]},
      {'name':'北部 · 山坡草地','key':'north_hill','native':[1700,1180,40],'direction':[-1,-1,0],'highest':True},
      {'name':'北部底层 · 泻湖草岸','key':'north_lagoon','native':[1400,1700,2],'direction':[-1,-1,0],'highest':True},
      {'name':'中北部 · 下行坡道','key':'north_ramp','native':[1093.101,727.697,20.4685],'direction':[.7,1,0]},
      {'name':'南部 · 初始洞穴','key':'spawn_cave','native':[639.5260806328593,-377.870286022694,33.0],'direction':[.7777442901023691,.6285807976809043,0],'required_floor_kind':'Structure','required_source_id':'f03d5707-4703-58a3-9c33-96106ea052be','maximum_search_distance_m':2.0,'character_only':True}
    ]
    for r in proposals:
        r['position']=godot(r['native'])
        d=r.pop('direction');r['look_direction']=[d[0],d[2],-d[1]]
    bounds=np.asarray([r['bounds']for r in source['objects']if r['kind']not in ['Water']],float)
    low=bounds[:,0].min(axis=0);high=bounds[:,1].max(axis=0)
    meta.update(source_document=source['source'],native_center=source['native_center'],objects=len(objects),
      triangles=sum(r['index_count']//3 for r in objects.values()),cad_object_count=source['cad_object_count'],
      cad_geometry_and_attributes_unchanged=source['all_cad_geometry_and_attributes_unchanged'],
      object_records=list(objects.values()),spawns=proposals,default_spawn_key='spawn_cave',
      native_bounds=[low.tolist(),high.tolist()],world_bounds=[godot(low),godot(high)],
      mesh_tolerance_m=.04,subd_export_level=2,mesh_sha256=hashlib.sha256((m.OUT/'current_region.glb').read_bytes()).hexdigest(),
      validation=m.validate_coverage(terrain,meta,sdf,height))
    (m.OUT/'metadata.json').write_text(json.dumps(meta,ensure_ascii=False,indent=2),encoding='utf-8')
    (m.OUT/'cad_layout.json').write_text(json.dumps(source['curves'],ensure_ascii=False),encoding='utf-8')
    grass_cells.main()
    print(json.dumps({k:meta[k]for k in ['objects','triangles','cad_geometry_and_attributes_unchanged','meters_per_texel','validation']},indent=2),flush=True)

if __name__=='__main__':main()
