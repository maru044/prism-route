# -*- coding: utf-8 -*-
"""Organize surface semantics in CAD without changing any geometry or object ID."""
from __future__ import unicode_literals
import Rhino, scriptcontext as sc, System, io, json, os

ROOT='D:/Prism Route/prism-route'
OUT=ROOT+'/assets/world/current_map_validation/review/cad_surface_layers.json'
TAG='map_1021_surface_layer_organization'
FAMILY='建筑::崖壁B'

def objects():
    options=Rhino.DocObjects.ObjectEnumeratorSettings()
    options.NormalObjects=True;options.HiddenObjects=True;options.LockedObjects=True
    return list(sc.doc.Objects.GetObjectList(options))

def prepare():
    assert sc.doc.Path.replace('\\','/').lower()=='d:/prism route/map/map_current.3dm'
    with io.open(ROOT+'/assets/world/current_map_validation/surface_roles.json','r',encoding='utf-8-sig')as f:policy=json.load(f)
    options=Rhino.FileIO.SerializationOptions()
    before={str(o.Id):{'geometry':int(o.Geometry.DataCRC(0)),'attributes':o.Attributes.ToJSON(options),'object':o.Attributes.Duplicate()}for o in objects()}
    moves=[]
    for o in objects():
        key=str(o.Id);path=sc.doc.Layers[o.Attributes.LayerIndex].FullPath
        target=None;rule=policy['objects'].get(key)
        if rule and rule['role']=='preserved_landscape':target='地形::保留原地形'
        elif path==FAMILY:
            if key=='0295f8be-063a-4f5d-90ff-5dabbf9fad42':target='交通::中层道路'
            elif key=='79d2ce03-2e53-4c69-9a13-a18da1838f89':target='环境::水面'
            elif rule and rule['kind']=='Terrain':target=FAMILY+'::种植承载面'
            else:target=FAMILY+'::建筑构件'
        if target and path!=target:moves.append({'id':key,'name':o.Name,'before':path,'after':target,'source_layer':o.Attributes.LayerIndex})
    assert len(moves)==27,'Unexpected affected object count: '+str(len(moves))
    sc.sticky[TAG]={'before':before,'moves':moves,'new_layers':[]}
    return moves

def find_layer(path):
    for layer in sc.doc.Layers:
        if not layer.IsDeleted and layer.FullPath==path:return layer
    return None

def ensure_layer(path,source):
    found=find_layer(path)
    if found:return found
    parent_path,name=path.rsplit('::',1);parent=find_layer(parent_path)
    assert parent,'Missing layer parent '+parent_path
    layer=Rhino.DocObjects.Layer();layer.Name=name;layer.ParentLayerId=parent.Id
    layer.Color=source.Color;layer.RenderMaterialIndex=source.RenderMaterialIndex
    layer.PlotColor=source.PlotColor;layer.PlotWeight=source.PlotWeight
    layer.IsVisible=True;layer.IsLocked=False
    index=sc.doc.Layers.Add(layer);assert index>=0
    sc.sticky[TAG]['new_layers'].append(path)
    return sc.doc.Layers[index]

def apply():
    d=sc.sticky[TAG];options=Rhino.FileIO.SerializationOptions()
    assert all(int(o.Geometry.DataCRC(0))==d['before'][str(o.Id)]['geometry']for o in objects())
    undo=sc.doc.BeginUndoRecord('1021 surface layer organization')
    try:
        for move in d['moves']:
            o=sc.doc.Objects.FindId(System.Guid(move['id']))
            layer=ensure_layer(move['after'],sc.doc.Layers[move['source_layer']])
            attrs=o.Attributes.Duplicate();attrs.LayerIndex=layer.Index
            assert sc.doc.Objects.ModifyAttributes(o,attrs,True)
        after={str(o.Id):o for o in objects()}
        assert set(after)==set(d['before'])
        expected={m['id']:find_layer(m['after']).Index for m in d['moves']}
        for key,o in after.items():
            assert int(o.Geometry.DataCRC(0))==d['before'][key]['geometry']
            if key not in expected:
                assert d['before'][key]['attributes']==o.Attributes.ToJSON(options)
                continue
            attrs=d['before'][key]['object'].Duplicate()
            if key in expected:attrs.LayerIndex=expected[key]
            assert attrs.ToJSON(options)==o.Attributes.Duplicate().ToJSON(options),'Unexpected attribute change '+key
    finally:sc.doc.EndUndoRecord(undo)
    sc.doc.Views.Redraw()
    return {'moved':len(d['moves']),'created_layers':d['new_layers'],'geometry_unchanged':True,'only_layer_indices_changed':True}

def save_and_check():
    d=sc.sticky[TAG]
    options=Rhino.FileIO.SerializationOptions()
    expected={m['id']:find_layer(m['after']).Index for m in d['moves']}
    for o in objects():
        key=str(o.Id);assert int(o.Geometry.DataCRC(0))==d['before'][key]['geometry']
        if key not in expected:
            assert d['before'][key]['attributes']==o.Attributes.ToJSON(options)
            continue
        attrs=d['before'][key]['object'].Duplicate()
        if key in expected:attrs.LayerIndex=expected[key]
        assert attrs.ToJSON(options)==o.Attributes.Duplicate().ToJSON(options),'Unexpected attribute change '+key
    assert Rhino.RhinoApp.RunScript('_-Save _Enter',False)
    saved=Rhino.FileIO.File3dm.Read(sc.doc.Path);assert saved
    rows={str(o.Id):o for o in saved.Objects}
    layers={l.Index:l for l in saved.Layers}
    layer_ids={l.Id:l for l in saved.Layers}
    assert set(rows)==set(d['before'])
    for key,o in rows.items():assert int(o.Geometry.DataCRC(0))==d['before'][key]['geometry']
    for move in d['moves']:
        o=rows[move['id']]
        layer=layers[o.Attributes.LayerIndex];parts=[layer.Name]
        while layer.ParentLayerId!=System.Guid.Empty:
            layer=layer_ids[layer.ParentLayerId];parts.insert(0,layer.Name)
        assert '::'.join(parts)==move['after']
    report={'source_document':sc.doc.Path,'objects':len(rows),'moved':len(d['moves']),'created_layers':d['new_layers'],'geometry_and_ids_unchanged':True,'only_layer_indices_changed':True,'saved_and_reread':True,'changes':d['moves']}
    with io.open(OUT,'w',encoding='utf-8')as f:f.write(json.dumps(report,ensure_ascii=False,indent=2))
    return report
