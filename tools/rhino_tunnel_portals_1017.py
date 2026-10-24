# -*- coding: utf-8 -*-
"""Grounded tunnel mouths; retain the existing low entrance architecture.

Explicit stages: prepare, build, cut_coastal_wall, trim_coastal_floor, verify,
publish, views/captures, save. Original objects are retained, hidden if replaced.
"""
from __future__ import unicode_literals,division
import Rhino,scriptcontext as sc,System,math,json,io,os
from System.Drawing import Color
G=Rhino.Geometry
ROOT='D:/Prism Route/prism-route'
OUT=ROOT+'/docs/concepts/tunnel_portals_2026-10-17_v01/model_v01'
TAG='tunnel_portals_1017_v01';LAYER='1017_中层隧道_渐入入口与临水出口_v01'
WEST='59dd95cc-d6f3-4378-ae67-d76fcbdf6ac8'
EAST='47800a9c-ca72-4dc5-8203-d6d5d91d29a9'
WALL='fac1e44f-0311-414e-ae69-18e143ff155a'
SOIL='81aa365d-5fb7-430a-afc2-819c6030473b'
OLD_FRONT='211469c8-934a-40d3-ab57-a3fc82014e8e'

def obj(s):return sc.doc.Objects.FindId(System.Guid(s))
def xyz(p):return [float(p.X),float(p.Y),float(p.Z)]
def smooth(t):
    t=max(0,min(1,t));return t*t*t*(10+t*(-15+6*t))
def write(n,data):
    if not os.path.isdir(OUT):os.makedirs(OUT)
    with io.open(OUT+'/'+n,'w',encoding='utf8')as f:f.write(unicode(json.dumps(data,ensure_ascii=False,indent=2,default=str)))
def allobjects():
    e=Rhino.DocObjects.ObjectEnumeratorSettings();e.HiddenObjects=True;e.LockedObjects=True;e.NormalObjects=True
    return list(sc.doc.Objects.GetObjectList(e))
def prepare():
    assert TAG not in sc.sticky,'Do not reset this study'
    west=obj(WEST).Geometry.Faces[0];east=obj(EAST).Geometry.Faces[0]
    wc=west.IsoCurve(1,west.Domain(0).Mid);ec=east.IsoCurve(1,east.Domain(0).Mid);ec.Reverse()
    p=G.Point3d(1973.3297526,355.4900366,35.1900055);ok,t=ec.ClosestPoint(p);cross=ec.GetLength(G.Interval(ec.Domain.T0,t))
    d={'west':wc,'east':ec,'coastal_cross':cross,
       'west_range':[900.,1005.],'east_range':[cross-24,cross+82],
       'source_crc':{str(o.Id):int(o.Geometry.DataCRC(0))for o in allobjects()},
       'view_before':Rhino.DocObjects.ViewportInfo(sc.doc.Views.ActiveView.ActiveViewport)}
    sc.sticky[TAG]=d
    write('scope.json',{'west_closed_range':d['west_range'],'east_range':d['east_range'],'coastal_wall_cross':cross,
                       'retain_low_front':OLD_FRONT,'description':'Entrance walls grow behind existing low arch; no new long covered approach.'})
    print('Prepared two native portal sites; coastal crossing %.3fm'%cross)

def frame(which,s):
    c=sc.sticky[TAG][which];ok,t=c.LengthParameter(s);assert ok
    p=c.PointAt(t);a=c.TangentAt(t);a.Z=0;a.Unitize();return p,a,G.Vector3d(-a.Y,a.X,0)
def point(which,s,y,z):
    p,a,n=frame(which,s);p+=n*y;p.Z=z;return p
def dimensions(which,s):
    d=sc.sticky[TAG];start,end=d[which+'_range'];t=(s-start)/(end-start)
    if which=='west':
        half=17.5-1.0*smooth((s-start)/45)
        crown=10.6;outer=13.5;foot=half+13
        # The limit surface rounds inward from its control cage. Bury the
        # control feet so their smoothed limit remains below the low ground.
        ground=-3.8
    else:
        half=27.0-2.0*smooth((s-start)/65)
        crown=13.2
        outer=16.3+8.8*smooth((s-start)/28)
        foot=half+17
        ground=frame(which,s)[0].Z-1.0
    return half,crown,outer,foot,ground

