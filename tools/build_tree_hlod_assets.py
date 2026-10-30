"""Build non-destructive large-tree LOD assets from the accepted source trees.

LOD1 preserves the authored crown volume with camera-facing clump cards.  The
small tree is split into five overlapping volume clumps instead of collapsing
to one whole-crown card.  The two large trees spatially aggregate their thirty
authored groups into fourteen larger clumps, retaining the outer silhouette
without paying for thirty medium-distance cards.  The atlas is rendered from
accepted high-detail foliage with an unlit material, so it carries alpha
silhouette detail but no baked lighting.

LOD2 keeps the real low-poly trunk and replaces the complete crown with one
camera-facing card.  Its atlas contains eight unlit azimuth views.  Godot picks
the appropriate frame in the vegetation shader.
"""

from __future__ import annotations

import math
import os
import shutil
import sys
import argparse
from pathlib import Path

import bpy
import bmesh
from mathutils import Vector


REPO = Path(__file__).resolve().parents[1]
MODEL_DIR = REPO / "assets" / "vegetation" / "models"
SOURCE_DIR = REPO / "assets" / "vegetation" / "source"
TEXTURE_DIR = REPO / "assets" / "vegetation" / "textures"
TEMP_DIR = REPO / ".tree_hlod_build"

SPECS = (
    {
        "key": "birch",
        "source": SOURCE_DIR / "tree_medium_birch_upright_canopy.blend",
        "stem": "tree_medium_birch_upright_canopy",
        "group_count": 24,
        "joined_group_faces": 96,
        "lod1_group_count": 12,
        "lod1_card_width_scale": 1.0,
        "lod1_card_height_scale": 1.10,
    },
    {
        "key": "small",
        "source": SOURCE_DIR / "tree_small_broad_canopy.blend",
        "stem": "tree_small_broad_canopy",
        "group_count": 1,
        "lod1_group_count": 5,
        "lod1_card_width_scale": 1.14,
        "lod1_card_height_scale": 1.22,
    },
    {
        "key": "broad",
        "source": SOURCE_DIR / "tree_medium_broad_clustered_canopy.blend",
        "stem": "tree_medium_broad_clustered_canopy",
        "group_count": 30,
        "lod1_group_count": 14,
        "lod1_card_width_scale": 0.94,
        "lod1_card_height_scale": 1.22,
    },
    {
        "key": "upright",
        "source": SOURCE_DIR / "tree_medium_upright_asymmetric_canopy.blend",
        "stem": "tree_medium_upright_asymmetric_canopy",
        "group_count": 30,
        "lod1_group_count": 14,
        "lod1_card_width_scale": 0.99,
        "lod1_card_height_scale": 1.18,
    },
)

CLUMP_CELL = 384
TREE_CELL = 320


def object_world_bounds(obj):
    points = [obj.matrix_world @ Vector(corner) for corner in obj.bound_box]
    minimum = Vector((
        min(point.x for point in points),
        min(point.y for point in points),
        min(point.z for point in points),
    ))
    maximum = Vector((
        max(point.x for point in points),
        max(point.y for point in points),
        max(point.z for point in points),
    ))
    return minimum, maximum


def union_bounds(objects):
    bounds = [object_world_bounds(obj) for obj in objects]
    minimum = Vector(tuple(min(bound[0][axis] for bound in bounds) for axis in range(3)))
    maximum = Vector(tuple(max(bound[1][axis] for bound in bounds) for axis in range(3)))
    return minimum, maximum


def bounds_center(bounds):
    return (bounds[0] + bounds[1]) * 0.5


