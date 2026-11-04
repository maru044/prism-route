# -*- coding: utf-8 -*-
from __future__ import unicode_literals, division
import Rhino, scriptcontext as sc, System, json, io, os
G=Rhino.Geometry
ROOT='D:/Prism Route/prism-route/docs/terrain_seams_1102'
TAG='terrain_seams_1102'

def fingerprint():
    options=Rhino.FileIO.SerializationOptions()
    return dict((str(o.Id),(int(o.Geometry.DataCRC(0)),o.Attributes.ToJSON(options))) for o in sc.doc.Objects)

def cage(points, thickness):
    n=len(points);m=len(points[0]);mesh=G.Mesh()
    for bottom in [False,True]:
        for row in points:
            for x,y,z in row:mesh.Vertices.Add(x,y,z-(thickness if bottom else 0.))
    count=n*m
    for i in range(n-1):
        for j in range(m-1):
            a=i*m+j;b=a+1;c=b+m;d=a+m
            mesh.Faces.AddFace(a,b,c,d);mesh.Faces.AddFace(d+count,c+count,b+count,a+count)
    ring=list(range(m))+[i*m+m-1 for i in range(1,n)]+[(n-1)*m+j for j in range(m-2,-1,-1)]+[i*m for i in range(n-2,0,-1)]
    for k,a in enumerate(ring):
        b=ring[(k+1)%len(ring)];mesh.Faces.AddFace(a,a+count,b+count,b)
    mesh.UnifyNormals();mesh.Normals.ComputeNormals();mesh.Compact()
    if mesh.SolidOrientation()<0:mesh.Flip(True,True,True)
    assert mesh.IsValid and mesh.IsClosed and mesh.IsManifold()
    result=G.SubD.CreateFromMesh(mesh,G.SubDCreationOptions.Smooth)
    assert result and result.IsValid and result.IsSolid
    return result

def prepare():
    assert sc.doc.Path.replace('\\','/').lower()=='d:/prism route/map/map_current.3dm'
    assert not any(o.Attributes.GetUserString('feature')==TAG for o in sc.doc.Objects),'Patches already exist'
    data=json.load(open(ROOT+'/control_nets.json'))
    state=dict(before=fingerprint(),parts={})
    for key,row in data.items():state['parts'][key]=cage(row['points'],row['thickness'])
    sc.sticky[TAG]=state
    return dict(prepared=dict((key,dict(faces=geo.Faces.Count,solid=bool(geo.IsSolid))) for key,geo in state['parts'].items()))

def commit():
    state=sc.sticky[TAG]
    assert fingerprint()==state['before'],'Model changed since preparing the local patches'
    parent_path='\u5730\u5f62::\u4e18\u9675\u4e0e\u5c40\u90e8\u8854\u63a5'
    layer_path=parent_path+'::\u5c40\u90e8\u4fee\u8865_1102'
    parent=sc.doc.Layers.FindByFullPath(parent_path,-1);assert parent>=0
    layer=sc.doc.Layers.FindByFullPath(layer_path,-1)
    if layer<0:
        item=Rhino.DocObjects.Layer();item.Name='\u5c40\u90e8\u4fee\u8865_1102';item.ParentLayerId=sc.doc.Layers[parent].Id
        item.Color=sc.doc.Layers[parent].Color
        item.RenderMaterialIndex=sc.doc.Layers[parent].RenderMaterialIndex
        layer=sc.doc.Layers.Add(item)
    template=sc.doc.Objects.FindId(System.Guid('9c6e4638-fa65-4d06-b84d-21feb0ab3b1b'))
    names=dict(east='East_arc_faired_ground_seam',west='West_missing_triangular_shore_apron')
    record=sc.doc.BeginUndoRecord('Two local SubD terrain seam patches')
    ids=[]
    try:
        for key,geo in state['parts'].items():
            attr=template.Attributes.Duplicate();attr.LayerIndex=layer;attr.Name=names[key]
            attr.Mode=Rhino.DocObjects.ObjectMode.Normal
            attr.SetUserString('feature',TAG);attr.SetUserString('patch_part',key)
            attr.SetUserString('description','Local smooth SubD ground repair; originals preserved')
            sid=sc.doc.Objects.AddSubD(geo,attr);assert sid!=System.Guid.Empty;ids.append(str(sid))
        after=fingerprint()
        assert set(after)-set(state['before'])==set(ids)
        assert all(after[sid]==value for sid,value in state['before'].items())
    except:
        for sid in ids:sc.doc.Objects.Delete(System.Guid(sid),True)
        raise
    finally:sc.doc.EndUndoRecord(record)
    state['ids']=ids
    sc.doc.Objects.UnselectAll();sc.doc.Views.Redraw()
    report=dict(object_ids=ids,layer=layer_path,objects_added=len(ids),unrelated_objects_unchanged=len(state['before']),
        geometry='Two closed native SubD local patches; existing terrain and roads untouched',parts={})
    for key,geo in state['parts'].items():
        b=geo.GetBoundingBox(True)
        report['parts'][key]=dict(faces=geo.Faces.Count,solid=bool(geo.IsSolid),bounds=[[b.Min.X,b.Min.Y,b.Min.Z],[b.Max.X,b.Max.Y,b.Max.Z]])
    with io.open(ROOT+'/model_report.json','w',encoding='utf-8') as f:f.write(json.dumps(report,ensure_ascii=False,indent=2))
    return report
