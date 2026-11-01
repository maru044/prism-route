# -*- coding: utf-8 -*-
"""Rebuildable, two small open-air shell remnants on the measured SE ridge.

Run prepare(), build('A'), build('B'), paths(), commit(), audit(), save()
inside the native Rhino document. Geometry is staged before a single undoable
commit. Source terrain and all existing model objects remain untouched.
"""
from __future__ import unicode_literals, division
import Rhino, scriptcontext as sc, System, math, json, io, os, time
from System.Drawing import Color
G = Rhino.Geometry
ROOT = 'D:/Prism Route/prism-route'
OUT = ROOT+'/docs/terrace_open_ruins_concepts_1101'
TAG = 'terrace_curved_ruins_1101'
LAYER = '\u5efa\u7b51::\u53f0\u5730\u66f2\u9762\u9057\u6784'
TERRAIN = '0280eafa-4058-40dd-8cf0-36b575adcb14'
CONFIG = {
    'A': dict(cx=1844.,cy=160.,rx=8.,ry=14.,floor=95.18,height=5.,curl=.29,twist=.62,thickness=.18,pocket=[2.1,4.1,-1.0,-.4]),
    'B': dict(cx=1860.,cy=235.,rx=5.5,ry=9.,floor=92.32,height=3.5,curl=.34,twist=-.46,thickness=.16,pocket=[1.3,2.5,-.7,.3])}
PATH_DEFINITIONS=[('Ridge_link',[(1844,173.94),(1840,190),(1861,208),(1860,226.04)],95.18,92.32),
    ('South_ground_approach',[(1840,130),(1843,136),(1844,141),(1844,146.06)],None,95.18),
    ('North_ground_approach',[(1860,243.96),(1862,250),(1859,259),(1857,265)],92.32,None)]

def state(): return sc.sticky[TAG]
def xyz(p): return [float(p.X),float(p.Y),float(p.Z)]
def write(name,data):
    with io.open(OUT+'/'+name,'w',encoding='utf-8') as f:
        f.write(json.dumps(data,ensure_ascii=False,indent=2))
def objects():
    settings=Rhino.DocObjects.ObjectEnumeratorSettings()
    settings.NormalObjects=True;settings.HiddenObjects=True;settings.LockedObjects=True
    return [o for o in sc.doc.Objects.GetObjectList(settings) if not o.IsDeleted]
def fingerprint():
    opts=Rhino.FileIO.SerializationOptions()
    return {str(o.Id):(int(o.Geometry.DataCRC(0)),o.Attributes.ToJSON(opts)) for o in objects()}
def finish(m):
    m.Vertices.CullUnused();m.UnifyNormals();m.Normals.ComputeNormals()
    if m.IsClosed and G.VolumeMassProperties.Compute(m).Volume<0:m.Flip(True,True,True)
    m.Unweld(math.radians(38),True);m.Normals.ComputeNormals();m.Compact()
    assert m.IsValid,'Invalid mesh'
    return m
def stage(geo,name,category,mat='shell',info=None):
    assert geo and geo.IsValid,'Invalid geometry '+name
    state()['parts'].append((geo,name,category,mat,info or {}))
def ground(x,y):
    t=G.Intersect.Intersection.MeshRay(state()['host'],G.Ray3d(G.Point3d(x,y,150),-G.Vector3d.ZAxis))
    assert t>=0,'Outside measured host: %s,%s'%(x,y)
    return 150.-t
def blend(t):
    t=max(0.,min(1.,t));return t*t*(3.-2.*t)
def lerp_knots(knots,t):
    for (a,va),(b,vb) in zip(knots[:-1],knots[1:]):
        if t<=b:return va+(vb-va)*(t-a)/(b-a)
    return knots[-1][1]
