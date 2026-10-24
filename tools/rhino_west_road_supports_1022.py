# -*- coding: utf-8 -*-
"""Staged NURBS foundations, viaduct and platform stitch for the selected west road."""
from __future__ import unicode_literals, division
import Rhino, scriptcontext as sc, System, math, bisect, io, json
G=Rhino.Geometry
ROOT='D:/Prism Route/prism-route'
CACHE=ROOT+'/.current_map_build'
TAG='west_road_supports_1022'
ROAD='305479e8-59d9-4a89-bcf6-204f69186e51'
BODY='d348f4df-9b88-42a1-b57e-64023ce5f1ad'
PIERS=[150.,208.,266.,324.,382.,440.,498.,556.,614.,672.,716.]

def obj(key):return sc.doc.Objects.FindId(System.Guid(key))
def xyz(p):return [p.X,p.Y,p.Z]
def smooth(t):
    t=max(0.,min(1.,t));return t*t*t*(10-15*t+6*t*t)
def unit(v):
    v=G.Vector3d(v);assert v.Unitize();return v
def write(name,value):
    with io.open(CACHE+'/'+name,'w',encoding='utf-8')as f:f.write(json.dumps(value,ensure_ascii=False,indent=2))
def objects():
    e=Rhino.DocObjects.ObjectEnumeratorSettings();e.NormalObjects=True;e.HiddenObjects=True;e.LockedObjects=True
    return list(sc.doc.Objects.GetObjectList(e))
def mesh(g,step=3.):
    p=G.MeshingParameters();p.Tolerance=.035;p.MaximumEdgeLength=step;p.RefineGrid=True;p.SimplePlanes=True
    m=G.Mesh()
    if isinstance(g,G.Mesh):m.Append(g)
    else:
        for q in G.Mesh.CreateFromBrep(g,p):m.Append(q)
    return m
def loft(sections):
    b=G.Brep.CreateFromLoft(sections,G.Point3d.Unset,G.Point3d.Unset,G.LoftType.Normal,False)
    assert b and len(b)==1
    b=b[0].CapPlanarHoles(.005);assert b and b.IsValid and b.IsSolid
    if b.SolidOrientation==G.BrepSolidOrientation.Inward:b.Flip()
    return b

def prepare():
    assert TAG not in sc.sticky,'Reuse the prepared state'
    assert sc.doc.Path.replace('\\','/').replace('//','/').lower()=='d:/prism route/map/map_current.3dm'
    source=sc.sticky['outer_roads_1022']['roads'][ROAD]['samples']
    survey=sc.sticky['west_road_clearance_1022']['terrain']
    with io.open(ROOT+'/assets/world/current_map_validation/metadata.json','r',encoding='utf-8')as f:meta=json.load(f)
    roles={r['id']:r for r in meta['object_records']}
    terrain=[row for row in survey if roles[row[0]]['kind']in ['Terrain','Sand']]
    sections=[];stations=[];distance=0.;last=None
    for a,b in source:
        p=a+(b-a)*.5
        if last is not None:distance+=last.DistanceTo(p)
        sections.append((G.Point3d(a),G.Point3d(b)));stations.append(distance);last=p
    c=G.Curve.CreateInterpolatedCurve([a+(b-a)*.5 for a,b in sections],3,G.CurveKnotStyle.Chord)
    d={'before':{str(o.Id):int(o.Geometry.DataCRC(0))for o in objects()},
       'attributes':{str(o.Id):o.Attributes.Duplicate()for o in objects()},
       'original_body':obj(BODY).Geometry.DuplicateBrep(),'sections':sections,'stations':stations,
       'route':c,'length':distance,'terrain':terrain,'piers':{},'pier_reports':{},'traffic':[],'roles':roles,
       'original_view':Rhino.DocObjects.ViewportInfo(sc.doc.Views.ActiveView.ActiveViewport)}
    for row in meta['object_records']:
        if row['id']==ROAD:continue
        if row['kind']!='Road'and not row['layer'].startswith('交通::隧道'):continue
        lo,hi=row['bounds']
        if hi[0]<220 or lo[0]>750 or hi[1]<90 or lo[1]>1330:continue
        d['traffic'].append((row,mesh(obj(row['id']).Geometry)if isinstance(obj(row['id']).Geometry,(G.Brep,G.Mesh))else None))
    sc.sticky[TAG]=d
    backup=Rhino.FileIO.File3dm();backup.Objects.Add(obj(BODY).Geometry,obj(BODY).Attributes)
    assert backup.Write(CACHE+'/west_supports_1022_before.3dm',8)
    return {'length_m':distance,'traffic_objects':len(d['traffic']),'piers':PIERS}