def arch_yz(half,crown,count=44):
    return [(-half*math.cos(math.pi*i/count),-.65+(crown+.65)*math.sin(math.pi*i/count)**.60)for i in range(count+1)]
def profile(which,s):
    p,a,n=frame(which,s);half,h,roof,foot,ground=dimensions(which,s);gz=ground-p.Z
    yz=arch_yz(half,h)
    # Inner soffit and a distinct, much thicker outer mass. Large feet reach
    # the actual low datum; this is not a constant-thickness bent sheet.
    yz += [(half+.25,-1.15),(foot-2,gz),(foot+1,gz),(foot+1.2,gz+.7),
           (foot,gz+(roof-gz)*.34),(half+12,roof*.48),(half+9,roof*.78),
           (half+4,roof*.97),(half*.65,roof),(0,roof),(-half*.65,roof),
           (-half-4,roof*.98),(-half-10,roof*.79),(-foot-2,gz+(roof-gz)*.42),
           (-foot-3,gz+.8),(-foot-2,gz),(-foot+1,gz),(-half-.25,-1.15)]
    return G.NurbsCurve.Create(True,3,[point(which,s,y,p.Z+z)for y,z in yz])

def loft(sections):
    b=G.Brep.CreateFromLoft(sections,G.Point3d.Unset,G.Point3d.Unset,G.LoftType.Normal,False)
    assert b and len(b)==1
    b=b[0].CapPlanarHoles(.003);assert b and b.IsValid and b.IsSolid
    if b.SolidOrientation==G.BrepSolidOrientation.Inward:b.Flip()
    return b

def build_one(which):
    d=sc.sticky[TAG];start,end=d[which+'_range'];n=int(math.ceil((end-start)/3))
    stations=[start+(end-start)*i/n for i in range(n+1)]
    core=loft([profile(which,s)for s in stations]);assets=[('拱腹与厚拱肩',core)]
    # Two low leading wings rise asymmetrically into the rear enclosure. The
    # front of the old low arch remains open and visible ahead of the new roof.
    for sign,lead in [(-1,46.),(1,30.)]:
        wing=[]
        for i in range(25):
            s=start-lead+(lead+8)*i/24;fade=smooth((s-(start-lead))/(lead+2))
            p,a,norm=frame(which,s);half,h,roof,foot,gz=dimensions(which,max(start,s))
            if which=='west':ground=-.8
            else:ground=p.Z-.7
            top=ground+.30+(p.Z+roof-1.5-ground)*fade
            center=half+7+3*(1-fade);width=.9+7.0*fade
            yz=[(center-width,ground-.8),(center-width,ground+.1),
                (center-width*.8,ground+(top-ground)*.45),(center-width*.32,top-.2),
                (center+.1,top),(center+width*.55,top-.3),
                (center+width,ground+(top-ground)*.40),(center+width+1,ground),
                (center+width,ground-.8),(center,ground-.9)]
            pts=[point(which,s,sign*y,z)for y,z in yz]
            if sign<0:pts.reverse()
            wing.append(G.NurbsCurve.Create(True,3,pts))
        assets.append(('渐入拱肩_'+str(sign),loft(wing)))
    # Buried road-bearing volume supports the high roadway and joins the
    # grounded haunches. Top remains below the existing asphalt.
    base=[]
    for s in stations:
        p,a,norm=frame(which,s);half,h,roof,foot,gz=dimensions(which,s)
        top=p.Z-.20;bottom=gz-.7;w=half+7
        yz=[(-w,bottom),(-w-.8,bottom+.5),(-w*.95,(top+bottom)/2),(-w*.88,top-.1),
            (-w*.8,top),(0,top),(w*.8,top),(w*.88,top-.1),(w*.95,(top+bottom)/2),(w+.8,bottom+.5),(w,bottom),(0,bottom)]
        base.append(G.NurbsCurve.Create(True,3,[point(which,s,y,z)for y,z in yz]))
    assets.append(('埋入式连续承台',loft(base)))
    d[which+'_assets']=assets
    print('%s: %d closed native masses, %d stations'%(which,len(assets),len(stations)))