def prepare():
    assert sc.doc.Path.replace('\\','/').lower()=='d:/prism route/map/map_current.3dm'
    assert str(sc.doc.ModelUnitSystem)=='Meters'
    assert not any(o.Attributes.GetUserString('feature')==TAG for o in objects()),'Existing feature: revise it instead of duplicating'
    assert TAG not in sc.sticky,'A staged build already exists'
    terrain=sc.doc.Objects.FindId(System.Guid(TERRAIN));assert terrain
    host=sc.sticky.get('terrace_ruins_measure_mesh_1101')
    if not isinstance(host,G.Mesh):
        host=G.Mesh();mp=G.MeshingParameters();mp.Tolerance=.02;mp.MaximumEdgeLength=3.;mp.RefineGrid=True
        for piece in G.Mesh.CreateFromBrep(terrain.Geometry,mp):host.Append(piece)
        host.Normals.ComputeNormals();host.Compact()
    backup_dir='D:/Prism Route/archive/terrace_curved_ruins_1101'
    if not os.path.exists(backup_dir):os.makedirs(backup_dir)
    backup=backup_dir+'/map_before_'+time.strftime('%Y%m%d_%H%M%S')+'.3dm'
    assert not os.path.exists(backup)
    opts=Rhino.FileIO.FileWriteOptions();opts.SuppressDialogBoxes=True
    assert sc.doc.Write3dmFile(backup,opts),'Native backup failed'
    sc.sticky[TAG]=dict(before=fingerprint(),parts=[],objects=[],host=host,backup=backup,
        built=[],materials={},categories={},original_camera=sc.doc.Views.ActiveView.ActiveViewport.GetCameraFrame()[1])
    write('model_parameters.json',dict(feature=TAG,terrain_id=TERRAIN,groups=CONFIG,view_axis=[1,0,0],
        shell='Elliptic doubly curved rolled plate; radial contraction with upward curl and asymmetric twist',
        ruin='Large missing roof sectors, connected irregular shell edge, sparse rectangular curved steel members',
        floor='Closed shallow foundation ring; bottom embeds 0.18 m into the unchanged source terrain; natural planting opening',
        path_width_m=2.2,units='Meters',backup=backup))
    return dict(backup=backup,original_object_count=len(state()['before']),host_faces=host.Faces.Count)

def floor_ring(c,outer_delta=0.,inner_delta=0.,z_offset=0.,band=False):
    m=G.Mesh();n=180
    px,py,ox,oy=c['pocket']
    for level in range(2):
        for boundary in range(2):
            for i in range(n):
                a=2*math.pi*i/n
                if band:
                    rx=c['rx']+outer_delta-boundary*.055;ry=c['ry']+outer_delta-boundary*.055
                    x=c['cx']+rx*math.cos(a);y=c['cy']+ry*math.sin(a)
                elif boundary==0:
                    x=c['cx']+(c['rx']+outer_delta)*math.cos(a);y=c['cy']+(c['ry']+outer_delta)*math.sin(a)
                else:
                    x=c['cx']+ox+(px+inner_delta)*math.cos(a);y=c['cy']+oy+(py+inner_delta)*math.sin(a)
                z=c['floor']+z_offset if level==0 else (c['floor']+z_offset-.055 if band else ground(x,y)-.18)
                m.Vertices.Add(x,y,z)
    for i in range(n):
        j=(i+1)%n
        m.Faces.AddFace(i,j,n+j,n+i)
        m.Faces.AddFace(2*n+i,3*n+i,3*n+j,2*n+j)
        m.Faces.AddFace(i,2*n+i,2*n+j,j)
        m.Faces.AddFace(n+i,n+j,3*n+j,3*n+i)
    return finish(m)

def shell(c,a,v):
    theta=math.radians(a);q=(a-105.)/150.
    profile=.22+.78*max(0.,math.sin(math.pi*q))**.72
    # A rolled cross section ends almost horizontally: a remnant of the roof
    # and facade is visibly one designed surface, rather than a planar wall.
    r=1.-c['curl']*v*v
    x=c['cx']+c['rx']*r*math.cos(theta)+.12*c['rx']*v*v
    y=c['cy']+c['ry']*r*math.sin(theta)+c['twist']*math.sin(theta*.65)*v*v
    z=c['floor']+c['height']*profile*math.sin(math.pi*.5*v)
    return G.Point3d(x,y,z)
def shell_normal(c,a,v):
    da=shell(c,a+.002,v)-shell(c,a-.002,v)
    dv=shell(c,a,v+.00002)-shell(c,a,v-.00002)
    n=G.Vector3d.CrossProduct(da,dv);assert n.Unitize()
    return n
def top_v(key,a):
    knots=([(105,1),(132,1),(135,.94),(138,.98),(139,.42),(144,.46),(146,.34),(152,.39),(154,.51),(156,.43),(157,.91),(162,1),(212,1),(213,.90),(217,.94),(219,1),(255,1)] if key=='A' else
           [(105,.72),(122,.91),(132,1),(172,1),(174,.85),(178,.90),(179,.32),(185,.37),(187,.27),(195,.34),(197,.79),(203,.93),(220,1),(240,.89),(255,.62)])
    return lerp_knots(knots,a)