def virtual_small_crown_bounds(foliage):
    """Split the single authored small crown into five overlapping volumes."""
    minimum, maximum = union_bounds(foliage)
    center = (minimum + maximum) * 0.5
    size = maximum - minimum
    # X/Y are horizontal in Blender and Z is vertical.  Offsets introduce real
    # front/back depth; cards later rotate around their individual pivots.
    layouts = (
        ((-0.22, -0.10, -0.10), (0.62, 0.68, 0.64)),
        ((0.21, 0.10, -0.08), (0.62, 0.68, 0.64)),
        ((-0.12, 0.18, 0.08), (0.60, 0.62, 0.62)),
        ((0.13, -0.18, 0.09), (0.60, 0.62, 0.62)),
        ((0.00, 0.00, 0.17), (0.58, 0.60, 0.60)),
    )
    result = []
    for offset_values, scale_values in layouts:
        offset = Vector(tuple(offset_values[index] * size[index] for index in range(3)))
        half_size = Vector(tuple(scale_values[index] * size[index] * 0.5 for index in range(3)))
        clump_center = center + offset
        result.append((clump_center - half_size, clump_center + half_size))
    return result


def aggregate_crown_bounds(foliage, target_count):
    """Deterministically cluster authored groups and return their union bounds."""
    source_bounds = [object_world_bounds(obj) for obj in foliage]
    if len(source_bounds) == 1:
        return virtual_small_crown_bounds(foliage)
    target_count = min(target_count, len(source_bounds))
    centers = [bounds_center(bounds) for bounds in source_bounds]
    overall_minimum, overall_maximum = union_bounds(foliage)
    extent = overall_maximum - overall_minimum

    def normalized_distance_squared(first, second):
        return sum(
            ((first[axis] - second[axis]) / max(extent[axis], 0.001)) ** 2
            for axis in range(3)
        )

    # Farthest-point seeds cover the complete silhouette before Lloyd updates.
    crown_center = (overall_minimum + overall_maximum) * 0.5
    seed_indices = [min(
        range(len(centers)),
        key=lambda index: normalized_distance_squared(centers[index], crown_center),
    )]
    while len(seed_indices) < target_count:
        seed_indices.append(max(
            (index for index in range(len(centers)) if index not in seed_indices),
            key=lambda index: min(
                normalized_distance_squared(centers[index], centers[seed])
                for seed in seed_indices
            ),
        ))
    centroids = [centers[index].copy() for index in seed_indices]
    assignments = [0] * len(centers)
    for _iteration in range(12):
        assignments = [
            min(
                range(target_count),
                key=lambda cluster: normalized_distance_squared(center, centroids[cluster]),
            )
            for center in centers
        ]
        updated = []
        for cluster in range(target_count):
            members = [
                centers[index]
                for index, assignment in enumerate(assignments)
                if assignment == cluster
            ]
            if not members:
                updated.append(centroids[cluster])
                continue
            updated.append(sum(members, Vector()) / len(members))
        centroids = updated

    result = []
    for cluster in range(target_count):
        member_bounds = [
            source_bounds[index]
            for index, assignment in enumerate(assignments)
            if assignment == cluster
        ]
        minimum = Vector(tuple(
            min(bounds[0][axis] for bounds in member_bounds)
            for axis in range(3)
        ))
        maximum = Vector(tuple(
            max(bounds[1][axis] for bounds in member_bounds)
            for axis in range(3)
        ))
        result.append((minimum, maximum))
    return sorted(result, key=lambda bounds: tuple(bounds_center(bounds)))


def foliage_objects():
    return sorted(
        [
            obj for obj in bpy.context.scene.objects
            if obj.type == "MESH" and "Foliage" in obj.name
        ],
        key=lambda obj: obj.name,
    )


