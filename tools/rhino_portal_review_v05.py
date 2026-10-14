# -*- coding: utf-8 -*-
"""Capture the unified portal model and archive editable native geometry."""
from __future__ import unicode_literals
import Rhino,scriptcontext as sc,System,os,json
from System.Drawing.Imaging import ImageFormat
G=Rhino.Geometry

def review(ns):
    data=sc.sticky[ns['TAG']];doc=sc.doc;view=doc.Views.ActiveView
    selected=[o.Id for o in doc.Objects.GetSelectedObjects(False,False)]
    doc.Objects.UnselectAll()
    try:
        ns['capture']()
        keep=set(r['id'] for r in data['state']['objects'] if r['group'] not in ['04_种植顶面','06_SubD编辑源_隐藏'])
        keep.update(r['id'] for r in data['site'].roads)
        hidden=[]
        for o in doc.Objects:
            l=doc.Layers[o.Attributes.LayerIndex];visible=l.IsVisible
            while visible and l.ParentLayerId!=System.Guid.Empty:
                l=doc.Layers.FindId(l.ParentLayerId)
                visible=l is not None and l.IsVisible
            if not o.IsDeleted and not o.IsHidden and visible and str(o.Id) not in keep:
                if doc.Objects.Hide(o.Id,True):hidden.append(o.Id)
        try:
            shots=[('04_T1_exposed_portal_oblique.png',G.Point3d(1140,770,64),G.Point3d(992,540,30)),
                   ('05_T2_exposed_portal_oblique.png',G.Point3d(1340,1050,75),G.Point3d(1540,818,27))]
            for name,camera,target in shots:
                view.ActiveViewport.SetCameraLocations(target,camera);doc.Views.Redraw()
                cap=Rhino.Display.ViewCapture();cap.Width=1920;cap.Height=1080
                cap.DrawGrid=False;cap.DrawAxes=False;cap.DrawGridAxes=False
                bmp=cap.CaptureToBitmap(view);bmp.Save(os.path.join(ns['OUT'],name),ImageFormat.Png);bmp.Dispose()
        finally:
            for oid in hidden:doc.Objects.Show(oid,True)
    finally:
        for oid in selected:doc.Objects.Select(oid,True)
        view.ActiveViewport.SetCameraLocations(G.Point3d(1060,880,25),G.Point3d(1250,3020,710));doc.Views.Redraw()
    ns['save_doc'](data['state']['draft_path'])
    print(json.dumps({'review_captures':5,'plant_overlays_hidden':all(ns['obj'](r['id']).IsHidden for r in data['state']['objects'] if r['group']=='04_种植顶面')}))

def archive(ns):
    data=sc.sticky[ns['TAG']];doc=sc.doc;native=Rhino.FileIO.File3dm()
    native.Settings.ModelUnitSystem=doc.ModelUnitSystem
    native.Settings.ModelAbsoluteTolerance=doc.ModelAbsoluteTolerance
    root=Rhino.DocObjects.Layer();root.Name=ns['LAYER'];root.Id=System.Guid.NewGuid();native.Layers.Add(root)
    layers={};materials={}
    for row in data['state']['objects']:
        o=ns['obj'](row['id']);a=o.Attributes.Duplicate();group=row['group']
        if group not in layers:
            source=doc.Layers[a.LayerIndex];l=Rhino.DocObjects.Layer();l.CopyAttributesFrom(source)
            l.Id=System.Guid.NewGuid();l.Name=group;l.ParentLayerId=root.Id
            l.IsVisible=group not in ['04_种植顶面','06_SubD编辑源_隐藏'];l.SetPersistentVisibility(l.IsVisible)
            layers[group]=len(list(native.Layers));native.Layers.Add(l)
        a.LayerIndex=layers[group]
        old_material=a.MaterialIndex
        if old_material>=0:
            if old_material not in materials:
                m=Rhino.DocObjects.Material();m.CopyFrom(doc.Materials[old_material])
                materials[old_material]=len(list(native.Materials));native.Materials.Add(m)
            a.MaterialIndex=materials[old_material]
        if group in ['04_种植顶面','06_SubD编辑源_隐藏']:a.Mode=Rhino.DocObjects.ObjectMode.Hidden
        if isinstance(o.Geometry,G.SubD):native.Objects.AddSubD(o.Geometry,a)
        else:native.Objects.AddBrep(o.Geometry,a)
    path=os.path.join(ns['OUT'],'exposed_portals_v05.3dm')
    if not native.Write(path,8):raise RuntimeError('Archive write failed')
    reopened=Rhino.FileIO.File3dm.Read(path)
    full=Rhino.FileIO.File3dm.Read(data['state']['draft_path'])
    failures=[];closed=0
    for row in data['state']['objects']:
        for label,model in [('local',reopened),('full',full)]:
            o=model.Objects.FindId(System.Guid(row['id']))
            if o is None or not o.Geometry.IsValid:failures.append(label+' invalid '+row['id'])
        if row['group'] not in ['04_种植顶面','06_SubD编辑源_隐藏']:
            if reopened.Objects.FindId(System.Guid(row['id'])).Geometry.IsSolid:closed+=1
            else:failures.append('Open production component '+row['id'])
    for oid,crc in data['state']['source_crc'].items():
        o=full.Objects.FindId(System.Guid(oid))
        if o is None or int(o.Geometry.DataCRC(0))!=crc:failures.append('Saved source changed '+oid)
    report={'failures':failures,'archive':path,'objects':len(list(reopened.Objects)),
            'closed_production_components':closed,'preserved_planting_overlays':6,'hidden_SubD_edit_sources':4,
            'full_draft':data['state']['draft_path'],'saved_sources_unchanged':not any('source' in f for f in failures)}
    ns['write']('archive_readback_report.json',report);print(json.dumps(report,ensure_ascii=False))
    if failures:raise RuntimeError('Readback checks failed')
