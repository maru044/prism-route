# -*- coding: utf-8 -*-
"""Repair the existing foundation in place, preserving every object ID and tree."""
from __future__ import unicode_literals,division
import Rhino,scriptcontext as sc,System,os,io,json,time
G=Rhino.Geometry
ROOT='D:/Prism Route/prism-route'
OUT=ROOT+'/docs/east_earth_pavilion_1102'
FLOOR='fa626145-0826-47d6-a041-a3a953acb4ea'

def run():
    assert sc.doc.Path.replace('\\','/').lower()=='d:/prism route/map/map_current.3dm'
    ns=sc.sticky['east_earth_pavilion_ns_1102'];before=ns['fingerprint']()
    floor=sc.doc.Objects.FindId(System.Guid(FLOOR));original=floor.Geometry.DuplicateBrep()
    replacement=ns['slab'](ns['rect'](-108.08,108.08,-2.08,98.08,14.08),61.25,.77)
    assert replacement.IsValid and replacement.IsSolid
    old_mesh=ns['mesh_of'](original);new_mesh=ns['mesh_of'](replacement);samples=[]
    for u in range(-90,91,3):
        for v in [-1.8,-1.,-.2,.2]:
            p=ns['P'](float(u),v,100.)
            old=G.Intersect.Intersection.MeshRay(old_mesh,G.Ray3d(p,-G.Vector3d.ZAxis))
            new=G.Intersect.Intersection.MeshRay(new_mesh,G.Ray3d(p,-G.Vector3d.ZAxis))
            assert new>=0 and abs(100.-new-62.02)<.001
            samples.append(dict(point=[p.X,p.Y,62.02],before_height=None if old<0 else 100.-old,after_height=100.-new))
    folder='D:/Prism Route/archive/east_earth_pavilion_1102'
    backup=folder+'/map_before_entry_gap_'+time.strftime('%Y%m%d_%H%M%S')+'.3dm'
    opts=Rhino.FileIO.FileWriteOptions();opts.SuppressDialogBoxes=True
    assert not os.path.exists(backup) and sc.doc.Write3dmFile(backup,opts)
    record=sc.doc.BeginUndoRecord('Close pavilion entrance ground gap')
    try:
        assert sc.doc.Objects.Replace(System.Guid(FLOOR),replacement)
        after=ns['fingerprint']();assert set(before)==set(after)
        assert [sid for sid in before if before[sid]!=after[sid]]==[FLOOR]
    except:
        sc.doc.Objects.Replace(System.Guid(FLOOR),original);raise
    finally:sc.doc.EndUndoRecord(record)
    state=ns['state']()
    state['parts']=[(replacement if name=='Lower_continuous_floor' else geo,name,category,material)
        for geo,name,category,material in state['parts']]
    report=dict(changed_id=FLOOR,backup=backup,samples=samples,objects_added=0,unrelated_objects_unchanged=len(before)-1,
        old_front_boundary_v=0.,new_front_boundary_v=-2.08,finish_height=62.02)
    with io.open(OUT+'/entry_gap_fix.json','w',encoding='utf-8') as f:f.write(json.dumps(report,ensure_ascii=False,indent=2))
    reviewed=json.load(open(OUT+'/model_report.json','r'));reviewed['entry_gap_fix']='entry_gap_fix.json'
    with io.open(OUT+'/model_report.json','w',encoding='utf-8') as f:f.write(json.dumps(reviewed,ensure_ascii=False,indent=2))
    # Keep the source component and actual open master synchronized.
    sc.doc.Objects.UnselectAll()
    for sid in reviewed['object_ids']+['920c8a45-b23e-4260-9aab-86333f61b992']:sc.doc.Objects.Select(System.Guid(sid))
    component_opts=Rhino.FileIO.FileWriteOptions();component_opts.SuppressDialogBoxes=True;component_opts.WriteSelectedObjectsOnly=True
    assert sc.doc.Write3dmFile(OUT+'/earth_pavilion.3dm',component_opts)
    sc.doc.Objects.UnselectAll();sc.doc.Views.Redraw()
    assert Rhino.RhinoApp.RunScript('_-Save _Enter',False) and not sc.doc.Modified
    return dict(changed_id=FLOOR,samples=len(samples),before_missing=sum(r['before_height'] is None for r in samples),after_missing=0,
        objects_added=0,unrelated_objects_unchanged=len(before)-1,backup=backup)
