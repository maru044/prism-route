# -*- coding: utf-8 -*-
"""Rebuild the two selected retained shore-road ribbons in map_current."""
from __future__ import unicode_literals, division
import Rhino, scriptcontext as sc, System, math, io, json, os
G = Rhino.Geometry
ROOT = 'D:/Prism Route/prism-route'
CACHE = ROOT+'/.current_map_build'
TAG = 'outer_roads_1022'
ROAD_IDS = ['ee277b2d-e4eb-4d39-80e6-c5d8a5d87d70', '305479e8-59d9-4a89-bcf6-204f69186e51']

def obj(key): return sc.doc.Objects.FindId(System.Guid(key))
def xyz(p): return [p.X,p.Y,p.Z]
def write(name, value):
    with io.open(CACHE+'/'+name, 'w', encoding='utf-8') as f:
        f.write(json.dumps(value, ensure_ascii=False, indent=2))
def objects():
    e=Rhino.DocObjects.ObjectEnumeratorSettings()
    e.NormalObjects=True;e.HiddenObjects=True;e.LockedObjects=True
    return list(sc.doc.Objects.GetObjectList(e))
def remesh(b):
    p=G.MeshingParameters();p.Tolerance=.10;p.MaximumEdgeLength=10;p.RefineGrid=True;p.SimplePlanes=True
    m=G.Mesh()
    for part in G.Mesh.CreateFromBrep(b,p):m.Append(part)
    return m

def prepare():
    assert sc.doc.Path.replace('\\','/').replace('//','/').lower()=='d:/prism route/map/map_current.3dm'
    assert TAG not in sc.sticky, 'Already prepared; retain original sources'
    with io.open(CACHE+'/road_rebuild_1022_inspect.json','r',encoding='utf-8')as f:info=json.load(f)
    candidates=set(r['id'] for r in info['terrain_candidates'])
    d={'source':{key:obj(key).Geometry.DuplicateBrep()for key in ROAD_IDS},
       'attributes':{str(o.Id):o.Attributes.Duplicate()for o in objects()},
       'before':{str(o.Id):int(o.Geometry.DataCRC(0))for o in objects()},
       'meshes':{},'terrain_source':{},'roads':{},'terrain_copies':{},'info':info}
    sc.sticky[TAG]=d
    for key in candidates:
        g=obj(key).Geometry
        d['terrain_source'][key]=g.DuplicateBrep()
        d['meshes'][key]=remesh(g)
    return {'terrain_meshes':len(d['meshes'])}

def inspect():
    d=sc.sticky[TAG];report=[]
    for road in d['info']['roads']:
        conflicts={};low={};examples={};inside={}
        keys=set(r['id']for r in d['info']['terrain_candidates']if r['road']==road['id'])
        for index,row in enumerate(road['samples']):
            a=G.Point3d(*row['left']);b=G.Point3d(*row['right'])
            for j in range(5):
                p=a+(b-a)*(j/4)
                line=G.Line(G.Point3d(p.X,p.Y,120),G.Point3d(p.X,p.Y,-20))
                for key in keys:
                    hits=G.Intersect.Intersection.MeshLine(d['meshes'][key],line)
                    dz=[q.Z-p.Z for q in hits if -.5<q.Z-p.Z<7]
                    if dz:
                        conflicts[key]=conflicts.get(key,0)+1
                        examples.setdefault(key,[])
                        if len(examples[key])<3:examples[key].append({'index':index,'point':xyz(p),'dz':dz})
                    near=[q.Z-p.Z for q in hits if -1<q.Z-p.Z<.3]
                    if near:low[key]=low.get(key,0)+1
                    g=d['terrain_source'][key]
                    if g.IsSolid and g.IsPointInside(p+G.Vector3d.ZAxis*.5,.01,False):inside[key]=inside.get(key,0)+1
        report.append({'road':road['id'],'conflicts':conflicts,'near_surface':low,'inside_solid':inside,'examples':examples})
    write('road_rebuild_1022_conflicts.json',report)
    return report

def loft(sections, closed=True):
    result=G.Brep.CreateFromLoft(sections,G.Point3d.Unset,G.Point3d.Unset,G.LoftType.Normal,False)
    assert result and len(result)==1
    b=result[0].CapPlanarHoles(.005)if closed else result[0]
    assert b and b.IsValid and (b.IsSolid or not closed)
    if b.IsSolid and b.SolidOrientation==G.BrepSolidOrientation.Inward:b.Flip()
    return b

