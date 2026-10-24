# -*- coding: utf-8 -*-
"""Local solid spit and shore road. Cape/sandbar shape remains unchanged.

No editing of an existing Brep surface table. Planar UV trimming uses the
supported CopyTrimCurves API on an unchanged source surface.
"""
from __future__ import unicode_literals,division
import Rhino,scriptcontext as sc,System,math,os,io,json,datetime
from System.Drawing import Color
G=Rhino.Geometry
ROOT='D:/Prism Route/prism-route'
OUT=ROOT+'/docs/concepts/spit_road_1017_v01'
TAG='spit_road_1017_v01';LAYER='1017_沙嘴与沿岸道路_v01'
CAP='1435beff-efcc-4af8-9837-27269aca4586';ROAD='60f020cf-5e56-4bbd-b67f-9059a1ab401c'
ROUTE='cdd81362-826e-4133-b37d-94bf806717f9'
SMALL='c34009e4-d6a5-420c-b0f9-f19d0f78cfc5';LONG='63c66d8c-cc9e-4399-b804-6042fb2e4a40'
START=1450.
PAVEMENT_DEPTH=.46
def obj(s):return sc.doc.Objects.FindId(System.Guid(s))
def xyz(p):return [float(p.X),float(p.Y),float(p.Z)]
def write(name,data):
    if not os.path.isdir(OUT):os.makedirs(OUT)
    with io.open(os.path.join(OUT,name),'w',encoding='utf8')as f:f.write(unicode(json.dumps(data,ensure_ascii=False,indent=2,default=str)))
def read(name):
    with io.open(os.path.join(OUT,name),'r',encoding='utf8')as f:return json.load(f)
def smooth(t):
    t=max(0,min(1,t));return t*t*t*(10+t*(-15+6*t))
def allobjects():
    e=Rhino.DocObjects.ObjectEnumeratorSettings();e.HiddenObjects=True;e.LockedObjects=True;e.NormalObjects=True
    return list(sc.doc.Objects.GetObjectList(e))
def prepare():
    assert TAG not in sc.sticky,'Do not reset an existing study'
    c=obj(ROUTE).Geometry.DuplicateCurve();end=c.GetLength()-90;ok,t=c.LengthParameter(START);p=c.PointAt(t)
    old=obj(ROAD).Geometry;hits=[]
    for f in old.Faces:
        ok,u,v=f.ClosestPoint(p);hits.append((f.PointAt(u,v).DistanceTo(p),int(f.FaceIndex),u,v))
    error,fi,u,v=min(hits);assert error<.01 and fi==6
    face=old.Faces[fi];cross=face.IsoCurve(0,v)
    kept=[f.DuplicateFace(False)for f in old.Faces if f.FaceIndex in [0,7,8]]
    kept.append(face.UnderlyingSurface().Trim(face.Domain(0),G.Interval(v,face.Domain(1).T1)).ToBrep())
    kept=list(G.Brep.JoinBreps(kept,.001));assert all(b.IsValid for b in kept)
    m=obj(SMALL).Geometry;last=[G.Point3d(m.Vertices[i])for i in range(7)]
    lm=obj(LONG).Geometry;lp=G.Point3d(lm.Vertices[3]);ok,lt=c.ClosestPoint(lp);ls=c.GetLength(G.Interval(c.Domain.T0,lt))-START
    cp=obj(CAP).Geometry;mp=G.MeshingParameters();mp.MaximumEdgeLength=9;mp.Tolerance=.08;mp.RefineGrid=True
    ground=G.Mesh()
    for part in G.Mesh.CreateFromBrep(cp,mp):ground.Append(part)
    sc.sticky[TAG]={'curve':c,'end':end,'length':end-START,'full_length':c.GetLength()-START,'cross':cross,'last_cross':last,
                    'long_station':ls,'long_z':lp.Z,'retained_road':kept,'ground':ground,
                    'source_crc':{str(o.Id):int(o.Geometry.DataCRC(0))for o in allobjects()},
                    'source_visibility':{str(o.Id):not o.IsHidden for o in allobjects()},
                    'begin_view':Rhino.DocObjects.ViewportInfo(sc.doc.Views.ActiveView.ActiveViewport)}
    write('scope.json',{'scope':'Spit, its shore road, and existing bridge junctions only. The large cape/sandbar is unchanged outside the narrow corridor.',
                        'source_cap':CAP,'source_road':ROAD,'road_start_station':START,'road_end_station':end,'bridge_branch_station':ls,
                        'road_length':end-START,'terrain_length':c.GetLength()-START})
    print('Prepared local corridor; road %.2fm'% (end-START))
