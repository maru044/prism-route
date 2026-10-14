# -*- coding: utf-8 -*-
"""Local architectural support study: a single closed editable SubD.

The underside has two actual topology openings continued into leaning,
twisting columns. No separate columns are Boolean-unioned onto a roof slab.
"""
from __future__ import division, unicode_literals
import Rhino, scriptcontext as sc, System, os, io, json, math
from System.Drawing import Color
from System.Drawing.Imaging import ImageFormat
G=Rhino.Geometry
ROOT=os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT=os.path.join(ROOT,'docs','concepts','cliff_terraces_2026-10-15','support_cell_v03')
TAG='prism_continuous_support_cell_v03'
LAYER='崖岸_连续支柱与拱腹_局部验证_v03'
INSET='prism_cliff_terrace_inset_v02'
NX=24;NY=12
START=.735;END=.815
# Root openings in underside topology. Each merges a broad roof shoulder into
# one smaller foot. Both topology rings have identical vertex counts.
ROOTS=[(3,9,2,10),(15,21,2,10)]

def write(name,value):
    if not os.path.isdir(OUT):os.makedirs(OUT)
    with io.open(os.path.join(OUT,name),'w',encoding='utf-8') as f:
        f.write(json.dumps(value,ensure_ascii=False,indent=2,default=str))

def xyz(p):return [float(p.X),float(p.Y),float(p.Z)]
def smooth(x):x=max(0,min(1,x));return x*x*(3-2*x)
def lookup(oid):
    o=sc.doc.Objects.FindId(System.Guid(oid))
    if o is None:raise RuntimeError('Missing '+oid)
    return o

def frame(site,q):
    s=START+(END-START)*q;t=site.rail.Domain.ParameterAt(s)
    p=site.rail.PointAt(t);axis=site.rail.TangentAt(t);axis.Z=0;axis.Unitize()
    ok,u,v=site.face.ClosestPoint(p);land=-site.face.NormalAt(u,v);land.Z=0;land.Unitize()
    return p,axis,land

def roof(site,q,f):
    p,axis,land=frame(site,q)
    front=76+12*math.sin(math.pi*q*2-.2)
    breadth=142+12*math.sin(math.pi*q)
    d=front+f*breadth
    point=p+land*d
    # A broad shoulder rises across the crown while the front edge curls down.
    z=p.Z-3+5.8*math.sin(math.pi*q)+3.2*math.sin(math.pi*f)*(1+.35*math.sin(2*math.pi*q))
    z-=4.5*(1-f)**2*(.6+.4*math.sin(math.pi*q))
    return G.Point3d(point.X,point.Y,min(59.5,z))

def perimeter(i0,i1,j0,j1):
    return ([(i,j0) for i in range(i0,i1)]+[(i1,j) for j in range(j0,j1)]
        +[(i,j1) for i in range(i1,i0,-1)]+[(i0,j) for j in range(j1,j0,-1)])