def build():
    d=sc.sticky[TAG];report=[]
    for key in ROAD_IDS:
        samples=[]
        for face in sorted(d['source'][key].Faces,key=lambda f:f.Domain(1).T0):
            c=face.IsoCurve(1,face.Domain(0).Mid);length=c.GetLength();count=int(math.ceil(length/5))
            for i in range(count+1):
                if i==0 and samples:continue
                if i==count:t=c.Domain.T1
                else:ok,t=c.LengthParameter(length*i/count);assert ok
                a=face.PointAt(face.Domain(0).T0,t);b=face.PointAt(face.Domain(0).T1,t)
                samples.append((a,b))
        pavement=[];bed=[];clearance=[]
        for a,b in samples:
            p=a+(b-a)*.5;n=b-a;n.Z=0;width=n.Length;n.Unitize()
            roll=(b.Z-a.Z)/width
            def q(y,z):return G.Point3d(p.X+n.X*y,p.Y+n.Y*y,p.Z+roll*y+z)
            w=width*.5
            pavement.append(G.PolylineCurve([a,b,b-G.Vector3d.ZAxis*.46,a-G.Vector3d.ZAxis*.46,a]))
            yz=[(-w-1.5,-.13),(-w,-.08),(0,-.08),(w,-.08),(w+1.5,-.13),
                (w+1.5,-.42),(w+.7,-1.3),(-w-.7,-1.3),(-w-1.5,-.42),(-w-1.5,-.13)]
            bed.append(G.PolylineCurve([q(y,z)for y,z in yz]))
            yz=[(-w-1.35,-1.4),(w+1.35,-1.4),(w+1.35,6),(-w-1.35,6),(-w-1.35,-1.4)]
            clearance.append(G.PolylineCurve([q(y,z)for y,z in yz]))
        d['roads'][key]={'pavement':loft(pavement),'bed':loft(bed),'cutter':loft(clearance),'samples':samples}
        report.append({'road':key,'sections':len(samples),'pavement_faces':d['roads'][key]['pavement'].Faces.Count,
            'roadbed_faces':d['roads'][key]['bed'].Faces.Count,'closed':True})
    return report

def part_inside(part,cutter):
    m=remesh(part);inside=0.;outside=0.
    for face in m.Faces:
        ids=[face.A,face.B,face.C]+([face.D]if face.IsQuad else [])
        p=G.Point3d(sum(m.Vertices[i].X for i in ids)/len(ids),sum(m.Vertices[i].Y for i in ids)/len(ids),sum(m.Vertices[i].Z for i in ids)/len(ids))
        a=G.Point3d(m.Vertices[face.A]);b=G.Point3d(m.Vertices[face.B]);c=G.Point3d(m.Vertices[face.C])
        area=G.Vector3d.CrossProduct(b-a,c-a).Length
        if cutter.IsPointInside(p,.01,False):inside+=area
        else:outside+=area
    total=inside+outside
    assert total>0
    return inside/total

def cut_terrain(road_key,keys):
    d=sc.sticky[TAG];cutter=d['roads'][road_key]['cutter'];report=[]
    for key in keys:
        source=d['terrain_copies'].get(key,d['terrain_source'][key])
        if source.IsSolid:
            parts=G.Brep.CreateBooleanDifference(source,cutter,.01)
            assert parts and all(p.IsValid and p.IsSolid for p in parts),'Solid trim failed '+key
            result=G.Brep()
            for part in parts:result.Append(part)
            removed_ratio=None
        else:
            parts=source.Split(cutter,.01)
            assert parts and len(parts)>1,'Surface trim failed '+key
            kept=[];ratios=[]
            for part in parts:
                ratio=part_inside(part,cutter);ratios.append(ratio)
                assert ratio<.01 or ratio>.99,'Ambiguous cut component '+str((key,ratio))
                if ratio<.01:kept.append(part)
            assert kept and len(kept)<len(parts),'No terrain footprint removed '+key
            result=G.Brep()
            for part in kept:result.Append(part)
            removed_ratio=ratios
        assert result.IsValid
        old_area=G.AreaMassProperties.Compute(source).Area
        new_area=G.AreaMassProperties.Compute(result).Area
        assert new_area>old_area*.7,'Unexpectedly broad terrain edit '+key
        d['terrain_copies'][key]=result
        report.append({'id':key,'old_faces':source.Faces.Count,'new_faces':result.Faces.Count,'area_delta':new_area-old_area,'part_inside_ratios':removed_ratio})
    return report

