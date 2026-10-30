# -*- coding: utf-8 -*-
"""Native annular pavilion, opposed portals and low terrain. Run staged in Rhino.

Angles are relative to the cave-facing axis. Source map geometry is read-only;
all new objects are tagged, so revisions can target this feature precisely.
"""
from __future__ import unicode_literals, division
import Rhino, scriptcontext as sc, System, math, io, json, os
from System.Drawing import Color
G = Rhino.Geometry
ROOT = 'D:/Prism Route/prism-route'
OUT = ROOT+'/docs/upper_ring_pavilion_1030'
CACHE = ROOT+'/.current_map_build'
TAG = 'upper_ring_pavilion_1030'
LAYER = '\u5efa\u7b51::\u4e0a\u5c42\u73af\u5ead\u9057\u5740'
CX, CY = 510., 115.
BASE, FLOOR, ROOF = 70., 70.08, 76.18
THETA = math.atan2(-368.44157405747984-CY,651.1922449843955-CX)
RO, RI = 52., 27.
PLAN_SCALE = 1.4

def state(): return sc.sticky[TAG]
def xyz(p): return [float(p.X),float(p.Y),float(p.Z)]
def smooth(t):
    t=max(0.,min(1.,t));return t*t*t*(10.-15.*t+6.*t*t)
def point(r,a,z):
    t=THETA+math.radians(a)
    return G.Point3d(CX+r*math.cos(t),CY+r*math.sin(t),z)
def vec(a):
    t=THETA+math.radians(a);return G.Vector3d(math.cos(t),math.sin(t),0)
def write(name,value):
    with io.open(OUT+'/'+name,'w',encoding='utf-8') as f:f.write(json.dumps(value,ensure_ascii=False,indent=2))
def fingerprint():
    return dict((str(o.Id),int(o.Geometry.DataCRC(0))) for o in sc.doc.Objects)
def layer(path):
    idx=sc.doc.Layers.FindByFullPath(path,-1)
    if idx>=0:return idx
    parent=System.Guid.Empty
    if '::' in path:parent=sc.doc.Layers[layer(path.rsplit('::',1)[0])].Id
    item=Rhino.DocObjects.Layer();item.Name=path.rsplit('::',1)[-1];item.ParentLayerId=parent
    return sc.doc.Layers.Add(item)
def material(name,rgb,roughness,metal=0.,opacity=1.):
    mat=Rhino.DocObjects.Material();mat.Name='PR_Ring_'+name
    mat.DiffuseColor=Color.FromArgb(*rgb);mat.Transparency=1-opacity
    mat.ToPhysicallyBased();p=mat.PhysicallyBased
    p.BaseColor=Rhino.Display.Color4f(rgb[0]/255.,rgb[1]/255.,rgb[2]/255.,1.)
    p.Roughness=roughness;p.Metallic=metal;p.Opacity=opacity
    return sc.doc.Materials.Add(mat)
def add(geometry,name,category,mat='ivory'):
    assert geometry and geometry.IsValid,'Invalid geometry: '+name
    if category not in ['terrain','08_paths']:
        geometry=geometry.Duplicate()
        geometry.Transform(G.Transform.Scale(G.Plane(G.Point3d(CX,CY,0),G.Vector3d.ZAxis),PLAN_SCALE,PLAN_SCALE,1.))
    at=Rhino.DocObjects.ObjectAttributes();at.Name='PR_Ring_'+name
    path=(u'\u624b\u5de5\u5730\u5f62::\u73af\u5ead\u7f13\u4e18' if category=='terrain' else LAYER+'::'+category)
    at.LayerIndex=layer(path);at.MaterialIndex=state()['materials'][mat]
    at.MaterialSource=Rhino.DocObjects.ObjectMaterialSource.MaterialFromObject
    at.ObjectColor=sc.doc.Materials[at.MaterialIndex].DiffuseColor
    at.SetUserString('feature',TAG);at.SetUserString('category',category)
    gid=sc.doc.Objects.Add(geometry,at);assert gid!=System.Guid.Empty
    state()['objects'].append(str(gid));state()['categories'][category]=state()['categories'].get(category,0)+1
    return gid
def solid(b):
    assert b and b.IsValid and b.IsSolid,'Expected closed solid'
    if b.SolidOrientation==G.BrepSolidOrientation.Inward:b.Flip()
    return b