def shell_plate(c,key):
    m=G.Mesh();na=300;nv=36;stride=nv+1;layer=(na+1)*stride
    for side in [-1,1]:
        for i in range(na+1):
            a=105+150.*i/na;top=top_v(key,a)
            for j in range(nv+1):
                v=top*j/nv;p=shell(c,a,v);n=shell_normal(c,a,v)
                m.Vertices.Add(p+n*(side*c['thickness']*.5))
    for i in range(na):
        for j in range(nv):
            k=i*stride+j;m.Faces.AddFace(k,k+stride,k+stride+1,k+1)
            k+=layer;m.Faces.AddFace(k,k+1,k+stride+1,k+stride)
    for i in range(na):
        k=i*stride;m.Faces.AddFace(k,k+layer,k+stride+layer,k+stride)
        k=i*stride+nv;m.Faces.AddFace(k,k+stride,k+stride+layer,k+layer)
    for j in range(nv):
        k=j;m.Faces.AddFace(k,k+1,k+1+layer,k+layer)
        k=na*stride+j;m.Faces.AddFace(k,k+layer,k+1+layer,k+1)
    return finish(m)

def ribbon(curvefun,t0,t1,width,depth,count=80):
    # A closed rectangular curved beam with a parallel, vertical reference.
    m=G.Mesh()
    for i in range(count+1):
        t=t0+(t1-t0)*i/count;p=curvefun(t)
        tangent=curvefun(t+.00001)-curvefun(t-.00001);tangent.Unitize()
        side=G.Vector3d.CrossProduct(tangent,G.Vector3d.ZAxis)
        if not side.Unitize():side=G.Vector3d.YAxis
        normal=G.Vector3d.CrossProduct(side,tangent);normal.Unitize()
        for sw,sd in [(-1,-1),(1,-1),(1,1),(-1,1)]:m.Vertices.Add(p+side*(sw*width/2)+normal*(sd*depth/2))
    for i in range(count):
        for j in range(4):
            a=i*4+j;b=i*4+(j+1)%4;m.Faces.AddFace(a,b,b+4,a+4)
    m.Faces.AddFace(3,2,1,0);a=count*4;m.Faces.AddFace(a,a+1,a+2,a+3)
    return finish(m)
def bezier(points,t):
    p=[G.Point3d(q) for q in points]
    for _ in range(3):p=[a+(b-a)*t for a,b in zip(p[:-1],p[1:])]
    return p[0]
def rib_fn(c,a):
    p=shell(c,a,1.);side=(a-180.)/75.
    y=c['cy']-side*c['ry']*.64
    end=G.Point3d(c['cx']+c['rx']*.70,y,c['floor']+.13)
    p1=G.Point3d(p.X+c['rx']*.66,p.Y+c['twist'],c['floor']+c['height']*.98)
    p2=G.Point3d(end.X+c['rx']*.14,end.Y+c['ry']*.045,c['floor']+c['height']*.79)
    pts=[p,p1,p2,end]
    return lambda t:bezier(pts,t)
