import bpy
import math
import os
import random
import sys
from mathutils import Quaternion, Vector


ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "assets", "vegetation"))
TEX_DIR = os.path.join(ROOT, "textures")
MODEL_DIR = os.path.join(ROOT, "models")
PREVIEW_DIR = os.path.join(ROOT, "preview")
GRASS_TEX = os.path.join(TEX_DIR, "grass_tuft_straw_minimal_v5.png")
LEAF_TEX = os.path.join(TEX_DIR, "leaf_clusters_witness_sparse_flat_v11.png")

SOURCE_DIR = os.path.join(ROOT, "source")
for path in (MODEL_DIR, SOURCE_DIR):
    os.makedirs(path, exist_ok=True)


def reset_scene():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for datablocks in (bpy.data.meshes, bpy.data.curves, bpy.data.materials, bpy.data.cameras, bpy.data.lights):
        pass


def image_material(name, image_path, roughness=0.9, emission_strength=0.0):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    mat.diffuse_color = (0.35, 0.8, 0.2, 1.0)
    mat.use_backface_culling = False
    try:
        mat.surface_render_method = "DITHERED"
    except Exception:
        try:
            mat.blend_method = "CLIP"
        except Exception:
            pass
    try:
        mat.alpha_threshold = 0.42
    except Exception:
        pass
    nodes = mat.node_tree.nodes
    links = mat.node_tree.links
    for node in list(nodes):
        nodes.remove(node)
    out = nodes.new("ShaderNodeOutputMaterial")
    bsdf = nodes.new("ShaderNodeBsdfPrincipled")
    tex = nodes.new("ShaderNodeTexImage")
    alpha_clip = nodes.new("ShaderNodeMath")
    alpha_clip.operation = "GREATER_THAN"
    alpha_clip.inputs[1].default_value = 0.42
    tex.image = bpy.data.images.load(image_path, check_existing=True)
    tex.interpolation = "Linear"
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Specular IOR Level"].default_value = 0.18
    links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    if emission_strength > 0.0 and "Emission Color" in bsdf.inputs:
        links.new(tex.outputs["Color"], bsdf.inputs["Emission Color"])
        bsdf.inputs["Emission Strength"].default_value = emission_strength
    links.new(tex.outputs["Alpha"], alpha_clip.inputs[0])
    links.new(alpha_clip.outputs[0], bsdf.inputs["Alpha"])
    links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
    return mat


def flat_material(name, color, roughness=0.95):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    mat.diffuse_color = (*color, 1.0)
    nodes = mat.node_tree.nodes
    links = mat.node_tree.links
    for node in list(nodes):
        nodes.remove(node)
    out = nodes.new("ShaderNodeOutputMaterial")
    bsdf = nodes.new("ShaderNodeBsdfPrincipled")
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Specular IOR Level"].default_value = 0.16
    links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
    return mat


def assign_uv(mesh, uv_coords):
    uv_layer = mesh.uv_layers.new(name="UVMap")
    for poly in mesh.polygons:
        for loop_index in poly.loop_indices:
            vertex_index = mesh.loops[loop_index].vertex_index
            uv_layer.data[loop_index].uv = uv_coords[vertex_index]


def add_wind_color(mesh, values):
    attr = mesh.color_attributes.new(name="wind_weight", type="FLOAT_COLOR", domain="POINT")
    for i, value in enumerate(values):
        attr.data[i].color = (value, value, value, 1.0)
    mesh.attributes.active_color = attr


def random_rotation_matrix(rng):
    """Return an unbiased random 3D rotation matrix."""
    u1 = rng.random()
    u2 = rng.random()
    u3 = rng.random()
    root_a = math.sqrt(1.0 - u1)
    root_b = math.sqrt(u1)
    x = root_a * math.sin(math.tau * u2)
    y = root_a * math.cos(math.tau * u2)
    z = root_b * math.sin(math.tau * u3)
    w = root_b * math.cos(math.tau * u3)
    return Quaternion((w, x, y, z)).to_matrix()


