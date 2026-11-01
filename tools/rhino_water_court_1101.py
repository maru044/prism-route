# -*- coding: utf-8 -*-
"""Native shallow-water shell court. Stage, validate, then one undoable commit.

Run prepare(), build(), check_site(), commit(), audit(), capture(), save().
Existing lagoon, exit ramp, terrain and all vegetation are unchanged.
Units are native metres. Both shells retain their analytic parameterization.
"""
from __future__ import unicode_literals, division
import Rhino, scriptcontext as sc, System, math, json, io, os, time
from System.Drawing import Color
G=Rhino.Geometry
ROOT='D:/Prism Route/prism-route'
OUT=ROOT+'/docs/water_court_1101'
TAG='water_court_1101'
LAYER='\u5efa\u7b51::\u6d45\u6c34\u8584\u58f3\u5ead\u9662'
RAMP='3ece7c15-82db-4301-920c-2f1cd7097101'
BED='c5ae764e-2995-42f9-96a6-f0bf6c7420a6'
CONFIG=dict(center=[555.,510.],ellipse=[36.,31.],main_angles=[72.,270.],
            main_height=14.2,shell_thickness=.24,water_level=0.,
            vault_y=[520.,551.],vault_inner_x=576.,vault_outer_x=622.,
            vault_height=[8.5,11.8,9.4],ramp_clear_width=16.,minimum_headroom=5.)

def xyz(p):return [float(p.X),float(p.Y),float(p.Z)]
def state():return sc.sticky[TAG]
def write(name,value):
    if not os.path.isdir(OUT):os.makedirs(OUT)
    with io.open(OUT+'/'+name,'w',encoding='utf-8') as f:f.write(json.dumps(value,ensure_ascii=False,indent=2))
def objects():
    e=Rhino.DocObjects.ObjectEnumeratorSettings();e.NormalObjects=True;e.HiddenObjects=True;e.LockedObjects=True
    return [o for o in sc.doc.Objects.GetObjectList(e) if not o.IsDeleted]
def fingerprint():
    opts=Rhino.FileIO.SerializationOptions()
    return {str(o.Id):(int(o.Geometry.DataCRC(0)),o.Attributes.ToJSON(opts)) for o in objects()}
def mesh_of(g):
    if isinstance(g,G.Mesh):return g.DuplicateMesh()
    m=G.Mesh();mp=G.MeshingParameters();mp.Tolerance=.015;mp.MaximumEdgeLength=2.;mp.RefineGrid=True
    for part in G.Mesh.CreateFromBrep(g,mp):m.Append(part)
    m.Normals.ComputeNormals();m.Compact();return m
def finish(m):
    m.Vertices.CullUnused();m.UnifyNormals();m.Normals.ComputeNormals()
    assert m.IsValid and m.IsClosed,'Invalid or open mesh'
    if G.VolumeMassProperties.Compute(m).Volume<0:m.Flip(True,True,True)
    m.Unweld(math.radians(40),True);m.Normals.ComputeNormals();m.Compact();return m
def stage(g,name,category,mat):
    assert g and g.IsValid,name
    assert g.IsClosed if isinstance(g,G.Mesh) else g.IsSolid,name
    state()['parts'].append((g,name,category,mat))
def cubic(points,t):
    p=[G.Point3d(q) for q in points]
    for i in range(3):p=[a+(b-a)*t for a,b in zip(p[:-1],p[1:])]
    return p[0]
def mix(a,b,t):return a+(b-a)*t
def smooth(t):t=max(0.,min(1.,t));return t*t*(3.-2.*t)
def unit(v):v=G.Vector3d(v);assert v.Unitize();return v
def terrain(x,y):
    m=state()['bed'];t=G.Intersect.Intersection.MeshRay(m,G.Ray3d(G.Point3d(x,y,100),-G.Vector3d.ZAxis))
    assert t>=0,'No measured lake bed at '+str((x,y));return 100-t
