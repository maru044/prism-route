# -*- coding: utf-8 -*-
"""Earth-enclosed two-level pavilion, authored in the live Rhino document.

prepare -> build_structure -> build_terrain -> check_site -> commit -> audit/save.
Only the selected manual hill is trimmed. All other source objects are immutable.
"""
from __future__ import unicode_literals, division
import Rhino,scriptcontext as sc,System,math,io,json,os,time
from System.Drawing import Color
G=Rhino.Geometry
ROOT='D:/Prism Route/prism-route'
OUT=ROOT+'/docs/east_earth_pavilion_1102'
TAG='east_earth_pavilion_1102'
LAYER='\u5efa\u7b51::\u4e1c\u4fa7\u8986\u571f\u5ead\u9662'
HILL='920c8a45-b23e-4260-9aab-86333f61b992'
ROAD='ee277b2d-e4eb-4d39-80e6-c5d8a5d87d70'
CY=865.
LOWER,UPPER,TOP=62.,69.6,77.2
COURT_U,COURT_V,COURT_A,COURT_B=16.,28.,17.,13.

def state():return sc.sticky[TAG]
def xyz(p):return [float(p.X),float(p.Y),float(p.Z)]
def smooth(t):t=max(0.,min(1.,t));return t*t*(3.-2.*t)
def mix(a,b,t):return a+(b-a)*t
def write(name,data):
    with io.open(OUT+'/'+name,'w',encoding='utf-8') as f:f.write(json.dumps(data,ensure_ascii=False,indent=2))
def objects():
    e=Rhino.DocObjects.ObjectEnumeratorSettings();e.NormalObjects=True;e.HiddenObjects=True;e.LockedObjects=True
    return [o for o in sc.doc.Objects.GetObjectList(e) if not o.IsDeleted]
def fingerprint():
    opts=Rhino.FileIO.SerializationOptions()
    return {str(o.Id):(int(o.Geometry.DataCRC(0)),o.Attributes.ToJSON(opts)) for o in objects()}
def mesh_of(g):
    if isinstance(g,G.Mesh):return g.DuplicateMesh()
    m=G.Mesh();mp=G.MeshingParameters();mp.Tolerance=.025;mp.MaximumEdgeLength=3.;mp.RefineGrid=True
    for p in G.Mesh.CreateFromBrep(g,mp):m.Append(p)
    m.Normals.ComputeNormals();m.Compact();return m
def finish(m):
    m.Vertices.CullUnused();m.UnifyNormals();m.Normals.ComputeNormals()
    assert m.IsValid and m.IsClosed,'Invalid solid mesh'
    if G.VolumeMassProperties.Compute(m).Volume<0:m.Flip(True,True,True)
    m.Unweld(math.radians(40),True);m.Normals.ComputeNormals();m.Compact();return m
def stage(g,name,category,material):
    assert g and g.IsValid,name
    assert g.IsClosed if isinstance(g,G.Mesh) else g.IsSolid,name
    state()['parts'].append((g,name,category,material))
def sample(mesh,x,y):
    t=G.Intersect.Intersection.MeshRay(mesh,G.Ray3d(G.Point3d(x,y,180),-G.Vector3d.ZAxis))
    return 180-t if t>=0 else None
def ground(x,y):
    zs=[sample(m,x,y) for m in state()['hosts']+[state()['hill_mesh']]]
    zs=[z for z in zs if z is not None];assert zs,'No site ground';return max(zs)
def front(u):
    pts=state()['contour'];y=CY+u;step=pts[1][0]-pts[0][0]
    k=max(0,min(len(pts)-2,int(math.floor((y-pts[0][0])/step))))
    t=(y-pts[k][0])/step;x0=pts[k][1];x1=pts[k+1][1]
    d0=(pts[k+1][1]-pts[max(0,k-1)][1])/(2. if k else 1.)
    d1=(pts[min(len(pts)-1,k+2)][1]-pts[k][1])/(2. if k+2<len(pts) else 1.)
    return (2*t**3-3*t*t+1)*x0+(t**3-2*t*t+t)*d0+(-2*t**3+3*t*t)*x1+(t**3-t*t)*d1
def P(u,v,z=0.):return G.Point3d(front(u)+v,CY+u,z)
def uv(p):u=p.Y-CY;return u,p.X-front(u)
def closed_curve(points):
    pts=list(points)
    if pts[0].DistanceTo(pts[-1])>1e-8:pts.append(pts[0])
    c=G.Curve.CreateInterpolatedCurve(pts,3,G.CurveKnotStyle.ChordPeriodic)
    assert c and c.IsClosed;return c
