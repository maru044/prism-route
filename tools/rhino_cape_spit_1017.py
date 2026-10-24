# -*- coding: utf-8 -*-
"""Local cape and spit study. Native NURBS; all original objects retained."""
from __future__ import unicode_literals,division
import Rhino,scriptcontext as sc,System,math,os,io,json,datetime
from System.Drawing import Color
G=Rhino.Geometry
ROOT=os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT=os.path.join(ROOT,'docs','concepts','cape_spit_1017_v01')
TAG='cape_spit_1017_v01';LAYER='1017_沙嘴与沙洲_v01'
CAP='1435beff-efcc-4af8-9837-27269aca4586'
ROAD='60f020cf-5e56-4bbd-b67f-9059a1ab401c'
ROUTE='cdd81362-826e-4133-b37d-94bf806717f9'
SMALL='c34009e4-d6a5-420c-b0f9-f19d0f78cfc5'
START=1450.;CUT_Y=1460.
def obj(s):return sc.doc.Objects.FindId(System.Guid(s))
def xyz(p):return [float(p.X),float(p.Y),float(p.Z)]
def write(name,data):
    if not os.path.isdir(OUT):os.makedirs(OUT)
    with io.open(os.path.join(OUT,name),'w',encoding='utf8')as f:f.write(unicode(json.dumps(data,ensure_ascii=False,indent=2,default=str)))
def smooth(t):
    t=max(0,min(1,t));return t*t*t*(10+t*(-15+6*t))
def allobjects():
    e=Rhino.DocObjects.ObjectEnumeratorSettings();e.HiddenObjects=True;e.LockedObjects=True;e.NormalObjects=True
    return list(sc.doc.Objects.GetObjectList(e))
def prepare_site():
    assert TAG not in sc.sticky,'Study already exists'
    c=obj(ROUTE).Geometry.DuplicateCurve();end=c.GetLength()-90
    old=obj(ROAD).Geometry;ok,t=c.LengthParameter(START);p=c.PointAt(t)
    hits=[]
    for f in old.Faces:
        ok,u,v=f.ClosestPoint(p);hits.append((f.PointAt(u,v).DistanceTo(p),f.FaceIndex,u,v))
    error,fi,u,v=min(hits);assert error<.01
    face=old.Faces[fi];cross=face.IsoCurve(0,v)
    kept=[f.DuplicateFace(False)for f in old.Faces if f.FaceIndex in [0,7,8]]
    kept.append(face.UnderlyingSurface().Trim(face.Domain(0),G.Interval(v,face.Domain(1).T1)).ToBrep())
    kept=list(G.Brep.JoinBreps(kept,.001));assert all(b.IsValid for b in kept)
    plane=G.Plane(G.Point3d(0,CUT_Y,0),G.Vector3d.YAxis)
    cutter=G.PlaneSurface(plane,G.Interval(-5000,5000),G.Interval(-5000,5000)).ToBrep()
    parts=list(obj(CAP).Geometry.Split(cutter,.01));assert len(parts)==3
    south=max(parts,key=lambda b:b.GetBoundingBox(True).Max.Y)
    north=[b for b in parts if b is not south]
    assert south.GetBoundingBox(True).Min.Y>CUT_Y-.01
    route=c.DuplicateCurve();route.Transform(G.Transform.PlanarProjection(G.Plane.WorldXY))
    coast=obj(CAP).Geometry.Faces[0].Loops[0].To3dCurve();coast.Transform(G.Transform.PlanarProjection(G.Plane.WorldXY))
    m=obj(SMALL).Geometry;last=[G.Point3d(m.Vertices[i])for i in range(7)]
    es=allobjects()
    d={'source_crc':{str(o.Id):int(o.Geometry.DataCRC(0))for o in es},'source_visibility':{str(o.Id):not o.IsHidden for o in es},
       'curve':c,'plan':route,'coast':coast,'old_south':south,'north':north,'retained_road':kept,'cross':cross,
       'end':end,'length':end-START,'last_cross':last,'start_face':int(fi),'start_v':v,
       'begin_view':Rhino.DocObjects.ViewportInfo(sc.doc.Views.ActiveView.ActiveViewport)}
    sc.sticky[TAG]=d
    write('site.json',{'source_terrain':CAP,'source_road':ROAD,'start_station':START,'end_station':end,'cut_face':int(fi),'cut_v':v,
                       'scope':'Southern cape/spit only. Northern terrain, existing curved cliffs and all bridges are retained.',
                       'terrain_boundary_y':CUT_Y,'road_start':xyz(p),'bridge_head':xyz(last[3])})
    print('Local road %.2fm; source cross-section face %d'%(d['length'],fi))
