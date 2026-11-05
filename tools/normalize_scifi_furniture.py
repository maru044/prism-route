"""
Normalize and export Sci-Fi furniture models from Sketchfab demo scene:
1. Donut Chair (左一: Demo_007_8_24)
2. Platform Bed (右一: Demo_7_28)
3. Long Sofa (右三: Demo_002_2_7)
4. Round Chair (右四: Demo_005_5_17)
5. Single Armchair (右二: Demo_003_3_11)

Standards:
- Zero floor contact: min_y == 0.0 (bottom rests exactly on ground plane)
- Centered on X: (min_x + max_x) / 2 == 0.0
- Centered on Z: (min_z + max_z) / 2 == 0.0
- Facing: Backrest is at +Z in Godot, seat front faces -Z (Godot Vector3.FORWARD)
- Bed oriented with length along Z, width along X
- Transforms fully baked, node transform == Transform3D.IDENTITY
"""
import bpy
from mathutils import Vector, Matrix
import math
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
        "rotate_z_deg": 0.0,
        "target_seat_height": 0.45
    },
    {
        "id": "scifi_round_chair",
        "name_zh": "科技圆形碗状单人椅 (右四)",
        "source_group": "Demo_005_5_17",
        "category": "chair",
        "rotate_z_deg": 0.0,
        "target_seat_height": 0.45
    },
    {
        "id": "scifi_long_sofa",
        "name_zh": "科技三人模块化长沙发 (右三)",
        "source_group": "Demo_002_2_7",
        "category": "sofa",
        "rotate_z_deg": 0.0,
        "target_seat_height": 0.46
    },
    {
        "id": "scifi_single_armchair",
        "name_zh": "科技单人扶手沙发椅 (右二)",
        "source_group": "Demo_003_3_11",
        "category": "armchair",
        "rotate_z_deg": 0.0,
        "target_seat_height": 0.46
    },
    {
        "id": "scifi_platform_bed",
        "name_zh": "科技平躺平台大床 (右一)",
        "source_group": "Demo_7_28",
        "category": "bed",
        "rotate_z_deg": 90.0, # Rotate 90 deg so length is along Z (depth) in Godot
        "target_seat_height": 0.48
    }
]

manifest = {"furniture": []}

for target in TARGETS:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(SOURCE_GLTF))
    
    g_obj = bpy.data.objects.get(target["source_group"])
    assert g_obj, f"Group {target['source_group']} not found!"
    
    meshes = []
    def collect(o):
        if o.type == 'MESH':
            meshes.append(o)
        for c in o.children:
            collect(c)
    collect(g_obj)
    
    # Detach meshes from parent hierarchy keeping exact world transforms
    for m in meshes:
        bpy.ops.object.select_all(action='DESELECT')
        m.select_set(True)
        bpy.context.view_layer.objects.active = m
        bpy.ops.object.parent_clear(type='CLEAR_KEEP_TRANSFORM')
        bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
        
    # Join into a single clean model preserving all material slots
    bpy.ops.object.select_all(action='DESELECT')
    for m in meshes:
        m.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    bpy.ops.object.join()
    joined = meshes[0]
    joined.name = target["id"]
    
    # Apply rotation around Z if requested
    if target.get("rotate_z_deg", 0.0) != 0.0:
        rot_mat = Matrix.Rotation(math.radians(target["rotate_z_deg"]), 4, 'Z')
        joined.data.transform(rot_mat)
        
    # Compute bounding box
    verts = [v.co for v in joined.data.vertices]
    min_x = min(v.x for v in verts)
    max_x = max(v.x for v in verts)
    min_y = min(v.y for v in verts)
    max_y = max(v.y for v in verts)
    min_z = min(v.z for v in verts)
    max_z = max(v.z for v in verts)
    
    center_x = (min_x + max_x) * 0.5
    center_y = (min_y + max_y) * 0.5
    base_z = min_z
    
    # Translate vertices so base is at Z=0, X centered at 0, Y centered at 0
    shift_mat = Matrix.Translation(Vector((-center_x, -center_y, -base_z)))
    joined.data.transform(shift_mat)
    
    # Remove all other objects in scene
    for o in list(bpy.data.objects):
        if o != joined:
            bpy.data.objects.remove(o, do_unlink=True)
            
    # Final bounds verification in Blender
    v_final = [v.co for v in joined.data.vertices]
    f_min_x, f_max_x = min(v.x for v in v_final), max(v.x for v in v_final)
    f_min_y, f_max_y = min(v.y for v in v_final), max(v.y for v in v_final)
    f_min_z, f_max_z = min(v.z for v in v_final), max(v.z for v in v_final)
    
    width = f_max_x - f_min_x
    depth = f_max_y - f_min_y
    height = f_max_z - f_min_z
    
    out_file = OUTPUT_DIR / f"{target['id']}.glb"
    
    bpy.ops.object.select_all(action='SELECT')
    bpy.context.view_layer.objects.active = joined
    
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
            "width": round(width, 3),
            "depth": round(depth, 3),
            "height": round(height, 3)
        },
        "seat_surface_height": target["target_seat_height"],
        "facing": "+Z",
        "backrest": "-Z",
        "ground_contact_y": 0.0
    }
    manifest["furniture"].append(entry)
    print(f"EXPORTED: {target['id']} -> {out_file.name}")
    print(f"  Dims: W:{width:.2f}m, D:{depth:.2f}m, H:{height:.2f}m")
    print(f"  Blender bounds: X:[{f_min_x:.3f}, {f_max_x:.3f}], Y:[{f_min_y:.3f}, {f_max_y:.3f}], Z:[{f_min_z:.3f}, {f_max_z:.3f}]")

manifest_path = OUTPUT_DIR / "furniture_catalog.json"
manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding="utf-8")
print(f"Manifest written to {manifest_path}")