def rect(u0,u1,v0,v1,r=0.):
    if r<=0:
        pts=[]
        for a,b in [((u0,v0),(u1,v0)),((u1,v0),(u1,v1)),((u1,v1),(u0,v1)),((u0,v1),(u0,v0))]:
            for i in range(15):pts.append(P(mix(a[0],b[0],i/15.),mix(a[1],b[1],i/15.)))
        pts.append(pts[0]);return G.PolylineCurve(pts)
    points=[]
    corners=[(u1-r,v1-r,0),(u0+r,v1-r,90),(u0+r,v0+r,180),(u1-r,v0+r,270)]
    for k,(cu,cv,start) in enumerate(corners):
        for i in range(10):
            a=math.radians(start+90.*i/9.);points.append((cu+r*math.cos(a),cv+r*math.sin(a)))
        nu,nv,na=corners[(k+1)%4];a=math.radians(na)
        end=(nu+r*math.cos(a),nv+r*math.sin(a));begin=points[-1]
        n=max(1,int(math.ceil(math.hypot(end[0]-begin[0],end[1]-begin[1])/3.)))
        for i in range(1,n):points.append((mix(begin[0],end[0],i/n),mix(begin[1],end[1],i/n)))
    pts=[P(u,v) for u,v in points]
    if r<2.:
        pts.append(pts[0]);return G.PolylineCurve(pts)
    return closed_curve(pts)
def ellipse(uc,vc,a,b,n=96):return closed_curve([P(uc+a*math.cos(2*math.pi*i/n),vc+b*math.sin(2*math.pi*i/n)) for i in range(n)])
def plane_region(outer,holes=None):
    breps=G.Brep.CreatePlanarBreps([outer]+(holes or []),.002)
    assert breps and len(breps)==1,'Plan region failed';return breps[0]
def slab(outer,z,thickness,holes=None):
    face=plane_region(outer,holes)
    result=face.Faces[0].CreateExtrusion(G.LineCurve(G.Point3d.Origin,G.Point3d(0,0,thickness)),True)
    assert result and result.IsValid and result.IsSolid,'Plan extrusion failed'
    result.Transform(G.Transform.Translation(0,0,z))
    if result.SolidOrientation==G.BrepSolidOrientation.Inward:result.Flip()
    return result
def beam(fn,t0,t1,width,depth,n=80):
    m=G.Mesh()
    for i in range(n+1):
        t=mix(t0,t1,i/n);p=fn(t);tangent=fn(t+.00001)-fn(t-.00001);assert tangent.Unitize()
        side=G.Vector3d.CrossProduct(tangent,G.Vector3d.ZAxis)
        if not side.Unitize():side=G.Vector3d.XAxis
        normal=G.Vector3d.CrossProduct(side,tangent);normal.Unitize()
        for a,b in [(-1,-1),(1,-1),(1,1),(-1,1)]:m.Vertices.Add(p+side*(a*width/2)+normal*(b*depth/2))
    for i in range(n):
        for j in range(4):
            k=4*i+j;l=4*i+(j+1)%4;m.Faces.AddFace(k,l,l+4,k+4)
    m.Faces.AddFace(3,2,1,0);k=4*n;m.Faces.AddFace(k,k+1,k+2,k+3)
    return finish(m)
def solid_skin(region,top,bottom,max_edge=2.2):
    mp=G.MeshingParameters();mp.Tolerance=.025;mp.MaximumEdgeLength=max_edge;mp.RefineGrid=True
    planar=G.Mesh()
    for piece in G.Mesh.CreateFromBrep(region,mp):planar.Append(piece)
    planar.Vertices.CombineIdentical(True,True);planar.Faces.ConvertQuadsToTriangles();planar.Compact()
    m=G.Mesh();count=planar.Vertices.Count;edges={}
    for side in [0,1]:
        for p in planar.Vertices:
            x,y=float(p.X),float(p.Y);z=top(x,y) if side==0 else bottom(x,y)
            m.Vertices.Add(x,y,z)
    for f in planar.Faces:
        m.Faces.AddFace(f.A,f.B,f.C);m.Faces.AddFace(f.C+count,f.B+count,f.A+count)
        for a,b in [(f.A,f.B),(f.B,f.C),(f.C,f.A)]:
            key=tuple(sorted([a,b]));edges[key]=edges.get(key,[])+[(a,b)]
    for records in edges.values():
        if len(records)==1:
            a,b=records[0];m.Faces.AddFace(a,a+count,b+count,b)
    return finish(m)
