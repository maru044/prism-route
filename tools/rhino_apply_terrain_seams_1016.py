# -*- coding: utf-8 -*-
"""Apply precomputed local seam fairing, one preserved solid per call."""
from __future__ import division, unicode_literals
import Rhino, scriptcontext as sc, System, json, io, time
G=Rhino.Geometry
OUT='D:/Prism Route/prism-route/docs/concepts/terrain_seams_1016_v01'
TAG='prism_terrain_seams_1016_v01'

def build(index):
    start=time.time()
    with io.open(OUT+'/repaired_controls.json','r',encoding='utf-8')as h:row=json.load(h)[index]
    source=sc.doc.Objects.FindId(System.Guid(row['id']))
    if source is None:raise RuntimeError('Missing original')
    top=source.Geometry.Faces[0].DuplicateFace(False)
    surf=top.Faces[0].UnderlyingSurface().ToNurbsSurface()
    for i in range(row['nu']):
        for j in range(row['nv']):
            cp=surf.Points.GetControlPoint(i,j);p=cp.Location
            surf.Points.SetPoint(i,j,G.Point3d(p.X,p.Y,row['z'][i*row['nv']+j]),cp.Weight)
    si=top.AddSurface(surf)
    if not top.Faces[0].ChangeSurface(si):raise RuntimeError('Surface replacement failed')
    top.Faces[0].RebuildEdges(.001,True,True);top.Compact()
    if not top.IsValid:raise RuntimeError('Updated top invalid')
    print('Top rebuilt',index,time.time()-start)
    # Reuse only the verified closed-ground builder, never its old publish().
    ns={'__file__':'D:/Prism Route/prism-route/tools/rhino_landscape_1016_completion_v03.py'}
    with io.open(ns['__file__'],'r',encoding='utf-8')as h:exec(compile(h.read(),ns['__file__'],'exec'),ns)
    solid=ns['make_solid'](top)
    if not solid.IsValid or not solid.IsSolid:raise RuntimeError('Invalid ground solid')
    sc.sticky[TAG+'_built_'+str(index)]=(source.Id,solid)
    print(json.dumps({'index':index,'valid':solid.IsValid,'solid':solid.IsSolid,'outward':str(solid.SolidOrientation),'seconds':time.time()-start}))

def publish(index):
    sid,solid=sc.sticky[TAG+'_built_'+str(index)]
    source=sc.doc.Objects.FindId(sid)
    if not source or source.IsHidden:raise RuntimeError('Original already hidden; do not republish')
    layer_name='1016_地形接缝顺接_v01'
    li=sc.doc.Layers.FindByFullPath(layer_name,-1)
    if li<0:
        layer=Rhino.DocObjects.Layer();layer.Name=layer_name
        layer.Color=System.Drawing.Color.FromArgb(239,234,223);li=sc.doc.Layers.Add(layer)
    attrs=source.Attributes.Duplicate();attrs.LayerIndex=li;attrs.Name=source.Attributes.Name+'_接缝顺接'
    attrs.RemoveDisplayModeOverride();attrs.SetUserString('recipe',TAG);attrs.SetUserString('source_object',str(sid))
    mp=G.MeshingParameters();mp.MaximumEdgeLength=3;mp.Tolerance=.008;mp.RefineGrid=True;mp.JaggedSeams=False
    attrs.CustomMeshingParameters=mp;attrs.WireDensity=-1
    undo=sc.doc.BeginUndoRecord('1016 地形共边顺接 '+str(index))
    try:
        oid=sc.doc.Objects.AddBrep(solid,attrs)
        if oid==System.Guid.Empty:raise RuntimeError('Add failed')
        sc.doc.Objects.Hide(sid,True)
    finally:sc.doc.EndUndoRecord(undo)
    if TAG+'_published' not in sc.sticky:sc.sticky[TAG+'_published']=[]
    sc.sticky[TAG+'_published'].append({'source':str(sid),'id':str(oid)})
    with io.open(OUT+'/published.json','w',encoding='utf-8')as h:h.write(unicode(json.dumps(sc.sticky[TAG+'_published'],indent=2)))
    sc.doc.Views.Redraw()
    print('Published',index,str(oid))
