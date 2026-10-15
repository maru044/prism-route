# -*- coding: utf-8 -*-
"""Native Rhino concept A: controlled section lofts, grounded hills, two passages.

Run inside Rhino in stages: prepare(), publish(), verify(), capture(), save().
Only objects carrying this recipe tag may be replaced during refinement.
"""
from __future__ import division, unicode_literals
import Rhino, scriptcontext as sc, System, math, json, os, io
from System.Drawing import Color
from System.Drawing.Imaging import ImageFormat
G = Rhino.Geometry
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, 'docs', 'concepts', 'inner_landscape_2026-10-15_v01', 'model_A')
TAG = 'prism_inner_landscape_A_v01'
LAYER = '内湾_A_内折长坡与丘陵_v01'
ROAD_IDS = ['e3c7a11d-7bdd-47a6-b8ae-b426b6903567', '4e756d0f-b36d-46a4-ada9-12ebe57462a2']
# x, y, crown elevation, section width. Coordinates were checked in the live site.
SPECS = [
    {'name': 'A01_内折下降主脊', 'stations': [
        [1630,755,43,70],[1535,790,43,114],[1430,830,44,151],
        [1330,900,37,164],[1240,990,28,138],[1200,1085,16,86],
        [1175,1160,1.2,5]], 'bias': -.06},
    {'name': 'A02_内湾低丘_回折肩部', 'stations': [
        [1135,720,1.2,5],[1055,765,19,112],[945,825,26,147],
        [935,905,19,112],[940,975,1.1,5]], 'bias': .08},
    {'name': 'A03_前景长丘_高低连续变化', 'stations': [
        [1585,1000,1,4],[1540,1080,21,151],[1440,1160,32,210],
        [1340,1230,24,175],[1285,1300,10,80],[1240,1360,1,4]], 'bias': -.07},
    {'name': 'A04_亲水低丘_渐隐收束', 'stations': [
        [1610,1240,1,4],[1540,1325,10,112],[1450,1410,17,164],
        [1350,1470,10,105],[1280,1520,1,4]], 'bias': .05},
]
# A closed cubic control polygon. Top, rolled shoulder, concave toe and hidden
# underside are one section, rather than a top plate with extruded vertical walls.
PROFILE = [(-.38,-.025),(-.51,.015),(-.56,.16),(-.57,.60),
           (-.50,.99),(-.35,1.08),(-.15,.91),(.10,.64),
           (.32,.30),(.48,.075),(.53,.005),(.48,-.025),(.34,-.04),
           (.10,-.04),(-.15,-.04)]

def xyz(p): return [float(p.X),float(p.Y),float(p.Z)]
def lookup(oid):
    obj=sc.doc.Objects.FindId(System.Guid(oid))
    if obj is None: raise RuntimeError('Missing source '+oid)
    return obj
def write(name,data):
    if not os.path.isdir(OUT): os.makedirs(OUT)
    with io.open(os.path.join(OUT,name),'w',encoding='utf-8') as f:
        f.write(json.dumps(data,ensure_ascii=False,indent=2,default=str))
def catmull(stations,t):
    f=max(0,min(1,t))*(len(stations)-1);k=min(int(f),len(stations)-2);u=f-k
    a=stations[max(k-1,0)];b=stations[k];c=stations[k+1];d=stations[min(k+2,len(stations)-1)]
    return [.5*((2*b[j])+(-a[j]+c[j])*u+(2*a[j]-5*b[j]+4*c[j]-d[j])*u*u+(-a[j]+3*b[j]-3*c[j]+d[j])*u*u*u) for j in range(len(b))]
def frame(spec,t):
    values=catmull(spec['stations'],t);a=catmull(spec['stations'],max(0,t-.0001));b=catmull(spec['stations'],min(1,t+.0001))
    axis=G.Vector3d(b[0]-a[0],b[1]-a[1],0);axis.Unitize()
    side=G.Vector3d(-axis.Y,axis.X,0)
    return values,axis,side
def oriented(b):
    if b.SolidOrientation==G.BrepSolidOrientation.Inward: b.Flip()
    return b