def frame(s):
    d=sc.sticky[TAG];ok,t=d['curve'].LengthParameter(max(0,min(d['curve'].GetLength(),START+s)))
    p=d['curve'].PointAt(t);a=d['curve'].TangentAt(t);a.Z=0;a.Unitize();return p,a,G.Vector3d(-a.Y,a.X,0)
def height(s):
    d=sc.sticky[TAG];length=d['length'];c=d['curve'];ok,t=c.LengthParameter(START);a=c.TangentAt(t)
    grade=a.Z/math.sqrt(a.X*a.X+a.Y*a.Y)
    m=obj(SMALL).Geometry;delta=G.Point3d(m.Vertices[10])-G.Point3d(m.Vertices[3]);eg=delta.Z/math.sqrt(delta.X**2+delta.Y**2)
    nodes=[(0,frame(0)[0].Z,grade),(65,2.,0),(300,3.2,0),(650,2.7,0),(950,1.8,0),
           (d['long_station']-15,d['long_z'],0),(d['long_station']+15,d['long_z'],0),(length,d['last_cross'][3].Z,eg)]
    s=max(0,min(length,s))
    for (a,za,ga),(b,zb,gb)in zip(nodes[:-1],nodes[1:]):
        if s<=b:
            t=(s-a)/(b-a);h=b-a
            return (2*t**3-3*t*t+1)*za+(t**3-2*t*t+t)*h*ga+(-2*t**3+3*t*t)*zb+(t**3-t*t)*h*gb
    return nodes[-1][1]
def roadpoint(s,y,dz=0):
    d=sc.sticky[TAG];p,a,n=frame(s);p+=n*y;p.Z=height(s)+dz
    for end,dist in [(0,s),(1,d['length']-s)]:
        if dist>=40:continue
        ss=0 if end==0 else d['length'];base,aa,nn=frame(ss)
        if end==0:
            c=d['cross'];t=(y+10)/20
            if G.Vector3d.Multiply(c.PointAtEnd-c.PointAtStart,nn)<0:t=1-t
            if 0<=t<=1:x=c.PointAtNormalizedLength(t)
            else:
                left,right=c.PointAtStart,c.PointAtEnd
                if G.Vector3d.Multiply(right-left,nn)<0:left,right=right,left
                x=left+(right-left)*((y+10)/20)
        else:
            left,right=d['last_cross'][0],d['last_cross'][-1]
            if G.Vector3d.Multiply(right-left,nn)<0:left,right=right,left
            x=left+(right-left)*((y+10)/20)
        nominal=base+nn*y;nominal.Z=height(ss)
        p+=(x-nominal)*(1-smooth(dist/40))
    return p
def groundz(p):
    d=sc.sticky[TAG];h=G.Intersect.Intersection.MeshRay(d['ground'],G.Ray3d(G.Point3d(p.X,p.Y,100),-G.Vector3d.ZAxis))
    return 100-h if h>=0 else .2
def widths(s):
    # Coast distances from the original plan are only guides. The sandbar
    # farther than 36m from the existing road is not part of this study.
    d=sc.sticky[TAG];rows=d['coast_sections'];station=START+s
    near=min(rows,key=lambda r:abs(r['s']-station))
    left=min(36,max(15,-near['left']+1.2));right=min(28,max(15,near['right']+1.2))
    if s>d['full_length']-25:
        factor=.13+.87*smooth((d['full_length']-s)/25);left*=factor;right*=factor
    return left,right,(-near['left']>37),(near['right']>29)