def build_cutter():
    d=sc.sticky[TAG];cross=d['coastal_cross'];sections=[]
    for i in range(41):
        s=cross-65+185*i/40;p,a,n=frame('east',s)
        half,h,roof,foot,gz=dimensions('east',s)
        yz=arch_yz(half+1.3,h+1.0)+[(half+1.3,-1.8),(0,-1.8),(-half-1.3,-1.8)]
        sections.append(G.NurbsCurve.Create(True,3,[point('east',s,y,p.Z+z)for y,z in yz]))
    d['cutter']=loft(sections)
    print('Prepared wider-than-road native clearance cutter')

def cut_coastal_wall():
    d=sc.sticky[TAG];b=obj(WALL).Geometry;parts=b.Split(d['cutter'],.01);assert parts and len(parts)>1,'Wall split failed'
    kept=[];removed=[]
    for p in parts:
        center=G.AreaMassProperties.Compute(p).Centroid
        if d['cutter'].IsPointInside(center,.03,False):removed.append(p)
        else:kept.append(p)
    assert kept and removed,'Split did not isolate the opening'
    result=G.Brep()
    for b in kept:result.Append(b)
    assert result.IsValid;d['wall_copy']=result
    write('wall_cut.json',{'parts':len(parts),'removed':len(removed),'kept':len(kept),'valid':True})
    print('Prepared coastal wall with an actual through opening')

def uvpoint(surface,p):
    ok,u,v=surface.ClosestPoint(G.Point3d(p.X,p.Y,0));assert ok
    for _ in range(7):
        ok,q,der=surface.Evaluate(u,v,1);a,b=der[0],der[1];dx=p.X-q.X;dy=p.Y-q.Y;det=a.X*b.Y-a.Y*b.X
        assert abs(det)>1e-10
        u+=(dx*b.Y-dy*b.X)/det;v+=(a.X*dy-a.Y*dx)/det
        if dx*dx+dy*dy<1e-12:break
    return G.Point3d(u,v,0)

def trim_coastal_floor():
    d=sc.sticky[TAG];face=obj(SOIL).Geometry.Faces[0];surface=face.UnderlyingSurface();source=face.Loops[0].To2dCurve()
    start,end=d['east_range'];rows=[]
    for sign in [-1,1]:
        pts=[]
        for i in range(61):
            s=start+(end-start)*i/60;p,a,n=frame('east',s);half=dimensions('east',s)[0]
            pts.append(p+n*sign*(half+3.5))
        rows.append(pts)
    points=rows[0]+list(reversed(rows[1]));points.append(points[0]);cut=G.PolylineCurve([uvpoint(surface,p)for p in points])
    if source.ClosedCurveOrientation(G.Plane.WorldXY)==G.CurveOrientation.Clockwise:source.Reverse()
    loops=G.Curve.CreateBooleanDifference(source,[cut],.01);assert loops
    outers=[c for c in loops if c.ClosedCurveOrientation(G.Plane.WorldXY)==G.CurveOrientation.CounterClockwise]
    inners=[c for c in loops if c not in outers];result=G.Brep()
    for outer in outers:
        holes=[c for c in inners if outer.Contains(c.PointAtStart,G.Plane.WorldXY,.01)==G.PointContainment.Inside]
        plane=G.Brep.CreateFromSurface(G.PlaneSurface(G.Plane.WorldXY,face.Domain(0),face.Domain(1)))
        pieces=plane.Faces[0].Split([outer]+holes,.01);assert pieces
        area=G.AreaMassProperties.Compute(outer).Area-sum(G.AreaMassProperties.Compute(c).Area for c in holes)
        f=min(pieces.Faces,key=lambda f:abs(G.AreaMassProperties.Compute(f).Area-area))
        assert abs(G.AreaMassProperties.Compute(f).Area-area)<max(.02,area*1e-6)
        b=G.Brep.CopyTrimCurves(f,surface,.01);assert b and b.IsValid;result.Append(b)
    assert result.IsValid;d['soil_copy']=result
    print('Prepared coastal floor clearance; original surface outside unchanged')

def layer(child):
    root=sc.doc.Layers.FindByFullPath(LAYER,-1)
    if root<0:
        l=Rhino.DocObjects.Layer();l.Name=LAYER;root=sc.doc.Layers.Add(l)
    i=sc.doc.Layers.FindByFullPath(LAYER+'::'+child,-1)
    if i<0:
        l=Rhino.DocObjects.Layer();l.Name=child;l.ParentLayerId=sc.doc.Layers[root].Id;i=sc.doc.Layers.Add(l)
    return i