def build():
    data=sc.sticky.get(INSET)
    if not data:raise RuntimeError('Inset site state is required; inspect/reload it before creating the study')
    site=data['site'];mesh=G.Mesh();top={};bottom={};points={}
    def vertex(p):return mesh.Vertices.Add(p)
    for i in range(NX+1):
        q=i/NX
        for j in range(NY+1):
            f=j/NY;p=roof(site,q,f)
            top[i,j]=vertex(p)
            # The roof belly becomes a deep haunch around the branching roots,
            # and returns gradually to a lighter edge between their shoulders.
            root_weight=max(math.exp(-((q-.25)/.16)**2),math.exp(-((q-.75)/.16)**2))
            depth=7.5+3.5*math.sin(math.pi*f)**2+9.5*root_weight*math.sin(math.pi*f)**2
            b=G.Point3d(p.X,p.Y,p.Z-depth);points[i,j]=b;bottom[i,j]=vertex(b)
    for i in range(NX):
        for j in range(NY):
            mesh.Faces.AddFace(top[i,j],top[i+1,j],top[i+1,j+1],top[i,j+1])
            if not any(i0<=i<i1 and j0<=j<j1 for i0,i1,j0,j1 in ROOTS):
                mesh.Faces.AddFace(bottom[i,j+1],bottom[i+1,j+1],bottom[i+1,j],bottom[i,j])
    boundary=perimeter(0,NX,0,NY)
    # Rounded return from top to underside, not a ruled vertical slab edge.
    last=[top[k] for k in boundary]
    center=roof(site,.5,.5)
    for fraction in [.18,.50,.82,1]:
        ring=[]
        for key in boundary:
            a=roof(site,key[0]/NX,key[1]/NY);b=points[key]
            outward=G.Vector3d(a.X-center.X,a.Y-center.Y,0);outward.Unitize()
            bulge=1.6*math.sin(math.pi*fraction)
            p=G.Point3d(a.X+outward.X*bulge,a.Y+outward.Y*bulge,a.Z+(b.Z-a.Z)*fraction)
            ring.append(bottom[key] if fraction==1 else vertex(p))
        for k in range(len(last)):
            m=(k+1)%len(last);mesh.Faces.AddFace(last[k],ring[k],ring[m],last[m])
        last=ring
    columns=[]
    for number,(i0,i1,j0,j1) in enumerate(ROOTS):
        boundary=perimeter(i0,i1,j0,j1)
        q=(i0+i1)/(2*NX);f=(j0+j1)/(2*NY)
        origin=roof(site,q,f);unused,axis,land=frame(site,q)
        ring0=[points[k] for k in boundary]
        center=G.Point3d(sum(p.X for p in ring0)/len(ring0),sum(p.Y for p in ring0)/len(ring0),sum(p.Z for p in ring0)/len(ring0))
        last=[bottom[k] for k in boundary]
        # Width spreads increasingly toward the roof; the axis leans and the
        # section rotates while descending. Root vertices belong to the same
        # roof skin, so Catmull-Clark smooths through the shared shoulder.
        steps=[(.12,.91),(.28,.72),(.47,.48),(.65,.30),(.81,.22),(.94,.205),(1,.215),(1.06,.22)]
        lean=1 if number==0 else -1
        foot=center+axis*(lean*28)+land*(16 if number==0 else -16)
        foot.Z=-.65
        rings=[]
        radius_x=max(abs(G.Vector3d.Multiply(p-center,axis)) for p in ring0)
        radius_y=max(abs(G.Vector3d.Multiply(p-center,land)) for p in ring0)
        for t,scale in steps:
            ring=[];blend=smooth(t);twist=math.radians(lean*28)*blend
            cx=center.X+(foot.X-center.X)*blend;cy=center.Y+(foot.Y-center.Y)*blend
            for p in ring0:
                delta=p-center;x=G.Vector3d.Multiply(delta,axis);y=G.Vector3d.Multiply(delta,land)
                # Rounded-rectangle root morphs toward an elliptical stem.
                angle=math.atan2(y/radius_y,x/radius_x)
                circular=smooth((t-.20)/.55)
                x=x*(1-circular)+radius_x*math.cos(angle)*circular
                y=y*(1-circular)+radius_y*math.sin(angle)*circular
                xi=x*math.cos(twist)-y*math.sin(twist)
                yi=x*math.sin(twist)+y*math.cos(twist)
                point=G.Point3d(cx,cy,0)+axis*(xi*scale)+land*(yi*scale*(1-.40*circular))
                point.Z=(center.Z+(p.Z-center.Z)*(1-t))*(1-min(t,1))+foot.Z*min(t,1)
                if t>1:point.Z=-4
                ring.append(vertex(point))
            for k in range(len(last)):
                m=(k+1)%len(last);mesh.Faces.AddFace(last[m],ring[m],ring[k],last[k])
            rings.append(ring);last=ring
        # Foot closure lies below the zero-height ground plane. Triangle fan
        # is confined to its hidden sole; the visible column is all quads.
        cap=G.Point3d(sum(mesh.Vertices[k].X for k in last)/len(last),sum(mesh.Vertices[k].Y for k in last)/len(last),-4)
        c=vertex(cap)
        for k in range(len(last)):mesh.Faces.AddFace(last[(k+1)%len(last)],c,last[k])
        columns.append({'root_center':xyz(center),'foot_center':xyz(foot),'root_perimeter_vertices':len(boundary),
            'root_section_m':[2*radius_x,2*radius_y],'foot_section_m':[2*radius_x*.215,2*radius_y*.215*.60],'lean_and_twist_degrees':lean*28})
    mesh.Vertices.CullUnused();mesh.UnifyNormals();mesh.Normals.ComputeNormals();mesh.Compact()
    if mesh.SolidOrientation()<0:mesh.Flip(True,True,True)
    if not mesh.IsValid or not mesh.IsClosed or not mesh.IsManifold():raise RuntimeError('Control topology is not a closed manifold')
    options=G.SubDCreationOptions.Smooth
    subd=G.SubD.CreateFromMesh(mesh,options)
    if not subd or not subd.IsValid or not subd.IsSolid:raise RuntimeError('SubD creation is not a closed valid solid')
    limit=G.Mesh.CreateFromSubD(subd,3)
    if not limit.IsValid or not limit.IsClosed:raise RuntimeError('Limit surface mesh invalid')
    state={'recipe':TAG,'site_s':[START,END],'columns':columns,'control_vertices':mesh.Vertices.Count,
        'control_faces':mesh.Faces.Count,'native_subd_faces':subd.Faces.Count,'limit_mesh_faces':limit.Faces.Count,
        'control_closed':bool(mesh.IsClosed),'control_manifold':bool(mesh.IsManifold()),'subd_solid':bool(subd.IsSolid),
        'geometry':'Single shared-topology SubD: crown, rolled perimeter, variable-depth belly, two twisted flaring feet',
        'objects':[],'source_crc':{str(o.Id):int(o.Geometry.DataCRC(0)) for o in sc.doc.Objects if o.Visible and isinstance(o.Geometry,(G.Brep,G.Extrusion,G.SubD))}}
    sc.sticky[TAG]={'site':site,'control':mesh,'subd':subd,'limit':limit,'state':state}
    write('prepare_report.json',state);print(json.dumps({k:state[k] for k in ['control_vertices','control_faces','native_subd_faces','subd_solid','columns']},ensure_ascii=False))