def create_grass(material):
    width = 0.92
    height = 1.15
    verts = []
    faces = []
    uvs = []
    wind = []
    # Three 60-degree cards form a star that keeps its apparent density while
    # the camera rotates around it. This is the standard GPU meadow pattern.
    for axis in range(3):
        angle = axis * math.pi / 3.0
        right = Vector((math.cos(angle), math.sin(angle), 0.0)) * (width * 0.5)
        base = len(verts)
        quad = [
            tuple(-right),
            tuple(right),
            tuple(right + Vector((0.0, 0.0, height))),
            tuple(-right + Vector((0.0, 0.0, height))),
        ]
        verts.extend(quad)
        verts.extend(quad)
        front = (base, base + 1, base + 2, base + 3)
        back = (base + 7, base + 6, base + 5, base + 4)
        faces.extend((front, back))
        card_uvs = [(0.0, 0.0), (1.0, 0.0), (1.0, 1.0), (0.0, 1.0)]
        uvs.extend(card_uvs)
        uvs.extend(card_uvs)
        wind.extend([0.0, 0.0, 1.0, 1.0] * 2)
    mesh = bpy.data.meshes.new("GrassCrossMesh")
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    # Grass cards use a shared upward-biased field instead of plane normals.
    # Both windings are present, so back-face culling remains enabled in-engine.
    mesh.normals_split_custom_set_from_vertices([(0.0, 0.0, 1.0)] * len(verts))
    for polygon in mesh.polygons:
        polygon.use_smooth = True
    mesh.materials.append(material)
    assign_uv(mesh, uvs)
    add_wind_color(mesh, wind)
    obj = bpy.data.objects.new("Grass_Star_3Card", mesh)
    bpy.context.collection.objects.link(obj)
    obj["asset_type"] = "grass_star_3card"
    obj["recommended_alpha_cutoff"] = 0.42
    obj["wind_vertex_color"] = "COLOR_0.r"
    return obj


def tapered_segment(name, start, end, radius_start, radius_end, material, vertices=7):
    direction = end - start
    length = direction.length
    bpy.ops.mesh.primitive_cone_add(
        vertices=vertices,
        radius1=radius_start,
        radius2=radius_end,
        depth=length,
        end_fill_type="NGON",
        location=(start + end) * 0.5,
    )
    obj = bpy.context.object
    obj.name = name
    obj.rotation_mode = "QUATERNION"
    obj.rotation_quaternion = Vector((0.0, 0.0, 1.0)).rotation_difference(direction.normalized())
    obj.data.materials.append(material)
    return obj


def join_objects(objects, name):
    bpy.ops.object.select_all(action="DESELECT")
    for obj in objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    bpy.ops.object.join()
    objects[0].name = name
    objects[0].data.name = name + "Mesh"
    return objects[0]


def refine_v8_crown(lobes):
    """Widen the v8 silhouette without replacing its layered crown volume."""
    # Upper growth directions are only a gentle contour influence. The v8
    # layer heights, inner fill and all 240 card-pair cells stay in place.
    directions = [-2.78, -1.64, -0.38, 0.63, 1.86, 2.63]
    refined = []
    for center, scale in lobes:
        angle = math.atan2(center.y, center.x)
        radial = math.hypot(center.x, center.y)
        nearest = max(math.cos(angle - direction) for direction in directions)
        influence = max(0.0, nearest) ** 7
        perimeter = min(1.0, radial / 2.0)
        position = center.copy()
        position.x *= 1.10 + 0.09 * influence * perimeter
        position.y *= 1.04 + 0.06 * influence * perimeter
        position.z += 0.09 * perimeter * math.sin(3.0 * angle + 0.45)
        refined.append((position, scale))
    return refined


