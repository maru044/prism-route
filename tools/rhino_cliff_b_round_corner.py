# -*- coding: utf-8 -*-
"""Locally restore the draft's broad western roof nose, without global scaling."""
from __future__ import division,unicode_literals
import Rhino,scriptcontext as sc,System,io,os,json,math
G=Rhino.Geometry
ROOT=os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
WORK=os.path.join(ROOT,'.map_1012_build')
STATE=os.path.join(WORK,'cliff_b_round_corner_state.json')
TAG='prism_cliff_b_round_corner_v01'


def load_recipe():
    p=os.path.join(ROOT,'tools','rhino_cliff_b_solid_nurbs.py')
    ns={'__file__':p,'__name__':'round_corner_recipe'}
    exec(compile('\n'.join(io.open(p,encoding='utf-8').read().splitlines()[1:]),p,'exec'),ns)
    rows=ns['source_rows']();ns['source_rows']=lambda:rows
    return ns


def weight(i,recipe):
    return recipe['smooth']((i-120)/55)*(1-recipe['smooth']((i-285)/70))


def boundary(recipe,repair=False):
    rows=recipe['source_rows']();pts=[]
    for i in range(0,len(rows),4):
        r=rows[i];a=rows[(i-2)%len(rows)];b=rows[(i+2)%len(rows)]
        radius=math.hypot(b[0]-a[0],b[1]-a[1])/max(math.hypot(b[2]-a[2],b[3]-a[3]),1e-8)
        retreat=min(45,radius*.55)
        if repair:
            w=weight(i,recipe);retreat=retreat*(1-w)+min(8,radius*.15)*w
        retreat*=recipe['smooth']((r[4]-65)/65)
        pts.append(G.Point3d(r[0]-r[2]*retreat,r[1]-r[3]*retreat,0))
    return recipe['loop'](pts,192)


def capped_loft(profiles):
    parts=[]
    for a,b in zip(profiles,profiles[1:]):
        parts.extend(G.Brep.CreateFromLoft([a,b],G.Point3d.Unset,G.Point3d.Unset,G.LoftType.Straight,False) or [])
    parts.extend(G.Brep.CreatePlanarBreps(profiles[0],.01) or [])
    parts.extend(G.Brep.CreatePlanarBreps(profiles[-1],.01) or [])
    joined=G.Brep.JoinBreps(parts,.01)
    if not joined or len(joined)!=1 or not joined[0].IsValid or not joined[0].IsSolid:
        raise RuntimeError('Loft must be one valid closed NURBS Brep')
    g=joined[0]
    if g.SolidOrientation==G.BrepSolidOrientation.Inward:g.Flip()
    return g


def make_roof(backing,recipe):
    helper=recipe['helpers']()['recipe']();draft,_=helper['curves']()
    road=helper['source_object']('road_id').Geometry.Edges[1].DuplicateCurve()
    road.Transform(G.Transform.PlanarProjection(G.Plane.WorldXY))
    points=[]
    for i in range(320):
        p=draft.PointAtNormalizedLength(i/320);ok,t=road.ClosestPoint(p)
        w=recipe['smooth']((p.DistanceTo(road.PointAt(t))-70)/75)
        ok,t=backing.ClosestPoint(p);q=backing.PointAt(t)
        tangent=draft.TangentAt(draft.NormalizedLengthParameter(i/320)[1]);tangent.Z=0;tangent.Unitize()
        points.append(G.Point3d(p.X*(1-w)+q.X*w+tangent.Y*.6*w,p.Y*(1-w)+q.Y*w-tangent.X*.6*w,0))
    outline=recipe['loop'](points,192);profiles=[]
    # A small buried overlap avoids a coincident-face boolean at the seam.
    for inset,z in [(0,56.8),(0,59),(-3.8,63)]:
        if inset==0:c=outline.DuplicateCurve()
        else:
            offsets=outline.Offset(G.Plane.WorldXY,inset,.01,G.CurveOffsetCornerStyle.Sharp)
            if not offsets or len(offsets)!=1:raise RuntimeError('Chamfer splits roof outline')
            c=offsets[0]
        c=c.Rebuild(192,3,True)
        hits=G.Intersect.Intersection.CurveSelf(c,.01)
        if hits and hits.Count:raise RuntimeError('Roof outline self-intersects')
        c.Transform(G.Transform.Translation(0,0,z));profiles.append(c)
    return capped_loft(profiles)