def prism(poly,height):
    curve=G.PolylineCurve(poly+[poly[0]])
    return solid(G.Extrusion.Create(curve,height,True).ToBrep())
def sector(r0,r1,a0,a1,z,thickness):
    plane=G.Plane(G.Point3d(CX,CY,z),G.Vector3d.ZAxis)
    start=THETA+math.radians(a0);end=THETA+math.radians(a1)
    outer=G.Arc(G.Circle(plane,r1),G.Interval(start,end)).ToNurbsCurve()
    inner=G.Arc(G.Circle(plane,r0),G.Interval(start,end)).ToNurbsCurve();inner.Reverse()
    c=G.PolyCurve();c.Append(outer);c.Append(G.LineCurve(outer.PointAtEnd,inner.PointAtStart));c.Append(inner);c.Append(G.LineCurve(inner.PointAtEnd,outer.PointAtStart))
    assert c.IsClosed
    return solid(G.Extrusion.Create(c,thickness,True).ToBrep())
def beam(a,b,width,depth):
    axis=b-a;length=axis.Length;axis.Unitize()
    x=G.Vector3d.CrossProduct(axis,G.Vector3d.ZAxis)
    if not x.Unitize():x=G.Vector3d.XAxis
    y=G.Vector3d.CrossProduct(axis,x);y.Unitize()
    return G.Box(G.Plane(a,x,y),G.Interval(-width/2,width/2),G.Interval(-depth/2,depth/2),G.Interval(0,length)).ToBrep()
def damage(a):
    a=a%360
    return 12<a<67 or 83<a<102
def portal(a):
    return min(abs((a+180)%360-180),abs((a-180+180)%360-180))<11

def prepare():
    assert TAG not in sc.sticky,'Feature already initialized; do not duplicate it'
    before=fingerprint()
    options=Rhino.FileIO.FileWriteOptions();options.SuppressDialogBoxes=True
    backup=CACHE+'/before_upper_ring_pavilion_1030.3dm'
    assert not os.path.exists(backup),'Keep existing backup; inspect before starting another build'
    assert sc.doc.Write3dmFile(backup,options),'Backup failed'
    sc.sticky[TAG]={'before':before,'objects':[],'categories':{},'materials':{},'backup':backup,'document':sc.doc.Path}
    d=state()
    for key,color,rough,metal,opacity in [
        ('ivory',(228,224,211),.78,0.,1.),('steel',(145,94,66),.84,.18,1.),
        ('frame',(73,65,58),.72,.35,1.),('glass',(102,139,145),.24,0.,.70),
        ('ground',(166,178,138),.96,0.,1.),('soil',(104,119,76),1.,0.,1.),
        ('water',(80,139,146),.18,0.,.75),('stone',(184,180,159),.92,0.,1.),
        ('leaf',(115,139,77),.96,0.,1.),('leaf_light',(145,160,94),.96,0.,1.)]:
        d['materials'][key]=material(key,color,rough,metal,opacity)
    d['host']=sc.sticky['ring_site_top_mesh_1030'];d['roads']=sc.sticky['ring_site_road_mesh_1030']
    d['edges']=[]
    for poly in d['host'].GetNakedEdges():
        for i in range(poly.Count-1):d['edges'].append((poly[i],poly[i+1]))
    write('parameters.json',{'center':[CX,CY],'roof_outer_radius':RO*PLAN_SCALE,'courtyard_radius':RI*PLAN_SCALE,'floor':FLOOR,'roof':ROOF,'front_axis_degrees':math.degrees(THETA),'opposed_entrances':[0,180],
        'hills':[{'center':[CX,CY],'crest_z':BASE,'radius':[115*PLAN_SCALE,105*PLAN_SCALE],'flat_crest_radius':54*PLAN_SCALE}, {'center':[350,265],'rise':5.2,'radius':[90,85]}, {'center':[470,270],'rise':4.2,'radius':[65,65]}],
        'steel':{'base_color_srgb':[145,94,66],'roughness':.84,'metallic':.18,'textured':False}})
    return {'backup':backup,'original_objects':len(before),'roof_diameter':RO*PLAN_SCALE*2,'floor':FLOOR,'roof':ROOF}

def host_z(x,y):
    t=G.Intersect.Intersection.MeshRay(state()['host'],G.Ray3d(G.Point3d(x,y,200),G.Vector3d(0,0,-1)))
    return 200-t if t>=0 else None
