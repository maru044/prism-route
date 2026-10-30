"""Package the read-only CAD feature; retain the main map and fixed tree layout."""
from pathlib import Path
import importlib.util,json,hashlib,math,shutil
import numpy as np
ROOT=Path(__file__).resolve().parents[1]
CACHE=ROOT/'.current_map_build'
OUT=ROOT/'assets/world/upper_ring_1030'
BASE=ROOT/'assets/world/current_map_validation'

def main():
    OUT.mkdir(parents=True,exist_ok=True)
    src=json.loads((CACHE/'upper_ring_1030.json').read_text(encoding='utf-8'))
    assert src['cad_unchanged'] and len(src['objects'])==539
    work=CACHE/'upper_ring_1030_export';work.mkdir(exist_ok=True)
    shutil.copyfile(CACHE/'upper_ring_1030.bin',work/'source.bin')
    spec=importlib.util.spec_from_file_location('feature_glb',ROOT/'tools/build_landscape_world_mask.py')
    mod=importlib.util.module_from_spec(spec);spec.loader.exec_module(mod)
    mod.CACHE=work;mod.OUT=OUT;mod.build_glb(src)
    (OUT/'current_region.glb').replace(OUT/'pavilion.glb')
    raw=(work/'source.bin').read_bytes()
    terrain=next(r for r in src['objects'] if r['category']=='terrain')
    p=np.frombuffer(raw,'<f4',count=terrain['vertex_count']*3,offset=terrain['offset']).reshape(-1,3)
    tri=np.frombuffer(raw,'<u4',count=terrain['index_count'],offset=terrain['offset']+terrain['vertex_count']*12).reshape(-1,3)
    width,height,step=179,143,2.5;origin=[255.,5.]
    heights=[None]*(width*height);diagonals=[-1]*((width-1)*(height-1))
    ij=np.rint((p[:,:2]-origin)/step).astype(int)
    for (i,j),v in zip(ij,p):heights[int(j)*width+int(i)]=float(v[2])
    for face in tri:
        points=[tuple(q) for q in ij[face]];i=min(q[0] for q in points);j=min(q[1] for q in points)
        diagonals[int(j)*(width-1)+int(i)]=0 if (i,j) in points and (i+1,j+1) in points else 1
    field={'origin_cad':origin,'step':step,'width':width,'height':height,'heights':heights,'diagonals':diagonals}
    (OUT/'height_field.json').write_text(json.dumps(field,separators=(',',':'))+'\n',encoding='utf-8')
    theta=math.atan2(-368.44157405747984-115,651.1922449843955-510)
    def cad(r,a,z):
        t=theta+math.radians(a);return [510+r*math.cos(t),115+r*math.sin(t),z]
    def godot(p):return [p[0]-1450,p[2],1150-p[1]]
    beds=[]
    for a,b,lo,hi in [(26,88,8,20),(101,151,13,23),(207,259,9,22)]:
        angles=np.linspace(a,b,25)
        polygon=[cad(hi*1.4,float(t),70.45) for t in angles]+[cad(lo*1.4,float(t),70.45) for t in angles[::-1]]
        beds.append([[q[0]-1450,1150-q[1]] for q in polygon])
    trees=[]
    for name,model,scale,r,a,bed,yaw in [('HeroBroad',1,1.5,12*1.4,57,0,.35),('CompanionA',0,.85,18*1.4,124,1,1.2),('CompanionB',0,.8,15*1.4,220,2,2.1),('CompanionC',0,.9,18*1.4,249,2,.6)]:
        trees.append({'name':name,'model':model,'scale':scale,'position':godot(cad(r,a,70.45)),'yaw':yaw,'bed':bed})
    paths=json.loads((ROOT/'docs/upper_ring_pavilion_1030/walking_routes.json').read_text(encoding='utf-8'))
    paths={k:[godot(q) for q in v] for k,v in paths.items()}
    manifest={'source':src['source'],'cad_unchanged':True,'objects':src['objects'],
        'triangles':sum(r['index_count']//3 for r in src['objects']),
        'mesh_sha256':hashlib.sha256((OUT/'pavilion.glb').read_bytes()).hexdigest(),
        'center':[-940,70.08,1035],'outer_radius':72.8,'courtyard_radius':37.8,
        'front':[math.cos(theta),0,-math.sin(theta)],
        'spawn':godot(cad(57*1.4,0,70.2)),
        'terrain_bounds':[[float(p[:,0].min()-1450),float(1150-p[:,1].max())],[float(p[:,0].max()-1450),float(1150-p[:,1].min())]],
        'trees':trees,'planting_beds':beds,'routes':paths,
        'probes':[dict(r,samples=[godot(q) for q in r['samples']]) for r in src['probes']]}
    (OUT/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    metadata=json.loads((BASE/'metadata.json').read_text(encoding='utf-8'))
    metadata.setdefault('static_features',{})['upper_ring_1030']={'manifest':'res://assets/world/upper_ring_1030/manifest.json','mesh_sha256':manifest['mesh_sha256'],'manifest_sha256':hashlib.sha256((OUT/'manifest.json').read_bytes()).hexdigest(),'height_field_sha256':hashlib.sha256((OUT/'height_field.json').read_bytes()).hexdigest(),'objects':539,'triangles':manifest['triangles']}
    (BASE/'metadata.json').write_text(json.dumps(metadata,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    # Register only terrain cells; architectural roofs are intentionally not turf.
    index=json.loads((BASE/'grass_cells.json').read_text(encoding='utf-8'))
    cells=set(tuple(q) for q in index['cells']);original=len(cells)
    world=p[:,[0,2,1]].copy();world[:,0]-=1450;world[:,2]=1150-world[:,2]
    for face in tri:
        lo=np.floor((world[face].min(axis=0)-.01)/24).astype(int);hi=np.floor((world[face].max(axis=0)+.01)/24).astype(int)
        for x in range(lo[0],hi[0]+1):
            for y in range(lo[1],hi[1]+1):
                for z in range(lo[2],hi[2]+1):cells.add((x,y,z))
    index['cells']=[list(q) for q in sorted(cells)]
    (BASE/'grass_cells.json').write_text(json.dumps(index,separators=(',',':'))+'\n',encoding='utf-8')
    assert metadata['mesh_sha256']==hashlib.sha256((BASE/'current_region.glb').read_bytes()).hexdigest()
    print(json.dumps({'objects':539,'triangles':manifest['triangles'],'new_terrain_cells':len(cells)-original,'hero_tree':trees[0],'base_mesh_unchanged':True}))

if __name__=='__main__':main()