def build(key):
    assert key not in state()['built'];c=CONFIG[key]
    stage(floor_ring(c),key+'_Terrain_fitted_foundation','01_foundation','deck')
    stage(floor_ring(c,z_offset=.012,band=True),key+'_Perimeter_metal_inlay','04_metal','trim')
    stage(shell_plate(c,key),key+'_Continuous_rolled_shell','02_shell','shell')
    # Low remnants frame the view without creating a complete enclosure.
    for a0,a1,h in [(-46,-18,.30),(18,39,.42)]:
        def low(t):
            a=math.radians(a0+(a1-a0)*t)
            return G.Point3d(c['cx']+c['rx']*.93*math.cos(a),c['cy']+c['ry']*.93*math.sin(a),c['floor']+.15)
        stage(ribbon(low,0,1,.15,h,40),key+'_Low_edge_%d'%a0,'02_shell','shell')
    angles=[126.,180.,234.] if key=='A' else [139.,225.]
    ribs=[]
    for i,a in enumerate(angles):
        fn=rib_fn(c,a);end=.61 if (key=='A' and i==1) else 1.
        # B's second beam is sheared off at the far end, still cantilevered
        # from the standing shell. No loose floating upper fragments.
        if key=='B' and i==1:end=.73
        ribs.append((fn,end));stage(ribbon(fn,0,end,.115 if key=='A' else .10,.22 if key=='A' else .18),key+'_Exposed_curved_box_rib_%d'%i,'03_ribs','steel')
        if end==1.:
            p=fn(1.);box=G.Box(G.Plane(G.Point3d(p.X,p.Y,c['floor']),G.Vector3d.ZAxis),G.Interval(-.22,.22),G.Interval(-.28,.28),G.Interval(0,.09)).ToBrep()
            stage(box,key+'_Rib_anchor_%d'%i,'04_metal','trim')
    # One small remaining canopy tongue, following the actual adjacent ribs.
    left,right=ribs[0][0],ribs[-1][0]
    def skin(u,v):
        a=left(.035+.19*u);b=right(.035+.19*u)
        p=a+(b-a)*v;p.Z-=.09+math.sin(math.pi*v)*.17
        return p
    roof=parametric_skin(skin,36,30,.09)
    stage(roof,key+'_Remaining_canopy_strip','02_shell','shell')
    # Manufactured joints are shallow narrow inlays, not dense facade tiling.
    for a in ([118,174,199,237] if key=='A' else [126,151,219,241]):
        vtop=top_v(key,a)
        def seam(v):return shell(c,a,v*vtop)+shell_normal(c,a,v*vtop)*(c['thickness']*.5+.006)
        stage(ribbon(seam,.025,.975,.014,.009,40),key+'_Panel_joint_%d'%a,'04_metal','joint')
    state()['built'].append(key)
    return dict(group=key,staged_parts=len(state()['parts']),floor=c['floor'],top=c['floor']+c['height'])
def parametric_skin(fn,nu,nv,thickness):
    m=G.Mesh();stride=nv+1;layer=(nu+1)*stride
    for side in [-1,1]:
        for i in range(nu+1):
            for j in range(nv+1):
                p=fn(i/nu,j/nv);m.Vertices.Add(p+G.Vector3d(0,0,side*thickness/2))
    for i in range(nu):
        for j in range(nv):
            k=i*stride+j;m.Faces.AddFace(k,k+stride,k+stride+1,k+1);k+=layer;m.Faces.AddFace(k,k+1,k+stride+1,k+stride)
    for i in range(nu):
        for j in [0,nv]:
            k=i*stride+j;m.Faces.AddFace(k,k+stride,k+stride+layer,k+layer)
    for i in [0,nu]:
        for j in range(nv):
            k=i*stride+j;m.Faces.AddFace(k,k+1,k+1+layer,k+layer)
    return finish(m)

def path_mesh(points,z_start=None,z_end=None,width=2.2):
    n=200;m=G.Mesh();rows=[]
    for i in range(n+1):
        t=i/n;p=bezier(points,t);tan=bezier(points,t+.0001)-bezier(points,t-.0001)
        side=G.Vector3d(-tan.Y,tan.X,0);side.Unitize()
        if i==0:start_ground=ground(p.X,p.Y)+.055
        target=ground(p.X,p.Y)+.055
        offset=0.
        if z_start is not None:offset+=(z_start-start_ground)*(1-blend(t/.80))
        if z_end is not None:
            e=points[-1];offset+=(z_end-ground(e.X,e.Y)-.055)*blend((t-.20)/.80)
        row=[]
        for sign in [-1,1]:
            q=p+side*(sign*width/2);z=ground(q.X,q.Y)+.055+offset
            # Constant crossfall at the deck contact eliminates a trip edge.
            if z_start is not None:z=z+(z_start-z)*(1-blend(t/.06))
            if z_end is not None:z=z+(z_end-z)*blend((t-.94)/.06)
            row.append(G.Point3d(q.X,q.Y,z))
        rows.append(row)
    for layer in range(2):
        for row in rows:
            for p in row:
                # Close the full space down to the host, including raised
                # deck approaches. A constant thin slab would float here.
                m.Vertices.Add(p if layer==0 else G.Point3d(p.X,p.Y,ground(p.X,p.Y)-.14))
    num=(n+1)*2
    for i in range(n):
        a=i*2;m.Faces.AddFace(a,a+1,a+3,a+2);m.Faces.AddFace(a+num,a+num+2,a+num+3,a+num+1)
        m.Faces.AddFace(a,a+2,a+2+num,a+num);m.Faces.AddFace(a+1,a+1+num,a+3+num,a+3)
    m.Faces.AddFace(0,num,num+1,1);a=n*2;m.Faces.AddFace(a,a+1,a+1+num,a+num)
    slopes=[]
    for a,b in zip(rows[:-1],rows[1:]):
        p=a[0]+(a[1]-a[0])*.5;q=b[0]+(b[1]-b[0])*.5
        slopes.append(abs(q.Z-p.Z)/math.hypot(q.X-p.X,q.Y-p.Y))
    return finish(m),dict(length_m=sum(a[0].DistanceTo(b[0]) for a,b in zip(rows[:-1],rows[1:])),max_center_gradient=max(slopes))