def prepare():
    assert sc.doc.Path.replace('\\','/').lower()=='d:/prism route/map/map_current.3dm'
    assert str(sc.doc.ModelUnitSystem)=='Meters'
    assert not any(o.Attributes.GetUserString('feature')==TAG for o in objects()),'Revise existing court instead of duplicating'
    assert TAG not in sc.sticky,'Reuse the staged court'
    if not os.path.isdir(OUT):os.makedirs(OUT)
    backup_dir='D:/Prism Route/archive/water_court_1101'
    if not os.path.isdir(backup_dir):os.makedirs(backup_dir)
    backup=backup_dir+'/map_before_'+time.strftime('%Y%m%d_%H%M%S')+'.3dm'
    opts=Rhino.FileIO.FileWriteOptions();opts.SuppressDialogBoxes=True
    assert not os.path.exists(backup) and sc.doc.Write3dmFile(backup,opts)
    sc.sticky[TAG]=dict(before=fingerprint(),parts=[],objects=[],backup=backup,materials={},
        ramp=mesh_of(sc.doc.Objects.FindId(System.Guid(RAMP)).Geometry),
        bed=mesh_of(sc.doc.Objects.FindId(System.Guid(BED)).Geometry),
        original_view=Rhino.DocObjects.ViewportInfo(sc.doc.Views.ActiveView.ActiveViewport))
    write('parameters.json',dict(feature=TAG,config=CONFIG,ramp_id=RAMP,lake_bed_id=BED,
        main_profile='Cubic radial rolled shell: foot, vertical flank, rolled roof and inner eave',
        vault_profile='Asymmetric cubic transverse rolled shell, flared curved ends over unchanged exit ramp',
        reference='concept_A.png; interpret geometry to fit the actual site and cross the ramp',
        units='Meters',backup=backup))
    return dict(backup=backup,existing_objects=len(state()['before']))

def epoint(a,rx,ry,z,cx=555.,cy=510.):
    a=math.radians(a);return G.Point3d(cx+rx*math.cos(a),cy+ry*math.sin(a),z)
def height(a):
    t=(a-72.)/198.
    return 3.7+10.5*math.sin(math.pi*max(0.,min(1.,t)))**.65
def main(a,v):
    angle=math.radians(a);h=height(a)
    q=cubic([G.Point3d(1.,0,-.85),G.Point3d(1.01,0,h*.68),
             G.Point3d(.85,0,h*1.06),G.Point3d(.61,0,h)],v)
    return G.Point3d(555.+36.*q.X*math.cos(angle)+1.0*v*v,
                    510.+31.*q.X*math.sin(angle),q.Z)
def top_v(a):
    # Two coherent torn-back roof zones, not random teeth or scattered debris.
    knots=[(72,1),(116,1),(119,.96),(122,.98),(124,.55),(129,.58),(131,.49),
           (134,.53),(136,.94),(139,1),(221,1),(224,.92),(227,.96),
           (229,.70),(233,.72),(235,.66),(238,.75),(240,.98),(243,1),(270,1)]
    for (aa,vv),(bb,ww) in zip(knots[:-1],knots[1:]):
        if a<=bb:return mix(vv,ww,(a-aa)/(bb-aa))
    return 1.
def skin(fn,nu,nv,thickness,vertical=False):
    m=G.Mesh();stride=nv+1;layer=(nu+1)*stride
    for side in [-1,1]:
        for i in range(nu+1):
            for j in range(nv+1):
                u=i/nu;v=j/nv;p=fn(u,v)
                n=G.Vector3d.ZAxis if vertical else unit(G.Vector3d.CrossProduct(fn(u+.0001,v)-fn(u-.0001,v),fn(u,v+.0001)-fn(u,v-.0001)))
                m.Vertices.Add(p+n*(side*thickness/2))
    for i in range(nu):
        for j in range(nv):
            k=i*stride+j;m.Faces.AddFace(k,k+stride,k+stride+1,k+1)
            k+=layer;m.Faces.AddFace(k,k+1,k+stride+1,k+stride)
    for i in range(nu):
        for j in [0,nv]:
            k=i*stride+j;m.Faces.AddFace(k,k+stride,k+stride+layer,k+layer)
    for i in [0,nu]:
        for j in range(nv):
            k=i*stride+j;m.Faces.AddFace(k,k+1,k+1+layer,k+layer)
    return finish(m)
