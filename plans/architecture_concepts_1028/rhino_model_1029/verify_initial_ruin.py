# -*- coding: utf-8 -*-
import Rhino, scriptcontext as sc
import System, json, os, math
HERE=r'D:\Prism Route\plans\architecture_concepts_1028\rhino_model_1029'
PR_RUIN_PHASE=''
exec(compile(open(os.path.join(HERE,'build_initial_ruin.py'),'rb').read().decode('utf-8'),'build_initial_ruin.py','exec'))
b=Builder()
with open(os.path.join(HERE,'before_objects.json')) as f: before=json.load(f)
failures=[]
def check(ok,message):
    if not ok:failures.append(message)
old_ids=set(x['id'] for x in before)
for row in before:
    obj=D.Objects.FindId(System.Guid(row['id']))
    check(obj is not None,'Original object missing: '+row['id'])
    if obj is not None:
        check(int(obj.Geometry.DataCRC(0))==row['crc'],'Original geometry modified: '+row['id'])
        check(obj.Attributes.Name==row['name'],'Original name modified: '+row['id'])
        check(D.Layers[obj.Attributes.LayerIndex].FullPath==row['layer'],'Original layer changed: '+row['id'])

objects=[];bad=[];volumes=[]
for row in b.state['objects']:
    obj=D.Objects.FindId(System.Guid(row['id']))
    if obj is None:bad.append(row['name']+':missing');continue
    geom=obj.Geometry
    if not isinstance(geom,Rhino.Geometry.Brep) or not geom.IsValid or not geom.IsSolid:bad.append(row['name']+':open/invalid')
    amp=Rhino.Geometry.VolumeMassProperties.Compute(geom)
    if amp is None or amp.Volume<=.000001:bad.append(row['name']+':volume')
    else:volumes.append(amp.Volume)
    objects.append((row,obj))
check(not bad,'Invalid new solids: '+str(bad))

# Main floor and stair surfaces must cover the original hill everywhere within the court.
min_clearance=1000.;floor_count=0
for i in range(240):
    v=(i+.5)*.25;w=width(v)
    for j in range(17):
        u=-w+2*w*j/16.;clear=floor_z(v)-b.ground(u,v)
        min_clearance=min(min_clearance,clear);floor_count+=1
check(min_clearance>.18,'Terrain protrudes through the courtyard floor')

# Sample each actual approach tread cap: both sides, centre and edge midpoints.
approach_clear=1000.;approach_samples=0
for row,obj in objects:
    if not row['name'].startswith('PR_Approach_'):continue
    geom=obj.Geometry;box3=geom.GetBoundingBox(True);zz=box3.Max.Z
    verts=geom.DuplicateVertices()
    top=[p for p in verts if abs(p.Z-zz)<.00001]
    center=Rhino.Geometry.Point3d(sum(p.X for p in top)/len(top),sum(p.Y for p in top)/len(top),zz)
    samples=[center]+top
    for p in top:samples.append(center+(p-center)*.5)
    for p in samples:
        clearance=zz-b.ground_xy(p.X,p.Y)
        approach_clear=min(approach_clear,clearance);approach_samples+=1
check(approach_clear>-.025,'Terrain protrudes through an approach tread')

# Clear axial walking corridor from the entry to the first summoning step.
obstacles=[obj.Geometry for row,obj in objects if row['category'] in ['front','colonnade','highwall','roof','dais']]
obstacle_hits=[]
for i in range(93):
    v=i*.25
    for u in [-.8,0.,.8]:
        p=world(u,v,floor_z(v)+1.)
        for obstacle in obstacles:
            if obstacle.IsPointInside(p,TOL,True):obstacle_hits.append([u,v]);break
check(not obstacle_hits,'Central circulation blocked')

# The projection anchor is covered by remaining roof, and a neighbouring notch is open.
roof_object=next(obj for row,obj in objects if row['name']=='PR_Broken_InclinedRoof')
params=Rhino.Geometry.MeshingParameters.FastRenderMesh
roof_mesh=Rhino.Geometry.Mesh()
for part in Rhino.Geometry.Mesh.CreateFromBrep(roof_object.Geometry,params):roof_mesh.Append(part)
anchor=world(0,25,61.5)
roof_hit=Rhino.Geometry.Intersect.Intersection.MeshRay(roof_mesh,Rhino.Geometry.Ray3d(anchor,Rhino.Geometry.Vector3d.ZAxis))
notch=world(2.5,26,61.5)
notch_hit=Rhino.Geometry.Intersect.Intersection.MeshRay(roof_mesh,Rhino.Geometry.Ray3d(notch,Rhino.Geometry.Vector3d.ZAxis))
check(roof_hit>2.,'No remaining roof above summoning dais')
check(notch_hit<0.,'Intended broken roof opening is closed')

report={'passed':not failures,'failures':failures,'original_objects_verified':len(before),
        'new_closed_valid_solids':len(objects)-len(bad),'new_objects':len(objects),
        'court_ground_samples':floor_count,'court_min_clearance_m':min_clearance,
        'approach_ground_samples':approach_samples,'approach_min_clearance_m':approach_clear,
        'central_corridor_samples':93*3,'corridor_obstacle_hits':obstacle_hits,
        'roof_above_dais_m':roof_hit,'broken_notch_open':notch_hit<0.,
        'entry_stairs':b.state['checks']['entry_stairs'],
        'approach_length_m':b.state['checks']['approach']['length_m'],
        'approach_risers':b.state['checks']['approach']['risers'],
        'approach_riser_m':b.state['checks']['approach']['riser_m'],
        'approach_minimum_tread_m':b.state['checks']['approach']['minimum_tread_m'],
        'summon_anchor':b.state['checks']['summon_anchor']}
with open(os.path.join(HERE,'verification_report.json'),'w') as f:json.dump(report,f,indent=2)
print(json.dumps(report))