def paths():
    assert set(state()['built'])==set(['A','B']) and not state().get('paths')
    definitions=PATH_DEFINITIONS
    report=[]
    for name,pts,zs,ze in definitions:
        points=[G.Point3d(x,y,0) for x,y in pts];m,stats=path_mesh(points,zs,ze)
        stage(m,name,'05_paths','deck');stats['name']=name;report.append(stats)
    state()['paths']=report;write('path_report.json',report)
    return report

def layer(path):
    idx=sc.doc.Layers.FindByFullPath(path,-1)
    if idx>=0:return idx
    parent=System.Guid.Empty
    if '::' in path:parent=sc.doc.Layers[layer(path.rsplit('::',1)[0])].Id
    l=Rhino.DocObjects.Layer();l.Name=path.rsplit('::',1)[-1];l.ParentLayerId=parent
    return sc.doc.Layers.Add(l)
def material(key,rgb,rough,metal):
    name='PR_TerraceRuins_'+key
    for i,m in enumerate(sc.doc.Materials):
        if m.Name==name:return i
    m=Rhino.DocObjects.Material();m.Name=name;m.DiffuseColor=Color.FromArgb(*rgb)
    m.ToPhysicallyBased();p=m.PhysicallyBased;p.BaseColor=Rhino.Display.Color4f(rgb[0]/255.,rgb[1]/255.,rgb[2]/255.,1.)
    p.Roughness=rough;p.Metallic=metal
    return sc.doc.Materials.Add(m)
def commit():
    d=state();assert not d['objects'] and d.get('paths')
    # Validate all pieces before adding anything to the live CAD document.
    for geo,name,cat,mat,info in d['parts']:
        assert geo.IsValid
        if isinstance(geo,G.Mesh):assert geo.IsClosed,'Open solid: '+name
    rec=sc.doc.BeginUndoRecord('Two low curved terrace ruins');sc.doc.Views.RedrawEnabled=False
    try:
        for key,rgb,rough,metal in [('shell',(218,211,194),.76,.10),('deck',(199,197,180),.86,0.),('steel',(110,100,85),.67,.55),('trim',(146,120,91),.72,.35),('joint',(147,143,128),.94,0.)]:
            d['materials'][key]=material(key,rgb,rough,metal)
        for geo,name,cat,mat,info in d['parts']:
            at=Rhino.DocObjects.ObjectAttributes();at.Name='PR_TerraceRuins_'+name
            at.LayerIndex=layer(LAYER+'::'+cat);at.MaterialIndex=d['materials'][mat]
            at.MaterialSource=Rhino.DocObjects.ObjectMaterialSource.MaterialFromObject
            at.ObjectColor=sc.doc.Materials[at.MaterialIndex].DiffuseColor
            at.SetUserString('feature',TAG);at.SetUserString('category',cat);at.SetUserString('material_key',mat)
            at.SetUserString('generator','tools/rhino_terrace_curved_ruins_1101.py')
            if name[0] in ['A','B'] and name[1]=='_':at.SetUserString('group',name[0])
            sid=sc.doc.Objects.Add(geo,at);assert sid!=System.Guid.Empty
            d['objects'].append(str(sid));d['categories'][cat]=d['categories'].get(cat,0)+1
    except:
        for sid in d['objects']:sc.doc.Objects.Delete(System.Guid(sid),True)
        d['objects']=[]
        raise
    finally:sc.doc.EndUndoRecord(rec);sc.doc.Views.RedrawEnabled=True;sc.doc.Views.Redraw()
    return dict(objects=len(d['objects']),categories=d['categories'])