def loft_solid(curves):
    result=G.Brep.CreateFromLoft(curves,G.Point3d.Unset,G.Point3d.Unset,G.LoftType.Normal,False)
    if not result or len(result)!=1: raise RuntimeError('Section loft failed')
    solid=result[0].CapPlanarHoles(.005)
    if solid is None or not solid.IsValid or not solid.IsSolid: raise RuntimeError('Loft is not a valid closed solid')
    return oriented(solid)
def make_ridge(spec):
    sections=[];stations=[];outlines=[]
    for i in range(43):
        t=i/42.;values,axis,side=frame(spec,t);x,y,h,w=values
        w=max(3,w);h=max(1,h)
        points=[]
        for cross,z in PROFILE:
            # Crown bank changes down the ridge; sidewalls do not remain vertical.
            bank=spec['bias']*math.sin(t*math.pi)*cross
            px=x+side.X*cross*w;py=y+side.Y*cross*w
            pz=-3.8+(h+3.8)*(z+bank)
            points.append(G.Point3d(px,py,pz))
        c=G.NurbsCurve.Create(True,3,points)
        if not c or not c.IsValid or not c.IsClosed: raise RuntimeError('Section curve invalid')
        sections.append(c)
        stations.append({'t':t,'center':[x,y,h],'width':w})
        outlines.extend([G.Point3d(x+side.X*w*.50,y+side.Y*w*.50,0),G.Point3d(x-side.X*w*.53,y-side.Y*w*.53,0)])
    b=loft_solid(sections)
    return {'name':spec['name'],'geometry':b,'sections':sections,'stations':stations,'outlines':outlines}
def make_tunnel(road_index):
    f=lookup(ROAD_IDS[road_index]).Geometry.Faces[0]
    c=f.IsoCurve(1,f.Domain(0).Mid).ToNurbsCurve()
    # Only the inward site sections are used; the distant road is untouched.
    limits=(.06,.66) if road_index==0 else (0,.28)
    curves=[]
    for i in range(37):
        t=c.Domain.ParameterAt(limits[0]+(limits[1]-limits[0])*i/36.)
        p=c.PointAt(t);axis=c.TangentAt(t);axis.Z=0;axis.Unitize();side=G.Vector3d(-axis.Y,axis.X,0)
        center=G.Point3d(p.X,p.Y,p.Z+4.2)
        plane=G.Plane(center,side,G.Vector3d.ZAxis)
        # Oval arched void: 28m maximum width, 13.4m crown above the road.
        curves.append(G.Ellipse(plane,14,9.2).ToNurbsCurve())
    return {'name':'T%d'%(road_index+1),'geometry':loft_solid(curves),'road':c,'limits':limits}