def refine():
    old=sc.sticky[TAG];state=old['state'];rows=list(state['objects'])
    if not rows:raise RuntimeError('Publish first')
    build();new=sc.sticky[TAG]
    new['state'].update({'objects':rows,'backup':state['backup'],'draft_path':state['draft_path'],'hidden_previous_layers':state['hidden_previous_layers']})
    record=sc.doc.BeginUndoRecord('连续支柱样段 椭圆支脚与收口细化')
    try:
        o=lookup(rows[0]['id'])
        if o.Attributes.GetUserString('recipe')!=TAG:raise RuntimeError('Object ownership changed')
        if not sc.doc.Objects.Replace(o.Id,new['subd']):raise RuntimeError('Replace SubD failed')
    finally:sc.doc.EndUndoRecord(record);sc.doc.Views.Redraw()
    # Original-geometry evidence remains the snapshot preceding all new objects.
    new['state']['source_crc']=state['source_crc']
    write('generation_state.json',new['state']);save_doc(new['state']['draft_path'])
    print(json.dumps({'refined':True,'id':rows[0]['id']}))

def layer(child,color,visible=True):
    root=sc.doc.Layers.FindByFullPath(LAYER,-1)
    if root<0:
        l=Rhino.DocObjects.Layer();l.Name=LAYER;root=sc.doc.Layers.Add(l)
    index=sc.doc.Layers.FindByFullPath(LAYER+'::'+child,-1)
    if index<0:
        l=Rhino.DocObjects.Layer();l.Name=child;l.ParentLayerId=sc.doc.Layers[root].Id;l.Color=color;l.IsVisible=visible;index=sc.doc.Layers.Add(l)
    return index

def save_doc(path):
    options=Rhino.FileIO.FileWriteOptions();options.UpdateDocumentPath=False;options.IncludeRenderMeshes=False
    options.SuppressAllInput=True;options.SuppressDialogBoxes=True
    if not sc.doc.Write3dmFile(path,options):raise RuntimeError('Save failed '+path)