def prepare():
    assert sc.doc.Path.replace('\\','/').lower()=='d:/prism route/map/map_current.3dm'
    assert str(sc.doc.ModelUnitSystem)=='Meters'
    assert TAG not in sc.sticky and not any(o.Attributes.GetUserString('feature')==TAG for o in objects())
    if not os.path.isdir(OUT):os.makedirs(OUT)
    folder='D:/Prism Route/archive/east_earth_pavilion_1102'
    if not os.path.isdir(folder):os.makedirs(folder)
    backup=folder+'/map_before_'+time.strftime('%Y%m%d_%H%M%S')+'.3dm'
    opts=Rhino.FileIO.FileWriteOptions();opts.SuppressDialogBoxes=True
    assert not os.path.exists(backup) and sc.doc.Write3dmFile(backup,opts)
    hill=sc.doc.Objects.FindId(System.Guid(HILL))
    sc.sticky[TAG]=dict(before=fingerprint(),parts=[],objects=[],backup=backup,materials={},categories={},
        original_hill=hill.Geometry.DuplicateBrep(),hill_attributes=hill.Attributes.Duplicate(),
        hill_mesh=sc.sticky['east_earth_pavilion_site_1102'],hosts=sc.sticky['east_earth_pavilion_ground_1102'],
        road=sc.sticky['east_earth_pavilion_road_1102'],contour=sc.sticky['east_earth_pavilion_contour_1102'])
    d=state();d['cut_loop']=ellipse(0.,45.,130.,90.)
    d['lower_outline']=rect(-108,108,-2,55,14)
    d['basement_outline']=rect(-106,106,0,97,16)
    d['upper_outline']=rect(-95,95,55,98,12)
    d['court_loop']=ellipse(COURT_U,COURT_V,COURT_A,COURT_B)
    d['ruin_loop']=rect(46,79,53,73,2.5)
    write('parameters.json',dict(feature=TAG,hill_source_id=HILL,road_source_id=ROAD,backup=backup,
        floor_levels=[LOWER,UPPER],upper_roof=TOP,courtyard=dict(center_uv=[COURT_U,COURT_V],opening_axes=[COURT_A,COURT_B],
        clear_floor_axes=[12.5,9.],floor=LOWER,rim=UPPER,ramp_width=2.4),
        contour_stations=d['contour'],local_coordinates='u=nativeY-865; v=nativeX-front_contour_60m(u)',
        plan_length_m=216.,two_levels=True,reference='concept_B3.png',plants_added=0))
    return dict(backup=backup,existing_objects=len(d['before']),floor_levels=[LOWER,UPPER])
def wall_with_openings(name,outer,inner,z,height,openings):
    pieces=[slab(outer,z,height,[inner])]
    for u0,u1,v0,v1,h in openings:
        door=h>=height
        cutter=slab(rect(u0,u1,v0,v1),z-.05 if door else z+.10,height+.10 if door else h)
        result=G.Brep.CreateBooleanDifference(pieces,[cutter],.003)
        assert result and all(g.IsValid and g.IsSolid for g in result),'Wall openings: '+name
        pieces=list(result)
    for i,g in enumerate(pieces):stage(g,name+'_%02d'%i,'03_retaining_walls','ivory')
def glazing(prefix,intervals,v,z,top):
    for j,(a,b) in enumerate(intervals):
        n=max(1,int(math.ceil((b-a)/9.)));step=(b-a)/n
        for i in range(n):
            u0=a+i*step+.07;u1=a+(i+1)*step-.07
            stage(slab(rect(u0,u1,v-.0225,v+.0225),z+.15,top-z-.28),prefix+'_Glass_%02d_%02d'%(j,i),'04_glazing','glass')
            for u in ([u0] if i<n-1 else [u0,u1]):
                stage(beam(lambda t,u=u:P(u,v,mix(z+.12,top-.10,t)),0,1,.11,.14,3),
                      prefix+'_Mullion_%02d_%02d_%d'%(j,i,int(u*10)),'05_frame','dark')
def ramp_point(t):
    a=math.pi*.5+2*math.pi*t
    return P(COURT_U+15.2*math.cos(a),COURT_V+11.2*math.sin(a),mix(UPPER,LOWER,t)-.15)