def frame(s):
    d=sc.sticky[TAG];s=max(0,min(d['length'],s))
    i=max(0,min(len(d['stations'])-2,bisect.bisect_right(d['stations'],s)-1))
    t=(s-d['stations'][i])/(d['stations'][i+1]-d['stations'][i])
    a0,b0=d['sections'][i];a1,b1=d['sections'][i+1]
    a=a0+(a1-a0)*t;b=b0+(b1-b0)*t
    p=a+(b-a)*.5;n=b-a;n.Z=0;width=n.Length;n=unit(n)
    tangent=unit(G.Vector3d(n.Y,-n.X,0))
    if G.Vector3d.Multiply(tangent,(a1+b1)*.5-(a0+b0)*.5)<0:tangent=-tangent
    return p,tangent,n,width*.5,(b.Z-a.Z)/width

def ground_at(point,upper):
    d=sc.sticky[TAG];hits=[]
    for key,name,m,b in d['terrain']:
        if point.X<b.Min.X or point.X>b.Max.X or point.Y<b.Min.Y or point.Y>b.Max.Y:continue
        start=G.Point3d(point.X,point.Y,upper)
        t=G.Intersect.Intersection.MeshRay(m,G.Ray3d(start,-G.Vector3d.ZAxis))
        if t>=0:hits.append((upper-t,key))
    return max(hits)if hits else (None,None)

def base_profile(s):
    p,a,n,w,roll=frame(s)
    # Grounded lower roadbed -> free beam -> grounded shoulder -> platform stitch.
    fill=(1-smooth((s-70)/120))if s<190 else (smooth((s-690)/140)if s<830 and s>690 else 0.)
    platform=smooth((s-795)/55)
    foot_extra=4.*max(fill,platform)
    central_depth=2.25
    contact=[]
    for side in [-1,1]:
        q=p+n*(side*(w+5));g,_=ground_at(q,p.Z+2)
        if g is None:g,_=ground_at(p,p.Z-.5)
        if g is None:g=p.Z-2
        contact.append(max(1.3,p.Z-g+.65))
    center_depth=central_depth*(1-fill)+(sum(contact)*.5)*fill
    left_depth=1.45*(1-fill)+contact[0]*fill
    right_depth=1.45*(1-fill)+contact[1]*fill
    # All shoulder tops stay beneath the unchanged asphalt.
    top=[(-w-1.5,-.20),(-w-1.0,-.15),(-w*.8,-.15),(-w*.45,-.15),(0,-.15),
         (w*.45,-.15),(w*.8,-.15),(w+1.,-.15),(w+1.5,-.20)]
    bottom=[(w+1.55+foot_extra*.35,-.48),
            (w+1.+foot_extra,-right_depth*.7),
            (w+.5+foot_extra,-right_depth),
            (w*.6,-center_depth),(0,-center_depth),(-w*.6,-center_depth),
            (-w-.5-foot_extra,-left_depth),
            (-w-1.-foot_extra,-left_depth*.7),(-w-1.55-foot_extra*.35,-.48)]
    pts=[G.Point3d(p.X+n.X*y,p.Y+n.Y*y,p.Z+roll*y+z)for y,z in top+bottom]
    curve=G.NurbsCurve.Create(True,3,pts);assert curve.IsValid and curve.IsClosed
    return curve