def edge_distance(x,y):
    best=1e20
    for a,b in state()['edges']:
        dx=b.X-a.X;dy=b.Y-a.Y
        t=max(0.,min(1.,((x-a.X)*dx+(y-a.Y)*dy)/max(.0001,dx*dx+dy*dy)))
        best=min(best,(x-a.X-t*dx)**2+(y-a.Y-t*dy)**2)
    return math.sqrt(best)
def ground_z(x,y):
    base=host_z(x,y)
    if base is None:return None
    r=math.sqrt((x-CX)**2+((y-CY)*115/105.)**2)
    main=max(0,BASE-base)*(1-smooth((r-54*PLAN_SCALE)/((115-54)*PLAN_SCALE)))
    secondary=[]
    for xx,yy,rx,ry,h in [(350,265,90,85,5.2),(470,270,65,65,4.2)]:
        q=math.sqrt(((x-xx)/rx)**2+((y-yy)/ry)**2)
        secondary.append(h*(1-smooth(q)))
    rise=max([main]+secondary)
    if rise<.00001:return base
    road=state()['roads'].ClosestPoint(G.Point3d(x,y,base))
    # Slope-limited shoulders: multiplying a tall hill by a narrow edge mask
    # creates a steep lip. Bound the rise by the available run instead.
    road_run=max(0.,road.DistanceTo(G.Point3d(x,y,base))-3)
    edge_run=max(0.,edge_distance(x,y)-4)
    return base+min(rise,road_run*.24,edge_run*.24)

def terrain():
    m=G.Mesh();lookup={};active={};samples=[]
    step=2.5;xs=[255+i*step for i in range(179)];ys=[5+i*step for i in range(143)]
    for i,x in enumerate(xs):
        for j,y in enumerate(ys):
            z=ground_z(x,y)
            if z is None:continue
            base=host_z(x,y);lookup[(i,j)]=m.Vertices.Add(x,y,z+.015);active[(i,j)]=z-base>.015
    for i in range(len(xs)-1):
        for j in range(len(ys)-1):
            cells=[(i,j),(i+1,j),(i+1,j+1),(i,j+1)]
            if all(k in lookup for k in cells) and any(active[k] for k in cells):m.Faces.AddFace(*[lookup[k] for k in cells])
    m.Vertices.CullUnused();m.Normals.ComputeNormals();m.Compact()
    add(m,'ThreeGentleHills','terrain','ground')
    for x,y in [(CX,CY),(350,265),(470,270)]:samples.append({'xy':[x,y],'original_z':host_z(x,y),'new_z':ground_z(x,y)})
    write('terrain_samples.json',samples)
    return {'faces':m.Faces.Count,'crests':samples}

def shell():
    for i in range(36):
        a=i*10
        add(sector(26,49.5,a,a+10,FLOOR-.58,.58),'Foundation_%02d'%i,'01_foundation')
        if not damage(a+5):add(sector(RI,RO,a+.06,a+9.94,ROOF,.44),'RoofPanel_%02d'%i,'03_roof')
        # Inner and outer beams remain even where cladding has disappeared.
        for r in [27.3,49.4]:add(sector(r-.18,r+.18,a,a+10,ROOF-.30,.38),'RingBeam_%g_%02d'%(r,i),'04_steel_skeleton','steel')
        add(beam(point(27.3,a,ROOF-.24),point(49.4,a,ROOF-.24),.30,.48),'RadialBeam_%02d'%i,'04_steel_skeleton','steel')
        if damage(a+5):
            for r in [33,39,45]:add(sector(r-.08,r+.08,a,a+10,ROOF-.14,.19),'ExposedPurlin_%g_%02d'%(r,i),'04_steel_skeleton','frame')
            # Remaining short skin tongues make loss read as a designed panel failure.
            if i in [1,6,8,10]:add(sector(27,31 if i%2 else 34,a+.1,a+6,ROOF,.44),'BrokenRoofTongue_%02d'%i,'03_roof')
    for r in [26.25,48.75]:
        for i in range(36):
            a=i*10
            if portal(a+5):continue
            add(sector(r-.16,r+.16,a,a+10,FLOOR,.35),'FacadeSill_%g_%d'%(r,i),'02_floor_edges')
    return dict(state()['categories'])