def source_foliage(spec):
    """Recover the birch's authored contiguous groups in a bake-only scene.

    Each authored volume contains 24 crossed cells, i.e. 96 quad faces.
    Copying the mesh preserves its UVs; the accepted source is never saved.
    """
    objects = foliage_objects()
    faces_per_group = spec.get("joined_group_faces")
    if faces_per_group is None:
        return objects
    if len(objects) != 1 or len(objects[0].data.polygons) != faces_per_group * spec["group_count"]:
        raise RuntimeError("Birch group topology changed; rebuild recipe must be reviewed")
    original = objects[0]
    result = []
    for group in range(spec["group_count"]):
        obj = original.copy()
        obj.data = original.data.copy()
        obj.name = f"Birch_Foliage_Group_{group:02d}"
        bpy.context.scene.collection.objects.link(obj)
        bm = bmesh.new()
        bm.from_mesh(obj.data)
        bm.faces.ensure_lookup_table()
        removed = [face for index, face in enumerate(bm.faces)
                   if not group * faces_per_group <= index < (group + 1) * faces_per_group]
        bmesh.ops.delete(bm, geom=removed, context="FACES")
        loose = [vertex for vertex in bm.verts if not vertex.link_faces]
        if loose:
            bmesh.ops.delete(bm, geom=loose, context="VERTS")
        bm.to_mesh(obj.data)
        bm.free()
        obj.data.update()
        result.append(obj)
    bpy.data.objects.remove(original, do_unlink=True)
    bpy.context.view_layer.update()
    return result


def trunk_object():
    trunks = [
        obj for obj in bpy.context.scene.objects
        if obj.type == "MESH" and "Trunk" in obj.name
    ]
    if len(trunks) != 1:
        raise RuntimeError(f"Expected one trunk, found {[obj.name for obj in trunks]}")
    return trunks[0]


def make_unlit_leaf_material(source_material):
    image = None
    for node in source_material.node_tree.nodes:
        if node.bl_idname == "ShaderNodeTexImage" and node.image is not None:
            image = node.image
            break
    if image is None:
        raise RuntimeError("Leaf material has no image texture")

    material = bpy.data.materials.get("M_Tree_HLOD_UnlitBake")
    if material is None:
        material = bpy.data.materials.new("M_Tree_HLOD_UnlitBake")
    material.use_nodes = True
    material.surface_render_method = "DITHERED"
    material.use_transparency_overlap = False
    nodes = material.node_tree.nodes
    links = material.node_tree.links
    nodes.clear()
    output = nodes.new("ShaderNodeOutputMaterial")
    principled = nodes.new("ShaderNodeBsdfPrincipled")
    texture = nodes.new("ShaderNodeTexImage")
    texture.image = image
    texture.interpolation = "Linear"
    base_weight = principled.inputs.get("Base Weight") or principled.inputs.get("Weight")
    if base_weight is not None:
        base_weight.default_value = 0.0
    principled.inputs["Emission Strength"].default_value = 1.0
    links.new(texture.outputs["Color"], principled.inputs["Emission Color"])
    links.new(texture.outputs["Alpha"], principled.inputs["Alpha"])
    links.new(principled.outputs["BSDF"], output.inputs["Surface"])
    return material


def configure_render():
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.film_transparent = True
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.render.image_settings.color_depth = "8"
    scene.render.resolution_percentage = 100
    scene.render.resolution_x = CLUMP_CELL
    scene.render.resolution_y = CLUMP_CELL
    scene.render.image_settings.color_mode = "RGBA"
    scene.view_settings.view_transform = "Standard"
    scene.view_settings.look = "None"
    scene.view_settings.exposure = 0.0
    scene.view_settings.gamma = 1.0

    camera_data = bpy.data.cameras.new("TreeHLOD_BakeCamera")
    camera_data.type = "ORTHO"
    camera = bpy.data.objects.new("TreeHLOD_BakeCamera", camera_data)
    scene.collection.objects.link(camera)
    scene.camera = camera
    return camera


def assign_bake_material(objects, material):
    for obj in objects:
        obj.data = obj.data.copy()
        obj.data.materials.clear()
        obj.data.materials.append(material)


