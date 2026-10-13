# -*- coding: utf-8 -*-
"""Run in Rhino: read current visible geometry without editing the document."""
from __future__ import unicode_literals
import Rhino
import scriptcontext as sc
import json
import os
import io

ROOT = r'D:\Prism Route\prism-route'
OUT = os.path.join(ROOT, '.cliff_b_build')


def run():
    if not os.path.isdir(OUT):
        os.makedirs(OUT)
    doc = sc.doc
    before = doc.Modified
    settings = Rhino.Geometry.MeshingParameters()
    settings.Tolerance = 0.12
    settings.RelativeTolerance = 0.0
    settings.MinimumEdgeLength = 0.25
    settings.MaximumEdgeLength = 18.0
    settings.RefineGrid = True
    settings.JaggedSeams = False
    settings.SimplePlanes = True
    records = []
    native = Rhino.FileIO.File3dm()
    native.Settings.ModelUnitSystem = doc.ModelUnitSystem
    native_layers = {}
    for obj in doc.Objects:
        if obj.IsDeleted or obj.IsHidden:
            continue
        layer = doc.Layers[obj.Attributes.LayerIndex]
        if not layer.IsVisible:
            continue
        path = layer.FullPath
        own = path.startswith('崖壁B_错层台地_NURBS_v01::')
        if not own and path not in ['地形', '路面', '沙滩', '水面']:
            continue
        geometry = obj.Geometry
        if not isinstance(geometry, (Rhino.Geometry.Brep, Rhino.Geometry.Extrusion, Rhino.Geometry.Mesh)):
            continue
        if not geometry.IsValid:
            raise RuntimeError('Invalid visible geometry: ' + str(obj.Id))
        if own:
            kind = 'Water' if '浅水' in path else ('Roads' if '中层道路' in path else 'Architecture')
        else:
            kind = {'地形':'Terrain', '路面':'Roads', '沙滩':'Beaches', '水面':'Water'}[path]
        # Native snapshot retains all exported geometry and its provenance.
        if path not in native_layers:
            nl = Rhino.DocObjects.Layer()
            nl.Name = path.replace('::', '_')
            native_layers[path] = len(list(native.Layers))
            native.Layers.Add(nl)
        li = native_layers[path]
        attrs = obj.Attributes.Duplicate()
        attrs.LayerIndex = li
        attrs.SetUserString('source_layer', path)
        attrs.SetUserString('source_id', str(obj.Id))
        native.Objects.Add(geometry.Duplicate(), attrs)
        if isinstance(geometry, Rhino.Geometry.Mesh):
            parts = [geometry.DuplicateMesh()]
        else:
            brep = geometry.ToBrep() if isinstance(geometry, Rhino.Geometry.Extrusion) else geometry
            parts = Rhino.Geometry.Mesh.CreateFromBrep(brep, settings)
        mesh = Rhino.Geometry.Mesh()
        for part in parts or []:
            mesh.Append(part)
        mesh.Faces.ConvertQuadsToTriangles()
        mesh.Vertices.CombineIdentical(True, True)
        mesh.Compact()
        mesh.Normals.ComputeNormals()
        if not mesh.IsValid:
            raise RuntimeError('Invalid tessellation: ' + str(obj.Id))
        records.append({'id':str(obj.Id), 'name':obj.Name or '', 'layer':path, 'kind':kind,
            'owned':own, 'plant_candidate':own and any(x in path for x in ['退后内核','斜切屋盖','圆润端部衔接']),
            'vertices':[[float(v.X),float(v.Y),float(v.Z)] for v in mesh.Vertices],
            'triangles':[[f.A,f.B,f.C] for f in mesh.Faces]})
    result = {'source_document':doc.Path, 'source_modified_at_read':before,
              'units':str(doc.ModelUnitSystem), 'objects':records}
    with io.open(os.path.join(OUT,'rhino_scene.json'),'w',encoding='utf-8') as f:
        f.write(json.dumps(result,ensure_ascii=False,separators=(',',':')))
    snapshot = os.path.join(ROOT,'assets','world','cliff_b_test','source','cliff_b_native_snapshot.3dm')
    if not native.Write(snapshot,8):
        raise RuntimeError('Cannot write native snapshot')
    if doc.Modified != before:
        raise RuntimeError('Source document state unexpectedly changed')
    print(json.dumps({'objects':len(records),'triangles':sum(len(r['triangles']) for r in records),
                      'output':snapshot,'source_modified_preserved':True},ensure_ascii=False))


if __name__ == '__main__':
    run()