def beam(fn,t0,t1,width,depth,n=70):
    m=G.Mesh()
    for i in range(n+1):
        t=mix(t0,t1,i/n);p=fn(t);tangent=unit(fn(t+.0001)-fn(t-.0001))
        side=G.Vector3d.CrossProduct(tangent,G.Vector3d.ZAxis)
        if not side.Unitize():side=G.Vector3d.XAxis
        up=unit(G.Vector3d.CrossProduct(side,tangent))
        for a,b in [(-1,-1),(1,-1),(1,1),(-1,1)]:m.Vertices.Add(p+side*(a*width/2)+up*(b*depth/2))
    for i in range(n):
        for j in range(4):
            k=4*i+j;l=4*i+(j+1)%4;m.Faces.AddFace(k,l,l+4,k+4)
    m.Faces.AddFace(3,2,1,0);k=n*4;m.Faces.AddFace(k,k+1,k+2,k+3)
    return finish(m)
def floor_band(a0,a1,outer,inner,z0=.28,z1=.28,n=120):
    m=G.Mesh();rows=[]
    for i in range(n+1):
        t=i/n;a=mix(a0,a1,t);z=mix(z0,z1,smooth(t))
        rows.append([epoint(a,outer[0],outer[1],z),epoint(a,inner[0],inner[1],z)])
    for level in range(2):
        for row in rows:
            for p in row:m.Vertices.Add(p if level==0 else G.Point3d(p.X,p.Y,terrain(p.X,p.Y)-.24))
    count=2*(n+1)
    for i in range(n):
        k=2*i;m.Faces.AddFace(k,k+1,k+3,k+2);m.Faces.AddFace(k+count,k+2+count,k+3+count,k+1+count)
        m.Faces.AddFace(k,k+2,k+2+count,k+count);m.Faces.AddFace(k+1,k+1+count,k+3+count,k+3)
    m.Faces.AddFace(0,count,count+1,1);k=2*n;m.Faces.AddFace(k,k+1,k+1+count,k+count)
    return finish(m)
def vault(u,v):
    y=mix(520.,551.,u)+8.0*math.sin(math.pi*v)*(2.*u-1.)
    outer=622.+1.4*math.sin(math.pi*u)
    inner=576.+3.0*math.sin(math.pi*u)
    h=mix(8.5,9.4,u)+2.8*math.sin(math.pi*u)
    q=cubic([G.Point3d(1.,0,-.85),G.Point3d(1.10,0,h*1.25),
             G.Point3d(.17,0,h*1.50),G.Point3d(0.,0,-.85)],v)
    return G.Point3d(mix(inner,outer,q.X),y,q.Z)
def vault_top(u):
    # A longitudinal missing roof wedge leaves one exposed arched rib.
    if .63<u<.78:return .67+.04*math.sin((u-.63)/.15*math.pi)
    if u<.18:return .79+.21*smooth(u/.18)
    return 1.
def connect_deck():
    # A low solid curved promenade joins the water court to the new vault foot;
    # it stops west of the original 14 m exit ramp, never paving over it.
    pts=[G.Point3d(558,534,-.32),G.Point3d(565,533,-.32),G.Point3d(576,530,-.32),G.Point3d(579,525,-.32)]
    return beam(lambda t:cubic(pts,t),0,1,3.2,1.20,65)
