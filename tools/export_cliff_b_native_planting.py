# -*- coding: utf-8 -*-
"""Run in Rhino, write a separate CAD copy with planting meshes and tree marks."""
from __future__ import unicode_literals
import Rhino
import System
import io
import os
import json

ROOT = r'D:\Prism Route\prism-route'

def read(path):
    with io.open(path,encoding='utf-8') as stream:
        return json.load(stream)

def run():
    folder = os.path.join(ROOT,'assets','world','cliff_b_test')
    model = Rhino.FileIO.File3dm.Read(os.path.join(folder,'source','cliff_b_native_snapshot.3dm'))
    if model is None:
        raise RuntimeError('Missing native source snapshot')
    def material(name,color):
        result = Rhino.DocObjects.Material()
        result.Name = name
        result.DiffuseColor = color
        result.Shine = 8
        index = len(list(model.Materials))
        model.Materials.Add(result)
        return index
    white = material('B_暖白人工建筑表面',System.Drawing.Color.FromArgb(243,239,232))
    green = material('B_种植区域_鼠尾草绿',System.Drawing.Color.FromArgb(126,149,89))
    for obj in model.Objects:
        source_layer = obj.Attributes.GetUserString('source_layer') or ''
        if source_layer.startswith('崖壁B_错层台地_NURBS_v01') and not any(word in source_layer for word in ['浅水','中层道路']):
            obj.Attributes.MaterialSource = Rhino.DocObjects.ObjectMaterialSource.MaterialFromObject
            obj.Attributes.MaterialIndex = white
            obj.Attributes.ObjectColor = System.Drawing.Color.FromArgb(243,239,232)
            obj.Attributes.ColorSource = Rhino.DocObjects.ObjectColorSource.ColorFromObject
    zone_layer = Rhino.DocObjects.Layer()
    zone_layer.Name = 'B_种植区域_v01'
    zone_layer.Color = System.Drawing.Color.FromArgb(126,149,89)
    zone_index = len(list(model.Layers))
    model.Layers.Add(zone_layer)
    zones = read(os.path.join(ROOT,'.cliff_b_build','planting_zones_native.json'))
    for zone in zones:
        mesh = Rhino.Geometry.Mesh()
        for p in zone['vertices']:
            mesh.Vertices.Add(float(p[0]),float(p[1]),float(p[2]))
        for tri in zone['triangles']:
            mesh.Faces.AddFace(int(tri[0]),int(tri[1]),int(tri[2]))
        mesh.Normals.ComputeNormals()
        attrs = Rhino.DocObjects.ObjectAttributes()
        attrs.LayerIndex = zone_index
        attrs.Name = zone['name']
        attrs.MaterialIndex = green
        attrs.MaterialSource = Rhino.DocObjects.ObjectMaterialSource.MaterialFromObject
        attrs.SetUserString('description','Planting test bed: 6m edge clearance; 0.06m sward skin, not final soil construction')
        model.Objects.AddMesh(mesh,attrs)
    tree_layer = Rhino.DocObjects.Layer()
    tree_layer.Name = 'B_树位_v01_辅助标记'
    tree_layer.Color = System.Drawing.Color.FromArgb(63,102,63)
    tree_index = len(list(model.Layers))
    model.Layers.Add(tree_layer)
    metadata = read(os.path.join(folder,'build_metadata.json'))
    records = read(os.path.join(folder,'tree_layout.json'))[:metadata['population']['cliff_b_trees']]
    center = metadata['native_center']
    for index,row in enumerate(records):
        point = Rhino.Geometry.Point3d(row[0]+center[0],-row[2]+center[1],row[1])
        attrs = Rhino.DocObjects.ObjectAttributes()
        attrs.LayerIndex = tree_index
        attrs.Name = 'B_树位_%03d'%index
        model.Objects.AddCircle(Rhino.Geometry.Circle(Rhino.Geometry.Plane(point,Rhino.Geometry.Vector3d.ZAxis),3*row[4]),attrs)
    target = os.path.join(os.path.dirname(ROOT),'map','map_cliffB_material_planting_v01.3dm')
    if not model.Write(target,8):
        raise RuntimeError('Cannot save processed CAD copy')
    print(json.dumps({'file':target,'planting_meshes':len(zones),'tree_markers':len(records)},ensure_ascii=False))

if __name__ == '__main__':
    run()