def build_body():
    d=sc.sticky[TAG];count=int(math.ceil(d['length']/5))
    sections=[base_profile(d['length']*i/count)for i in range(count+1)]
    d['body']=loft(sections)
    return {'closed':d['body'].IsSolid,'faces':d['body'].Faces.Count,'length_m':d['length']}

def pier_leg(s,side,compact=False):
    p,a,n,w,roll=frame(s);ground_point=p-a*2.4+n*(side*.65)
    g,key=ground_at(ground_point,p.Z-1)
    assert g is not None,'No foundation ground '+str(s)
    height=p.Z-g;sections=[]
    for i in range(13):
        t=i/12.;spread=smooth((t-.12)/.88)
        center=p-a*(2.4*(1-spread))+n*(side*(.65+5.6*spread))
        center.Z=g-.9+(height+.55)*t+roll*side*5.6*spread
        rx=1.65+.9*smooth((t-.68)/.32)
        ry=1.0+1.5*smooth((t-.65)/.35)
        plane=G.Plane(center,a,n)
        sections.append(G.Ellipse(plane,rx,ry).ToNurbsCurve())
    return loft(sections),{'station':s,'side':side,'ground_z':g,'ground_source':key,'road_z':p.Z,'height_m':height}

def build_pier(s):
    d=sc.sticky[TAG];p,a,n,w,roll=frame(s);g,key=ground_at(p-a*2.4,p.Z-1)
    assert g is not None
    if p.Z-g<7:
        sections=[]
        for i in range(13):
            t=i/12.;flare=smooth((t-.35)/.65)
            center=p-a*(2.4*(1-smooth(t)));center.Z=g-.9+(p.Z-g+.55)*t
            sections.append(G.Ellipse(G.Plane(center,a,n),1.8+1.1*flare,1.1+2.4*flare).ToNurbsCurve())
        result=loft(sections);reports=[{'station':s,'ground_z':g,'road_z':p.Z,'height_m':p.Z-g,'ground_source':key,'type':'compact flared pier'}]
    else:
        left,lr=pier_leg(s,-1);right,rr=pier_leg(s,1)
        joined=G.Brep.CreateBooleanUnion([left,right],.005)
        assert joined and len(joined)==1 and joined[0].IsValid and joined[0].IsSolid,'Pier union failed '+str(s)
        result=joined[0];reports=[lr,rr]
    d['piers'][s]=result;d['pier_reports'][s]=reports
    return {'station':s,'height_m':p.Z-g,'faces':result.Faces.Count,'closed':result.IsSolid}

def publish_body_and_piers(stations):
    d=sc.sticky[TAG];d.setdefault('ids',{})
    undo=sc.doc.BeginUndoRecord('西侧岸路_路基高架与平台承托')
    try:
        assert sc.doc.Objects.Replace(System.Guid(BODY),d['body'])
        a=d['attributes'][BODY].Duplicate();a.Name='西侧岸路_渐起路基_连续高架梁腹与平台搭接'
        a.SetUserString('support_recipe',TAG)
        assert sc.doc.Objects.ModifyAttributes(System.Guid(BODY),a,True)
        for s in stations:
            key=str(s);g=d['piers'][s]
            if key in d['ids']:assert sc.doc.Objects.Replace(System.Guid(d['ids'][key]),g)
            else:
                a=d['attributes'][BODY].Duplicate();a.ObjectId=System.Guid.Empty
                a.Name='西侧岸路_流线支墩_%04d米'%round(s)
                a.SetUserString('support_recipe',TAG);a.SetUserString('source_road',ROAD);a.SetUserString('support_station_m',str(s))
                oid=sc.doc.Objects.AddBrep(g,a);assert oid!=System.Guid.Empty;d['ids'][key]=str(oid)
    finally:sc.doc.EndUndoRecord(undo)
    sc.doc.Views.Redraw()
    return {'body':BODY,'piers':d['ids']}