def publish():
    d=sc.sticky[TAG];assert not d.get('objects'),'Already published'
    backup='D:/Prism Route/map/map_1017_before_tunnel_portals_v01.3dm';assert not os.path.exists(backup)
    opt=Rhino.FileIO.FileWriteOptions();opt.UpdateDocumentPath=False;opt.IncludeRenderMeshes=False;opt.SuppressAllInput=True;opt.SuppressDialogBoxes=True
    assert sc.doc.Write3dmFile(backup,opt);d['backup']=backup
    mi=next(i for i,m in enumerate(sc.doc.Materials)if m.Name=='沙嘴_暖白半光建筑覆面')
    rows=[];rec=sc.doc.BeginUndoRecord('中层隧道_渐入入口与临水出口')
    try:
        def add(g,name,child,source=None):
            a=obj(source).Attributes.Duplicate()if source else Rhino.DocObjects.ObjectAttributes()
            if source:
                l=sc.doc.Layers[a.LayerIndex]
                if a.MaterialSource==Rhino.DocObjects.ObjectMaterialSource.MaterialFromLayer:
                    a.MaterialIndex=l.RenderMaterialIndex;a.MaterialSource=Rhino.DocObjects.ObjectMaterialSource.MaterialFromObject
                if a.ColorSource==Rhino.DocObjects.ObjectColorSource.ColorFromLayer:
                    a.ObjectColor=l.Color;a.ColorSource=Rhino.DocObjects.ObjectColorSource.ColorFromObject
            else:
                a.MaterialIndex=mi;a.MaterialSource=Rhino.DocObjects.ObjectMaterialSource.MaterialFromObject
                a.ObjectColor=sc.doc.Materials[mi].DiffuseColor;a.ColorSource=Rhino.DocObjects.ObjectColorSource.ColorFromObject
            a.ObjectId=System.Guid.Empty;a.Name=name;a.LayerIndex=layer(child);a.SetUserString('recipe',TAG)
            oid=sc.doc.Objects.AddBrep(g,a);assert oid!=System.Guid.Empty
            mp=G.MeshingParameters();mp.MaximumEdgeLength=1.5;mp.MinimumEdgeLength=.03;mp.Tolerance=.012;mp.RefineGrid=True;mp.JaggedSeams=False
            assert obj(str(oid)).SetRenderMeshParameters(mp)
            rows.append({'id':str(oid),'name':name,'layer':child})
        for which,child in [('west','01_低处入口_后退渐入'),('east','02_临水出口_连续拱肩')]:
            for name,g in d[which+'_assets']:add(g,which+'_'+name,child)
        add(d['wall_copy'],'原岸墙_临水隧道实际开洞','03_原岸墙开洞',WALL)
        add(d['soil_copy'],'原临水台地_通行范围让位','04_原台地局部让位',SOIL)
        for sid in [WALL,SOIL]:assert sc.doc.Objects.Hide(System.Guid(sid),True)
        d['objects']=rows
    finally:sc.doc.EndUndoRecord(rec);sc.doc.Views.Redraw()
    write('publication.json',{'objects':rows,'hidden_originals':[WALL,SOIL],'retained_front':OLD_FRONT,'backup':backup})
    print('Published native portals; original low front retained visible')

def view(which):
    vp=sc.doc.Views.ActiveView.ActiveViewport
    if which=='west':vp.SetCameraLocations(G.Point3d(949,540,37),G.Point3d(1105,775,50))
    elif which=='west_side':vp.SetCameraLocations(G.Point3d(934,532,33),G.Point3d(1145,610,68))
    else:vp.SetCameraLocations(G.Point3d(1973,355,39),G.Point3d(2195,335,70))
    sc.doc.Views.Redraw()
def capture(name):
    c=Rhino.Display.ViewCapture();c.Width=1800;c.Height=1100;c.DrawGrid=False;c.DrawAxes=False;c.DrawGridAxes=False
    b=c.CaptureToBitmap(sc.doc.Views.ActiveView);b.Save(OUT+'/'+name+'.png',System.Drawing.Imaging.ImageFormat.Png);b.Dispose()