def build_structure():
    d=state();assert not d['parts']
    # Match the earth collar's inner boundary; the old smaller basement plan
    # left an open strip in front of the facade. A 2cm finish separates the
    # narrow perimeter lap from coplanar earth without a noticeable step.
    stage(slab(rect(-108.08,108.08,-2.08,98.08,14.08),LOWER-.75,.77),'Lower_continuous_floor','02_floors','floor')
    stage(slab(d['lower_outline'],UPPER-.50,.50,[d['court_loop']]),'Lower_roof_with_atrium','06_roof_slabs','ivory')
    stage(slab(d['upper_outline'],UPPER-.50,.50),'Upper_gallery_floor','02_floors','floor')
    upper_roof=slab(rect(-98,98,53,100,13),TOP-.48,.48)
    notch=slab(d['ruin_loop'],TOP-1.,2.)
    roof=G.Brep.CreateBooleanDifference(upper_roof,notch,.003);assert roof
    for i,g in enumerate(roof):stage(g,'Upper_partial_roof_%d'%i,'06_roof_slabs','ivory')
    low_windows=[(-81,-44),(-39,-7),(29,64),(69,85)]
    openings=[(a,b,-1.5,1.5,6.85) for a,b in low_windows]+[(7,25,-1.5,1.5,7.4)]
    wall_with_openings('Lower_earth_retaining_envelope',d['basement_outline'],rect(-105.4,105.4,.6,96.4,15.4),LOWER,7.35,openings)
    wall_with_openings('Upper_earth_retaining_envelope',d['upper_outline'],rect(-94.4,94.4,55.6,97.4,11.4),UPPER,7.35,
        [(a,b,53.5,56.6,6.95) for a,b in [(-78,-35),(-30,9),(22,43),(46,79)]]+[(10,21,53.5,56.6,7.4)])
    glazing('Lower',low_windows,.30,LOWER,UPPER-.5)
    glazing('Upper',[(-78,-35),(-30,9),(22,43)],55.30,UPPER,TOP-.48)
    # Three remaining beams at one localized roof loss, anchored at the rear.
    for i,u in enumerate([49.,62.,76.]):
        end=.72 if i==1 else 1.
        stage(beam(lambda t,u=u:P(u,mix(84.,54.,t),TOP-.16+.16*math.sin(math.pi*t)),0,end,.20,.34,60),
              'Exposed_ruin_box_beam_%d'%i,'05_frame','steel')
    # Atrium floor is deliberately unoccupied, with an unobtrusive pale inlay.
    stage(slab(ellipse(COURT_U,COURT_V,16.8,12.8),LOWER-.10,.125),'Daylit_atrium_paving','02_floors','court')
    stage(slab(ellipse(COURT_U,COURT_V,17.65,13.65),UPPER,.10,[d['court_loop']]),'Atrium_sculpted_white_rim','07_courtyard','ivory')
    # Curved retaining wall, opened into the entrance hall at its front.
    outer=ellipse(COURT_U,COURT_V,17.4,13.4)
    inner=ellipse(COURT_U,COURT_V,17.,13.)
    wall=slab(outer,LOWER,UPPER-LOWER,[inner])
    portal=slab(rect(COURT_U-4.5,COURT_U+4.5,10.,19.),LOWER-.02,4.7)
    walls=G.Brep.CreateBooleanDifference(wall,portal,.003);assert walls
    for i,g in enumerate(walls):stage(g,'Atrium_open_entry_wall_%d'%i,'07_courtyard','ivory')
    stage(beam(ramp_point,-.008,1.004,2.4,.30,284),'Atrium_continuous_helical_ramp','08_ramps','floor')
    for i,t in enumerate([.10,.31,.52,.73]):
        p=ramp_point(t)
        stage(beam(lambda s,p=p:G.Point3d(p.X,p.Y,mix(LOWER,p.Z-.15,s)),0,1,.18,.25,3),
              'Ramp_wallside_support_%d'%i,'05_frame','steel')
    # Upper roof approach to the courtyard ring, flush with the upper gallery.
    stage(slab(rect(COURT_U-1.2,COURT_U+1.2,40.25,55.2,.45),UPPER,.04),'Upper_atrium_approach','08_ramps','floor')
    d['structure_built']=True
    return dict(parts=len(d['parts']),court_opening=[34.,26.],clear_floor=[25.,18.],ramp_drop=UPPER-LOWER)

def path_frame(t):
    # Smooth approach from the measured outer road edge to the entrance.
    p=[G.Point3d(1699.8,860,0),G.Point3d(1750,856,0),P(16.,-55.,0),P(16.,2.,0)]
    def cubic(t):
        q=[G.Point3d(a) for a in p]
        for i in range(3):q=[a+(b-a)*t for a,b in zip(q[:-1],q[1:])]
        return q[0]
    q=cubic(t);tangent=cubic(t+.0001)-cubic(t-.0001);tangent.Unitize()
    return q,G.Vector3d(-tangent.Y,tangent.X,0)