def publish():
    data=sc.sticky[TAG];state=data['state'];doc=sc.doc
    if state['objects']:raise RuntimeError('Already published')
    for oid,crc in state['source_crc'].items():
        if int(lookup(oid).Geometry.DataCRC(0))!=crc:raise RuntimeError('Source changed '+oid)
    backup=os.path.join(os.path.dirname(ROOT),'map','map_before_continuous_support_v03.3dm')
    if os.path.exists(backup):raise RuntimeError('Backup exists; preserve it')
    save_doc(backup);state['backup']=backup
    record=doc.BeginUndoRecord('连续支柱与曲面腹部 局部验证 v03')
    try:
        white=Color.FromArgb(238,234,225)
        mat=Rhino.DocObjects.Material();mat.Name='连续结构_暖白高光建筑表面';mat.DiffuseColor=white;mat.Shine=90;mat.Reflectivity=.18
        mi=doc.Materials.Add(mat)
        a=Rhino.DocObjects.ObjectAttributes();a.Name='连续曲面单元_双支脚_展开拱腹_扭转种植冠'
        a.LayerIndex=layer('01_连续结构_SubD',white);a.MaterialIndex=mi;a.MaterialSource=Rhino.DocObjects.ObjectMaterialSource.MaterialFromObject
        a.SetUserString('recipe',TAG);a.SetUserString('description',state['geometry']);oid=doc.Objects.AddSubD(data['subd'],a)
        if oid==System.Guid.Empty:raise RuntimeError('Add SubD failed')
        state['objects'].append({'id':str(oid),'name':a.Name,'role':'structure'})
        # Preserve original plates as an alternative, hiding only those and
        # their planting overlays. Keep cropped context and the previous bridge.
        state['hidden_previous_layers']=[]
        for name in ['02_内退建筑曲面','03_种植区域']:
            index=doc.Layers.FindByFullPath('崖岸_内退曲面_B方案_v02::'+name,-1)
            if index>=0:
                l=doc.Layers[index];state['hidden_previous_layers'].append({'index':index,'visible':bool(l.IsVisible)})
                l.IsVisible=False;doc.Layers.Modify(l,index,True)
        doc.Objects.UnselectAll()
    finally:doc.EndUndoRecord(record);doc.Views.Redraw()
    state['draft_path']=os.path.join(os.path.dirname(ROOT),'map','map_continuous_support_v03.3dm')
    save_doc(state['draft_path']);write('generation_state.json',state)
    print(json.dumps({'published':True,'id':str(oid),'draft':state['draft_path']},ensure_ascii=False))

def verify():
    data=sc.sticky[TAG];state=data['state'];mesh=data['limit'];failures=[]
    for oid,crc in state['source_crc'].items():
        if int(lookup(oid).Geometry.DataCRC(0))!=crc:failures.append('Original geometry changed '+oid)
    b=mesh.GetBoundingBox(True)
    if b.Max.Z>60.918:failures.append('Height ceiling exceeded')
    if not data['subd'].IsValid or not data['subd'].IsSolid:failures.append('SubD invalid/open')
    components=mesh.SplitDisjointPieces()
    if len(components)!=1:failures.append('More than one topology component')
    passages=[]
    for number,r in enumerate(data['site'].roads):
        road=lookup(r['id']).Geometry.Faces[0];curve=r['curve'];minimum=1e10;hits=0;bad=[]
        lo=max(0,r['station']-320);hi=min(curve.GetLength(),r['station']+320)
        for i in range(129):
            ok,t=curve.LengthParameter(lo+(hi-lo)*i/128);ok,u,v=road.ClosestPoint(curve.PointAt(t))
            for cross in [.03,.18,.34,.5,.66,.82,.97]:
                p=road.PointAt(road.Domain(0).ParameterAt(cross),v)
                distance=G.Intersect.Intersection.MeshRay(mesh,G.Ray3d(p+G.Vector3d(0,0,.05),G.Vector3d.ZAxis))
                if distance>=0:
                    hits+=1;clearance=distance+.05;minimum=min(minimum,clearance)
                    if clearance<9.8:bad.append({'point':xyz(p),'clearance_m':clearance})
        if bad:failures.append('T%d clearance'%(number+1))
        passages.append({'road':'T%d'%(number+1),'samples':903,'overhead_hits':hits,'minimum_clearance_m':None if minimum==1e10 else minimum,'violations':bad})
    result={'failures':failures,'bounds':[xyz(b.Min),xyz(b.Max)],'geometry_valid':bool(data['subd'].IsValid),'geometry_closed':bool(data['subd'].IsSolid),
        'single_topology_component':len(components)==1,'topology_component_count':len(components),'passages':passages,'sources_unchanged':not any('Original' in f for f in failures),
        'limitations':'Local shape study. Not whole-region replacement, terrain stitching, structural engineering or game physics acceptance. Road checks are sampled rays against the SubD limit mesh.'}
    write('verification_report.json',result);print(json.dumps(result,ensure_ascii=False));return result