def build():
    d=state();assert not d['parts'] and not d['objects']
    stage(skin(lambda u,v:main(mix(72.,270.,u),v*top_v(mix(72.,270.,u))),260,34,.24),
          'Main_rolled_crescent_shell','01_shells','ivory')
    stage(skin(lambda u,v:vault(u,v*vault_top(u)),125,64,.22),
          'Continuous_ramp_crossing_shell','01_shells','ivory')
    # Dark slender manufactured edge members reveal the original structure.
    stage(beam(lambda t:main(mix(72.,270.,t),top_v(mix(72.,270.,t))),0,1,.16,.22,240),
          'Main_exposed_eave_rib','03_structure','steel')
    for a in [72.,152.,209.,270.]:
        stage(beam(lambda t,a=a:main(a,t),0,1,.14,.22,65),'Main_curved_frame_%03d'%a,'03_structure','steel')
    for i,u in enumerate([0.,.68,1.]):
        stage(beam(lambda t,u=u:vault(u,t),0,1,.15,.26,100),'Vault_continuous_arch_rib_%d'%i,'03_structure','steel')
    # Thin slab edges; the flooded central courtyard remains the original water.
    stage(floor_band(80,215,(25.8,21.8),(20.8,16.8)),'Crescent_dry_gallery','02_platforms','deck')
    stage(floor_band(220,270,(25.8,21.8),(21.2,17.2),.28,-.40),'Broken_gallery_dipping_into_water','02_platforms','deck')
    stage(connect_deck(),'Low_curved_court_connection','02_platforms','deck')
    # Curved blue glass remains in coherent groups under the main rolled eave.
    glazing=[(82,98,1.),(99,114,.78),(145,164,1.),(165,181,.86),(182,202,1.),(203,218,.72)]
    for i,(a0,a1,top) in enumerate(glazing):
        def pane(u,v,a0=a0,a1=a1,top=top):
            a=mix(a0,a1,u);roof=main(a,1.)
            # Some panes have a slanted missing top edge, all remain on a base.
            h=(roof.Z-.12)*min(1.,top+.12*u)
            return G.Point3d(roof.X,roof.Y,mix(.30,h,v))
        stage(skin(pane,32,5,.045),'Curved_glass_remnant_%02d'%i,'04_glazing','glass')
    for a in [82,114,145,181,202,218]:
        p=main(a,1.)
        stage(beam(lambda t,p=p:G.Point3d(p.X,p.Y,mix(.25,p.Z-.12,t)),0,1,.075,.095,4),
              'Glazing_mullion_%03d'%a,'03_structure','dark')
    # Only four large panel seams; avoid a tiled facade appearance.
    for a in [100.,165.,202.,253.]:
        def seam(t,a=a):
            p=main(a,t);du=main(a+.001,t)-main(a-.001,t);dv=main(a,t+.0001)-main(a,t-.0001)
            return p+unit(G.Vector3d.CrossProduct(du,dv))*.126
        stage(beam(seam,.02,min(.985,top_v(a)),.023,.012,65),'Shell_expansion_joint_%03d'%a,'05_joints','joint')
    # Native floor support under the vault's two curved springing lines.
    for v in [0.,1.]:
        stage(beam(lambda u,v=v:vault(u,v)+G.Vector3d(0,0,.20),0,1,.65,.55,80),
              'Submerged_shell_footing_%d'%v,'06_foundations','deck')
    return dict(parts=len(d['parts']),main_height_m=14.2,vault_height_m=11.8,
                existing_ramp_retained=True,plants_added=0)