def prepare(allow_existing=False):
    if not os.path.isdir(OUT): os.makedirs(OUT)
    previous=sc.sticky.get(TAG)
    if not allow_existing and any(o.Attributes.GetUserString('recipe')==TAG for o in sc.doc.Objects): raise RuntimeError('Already published; use refine instead')
    bodies=[make_ridge(s) for s in SPECS]
    tunnels=[make_tunnel(i) for i in range(2)]
    cutlog=[]
    for body in bodies:
        parts=[body['geometry']]
        for tunnel in tunnels:
            nextparts=[]
            for part in parts:
                intersection=G.Brep.CreateBooleanIntersection(part,tunnel['geometry'],.01)
                volume=sum(G.VolumeMassProperties.Compute(x).Volume for x in intersection or [])
                if volume>.01:
                    result=G.Brep.CreateBooleanDifference(part,tunnel['geometry'],.01)
                    if not result: raise RuntimeError('Tunnel difference failed '+body['name'])
                    nextparts.extend(oriented(x) for x in result)
                    cutlog.append({'body':body['name'],'tunnel':tunnel['name'],'removed_volume_m3':volume})
                else: nextparts.append(part)
            parts=nextparts
        body['parts']=parts
        for p in parts:
            if not p.IsValid or not p.IsSolid: raise RuntimeError('Open/invalid tunnel body')
    # Checking footprint against the ORIGINAL land loops prevents water coverage.
    landloops=[]
    for oid in ['493f74fe-8166-43ba-9dd3-b60a30144c9a','4c560a71-7757-47c1-8e6c-23bdf73081d6','a4adc150-3ba0-4216-b8b5-8d21449e8f69','ad44a7ee-76bf-4eac-aff2-1f138675d8a6']:
        obj=lookup(oid)
        for face in obj.Geometry.Faces:
            for loop in face.Loops:
                if loop.LoopType!=G.BrepLoopType.Outer: continue
                c=loop.To3dCurve();c.Transform(G.Transform.PlanarProjection(G.Plane.WorldXY));landloops.append(c)
    outside=[]
    for body in bodies:
        for p in body['outlines']:
            if not any(c.Contains(p,G.Plane.WorldXY,.1)!=G.PointContainment.Outside for c in landloops): outside.append(xyz(p))
    state={'recipe':TAG,'method':'Periodic cubic sections lofted along four irregular height-varying ridges. Entire cross-section is a solid from crown through rolled shoulder to buried base; native NURBS, not implicit mesh.',
           'specifications':SPECS,'tunnel_cuts':cutlog,'outline_samples_outside_original_land':outside,
           'objects':previous['state']['objects'] if allow_existing else [],'source_crc':previous['state']['source_crc'] if allow_existing else {str(o.Id):int(o.Geometry.DataCRC(0)) for o in sc.doc.Objects if not o.IsDeleted and o.Attributes.GetUserString('recipe')!=TAG},
           'geometry':[{'name':b['name'],'parts':len(b['parts']),'bounds':[xyz(b['geometry'].GetBoundingBox(True).Min),xyz(b['geometry'].GetBoundingBox(True).Max)],'section_count':len(b['sections'])}for b in bodies]}
    if allow_existing and previous:
        for key in ['backup','road_replacement','draft_path']:
            if key in previous['state']:state[key]=previous['state'][key]
    sc.sticky[TAG]={'bodies':bodies,'tunnels':tunnels,'state':state}
    write('prepare_report.json',state)
    print(json.dumps({'prepared':True,'ridges':len(bodies),'tunnel_cuts':cutlog,'outside_land_samples':len(outside),'geometry':state['geometry']},ensure_ascii=False))

def refine():
    prepare(True);data=sc.sticky[TAG];state=data['state'];doc=sc.doc
    undo=doc.BeginUndoRecord('A方案 曲面剖面与低端渐隐调整')
    try:
        for row in state['objects']:
            if row['group']=='01_连续实体地形':
                body=next(b for b in data['bodies'] if row['name'].startswith(b['name']+'_'))
                if len(body['parts'])!=1:raise RuntimeError('Unexpected split during refinement')
                if not doc.Objects.Replace(System.Guid(row['id']),body['parts'][0]):raise RuntimeError('Replacement failed')
            elif row['group']=='90_剖面编辑源_隐藏':
                body=next(b for b in data['bodies'] if row['name'].startswith(b['name']+'_'))
                i=int(row['name'].split('_')[-1]);doc.Objects.Replace(System.Guid(row['id']),body['sections'][i])
            elif row['group']=='91_隧道净空_隐藏':
                tunnel=next(t for t in data['tunnels'] if row['name'].startswith(t['name']+'_'))
                doc.Objects.Replace(System.Guid(row['id']),tunnel['geometry'])
        for m in doc.Materials:
            if m.Name=='A内湾_暖白半光建筑表皮':
                m.Shine=32;m.Reflectivity=.055;m.CommitChanges()
    finally:doc.EndUndoRecord(undo);doc.Views.Redraw()
    write('generation_state.json',state)
    print('Refined native section geometry, source objects retained.')

def layer(child,color,visible=True):
    root=sc.doc.Layers.FindByFullPath(LAYER,-1)
    if root<0:
        l=Rhino.DocObjects.Layer();l.Name=LAYER;root=sc.doc.Layers.Add(l)
    index=sc.doc.Layers.FindByFullPath(LAYER+'::'+child,-1)
    if index<0:
        l=Rhino.DocObjects.Layer();l.Name=child;l.ParentLayerId=sc.doc.Layers[root].Id;l.Color=color;l.IsVisible=visible;index=sc.doc.Layers.Add(l)
    return index