def render_view(objects, center, diameter, angle, output_path, resolution):
    scene = bpy.context.scene
    scene.render.resolution_x = resolution
    scene.render.resolution_y = resolution
    for obj in scene.objects:
        obj.hide_render = obj not in objects and obj.type != "CAMERA"

    direction = Vector((math.sin(angle), -math.cos(angle), 0.0))
    camera = scene.camera
    camera.location = center + direction * max(24.0, diameter * 2.6)
    camera.rotation_euler = (center - camera.location).to_track_quat("-Z", "Y").to_euler()
    camera.data.ortho_scale = diameter * 1.10
    scene.render.filepath = str(output_path)
    bpy.ops.render.render(write_still=True)


def pack_atlas(paths, columns, rows, output_path):
    loaded = [bpy.data.images.load(str(path), check_existing=False) for path in paths]
    width = loaded[0].size[0]
    height = loaded[0].size[1]
    atlas = bpy.data.images.new(
        output_path.stem,
        width=width * columns,
        height=height * rows,
        alpha=True,
    )
    atlas_pixels = [0.0] * (width * columns * height * rows * 4)
    for index, image in enumerate(loaded):
        source = list(image.pixels[:])
        cell_x = index % columns
        # Blender image pixels use a bottom-left origin. Keep row zero at the
        # bottom so Godot's atlas math can use the same convention explicitly.
        cell_y = index // columns
        for row in range(height):
            source_offset = row * width * 4
            target_offset = (
                ((cell_y * height + row) * width * columns + cell_x * width) * 4
            )
            atlas_pixels[target_offset:target_offset + width * 4] = (
                source[source_offset:source_offset + width * 4]
            )
    atlas.pixels.foreach_set(atlas_pixels)
    temporary_output = TEMP_DIR / output_path.name
    atlas.filepath_raw = str(temporary_output)
    atlas.file_format = "PNG"
    atlas.save()
    shutil.copyfile(temporary_output, output_path)
    for image in loaded:
        bpy.data.images.remove(image)
    bpy.data.images.remove(atlas)


def encode_octahedral(normal):
    normal = normal.normalized()
    denominator = abs(normal.x) + abs(normal.y) + abs(normal.z)
    x = normal.x / denominator
    y = normal.y / denominator
    if normal.z < 0.0:
        old_x = x
        x = (1.0 - abs(y)) * (1.0 if old_x >= 0.0 else -1.0)
        y = (1.0 - abs(old_x)) * (1.0 if y >= 0.0 else -1.0)
    return x * 0.5 + 0.5, y * 0.5 + 0.5


def image_material(name, image_path):
    material = bpy.data.materials.new(name)
    material.use_nodes = True
    material.surface_render_method = "DITHERED"
    nodes = material.node_tree.nodes
    links = material.node_tree.links
    nodes.clear()
    output = nodes.new("ShaderNodeOutputMaterial")
    principled = nodes.new("ShaderNodeBsdfPrincipled")
    texture = nodes.new("ShaderNodeTexImage")
    texture.image = bpy.data.images.load(str(image_path), check_existing=True)
    texture.interpolation = "Linear"
    principled.inputs["Roughness"].default_value = 0.9
    principled.inputs["Specular IOR Level"].default_value = 0.15
    links.new(texture.outputs["Color"], principled.inputs["Base Color"])
    links.new(texture.outputs["Alpha"], principled.inputs["Alpha"])
    links.new(principled.outputs["BSDF"], output.inputs["Surface"])
    return material


def add_vertex_data(mesh, normals, wind_values):
    attribute = mesh.color_attributes.new(
        name="foliage_data", type="FLOAT_COLOR", domain="POINT"
    )
    for index, normal in enumerate(normals):
        encoded_x, encoded_y = encode_octahedral(normal)
        attribute.data[index].color = (
            wind_values[index], encoded_x, encoded_y, 1.0
        )
    mesh.attributes.active_color = attribute


def add_uv(mesh, uvs):
    layer = mesh.uv_layers.new(name="UVMap")
    for polygon in mesh.polygons:
        for loop_index in polygon.loop_indices:
            vertex_index = mesh.loops[loop_index].vertex_index
            layer.data[loop_index].uv = uvs[vertex_index]