def meshed(b,maxedge=2,tol=.02):
    if isinstance(b,G.SubD):return G.Mesh.CreateFromSubD(b,2)
    p=G.MeshingParameters();p.MaximumEdgeLength=maxedge;p.MinimumEdgeLength=.03;p.Tolerance=tol;p.RefineGrid=True;p.JaggedSeams=False
    m=G.Mesh()
    for part in G.Mesh.CreateFromBrep(b,p):m.Append(part)
    m.Normals.ComputeNormals();return m

def build_unified_mouth(which):
    """One closed shared-topology volume: soffit, rolled lip and grounded feet.

    Leading feet advance while the crown retreats, so no separate blade-like
    wing solids are needed. SubD smooths the common quad topology, not separate
    overlapping panels. Its inner and outer surfaces have different shapes.
    """
    d=sc.sticky[TAG];start,end=d[which+'_range'];N=48;M=40;K=5
    lead=8 if which=='west'else 24
    def at(t,j,k):
        theta=math.pi*j/M;f=k/K;side=math.cos(theta)
        front=start-lead*abs(side)**1.6*(1+.14*side)-1.7*math.sin(math.pi*f)
        s=front+(end-front)*t;p,a,n=frame(which,s)
        half,h,roof,foot,ground=dimensions(which,max(start,min(end,s)))
        if which=='east':ground=p.Z-.65
        yi=-half*math.cos(theta);zi=p.Z-.65+(h+.65)*math.sin(theta)**.60
        yo=-foot*math.cos(theta);zo=ground+(p.Z+roof-ground)*math.sin(theta)**.77
        # Front cap has a rounded nose rather than a planar cut face.
        y=yi*(1-f)+yo*f;z=zi*(1-f)+zo*f
        return p+n*y+G.Vector3d.ZAxis*(z-p.Z)
    # Ordered closed section: inner arch, right foot, outer arch, left foot.
    coords=[(j,0)for j in range(M+1)]+[(M,k)for k in range(1,K)]+[(j,K)for j in reversed(range(M+1))]+[(0,k)for k in reversed(range(1,K))]
    m=G.Mesh();lookup={}
    for i in range(N+1):
        for j,k in coords:lookup[(i,j,k)]=m.Vertices.Add(at(i/N,j,k))
    count=len(coords)
    for i in range(N):
        for z in range(count):
            a=lookup[(i,)+coords[z]];b=lookup[(i,)+coords[(z+1)%count]]
            c=lookup[(i+1,)+coords[(z+1)%count]];e=lookup[(i+1,)+coords[z]]
            m.Faces.AddFace(a,b,c,e)
    for i in [0,N]:
        for j in range(1,M):
            for k in range(1,K):lookup[(i,j,k)]=m.Vertices.Add(at(i/N,j,k))
        for j in range(M):
            for k in range(K):
                a,b,c,e=[lookup[x]for x in [(i,j,k),(i,j+1,k),(i,j+1,k+1),(i,j,k+1)]]
                m.Faces.AddFace(a,b,c,e)
    m.UnifyNormals();m.Weld(math.pi);m.Normals.ComputeNormals();m.Compact()
    assert m.IsValid and m.IsClosed and len(m.SplitDisjointPieces())==1
    sub=G.SubD.CreateFromMesh(m,G.SubDCreationOptions.Smooth);assert sub and sub.IsValid
    limit=G.Mesh.CreateFromSubD(sub,2);assert limit.IsValid and limit.IsClosed
    d[which+'_unified']=sub
    write(which+'_unified_topology.json',{'closed_limit_mesh':bool(limit.IsClosed),'control_faces':m.Faces.Count,'control_vertices':m.Vertices.Count,
                                        'visible_front_geometry_retained':OLD_FRONT if which=='west'else None,
                                        'method':'Shared topology curved mouth, soffit, extrados and feet; variable mass thickness.'})
    print(which+' unified grounded mouth prepared')