def create_tree(trunk_material, leaf_material, crown_layout="layered"):
    # Deliberately plain: one straight, slender trunk and no visible branch cage.
    trunk = tapered_segment(
        "Tree_Trunk_Straight",
        Vector((0.0, 0.0, 0.0)), Vector((0.0, 0.0, 3.35)),
        0.19, 0.105, trunk_material, 10,
    )
    trunk["asset_type"] = "stylized_single_trunk"

    rng = random.Random(20260914)
    # Two hundred forty crown cells, two crossed cards each. The v11 atlas has
    # Witness-like negative space, so crown continuity comes from overlapping
    # many broad cards rather than packing each texture with opaque leaves.
    # Every sheet has
    # front and back geometry so the engine can use real back-face culling.
    lobes = []
    layer_specs = [
        (2.85, 2.45, 2.00, 40, 1.12),
        (3.35, 2.82, 2.25, 48, 1.10),
        (3.90, 2.92, 2.34, 48, 1.07),
        (4.45, 2.65, 2.15, 32, 1.02),
        (5.00, 2.12, 1.76, 16, 0.96),
        (5.45, 1.30, 1.08, 8, 0.88),
    ]
    for z, radius_x, radius_y, count, scale in layer_specs:
        phase = rng.uniform(0.0, math.tau)
        for i in range(count):
            angle = phase + (math.tau * i / count) + rng.uniform(-0.16, 0.16)
            radial = rng.uniform(0.48, 0.94) if count > 4 else rng.uniform(0.18, 0.72)
            center = Vector((
                math.cos(angle) * radius_x * radial,
                math.sin(angle) * radius_y * radial,
                z + rng.uniform(-0.18, 0.18),
            ))
            lobes.append((center, scale * rng.uniform(0.92, 1.10)))
    # The silhouette layers above deliberately favour the crown perimeter. Add
    # a separate inner volume so a top-down camera never looks through a hollow
    # ring around the trunk. These are full 3D crossed-card groups as well, not
    # horizontal patches inserted only for one camera angle.
    inner_specs = [
        (3.05, 0.82, 10, 1.04),
        (3.55, 1.02, 14, 1.03),
        (4.10, 1.08, 14, 0.99),
        (4.65, 0.92, 10, 0.92),
    ]
    for z, radius, count, scale in inner_specs:
        for _index in range(count):
            angle = rng.uniform(0.0, math.tau)
            radial = math.sqrt(rng.random()) * radius
            center = Vector((
                math.cos(angle) * radial,
                math.sin(angle) * radial * 0.84,
                z + rng.uniform(-0.22, 0.22),
            ))
            lobes.append((center, scale * rng.uniform(0.92, 1.08)))
    if crown_layout == "branch_guided":
        # Preserve v8 cards, texture, inner volume, orientation, trunk and wind.
        lobes = refine_v8_crown(lobes)
    elif crown_layout != "layered":
        raise ValueError(f"Unknown crown layout: {crown_layout}")
    atlas_regions = [
        (0.02, 0.52, 0.48, 0.98),
        (0.52, 0.52, 0.98, 0.98),
        (0.02, 0.02, 0.48, 0.48),
        (0.52, 0.02, 0.98, 0.48),
    ]
    region_aspects = [1.42, 0.82, 1.08, 1.18]
    verts, faces, uvs, wind, crown_normals = [], [], [], [], []
    card_index = 0
    for lobe_index, (lobe_center, lobe_scale) in enumerate(lobes):
        # Each crown cell is one crossed-card cluster. The two cards remain
        # perpendicular locally, then the whole pair receives an independent,
        # unrestricted 3D rotation. No shared world-up direction remains.
        group_rotation = random_rotation_matrix(rng)
        group_center = lobe_center + Vector((
            rng.uniform(-0.10, 0.10),
            rng.uniform(-0.10, 0.10),
            rng.uniform(-0.08, 0.08),
        ))
        group_up = (group_rotation @ Vector((0.0, 0.0, 1.0))).normalized()
        for pair_index in range(2):
            region_index = (lobe_index * 2 + pair_index) % 4
            center = group_center
            # Broad cards are intentional: v11 keeps only about 24% alpha
            # coverage, so larger sheets overlap in 3D without reading as
            # solid rectangular clumps.
            # The refined tree keeps the v8 card count and sparse atlas, but
            # gives each sheet more reach so adjacent foliage overlaps into
            # broader, readable masses at gameplay distance.
            card_extent = 1.25 if crown_layout == "branch_guided" else 1.0
            height = rng.uniform(0.72, 0.94) * lobe_scale * card_extent
            width = height * region_aspects[region_index] * rng.uniform(0.95, 1.10)
            local_right = Vector((1.0, 0.0, 0.0)) if pair_index == 0 else Vector((0.0, 1.0, 0.0))
            right = (group_rotation @ local_right).normalized()
            half_r = right * (width * 0.5)
            half_u = group_up * (height * 0.5)
            base = len(verts)
            card_vertices = [
                center - half_r - half_u,
                center + half_r - half_u,
                center + half_r + half_u,
                center - half_r + half_u,
            ]
            verts.extend(tuple(vertex) for vertex in card_vertices)
            verts.extend(tuple(vertex) for vertex in card_vertices)
            # The cards carry the normal field of one broad ellipsoidal crown,
            # not their own plane normals. Lighting therefore describes crown
            # volume and no longer reveals each crossed sheet.
            card_normals = []
            for vertex in card_vertices:
                normal = Vector((
                    vertex.x / (3.15 * 3.15),
                    vertex.y / (2.58 * 2.58),
                    (vertex.z - 4.08) / (1.78 * 1.78),
                ))
                if normal.length_squared < 0.0001:
                    normal = Vector((0.0, 0.0, 1.0))
                card_normals.append(tuple(normal.normalized()))
            crown_normals.extend(card_normals)
            crown_normals.extend(card_normals)
            front = (base, base + 1, base + 2, base + 3)
            back = (base + 7, base + 6, base + 5, base + 4)
            faces.extend((front, back))
            u0, v0, u1, v1 = atlas_regions[region_index]
            card_uvs = [(u0, v0), (u1, v0), (u1, v1), (u0, v1)]
            uvs.extend(card_uvs)
            uvs.extend(card_uvs)
            weight = min(1.0, max(0.58, (center.z - 2.35) / 3.2))
            wind.extend([weight] * 8)
            card_index += 1
    mesh = bpy.data.meshes.new("TreeFoliageCardsMesh")
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    mesh.normals_split_custom_set_from_vertices(crown_normals)
    for polygon in mesh.polygons:
        polygon.use_smooth = True
    mesh.materials.append(leaf_material)
    assign_uv(mesh, uvs)
    add_wind_color(mesh, wind)
    foliage = bpy.data.objects.new("Tree_Foliage_480Cards_BroadSparse", mesh)
    bpy.context.collection.objects.link(foliage)
    foliage["asset_type"] = "foliage_card_cluster"
    foliage["card_count"] = card_index
    foliage["recommended_alpha_cutoff"] = 0.42
    foliage["wind_vertex_color"] = "COLOR_0.r"
    return trunk, foliage