def capture():
    data=sc.sticky[TAG];site=data['site'];center,axis,land=frame(site,.5);center=center+land*145;center.Z=22
    view=sc.doc.Views.ActiveView
    views=[('01_foot_to_belly.png',center-land*175+axis*38+G.Vector3d(0,0,3),center+G.Vector3d(0,0,4)),
        ('02_under_canopy.png',center-land*38-axis*115+G.Vector3d(0,0,-8),center+axis*45+G.Vector3d(0,0,10)),
        ('03_three_quarter.png',center-land*240-axis*155+G.Vector3d(0,0,115),center+G.Vector3d(0,0,3))]
    for name,camera,target in views:
        view.ActiveViewport.SetCameraLocations(target,camera);sc.doc.Views.Redraw()
        c=Rhino.Display.ViewCapture();c.Width=1920;c.Height=1080;c.DrawGrid=False;c.DrawAxes=False;c.DrawGridAxes=False
        bitmap=c.CaptureToBitmap(view);bitmap.Save(os.path.join(OUT,name),ImageFormat.Png);bitmap.Dispose()
    view.ActiveViewport.SetCameraLocations(views[0][2],views[0][1]);sc.doc.Views.Redraw();save_doc(data['state']['draft_path'])
    print(json.dumps({'captures':[v[0] for v in views]}))

def archive_and_capture_isolated():
    data=sc.sticky[TAG];state=data['state'];doc=sc.doc;o=lookup(state['objects'][0]['id'])
    native=Rhino.FileIO.File3dm();native.Settings.ModelUnitSystem=doc.ModelUnitSystem;native.Settings.ModelAbsoluteTolerance=doc.ModelAbsoluteTolerance
    l=Rhino.DocObjects.Layer();l.Name='连续支柱与拱腹_局部样段';native.Layers.Add(l)
    mat=Rhino.DocObjects.Material();mat.CopyFrom(doc.Materials[o.Attributes.MaterialIndex]);native.Materials.Add(mat)
    a=o.Attributes.Duplicate();a.LayerIndex=0;a.MaterialIndex=0
    native.Objects.AddSubD(o.Geometry,a)
    path=os.path.join(OUT,'support_cell_v03.3dm')
    if not native.Write(path,8):raise RuntimeError('Native study archive failed')
    read=Rhino.FileIO.File3dm.Read(path);rows=list(read.Objects)
    result={'path':path,'objects':len(rows),'valid':all(r.Geometry.IsValid for r in rows),'solid':all(r.Geometry.IsSolid for r in rows),'units':str(read.Settings.ModelUnitSystem)}
    read.Dispose();native.Dispose();write('saved_cell_readback.json',result)
    hide=[];before_modified=bool(doc.Modified)
    # Screenshot isolation only; restore every previously visible object.
    try:
        for other in doc.Objects:
            if other.Id==o.Id or not other.Visible or other.IsHidden:continue
            if doc.Objects.Hide(other.Id,True):hide.append(other.Id)
        doc.Views.Redraw()
        site=data['site'];center,axis,land=frame(site,.5);center=center+land*145;center.Z=22
        view=doc.Views.ActiveView
        views=[('04_isolated_supports.png',center-land*250+axis*5+G.Vector3d(0,0,5),center+G.Vector3d(0,0,3)),
            ('05_isolated_underbelly.png',center-land*70-axis*180+G.Vector3d(0,0,-1),center+axis*25+G.Vector3d(0,0,8))]
        for name,camera,target in views:
            view.ActiveViewport.SetCameraLocations(target,camera);doc.Views.Redraw()
            c=Rhino.Display.ViewCapture();c.Width=1920;c.Height=1080;c.DrawGrid=False;c.DrawAxes=False;c.DrawGridAxes=False
            bitmap=c.CaptureToBitmap(view);bitmap.Save(os.path.join(OUT,name),ImageFormat.Png);bitmap.Dispose()
    finally:
        for oid in hide:doc.Objects.Show(oid,True)
        doc.Views.Redraw();doc.Modified=before_modified
    state['isolated_archive']=path;write('generation_state.json',state);save_doc(state['draft_path'])
    print(json.dumps({'archive':result,'isolated_captures':['04_isolated_supports.png','05_isolated_underbelly.png'],'restored_objects':len(hide)},ensure_ascii=False))