def build_spit():
    d=sc.sticky[TAG]
    with io.open(ROOT+'/docs/concepts/cape_spit_1017_v01/section_probe.json','r',encoding='utf8')as f:d['coast_sections']=json.load(f)['rows']
    length=d['full_length'];n=int(math.ceil((length-2)/9));stations=[(length-2)*i/n for i in range(n+1)]
    profiles=[];outline_left=[];outline_right=[];clip_left=[];clip_right=[]
    for s in stations:
        p,a,normal=frame(s);left,right,left_land,right_land=widths(s)
        top=height(s)-.28
        if s>d['length']:top=height(d['length'])-.28-.52*smooth((s-d['length'])/90)
        def edge(y,land):
            q=p+normal*y
            return groundz(q)+.07 if land else .22
        lz=edge(-left,left_land);rz=edge(right,right_land)
        # Continuous native top, rolled shores, and a solid underwater base.
        toppts=[(-left,lz),(-left+.7,lz),(-left+2,lz+.04),(-(left+11.3)/2,(lz+top)/2),
                (-13.3,top+.07),(-11,top),(-9,top),(-5,top),(0,top),(5,top),(9,top),(11,top),
                (13.3,top+.07),((right+11.3)/2,(rz+top)/2),(right-2,rz+.04),(right-.7,rz),(right,rz)]
        # Near the buried tip rescale the same topology to avoid crossing ribs.
        if min(left,right)<16.5:
            leftscale=left/15;rightscale=right/15
            toppts=[(-15*leftscale,.22),(-14.3*leftscale,.22),(-13*leftscale,.22),(-10*leftscale,.1),
                    (-8.8*leftscale,top+.07),(-7.3*leftscale,top),(-6*leftscale,top),(-3.3*leftscale,top),(0,top),
                    (3.3*rightscale,top),(6*rightscale,top),(7.3*rightscale,top),(8.8*rightscale,top+.07),(10*rightscale,.1),
                    (13*rightscale,.22),(14.3*rightscale,.22),(15*rightscale,.22)]
        # Loft control locations have monotonically increasing transverse XY.
        yy=[x for x,z in toppts];assert all(b>a for a,b in zip(yy[:-1],yy[1:])),str((s,left,right,yy))
        yz=toppts+[(right+.15,rz-.6),(right-.1,-3.8),(right-1,-4.1),(right*.5,-4.1),(0,-4.1),
                   (-left*.5,-4.1),(-left+1,-4.1),(-left+.1,-3.8),(-left-.15,lz-.6)]
        pts=[G.Point3d(p.X+normal.X*y,p.Y+normal.Y*y,z)for y,z in yz]
        c=G.NurbsCurve.Create(True,3,pts);assert c.IsValid and c.IsClosed;profiles.append(c)
        outline_left.append(xyz(p-normal*left));outline_right.append(xyz(p+normal*right))
        clip_left.append(xyz(p-normal*max(.5,left-1.0)));clip_right.append(xyz(p+normal*max(.5,right-1.0)))
    result=G.Brep.CreateFromLoft(profiles,G.Point3d.Unset,G.Point3d.Unset,G.LoftType.Normal,False)
    assert result and len(result)==1
    body=result[0].CapPlanarHoles(.001);assert body and body.IsValid and body.IsSolid
    if body.SolidOrientation==G.BrepSolidOrientation.Inward:body.Flip()
    d.update({'spit':body,'stations':stations,'clip_left':clip_left,'clip_right':clip_right})
    write('body.json',{'solid':bool(body.IsSolid),'faces':int(body.Faces.Count),'sections':len(stations),'width_limits':[72,56],
                       'note':'Maximum outer and inner half-widths are 36m and 28m; the large detached cape is untouched.'})
    print('Prepared solid NURBS spit with %d longitudinal stations'%len(stations))
def export_roads():
    d=sc.sticky[TAG];length=d['length'];n=int(math.ceil(length/1.0));rows=[]
    for i in range(n+1):
        s=length*i/n;rows.append({'s':s,'cross':[xyz(roadpoint(s,y))for y in [-10,-5,0,5,10]]})
    fixed=[]
    for sid in [LONG,SMALL]:
        m=obj(sid).Geometry;vv=[xyz(v)for v in m.Vertices]
        fixed.append({'id':sid,'v':vv,'f':[[int(f.A),int(f.B),int(f.C),int(f.D)]for f in m.Faces]})
    write('road_input.json',{'rows':rows,'fixed':fixed,'left':d['clip_left'],'right':d['clip_right']})
    print('Exported shared road and bridge constraints')