def replace_mouths():
    d=sc.sticky[TAG];rows=[]
    mi=next(i for i,m in enumerate(sc.doc.Materials)if m.Name=='沙嘴_暖白半光建筑覆面')
    # Keep the first modeling study hidden, and replace only this task's new
    # core and blade-like trial wings. Original architecture stays visible.
    for which,child in [('west','01_低处入口_后退渐入'),('east','02_临水出口_连续拱肩')]:
        retired=[r for r in d['objects']if r['name'].startswith(which+'_')and '承台'not in r['name']]
        for r in retired:
            assert sc.doc.Objects.Hide(System.Guid(r['id']),True)
            a=obj(r['id']).Attributes.Duplicate();a.LayerIndex=layer('99_初版分体构造_隐藏');sc.doc.Objects.ModifyAttributes(System.Guid(r['id']),a,True)
        a=Rhino.DocObjects.ObjectAttributes();a.Name=which+'_连续拱腹_圆转洞唇_实体落地拱肩';a.LayerIndex=layer(child)
        a.MaterialIndex=mi;a.MaterialSource=Rhino.DocObjects.ObjectMaterialSource.MaterialFromObject
        a.ObjectColor=sc.doc.Materials[mi].DiffuseColor;a.ColorSource=Rhino.DocObjects.ObjectColorSource.ColorFromObject;a.SetUserString('recipe',TAG)
        oid=sc.doc.Objects.AddSubD(d[which+'_unified'],a);assert oid!=System.Guid.Empty
        rows.append({'id':str(oid),'name':a.Name,'layer':child})
        d[which+'_assets']=[('连续拱腹与落地拱肩',d[which+'_unified']),d[which+'_assets'][-1]]
    d['retired_objects']=d.get('retired_objects',[])+[r for r in d['objects']if r['name'].startswith(('west_','east_'))and '承台'not in r['name']]
    d['objects']=[r for r in d['objects']if r not in d['retired_objects']]+rows
    write('publication.json',{'objects':d['objects'],'retired_objects':d['retired_objects'],'hidden_originals':[WALL,SOIL],'retained_front':OLD_FRONT,'backup':d['backup']})
    sc.doc.Views.Redraw()

def verify():
    d=sc.sticky[TAG];reports={};d['asset_meshes']={}
    for which,rid in [('west',WEST),('east',EAST)]:
        face=obj(rid).Geometry.Faces[0];surface=face.UnderlyingSurface();start,end=d[which+'_range']
        gm=[(name,meshed(b))for name,b in d[which+'_assets']];d['asset_meshes'][which]=gm
        cover=G.Mesh()
        for name,m in gm[:-1]:cover.Append(m)
        floors=gm[-1][1];clearance=[];floor_gaps=[];bad=[];inside=[]
        for i in range(1,61):
            s=start+(end-start)*(i-.317)/61;p,a,n=frame(which,s);uv=uvpoint(surface,p)
            edges=[face.PointAt(face.Domain(0).T0,uv.Y),face.PointAt(face.Domain(0).T1,uv.Y)]
            half=edges[0].DistanceTo(edges[1])/2
            for j in range(9):
                y=(j/8*2-1)*(half-.12);q=p+n*y;uq=uvpoint(surface,q);q.Z=surface.PointAt(uq.X,uq.Y).Z
                h=G.Intersect.Intersection.MeshRay(cover,G.Ray3d(q+G.Vector3d.ZAxis*.10,G.Vector3d.ZAxis))
                if h>=0:
                    clearance.append(h+.10)
                    if h+.10<6:bad.append([s,y,h+.10])
                else:bad.append([s,y,'no ceiling'])
                h=G.Intersect.Intersection.MeshRay(floors,G.Ray3d(q+G.Vector3d.ZAxis,G.Vector3d(0,0,-1)))
                if h>=0:floor_gaps.append(h-1)
                else:bad.append([s,y,'no bearing'])
                for z in [.1,3,6]:
                    test=q+G.Vector3d.ZAxis*z
                    if any(m.IsPointInside(test,.01,True)for name,m in gm):inside.append([s,y,z])
        reports[which]={'minimum_sampled_clear_height':min(clearance)if clearance else None,
                        'road_to_bearing_top_range':[min(floor_gaps),max(floor_gaps)]if floor_gaps else None,
                        'clearance_failures':bad,'traffic_volume_intrusions':inside,
                        'closed_native_solids':[{'name':name,'valid':bool(b.IsValid),
                         'solid':bool(meshed(b).IsClosed)if isinstance(b,G.SubD)else bool(b.IsSolid),
                         'type':'SubD'if isinstance(b,G.SubD)else 'Brep','faces':b.Faces.Count}for name,b in d[which+'_assets']]}
    reports['original_geometry_unchanged']=all(obj(sid)and int(obj(sid).Geometry.DataCRC(0))==crc for sid,crc in d['source_crc'].items())
    reports['original_front_unhidden']=not obj(OLD_FRONT).IsHidden
    reports['coastal_wall_opening_valid']=bool(d['wall_copy'].IsValid)
    reports['game_tested']=False;d['verification']=reports;write('verification.json',reports)
    print(json.dumps(reports));return reports