def frame(s):
    d=sc.sticky[TAG];ok,t=d['curve'].LengthParameter(max(0,min(d['end'],START+s)));p=d['curve'].PointAt(t)
    a=d['curve'].TangentAt(t);a.Z=0;a.Unitize();return p,a,G.Vector3d(-a.Y,a.X,0)
def height(s):
    d=sc.sticky[TAG];length=d['length'];c=d['curve']
    ok,t=c.LengthParameter(START);tan=c.TangentAt(t);grade=tan.Z/math.sqrt(tan.X*tan.X+tan.Y*tan.Y)
    # Match the existing bridge approach's real first segment, including crown.
    m=obj(SMALL).Geometry;a=G.Point3d(m.Vertices[3]);b=G.Point3d(m.Vertices[10]);delta=b-a
    endgrade=delta.Z/math.sqrt(delta.X*delta.X+delta.Y*delta.Y)
    nodes=[(0,frame(0)[0].Z,grade),(65,2.,0),(300,3.2,0),(650,2.7,0),(950,2.,0),(length,d['last_cross'][3].Z,endgrade)]
    s=max(0,min(length,s))
    for (sa,za,ga),(sb,zb,gb)in zip(nodes[:-1],nodes[1:]):
        if s<=sb:
            t=(s-sa)/(sb-sa);h=sb-sa
            return (2*t**3-3*t*t+1)*za+(t**3-2*t*t+t)*h*ga+(-2*t**3+3*t*t)*zb+(t**3-t*t)*h*gb
    return nodes[-1][1]
def surface_height(surface,x,y):
    # Newton inversion of the XY map. Changes are in Z only, so the trim UVs
    # and coastline plan remain exactly those of the original NURBS surface.
    d=sc.sticky[TAG];base=d['old_south'].Faces[0].UnderlyingSurface()
    ok,u,v=base.ClosestPoint(G.Point3d(x,y,0))
    for _ in range(5):
        ok,p,der=surface.Evaluate(u,v,1);a,b=der[0],der[1];dx=x-p.X;dy=y-p.Y;det=a.X*b.Y-a.Y*b.X
        if abs(det)<1e-10:break
        u+=(dx*b.Y-dy*b.X)/det;v+=(a.X*dy-a.Y*dx)/det
        if dx*dx+dy*dy<1e-12:break
    return surface.PointAt(u,v).Z
def build_terrain():
    d=sc.sticky[TAG];b=d['old_south'].DuplicateBrep();s=b.Faces[0].UnderlyingSurface().ToNurbsSurface();count=0
    for i in range(s.Points.CountU):
        for j in range(s.Points.CountV):
            cp=s.Points.GetControlPoint(i,j);p=cp.Location
            w=smooth((p.Y-1520)/130)
            if w==0:continue
            q=G.Point3d(p.X,p.Y,0);ok,t=d['coast'].ClosestPoint(q);coast=q.DistanceTo(d['coast'].PointAt(t))
            dune=.6+6.4*math.exp(-((p.X-2140)/185)**2-((p.Y-2200)/210)**2)
            dune+=2.4*math.exp(-((p.X-1940)/150)**2-((p.Y-1900)/170)**2)
            target=.22+dune*smooth(coast/45)
            ok,t=d['plan'].ClosestPoint(q);near=d['plan'].PointAt(t);dist=q.DistanceTo(near)
            station=d['curve'].GetLength(G.Interval(d['curve'].Domain.T0,t))-START
            roadweight=1-smooth((dist-18)/34)
            if -25<station<d['length']+25:target=target*(1-roadweight)+(height(station)-.9)*roadweight
            z=p.Z*(1-w)+target*w
            assert s.Points.SetControlPoint(i,j,G.ControlPoint(G.Point3d(p.X,p.Y,z),cp.Weight));count+=1
    si=b.AddSurface(s);assert b.Faces[0].ChangeSurface(si)
    assert b.Faces[0].RebuildEdges(.001,True,True);b.Compact();assert b.IsValid
    mp=G.MeshingParameters();mp.MaximumEdgeLength=5;mp.MinimumEdgeLength=.1;mp.Tolerance=.035;mp.RefineGrid=True;mp.JaggedSeams=False
    limit=G.Mesh()
    for m in G.Mesh.CreateFromBrep(b,mp):limit.Append(m)
    assert limit.IsValid
    # A native ruled shoreline skirt, kept below the visible beach edge.
    boundary=b.Faces[0].Loops[0].To3dCurve();bottom=boundary.DuplicateCurve();bottom.Transform(G.Transform.PlanarProjection(G.Plane.WorldXY));bottom.Transform(G.Transform.Translation(0,0,-3))
    walls=G.Brep.CreateFromLoft([boundary,bottom],G.Point3d.Unset,G.Point3d.Unset,G.LoftType.Straight,False)
    assert walls and all(x.IsValid for x in walls)
    d.update({'terrain':b,'terrain_surface':s,'terrain_mesh':limit,'shore_walls':list(walls)})
    write('terrain_prepared.json',{'valid':bool(b.IsValid),'native_faces':int(b.Faces.Count),'modified_control_points':count,'render_faces':int(limit.Faces.Count),
                                 'bbox':[xyz(b.GetBoundingBox(True).Min),xyz(b.GetBoundingBox(True).Max)]})
    print('Native cape surface prepared; %d local control points changed'%count)
