# -*- coding: utf-8 -*-
"""Repair only the low opposite-shore road between the outlet and ascent.

Run stages explicitly in the live Rhino document. Source objects are hidden,
never reshaped. Retain the previously completed spit and both bridge assets.
"""
from __future__ import unicode_literals,division
import Rhino,scriptcontext as sc,System,math,io,json,os
from System.Drawing import Color
G=Rhino.Geometry
ROOT='D:/Prism Route/prism-route'
OUT=ROOT+'/docs/concepts/opposite_shore_road_1017_v01'
TAG='opposite_shore_road_1017_v01'
LAYER='1017_小桥另一侧岸路修正_v01'
ROUTE='2937ea84-2de9-4456-a5ac-8c233052abf0'
ROAD='b62a4e53-2495-4477-a10c-dff489b98855'
LAND='e8d79f0e-6908-48e3-af35-3d131f7da558'
BRIDGE='c34009e4-d6a5-420c-b0f9-f19d0f78cfc5'
START=90.;END=480.;DEPTH=.46

def obj(s):return sc.doc.Objects.FindId(System.Guid(s))
def xyz(p):return [float(p.X),float(p.Y),float(p.Z)]
def write(name,data):
    if not os.path.isdir(OUT):os.makedirs(OUT)
    with io.open(OUT+'/'+name,'w',encoding='utf8')as f:f.write(unicode(json.dumps(data,ensure_ascii=False,indent=2)))
def smooth(t):
    t=max(0,min(1,t));return t*t*t*(10+t*(-15+6*t))
def frame(s):
    c=sc.sticky[TAG]['route'];ok,t=c.LengthParameter(s);assert ok
    p=c.PointAt(t);a=c.TangentAt(t);a.Z=0;a.Unitize()
    return p,a,G.Vector3d(-a.Y,a.X,0)
def height(s):
    # Gentle broad lift, not per-vertex noise or a series of little ramps.
    return frame(s)[0].Z+.95*smooth((s-START)/65)*(1-smooth((s-400)/80))
def roadpoint(s,y,dz=0):
    d=sc.sticky[TAG];p,a,n=frame(s);p+=n*y;p.Z=height(s)+dz
    for i,dist in [(0,s-START),(1,END-s)]:
        if dist>=28:continue
        ss=START if i==0 else END;base,aa,nn=frame(ss)
        left,right=d['cross'][i]
        exact=left+(right-left)*((y+10)/20)
        nominal=base+nn*y;nominal.Z=height(ss)
        p+=(exact-nominal)*(1-smooth(dist/28))
    return p
def prepare():
    d=sc.sticky.get(TAG,{})
    assert not d.get('objects'),'Already published'
    d['route']=obj(ROUTE).Geometry.DuplicateCurve();sc.sticky[TAG]=d
    m=obj(BRIDGE).Geometry;last=[G.Point3d(m.Vertices[i])for i in range(m.Vertices.Count-7,m.Vertices.Count)]
    p,a,n=frame(START);left,right=last[0],last[-1]
    if G.Vector3d.Multiply(right-left,n)<0:left,right=right,left
    source=obj(ROAD).Geometry;p,a,n=frame(END);f=source.Faces[1];ok,u,v=f.ClosestPoint(p)
    assert ok and f.PointAt(u,v).DistanceTo(p)<.01
    ends=[f.PointAt(f.Domain(0).T0,v),f.PointAt(f.Domain(0).T1,v)]
    if G.Vector3d.Multiply(ends[1]-ends[0],n)<0:ends.reverse()
    d['cross']=[(left,right),tuple(ends)];d['cut_v']=v
    retained=[f.DuplicateFace(False)for f in source.Faces if f.FaceIndex not in [1,4]]
    retained.append(source.Faces[1].UnderlyingSurface().Trim(source.Faces[1].Domain(0),G.Interval(v,source.Faces[1].Domain(1).T1)).ToBrep())
    kept=list(G.Brep.JoinBreps(retained,.001));assert kept and all(b.IsValid for b in kept)
    d['retained']=kept
    e=Rhino.DocObjects.ObjectEnumeratorSettings();e.HiddenObjects=True;e.LockedObjects=True;e.NormalObjects=True
    d['source_crc']={str(o.Id):int(o.Geometry.DataCRC(0))for o in sc.doc.Objects.GetObjectList(e)}
    d['source_visibility']={str(o.Id):not o.IsHidden for o in sc.doc.Objects.GetObjectList(e)}
    print('Prepared 390m local correction; fixed bridge and upper road sections')