def path_z(t):return mix(49.65,LOWER+.025,smooth(t))
def berm(x,y,base):
    best=None
    stations=state()['path_stations']
    for (ta,a,na),(tb,b,nb) in zip(stations[:-1],stations[1:]):
        dx=b.X-a.X;dy=b.Y-a.Y
        f=max(0.,min(1.,((x-a.X)*dx+(y-a.Y)*dy)/max(.0001,dx*dx+dy*dy)))
        px=a.X+dx*f;py=a.Y+dy*f;dd=(x-px)**2+(y-py)**2
        if best is None or dd<best[0]:best=(dd,mix(ta,tb,f))
    dd,t=best;distance=math.sqrt(dd)
    width=4.+30.*smooth(t/.20);weight=1.-smooth((distance-3.7)/max(1.,width-3.7))
    return mix(base,path_z(t)-.055,weight)
def target_soil(u,v):
    x,y=P(u,v).X,CY+u;native=ground(x,y)
    if v<0.:
        end=smooth((abs(u)-85.)/22.)
        return LOWER+end*(UPPER+.5-LOWER)*smooth((v+22.)/22.)
    if v<50.:value=UPPER+.40+.45*math.sin(math.pi*max(0.,min(1.,(u+108.)/216.)))**2+.25*smooth(v/50.)
    elif v<55.:value=UPPER+.10
    else:value=mix(TOP+.55,max(TOP+.55,native),smooth((v-55.)/42.))
    end_target=mix(UPPER+.45,max(TOP+.6,native),smooth((v-51.5)/23.))
    return mix(value,end_target,smooth((abs(u)-80.)/20.))
def collar_top(x,y):
    u,v=uv(G.Point3d(x,y,0));native=ground(x,y)
    du=max(0.,abs(u)-108.);dv=max(0.,-2.-v,v-98.)
    weight=1.-smooth(math.hypot(du,dv)/23.)
    # Beyond the rounded ends, earth closes the exposed slab profiles.
    target=target_soil(u,v)
    if abs(u)>100. and 0<v<98:target=max(target,UPPER+.45)
    value=mix(native,target,weight)
    return berm(x,y,value) if v<0. else value
def build_terrain():
    d=state();assert d.get('structure_built') and not d.get('terrain_built')
    d['path_stations']=[(i/100.,)+path_frame(i/100.) for i in range(101)]
    # Trim a hole from the one authored hill instead of leaving earth inside rooms.
    cutter=slab(d['cut_loop'],5.,160.)
    split=d['original_hill'].Split(cutter,.005)
    assert split and len(split)>=2,'Could not trim the selected hill'
    outside=[b for b in split if any(f.Loops.Count>1 for f in b.Faces)]
    assert len(outside)==1,'Expected exterior hill with one interior opening'
    d['hill_replacement']=outside[0];assert d['hill_replacement'].IsValid
    # A collar retains the original perimeter; the inner border meets the new roofs.
    collar=plane_region(d['cut_loop'],[rect(-108,108,-2,98,14)])
    stage(solid_skin(collar,collar_top,lambda x,y:min(collar_top(x,y)-.65,ground(x,y)-.20),3.),
          'Continuous_hill_earth_collar','01_terrain_wrap','grass')
    void=G.Curve.CreateBooleanUnion([ellipse(COURT_U,COURT_V,18.1,14.1),rect(COURT_U-1.5,COURT_U+1.5,40.,56.,.45)],.005)
    assert void and len(void)==1,'Atrium roof access mask failed'
    lower_loops=G.Curve.CreateBooleanDifference(rect(-106.5,106.5,.7,49.5,13.5),void[0],.005)
    assert lower_loops and len(lower_loops)==1,'Lower turf atrium access failed'
    lower_region=plane_region(lower_loops[0])
    stage(solid_skin(lower_region,lambda x,y:target_soil(*uv(G.Point3d(x,y,0))),lambda x,y:UPPER+.03),
          'Lower_continuous_turf_roof','01_terrain_wrap','grass')
    grass_loops=G.Curve.CreateBooleanDifference(rect(-96.5,96.5,55.6,98.5,12.),d['ruin_loop'],.005)
    assert grass_loops and len(grass_loops)==1,'Upper turf ruin outline failed'
    upper_region=plane_region(grass_loops[0])
    stage(solid_skin(upper_region,lambda x,y:target_soil(*uv(G.Point3d(x,y,0))),lambda x,y:TOP+.03),
          'Upper_hill_enclosed_turf_roof','01_terrain_wrap','grass')
    # Earth wraps the recessed upper storey's rounded ends, closing the gap
    # between the smaller upper plan and the long lower-storey footprint.
    for side in [-1,1]:
        cap=rect(80,108,51.5,98,4) if side>0 else rect(-108,-80,51.5,98,4)
        cap_loops=G.Curve.CreateBooleanDifference(cap,rect(-98,98,53,100,13),.005)
        assert cap_loops,'End-wrap terrain failed'
        for i,loop in enumerate(cap_loops):
            region=plane_region(loop)
            def cap_top(x,y):return target_soil(*uv(G.Point3d(x,y,0)))
            stage(solid_skin(region,cap_top,lambda x,y:min(LOWER-.8,ground(x,y)-.2)),
                  'Buried_upper_end_%d_%d'%(side,i),'01_terrain_wrap','grass')
    # A broad, gently feathered earth causeway, not a floating thin path.
    outline=[]
    for side in [-1.,1.]:
        ts=range(101) if side<0 else range(100,-1,-1)
        for i in ts:
            t=i/100.;p,n=path_frame(t);outline.append(p+n*(side*(4.+30.*smooth(t/.20))))
    path_outline=closed_curve(outline)
    path_region=plane_region(path_outline)
    # Keep only the portion outside the already replaced hill collar.
    curves=G.Curve.CreateBooleanDifference(path_outline,d['cut_loop'],.005)
    assert curves,'Approach terrain boolean failed'
    for i,curve in enumerate(curves):
        region=plane_region(curve)
        stage(solid_skin(region,lambda x,y:berm(x,y,ground(x,y)),lambda x,y:ground(x,y)-.22,3.),
              'Grounded_approach_berm_%d'%i,'01_terrain_wrap','grass')
    # Native sloped path surface and its solid underside.
    def route(t):
        p,n=path_frame(t);p.Z=path_z(t)-.12;return p
    stage(beam(route,0,1,6.5,.24,220),'Road_to_shaded_entrance_ramp','08_ramps','floor')
    d['terrain_built']=True
    return dict(parts=len(d['parts']),selected_hill_trimmed=True,unrelated_terrain_changed=False)