def uvpoint(surface,p):
    ok,u,v=surface.ClosestPoint(G.Point3d(p[0],p[1],0));assert ok
    for _ in range(5):
        ok,q,der=surface.Evaluate(u,v,1);a,b=der[0],der[1];dx=p[0]-q.X;dy=p[1]-q.Y;det=a.X*b.Y-a.Y*b.X
        assert abs(det)>1e-10
        u+=(dx*b.Y-dy*b.X)/det;v+=(a.X*dy-a.Y*dx)/det
        if dx*dx+dy*dy<1e-12:break
    return G.Point3d(u,v,0)
def trim_old_cap():
    d=sc.sticky[TAG];data=read('road_geometry.json');face=obj(CAP).Geometry.Faces[0];surface=face.UnderlyingSurface();source=face.Loops[0].To2dCurve()
    cutters=[]
    for loop in data['cutters']:
        pts=[uvpoint(surface,p)for p in loop];pts.append(pts[0])
        cutters.append(G.PolylineCurve(pts))
    if source.ClosedCurveOrientation(G.Plane.WorldXY)==G.CurveOrientation.Clockwise:source.Reverse()
    curves=G.Curve.CreateBooleanDifference(source,cutters,.015);assert curves,'Planar UV trim failed'
    # Correct UV coordinates are preserved by an explicit WorldXY plane.
    outers=[c for c in curves if c.ClosedCurveOrientation(G.Plane.WorldXY)==G.CurveOrientation.CounterClockwise]
    inners=[c for c in curves if c not in outers];caps=[]
    assert outers
    for outer in outers:
        children=[c for c in inners if outer.Contains(c.PointAtStart,G.Plane.WorldXY,.01)==G.PointContainment.Inside]
        plane=G.Brep.CreateFromSurface(G.PlaneSurface(G.Plane.WorldXY,face.Domain(0),face.Domain(1)))
        flat=plane.Faces[0].Split([outer]+children,.01);assert flat and flat.IsValid
        area=G.AreaMassProperties.Compute(outer).Area-sum(G.AreaMassProperties.Compute(c).Area for c in children)
        target=min(list(flat.Faces),key=lambda f:abs(G.AreaMassProperties.Compute(f).Area-area))
        assert abs(G.AreaMassProperties.Compute(target).Area-area)<max(.02,area*1e-6)
        # Split preserves the full underlying parameter domains. CopyTrimCurves
        # therefore leaves every surviving source UV coordinate unchanged.
        assert abs(target.Domain(0).T0-face.Domain(0).T0)<1e-9
        cap=G.Brep.CopyTrimCurves(target,surface,.01);assert cap and cap.IsValid;caps.append(cap)
    d['trimmed_cap']=caps
    print('Prepared unchanged source terrain with the local corridor trimmed')

