"""Derive collision-only geometry from the saved CAD stair stations; package Rhino readback."""
from pathlib import Path
import argparse, hashlib, importlib.util, json, math, struct
import numpy as np
from scipy.interpolate import PchipInterpolator
ROOT=Path(__file__).resolve().parents[1]
CAD=ROOT.parent/'plans/architecture_concepts_1028/rhino_model_1029'
CACHE=ROOT/'.current_map_build'
OUT=ROOT/'assets/world/initial_ruin_1029'
RECIPE=CAD/'walk_collision_recipe.json'

def read(p):return json.loads(p.read_text(encoding='utf-8-sig'))
def write(p,d):p.write_text(json.dumps(d,ensure_ascii=False,indent=2),encoding='utf-8')
def make_recipe():
    state=read(CAD/'build_state.json');source=read(CACHE/'initial_ruin_1029.json');plan=state['placement'];approach=state['checks']['approach']
    assert len(state['objects'])==328
    by_name={o['name']:o for o in source['objects']}
    center=np.array(plan['front_center']);right=np.array(plan['right_axis']);forward=np.array(plan['long_axis'])
    def world(u,v,z):
        p=center+right*u+forward*v
        return [float(p[0]),float(p[1]),float(z)]
    def width(v):return 15.-v*.25
    nodes=np.array(approach['curve_nodes'],float);rounded=[nodes[0]]
    def line_to(end):
        start=rounded[-1];count=max(1,math.ceil(np.linalg.norm(end-start)/.75))
        rounded.extend(start+(end-start)*(i/count) for i in range(1,count+1))
    for i in range(1,len(nodes)-1):
        a=nodes[i]-nodes[i-1];b=nodes[i+1]-nodes[i];trim=min(5.,np.linalg.norm(a)*.25,np.linalg.norm(b)*.25)
        a=nodes[i]-a/np.linalg.norm(a)*trim;b=nodes[i]+b/np.linalg.norm(b)*trim
        line_to(a)
        for j in range(1,21):
            t=j/20.;rounded.append(a*(1-t)**2+nodes[i]*(2*t*(1-t))+b*t*t)
    line_to(nodes[-1]);rounded=np.array(rounded);segments=np.diff(rounded,axis=0);dist=np.linalg.norm(segments,axis=1);arc=np.r_[0.,np.cumsum(dist)];length=arc[-1]
    assert abs(length-approach['length_m'])<1e-7
    def frame(d):
        i=min(len(dist)-1,max(0,int(np.searchsorted(arc,d,side='right')-1)))
        tangent=segments[i]/dist[i];p=rounded[i]+tangent*(d-arc[i]);return p,np.array([tangent[1],-tangent[0]])
    stations=approach['step_stations'];z0=approach['start_z'];riser=approach['riser_m'];knots=[(0.,z0)]
    for i,s in enumerate(stations):
        if i%18==0:
            # Preserve a horizontal rest section before the next flight, using
            # one tread's run to meet its first visible nosing continuously.
            lead=min(.37,(s-(stations[i-1] if i else 0.))*.5)
            knots.append((s-lead,z0+i*riser))
        knots.append((s,z0+(i+1)*riser))
    knots.append((length,approach['end_z']));profile=PchipInterpolator(*np.array(knots).T)
    intervals=[(0.,stations[0],z0)]+[(s,stations[i+1] if i+1<len(stations) else length,z0+(i+1)*riser) for i,s in enumerate(stations)]
    bottoms=[]
    for j,(a,b,z) in enumerate(intervals):
        count=max(1,math.ceil((b-a)/3.))
        for n in range(count):bottoms.append((a+(b-a)*n/count,a+(b-a)*(n+1)/count,by_name['PR_Approach_%03d_%02d'%(j,n)]['bounds'][0][2]-.02))
    models=[]
    def strip(name,role,sections,route):
        verts=[];faces=[];top_faces=[]
        for left,right,bottom in sections:
            verts.extend([left,right,[left[0],left[1],bottom],[right[0],right[1],bottom]])
        def quad(a,b,c,d,top=False):
            if top:top_faces.extend([len(faces),len(faces)+1])
            faces.extend([[a,b,c],[a,c,d]])
        for i in range(len(sections)-1):
            a=i*4;b=a+4
            quad(a,a+1,b+1,b,True);quad(a+2,b+2,b+3,a+3)
            quad(a,b,b+2,a+2);quad(a+1,a+3,b+3,b+1)
        quad(0,2,3,1);n=(len(sections)-1)*4;quad(n,n+1,n+3,n+2)
        models.append(dict(name=name+'-colonly',role=role,vertices=verts,triangles=faces,top_faces=top_faces,route=route))
    samples=sorted(set([float(s) for s in np.linspace(0,length,math.ceil(length/.25)+1)]+arc.tolist()+[k[0] for k in knots]+[v for row in bottoms for v in row[:2]]))
    cleaned=[samples[0]]
    for s in samples[1:]:
        if s-cleaned[-1]>.01:cleaned.append(s)
    if length-cleaned[-1]<.01:cleaned[-1]=length
    else:cleaned.append(length)
    samples=cleaned
    sections=[];route=[]
    for s in samples:
        p,r=frame(s);z=float(profile(s));left=p-r*1.6;right_p=p+r*1.6
        bottom=min(row[2] for row in bottoms if row[0]-1e-7<=s<=row[1]+1e-7)
        sections.append(([float(left[0]),float(left[1]),z],[float(right_p[0]),float(right_p[1]),z],bottom))
    for s in np.linspace(0,length,math.ceil(length/1.)+1):
        p,r=frame(s);route.append([float(p[0]),float(p[1]),float(profile(s))])
    strip('PR_Walk_Approach','approach',sections,route)
    def flight(name,role,a,z,risers,half_width=None):
        last=a+(risers-1)*.35;end=a+risers*.35;start=a-.35;top=z+risers*.15
        sections=[]
        for v,h in [(start,z),(last,top),(end,top)]:
            w=half_width if half_width is not None else width(v)
            sections.append((world(-w,v,h),world(w,v,h),min(z-.25,h-.25)))
        route=[]
        for v in np.linspace(start-.5,end+.6,math.ceil((end-start+1.1)/.7)+1):
            h=z+max(0.,min(1.,(v-start)/(last-start)))*(top-z)
            route.append(world(0,v,h))
        strip(name,role,sections,route)
    flight('PR_Walk_Entry_1','entry_1',-27.,55.05,18,3.6)
    flight('PR_Walk_Entry_2','entry_2',-18.3,57.75,18,3.6)
    flight('PR_Walk_Internal_1','internal_1',9.,60.45,4)
    flight('PR_Walk_Internal_2','internal_2',47.5,61.05,4)
    # Circular dais: continuous conical walking skirt plus a level top disk.
    verts=[];faces=[];top_faces=[];rings=[(2.10,61.05),(1.8,61.2),(1.5,61.35),(1.25,61.5)];sides=128
    for radius,z in rings:
        verts.extend(world(math.cos(i*2*math.pi/sides)*radius,25.+math.sin(i*2*math.pi/sides)*radius,z) for i in range(sides))
    for j in range(len(rings)-1):
        for i in range(sides):
            k=(i+1)%sides;a=j*sides+i;b=j*sides+k;c=(j+1)*sides+k;d=(j+1)*sides+i
            top_faces.extend([len(faces),len(faces)+1]);faces.extend([[a,b,c],[a,c,d]])
    disk=len(verts);verts.append(world(0,25.,61.5));bottom=len(verts);verts.append(world(0,25.,61.0))
    rim=len(verts);verts.extend(world(math.cos(i*2*math.pi/sides)*2.1,25.+math.sin(i*2*math.pi/sides)*2.1,61.0) for i in range(sides))
    for i in range(sides):
        k=(i+1)%sides;top_faces.append(len(faces));faces.append([3*sides+i,3*sides+k,disk])
        faces.extend([[bottom,rim+k,rim+i],[i,rim+i,rim+k],[i,rim+k,k]])
    route=[]
    for v in np.linspace(22.3,25.,12):
        r=25.-v;z=float(np.interp(r,[1.25,1.5,1.8,2.1],[61.5,61.35,61.2,61.05]));route.append(world(0,v,z))
    models.append(dict(name='PR_Walk_SummonDais-colonly',role='dais',vertices=verts,triangles=faces,top_faces=top_faces,route=route))
    replaced=[o for o in state['objects'] if o['name'].startswith(('PR_Approach_','PR_EntryFlight_','PR_InternalStair_','PR_SummonStep_'))]
    assert len(replaced)==206
    recipe=dict(version=1,source_state=str(CAD/'build_state.json'),source_state_sha256=hashlib.sha256((CAD/'build_state.json').read_bytes()).hexdigest(),native_center=[1450,1150,0],models=models,replaced_objects=replaced,source_bounds={o['id']:by_name[o['name']]['bounds'] for o in replaced},math=dict(approach_length=length,approach_stations=stations,approach_height_knots=knots,profile='monotone PCHIP, piecewise linear triangle mesh',sample_spacing_m=.25,approach_width=3.2,entry_width=7.2,riser=.15,tread=.35,dais_rings=rings))
    write(RECIPE,recipe)
    print(json.dumps(dict(recipe=str(RECIPE),models=len(models),triangles=sum(len(m['triangles']) for m in models),replaced=len(replaced),length=length)))