def portal_material():
    d=sc.sticky[TAG]
    if 'portal_material'in d:return d['portal_material']
    m=Rhino.DocObjects.Material();m.Name='隧道_暖白建筑复合面_PBR_非金属'
    m.DiffuseColor=Color.FromArgb(241,237,228);m.Reflectivity=.02;m.Shine=40;m.ToPhysicallyBased()
    p=m.PhysicallyBased;p.BaseColor=Rhino.Display.Color4f(.945,.929,.894,1.)
    p.Metallic=0.;p.Roughness=.32;p.Specular=.45;p.ReflectiveIOR=1.47;p.Clearcoat=.10;p.ClearcoatRoughness=.25
    d['portal_material']=sc.doc.Materials.Add(m);return d['portal_material']

def apply_material():
    d=sc.sticky[TAG];mi=portal_material()
    for row in d['objects']:
        if row['name'].startswith(('west_','east_')):
            a=obj(row['id']).Attributes.Duplicate();a.MaterialIndex=mi;a.MaterialSource=Rhino.DocObjects.ObjectMaterialSource.MaterialFromObject
            assert sc.doc.Objects.ModifyAttributes(System.Guid(row['id']),a,True)
    sc.doc.Views.Redraw()

def road_beds_and_walks():
    d=sc.sticky[TAG];assert not d.get('finish_objects'),'Already finished'
    mi=portal_material();black=next(i for i,m in enumerate(sc.doc.Materials)if m.Name=='沙嘴_石墨沥青')
    rows=[]
    for which,rid in [('west',WEST),('east',EAST)]:
        face=obj(rid).Geometry.Faces[0];surface=face.UnderlyingSurface();start,end=d[which+'_range'];start-=26;end-=.5
        n=int(math.ceil(end-start));samples=[start+(end-start)*i/n for i in range(n+1)]
        def solid_mesh(toprows,depth):
            m=G.Mesh();ny=len(toprows[0]);nv=(n+1)*ny
            for row in toprows:
                for p in row:m.Vertices.Add(p)
            for row in toprows:
                for p in row:m.Vertices.Add(p-G.Vector3d.ZAxis*depth)
            for i in range(n):
                for j in range(ny-1):
                    k=i*ny+j;m.Faces.AddFace(k,k+ny,k+ny+1,k+1);m.Faces.AddFace(k+nv+1,k+ny+nv+1,k+ny+nv,k+nv)
                for j in [0,ny-1]:
                    k=i*ny+j;m.Faces.AddFace(k,k+nv,k+ny+nv,k+ny)
            for i in [0,n]:
                for j in range(ny-1):
                    k=i*ny+j;m.Faces.AddFace(k,k+1,k+1+nv,k+nv)
            m.UnifyNormals();m.Unweld(.6,True);m.Normals.ComputeNormals();m.Compact();assert m.IsValid and m.IsClosed
            return m
        bedrows=[];walkrows=[[],[]]
        for s in samples:
            p,a,normal=frame(which,s);uv=uvpoint(surface,p);v=uv.Y
            cross=[face.PointAt(face.Domain(0).T0,v),face.PointAt(face.Domain(0).T1,v)]
            if G.Vector3d.Multiply(cross[1]-cross[0],normal)<0:cross.reverse()
            bedrows.append([face.PointAt(face.Domain(0).ParameterAt(j/6),v)-G.Vector3d.ZAxis*.025 for j in range(7)])
            fade=smooth((s-start)/12)*(1-smooth((s-(end-12))/12))
            for side,sign in enumerate([-1,1]):
                edge=cross[side];pts=[]
                for offset in [.3,2.2]:
                    q=edge+normal*(sign*offset);q.Z=p.Z-.08+.18*fade;pts.append(q)
                walkrows[side].append(pts)
        for name,g,mat in [('铺装下实体基层',solid_mesh(bedrows,.44),black),
                           ('左侧连续步行肩',solid_mesh(walkrows[0],.38),mi),('右侧连续步行肩',solid_mesh(walkrows[1],.38),mi)]:
            a=Rhino.DocObjects.ObjectAttributes();a.Name=which+'_'+name;a.LayerIndex=layer('05_路基与步行肩')
            a.MaterialIndex=mat;a.MaterialSource=Rhino.DocObjects.ObjectMaterialSource.MaterialFromObject;a.SetUserString('recipe',TAG)
            oid=sc.doc.Objects.AddMesh(g,a);assert oid!=System.Guid.Empty
            rows.append({'id':str(oid),'name':a.Name,'layer':'05_路基与步行肩'})
    d['objects'].extend(rows);d['finish_objects']=rows
    sc.doc.Views.Redraw()