def mesh(row,depth=None):
    m=G.Mesh();v=row['v'];n=len(v)
    for p in v:m.Vertices.Add(*p)
    if depth is not None:
        for x,y,z in v:m.Vertices.Add(x,y,z-depth)
    edges={}
    for f in row['f']:
        if len(f)==3:
            a,b,c=f;m.Faces.AddFace(a,b,c)
            if depth is not None:
                m.Faces.AddFace(c+n,b+n,a+n)
                for x,y in [(a,b),(b,c),(c,a)]:
                    key=(min(x,y),max(x,y));edges[key]=None if key in edges else(x,y)
        else:m.Faces.AddFace(*f)
    if depth is not None:
        for edge in edges.values():
            if edge:
                a,b=edge;m.Faces.AddFace(b,a,a+n,b+n)
    m.UnifyNormals();m.Unweld(.6,True);m.Normals.ComputeNormals();m.Compact();assert m.IsValid
    if depth is not None:assert m.IsClosed
    return m
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
    geo=read('road_geometry.json');d['roads']=[mesh(r,PAVEMENT_DEPTH)for r in geo['roads']]
    d['roadtop']=G.Mesh()
    for r in geo['roads']:d['roadtop'].Append(mesh(r))
    d['lines']=[mesh(r)for r in geo['markings']if r['f']]
    cap=G.Brep()
    for b in d['trimmed_cap']:cap.Append(b)
    assert cap.IsValid
    d['cap']=cap
    backup='D:/Prism Route/map/map_1016_before_spit_local_'+datetime.datetime.now().strftime('%Y%m%d_%H%M%S')+'.3dm'
    options=Rhino.FileIO.FileWriteOptions();options.UpdateDocumentPath=False;options.IncludeRenderMeshes=False;options.SuppressAllInput=True;options.SuppressDialogBoxes=True
    assert sc.doc.Write3dmFile(backup,options);d['backup']=backup
    rec=sc.doc.BeginUndoRecord('沙嘴与沿岸道路_局部连续曲面');rows=[]
    try:
        def mat(name,rgb,shine,reflect):
            m=Rhino.DocObjects.Material();m.Name=name;m.DiffuseColor=Color.FromArgb(*rgb);m.Shine=shine;m.Reflectivity=reflect
            return sc.doc.Materials.Add(m)
        white=mat('沙嘴_暖白半光建筑覆面',[239,235,226],80,.18)
        asphalt=mat('沙嘴_石墨沥青',[53,58,61],12,.02)
        paint=mat('沙嘴_暖白标线',[235,233,220],10,.01)
        def add(g,name,child,mi=None,source=None):
            a=obj(source).Attributes.Duplicate()if source else Rhino.DocObjects.ObjectAttributes()
            if source:
                original=obj(source);oldlayer=sc.doc.Layers[a.LayerIndex]
                if a.MaterialSource==Rhino.DocObjects.ObjectMaterialSource.MaterialFromLayer:
                    a.MaterialIndex=oldlayer.MaterialIndex;a.MaterialSource=Rhino.DocObjects.ObjectMaterialSource.MaterialFromObject
                if a.ColorSource==Rhino.DocObjects.ObjectColorSource.ColorFromLayer:
                    a.ObjectColor=oldlayer.Color;a.ColorSource=Rhino.DocObjects.ObjectColorSource.ColorFromObject
            a.ObjectId=System.Guid.Empty;a.Name=name;a.LayerIndex=layer(child);a.SetUserString('recipe',TAG)
            if mi is not None:
                a.MaterialIndex=mi;a.MaterialSource=Rhino.DocObjects.ObjectMaterialSource.MaterialFromObject
                a.ObjectColor=sc.doc.Materials[mi].DiffuseColor;a.ColorSource=Rhino.DocObjects.ObjectColorSource.ColorFromObject
            oid=sc.doc.Objects.AddMesh(g,a)if isinstance(g,G.Mesh)else sc.doc.Objects.AddBrep(g,a)
            assert oid!=System.Guid.Empty;rows.append({'id':str(oid),'name':name,'layer':child})
        add(d['cap'],'原地形_仅让出沙嘴道路覆盖区','01_原地形_局部让位',source=CAP)
        add(d['spit'],'沙嘴_连续实体岸带_NURBS','02_沙嘴连续实体',white)
        configure_spit_display(obj(rows[-1]['id']))
        for i,b in enumerate(d['retained_road']):add(b,'原岸路_保留北段_%d'%i,'03_保留岸路_原样',source=ROAD)
        for i,m in enumerate(d['roads']):add(m,'沙嘴_连续道路_%d'%i,'04_重建沿岸道路',asphalt)
        for i,m in enumerate(d['lines']):add(m,'沙嘴_道路标线_%d'%i,'05_标线',paint)
        for sid in [CAP,ROAD]:assert sc.doc.Objects.Hide(System.Guid(sid),True)
        d['objects']=rows;sc.doc.Objects.UnselectAll()
    finally:sc.doc.EndUndoRecord(rec);sc.doc.Views.Redraw()
    write('publication.json',{'objects':rows,'backup':backup,'hidden_originals':[CAP,ROAD]})
    print('Published %d local objects; only two originals hidden'%len(rows))
def configure_spit_display(o):
    """Keep broad rolled surfaces smooth in close viewport inspection."""
    p=G.MeshingParameters();p.MaximumEdgeLength=2.;p.MinimumEdgeLength=.03;p.Tolerance=.015
    p.RefineGrid=True;p.JaggedSeams=False
    assert o.SetRenderMeshParameters(p)
    o.CreateMeshes(G.MeshType.Render,p,False)