def check_site():
    d=state();assert d['parts']
    ramp=d['ramp'];collisions=[];combined=G.Mesh();bounds=G.BoundingBox.Empty;triangle_count=0
    for geo,name,cat,mat in d['parts']:
        m=mesh_of(geo);bounds.Union(m.GetBoundingBox(True));triangle_count+=m.Faces.TriangleCount+2*m.Faces.QuadCount
        hits=G.Intersect.Intersection.MeshMeshFast(m,ramp)
        if hits and len(hits):collisions.append(name)
        combined.Append(m)
    assert not collisions,'Original ramp intersects new structure: '+str(collisions)
    combined.Normals.ComputeNormals();headroom=[];ramp_stations=[]
    for y in range(518,555,2):
        t=(y-500.)/240.;x=600.-9.*math.sin(math.pi*t)**2
        for dx in [-7.,-3.5,0.,3.5,7.]:
            origin=G.Point3d(x+dx,y,20.)
            hit=G.Intersect.Intersection.MeshRay(ramp,G.Ray3d(origin,-G.Vector3d.ZAxis))
            assert hit>=0,'Missing ramp in measurement'
            z=20.-hit;p=G.Point3d(x+dx,y,z+.03)
            up=G.Intersect.Intersection.MeshRay(combined,G.Ray3d(p,G.Vector3d.ZAxis))
            if up>=0:
                headroom.append(up+.03);assert up+.03>5.,'Insufficient underpass headroom'
            ramp_stations.append(dict(point=[x+dx,y,z],headroom_m=up+.03 if up>=0 else None))
    assert len(headroom)>30,'Canopy must actually cross the ramp'
    # Ground level against the two shell springing curves (not overhead roofs).
    feet=[]
    for i in range(17):
        for p in [main(mix(72.,270.,i/16.),0),vault(i/16.,0),vault(i/16.,1)]:
            bed=terrain(p.X,p.Y);embed=bed-p.Z
            assert embed>.05,'Floating shell foot'
            feet.append(dict(point=xyz(p),bed_z=bed,embed_m=embed))
    report=dict(ramp_id=RAMP,ramp_intersections=collisions,ramp_width_m=14.,
        underpass_minimum_headroom_m=min(headroom),covered_ramp_samples=len(headroom),
        ramp_samples=ramp_stations,grounded_shell_samples=feet,
        bounds_native=[xyz(bounds.Min),xyz(bounds.Max)],mesh_triangles=triangle_count,
        main_height_above_water_m=14.2,water_z=0.,plants_added=0,existing_terrain_edited=False)
    d['site_report']=report;write('site_check.json',report)
    return {k:report[k] for k in ['ramp_intersections','underpass_minimum_headroom_m','covered_ramp_samples','bounds_native','mesh_triangles']}
def layer(path):
    idx=sc.doc.Layers.FindByFullPath(path,-1)
    if idx>=0:return idx
    parent=System.Guid.Empty
    if '::' in path:parent=sc.doc.Layers[layer(path.rsplit('::',1)[0])].Id
    item=Rhino.DocObjects.Layer();item.Name=path.rsplit('::',1)[-1];item.ParentLayerId=parent
    return sc.doc.Layers.Add(item)
def material(key,rgb,rough,metal,opacity=1.):
    name='PR_WaterCourt_'+key
    for i,m in enumerate(sc.doc.Materials):
        if m.Name==name:return i
    m=Rhino.DocObjects.Material();m.Name=name;m.DiffuseColor=Color.FromArgb(*rgb);m.Transparency=1-opacity
    m.ToPhysicallyBased();p=m.PhysicallyBased
    p.BaseColor=Rhino.Display.Color4f(rgb[0]/255.,rgb[1]/255.,rgb[2]/255.,1.)
    p.Roughness=rough;p.Metallic=metal;p.Opacity=opacity
    if key=='glass':p.OpacityIOR=1.46
    return sc.doc.Materials.Add(m)
def commit():
    d=state();assert d.get('site_report') and not d['objects']
    before=fingerprint();assert before==d['before'],'Scene changed during staging; inspect before commit'
    record=sc.doc.BeginUndoRecord('Shallow water shell court across existing ramp');sc.doc.Views.RedrawEnabled=False
    try:
        for key,rgb,rough,metal,opacity in [('ivory',(228,224,211),.68,.04,1.),('deck',(205,203,185),.82,0.,1.),
                ('steel',(137,106,81),.69,.40,1.),('dark',(66,72,70),.50,.50,1.),
                ('glass',(134,180,185),.17,0.,.35),('joint',(153,151,136),.91,0.,1.)]:
            d['materials'][key]=material(key,rgb,rough,metal,opacity)
        for geo,name,cat,mat in d['parts']:
            at=Rhino.DocObjects.ObjectAttributes();at.Name='PR_WaterCourt_'+name
            at.LayerIndex=layer(LAYER+'::'+cat);at.MaterialIndex=d['materials'][mat]
            at.MaterialSource=Rhino.DocObjects.ObjectMaterialSource.MaterialFromObject
            at.ObjectColor=sc.doc.Materials[at.MaterialIndex].DiffuseColor
            at.SetUserString('feature',TAG);at.SetUserString('category',cat);at.SetUserString('material_key',mat)
            at.SetUserString('generator','tools/rhino_water_court_1101.py')
            sid=sc.doc.Objects.Add(geo,at);assert sid!=System.Guid.Empty;d['objects'].append(str(sid))
        group=sc.doc.Groups.Add('PR_WaterCourt_1101',[System.Guid(sid) for sid in d['objects']])
        assert group>=0
    except:
        for sid in d['objects']:sc.doc.Objects.Delete(System.Guid(sid),True)
        d['objects']=[];raise
    finally:sc.doc.EndUndoRecord(record);sc.doc.Views.RedrawEnabled=True;sc.doc.Views.Redraw()
    return dict(objects=len(d['objects']),layer=LAYER)