def write3dm(path):
    options=Rhino.FileIO.FileWriteOptions();options.UpdateDocumentPath=False;options.IncludeRenderMeshes=False
    options.SuppressAllInput=True;options.SuppressDialogBoxes=True
    if not sc.doc.Write3dmFile(path,options): raise RuntimeError('Save failed '+path)
def publish():
    data=sc.sticky[TAG];state=data['state'];doc=sc.doc
    if state['objects']: raise RuntimeError('Already published')
    for oid,crc in state['source_crc'].items():
        if int(lookup(oid).Geometry.DataCRC(0))!=crc: raise RuntimeError('Source changed')
    backup=os.path.join(os.path.dirname(ROOT),'map','map_before_inner_landscape_A_v01.3dm')
    if os.path.exists(backup): raise RuntimeError('Preserve existing backup')
    write3dm(backup);state['backup']=backup
    undo=doc.BeginUndoRecord('A方案 内折长坡与低地丘陵')
    try:
        white=Color.FromArgb(240,235,225)
        m=Rhino.DocObjects.Material();m.Name='A内湾_暖白半光建筑表皮';m.DiffuseColor=white;m.Shine=32;m.Reflectivity=.055
        mi=doc.Materials.Add(m)
        mp=G.MeshingParameters();mp.Tolerance=.025;mp.RelativeTolerance=0;mp.MaximumEdgeLength=4;mp.MinimumEdgeLength=.15
        mp.RefineGrid=True;mp.JaggedSeams=False;mp.GridAngle=math.radians(8)
        for body in data['bodies']:
            for k,part in enumerate(body['parts']):
                a=Rhino.DocObjects.ObjectAttributes();a.Name=body['name']+'_%02d'%k;a.LayerIndex=layer('01_连续实体地形',white)
                a.MaterialIndex=mi;a.MaterialSource=Rhino.DocObjects.ObjectMaterialSource.MaterialFromObject;a.CustomMeshingParameters=mp
                a.SetUserString('recipe',TAG);a.SetUserString('reference','A_inward_sweep.png');a.SetUserString('part',body['name'])
                oid=doc.Objects.AddBrep(part,a)
                if oid==System.Guid.Empty: raise RuntimeError('Add failed')
                state['objects'].append({'id':str(oid),'name':a.Name,'group':'01_连续实体地形'})
            for i,c in enumerate(body['sections']):
                if i%3: continue
                a=Rhino.DocObjects.ObjectAttributes();a.Name=body['name']+'_剖面_%02d'%i;a.LayerIndex=layer('90_剖面编辑源_隐藏',Color.CornflowerBlue,False);a.SetUserString('recipe',TAG)
                oid=doc.Objects.AddCurve(c,a);state['objects'].append({'id':str(oid),'name':a.Name,'group':'90_剖面编辑源_隐藏'})
        for tunnel in data['tunnels']:
            a=Rhino.DocObjects.ObjectAttributes();a.Name=tunnel['name']+'_道路净空编辑源';a.LayerIndex=layer('91_隧道净空_隐藏',Color.DeepSkyBlue,False);a.SetUserString('recipe',TAG)
            oid=doc.Objects.AddBrep(tunnel['geometry'],a);state['objects'].append({'id':str(oid),'name':a.Name,'group':'91_隧道净空_隐藏'})
    finally: doc.EndUndoRecord(undo);doc.Views.Redraw()
    write('generation_state.json',state)
    print(json.dumps({'published':True,'objects':len(state['objects']),'layer':LAYER,'backup':backup},ensure_ascii=False))