def remesh(brep,maxedge=2):
    p=G.MeshingParameters();p.MaximumEdgeLength=maxedge;p.MinimumEdgeLength=.03;p.Tolerance=.025;p.RefineGrid=True;p.JaggedSeams=False
    m=G.Mesh()
    for part in G.Mesh.CreateFromBrep(brep,p):m.Append(part)
    m.Vertices.CombineIdentical(True,True);m.UnifyNormals();m.Normals.ComputeNormals();m.Compact();return m
def verify():
    d=sc.sticky[TAG];land=remesh(d['spit'],3);d['spitmesh']=land
    gaps=[];groundbad=[];bodybad=[];surface=obj(CAP).Geometry.Faces[0].UnderlyingSurface()
    for s in [d['length']*i/400 for i in range(1,400)]:
        for y in [-9,0,9]:
            p=roadpoint(s,y);ray=G.Ray3d(G.Point3d(p.X,p.Y,100),-G.Vector3d.ZAxis)
            rd=G.Intersect.Intersection.MeshRay(d['roadtop'],ray)
            if rd<0:continue # Fixed bridge owns its footprint.
            a=G.Intersect.Intersection.MeshRay(land,ray)
            if a>=0:
                gap=a-rd;gaps.append(gap)
                if gap<.04:bodybad.append([s,y,gap])
            uv=uvpoint(surface,xyz(p));inside=any(f.IsPointOnFace(uv.X,uv.Y)!=G.PointFaceRelation.Exterior for f in d['cap'].Faces)
            if inside:
                terrain_z=surface.PointAt(uv.X,uv.Y).Z;gap=100-rd-terrain_z
                if gap<.04:groundbad.append([s,y,gap])
    start=[];end=[]
    for y in [-10,-5,0,5,10]:
        for s,errors in [(0,start),(d['length'],end)]:
            p=roadpoint(s,y);q=d['roadtop'].ClosestMeshPoint(p,1);errors.append(p.DistanceTo(q.Point)if q else 99)
    unchanged=all(obj(sid)and int(obj(sid).Geometry.DataCRC(0))==crc for sid,crc in d['source_crc'].items())
    report={'original_geometry_unchanged':unchanged,'spit_valid_solid':bool(d['spit'].IsValid and d['spit'].IsSolid),
            'spit_faces':int(d['spit'].Faces.Count),'road_samples':len(gaps),'minimum_road_body_gap':min(gaps)if gaps else None,
            'maximum_road_body_gap':max(gaps)if gaps else None,'pavement_depth_m':PAVEMENT_DEPTH,
            'sampled_pavement_embeds_in_body':bool(gaps and max(gaps)<PAVEMENT_DEPTH),
            'body_conflicts':bodybad,'retained_terrain_conflicts':groundbad,
            'north_head_error_m':max(start),'small_bridge_head_error_m':max(end),'cape_sandbar_remodelled':False,
            'limitation':'Rhino geometry samples only; game driving/collider validation not performed.'}
    d['verification']=report;write('verification.json',report);print(json.dumps(report));return report
def view(kind):
    vp=sc.doc.Views.ActiveView.ActiveViewport;vp.ChangeToPerspectiveProjection(True,45)
    vp.DisplayMode=next(x for x in Rhino.Display.DisplayModeDescription.GetDisplayModes()if x.EnglishName=='Rendered')
    if kind=='overview':vp.SetCameraLocations(G.Point3d(1410,1710,0),G.Point3d(950,2550,800))
    elif kind=='road':vp.SetCameraLocations(G.Point3d(1610,1725,2),G.Point3d(1670,1810,38))
    elif kind=='bridge':vp.SetCameraLocations(G.Point3d(841,1722,1),G.Point3d(960,1920,100))
    sc.doc.Views.Redraw()
def capture(name):
    c=Rhino.Display.ViewCapture();c.Width=1800;c.Height=1100;c.DrawGrid=False;c.DrawAxes=False;c.DrawGridAxes=False
    bmp=c.CaptureToBitmap(sc.doc.Views.ActiveView);path=OUT+'/'+name+'.png';bmp.Save(path,System.Drawing.Imaging.ImageFormat.Png);bmp.Dispose();print(path)