def check_site():
    d=state();assert d.get('terrain_built');bounds=G.BoundingBox.Empty;triangles=0
    for geo,name,cat,mat in d['parts']:
        assert geo.IsValid and (geo.IsClosed if isinstance(geo,G.Mesh) else geo.IsSolid),name
        bounds.Union(geo.GetBoundingBox(True))
        if isinstance(geo,G.Mesh):triangles+=geo.Faces.TriangleCount+2*geo.Faces.QuadCount
    # Verify open rooms against the exact trimmed hill, not a hidden original.
    hill=mesh_of(d['hill_replacement'])
    for u,v in [(16,28),(16,5),(0,70),(-50,65),(60,75)]:
        p=P(u,v,LOWER+1.)
        assert sample(hill,p.X,p.Y) is None,'Original hill still occupies interior'
    ramps=[]
    for name,fn,top_offset in [('atrium',ramp_point,.15),('entry',lambda t:G.Point3d(path_frame(t)[0].X,path_frame(t)[0].Y,path_z(t)),0.)]:
        points=[fn(i/500.) for i in range(501)]
        length=sum(a.DistanceTo(b) for a,b in zip(points[:-1],points[1:]));grades=[]
        for a,b in zip(points[:-1],points[1:]):grades.append(abs(b.Z-a.Z)/max(.0001,math.hypot(b.X-a.X,b.Y-a.Y)))
        assert max(grades)<.145,'Ramp too steep: '+name
        ramps.append(dict(name=name,length_m=length,max_grade=max(grades),samples=[xyz(p+G.Vector3d(0,0,top_offset)) for p in points[::10]]))
    # Direct lower-level sight and walk corridor from entry into the sunlit court.
    blockers=G.Mesh()
    for geo,name,cat,mat in d['parts']:
        if cat not in ['03_retaining_walls','04_glazing']:continue
        blockers.Append(mesh_of(geo))
    a=P(16,-5,LOWER+1.6);b=P(16,27,LOWER+1.6)
    hit=G.Intersect.Intersection.MeshLine(blockers,G.Line(a,b))
    assert not hit or len(hit)==0,'Entrance view to courtyard blocked'
    report=dict(bounds_native=[xyz(bounds.Min),xyz(bounds.Max)],staged_objects=len(d['parts']),mesh_triangles=triangles,
        levels=[LOWER,UPPER],upper_roof=TOP,court_opening_m=[34.,26.],clear_floor_m=[25.,18.],
        direct_entry_sightline=True,original_hill_removed_from_rooms=True,ramps=ramps,
        changed_source_ids=[HILL],plants_added=0)
    d['site_report']=report;write('site_check.json',report)
    return {k:report[k] for k in ['bounds_native','staged_objects','levels','court_opening_m','direct_entry_sightline']}