def audit():
    d=state();actual={str(o.Id):o for o in objects()};changed=[];opts=Rhino.FileIO.SerializationOptions()
    for sid,(crc,attrs) in d['before'].items():
        o=actual.get(sid)
        if not o or int(o.Geometry.DataCRC(0))!=crc or o.Attributes.ToJSON(opts)!=attrs:changed.append(sid)
    assert not changed,'Unrelated objects changed'
    own=[o for o in objects() if o.Attributes.GetUserString('feature')==TAG]
    assert set(str(o.Id) for o in own)==set(d['objects'])
    bounds=G.BoundingBox.Empty;triangles=0;volumes={}
    for o in own:
        bounds.Union(o.Geometry.GetBoundingBox(True));assert o.Geometry.IsValid
        if isinstance(o.Geometry,G.Mesh):
            assert o.Geometry.IsClosed,'Open solid '+o.Name
            vol=G.VolumeMassProperties.Compute(o.Geometry).Volume;assert vol>0,'Inward mesh '+o.Name
            volumes[o.Name]=vol;triangles+=o.Geometry.Faces.TriangleCount+o.Geometry.Faces.QuadCount*2
    report=dict(feature=TAG,object_ids=d['objects'],objects=len(own),categories=d['categories'],
        unchanged_original_objects=len(d['before']),unrelated_changes=changed,bounds=[xyz(bounds.Min),xyz(bounds.Max)],
        mesh_triangles=triangles,closed_mesh_volumes_m3=volumes,groups=CONFIG,paths=d['paths'],
        plants_added=0,terrain_modified=False,openings_facing='+X: lower crescent terrace',backup=d['backup'])
    write('model_report.json',report);return {k:report[k] for k in ['objects','categories','unchanged_original_objects','bounds','mesh_triangles']}
def camera(name):
    views={
        'overview':((1940,45,165),(1852,202,93),38.),
        'site':((1580,-350,360),(1850,210,60),38.),
        'A_front':((1880,122,113),(1843,160,97.2),42.),
        'A_detail':((1867,140,105.8),(1843,160,97),42.),
        'B_front':((1884,217,103),(1860,235,93.7),42.)}
    eye,target,lens=views[name];vp=sc.doc.Views.ActiveView.ActiveViewport
    vp.SetCameraLocations(G.Point3d(*target),G.Point3d(*eye));vp.Camera35mmLensLength=lens
    vp.ConstructionPlane() # Deliberately leave the user's construction plane intact.
    sc.doc.Objects.UnselectAll();sc.doc.Views.Redraw()
    return dict(view=name,eye=eye,target=target)
def capture(name):
    camera(name);view=sc.doc.Views.ActiveView
    vc=Rhino.Display.ViewCapture();vc.Width=1600;vc.Height=1000;vc.ScaleScreenItems=False
    vc.DrawAxes=False;vc.DrawGrid=False;vc.DrawGridAxes=False
    bitmap=vc.CaptureToBitmap(view);assert bitmap
    bitmap.Save(OUT+'/model_'+name+'.png',System.Drawing.Imaging.ImageFormat.Png);bitmap.Dispose()
    return OUT+'/model_'+name+'.png'
def save():
    audit();d=state();opts=Rhino.FileIO.FileWriteOptions();opts.SuppressDialogBoxes=True
    sc.doc.Objects.UnselectAll()
    try:
        for sid in d['objects']:sc.doc.Objects.Select(System.Guid(sid))
        opts.WriteSelectedObjectsOnly=True
        path=OUT+'/terrace_curved_ruins.3dm'
        assert not os.path.exists(path),'Keep the previous component rather than overwriting without review'
        assert sc.doc.Write3dmFile(path,opts),'Component save failed'
    finally:sc.doc.Objects.UnselectAll()
    camera('A_front');sc.doc.NamedViews.Add('TerraceRuins_A_1101',sc.doc.Views.ActiveView.ActiveViewport.Id)
    camera('B_front');sc.doc.NamedViews.Add('TerraceRuins_B_1101',sc.doc.Views.ActiveView.ActiveViewport.Id)
    camera('overview');sc.doc.NamedViews.Add('TerraceRuins_Overview_1101',sc.doc.Views.ActiveView.ActiveViewport.Id)
    camera('A_front')
    assert Rhino.RhinoApp.RunScript('_-Save _Enter',False) and not sc.doc.Modified
    saved=Rhino.FileIO.File3dm.Read(sc.doc.Path);assert saved
    assert set(str(o.Id) for o in saved.Objects if o.Attributes.GetUserString('feature')==TAG)==set(d['objects'])
    return dict(main=sc.doc.Path,component=path,objects=len(d['objects']),saved_readback_verified=True)
