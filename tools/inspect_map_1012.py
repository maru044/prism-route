"""Read-only Blender inspection of the Rhino glTF export."""
import bpy
import json
from pathlib import Path
from mathutils import Vector

root = Path(__file__).resolve().parents[1]
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
bpy.ops.import_scene.gltf(filepath=str(root.parent / 'map/mesh.gltf'))
report = []
for obj in bpy.data.objects:
    if obj.type != 'MESH':
        continue
    parents = []
    parent = obj.parent
    while parent:
        parents.append(parent.name)
        parent = parent.parent
    points = [obj.matrix_world @ Vector(p) for p in obj.bound_box]
    report.append({'name': obj.name, 'parents': parents,
                   'vertices': len(obj.data.vertices), 'polygons': len(obj.data.polygons),
                   'min': [min(p[i] for p in points) for i in range(3)],
                   'max': [max(p[i] for p in points) for i in range(3)]})
out = root / '.map_1012_build'
out.mkdir(exist_ok=True)
(out / 'source_inspection.json').write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding='utf-8')
for item in report:
    if item['polygons']:
        print('MAP_OBJECT', json.dumps(item, ensure_ascii=False), flush=True)