def verify_clearances():
    d=state();all_geo=G.Mesh()
    for geo,name,cat,mat in d['parts']:all_geo.Append(mesh_of(geo))
    all_geo.Append(mesh_of(d['hill_replacement']))
    for m in d['hosts']:all_geo.Append(m)
    route_stats=[]
    for name,fn,top in [('entry',lambda t:G.Point3d(path_frame(t)[0].X,path_frame(t)[0].Y,path_z(t)),0.),
                         ('atrium',ramp_point,.15)]:
        errors=[];headrooms=[]
        for i in range(101):
            p=fn(i/100.);p.Z+=top
            t=G.Intersect.Intersection.MeshRay(all_geo,G.Ray3d(p+G.Vector3d(0,0,.3),-G.Vector3d.ZAxis))
            assert t>=0,'Missing walking surface '+name
            error=.3-t;errors.append(error)
            foot=G.Point3d(p.X,p.Y,p.Z+error)
            up=G.Intersect.Intersection.MeshRay(all_geo,G.Ray3d(foot+G.Vector3d(0,0,.055),G.Vector3d.ZAxis))
            if up>=0:headrooms.append(up+.055)
        assert max(abs(e) for e in errors)<.065,'Walking surface occluded: '+name+' '+str(max(errors))
        assert not headrooms or min(headrooms)>2.,'Headroom blocked on '+name
        route_stats.append(dict(name=name,samples=101,max_surface_error_m=max(abs(e) for e in errors),
                                minimum_headroom_m=min(headrooms) if headrooms else None))
    result=dict(routes=route_stats,source_hill_valid=d['hill_replacement'].IsValid,walkable=True)
    write('clearance_check.json',result);d['clearance_report']=result;return result
def layer(path):
    i=sc.doc.Layers.FindByFullPath(path,-1)
    if i>=0:return i
    parent=System.Guid.Empty
    if '::' in path:parent=sc.doc.Layers[layer(path.rsplit('::',1)[0])].Id
    l=Rhino.DocObjects.Layer();l.Name=path.rsplit('::',1)[-1];l.ParentLayerId=parent;return sc.doc.Layers.Add(l)
def material(key,rgb,rough,metal=0.,opacity=1.):
    name='PR_EarthPavilion_'+key
    for i,m in enumerate(sc.doc.Materials):
        if m.Name==name:return i
    m=Rhino.DocObjects.Material();m.Name=name;m.DiffuseColor=Color.FromArgb(*rgb);m.Transparency=1-opacity
    m.ToPhysicallyBased();p=m.PhysicallyBased;p.BaseColor=Rhino.Display.Color4f(rgb[0]/255.,rgb[1]/255.,rgb[2]/255.,1.)
    p.Roughness=rough;p.Metallic=metal;p.Opacity=opacity;return sc.doc.Materials.Add(m)
def commit():
    d=state();assert d.get('site_report') and not d['objects'];assert fingerprint()==d['before'],'Scene changed while staging'
    record=sc.doc.BeginUndoRecord('Earth-covered pavilion and daylight atrium');sc.doc.Views.RedrawEnabled=False
    try:
        for key,rgb,rough,metal,alpha in [('ivory',(228,224,211),.75,.02,1.),('floor',(204,201,184),.83,0.,1.),
            ('court',(231,226,207),.86,0.,1.),('grass',(153,173,118),.97,0.,1.),('steel',(145,105,78),.76,.30,1.),
            ('dark',(66,72,70),.55,.40,1.),('glass',(128,169,176),.20,0.,.40)]:
            d['materials'][key]=material(key,rgb,rough,metal,alpha)
        assert sc.doc.Objects.Replace(System.Guid(HILL),d['hill_replacement'])
        hill_at=d['hill_attributes'].Duplicate();hill_at.MaterialIndex=d['materials']['grass']
        hill_at.MaterialSource=Rhino.DocObjects.ObjectMaterialSource.MaterialFromObject
        hill_at.ObjectColor=sc.doc.Materials[hill_at.MaterialIndex].DiffuseColor
        assert sc.doc.Objects.ModifyAttributes(System.Guid(HILL),hill_at,True)
        for geo,name,cat,mat in d['parts']:
            at=Rhino.DocObjects.ObjectAttributes();at.Name='PR_EarthPavilion_'+name
            at.LayerIndex=layer(LAYER+'::'+cat);at.MaterialIndex=d['materials'][mat]
            at.MaterialSource=Rhino.DocObjects.ObjectMaterialSource.MaterialFromObject
            at.ObjectColor=sc.doc.Materials[at.MaterialIndex].DiffuseColor
            at.SetUserString('feature',TAG);at.SetUserString('category',cat);at.SetUserString('material_key',mat)
            at.SetUserString('generator','tools/rhino_east_earth_pavilion_1102.py')
            sid=sc.doc.Objects.Add(geo,at);assert sid!=System.Guid.Empty;d['objects'].append(str(sid))
            d['categories'][cat]=d['categories'].get(cat,0)+1
        assert sc.doc.Groups.Add('PR_EastEarthPavilion_1102',[System.Guid(s) for s in d['objects']])>=0
    except:
        for sid in d['objects']:sc.doc.Objects.Delete(System.Guid(sid),True)
        sc.doc.Objects.Replace(System.Guid(HILL),d['original_hill']);sc.doc.Objects.ModifyAttributes(System.Guid(HILL),d['hill_attributes'],True)
        d['objects']=[];raise
    finally:sc.doc.EndUndoRecord(record);sc.doc.Views.RedrawEnabled=True;sc.doc.Views.Redraw()
    return dict(objects=len(d['objects']),categories=d['categories'])