def finish():
    d=sc.sticky[TAG];assert not d.get('rails'),'Already finished'
    geo=read('road_geometry.json');d['roads']=[mesh(r,PAVEMENT_DEPTH)for r in geo['roads']]
    for row,g in zip([r for r in d['objects']if r['layer']=='04_重建沿岸道路'],d['roads']):
        assert sc.doc.Objects.Replace(System.Guid(row['id']),g)
    rails=G.Mesh();posts=G.Mesh();length=d['length'];n=int(math.ceil(length/1.8));samples=[length*i/n for i in range(n+1)]
    for sign in [-1,1]:
        for offset,radius in [(1.2,.085),(.65,.045)]:
            m=G.Mesh();sides=10
            for s in samples:
                h=offset*(.18+.82*smooth(s/20));p=roadpoint(s,sign*11.7,h);normal=frame(s)[2]
                for j in range(sides):
                    a=2*math.pi*j/sides;m.Vertices.Add(p+normal*(radius*math.cos(a))+G.Vector3d.ZAxis*(radius*math.sin(a)))
            for i in range(n):
                if sign==1 and abs((samples[i]+samples[i+1])/2-d['long_station'])<22:continue
                for j in range(sides):
                    a=i*sides+j;b=i*sides+(j+1)%sides;m.Faces.AddFace(a,b,b+sides,a+sides)
            rails.Append(m)
        for i in range(int(length/5)+1):
            s=length*i/int(length/5)
            if sign==1 and abs(s-d['long_station'])<22:continue
            p=roadpoint(s,sign*11.7,-.35);height=1.2*(.18+.82*smooth(s/20))+.35
            posts.Append(G.Mesh.CreateFromCylinder(G.Cylinder(G.Circle(G.Plane(p,G.Vector3d.ZAxis),.065),height),1,10,True,True))
    material=Rhino.DocObjects.Material();material.Name='沙嘴_浅灰金属低护栏';material.DiffuseColor=Color.FromArgb(177,184,182);material.Shine=100;material.Reflectivity=.4
    mi=sc.doc.Materials.Add(material);rows=[]
    for i,m in enumerate([rails,posts]):
        m.Normals.ComputeNormals();m.Compact();assert m.IsValid
        a=Rhino.DocObjects.ObjectAttributes();a.Name='沙嘴_低护栏_%d'%i;a.LayerIndex=layer('06_低护栏');a.MaterialIndex=mi
        a.MaterialSource=Rhino.DocObjects.ObjectMaterialSource.MaterialFromObject;a.SetUserString('recipe',TAG)
        oid=sc.doc.Objects.AddMesh(m,a);assert oid!=System.Guid.Empty;rows.append({'id':str(oid),'name':a.Name,'layer':'06_低护栏'})
    d['rails']=rows;d['objects'].extend(rows)
    write('publication.json',{'objects':d['objects'],'backup':d['backup'],'hidden_originals':[CAP,ROAD]})
    sc.doc.Views.Redraw();print('Pavement bed and low rails completed; lagoon bridge junction left open')

def connection_checks():
    d=sc.sticky[TAG];errors=[];m=obj(LONG).Geometry
    for i in range(7):
        p=G.Point3d(m.Vertices[i]);q=d['roadtop'].ClosestMeshPoint(p,2);errors.append(p.DistanceTo(q.Point)if q else 99)
    face=obj(CAP).Geometry.Faces[0];s=face.UnderlyingSurface();cape=[]
    for xy in [(2100,2200),(2200,2200),(2000,2200),(2150,2350),(2200,2300)]:
        uv=uvpoint(s,list(xy));before=face.IsPointOnFace(uv.X,uv.Y)!=G.PointFaceRelation.Exterior
        after=any(f.IsPointOnFace(uv.X,uv.Y)!=G.PointFaceRelation.Exterior for f in d['cap'].Faces)
        distances=[s.PointAt(uv.X,uv.Y).DistanceTo(f.UnderlyingSurface().PointAt(uv.X,uv.Y))for f in d['cap'].Faces]
        cape.append({'xy':xy,'before':before,'after':after,'surface_position_error':min(distances)})
    report={'long_bridge_head_max_error_m':max(errors),'cape_samples':cape,'new_pavement_closed':all(m.IsClosed for m in d['roads']),
            'pavement_depth_m':PAVEMENT_DEPTH,'spit_road_gap_max_allowed_for_embed':PAVEMENT_DEPTH}
    d['connections']=report;write('connection_checks.json',report);print(json.dumps(report));return report