def package():
    exported=read(CACHE/'ruin_walk_collision_cad.json');recipe=read(RECIPE)
    assert exported['original_objects_preserved'] and len(exported['objects'])==6
    work=CACHE/'ruin_walk_collision_export';work.mkdir(exist_ok=True)
    (work/'source.bin').write_bytes((CACHE/'ruin_walk_collision_cad.bin').read_bytes())
    spec=importlib.util.spec_from_file_location('walk_glb',ROOT/'tools/build_landscape_world_mask.py');module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module);module.CACHE=work;module.OUT=work
    module.build_glb(exported)
    data=(work/'current_region.glb').read_bytes();length,kind=struct.unpack_from('<II',data,12);doc=json.loads(data[20:20+length]);tail=data[20+length:]
    names={r['id']:r['name'] for r in exported['objects']}
    for node in doc['nodes']:node['name']=names[node['extras']['source_id']]
    doc['asset']['generator']='Prism Route Rhino collision-only stair surfaces'
    text=json.dumps(doc,separators=(',',':')).encode();text+=b' '*((-len(text))%4)
    glb=struct.pack('<III',0x46546c67,2,20+len(text)+len(tail))+struct.pack('<II',len(text),0x4e4f534a)+text+tail
    (OUT/'walk_collision.glb').write_bytes(glb)
    def godot(p):return [p[0]-1450.,p[2],1150.-p[1]]
    probes=[];routes={}
    for model,row in zip(recipe['models'],exported['objects']):
        vertices=np.array(model['vertices']);triangles=np.array(model['triangles']);points=vertices[triangles[model['top_faces']]].mean(axis=1)
        # Samples independently come from the CAD recipe, not the runtime collider.
        stride=max(1,len(points)//180)
        probes.append(dict(id=row['id'],role=model['role'],samples=[godot(p) for p in points[::stride].tolist()]))
        routes[model['role']]=[godot(p) for p in model['route']]
    manifest=dict(version=1,source_document=exported['source'],source_layer=exported['layer'],cad_objects=exported['objects'],original_objects_preserved=True,source_state_sha256=recipe['source_state_sha256'],mesh_sha256=hashlib.sha256(glb).hexdigest(),replaced_actor_collision_ids=[o['id'] for o in recipe['replaced_objects']],replaced_names=[o['name'] for o in recipe['replaced_objects']],triangles=sum(o['index_count']//3 for o in exported['objects']),probes=probes,routes=routes,math=recipe['math'])
    write(OUT/'walk_collision.json',manifest)
    print(json.dumps(dict(objects=6,triangles=manifest['triangles'],bytes=len(glb),original_preserved=True)))

if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('action',choices=['recipe','package']);args=parser.parse_args()
    make_recipe() if args.action=='recipe' else package()