def closed_loft(sections):
    b=G.Brep.CreateFromLoft(sections,G.Point3d.Unset,G.Point3d.Unset,G.LoftType.Normal,False)
    assert b and len(b)==1
    b=b[0].CapPlanarHoles(.001);assert b and b.IsValid and b.IsSolid
    if b.SolidOrientation==G.BrepSolidOrientation.Inward:b.Flip()
    return b

def build():
    d=sc.sticky[TAG];sections=[];bank=[];n=130
    # Rectangle sections use degree-1 curves. Lofting along the length is smooth;
    # the road surface stays level transversely, including its exact end cuts.
    surface=obj(LAND).Geometry.Faces[0].UnderlyingSurface()
    uvpoint=sc.sticky['spit_recipe']['uvpoint']
    def oldground(p):
        uv=uvpoint(surface,xyz(p));return surface.PointAt(uv.X,uv.Y).Z
    for i in range(n+1):
        s=START+(END-START)*i/n
        l,r=roadpoint(s,-10),roadpoint(s,10)
        sections.append(G.PolylineCurve([l,r,r-G.Vector3d.ZAxis*DEPTH,l-G.Vector3d.ZAxis*DEPTH,l]))
        # One rolled roadbed, with broad shoulders returning to the unchanged
        # original surface at the margins. Buried base stays below water.
        top=height(s)-.28;p,a,normal=frame(s)
        lo=oldground(p-normal*18);hi=oldground(p+normal*18)
        yz=[(-18,lo+.015),(-17.5,lo+.015),(-16,lo+.02),(-14,(lo+top)/2),
            (-12,top),(-10,top),(-7,top),(0,top),(7,top),(10,top),(12,top),
            (14,(hi+top)/2),(16,hi+.02),(17.5,hi+.015),(18,hi+.015),
            (18.1,hi-.7),(17.8,-3.8),(16,-4),(0,-4),(-16,-4),(-17.8,-3.8),(-18.1,lo-.7)]
        pts=[]
        for y,z in yz:
            q=roadpoint(s,y);q.Z=z;pts.append(q)
        bank.append(G.NurbsCurve.Create(True,3,pts))
    d['pavement']=closed_loft(sections);d['bank']=closed_loft(bank)
    count=int(math.ceil((END-START)/.75));ys=[-10,-7,-3.5,0,3.5,7,10]
    def strip(yvalues,offset=0,segments=None):
        m=G.Mesh();ny=len(yvalues)
        for i in range(count+1):
            s=START+(END-START)*i/count
            for y in yvalues:m.Vertices.Add(roadpoint(s,y,offset))
        for i in range(count):
            s=START+(END-START)*(i+.5)/count
            if segments and not segments(s):continue
            for j in range(ny-1):
                k=i*ny+j;m.Faces.AddFace(k,k+ny,k+ny+1,k+1)
        m.Normals.ComputeNormals();m.Compact();assert m.IsValid
        return m
    d['roadtop']=strip(ys)
    d['markings']=[strip([-.065,.065],.022,lambda s:int((s-START)/9)%2==0),
                   strip([-9.6,-9.47],.022),strip([9.47,9.6],.022)]
    print('Prepared valid closed road and rolled roadbed; %d / %d native faces'%(d['pavement'].Faces.Count,d['bank'].Faces.Count))

