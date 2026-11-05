"""
Extract and normalize requested Sci-Fi furniture models from demo pack:
1. Donut Chair (左一: Demo_007_8_24)
2. Platform Bed (右一: Demo_7_28)
3. Long Sofa (右三: Demo_002_2_7)
4. Round Chair (右四: Demo_005_5_17)
5. Single Armchair (右二: Demo_003_3_11, complementary)
"""
import bpy
from mathutils import Vector, Matrix
from pathlib import Path
import json

SOURCE_GLTF = Path("D:/Prism Route/assets/model/sci-fi_chairs_demo/scene.gltf")
OUTPUT_DIR = Path("D:/Prism Route/prism-route/assets/furniture/scifi")
OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

TARGETS = [
    {
        "id": "scifi_donut_chair",
        "name_zh": "科技甜甜圈圆环椅 (左一)",
        "source_group": "Demo_007_8_24",
        "category": "chair",
        "target_seat_height": 0.45
    },
    {
        "id": "scifi_platform_bed",
        "name_zh": "科技平躺平台大床 (右一)",
        "source_group": "Demo_7_28",
        "category": "bed",
        "target_seat_height": 0.48
    },
    {
        "id": "scifi_long_sofa",
        "name_zh": "科技三人模块化长沙发 (右三)",
        "source_group": "Demo_002_2_7",
        "category": "sofa",
        "target_seat_height": 0.46
    },
    {
        "id": "scifi_round_chair",
        "name_zh": "科技圆形碗状单人椅 (右四)",
        "source_group": "Demo_005_5_17",
        "category": "chair",
        "target_seat_height": 0.45
    },
    {
        "id": "scifi_single_armchair",
        "name_zh": "科技单人扶手沙发椅 (右二)",
        "source_group": "Demo_003_3_11",
        "category": "armchair",
        "target_seat_height": 0.46
    }
]

manifest = {"furniture": []}

for target in TARGETS:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(SOURCE_GLTF))
    
    g_obj = bpy.data.objects.get(target["source_group"])
    assert g_obj, f"Group {target['source_group']} not found!"
    
    # Collect all mesh children
    meshes = []
    def collect(o):
        if o.type == 'MESH':
            meshes.append(o)
        for c in o.children:
            collect(c)
    collect(g_obj)
    
    # Unlink all other objects
    to_keep = set(meshes)
    curr = g_obj
    while curr:
        to_keep.add(curr)
        curr = curr.parent
    for o in list(bpy.data.objects):
        if o not in to_keep and o.type == 'MESH':
            bpy.data.objects.remove(o, do_unlink=True)
            
    # Calculate global bounding box
    min_co = Vector((1e9, 1e9, 1e9))
    max_co = Vector((-1e9, -1e9, -1e9))
    for m in meshes:
        for v in m.data.vertices:
            w = m.matrix_world @ v.co
            min_co.x = min(min_co.x, w.x)
            min_co.y = min(min_co.y, w.y)
            min_co.z = min(min_co.z, w.z)
            max_co.x = max(max_co.x, w.x)
            max_co.y = max(max_co.y, w.y)
            max_co.z = max(max_co.z, w.z)
            
    center_x = (min_co.x + max_co.x) * 0.5
    center_y = (min_co.y + max_co.y) * 0.5
    base_z = min_co.z
    dims = max_co - min_co
    
    # Shift so center X=0, center Y=0, base Z=0
    shift = Vector((-center_x, -center_y, -base_z))
    
    # Create an empty as new clean root
    root = bpy.data.objects.new(target["id"], None)
    bpy.context.scene.collection.objects.link(root)
    
    # Move and apply transforms to all meshes directly
    for m in meshes:
        # Bake world matrix + shift into vertices
        mw = Matrix.Translation(shift) @ m.matrix_world
        m.data.transform(mw)
        m.matrix_world = Matrix.Identity(4)
        m.parent = root
        
    # Remove unused objects
    for o in list(bpy.data.objects):
        if o != root and o not in meshes:
            bpy.data.objects.remove(o, do_unlink=True)
            
    out_file = OUTPUT_DIR / f"{target['id']}.glb"
    
    # Select root and meshes
    for o in bpy.data.objects:
        o.select_set(True)
    bpy.context.view_layer.objects.active = root
    
    bpy.ops.export_scene.gltf(
        filepath=str(out_file),
        export_format='GLB',
        use_selection=True,
        export_apply=True,
        export_yup=True
    )
    
    entry = {
        "id": target["id"],
        "name_zh": target["name_zh"],
        "category": target["category"],
        "file": f"res://assets/furniture/scifi/{target['id']}.glb",
        "dimensions": {
            "width": round(dims.x, 3),
            "depth": round(dims.y, 3),
            "height": round(dims.z, 3)
        },
        "seat_surface_height": target["target_seat_height"],
        "facing": "-Z"
    }
    manifest["furniture"].append(entry)
    print(f"EXPORTED: {target['id']} -> {out_file} (Dims: {dims.x:.2f}x{dims.y:.2f}x{dims.z:.2f}m)")

manifest_path = OUTPUT_DIR / "furniture_catalog.json"
manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding="utf-8")
print(f"Catalog saved: {manifest_path}")