def prepare():
    recipe=load_recipe();oldstate=recipe['read'](recipe['STATE'])
    if int(sc.doc.RuntimeSerialNumber)!=oldstate['document_serial']:raise RuntimeError('Rhino document changed')
    if os.path.exists(STATE):raise RuntimeError('Corner candidate already exists')
    core=sc.doc.Objects.FindId(System.Guid(oldstate['backing_id']))
    roof_record=next(r for r in oldstate['objects'] if r['group']=='03_斜切屋盖')
    oldroof=sc.doc.Objects.FindId(System.Guid(roof_record['id'])).Geometry
    backup=os.path.join(os.path.dirname(ROOT),'map','map_before_cliffB_round_corner.3dm')
    if not os.path.exists(backup):recipe['save'](backup)
    # Removing the old roof before adding the repaired roof avoids an exposed
    # second top surface and preserves the remainder of the authored solid.
    base=G.Brep.CreateBooleanDifference(core.Geometry,oldroof,.01)
    if not base or len(base)!=1 or not base[0].IsValid or not base[0].IsSolid:raise RuntimeError('Cannot isolate roof from main solid')
    lower=boundary(recipe);upper=boundary(recipe,True)
    lower_area=G.AreaMassProperties.Compute(lower).Area
    offsets=[]
    for distance in [-.8,.8]:
        offsets.extend(lower.Offset(G.Plane.WorldXY,distance,.01,G.CurveOffsetCornerStyle.Sharp) or [])
    inward=[c for c in offsets if c.IsClosed and G.AreaMassProperties.Compute(c).Area<lower_area]
    if not inward:raise RuntimeError('Cannot bury lower shoulder seam')
    lower=max(inward,key=lambda c:G.AreaMassProperties.Compute(c).Area).Rebuild(192,3,True)
    lower.Transform(G.Transform.Translation(0,0,43));upper.Transform(G.Transform.Translation(0,0,57.2))
    transition=capped_loft([lower,upper])
    crop=G.BoundingBox(G.Point3d(850,-80,42.5),G.Point3d(1085,190,57.5)).ToBrep()
    parts=G.Brep.CreateBooleanIntersection(transition,crop,.01)
    if not parts or len(parts)!=1 or not parts[0].IsSolid:raise RuntimeError('Cannot isolate local shoulder')
    corrected=make_roof(boundary(recipe,True),recipe)
    # The original solid has many coincident trims on this shoulder. Keep
    # closed, buried-overlap construction pieces instead of accepting a
    # boolean that silently discards the added volume.
    geometries=[base[0],parts[0],corrected]
    for g in geometries:
        if not g.IsValid or not g.IsSolid:raise RuntimeError('Repair component is not valid and closed')
        if g.SolidOrientation==G.BrepSolidOrientation.Inward:g.Flip()
        for e in g.Edges:
            hits=G.Intersect.Intersection.CurveSelf(e,.01)
            if hits and hits.Count:raise RuntimeError('Corrected solid edge self-intersects')
    state={'document_serial':int(sc.doc.RuntimeSerialNumber),'backup':backup,'core_id':str(core.Id),'roof_id':roof_record['id'],
           'objects':[],'candidate_faces':[g.Faces.Count for g in geometries],'corner_retraction_m':8,'shoulder_start_z_m':43,
           'affected_sample_indices':[120,355]}
    ns=recipe['helpers']();ns['TAG']=TAG
    ns['cfg']=lambda:{'layer':u'崖壁B_圆润端部修正_预览'}
    ns['add'](base[0],u'B_NURBS_西端圆润修正候选','01_候选实体',state,core.Attributes)
    ns['add'](parts[0],u'B_NURBS_西端斜向衔接','03_候选衔接',state,core.Attributes)
    ns['add'](corrected,u'B_NURBS_西端圆润屋盖','02_候选屋盖',state,core.Attributes)
    state['candidate_id']=state['objects'][0]['id'];state['candidate_shoulder_id']=state['objects'][1]['id'];state['candidate_roof_id']=state['objects'][2]['id']
    sc.doc.Objects.Hide(core,True)
    recipe['write'](STATE,state)
    print(json.dumps({'candidate_closed':True,'candidate_valid':True,'faces':state['candidate_faces'],'candidate_id':state['candidate_id']}))