def trim_land():
    d=sc.sticky[TAG];uvpoint=sc.sticky['spit_recipe']['uvpoint']
    face=obj(LAND).Geometry.Faces[0];surface=face.UnderlyingSurface();source=face.Loops[0].To2dCurve()
    # Offset inside the bank's edge, leaving a small buried overlap. Include
    # the already fixed small bridge footprint to remove its soil occlusion.
    rings=[]
    for sign in [-1,1]:
        rings.append([roadpoint(START+(END-START)*i/130,sign*17.1)for i in range(131)])
    outline=rings[0]+list(reversed(rings[1]));outline.append(outline[0])
    cutters=[G.PolylineCurve([uvpoint(surface,xyz(p))for p in outline])]
    m=obj(BRIDGE).Geometry;rows=m.Vertices.Count//7
    edge=[G.Point3d(m.Vertices[i*7])for i in range(rows)]+[G.Point3d(m.Vertices[i*7+6])for i in reversed(range(rows))]
    edge.append(edge[0]);cutters.append(G.PolylineCurve([uvpoint(surface,xyz(p))for p in edge]))
    if source.ClosedCurveOrientation(G.Plane.WorldXY)==G.CurveOrientation.Clockwise:source.Reverse()
    curves=G.Curve.CreateBooleanDifference(source,cutters,.01);assert curves
    outers=[c for c in curves if c.ClosedCurveOrientation(G.Plane.WorldXY)==G.CurveOrientation.CounterClockwise]
    inners=[c for c in curves if c not in outers];result=G.Brep()
    for outer in outers:
        children=[c for c in inners if outer.Contains(c.PointAtStart,G.Plane.WorldXY,.01)==G.PointContainment.Inside]
        plane=G.Brep.CreateFromSurface(G.PlaneSurface(G.Plane.WorldXY,face.Domain(0),face.Domain(1)))
        parts=plane.Faces[0].Split([outer]+children,.01);assert parts and parts.IsValid
        area=G.AreaMassProperties.Compute(outer).Area-sum(G.AreaMassProperties.Compute(c).Area for c in children)
        selected=min(parts.Faces,key=lambda f:abs(G.AreaMassProperties.Compute(f).Area-area))
        assert abs(G.AreaMassProperties.Compute(selected).Area-area)<max(.02,area*1e-6)
        b=G.Brep.CopyTrimCurves(selected,surface,.01);assert b and b.IsValid;result.Append(b)
    assert result.IsValid and result.Faces.Count>0;d['land_copy']=result
    print('Prepared original shore surface with only roadbed/bridge footprints removed')

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
    backup='D:/Prism Route/map/map_1017_before_opposite_shore_road.3dm'
    assert not os.path.exists(backup)
    opt=Rhino.FileIO.FileWriteOptions();opt.UpdateDocumentPath=False;opt.IncludeRenderMeshes=False;opt.SuppressAllInput=True;opt.SuppressDialogBoxes=True
    assert sc.doc.Write3dmFile(backup,opt);d['backup']=backup
    def material(name):
        return next(i for i,m in enumerate(sc.doc.Materials)if m.Name==name)
    white=material('沙嘴_暖白半光建筑覆面');asphalt=material('沙嘴_石墨沥青');paint=material('沙嘴_暖白标线')
    rows=[];rec=sc.doc.BeginUndoRecord('小桥另一侧低位岸路与路肩修正')
    try:
        def add(g,name,child,mi=None,source=None):
            a=obj(source).Attributes.Duplicate()if source else Rhino.DocObjects.ObjectAttributes()
            if source:
                l=sc.doc.Layers[a.LayerIndex]
                if a.MaterialSource==Rhino.DocObjects.ObjectMaterialSource.MaterialFromLayer:
                    a.MaterialIndex=l.MaterialIndex;a.MaterialSource=Rhino.DocObjects.ObjectMaterialSource.MaterialFromObject
                if a.ColorSource==Rhino.DocObjects.ObjectColorSource.ColorFromLayer:
                    a.ObjectColor=l.Color;a.ColorSource=Rhino.DocObjects.ObjectColorSource.ColorFromObject
            a.ObjectId=System.Guid.Empty;a.Name=name;a.LayerIndex=layer(child);a.SetUserString('recipe',TAG)
            if mi is not None:
                a.MaterialIndex=mi;a.MaterialSource=Rhino.DocObjects.ObjectMaterialSource.MaterialFromObject
                a.ObjectColor=sc.doc.Materials[mi].DiffuseColor;a.ColorSource=Rhino.DocObjects.ObjectColorSource.ColorFromObject
            oid=sc.doc.Objects.AddMesh(g,a)if isinstance(g,G.Mesh)else sc.doc.Objects.AddBrep(g,a)
            assert oid!=System.Guid.Empty
            if isinstance(g,G.Brep)and not source:sc.sticky['spit_recipe']['configure_spit_display'](obj(str(oid)))
            rows.append({'id':str(oid),'name':name,'layer':child})
        add(d['land_copy'],'原岸地形_道路及小桥局部让位','01_保留原地形',source=LAND)
        for b in d['retained']:add(b,'原岸路_保留上坡及北段','02_保留原岸路',source=ROAD)
        add(d['bank'],'岸路_连续圆顺路基与路肩','03_连续路肩实体',white)
        add(d['pavement'],'岸路_修正纵坡与桥头接续','04_修正路面',asphalt)
        for i,m in enumerate(d['markings']):add(m,'岸路_标线_%d'%i,'05_标线',paint)
        for sid in [ROAD,LAND]:assert sc.doc.Objects.Hide(System.Guid(sid),True)
        d['objects']=rows
    finally:sc.doc.EndUndoRecord(rec);sc.doc.Views.Redraw()
    write('publication.json',{'objects':rows,'hidden_originals':[ROAD,LAND],'backup':backup,'stations':[START,END]})
    print('Published local correction; source road and terrain preserved hidden')