def add_uv2(mesh, uvs):
    layer = mesh.uv_layers.new(name="UVMap.001")
    for polygon in mesh.polygons:
        for loop_index in polygon.loop_indices:
            vertex_index = mesh.loops[loop_index].vertex_index
            layer.data[loop_index].uv = uvs[vertex_index]


def append_double_sided_quad(
    vertices, faces, uvs, normals, winds, pivots,
    corners, uv_rect, normal, pivot_uv=(0.0, 0.0)
):
    start = len(vertices)
    vertices.extend(corners)
    u0, v0, u1, v1 = uv_rect
    uvs.extend(((u0, v0), (u1, v0), (u1, v1), (u0, v1)))
    normals.extend((normal,) * 4)
    winds.extend((0.30, 0.58, 1.0, 0.76))
    pivots.extend((pivot_uv,) * 4)
    faces.append((start, start + 1, start + 2, start + 3))

    start = len(vertices)
    vertices.extend(corners)
    uvs.extend(((u0, v0), (u1, v0), (u1, v1), (u0, v1)))
    normals.extend((-normal,) * 4)
    winds.extend((0.30, 0.58, 1.0, 0.76))
    pivots.extend((pivot_uv,) * 4)
    faces.append((start + 3, start + 2, start + 1, start))


def create_lod1_foliage(
    group_bounds,
    material,
    source_group_count,
    card_width_scale,
    card_height_scale,
):
    vertices, faces, uvs, normals, winds, pivots = [], [], [], [], [], []
    for index, (minimum, maximum) in enumerate(group_bounds):
        center = (minimum + maximum) * 0.5
        horizontal = (
            max(maximum.x - minimum.x, maximum.y - minimum.y)
            * card_width_scale
        )
        height = (maximum.z - minimum.z) * card_height_scale
        half_width = horizontal * 0.5
        half_height = height * 0.5
        z0 = center.z - half_height
        z1 = center.z + half_height
        variant = index % 4
        column = variant % 2
        row = variant // 2
        uv_rect = (column * 0.5, row * 0.5, (column + 1) * 0.5, (row + 1) * 0.5)
        append_double_sided_quad(
            vertices, faces, uvs, normals, winds, pivots,
            (
                (center.x - half_width, center.y, z0),
                (center.x + half_width, center.y, z0),
                (center.x + half_width, center.y, z1),
                (center.x - half_width, center.y, z1),
            ),
            uv_rect,
            Vector((0.0, -1.0, 0.0)),
            (center.x, center.y),
        )
    mesh = bpy.data.meshes.new("TreeHLOD1_FoliageMesh")
    mesh.from_pydata(vertices, [], faces)
    mesh.materials.append(material)
    add_uv(mesh, uvs)
    add_uv2(mesh, pivots)
    add_vertex_data(mesh, normals, winds)
    obj = bpy.data.objects.new("TreeHLOD1_Foliage", mesh)
    bpy.context.scene.collection.objects.link(obj)
    obj["lod_role"] = "tree_group_camera_facing_billboards"
    obj["source_group_count"] = source_group_count
    obj["lod1_group_count"] = len(group_bounds)
    obj["triangle_count"] = len(faces) * 2
    return obj