def audit():
    d=state();actual=fingerprint();changed=[sid for sid,r in d['before'].items() if actual.get(sid)!=r]
    assert changed==[HILL] or set(changed)==set([HILL]),'Unexpected source edits: '+str(changed)
    assert sc.doc.Objects.FindId(System.Guid(HILL)).Geometry.IsValid
    owned=[o for o in objects() if o.Attributes.GetUserString('feature')==TAG]
    assert set(str(o.Id) for o in owned)==set(d['objects'])
    report=dict(feature=TAG,objects=len(owned),object_ids=d['objects'],categories=d['categories'],changed_source_ids=[HILL],
        unrelated_objects_unchanged=len(d['before'])-1,site=d['site_report'],backup=d['backup'],game_imported=False)
    write('model_report.json',report);return dict(objects=len(owned),changed_source_ids=[HILL],unrelated_objects_unchanged=len(d['before'])-1)
def camera(name='overview'):
    target=P(0,36,68.)
    views={'overview':(G.Point3d(1715,680,200),target,40.),'courtyard':(P(5,10,88),P(16,28,63.5),34.),
        'entry':(P(16,-45,65),P(16,26,64),32.),'site':(G.Point3d(1550,480,280),P(0,30,64),38.)}
    eye,aim,lens=views[name];vp=sc.doc.Views.ActiveView.ActiveViewport
    vp.SetCameraLocations(aim,eye);vp.Camera35mmLensLength=lens
    sc.doc.Objects.UnselectAll();sc.doc.Views.Redraw()
def capture(name='overview'):
    camera(name);vc=Rhino.Display.ViewCapture();vc.Width=1700;vc.Height=1050
    vc.DrawAxes=False;vc.DrawGrid=False;vc.DrawGridAxes=False;vc.ScaleScreenItems=False
    bmp=vc.CaptureToBitmap(sc.doc.Views.ActiveView);assert bmp
    path=OUT+'/model_'+name+'.png';bmp.Save(path,System.Drawing.Imaging.ImageFormat.Png);bmp.Dispose();return path
def save():
    audit();d=state();assert d.get('clearance_report');path=OUT+'/earth_pavilion.3dm'
    if os.path.exists(path):
        previous=Rhino.FileIO.File3dm.Read(path)
        assert previous and set(str(o.Id) for o in previous.Objects)==set(d['objects']+[HILL]),'Keep unrelated component file'
    opts=Rhino.FileIO.FileWriteOptions();opts.SuppressDialogBoxes=True;opts.WriteSelectedObjectsOnly=True
    sc.doc.Objects.UnselectAll()
    try:
        for sid in d['objects']+[HILL]:sc.doc.Objects.Select(System.Guid(sid))
        assert sc.doc.Write3dmFile(path,opts)
    finally:sc.doc.Objects.UnselectAll()
    for name in ['overview','courtyard','entry','site']:
        camera(name);sc.doc.NamedViews.Add('EarthPavilion_'+name+'_1102',sc.doc.Views.ActiveView.ActiveViewport.Id)
    camera('overview');assert Rhino.RhinoApp.RunScript('_-Save _Enter',False) and not sc.doc.Modified
    component=Rhino.FileIO.File3dm.Read(path);assert component and len(list(component.Objects))==len(d['objects'])+1
    main=Rhino.FileIO.File3dm.Read(sc.doc.Path);assert main
    assert len([o for o in main.Objects if o.Attributes.GetUserString('feature')==TAG])==len(d['objects'])
    return dict(main=sc.doc.Path,component=path,objects=len(d['objects']),saved_readback=True)
