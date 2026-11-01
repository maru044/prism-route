# -*- coding: utf-8 -*-
"""Small native bridge/road seam correction and direct component save."""
from __future__ import unicode_literals,division
import Rhino,scriptcontext as sc,System,os,shutil,math,json,io
G=Rhino.Geometry

def apply():
    ns=sc.sticky['oval_atrium_builder_ns_1031'];d=sc.sticky['oval_atrium_1031']
    assert not d.get('road_join_trimmed'),'Road join already trimmed'
    road=ns['obj']('road').Geometry
    deck=ns['named_part']('Level_road_connector');rails=ns['named_part']('Road_connector_guardrails');braces=ns['named_part']('Road_connector_brackets')
    trimmed=ns['difference'](deck.Geometry,road,'trim connector to road boundary')
    direction=ns['EXIT_DIR'];normal=G.Vector3d(-direction.Y,direction.X,0)
    start=G.Point3d(ns['CX'],ns['CY'],35.)+direction*65.7
    far=d['prepared']['exit_end']+direction*5.
    rail_mesh=G.Mesh();brace_mesh=G.Mesh();contacts=[]
    for side in [-1,1]:
        a=start+normal*side*3.8;b=far+normal*side*3.8
        line=G.Line(G.Point3d(a.X,a.Y,34.6),G.Point3d(b.X,b.Y,34.6))
        hit=G.Intersect.Intersection.CurveBrep(line.ToNurbsCurve(),road,.005)[2]
        assert hit and len(hit)>0,'Missing actual road-edge intersection'
        boundary=min(hit,key=lambda p:p.DistanceTo(line.From))
        end=G.Point3d(boundary.X,boundary.Y,35.)-direction*.22
        contacts.append(ns['xyz'](boundary))
        n=max(2,int(math.ceil(a.DistanceTo(end)/2.5)))
        for i in range(n):
            p=a+(end-a)*i/n;q=a+(end-a)*(i+1)/n
            aa=p+G.Vector3d(0,0,1.15);bb=q+G.Vector3d(0,0,1.15)
            rail_mesh.Append(ns['pipe_mesh'](aa,bb,.05));rail_mesh.Append(ns['pipe_mesh'](p,aa,.05))
        rail_mesh.Append(ns['pipe_mesh'](end,end+G.Vector3d(0,0,1.15),.05))
        beam_end=end-direction*.12
        brace_mesh.Append(ns['pipe_mesh'](a-G.Vector3d(0,0,.9),beam_end-G.Vector3d(0,0,.9),.19))
        anchor=a-direction*2.-G.Vector3d(0,0,8.)
        for t in [.35,.7,1.]:brace_mesh.Append(ns['pipe_mesh'](anchor,a+(beam_end-a)*t-G.Vector3d(0,0,.9),.2))
    replacements=[(deck,trimmed),(rails,ns['mesh_finish'](rail_mesh)),(braces,ns['mesh_finish'](brace_mesh))]
    record=sc.doc.BeginUndoRecord('Trim atrium bridge at actual road edge')
    try:
        for o,geometry in replacements:assert sc.doc.Objects.Replace(o.Id,geometry)
        d['road_join_trimmed']=True;d['road_join_patched_ids']=[str(o.Id) for o,g in replacements]
        d['parts']=[(o.Geometry.Duplicate(),o.Name[len('PR_Atrium_'):],o.Attributes.GetUserString('category'),'floor',{}) for o in ns['feature_objects']()]
    finally:sc.doc.EndUndoRecord(record);sc.doc.Views.Redraw()
    info={'patched_ids':d['road_join_patched_ids'],'road_edge_contacts':contacts,'railing_setback_m':.22,
        'change':'Deck trimmed by existing road solid; rail and brace ends follow curved road edge','full_validation_rerun':False}
    ns['write']('bridge_join_fix.json',info)
    return info

def save_component():
    ns=sc.sticky['oval_atrium_builder_ns_1031'];d=sc.sticky['oval_atrium_1031']
    path=ns['OUT']+'/oval_atrium.3dm';backup='D:/Prism Route/archive/oval_atrium_1031/oval_atrium_bridge_previous.3dm'
    if os.path.exists(path):shutil.copy2(path,backup)
    selected=[o.Id for o in sc.doc.Objects.GetSelectedObjects(False,False)]
    sc.doc.Objects.UnselectAll()
    try:
        for sid in d['objects']+[ns['SOURCE']['oval']]:sc.doc.Objects.Select(System.Guid(sid))
        options=Rhino.FileIO.FileWriteOptions();options.SuppressDialogBoxes=True;options.WriteSelectedObjectsOnly=True
        assert sc.doc.Write3dmFile(path,options)
    finally:
        sc.doc.Objects.UnselectAll()
        for sid in selected:sc.doc.Objects.Select(sid)
    assert Rhino.RhinoApp.RunScript('_-Save _Enter',False)
    return {'main_saved':not sc.doc.Modified,'component':path}
