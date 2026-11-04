# -*- coding: utf-8 -*-
import io

path = 'D:/Prism Route/prism-route/scripts/map_1021.gd'
content = io.open(path, 'r', encoding='utf-8').read()

# 1. Add const and var
target1 = 'const ROAD_JUNCTION := preload("res://scripts/world/road_junction.gd")\nvar sunken_archive'
replacement1 = 'const ROAD_JUNCTION := preload("res://scripts/world/road_junction.gd")\nconst CHURCH_RUINS := preload("res://scripts/world/church_ruins.gd")\nvar church_ruins\nvar sunken_archive'
if target1 not in content:
    target1 = target1.replace('\n', '\r\n')
    replacement1 = replacement1.replace('\n', '\r\n')

assert target1 in content, "target1 not found"
content = content.replace(target1, replacement1, 1)

# 2. Add build call in _ready
target2 = '_build_sunken_archive();_build_upper_ring();'
replacement2 = '_build_sunken_archive();_build_church_ruins();_build_upper_ring();'
assert target2 in content, "target2 not found"
content = content.replace(target2, replacement2, 1)

# 3. Add preview CLI argument
target3 = 'if "--sunken-archive-preview" in OS.get_cmdline_user_args():'
preview_block = '''\tif "--church-preview" in OS.get_cmdline_user_args():
\t\tfor i in resolved_spawns.size():
\t\t\tif resolved_spawns[i].get("key","")=="church_ruins":initial_spawn=i;break
\tif "--sunken-archive-preview" in OS.get_cmdline_user_args():'''
if '\r\n' in content:
    preview_block = preview_block.replace('\n', '\r\n')

assert target3 in content, "target3 not found"
content = content.replace(target3, preview_block, 1)

# 4. Add _build_church_ruins function
target4 = 'func _build_sunken_archive() -> void:'
build_block = '''func _build_church_ruins() -> void:
\tchurch_ruins=CHURCH_RUINS.new();church_ruins.world=self;add_child(church_ruins)
\tmetadata.spawns.append({"name":"西双子山 · 孤顶教堂遗址","key":"church_ruins","position":church_ruins.manifest.spawn_godot,
\t\t"look_direction":church_ruins.manifest.spawn_look_direction_godot,"required_floor_kind":"Structure",
\t\t"required_source_id":church_ruins.manifest.spawn_source_id,"maximum_search_distance_m":2.,"character_only":true})

func _build_sunken_archive() -> void:'''
if '\r\n' in content:
    build_block = build_block.replace('\n', '\r\n')

assert target4 in content, "target4 not found"
content = content.replace(target4, build_block, 1)

io.open(path, 'w', encoding='utf-8').write(content)
print("Successfully patched map_1021.gd for Church Ruins!")