def save():
    d=sc.sticky[TAG];v=d['verification'];c=d['connections']
    assert v['original_geometry_unchanged']and not v['body_conflicts']and not v['retained_terrain_conflicts']
    assert v['sampled_pavement_embeds_in_body']
    assert c['long_bridge_head_max_error_m']<.015
    assert all(x['before']==x['after']and x['surface_position_error']<1e-8 for x in c['cape_samples'])
    path='D:/Prism Route/map/map_1017_spit_road_v01.3dm'
    assert not os.path.exists(path),'Do not overwrite an existing revision'
    options=Rhino.FileIO.FileWriteOptions();options.UpdateDocumentPath=True;options.IncludeRenderMeshes=False;options.SuppressAllInput=True;options.SuppressDialogBoxes=True
    assert sc.doc.Write3dmFile(path,options)
    # Write3dmFile can leave the live document attached to its old file.
    if sc.doc.Path.replace('\\','/').lower()!=path.lower():
        Rhino.RhinoApp.RunScript('_-SaveAs "'+path.replace('/','\\')+'" _Enter _Yes',False)
    assert sc.doc.Path.replace('\\','/').lower()==path.lower()
    assert not sc.doc.Modified
    write('saved.json',{'scene':path,'active_document':sc.doc.Path,'backup':d['backup']})
    print('Saved '+path+'; active '+sc.doc.Path)

def trim_bridge_furniture():
    d=sc.sticky[TAG];assert not d.get('bridge_furniture'),'Already trimmed'
    lm=obj(LONG).Geometry;p=G.Point3d(lm.Vertices[3]);q=G.Point3d(lm.Vertices[10]);axis=q-p;axis.Z=0;axis.Unitize()
    plane=G.Plane(p+axis*12,axis)
    posts=['2f134dbb-c424-4658-ae5e-28167003f187','763dbc2b-8491-4e6a-970a-78e79b386183']
    other=['bc401358-2a14-4000-9215-ff79cbc0018f','0cbb130e-a14c-40a2-82be-ee070a1279d2',
           '2012b733-4fc3-43e1-bd62-e01af811ea53','1217bac6-6657-4eaa-a4f0-667286664a65',
           '24c843b4-b46d-4dc6-8ec4-1a0270f2f094','a8cf7740-46e1-41b7-9430-e543d68ac140']
    rows=[]
    for sid in posts+other:
        old=obj(sid);assert old and isinstance(old.Geometry,G.Mesh)
        if sid in posts:
            pieces=[m for m in old.Geometry.SplitDisjointPieces()if plane.DistanceTo(m.GetBoundingBox(True).Center)>.02]
        else:
            split=old.Geometry.Split(plane);assert split
            pieces=[m for m in split if plane.DistanceTo(m.GetBoundingBox(True).Center)>.02]
        result=G.Mesh()
        for m in pieces:result.Append(m)
        result.FillHoles();result.Normals.ComputeNormals();result.Compact();assert result.IsValid and result.Faces.Count>0
        a=old.Attributes.Duplicate();a.ObjectId=System.Guid.Empty;a.LayerIndex=layer('07_长桥路口护栏退让');a.Name='路口退让_'+(old.Name or sid)
        a.SetUserString('recipe',TAG)
        oid=sc.doc.Objects.AddMesh(result,a);assert oid!=System.Guid.Empty
        assert sc.doc.Objects.Hide(old.Id,True)
        rows.append({'id':str(oid),'name':a.Name,'layer':'07_长桥路口护栏退让','source':sid})
    d['bridge_furniture']=rows;d['objects'].extend(rows)
    write('publication.json',{'objects':d['objects'],'backup':d['backup'],'hidden_originals':[CAP,ROAD]+posts+other})
    print('Retreated existing bridge rails, posts and edge bands to the actual road edge')
    sc.doc.Views.Redraw()