def audit():
    d=state();now=fingerprint();changed=[sid for sid,record in d['before'].items() if now.get(sid)!=record]
    assert not changed,'Unrelated source changed'
    owned=[o for o in objects() if o.Attributes.GetUserString('feature')==TAG]
    assert set(str(o.Id) for o in owned)==set(d['objects'])
    for o in owned:
        assert o.Geometry.IsValid and o.Geometry.IsClosed,o.Name
        assert G.VolumeMassProperties.Compute(o.Geometry).Volume>0,o.Name
    report=dict(feature=TAG,objects=len(owned),object_ids=d['objects'],unrelated_objects_unchanged=len(d['before']),
                unrelated_changes=changed,site=d['site_report'],backup=d['backup'],game_imported=False)
    write('model_report.json',report)
    return dict(objects=len(owned),unrelated_objects_unchanged=len(d['before']),ramp_unchanged=True)
def camera(name='overview'):
    views={'overview':((680,385,140),(567,516,6),42.),
           'court':((559,448,12),(553,519,6.5),31.),
           'underpass':((600,495,3.2),(599,548,3.6),30.),
           'site':((900,230,420),(580,570,12),40.)}
    eye,target,lens=views[name];vp=sc.doc.Views.ActiveView.ActiveViewport
    vp.SetCameraLocations(G.Point3d(*target),G.Point3d(*eye));vp.Camera35mmLensLength=lens
    sc.doc.Objects.UnselectAll();sc.doc.Views.Redraw()
def capture(name='overview'):
    camera(name);vc=Rhino.Display.ViewCapture();vc.Width=1700;vc.Height=1050
    vc.DrawAxes=False;vc.DrawGrid=False;vc.DrawGridAxes=False;vc.ScaleScreenItems=False
    bmp=vc.CaptureToBitmap(sc.doc.Views.ActiveView);assert bmp
    path=OUT+'/model_'+name+'.png';bmp.Save(path,System.Drawing.Imaging.ImageFormat.Png);bmp.Dispose();return path
def save():
    audit();d=state();path=OUT+'/water_court.3dm';assert not os.path.exists(path)
    opts=Rhino.FileIO.FileWriteOptions();opts.SuppressDialogBoxes=True;opts.WriteSelectedObjectsOnly=True
    sc.doc.Objects.UnselectAll()
    try:
        for sid in d['objects']:sc.doc.Objects.Select(System.Guid(sid))
        assert sc.doc.Write3dmFile(path,opts)
    finally:sc.doc.Objects.UnselectAll()
    for name in ['overview','court','underpass','site']:
        camera(name);sc.doc.NamedViews.Add('WaterCourt_'+name+'_1101',sc.doc.Views.ActiveView.ActiveViewport.Id)
    camera('overview')
    assert Rhino.RhinoApp.RunScript('_-Save _Enter',False) and not sc.doc.Modified
    saved=Rhino.FileIO.File3dm.Read(sc.doc.Path);assert saved
    assert set(str(o.Id) for o in saved.Objects if o.Attributes.GetUserString('feature')==TAG)==set(d['objects'])
    component=Rhino.FileIO.File3dm.Read(path);assert component and len(list(component.Objects))==len(d['objects'])
    return dict(main=sc.doc.Path,component=path,objects=len(d['objects']),saved_readback=True)
