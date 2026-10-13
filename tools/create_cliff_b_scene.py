"""Assemble the dedicated study from the established world-controller baseline."""
from pathlib import Path
import shutil

ROOT = Path(__file__).resolve().parents[1]

BUILD_MAP = '''func _build_map() -> void:
\tmodel = (load(ASSETS + "cliff_b_world.glb") as PackedScene).instantiate()
\tadd_child(model)
\tterrain_material = ShaderMaterial.new()
\tterrain_material.shader = TERRAIN_SHADER
\tterrain_material.set_shader_parameter("biome_noise_texture", biome_noise)
\tterrain_material.set_shader_parameter("use_height_sand", false)
\tterrain_material.set_shader_parameter("rock_color", Color(0.68, 0.67, 0.62))
\tvar sand := ShaderMaterial.new()
\tsand.shader = load("res://assets/world/map_1012_test/sand.gdshader")
\tsand.set_shader_parameter("grain_texture", _noise_texture(1012, 0.075))
\tvar water := ShaderMaterial.new()
\twater.shader = load("res://assets/world/map_1012_test/water.gdshader")
\tvar road := ShaderMaterial.new()
\troad.shader = load("res://assets/world/map_1012_test/road.gdshader")
\tvar projection: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ASSETS + "road_projection_metadata.json"))
\tvar atlas: Texture2D = load(ASSETS + "road_projection.res")
\tterrain_material.set_shader_parameter("project_roads", true)
\tfor material: ShaderMaterial in [terrain_material, road]:
\t\tmaterial.set_shader_parameter("road_projection", atlas)
\t\tmaterial.set_shader_parameter("road_origin_xz", Vector2(projection.origin_xz[0], projection.origin_xz[1]))
\t\tmaterial.set_shader_parameter("road_extent_xz", Vector2(projection.extent_xz[0], projection.extent_xz[1]))
\t\tmaterial.set_shader_parameter("ground_road_height_tolerance", projection.ground_road_height_tolerance_m)
\tvar architecture := preload("res://assets/world/cliff_b_test/architecture.tres")
\tplanting_material = ShaderMaterial.new()
\tplanting_material.shader = preload("res://assets/world/cliff_b_test/meadow.gdshader")
\tvar meshes: Array[MeshInstance3D] = []
\t_collect_meshes(model, meshes)
\tfor mesh in meshes:
\t\tvar kind: String = str(mesh.name).get_slice("_", 0)
\t\tmesh.material_override = {"Terrain": terrain_material, "Roads": road, "Beaches": sand, "Water": water, "Architecture": architecture, "Planting": planting_material}.get(kind, terrain_material)
\t\tif kind in ["Water", "Planting"]:
\t\t\tmesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
\t\tvar shape := mesh.mesh.create_trimesh_shape()
\t\tshape.backface_collision = true
\t\tvar body := StaticBody3D.new()
\t\tbody.name = "ExactMeshCollision"
\t\tbody.collision_layer = 4 if kind == "Water" else (17 if kind == "Planting" else (9 if kind == "Roads" else 1))
\t\tbody.collision_mask = 0
\t\tbody.set_meta("map_surface", kind)
\t\tmesh.add_child(body)
\t\tvar collider := CollisionShape3D.new()
\t\tcollider.shape = shape
\t\tbody.add_child(collider)

'''


def main():
    script = (ROOT/'scripts/map_1012_drive_test.gd').read_text(encoding='utf-8')
    script = script.replace('## 1012 world review: original CAD surfaces, spaced trees and the short camper.',
        '## Cliff B: warm fabricated white architecture and explicit planting beds.')
    script = script.replace('res://assets/world/map_1012_test/', 'res://assets/world/cliff_b_test/')
    script = script.replace('["道路出生点", "林地", "沙滩", "高层平台"]', '["道路廊道", "底层步道", "错层台地", "屋顶草甸"]')
    script = script.replace('var character_mode := false', 'var character_mode := true\nvar scene_label := "崖壁 B"\nvar planting_material: ShaderMaterial\nvar show_planting_regions := false')
    script = script.replace('await select_spawn(0)', 'await select_spawn(3)')
    script = script.replace('vegetation.initialize(camper, biome_noise, 2)', 'vegetation.initialize(active_actor(), biome_noise, 2)\n\t_sync_actor_controls()')
    script = script.replace('MAP_1012_READY trees=%d large=%d old_camper_unscaled=true', 'CLIFF_B_READY trees=%d large=%d native_scale=true')
    script = script.replace('test_ready = true', 'test_ready = true\n\tif not automation_enabled:\n\t\tshow_overview()')
    begin = script.index('func _build_map() -> void:')
    end = script.index('func _collect_meshes(', begin)
    script = script[:begin]+BUILD_MAP+script[end:]
    script = script.replace('sun.directional_shadow_max_distance = 180','sun.directional_shadow_max_distance = 500')
    script = script.replace('environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY',
        'environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR\n\tenvironment.ambient_light_color = Color(0.94, 0.955, 0.98)')
    script = script.replace('environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY',
        'environment.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED')
    script = script.replace('sun.light_color = Color("ffe2b8")', 'sun.light_color = Color("fff2df")')
    script = script.replace('Vector3(point.x, 400, point.z), Vector3(point.x, -30, point.z)',
        'point + Vector3.UP * 3.0, point - Vector3.UP * 12.0')
    script = script.replace('camera.position = Vector3(1400, 1450, 1900)', 'camera.position = Vector3(550, 420, -620)')
    script = script.replace('camera.look_at(Vector3(0, 35, 0))', 'camera.look_at(Vector3(0, 30, 0))')
    script = script.replace('KEY_TAB: show_overview()', 'KEY_TAB: show_overview()\n\t\t\tKEY_P: toggle_planting_regions()')
    script = script.replace('test_panel.setup(self)', 'test_panel.setup(self)')
    script += '''
func toggle_planting_regions() -> void:
\tshow_planting_regions = not show_planting_regions
\tplanting_material.set_shader_parameter("green", Color(0.18, 0.72, 0.43) if show_planting_regions else Color(0.42, 0.51, 0.29))
\tplanting_material.set_shader_parameter("straw", Color(0.18, 0.72, 0.43) if show_planting_regions else Color(0.60, 0.57, 0.35))
'''
    (ROOT/'scripts/cliff_b_gameplay_test.gd').write_text(script,encoding='utf-8')
    scene = (ROOT/'scenes/map_1012_drive_test.tscn').read_text(encoding='utf-8')
    scene = scene.replace('scripts/map_1012_drive_test.gd','scripts/cliff_b_gameplay_test.gd')
    scene = scene.replace('scripts/map_1012_vegetation.gd','scripts/cliff_b_vegetation.gd')
    scene = scene.replace('Map1012DriveTest','CliffBGameplayTest')
    (ROOT/'scenes/cliff_b_gameplay_test.tscn').write_text(scene,encoding='utf-8')
    main_scene = (ROOT/'scenes/main.tscn').read_text(encoding='utf-8')
    main_scene = main_scene.replace('map_1012_drive_test.tscn','cliff_b_gameplay_test.tscn').replace('Map1012DriveTest','CliffBGameplayTest')
    (ROOT/'scenes/main.tscn').write_text(main_scene,encoding='utf-8')
    print('Cliff B scene assembled; F5 enters roof meadow, original 1012 scene retained.')


if __name__ == '__main__':
    main()