def export_selected(filepath, objects):
    bpy.ops.object.select_all(action="DESELECT")
    for obj in objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    bpy.ops.export_scene.gltf(
        filepath=filepath,
        export_format="GLB",
        use_selection=True,
        export_apply=True,
        export_yup=True,
        export_vertex_color="ACTIVE",
        export_materials="EXPORT",
    )


def make_preview(grass, trunk, foliage):
    grass.location = (-3.0, 0.1, 0.0)
    grass.scale = (1.35, 1.35, 1.35)
    trunk.location = (0.8, 0.0, 0.0)
    foliage.location = (0.8, 0.0, 0.0)

    ground_mat = flat_material("PreviewGround", (0.18, 0.42, 0.16), 1.0)
    bpy.ops.mesh.primitive_plane_add(size=14, location=(0.0, 0.0, -0.02))
    ground = bpy.context.object
    ground.name = "Preview_Ground"
    ground.data.materials.append(ground_mat)

    bpy.ops.object.light_add(type="AREA", location=(-3.5, -4.0, 7.0))
    key = bpy.context.object
    key.name = "Preview_Key"
    key.data.energy = 1100
    key.data.shape = "DISK"
    key.data.size = 5.0

    bpy.ops.object.light_add(type="AREA", location=(4.0, 2.0, 4.5))
    fill = bpy.context.object
    fill.name = "Preview_Fill"
    fill.data.energy = 500
    fill.data.color = (0.65, 0.82, 1.0)
    fill.data.size = 4.0

    bpy.ops.object.camera_add(location=(10.8, -14.8, 7.4))
    camera = bpy.context.object
    camera.name = "Preview_Camera"
    target = Vector((0.0, 0.0, 2.85))
    camera.rotation_euler = (target - camera.location).to_track_quat("-Z", "Y").to_euler()
    camera.data.lens = 58
    bpy.context.scene.camera = camera

    world = bpy.context.scene.world
    world.color = (0.04, 0.06, 0.08)
    world.use_nodes = True
    bg = world.node_tree.nodes.get("Background")
    bg.inputs["Color"].default_value = (0.11, 0.18, 0.24, 1.0)
    bg.inputs["Strength"].default_value = 0.55

    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = 960
    scene.render.resolution_y = 720
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.filepath = os.path.join(PREVIEW_DIR, "vegetation_assets_preview_v8.png")
    scene.render.film_transparent = False
    scene.view_settings.look = "AgX - Medium High Contrast"
    bpy.ops.render.render(write_still=True)


reset_scene()
leaf_mat = image_material("M_Leaves_FlatMuted_AlphaClip", LEAF_TEX, emission_strength=0.0)
trunk_mat = flat_material("M_Trunk_Stylized", (0.28, 0.13, 0.055))
if "--tree-refined-v10" in sys.argv:
    trunk, foliage = create_tree(trunk_mat, leaf_mat, crown_layout="branch_guided")
    model_path = os.path.join(MODEL_DIR, "tree_foliage_480card_v10_branch_guided.glb")
    export_selected(model_path, [trunk, foliage])
    source_path = os.path.join(SOURCE_DIR, "vegetation_source_v10_branch_guided.blend")
    bpy.ops.wm.save_as_mainfile(filepath=source_path)
    print(f"BRANCH_GUIDED_TREE_BUILD_COMPLETE cards={foliage['card_count']}")
    print(model_path)
    print(source_path)
else:
    os.makedirs(PREVIEW_DIR, exist_ok=True)
    grass_mat = image_material("M_Grass_Fresh_AlphaClip", GRASS_TEX)
    grass = create_grass(grass_mat)
    trunk, foliage = create_tree(trunk_mat, leaf_mat)
    export_selected(os.path.join(MODEL_DIR, "grass_star_3card_v6.glb"), [grass])
    export_selected(os.path.join(MODEL_DIR, "tree_foliage_480card_v8.glb"), [trunk, foliage])
    make_preview(grass, trunk, foliage)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(SOURCE_DIR, "vegetation_source_v8.blend"))
    print("VEGETATION_BUILD_COMPLETE")
    print(os.path.join(MODEL_DIR, "grass_star_3card_v6.glb"))
    print(os.path.join(MODEL_DIR, "tree_foliage_480card_v8.glb"))
    print(os.path.join(PREVIEW_DIR, "vegetation_assets_preview_v8.png"))