def create_lod2_foliage(foliage, material):
    minimum, maximum = union_bounds(foliage)
    center = (minimum + maximum) * 0.5
    # render_view() bakes every direction through a square orthographic frame
    # whose side is diameter * 1.10.  Mapping that image onto a crown-aspect
    # rectangle scales the silhouette a second time and visibly flattens LOD2.
    # Reconstruct it on the same square extent used by the bake instead.
    diameter = max(
        maximum.x - minimum.x,
        maximum.y - minimum.y,
        maximum.z - minimum.z,
    )
    half_width = diameter * 0.55
    half_height = diameter * 0.55
    corners = (
        (center.x - half_width, 0.0, center.z - half_height),
        (center.x + half_width, 0.0, center.z - half_height),
        (center.x + half_width, 0.0, center.z + half_height),
        (center.x - half_width, 0.0, center.z + half_height),
    )
    vertices, faces, uvs, normals, winds, pivots = [], [], [], [], [], []
    append_double_sided_quad(
        vertices, faces, uvs, normals, winds, pivots,
        corners, (0.0, 0.0, 1.0, 1.0),
        Vector((0.0, -1.0, 0.0)),
    )
    mesh = bpy.data.meshes.new("TreeHLOD2_ImpostorMesh")
    mesh.from_pydata(vertices, [], faces)
    mesh.materials.append(material)
    add_uv(mesh, uvs)
    add_uv2(mesh, pivots)
    add_vertex_data(mesh, normals, winds)
    obj = bpy.data.objects.new("TreeHLOD2_Impostor", mesh)
    bpy.context.scene.collection.objects.link(obj)
    obj["lod_role"] = "large_tree_8_view_impostor"
    obj["atlas_grid"] = "4x2"
    return obj


def export_selected(filepath, objects):
    bpy.ops.object.select_all(action="DESELECT")
    for obj in objects:
        obj.hide_viewport = False
        obj.hide_render = False
        obj.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    bpy.ops.export_scene.gltf(
        filepath=str(filepath),
        export_format="GLB",
        use_selection=True,
        export_apply=True,
        export_yup=True,
        export_vertex_color="ACTIVE",
        export_materials="EXPORT",
    )


