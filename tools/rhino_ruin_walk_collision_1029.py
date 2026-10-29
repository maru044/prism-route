# -*- coding: utf-8 -*-
"""Add parameter-derived hidden collision meshes without editing authored architecture."""
from __future__ import unicode_literals,division
import Rhino, scriptcontext as sc, System, System.Drawing as Drawing, io,json,os
G=Rhino.Geometry
ROOT='D:/Prism Route/prism-route'
CAD='D:/Prism Route/plans/architecture_concepts_1028/rhino_model_1029'
LAYER=u'建筑::初始三角遗迹::09_平滑碰撞'
TAG='PR_RuinWalkCollision_1029'

def read(path):
    with io.open(path,'r',encoding='utf-8-sig') as f:return json.load(f)
def write(path,value):
    with io.open(path,'w',encoding='utf-8') as f:f.write(json.dumps(value,ensure_ascii=False,indent=2))
def all_objects():
    settings=Rhino.DocObjects.ObjectEnumeratorSettings()
    settings.NormalObjects=True;settings.LockedObjects=True;settings.HiddenObjects=True
    return sc.doc.Objects.GetObjectList(settings)
def fingerprint():
    options=Rhino.FileIO.SerializationOptions()
    return dict((str(o.Id),(int(o.Geometry.DataCRC(0)),o.Attributes.ToJSON(options))) for o in all_objects())
def prepare():
    recipe=read(CAD+'/walk_collision_recipe.json');before=fingerprint();stage=[]
    assert sc.doc.Path.lower().replace('\\','/').endswith('/map/map_current.3dm')
    assert not os.path.isfile(CAD+'/walk_collision_state.json'),'Already created; use export_saved() to re-export'
    for row in recipe['replaced_objects']:
        obj=sc.doc.Objects.FindId(System.Guid(row['id']));assert obj is not None
        bounds=obj.Geometry.GetBoundingBox(True);expected=recipe['source_bounds'][row['id']]
        assert max(abs(bounds.Min[i]-expected[0][i]) for i in range(3))<.002,'Source stair changed'
        assert max(abs(bounds.Max[i]-expected[1][i]) for i in range(3))<.002,'Source stair changed'
    for model in recipe['models']:
        mesh=G.Mesh()
        for p in model['vertices']:mesh.Vertices.Add(float(p[0]),float(p[1]),float(p[2]))
        for t in model['triangles']:mesh.Faces.AddFace(*[int(v) for v in t])
        mesh.Normals.ComputeNormals();mesh.Compact()
        assert mesh.IsValid and mesh.IsClosed,'Collision mesh must be closed: '+model['name']
        stage.append((mesh,model))
    sc.sticky[TAG]={'recipe':recipe,'before':before,'stage':stage}
    return {'ready':len(stage),'old_objects':len(before),'triangles':sum(x[0].Faces.Count for x in stage)}
def apply():
    task=sc.sticky[TAG];assert fingerprint()==task['before']
    layer=sc.doc.Layers.FindByFullPath(LAYER,-1)
    if layer<0:layer=sc.doc.Layers.AddPath(LAYER,Drawing.Color.FromArgb(55,220,135))
    assert layer>=0
    record=sc.doc.BeginUndoRecord('Project PR smooth collision surfaces');rows=[]
    try:
        for mesh,model in task['stage']:
            a=Rhino.DocObjects.ObjectAttributes();a.Name=model['name'];a.LayerIndex=layer
            a.ObjectColor=Drawing.Color.FromArgb(55,220,135);a.ColorSource=Rhino.DocObjects.ObjectColorSource.ColorFromObject
            a.SetUserString('pr_collision_only','true');a.SetUserString('pr_walk_role',model['role'])
            a.SetUserString('pr_walk_recipe',CAD+'/walk_collision_recipe.json')
            a.SetUserString('description','Smooth actor-only walk collision; visible stair geometry remains separate')
            ident=sc.doc.Objects.AddMesh(mesh,a);assert ident!=System.Guid.Empty
            if 'add_object_metadata' in globals():add_object_metadata(ident,model['name'],'Hidden smooth stair walking collision, generated from saved stair parameters')
            rows.append({'id':str(ident),'name':model['name'],'role':model['role']})
        item=sc.doc.Layers[layer];item.IsVisible=False;item.IsLocked=True
        item.CommitChanges()
        assert not sc.doc.Layers[layer].IsVisible and sc.doc.Layers[layer].IsLocked
    finally:sc.doc.EndUndoRecord(record)
    after=fingerprint();assert all(after.get(k)==v for k,v in task['before'].items())
    state={'layer':LAYER,'objects':rows,'original_count':len(task['before']),'original_objects_preserved':True,'original_fingerprints':task['before']}
    write(CAD+'/walk_collision_state.json',state);sc.doc.Views.Redraw()
    return {'added':len(rows),'original_objects_preserved':True,'layer_hidden':not sc.doc.Layers[layer].IsVisible}