def capture(s,name):
    d=sc.sticky[TAG];p,a,n,w,roll=frame(s);g,_=ground_at(p-a*2.4,p.Z-1)
    view=sc.doc.Views.ActiveView;vp=view.ActiveViewport
    eye=p+n*62-a*38;eye.Z=(g if g is not None else p.Z-10)+7
    target=p;target.Z=(p.Z+(g if g is not None else p.Z-10))*.5
    vp.SetCameraLocation(eye,False);vp.SetCameraTarget(target,False)
    vp.SetCameraDirection(target-eye,False);vp.Camera35mmLensLength=36
    sc.doc.Objects.UnselectAll();sc.doc.Views.Redraw()
    capture=Rhino.Display.ViewCapture();capture.Width=1440;capture.Height=900
    capture.DrawGrid=False;capture.DrawAxes=False;capture.DrawGridAxes=False
    image=capture.CaptureToBitmap(view);assert image
    path=CACHE+'/'+name+'.png';image.Save(path,System.Drawing.Imaging.ImageFormat.Png);image.Dispose()
    return path

def assemble():
    d=sc.sticky[TAG];assert set(d['piers'])==set(PIERS)
    result=G.Brep.CreateBooleanUnion([d['body']]+[d['piers'][s]for s in PIERS],.01)
    assert result and len(result)==1,'Supports did not form one continuous body'
    b=result[0];assert b.IsValid and b.IsSolid
    if b.SolidOrientation==G.BrepSolidOrientation.Inward:b.Flip()
    d['assembly']=b
    return {'connected_bodies':len(result),'closed':b.IsSolid,'faces':b.Faces.Count,'piers':len(PIERS)}