def lift_road():
    data=sc.sticky[TAG];state=data['state'];doc=sc.doc
    if state.get('road_replacement'):return
    original=lookup(ROAD_IDS[0]);g=original.Geometry.DuplicateBrep();g.Transform(G.Transform.Translation(0,0,.30))
    undo=doc.BeginUndoRecord('内湾道路抬升30厘米避免地面闪烁')
    try:
        a=original.Attributes.Duplicate();a.Name='A_中层下降道路_表面抬升0.30米';a.LayerIndex=layer('02_道路显示修正',Color.FromArgb(72,72,72));a.SetUserString('recipe',TAG)
        m=Rhino.DocObjects.Material();m.Name='A_下降道路_深灰沥青';m.DiffuseColor=Color.FromArgb(68,70,71);m.Shine=6
        a.MaterialIndex=doc.Materials.Add(m);a.MaterialSource=Rhino.DocObjects.ObjectMaterialSource.MaterialFromObject
        oid=doc.Objects.AddBrep(g,a)
        state['objects'].append({'id':str(oid),'name':a.Name,'group':'02_道路显示修正'})
        state['road_replacement']={'source':ROAD_IDS[0],'replacement':str(oid),'vertical_offset_m':.30,'reason':'Avoid coplanar road/zero-ground z fighting. Original retained hidden.'}
        doc.Objects.Hide(original.Id,True)
    finally:doc.EndUndoRecord(undo);doc.Views.Redraw()
    write('generation_state.json',state)

def capture(name='01_overview.png',camera=None,target=None,clean=True):
    view=sc.doc.Views.ActiveView;vp=view.ActiveViewport;vp.PushViewProjection()
    layers=[]
    try:
        if clean:
            for l in sc.doc.Layers:
                if l.FullPath in ['辅助线','边线','标注','中层道路中线','上层道路中线','参考边框'] and l.IsVisible:
                    layers.append(l.Id);l.IsVisible=False;l.CommitChanges()
        if camera:
            vp.SetCameraLocations(G.Point3d(*target),G.Point3d(*camera));vp.CameraUp=G.Vector3d.ZAxis;vp.Camera35mmLensLength=42
        sc.doc.Views.Redraw()
        vc=Rhino.Display.ViewCapture();vc.Width=1800;vc.Height=1200;vc.DrawGrid=False;vc.DrawAxes=False;vc.DrawGridAxes=False
        bitmap=vc.CaptureToBitmap(view);bitmap.Save(os.path.join(OUT,name),ImageFormat.Png);bitmap.Dispose()
    finally:
        for lid in layers:
            l=sc.doc.Layers.FindId(lid);l.IsVisible=True;l.CommitChanges()
        vp.PopViewProjection();sc.doc.Views.Redraw()
    print(os.path.join(OUT,name))

def verify():
    data=sc.sticky[TAG];state=data['state'];failures=[];bodies=[]
    for row in state['objects']:
        if row['group']!='01_连续实体地形':continue
        g=lookup(row['id']).Geometry;b=g.GetBoundingBox(True)
        bodies.append({'name':row['name'],'valid':g.IsValid,'solid':g.IsSolid,'faces':g.Faces.Count,'edges':g.Edges.Count,'bounds':[xyz(b.Min),xyz(b.Max)]})
        if not g.IsValid or not g.IsSolid:failures.append('Invalid/open '+row['name'])
        if b.Max.Z>60.918:failures.append('Height above existing rim')
    for oid,crc in state['source_crc'].items():
        if int(lookup(oid).Geometry.DataCRC(0))!=crc:failures.append('Source geometry changed '+oid)
    # Sample an actual vehicle envelope through both existing road alignments.
    clearance=[]
    for ri,tunnel in enumerate(data['tunnels']):
        c=tunnel['road'];obstructed=[];samples=0
        for i in range(161):
            t=c.Domain.ParameterAt(i/160.);p=c.PointAt(t);axis=c.TangentAt(t);axis.Z=0;axis.Unitize();side=G.Vector3d(-axis.Y,axis.X,0)
            for cross in [-9,-4.5,0,4.5,9]:
                for height in [1.0,4,8]:
                    q=p+side*cross+G.Vector3d(0,0,height+(.30 if ri==0 else 0));samples+=1
                    for body in data['bodies']:
                        if body['geometry'].GetBoundingBox(True).Contains(q):
                            if any(part.IsPointInside(q,.02,True) for part in body['parts']):obstructed.append(xyz(q));break
        clearance.append({'road':tunnel['name'],'envelope_width_m':18,'tested_height_m':[1,8],'samples':samples,'obstructed':obstructed})
        if obstructed:failures.append('New terrain blocks road envelope '+tunnel['name'])
    if state['outline_samples_outside_original_land']:failures.append('Sampled footprint extends beyond original land')
    report={'failures':failures,'bodies':bodies,'unchanged_source_objects':len(state['source_crc']),'tunnel_cuts':state['tunnel_cuts'],
            'road_clearance':clearance,'land_outline_samples':sum(len(b['outlines'])for b in data['bodies']),'land_outline_outside':len(state['outline_samples_outside_original_land']),
            'limits':'Native validity/solid/height and source-preservation checks. No global G2, self-intersection, drivability or game collision certification.'}
    write('verification_report.json',report);print(json.dumps(report,ensure_ascii=False))
    if failures:raise RuntimeError('Verification failed')
    return report