def facades():
    for i in range(36):
        a=i*10
        if portal(a):continue
        radial=vec(a);tangent=vec(a+90)
        distance=min(abs((a+180)%360-180),abs(a-180))
        strength=1-smooth((distance-15)/65.)
        sections=[]
        for t in [0,.12,.32,.58,.82,1]:
            r=48.-1.55*math.sin(math.pi*t)+1.6*t**4
            center=point(r,a,FLOOR+t*(ROOF-FLOOR-.15))
            twist=math.radians(18*strength*math.sin(math.pi*t))
            u=tangent*math.cos(twist)+radial*math.sin(twist)
            v=radial*math.cos(twist)-tangent*math.sin(twist)
            width=.34+.10*strength;depth=1.15+1.1*strength
            poly=[center-u*width/2-v*depth/2,center+u*width/2-v*depth/2,center+u*width/2+v*depth/2,center-u*width/2+v*depth/2]
            sections.append(G.PolylineCurve(poly+[poly[0]]))
        result=G.Brep.CreateFromLoft(sections,G.Point3d.Unset,G.Point3d.Unset,G.LoftType.Normal,False)
        rib=solid(result[0].CapPlanarHoles(.001))
        add(rib,'ParametricFin_%02d'%i,'05_parametric_fins','steel' if damage(a) else 'ivory')
        for z in [FLOOR+.05,ROOF-.42]:
            p=point(48. if z<FLOOR+1 else 49.2,a,z)
            add(prism([p-tangent*.38-radial*.8,p+tangent*.38-radial*.8,p+tangent*.38+radial*.8,p-tangent*.38+radial*.8],.12),'FinConnection_%02d_%g'%(i,z),'04_steel_skeleton','steel')
    # Matching clear portals through both outer and inner facades, opposite each other.
    for i in range(72):
        a=i*5;mid=a+2.5
        if portal(mid):continue
        for radius in [27.6,47.3]:
            if radius>40 and damage(mid):continue
            add(sector(radius-.055,radius+.055,a+.3,a+4.7,FLOOR+.38,5.1),'Glazing_%g_%02d'%(radius,i),'06_glazing','glass')
        if i%2==0:
            add(beam(point(27.6,a,FLOOR),point(27.6,a,ROOF),.24,.24),'CourtyardPost_%02d'%i,'04_steel_skeleton','steel')
    # A partial solid wall gives intact-vs-open contrast without enclosing either portal.
    for a in range(235,286,10):add(sector(46.9,47.45,a,a+7,FLOOR,5.55),'IntactComposite_%03d'%a,'07_wall_panels')
    return dict(state()['categories'])

def walk_z(x,y):
    z=ground_z(x,y)
    if z is not None:return z
    t=G.Intersect.Intersection.MeshRay(state()['roads'],G.Ray3d(G.Point3d(x,y,200),G.Vector3d(0,0,-1)))
    if t>=0:return 200-t
    # The original road trim leaves a 1.3 m reveal next to the terrain skin.
    # Only the short, supported threshold apron bridges that narrow reveal.
    p=G.Point3d(x,y,60.4)
    a=state()['host'].ClosestPoint(p);b=state()['roads'].ClosestPoint(p)
    da=math.hypot(x-a.X,y-a.Y);db=math.hypot(x-b.X,y-b.Y)
    if da<2 and db<2 and abs(a.Z-b.Z)<.3:
        return (a.Z*db+b.Z*da)/max(.0001,da+db)
    return None

def remove_category(category):
    d=state();removed=[]
    for sid in d['objects']:
        o=sc.doc.Objects.FindId(System.Guid(sid))
        if o and o.Attributes.GetUserString('category')==category:
            assert o.Attributes.GetUserString('feature')==TAG
            sc.doc.Objects.Delete(o.Id,True);removed.append(sid)
    for sid in removed:d['objects'].remove(sid)
    d['categories'][category]=0