def roadpoint(s,y,dz=0):
    d=sc.sticky[TAG];p,a,n=frame(s);p=p+n*y;p.Z=height(s)+dz
    # Match the full real transverse cuts, not just their center points.
    for end,dist in [(0,s),(1,d['length']-s)]:
        if dist>=45:continue
        ss=0 if end==0 else d['length'];base,aa,nn=frame(ss)
        if end==0:
            c=d['cross'];x=c.PointAtNormalizedLength((y+10)/20)
            c0=c.PointAtStart;c1=c.PointAtEnd
            if G.Vector3d.Multiply(c1-c0,nn)<0:x=c.PointAtNormalizedLength(1-(y+10)/20)
        else:
            left,right=d['last_cross'][0],d['last_cross'][-1]
            if G.Vector3d.Multiply(right-left,nn)<0:left,right=right,left
            x=left+(right-left)*((y+10)/20)
        nominal=base+nn*y;nominal.Z=height(ss)
        p+=(x-nominal)*(1-smooth(dist/45))
    return p
def build_road():
    d=sc.sticky[TAG];length=d['length'];n=int(math.ceil(length/8));stations=[length*i/n for i in range(n+1)];sections=[];profiles=[]
    for s in stations:
        pts=[roadpoint(s,y)for y in [-10,-20/3,-10/3,0,10/3,20/3,10]]
        sections.append(G.Curve.CreateInterpolatedCurve(pts,3))
        p,a,normal=frame(s);top=height(s)-.075
        ground=[]
        for y in [-12,0,12]:
            q=roadpoint(s,y);hit=G.Intersect.Intersection.MeshRay(d['terrain_mesh'],G.Ray3d(G.Point3d(q.X,q.Y,100),-G.Vector3d.ZAxis))
            if hit>=0:ground.append(100-hit)
        base=min(ground)-.65 if ground else -3
        base=min(base,top-.6)
        # The final profile is identical to the existing small bridge's cap.
        end=smooth(min(s,length-s)/25);head=1-smooth((length-s)/45)
        base=base*(1-head)-2.5*head
        upper=12.4+.5*end;fold=13.5+1.1*end;foldz=top*.54+base*.46
        half=[(0,top),(5,top),(10,top),(11,top),(11.5,top),(upper,top+.14*end),
              (upper+.65,top+.38*end),(fold-.3,top-.25),(fold,foldz+.35),(fold-.25,foldz-.1),
              (12.9,base+.12),(10,base),(5,base),(0,base)]
        yz=half+[(-y,z)for y,z in reversed(half[1:-1])]
        ps=[]
        for y,z in yz:
            q=roadpoint(s,y);q.Z=z;ps.append(q)
        profiles.append(G.NurbsCurve.Create(True,3,ps))
    road=G.Brep.CreateFromLoft(sections,G.Point3d.Unset,G.Point3d.Unset,G.LoftType.Normal,False)
    body=G.Brep.CreateFromLoft(profiles,G.Point3d.Unset,G.Point3d.Unset,G.LoftType.Normal,False)
    assert road and len(road)==1 and road[0].IsValid
    body=body[0].CapPlanarHoles(.001);assert body and body.IsValid and body.IsSolid
    if body.SolidOrientation==G.BrepSolidOrientation.Inward:body.Flip()
    d.update({'road':road[0],'body':body,'stations':stations})
    write('road_prepared.json',{'native_road_faces':int(road[0].Faces.Count),'body_faces':int(body.Faces.Count),'body_solid':bool(body.IsSolid),'sections':len(stations),
                              'height_range':[min(height(s)for s in stations),max(height(s)for s in stations)]})
    print('Native continuous road and solid verge prepared')