def light_reveals():
    d=sc.sticky[TAG];assert not d.get('light_objects'),'Already added'
    mat=Rhino.DocObjects.Material();mat.Name='隧道_内收暖色灯槽';mat.DiffuseColor=Color.FromArgb(238,188,112);mat.ToPhysicallyBased()
    mat.PhysicallyBased.BaseColor=Rhino.Display.Color4f(.85,.53,.20,1)
    mat.PhysicallyBased.Emission=Rhino.Display.Color4f(1.,.64,.27,1.);mat.PhysicallyBased.Roughness=.45
    mi=sc.doc.Materials.Add(mat);rows=[]
    for which in ['west','east']:
        start,end=d[which+'_range'];mesh=G.Mesh();n=int(math.ceil((end-start)/1.2));sides=8
        for theta in [.55,math.pi-.55]:
            base=mesh.Vertices.Count
            for i in range(n+1):
                s=start+2+(end-start-4)*i/n;p,a,normal=frame(which,s);half,h,roof,foot,gz=dimensions(which,s)
                y=-half*math.cos(theta)*.995;z=p.Z-.65+(h+.65)*math.sin(theta)**.6-.12
                center=point(which,s,y,z)
                for j in range(sides):
                    angle=2*math.pi*j/sides;mesh.Vertices.Add(center+normal*(.055*math.cos(angle))+G.Vector3d.ZAxis*(.055*math.sin(angle)))
            for i in range(n):
                for j in range(sides):
                    k=base+i*sides+j;l=base+i*sides+(j+1)%sides;mesh.Faces.AddFace(k,l,l+sides,k+sides)
        mesh.Normals.ComputeNormals();mesh.Compact();assert mesh.IsValid
        a=Rhino.DocObjects.ObjectAttributes();a.Name=which+'_拱腹内收灯槽';a.LayerIndex=layer('06_内收灯槽')
        a.MaterialIndex=mi;a.MaterialSource=Rhino.DocObjects.ObjectMaterialSource.MaterialFromObject;a.SetUserString('recipe',TAG)
        oid=sc.doc.Objects.AddMesh(mesh,a);assert oid!=System.Guid.Empty
        rows.append({'id':str(oid),'name':a.Name,'layer':'06_内收灯槽'})
    d['objects'].extend(rows);d['light_objects']=rows;sc.doc.Views.Redraw()

def save():
    d=sc.sticky[TAG];v=d['verification']
    assert v['original_geometry_unchanged']and v['original_front_unhidden']
    for which in ['west','east']:
        assert not v[which]['clearance_failures']and not v[which]['traffic_volume_intrusions']
    assert not d['wall_travel_check']['conflicts']
    path='D:/Prism Route/map/map_1017_tunnel_portals_v01.3dm';assert not os.path.exists(path)
    assert sc.doc.SaveAs(path)
    if sc.doc.Path.replace('\\','/').lower()!=path.lower():Rhino.RhinoApp.RunScript('_-SaveAs "'+path.replace('/','\\')+'" _Enter _Yes',False)
    assert sc.doc.Path.replace('\\','/').lower()==path.lower()and not sc.doc.Modified
    write('publication.json',{'objects':d['objects'],'retired_objects':d.get('retired_objects',[]),'hidden_originals':[WALL,SOIL],'retained_front':OLD_FRONT,'backup':d['backup']})
    write('scope.json',{'west_closed_range':d['west_range'],'east_range':d['east_range'],'coastal_wall_cross':d['coastal_cross'],'retain_low_front':OLD_FRONT,
                       'description':'Existing front arch retained; full enclosure begins behind it. Coastal mouth follows actual wide road.'})
    write('saved.json',{'scene':path,'active_document':sc.doc.Path,'backup':d['backup']});print('Saved '+path)