def path_mesh(points,width,name):
    m=G.Mesh();stations=[]
    for i,p in enumerate(points):
        direction=points[min(i+1,len(points)-1)]-points[max(0,i-1)];direction.Z=0;direction.Unitize()
        if points[0].DistanceTo(points[-1])<.001 and i in [0,len(points)-1]:
            direction=points[1]-points[-2];direction.Z=0;direction.Unitize()
        side=G.Vector3d(-direction.Y,direction.X,0)*width/2
        for q in [p-side,p+side]:
            z=walk_z(q.X,q.Y);assert z is not None,'Path leaves supported plateau: '+name+' '+str(xyz(q))
            # Last metres meet the slab gently, rather than adding visible stairs.
            r=math.sqrt((q.X-CX)**2+(q.Y-CY)**2)
            z=max(z,FLOOR*(1-smooth((r-48*PLAN_SCALE)/(8*PLAN_SCALE)))+z*smooth((r-48*PLAN_SCALE)/(8*PLAN_SCALE))) if r<56*PLAN_SCALE else z
            m.Vertices.Add(q.X,q.Y,z+.06)
        stations.append(xyz(G.Point3d(p.X,p.Y,walk_z(p.X,p.Y))))
        if i:m.Faces.AddFace(i*2-2,i*2-1,i*2+1,i*2)
    count=m.Vertices.Count
    for i in range(count):
        q=m.Vertices[i];m.Vertices.Add(q.X,q.Y,q.Z-.18)
    for i in range(len(points)-1):
        a=i*2;b=a+2
        m.Faces.AddFace(a+count,b+count,b+1+count,a+1+count)
        m.Faces.AddFace(a,b,a+count+2,a+count)
        m.Faces.AddFace(a+1,a+1+count,b+1+count,b+1)
    if points[0].DistanceTo(points[-1])>.001:
        m.Faces.AddFace(0,count,count+1,1)
        m.Faces.AddFace(count-2,count-1,2*count-1,2*count-2)
    m.Vertices.CombineIdentical(True,True);m.Normals.ComputeNormals();m.Compact()
    assert m.IsClosed,'Path slab is not closed: '+name
    if m.SolidOrientation()<0:m.Flip(True,True,True)
    m.Unweld(math.radians(50),True)
    add(m,name,'08_paths','stone')
    state().setdefault('routes',{})[name]=stations
def paths():
    remove_category('08_paths')
    path_mesh([point(70*PLAN_SCALE,i*1.5,0) for i in range(241)],3.2,'ContourLoop')
    for a in [0,180]:path_mesh([point(r*PLAN_SCALE,a,0) for r in range(47,72,2)],5.0,'PortalApron_%03d'%a)
    start=point(70*PLAN_SCALE,180,0)
    curve=G.Curve.CreateInterpolatedCurve([start,G.Point3d(510,205,0),G.Point3d(535,215,0),G.Point3d(554,222,0)],3)
    pts=[curve.PointAt(curve.Domain.ParameterAt(i/35.)) for i in range(36)]
    path_mesh(pts,4.0,'RearRoadConnection')
    write('walking_routes.json',state()['routes'])
    return {'routes':len(state()['routes'])}

def garden():
    # Courtyard floor with a clear diametric circulation strip between both portals.
    add(sector(.01,26,0,180,FLOOR-.15,.15),'CourtFloor_A','09_courtyard','stone')
    add(sector(.01,26,180,360,FLOOR-.15,.15),'CourtFloor_B','09_courtyard','stone')
    for i,(a0,a1,r0,r1) in enumerate([(26,88,8,20),(101,151,13,23),(207,259,9,22)]):
        add(sector(r0,r1,a0,a1,FLOOR,.37),'GardenSoil_%d'%i,'09_courtyard','soil')
        for r in [r0,r1]:add(sector(r-.16,r+.16,a0,a1,FLOOR,.52),'PlanterRim_%d_%g'%(i,r),'09_courtyard','steel')
        for a in [a0,a1]:add(beam(point(r0,a,FLOOR+.26),point(r1,a,FLOOR+.26),.32,.52),'PlanterEnd_%d_%g'%(i,a),'09_courtyard','steel')
    add(sector(7,21,285,332,FLOOR,.12),'ReflectingWater','09_courtyard','water')
    for r in [6.8,21.2]:add(sector(r-.15,r+.15,284,333,FLOOR,.22),'PoolRim_%g'%r,'09_courtyard')
    for i,a in enumerate([68,129,236]):
        add(sector(23.5,25,a-10,a+10,FLOOR+.38,.18),'CurvedBench_%d'%i,'09_courtyard')
        for angle in [a-7,a+7]:add(beam(point(24.2,angle,FLOOR),point(24.2,angle,FLOOR+.4),.25,.3),'BenchSupport_%d_%g'%(i,angle),'09_courtyard','steel')
    return dict(state()['categories'])