def save():
    data=sc.sticky[TAG];state=data['state'];verify()
    path=os.path.join(os.path.dirname(ROOT),'map','map_inner_landscape_A_v01.3dm')
    write3dm(path);state['draft_path']=path
    # Also archive just this study, with editable section and tunnel sources.
    model=Rhino.FileIO.File3dm();model.Settings.ModelUnitSystem=sc.doc.ModelUnitSystem
    model.Settings.ModelAbsoluteTolerance=sc.doc.ModelAbsoluteTolerance
    root=model.Layers.AddLayer(LAYER,Color.FromArgb(240,235,225));layers={};materials={}
    for row in state['objects']:
        o=lookup(row['id']);a=o.Attributes.Duplicate();group=row['group']
        if group not in layers:
            index=model.Layers.AddLayer(group,sc.doc.Layers[a.LayerIndex].Color,model.Layers.FindIndex(root).Id)
            model.Layers.FindIndex(index).IsVisible='隐藏' not in group;layers[group]=index
        a.LayerIndex=layers[group]
        if a.MaterialIndex>=0:
            source_index=a.MaterialIndex
            if source_index not in materials:materials[source_index]=model.Materials.AddMaterial(sc.doc.Materials[source_index])
            a.MaterialIndex=materials[source_index]
        model.Objects.Add(o.Geometry,a)
    archive=os.path.join(OUT,'inner_landscape_A_editable.3dm')
    if not model.Write(archive,8):raise RuntimeError('Standalone archive failed')
    state['standalone_archive']=archive
    # The user's live map remains the main working document; a pre-edit full
    # backup and a second full-scene snapshot are kept alongside it.
    current=sc.doc.Path
    # A copy-write cannot replace Rhino's currently open locked document.
    # Use Rhino's normal save command for that one path.
    if not Rhino.RhinoApp.RunScript('_Save',False):raise RuntimeError('Main-document Save command failed')
    state['main_document_path']=current
    write('generation_state.json',state)
    saved=Rhino.FileIO.File3dm.Read(current);prior=Rhino.FileIO.File3dm.Read(state['backup'])
    missing=[];changed=[]
    for before in prior.Objects:
        after=saved.Objects.FindId(before.Id)
        if after is None:missing.append(str(before.Id))
        elif int(after.Geometry.DataCRC(0))!=int(before.Geometry.DataCRC(0)):changed.append(str(before.Id))
    readback={'main':current,'snapshot':path,'standalone':archive,'original_objects':len(list(prior.Objects)),
              'missing_originals':missing,'changed_original_geometry':changed,
              'saved_new_solid_count':sum(1 for row in state['objects'] if row['group']=='01_连续实体地形' and saved.Objects.FindId(System.Guid(row['id'])).Geometry.IsSolid)}
    write('saved_readback_report.json',readback)
    if missing or changed:raise RuntimeError('Saved original geometry mismatch')
    print(json.dumps(readback,ensure_ascii=False))