def verify():
    d=sc.sticky[TAG]
    meshes={key:remesh(g)for key,g in d['terrain_copies'].items()}
    report=[]
    for key in ROAD_IDS:
        road=d['roads'][key];rm=remesh(road['pavement']);bad=[];worst=0.;cover=0
        keys=set(r['id']for r in d['info']['terrain_candidates']if r['road']==key)
        # Existing connecting asphalt is permitted to meet the rebuilt asphalt.
        keys-=set(['0808d32c-6ebc-4105-9258-a0f755ac2752','a4c9a543-2d8a-401c-bebe-b21f45031605'])
        for index,(a,b) in enumerate(road['samples']):
            for j in range(9):
                p=a+(b-a)*(.025+.95*j/8)
                if index in [0,len(road['samples'])-1]:
                    assert road['pavement'].ClosestPoint(p).DistanceTo(p)<.001,'End connection moved'
                    continue
                t=G.Intersect.Intersection.MeshRay(rm,G.Ray3d(p+G.Vector3d.ZAxis*.5,-G.Vector3d.ZAxis))
                assert t>=0,'Road coverage hole '+str((key,index,j,xyz(p)))
                worst=max(worst,abs(.5-t));cover+=1
                line=G.Line(p+G.Vector3d.ZAxis*.025,p+G.Vector3d.ZAxis*5)
                for terrain in keys:
                    hits=G.Intersect.Intersection.MeshLine(meshes.get(terrain,d['meshes'][terrain]),line)
                    if hits:bad.append({'station':index,'cross':j,'terrain':terrain,'point':xyz(p),'height_above':min(q.Z-p.Z for q in hits)})
        assert worst<.08,'Road deviated from original grade '+str(worst)
        report.append({'road':key,'samples':cover,'mesh_height_error_m':worst,'terrain_obstructions':len(bad),'examples':bad[:8]})
    d['verification']=report;write('road_rebuild_1022_verification.json',report)
    return report

def publish():
    d=sc.sticky[TAG];assert not d.get('published')
    assert d.get('verification') and all(r['terrain_obstructions']==0 for r in d['verification'])
    backup=Rhino.FileIO.File3dm()
    for key in set(ROAD_IDS)|set(d['terrain_copies']):
        o=obj(key);backup.Objects.Add(o.Geometry,o.Attributes)
    assert backup.Write(CACHE+'/outer_roads_1022_before.3dm',8)
    undo=sc.doc.BeginUndoRecord('重建东西两侧岸路及地形局部让位')
    rows=[]
    try:
        for key,g in d['terrain_copies'].items():
            assert sc.doc.Objects.Replace(System.Guid(key),g)
            assert sc.doc.Objects.ModifyAttributes(System.Guid(key),d['attributes'][key],True)
        for i,key in enumerate(ROAD_IDS):
            road=d['roads'][key]
            assert sc.doc.Objects.Replace(System.Guid(key),road['pavement'])
            a=d['attributes'][key].Duplicate();a.SetUserString('rebuild_recipe',TAG)
            a.Name=('东侧'if i==0 else'西侧')+'岸路_连续NURBS路面与闭合底板'
            assert sc.doc.Objects.ModifyAttributes(System.Guid(key),a,True)
            a=a.Duplicate();a.ObjectId=System.Guid.Empty
            a.Name=('东侧'if i==0 else'西侧')+'岸路_连续路肩与承托底面'
            a.MaterialIndex=77;a.MaterialSource=Rhino.DocObjects.ObjectMaterialSource.MaterialFromObject
            a.ObjectColor=sc.doc.Materials[77].DiffuseColor;a.ColorSource=Rhino.DocObjects.ObjectColorSource.ColorFromObject
            rid=sc.doc.Objects.AddBrep(road['bed'],a);assert rid!=System.Guid.Empty
            rows.append({'pavement':key,'roadbed':str(rid)})
        d['published']=rows
    finally:sc.doc.EndUndoRecord(undo)
    sc.doc.Objects.UnselectAll()
    for key in ROAD_IDS:obj(key).Select(True)
    sc.doc.Views.Redraw()
    changed=[str(o.Id)for o in objects()if str(o.Id)in d['before']and int(o.Geometry.DataCRC(0))!=d['before'][str(o.Id)]]
    assert set(changed)==set(ROAD_IDS)|set(d['terrain_copies'])
    write('road_rebuild_1022_publication.json',{'roads':rows,'terrain_modified':list(d['terrain_copies']),'changed_existing_objects':changed,'verification':d['verification']})
    return {'roads':rows,'modified_existing':len(changed),'unrelated_geometry_unchanged':True}