def audit():
    d=state();now=fingerprint();unchanged=all(now.get(k)==v for k,v in d['before'].items())
    assert unchanged,'Source CAD geometry changed'
    invalid=[];open_solids=[]
    for sid in d['objects']:
        o=sc.doc.Objects.FindId(System.Guid(sid));g=o.Geometry
        if not g.IsValid:invalid.append(sid)
        if isinstance(g,G.Brep) and not g.IsSolid:open_solids.append(sid)
    assert not invalid and not open_solids
    blocked=[]
    for r in range(-70,71,3):
        for offset in [-2.5,0.,2.5]:
            p=point(r,0,FLOOR+1.2)+vec(90)*offset
            for sid in d['objects']:
                o=sc.doc.Objects.FindId(System.Guid(sid));g=o.Geometry
                if isinstance(g,G.Brep) and g.GetBoundingBox(True).Contains(p,False) and g.IsPointInside(p,.001,True):
                    blocked.append({'object':o.Name,'point':xyz(p)})
    assert not blocked,'Opposed entry corridor is obstructed'
    # Validate every entry station: no unsupported point and no stair/ramp discontinuity.
    routes={}
    for name,rows in d['routes'].items():
        grade=0.
        for a,b in zip(rows,rows[1:]):
            length=math.hypot(b[0]-a[0],b[1]-a[1]);grade=max(grade,abs(b[2]-a[2])/max(.001,length))
        routes[name]={'stations':len(rows),'maximum_grade':grade}
        assert grade<.26,'Walking route too steep: '+name
    result={'source':sc.doc.Path,'source_geometry_unchanged':unchanged,'new_objects':len(d['objects']),'categories':d['categories'],'invalid':invalid,'open_breps':open_solids,'opposed_entry_clear_width_tested':5.,'blocked_entry_samples':blocked,'routes':routes,'objects':d['objects'],'parameters':'parameters.json'}
    write('model_report.json',result);return result

def camera(which='overview'):
    vp=sc.doc.Views.ActiveView.ActiveViewport
    if which=='overview':eye=G.Point3d(160,-390,315);target=G.Point3d(485,155,69)
    elif which=='front':eye=point(205,-8,114);target=G.Point3d(CX,CY,73)
    elif which=='rear':eye=point(205,180,114);target=G.Point3d(CX,CY,73)
    elif which=='roof':eye=G.Point3d(575,10,185);target=G.Point3d(CX,CY,70)
    elif which=='cave':eye=G.Point3d(659.75,-361.53,34.8);target=G.Point3d(CX,CY,73)
    else:raise ValueError(which)
    vp.ChangeToPerspectiveProjection(True,40 if which!='overview' else 38)
    vp.SetCameraLocations(target,eye)
    vp.DisplayMode=Rhino.Display.DisplayModeDescription.FindByName('Rendered')
    sc.doc.Views.Redraw();return {'view':which,'eye':xyz(eye),'target':xyz(target)}

def capture(which):
    camera(which)
    vp=sc.doc.Views.ActiveView.ActiveViewport
    sc.doc.NamedViews.Add('UpperRing_'+which+'_1030',vp.Id)
    cap=Rhino.Display.ViewCapture();cap.Width=1600;cap.Height=1000
    cap.DrawGrid=False;cap.DrawAxes=False;cap.DrawGridAxes=False
    bitmap=cap.CaptureToBitmap(sc.doc.Views.ActiveView)
    assert bitmap
    path=OUT+'/'+which+'.png'
    bitmap.Save(path,System.Drawing.Imaging.ImageFormat.Png);bitmap.Dispose()
    return {'capture':path}

def save():
    audit();d=state()
    options=Rhino.FileIO.FileWriteOptions();options.SuppressDialogBoxes=True
    sc.doc.Objects.UnselectAll()
    for sid in d['objects']:sc.doc.Objects.Select(System.Guid(sid))
    options.WriteSelectedObjectsOnly=True
    standalone=OUT+'/upper_ring_pavilion.3dm';version=2
    while os.path.exists(standalone):
        standalone=OUT+'/upper_ring_pavilion_v%d.3dm'%version;version+=1
    assert sc.doc.Write3dmFile(standalone,options)
    sc.doc.Objects.UnselectAll();options.WriteSelectedObjectsOnly=False
    assert sc.doc.Path==d['document']
    assert Rhino.RhinoApp.RunScript('_-Save _Enter',False)
    assert not sc.doc.Modified,'Native save did not finish'
    sc.doc.Views.Redraw()
    return {'saved_document':d['document'],'standalone':standalone,'new_objects':len(d['objects'])}