def build_spec(spec, lod1_only=False, lod2_only=False):
    bpy.ops.wm.open_mainfile(filepath=str(spec["source"]))
    foliage = source_foliage(spec)
    trunk = trunk_object()
    expected_groups = spec["group_count"]
    if len(foliage) != expected_groups:
        raise RuntimeError(
            f"{spec['key']}: expected {expected_groups} crown groups, found {len(foliage)}"
        )

    TEMP_DIR.mkdir(parents=True, exist_ok=True)
    clump_atlas = TEXTURE_DIR / f"tree_{spec['key']}_clump_unlit_4var_v1.png"
    tree_atlas = TEXTURE_DIR / f"tree_{spec['key']}_canopy_unlit_8view_v1.png"

    geometry_only = lod1_only or lod2_only
    if not geometry_only:
        source_material = foliage[0].data.materials[0]
        bake_material = make_unlit_leaf_material(source_material)
        assign_bake_material(foliage, bake_material)
        camera = configure_render()

        # Pick four substantially different authored group sizes for LOD1.
        ranked = sorted(
            foliage,
            key=lambda obj: object_world_bounds(obj)[1].x - object_world_bounds(obj)[0].x,
        )
        if len(ranked) == 1:
            representatives = [ranked[0]] * 4
        else:
            representatives = [ranked[min(index, len(ranked)-1)] for index in (2, 10, 19, 27)]
        clump_paths = []
        for index, obj in enumerate(representatives):
            minimum, maximum = object_world_bounds(obj)
            center = (minimum + maximum) * 0.5
            diameter = max(
                maximum.x - minimum.x,
                maximum.y - minimum.y,
                maximum.z - minimum.z,
            )
            path = TEMP_DIR / f"{spec['key']}_clump_{index}.png"
            render_view([obj], center, diameter, index * math.pi * 0.37, path, CLUMP_CELL)
            clump_paths.append(path)
        pack_atlas(clump_paths, 2, 2, clump_atlas)

        minimum, maximum = union_bounds(foliage)
        center = (minimum + maximum) * 0.5
        diameter = max(
            maximum.x - minimum.x,
            maximum.y - minimum.y,
            maximum.z - minimum.z,
        )
        tree_paths = []
        for index in range(8):
            path = TEMP_DIR / f"{spec['key']}_tree_{index}.png"
            render_view(
                foliage,
                center,
                diameter,
                index * math.tau / 8.0,
                path,
                TREE_CELL,
            )
            tree_paths.append(path)
        pack_atlas(tree_paths, 4, 2, tree_atlas)

        # Remove bake-only objects before constructing export scenes.
        bpy.data.objects.remove(camera, do_unlink=True)
        for obj in foliage:
            bpy.data.objects.remove(obj, do_unlink=True)
    elif lod1_only and not clump_atlas.exists():
        raise RuntimeError(f"LOD1-only build needs: {clump_atlas}")
    elif lod2_only and not tree_atlas.exists():
        raise RuntimeError(f"LOD2-only build needs: {tree_atlas}")

    if not lod2_only:
        # Re-open to restore authored bounds and build a clean LOD1 scene.
        bpy.ops.wm.open_mainfile(filepath=str(spec["source"]))
        foliage = source_foliage(spec)
        trunk = trunk_object()
        lod1_group_bounds = aggregate_crown_bounds(
            foliage, spec["lod1_group_count"]
        )
        lod1_material = image_material(f"M_{spec['key']}_TreeHLOD1", clump_atlas)
        lod1_foliage = create_lod1_foliage(
            lod1_group_bounds,
            lod1_material,
            len(foliage),
            spec["lod1_card_width_scale"],
            spec["lod1_card_height_scale"],
        )
        for obj in foliage:
            bpy.data.objects.remove(obj, do_unlink=True)
        lod1_blend = SOURCE_DIR / f"{spec['stem']}_lod1.blend"
        bpy.ops.wm.save_as_mainfile(filepath=str(lod1_blend))
        export_selected(
            MODEL_DIR / f"{spec['stem']}_lod1.glb", [trunk, lod1_foliage]
        )

        if lod1_only:
            print(
                f"TREE_HLOD1_BUILT {spec['key']} groups={len(lod1_group_bounds)} "
                f"asset={MODEL_DIR / (spec['stem'] + '_lod1.glb')}"
            )
            return

    bpy.ops.wm.open_mainfile(filepath=str(spec["source"]))
    foliage = source_foliage(spec)
    trunk = trunk_object()
    lod2_material = image_material(f"M_{spec['key']}_TreeHLOD2", tree_atlas)
    lod2_foliage = create_lod2_foliage(foliage, lod2_material)
    for obj in foliage:
        bpy.data.objects.remove(obj, do_unlink=True)
    lod2_blend = SOURCE_DIR / f"{spec['stem']}_lod2_impostor.blend"
    bpy.ops.wm.save_as_mainfile(filepath=str(lod2_blend))
    export_selected(MODEL_DIR / f"{spec['stem']}_lod2_impostor.glb", [trunk, lod2_foliage])

    print(
        f"TREE_HLOD_BUILT {spec['key']} "
        f"lod1={MODEL_DIR / (spec['stem'] + '_lod1.glb')} "
        f"lod2={MODEL_DIR / (spec['stem'] + '_lod2_impostor.glb')}"
    )


def main():
    # Editable sources are explicitly backed up by the caller when needed.
    bpy.context.preferences.filepaths.save_version = 0
    parser = argparse.ArgumentParser()
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--lod1-only", action="store_true")
    mode.add_argument("--lod2-only", action="store_true")
    parser.add_argument(
        "--spec",
        action="append",
        choices=tuple(spec["key"] for spec in SPECS),
        help="Build only the selected tree key; may be repeated.",
    )
    # Blender leaves its own flags in sys.argv; arguments after `--` belong to
    # this script.
    script_arguments = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    arguments = parser.parse_args(script_arguments)
    MODEL_DIR.mkdir(parents=True, exist_ok=True)
    SOURCE_DIR.mkdir(parents=True, exist_ok=True)
    TEXTURE_DIR.mkdir(parents=True, exist_ok=True)
    selected_specs = [
        spec for spec in SPECS
        if not arguments.spec or spec["key"] in arguments.spec
    ]
    for spec in selected_specs:
        build_spec(spec, arguments.lod1_only, arguments.lod2_only)


if __name__ == "__main__":
    main()