def verify():
    d=sc.sticky[TAG];remesh=sc.sticky['spit_recipe']['remesh'];bank=remesh(d['bank'],1.5)
    uvpoint=sc.sticky['spit_recipe']['uvpoint'];surface=obj(LAND).Geometry.Faces[0].UnderlyingSurface()
    bad=[];gaps=[];groundbad=[];samples=0;minimum_z=100
    for i in range(1,391):
        s=START+(END-START)*(i-.371)/390
        for y in [-9.9,-5,0,5,9.9]:
            p=roadpoint(s,y);minimum_z=min(minimum_z,p.Z);ray=G.Ray3d(G.Point3d(p.X,p.Y,150),-G.Vector3d.ZAxis)
            a=G.Intersect.Intersection.MeshRay(bank,ray);b=G.Intersect.Intersection.MeshRay(d['roadtop'],ray)
            assert a>=0 and b>=0
            gap=a-b;gaps.append(gap);samples+=1
            if gap<.06 or gap>DEPTH:bad.append([s,y,gap])
            uv=uvpoint(surface,xyz(p))
            if any(f.IsPointOnFace(uv.X,uv.Y)!=G.PointFaceRelation.Exterior for f in d['land_copy'].Faces):
                if surface.PointAt(uv.X,uv.Y).Z>p.Z-.04:groundbad.append([s,y])
            for sid,m in d.get('land',[]):
                if sid==LAND:continue
                hit=G.Intersect.Intersection.MeshRay(m,ray)
                if hit>=0 and 150-hit>p.Z-.04:groundbad.append([s,y,sid,150-hit-p.Z])
    heads=[]
    for i,s in enumerate([START,END]):
        left,right=d['cross'][i]
        heads.append(max(roadpoint(s,y).DistanceTo(left+(right-left)*((y+10)/20))for y in [-10,-5,0,5,10]))
    unchanged=all(obj(sid)and int(obj(sid).Geometry.DataCRC(0))==crc for sid,crc in d['source_crc'].items())
    report={'length_m':END-START,'samples':samples,'minimum_road_z':minimum_z,'bank_clearance_range':[min(gaps),max(gaps)],
            'bank_conflicts_or_unsupported_samples':bad,'other_terrain_conflicts':groundbad,'head_errors_m':heads,
            'pavement_valid_closed':bool(d['pavement'].IsValid and d['pavement'].IsSolid),
            'bank_valid_closed':bool(d['bank'].IsValid and d['bank'].IsSolid),'original_geometry_unchanged':unchanged,
            'game_driving_tested':False}
    d['verification']=report;write('verification.json',report);print(json.dumps(report))
    return report

def capture(name):
    c=Rhino.Display.ViewCapture();c.Width=1800;c.Height=1100;c.DrawGrid=False;c.DrawAxes=False;c.DrawGridAxes=False
    b=c.CaptureToBitmap(sc.doc.Views.ActiveView);b.Save(OUT+'/'+name+'.png',System.Drawing.Imaging.ImageFormat.Png);b.Dispose()

def save():
    d=sc.sticky[TAG];v=d['verification']
    assert v['original_geometry_unchanged']and not v['bank_conflicts_or_unsupported_samples']and not v['other_terrain_conflicts']
    assert max(v['head_errors_m'])<.01 and v['pavement_valid_closed']and v['bank_valid_closed']
    p='D:/Prism Route/map/map_1017_spit_road_v02.3dm';assert not os.path.exists(p)
    assert sc.doc.SaveAs(p)
    if sc.doc.Path.replace('\\','/').lower()!=p.lower():
        Rhino.RhinoApp.RunScript('_-SaveAs "'+p.replace('/','\\')+'" _Enter _Yes',False)
    assert sc.doc.Path.replace('\\','/').lower()==p.lower()and not sc.doc.Modified
    write('saved.json',{'scene':p,'active_document':sc.doc.Path,'backup':d['backup']});print('Saved '+p)