def save_and_export_patch():
    d=sc.sticky[TAG];assert d.get('published')
    options=Rhino.FileIO.FileWriteOptions();options.SuppressDialogBoxes=True
    assert sc.doc.WriteFile(sc.doc.Path,options);sc.doc.Modified=False
    saved=Rhino.FileIO.File3dm.Read(sc.doc.Path);assert saved
    keys=set(ROAD_IDS)|set(d['terrain_copies'])|set(r['roadbed']for r in d['published'])|set(d.get('junction_copies',{}))
    for key in keys:
        assert saved.Objects.FindId(System.Guid(key)).Geometry.DataCRC(0)==obj(key).Geometry.DataCRC(0)
    roles={};path=ROOT+'/tools/rhino_current_map_validation.py'
    exec(compile(open(path,'rb').read().decode('utf-8'),path,'exec'),roles)
    p=G.MeshingParameters();p.SimplePlanes=True;p.RefineGrid=True;p.JaggedSeams=False
    p.GridMinCount=4;p.GridMaxCount=40;p.MaximumEdgeLength=8;p.MinimumEdgeLength=.08;p.Tolerance=.04;p.RelativeTolerance=0;p.RefineAngle=.10
    stream=System.IO.FileStream(CACHE+'/outer_roads_1022_patch.bin',System.IO.FileMode.Create)
    writer=System.IO.BinaryWriter(stream);records=[]
    try:
        for key in sorted(keys):
            o=obj(key);m=G.Mesh()
            for q in G.Mesh.CreateFromBrep(o.Geometry,p):m.Append(q)
            m.Faces.ConvertQuadsToTriangles();m.Normals.ComputeNormals();m.Compact();assert m.IsValid
            offset=stream.Position
            for array in [m.Vertices.ToFloatArray(),m.Faces.ToIntArray(True)]:
                raw=System.Array.CreateInstance(System.Byte,array.Length*4)
                System.Buffer.BlockCopy(array,0,raw,0,raw.Length);writer.Write(raw)
            b=m.GetBoundingBox(True)
            records.append({'id':key,'name':o.Name or'','layer':sc.doc.Layers[o.Attributes.LayerIndex].FullPath,
                'kind':roles['kind'](o),'offset':int(offset),'vertex_count':m.Vertices.Count,'index_count':m.Faces.Count*3,
                'bounds':[xyz(b.Min),xyz(b.Max)],'collision':True})
    finally:writer.Close()
    report={'source':sc.doc.Path,'objects':records,'cad_object_count':len(objects()),'saved_and_readback_verified':True}
    write('outer_roads_1022_patch.json',report)
    return {'patch_objects':len(records),'cad_objects':len(objects()),'triangles':sum(r['index_count']//3 for r in records),'saved_and_readback_verified':True}

def blend_west_junction():
    d=sc.sticky[TAG];key='5182ccac-8e3b-4322-8826-976a9254271b'
    assert not d.get('junction_copies'),'Already blended'
    o=obj(key);source=o.Geometry.DuplicateBrep();a=o.Attributes.Duplicate()
    backup=Rhino.FileIO.File3dm();backup.Objects.Add(source,a)
    assert backup.Write(CACHE+'/outer_roads_1022_junction_before.3dm',8)
    f=source.Faces[0];c=f.IsoCurve(1,f.Domain(0).Mid);length=c.GetLength()
    road=remesh(d['roads'][ROAD_IDS[1]]['pavement'])
    offsets=[]
    for u in [f.Domain(0).T0,f.Domain(0).T1]:
        p=f.PointAt(u,f.Domain(1).T0)
        t=G.Intersect.Intersection.MeshRay(road,G.Ray3d(p+G.Vector3d.ZAxis*2,-G.Vector3d.ZAxis))
        assert t>=0 and abs(2-t)<1
        offsets.append(2-t)
    sections=[];count=int(math.ceil(length/2))
    for i in range(count+1):
        s=length*i/count
        if i==count:t=c.Domain.T1
        else:ok,t=c.LengthParameter(s);assert ok
        factor=1-max(0,min(1,s/45))**2*(3-2*max(0,min(1,s/45)))
        points=[]
        for j,u in enumerate([f.Domain(0).T0,f.Domain(0).T1]):
            p=f.PointAt(u,t);p.Z+=offsets[j]*factor;points.append(p)
        sections.append(G.LineCurve(points[0],points[1]))
    result=loft(sections,False);assert result.IsValid
    undo=sc.doc.BeginUndoRecord('顺接西侧岸路与现有双层桥引道的高差')
    try:
        assert sc.doc.Objects.Replace(o.Id,result)
        assert sc.doc.Objects.ModifyAttributes(o.Id,a,True)
    finally:sc.doc.EndUndoRecord(undo)
    d['junction_copies']={key:result}
    sc.doc.Views.Redraw()
    report={'id':key,'blend_length_m':45,'edge_correction_m':offsets,'far_bridge_endpoint_unchanged':True}
    write('outer_roads_1022_junction.json',report)
    return report