def verify():
    d=sc.sticky[TAG];m=mesh(d['assembly'],2.5);bad=[];contacts=[];count=0
    for i in range(267):
        s=d['length']*(i+.37)/267;p,a,n,w,roll=frame(s)
        for j in range(9):
            y=w*(-.98+1.96*j/8);q=p+n*y;q.Z+=roll*y
            t=G.Intersect.Intersection.MeshRay(m,G.Ray3d(q+G.Vector3d.ZAxis*.025,G.Vector3d.ZAxis))
            if t>=0:bad.append({'s':s,'cross':y,'type':'above asphalt'})
            count+=1
    for s in PIERS:
        p,a,n,w,roll=frame(s);ground,_=ground_at(p-a*2.4,p.Z-1)
        foot=p-a*2.4;foot.Z=ground+.02
        assert d['piers'][s].IsPointInside(foot,.02,False),'Pier foot not embedded '+str(s)
        contacts.append({'station_m':s,'ground_z':ground,'road_z':p.Z,'height_m':p.Z-ground})
    # Existing traffic/tunnel envelopes may meet the buried shoulder, but the
    # new structure must never occupy any original road's driving headroom.
    road_block=[]
    for row,rm in d['traffic']:
        if row['kind']!='Road' or rm is None:continue
        normals=rm.FaceNormals;normals.ComputeFaceNormals()
        for index in range(0,rm.Faces.Count,max(1,rm.Faces.Count//250)):
            face=rm.Faces[index];a=G.Point3d(rm.Vertices[face.A]);b=G.Point3d(rm.Vertices[face.B]);c=G.Point3d(rm.Vertices[face.C])
            if normals[index].Z<.72:continue
            q=G.Point3d((a.X+b.X+c.X)/3,(a.Y+b.Y+c.Y)/3,(a.Z+b.Z+c.Z)/3)
            for h in [.25,1.,3.,5.]:
                p=q+G.Vector3d.ZAxis*h
                if d['assembly'].IsPointInside(p,.01,False):road_block.append({'id':row['id'],'height_above_road':h,'point':xyz(q)})
    report={'road_samples':count,'road_obstructions':bad,'other_road_headroom_obstructions':road_block,'piers':contacts,
            'closed':d['assembly'].IsSolid,'valid':d['assembly'].IsValid,'single_connected_nurbs_body':True,'faces':d['assembly'].Faces.Count}
    assert not bad and not road_block,'Structure occupies traffic clearance'
    d['verification']=report;write('west_supports_1022_verification.json',report)
    return report

def publish_final():
    d=sc.sticky[TAG];assert d.get('verification')
    undo=sc.doc.BeginUndoRecord('完成西侧岸路连续路基高架')
    try:
        assert sc.doc.Objects.Replace(System.Guid(BODY),d['assembly'])
        a=d['attributes'][BODY].Duplicate();a.Name='西侧岸路_连续路基_11墩高架与平台搭接_NURBS'
        a.SetUserString('support_recipe',TAG);a.SetUserString('pier_count','11')
        assert sc.doc.Objects.ModifyAttributes(System.Guid(BODY),a,True)
        # Remove only our published prototype after it joins the one final Brep.
        for key in d.get('ids',{}).values():assert sc.doc.Objects.Delete(System.Guid(key),True)
        d['ids']={}
    finally:sc.doc.EndUndoRecord(undo)
    after={str(o.Id):int(o.Geometry.DataCRC(0))for o in objects()}
    assert set(after)==set(d['before'])
    changed=[k for k in after if after[k]!=d['before'][k]]
    assert changed==[BODY]
    sc.doc.Objects.UnselectAll();obj(BODY).Select(True);sc.doc.Views.Redraw()
    report={'changed_existing_ids':changed,'added_objects':0,'unchanged_objects':len(after)-1,'cad_objects':len(after),'verification':d['verification']}
    write('west_supports_1022_publication.json',report)
    return report

def save():
    d=sc.sticky[TAG];assert d.get('verification')and obj(BODY).Geometry.IsSolid
    options=Rhino.FileIO.FileWriteOptions();options.SuppressDialogBoxes=True
    assert sc.doc.WriteFile(sc.doc.Path,options);sc.doc.Modified=False
    return {'saved':True,'path':sc.doc.Path}

def export_patch():
    d=sc.sticky[TAG];assert not sc.doc.Modified
    saved=Rhino.FileIO.File3dm.Read(sc.doc.Path)
    assert saved.Objects.FindId(System.Guid(BODY)).Geometry.DataCRC(0)==obj(BODY).Geometry.DataCRC(0)
    assert len([x for x in saved.Objects])==len(d['before'])
    p=G.MeshingParameters();p.SimplePlanes=True;p.RefineGrid=True;p.JaggedSeams=False
    p.GridMinCount=4;p.GridMaxCount=40;p.MaximumEdgeLength=8;p.MinimumEdgeLength=.08;p.Tolerance=.04;p.RelativeTolerance=0;p.RefineAngle=.10
    m=G.Mesh()
    for q in G.Mesh.CreateFromBrep(obj(BODY).Geometry,p):m.Append(q)
    m.Faces.ConvertQuadsToTriangles();m.Normals.ComputeNormals();m.Compact();assert m.IsValid
    stream=System.IO.FileStream(CACHE+'/west_supports_1022_patch.bin',System.IO.FileMode.Create)
    writer=System.IO.BinaryWriter(stream)
    try:
        for array in [m.Vertices.ToFloatArray(),m.Faces.ToIntArray(True)]:
            raw=System.Array.CreateInstance(System.Byte,array.Length*4)
            System.Buffer.BlockCopy(array,0,raw,0,raw.Length);writer.Write(raw)
    finally:writer.Close()
    b=m.GetBoundingBox(True)
    row={'id':BODY,'name':obj(BODY).Name,'layer':sc.doc.Layers[obj(BODY).Attributes.LayerIndex].FullPath,
         'kind':'Structure','offset':0,'vertex_count':m.Vertices.Count,'index_count':m.Faces.Count*3,
         'bounds':[xyz(b.Min),xyz(b.Max)],'collision':True}
    report={'objects':[row],'cad_object_count':len(d['before']),'saved_and_readback_verified':True,'source':sc.doc.Path}
    write('west_supports_1022_patch.json',report)
    return {'closed_nurbs':True,'faces':obj(BODY).Geometry.Faces.Count,'export_triangles':m.Faces.Count,'saved_and_readback_verified':True}