def export_saved():
    state=read(CAD+'/walk_collision_state.json');before=fingerprint();rows=[]
    stream=System.IO.FileStream(ROOT+'/.current_map_build/ruin_walk_collision_cad.bin',System.IO.FileMode.Create)
    writer=System.IO.BinaryWriter(stream)
    try:
        for row in state['objects']:
            obj=sc.doc.Objects.FindId(System.Guid(row['id']));mesh=obj.Geometry.DuplicateMesh()
            assert mesh.IsClosed and mesh.IsValid
            offset=int(stream.Position)
            for array in [mesh.Vertices.ToFloatArray(),mesh.Faces.ToIntArray(True)]:
                raw=System.Array.CreateInstance(System.Byte,array.Length*4);System.Buffer.BlockCopy(array,0,raw,0,raw.Length);writer.Write(raw)
            rows.append(dict(row,kind='WalkCollision',offset=offset,vertex_count=mesh.Vertices.Count,index_count=mesh.Faces.Count*3,geometry_crc=int(obj.Geometry.DataCRC(0))))
    finally:writer.Close()
    after=fingerprint();assert before==after
    assert all(after.get(k)==tuple(v) for k,v in state['original_fingerprints'].items())
    result={'source':sc.doc.Path,'native_center':[1450,1150,0],'layer':state['layer'],'original_objects_preserved':True,'objects':rows}
    write(ROOT+'/.current_map_build/ruin_walk_collision_cad.json',result)
    return {'objects':len(rows),'triangles':sum(r['index_count']//3 for r in rows),'original_preserved':True}
def save():
    state=read(CAD+'/walk_collision_state.json');before=fingerprint()
    options=Rhino.FileIO.FileWriteOptions();options.SuppressDialogBoxes=True;options.SuppressAllInput=True;options.UpdateDocumentPath=True
    assert sc.doc.WriteFile('D:/Prism Route/map/map_current.3dm',options)
    # The inspection copy exposes the collision layer for comparison, while the
    # actual working model keeps it hidden and locked.
    ids=[System.Guid(r['id']) for r in read(CAD+'/build_state.json')['objects']+state['objects']]
    ids += [System.Guid(x) for x in ['577d868b-7597-4058-83f8-4b630606b305','0e79433e-80e9-48f1-ab77-3786fdc3819f','9713e301-b5a7-4acb-821d-d98484bc52de']]
    model=Rhino.FileIO.File3dm();model.Settings.ModelUnitSystem=sc.doc.ModelUnitSystem
    for layer in sc.doc.Layers:
        if not layer.IsDeleted:model.AllLayers.Add(layer)
    for material in sc.doc.Materials:model.AllMaterials.Add(material)
    for ident in ids:
        obj=sc.doc.Objects.FindId(ident);assert obj is not None;model.Objects.Add(obj.Geometry,obj.Attributes)
    path=CAD+'/initial_triangle_ruin_smooth_collision_review.3dm'
    assert model.Write(path,8)
    disk=Rhino.FileIO.File3dm.Read('D:/Prism Route/map/map_current.3dm');disk_ids=dict((str(o.Id),int(o.Geometry.DataCRC(0))) for o in disk.Objects)
    assert all(disk_ids[k]==v[0] for k,v in before.items())
    assert before==fingerprint()
    original=Rhino.FileIO.File3dm.Read('D:/Prism Route/map/backups/map_before_ruin_walk_collision_1029.3dm')
    serialized=Rhino.FileIO.SerializationOptions()
    by_id=dict((str(o.Id),o) for o in disk.Objects)
    assert disk.Objects.Count==original.Objects.Count+6,'Unexpected duplicate collision helpers'
    original_layers=dict((layer.Index,str(layer.Id)) for layer in original.AllLayers)
    saved_layers=dict((layer.Index,str(layer.Id)) for layer in disk.AllLayers)
    for obj in original.Objects:
        saved=by_id[str(obj.Id)]
        assert obj.Geometry.DataCRC(0)==saved.Geometry.DataCRC(0)
        # Rhino reindexes later layers when saving a newly inserted layer. Verify
        # semantic layer GUID and normalize that serialized index for comparison.
        assert original_layers[obj.Attributes.LayerIndex]==saved_layers[saved.Attributes.LayerIndex]
        if obj.Attributes.ToJSON(serialized)!=saved.Attributes.ToJSON(serialized):
            assert obj.Attributes.LayerIndex!=saved.Attributes.LayerIndex
            for field in ['Name','Mode','MaterialIndex','MaterialSource','ColorSource','ObjectColor','Visible','ObjectId','WireDensity','PlotColor','PlotWeight','LinetypeIndex','ViewportId','Space','LinetypeSource','PlotColorSource','PlotWeightSource']:
                assert getattr(obj.Attributes,field)==getattr(saved.Attributes,field),field
            old_users=obj.Attributes.GetUserStrings();new_users=saved.Attributes.GetUserStrings()
            assert dict((k,old_users[k]) for k in old_users.AllKeys)==dict((k,new_users[k]) for k in new_users.AllKeys)
            assert list(obj.Attributes.GetGroupList() or [])==list(saved.Attributes.GetGroupList() or [])
    report={'main':sc.doc.Path,'review':path,'saved_objects':len(disk_ids),'original_preserved':True,'collision_objects':6,'layer':LAYER,'hidden':True,'locked':True}
    write(CAD+'/walk_collision_saved.json',report)
    return report
