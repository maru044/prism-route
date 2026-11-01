# -*- coding: utf-8 -*-
"""Remove only obsolete tagged control objects; preserve the whole live scene."""
from __future__ import unicode_literals, division
import Rhino,scriptcontext as sc,System,json,io,os
ROOT='D:/Prism Route/prism-route'
TAG='island_saddle_1030'
OUT=ROOT+'/docs/island_saddle_1030'
ARCHIVE='D:/Prism Route/archive/modeling_cleanup_1031'

def active_objects():
    settings=Rhino.DocObjects.ObjectEnumeratorSettings()
    settings.NormalObjects=True;settings.HiddenObjects=True;settings.LockedObjects=True
    return [o for o in sc.doc.Objects.GetObjectList(settings) if not o.IsDeleted]

def cleanup():
    assert sc.doc.Path.replace('\\','/').lower()=='d:/prism route/map/map_current.3dm'
    with io.open(OUT+'/model_report.json','r',encoding='utf-8') as f:model=json.load(f)
    expected=set(model['object_ids']);objects=active_objects()
    ids=set(str(o.Id) for o in objects);assert expected<=ids
    obsolete=[o for o in objects if o.Attributes.GetUserString('feature')==TAG and str(o.Id) not in expected]
    allowed=set(['PR_Saddle_MasterContinuousSurface','PR_Saddle_ShellPlanBoundary',
                 'PR_Saddle_InnerRaisedEdge_Control','PR_Saddle_OuterCollapsedEdge_Control'])
    for obj in obsolete:
        assert obj.Name in allowed and obj.Attributes.GetUserString('category').startswith('00_')
    if not obsolete:return {'removed_objects':0,'already_clean':True}
    # Include hidden/locked objects in the fingerprint, unlike normal enumeration.
    opts=Rhino.FileIO.SerializationOptions()
    removed=set(str(o.Id) for o in obsolete)
    before=dict((str(o.Id),(int(o.Geometry.DataCRC(0)),o.Attributes.ToJSON(opts))) for o in objects if str(o.Id) not in removed)
    options=Rhino.FileIO.FileWriteOptions();options.SuppressDialogBoxes=True
    backup=ARCHIVE+'/map_before_cleanup.3dm'
    assert not os.path.exists(backup),'Cleanup backup already exists; inspect before repeating'
    assert sc.doc.Write3dmFile(backup,options)
    removed_records=[{'id':str(o.Id),'name':o.Name,'layer_index':o.Attributes.LayerIndex} for o in obsolete]
    layer_states={}
    try:
        for obj in obsolete:
            index=obj.Attributes.LayerIndex
            if index not in layer_states:
                layer=sc.doc.Layers[index];layer_states[index]=(layer.IsVisible,layer.IsLocked)
                layer.IsLocked=False;layer.CommitChanges()
            assert sc.doc.Objects.Purge(obj),'Could not purge stale control'
    finally:
        for index,(visible,locked) in layer_states.items():
            layer=sc.doc.Layers[index];layer.IsVisible=visible;layer.IsLocked=locked;layer.CommitChanges()
    after=active_objects()
    actual=dict((str(o.Id),(int(o.Geometry.DataCRC(0)),o.Attributes.ToJSON(opts))) for o in after)
    assert actual==before,'Cleanup changed a retained object'
    feature=[o for o in after if o.Attributes.GetUserString('feature')==TAG]
    assert set(str(o.Id) for o in feature)==expected
    obsolete_views=[]
    for i in range(sc.doc.NamedViews.Count-1,-1,-1):
        name=sc.doc.NamedViews[i].Name
        if name in ['IslandSaddle_marked_1030','IslandSaddle_compact_after_1030','IslandSaddle_transition_after_1030']:
            obsolete_views.append(name);assert sc.doc.NamedViews.Delete(i)
    sc.doc.NamedViews.Add('IslandSaddle_Current_1031',sc.doc.Views.ActiveView.ActiveViewport.Id)
    assert Rhino.RhinoApp.RunScript('_-Save _Enter',False) and not sc.doc.Modified
    readback=Rhino.FileIO.File3dm.Read(sc.doc.Path);assert readback
    saved=set(str(o.Id) for o in readback.Objects if o.Attributes.GetUserString('feature')==TAG)
    assert saved==expected,'Saved map contains obsolete or missing feature objects'
    result={'document':sc.doc.Path,'backup':backup,'removed_objects':len(removed_records),
        'removed_controls':removed_records,'removed_named_views':obsolete_views,
        'retained_feature_objects':len(feature),'retained_scene_objects':len(after),
        'retained_objects_geometry_and_attributes_unchanged':True,
        'saved_map_readback_verified':True,'current_named_view':'IslandSaddle_Current_1031'}
    with io.open(OUT+'/cleanup_report.json','w',encoding='utf-8') as f:
        f.write(json.dumps(result,ensure_ascii=False,indent=2,separators=(',',': ')))
    sc.sticky['saddle_cleanup_1031']=result
    return result