def install():
    recipe=load_recipe();s=recipe['read'](STATE)
    if int(sc.doc.RuntimeSerialNumber)!=s['document_serial']:raise RuntimeError('Rhino document changed')
    if s.get('installed'):raise RuntimeError('Corner repair already installed')
    old=recipe['read'](recipe['STATE']);core=sc.doc.Objects.FindId(System.Guid(s['core_id']))
    candidate=sc.doc.Objects.FindId(System.Guid(s['candidate_id']))
    sc.doc.Objects.Show(core,True)
    if not sc.doc.Objects.Replace(core.Id,candidate.Geometry.DuplicateBrep()):raise RuntimeError('Cannot install corrected core')
    roof=sc.doc.Objects.FindId(System.Guid(s['roof_id']));sc.doc.Objects.Show(roof,True)
    newroof=sc.doc.Objects.FindId(System.Guid(s['candidate_roof_id']))
    if not sc.doc.Objects.Replace(roof.Id,newroof.Geometry.DuplicateBrep()):raise RuntimeError('Cannot install editable roof')
    sc.doc.Objects.Hide(candidate,True);sc.doc.Objects.Hide(newroof,True)
    shoulder=sc.doc.Objects.FindId(System.Guid(s['candidate_shoulder_id']))
    parent=sc.doc.Layers[core.Attributes.LayerIndex].ParentLayerId
    layer=Rhino.DocObjects.Layer();layer.Name=u'13_圆润端部衔接';layer.ParentLayerId=parent
    index=sc.doc.Layers.Add(layer);a=shoulder.Attributes.Duplicate();a.LayerIndex=index
    a.SetUserString('recipe',recipe['TAG']);a.SetUserString('component',u'13_圆润端部衔接')
    sc.doc.Objects.ModifyAttributes(shoulder,a,True)
    old['objects'].append({'id':str(shoulder.Id),'name':shoulder.Name,'group':u'13_圆润端部衔接'})
    old['editable_hidden_ids'].remove(s['roof_id'])
    old['round_corner_revision']=s
    old['roof_union']={'strategy':'Separate closed NURBS construction solids with buried overlap','core_faces':candidate.Geometry.Faces.Count,'roof_faces':newroof.Geometry.Faces.Count,'shoulder_faces':shoulder.Geometry.Faces.Count}
    a=core.Attributes.Duplicate();a.Name=u'B_NURBS_实体侧错层台地内核_圆润端部';sc.doc.Objects.ModifyAttributes(core,a,True)
    old.setdefault('initial_unified_audit',old.get('audit',{}))
    old['audit']=s['audit']
    for record in old['objects']:
        if record['id']==str(core.Id):record['name']=a.Name
    recipe['write'](recipe['STATE'],old);s['installed']=True;recipe['write'](STATE,s)


def check():
    recipe=load_recipe();s=recipe['read'](STATE);helper=recipe['helpers']()['recipe']()
    ids=[s['candidate_id'],s['candidate_shoulder_id'],s['candidate_roof_id']]
    meshes=[]
    for i,oid in enumerate(ids):
        g=sc.doc.Objects.FindId(System.Guid(oid)).Geometry;m=helper['mesh_for'](g,4)
        meshes.append(m)
        m.Faces.ConvertQuadsToTriangles();m.Vertices.CombineIdentical(True,True);m.Compact()
        recipe['write'](os.path.join(WORK,'round_corner_component_%d.json'%i),{
            'vertices':[[float(p.X),float(p.Y),float(p.Z)] for p in m.Vertices],
            'faces':[[int(f.A),int(f.B),int(f.C)] for f in m.Faces]})
    combined=G.Mesh()
    for m in meshes:combined.Append(m)
    neighbor=[]
    for obstacle in recipe['source_input']()['obstacles']:
        obj=sc.doc.Objects.FindId(System.Guid(obstacle['id']));m=helper['mesh_for'](obj.Geometry,5)
        h=G.Intersect.Intersection.MeshMeshFast(combined,m)
        if h and len(h):raise RuntimeError('Round corner intersects neighboring terrain')
        neighbor.append({'id':obstacle['id'],'intersections':0})
    road=helper['source_object']('road_id').Geometry.DuplicateBrep();road.Transform(G.Transform.Translation(0,0,.1))
    volume=road.Faces[0].CreateExtrusion(G.LineCurve(G.Point3d.Origin,G.Point3d(0,0,5.1)),True)
    h=G.Intersect.Intersection.MeshMeshFast(combined,helper['mesh_for'](volume))
    if h and len(h):raise RuntimeError('Repair blocks road')
    paths=[];perimeter,path=helper['curves']()
    for entry in recipe['source_state']()['walking_clearance']['paths']:
        p,tangent,outward=helper['frame'](entry['path_s'],perimeter,path);p.Z=.66
        plane=G.Plane(p,tangent,-outward)
        if plane.ZAxis.Z<0:plane=G.Plane(p,-tangent,-outward)
        vol=G.Box(plane,G.Interval(-.75,.75),G.Interval(-20,26),G.Interval(.1,2.2)).ToBrep()
        h=G.Intersect.Intersection.MeshMeshFast(combined,helper['mesh_for'](vol,2))
        if h and len(h):raise RuntimeError('Repair blocks ground passage')
        paths.append({'s':entry['path_s'],'intersections':0})
    s['audit']={'neighbors':neighbor,'road_intersections':0,'ground_paths':paths,'edge_self_events':0,'all_components_valid_closed':True}
    recipe['write'](STATE,s);print(json.dumps(s['audit']))


def run(stage):
    old=sc.doc.Views.RedrawEnabled;undo=sc.doc.BeginUndoRecord('Round Cliff B western corner '+stage)
    try:
        sc.doc.Views.RedrawEnabled=False
        if stage=='prepare':prepare()
        elif stage=='install':install()
        elif stage=='check':check()
        else:raise RuntimeError('Unknown stage')
    finally:
        sc.doc.EndUndoRecord(undo);sc.doc.Views.RedrawEnabled=old;sc.doc.Views.Redraw()
