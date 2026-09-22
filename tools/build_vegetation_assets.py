import bpy
import math
import os
import random
import sys
from mathutils import Euler, Quaternion, Vector


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


def encode_octahedral(normal):
    """Pack a unit vector into two 0..1 channels for Godot vertex COLOR.gb."""
    n = normal.normalized()
    denominator = abs(n.x) + abs(n.y) + abs(n.z)
    if denominator < 0.00001:
        return (0.5, 0.5)
    x = n.x / denominator
    y = n.y / denominator
    if n.z < 0.0:
        old_x = x
        x = (1.0 - abs(y)) * (1.0 if old_x >= 0.0 else -1.0)
        y = (1.0 - abs(old_x)) * (1.0 if y >= 0.0 else -1.0)
    return (x * 0.5 + 0.5, y * 0.5 + 0.5)


def add_foliage_vertex_data(mesh, wind_values, plane_normals):
    """R stores wind weight; G/B store the true card plane normal."""
    attr = mesh.color_attributes.new(name="foliage_data", type="FLOAT_COLOR", domain="POINT")
    for index, (wind_value, plane_normal) in enumerate(zip(wind_values, plane_normals)):
        encoded_x, encoded_y = encode_octahedral(plane_normal)
        attr.data[index].color = (wind_value, encoded_x, encoded_y, 1.0)
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


def create_stylized_trunk(name, height, material, size="small", seed=20260928):
    """Create a restrained low-poly trunk from several subtly varied rings.

    The centre line remains visually straight. Ring offsets, ellipse ratios and
    rotations only keep the silhouette from reading as a perfect cone; they do
    not turn the trunk into a decorative crooked branch sculpture.
    """
    if size == "small":
        sides = 10
        rings = [
            (0.00, 0.145),
            (0.12, 0.132),
            (0.70, 0.118),
            (1.42, 0.105),
            (2.18, 0.089),
            (height, 0.074),
        ]
        max_offset = 0.010
        ellipse_range = (0.965, 1.035)
    elif size == "large":
        sides = 12
        rings = [
            (0.00, 0.360),
            (0.16, 0.326),
            (0.72, 0.300),
            (1.48, 0.274),
            (2.42, 0.238),
            (3.46, 0.202),
            (4.62, 0.160),
            (height, 0.118),
        ]
        max_offset = 0.018
        ellipse_range = (0.955, 1.045)
    else:
        raise ValueError(f"Unknown stylized trunk size: {size}")

    rng = random.Random(seed)
    vertices = []
    faces = []
    for ring_index, (z, radius) in enumerate(rings):
        height_ratio = z / max(height, 0.001)
        # Both ends remain centred. Intermediate offsets are small enough that
        # the trunk still reads as one calm, upright stroke at gameplay scale.
        offset_weight = math.sin(height_ratio * math.pi)
        center = Vector((
            rng.uniform(-max_offset, max_offset) * offset_weight,
            rng.uniform(-max_offset, max_offset) * offset_weight,
            z,
        ))
        ellipse = rng.uniform(*ellipse_range)
        rotation = rng.uniform(-0.10, 0.10) + ring_index * 0.035
        for side in range(sides):
            angle = math.tau * side / sides + rotation
            vertices.append(tuple(center + Vector((
                math.cos(angle) * radius * ellipse,
                math.sin(angle) * radius / ellipse,
                0.0,
            ))))

    for ring_index in range(len(rings) - 1):
        lower = ring_index * sides
        upper = (ring_index + 1) * sides
        for side in range(sides):
            next_side = (side + 1) % sides
            faces.append((
                lower + side,
                lower + next_side,
                upper + next_side,
                upper + side,
            ))
    faces.append(tuple(reversed(range(sides))))
    top_start = (len(rings) - 1) * sides
    faces.append(tuple(top_start + side for side in range(sides)))

    mesh = bpy.data.meshes.new(name + "Mesh")
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    mesh.materials.append(material)
    # Smooth the vertical surface while keeping both end caps planar.
    for polygon in mesh.polygons[:-2]:
        polygon.use_smooth = True

    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    obj["asset_type"] = f"stylized_{size}_trunk"
    obj["ring_count"] = len(rings)
    obj["side_count"] = sides
    obj["base_radius"] = rings[0][1]
    obj["top_radius"] = rings[-1][1]
    obj["height"] = height
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


def create_tree(
    trunk_material, leaf_material, crown_layout="layered", use_refined_trunk=False
):
    # Deliberately plain: one straight, slender trunk and no visible branch cage.
    if use_refined_trunk:
        trunk = create_stylized_trunk(
            "Tree_Trunk_Stylized",
            3.25,
            trunk_material,
            size="small",
            seed=20260928,
        )
    else:
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
    verts, faces, uvs, wind, crown_normals, plane_normals = [], [], [], [], [], []
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
            plane_normal = right.cross(group_up).normalized()
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
            plane_normals.extend([plane_normal] * 8)
            card_index += 1
    mesh = bpy.data.meshes.new("TreeFoliageCardsMesh")
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    mesh.normals_split_custom_set_from_vertices(crown_normals)
    for polygon in mesh.polygons:
        polygon.use_smooth = True
    mesh.materials.append(leaf_material)
    assign_uv(mesh, uvs)
    add_foliage_vertex_data(mesh, wind, plane_normals)
    foliage = bpy.data.objects.new("Tree_Foliage_480Cards_BroadSparse", mesh)
    bpy.context.collection.objects.link(foliage)
    foliage["asset_type"] = "foliage_card_cluster"
    foliage["card_count"] = card_index
    foliage["recommended_alpha_cutoff"] = 0.42
    foliage["wind_vertex_color"] = "COLOR_0.r"
    foliage["view_angle_data"] = "COLOR_0.gb_octahedral_plane_normal"
    return trunk, foliage


def create_camphor_tree(trunk_material, leaf_material, shadow_material, dense_v2=False):
    """Build a 20 m, thirty-clump broad-canopy tree as a separate species test."""
    trunk = tapered_segment(
        "Camphor_Trunk_Straight",
        Vector((0.0, 0.0, 0.0)), Vector((0.0, 0.0, 10.2)),
        0.58, 0.16, trunk_material, 12,
    )
    trunk["asset_type"] = "stylized_large_single_trunk"

    rng = random.Random(20260921)
    clumps = []
    # Thirty overlapping ellipsoids form the readable mid-scale crown. The
    # lower rings are broad; the upper rings contract without becoming a cone.
    layer_specs = [
        (8.2, 5.7, 4.4, 8, (2.55, 2.05, 2.15)),
        (11.2, 7.0, 5.2, 9, (2.85, 2.25, 2.35)),
        (14.3, 6.2, 4.8, 7, (2.75, 2.20, 2.45)),
        (17.0, 4.0, 3.2, 4, (2.45, 2.00, 2.35)),
    ]
    for layer_index, (z, radius_x, radius_y, count, base_radii) in enumerate(layer_specs):
        phase = rng.uniform(0.0, math.tau)
        for index in range(count):
            angle = phase + math.tau * index / count + rng.uniform(-0.20, 0.20)
            radial = rng.uniform(0.70, 1.0)
            center = Vector((
                math.cos(angle) * radius_x * radial + rng.uniform(-0.35, 0.35),
                math.sin(angle) * radius_y * radial + rng.uniform(-0.30, 0.30),
                z + rng.uniform(-0.45, 0.45),
            ))
            radii = Vector((
                base_radii[0] * rng.uniform(0.86, 1.14),
                base_radii[1] * rng.uniform(0.86, 1.14),
                base_radii[2] * rng.uniform(0.88, 1.12),
            ))
            yaw = angle + rng.uniform(-0.55, 0.55)
            tilt_axis = Vector((math.cos(yaw), math.sin(yaw), 0.0))
            rotation = (
                Quaternion(Vector((0.0, 0.0, 1.0)), yaw).to_matrix()
                @ Quaternion(tilt_axis, rng.uniform(-0.16, 0.16)).to_matrix()
            )
            clumps.append((center, radii, rotation))
    # Two inner clumps prevent a hollow crown while preserving readable valleys.
    clumps.extend([
        (Vector((-0.8, 0.4, 11.6)), Vector((3.15, 2.55, 2.55)), random_rotation_matrix(rng)),
        (Vector((0.9, -0.5, 14.8)), Vector((2.90, 2.35, 2.65)), random_rotation_matrix(rng)),
    ])
    assert len(clumps) == 30

    atlas_regions = [
        (0.02, 0.52, 0.48, 0.98),
        (0.52, 0.52, 0.98, 0.98),
        (0.02, 0.02, 0.48, 0.48),
        (0.52, 0.02, 0.98, 0.48),
    ]
    region_aspects = [1.42, 0.82, 1.08, 1.18]
    verts, faces, uvs = [], [], []
    wind, plane_normals, crown_normals = [], [], []
    card_count = 0
    # V1 inherited the card scale of the six-metre tree: eighty small cards
    # could not fill an ellipsoid roughly five metres across. V2 treats every
    # ellipsoid as a foliage asset of its own. Most cells sit near its shell to
    # keep the silhouette continuous, while the rest prevent a hollow centre.
    cells_per_clump = 110 if dense_v2 else 40
    for clump_index, (clump_center, clump_radii, clump_rotation) in enumerate(clumps):
        for cell_index in range(cells_per_clump):
            azimuth = rng.uniform(0.0, math.tau)
            vertical = rng.uniform(-1.0, 1.0)
            horizontal = math.sqrt(max(0.0, 1.0 - vertical * vertical))
            direction = Vector((
                math.cos(azimuth) * horizontal,
                math.sin(azimuth) * horizontal,
                vertical,
            ))
            if dense_v2:
                if rng.random() < 0.70:
                    radial = 0.56 + 0.38 * (rng.random() ** 0.42)
                else:
                    radial = 0.12 + 0.58 * (rng.random() ** 0.72)
            else:
                # Mix interior fill with a mild surface bias for fluffy silhouettes.
                radial = 0.20 + 0.80 * (rng.random() ** 0.48)
            local_center = Vector((
                direction.x * clump_radii.x * radial,
                direction.y * clump_radii.y * radial,
                direction.z * clump_radii.z * radial,
            ))
            center = clump_center + clump_rotation @ local_center
            card_rotation = random_rotation_matrix(rng)
            card_up = (card_rotation @ Vector((0.0, 0.0, 1.0))).normalized()
            for pair_index in range(2):
                region_index = (clump_index + cell_index * 2 + pair_index) % 4
                local_right = (
                    Vector((1.0, 0.0, 0.0)) if pair_index == 0
                    else Vector((0.0, 1.0, 0.0))
                )
                card_right = (card_rotation @ local_right).normalized()
                plane_normal = card_right.cross(card_up).normalized()
                height = rng.uniform(1.38, 1.82) if dense_v2 else rng.uniform(0.92, 1.30)
                width = height * region_aspects[region_index] * rng.uniform(0.94, 1.12)
                half_r = card_right * width * 0.5
                half_u = card_up * height * 0.5
                card_vertices = [
                    center - half_r - half_u,
                    center + half_r - half_u,
                    center + half_r + half_u,
                    center - half_r + half_u,
                ]
                base = len(verts)
                verts.extend(tuple(vertex) for vertex in card_vertices)
                faces.append((base, base + 1, base + 2, base + 3))
                u0, v0, u1, v1 = atlas_regions[region_index]
                uvs.extend([(u0, v0), (u1, v0), (u1, v1), (u0, v1)])
                for vertex in card_vertices:
                    local_vertex = clump_rotation.transposed() @ (vertex - clump_center)
                    normal_local = Vector((
                        local_vertex.x / max(0.001, clump_radii.x * clump_radii.x),
                        local_vertex.y / max(0.001, clump_radii.y * clump_radii.y),
                        local_vertex.z / max(0.001, clump_radii.z * clump_radii.z),
                    ))
                    if normal_local.length_squared < 0.0001:
                        normal_local = direction
                    crown_normals.append(tuple((clump_rotation @ normal_local.normalized()).normalized()))
                    plane_normals.append(plane_normal)
                    wind.append(min(1.0, max(0.35, (vertex.z - 5.0) / 14.0)))
                card_count += 1

    mesh = bpy.data.meshes.new("CamphorFoliageCardsMesh")
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    mesh.normals_split_custom_set_from_vertices(crown_normals)
    for polygon in mesh.polygons:
        polygon.use_smooth = True
    mesh.materials.append(leaf_material)
    assign_uv(mesh, uvs)
    add_foliage_vertex_data(mesh, wind, plane_normals)
    foliage = bpy.data.objects.new(
        "Camphor_Foliage_30Clumps_6600Cards"
        if dense_v2 else "Camphor_Foliage_30Clumps_2400Cards",
        mesh,
    )
    bpy.context.collection.objects.link(foliage)
    foliage["asset_type"] = "foliage_30_ellipsoid_clumps"
    foliage["clump_count"] = len(clumps)
    foliage["card_count"] = card_count
    foliage["view_angle_data"] = "COLOR_0.gb_octahedral_plane_normal"
    foliage["wind_vertex_color"] = "COLOR_0.r"

    proxy_verts, proxy_faces = [], []
    octahedron_faces = [
        (0, 2, 4), (0, 4, 3), (0, 3, 5), (0, 5, 2),
        (1, 4, 2), (1, 3, 4), (1, 5, 3), (1, 2, 5),
    ]
    for clump_center, clump_radii, clump_rotation in clumps:
        local_points = [
            Vector((0.0, 0.0, clump_radii.z)),
            Vector((0.0, 0.0, -clump_radii.z)),
            Vector((clump_radii.x, 0.0, 0.0)),
            Vector((-clump_radii.x, 0.0, 0.0)),
            Vector((0.0, clump_radii.y, 0.0)),
            Vector((0.0, -clump_radii.y, 0.0)),
        ]
        base = len(proxy_verts)
        proxy_verts.extend(tuple(clump_center + clump_rotation @ point) for point in local_points)
        proxy_faces.extend(tuple(base + index for index in face) for face in octahedron_faces)
    proxy_mesh = bpy.data.meshes.new("CamphorShadowProxyMesh")
    proxy_mesh.from_pydata(proxy_verts, [], proxy_faces)
    proxy_mesh.update()
    proxy_mesh.materials.append(shadow_material)
    shadow_proxy = bpy.data.objects.new("Camphor_Shadow_Proxies_30Clumps", proxy_mesh)
    bpy.context.collection.objects.link(shadow_proxy)
    shadow_proxy["asset_type"] = "clump_shadow_proxies"
    shadow_proxy["clump_count"] = len(clumps)
    return trunk, foliage, shadow_proxy


def create_camphor_from_old_crowns(
    trunk_material, leaf_material, compact=False, dense30=False,
    round30=False, broad30=False, upright_asymmetric30=False,
    use_refined_trunk=False
):
    """Build a large tree from reduced copies of the accepted v10 crown."""
    old_trunk, source_crown = create_tree(
        trunk_material, leaf_material, crown_layout="branch_guided"
    )
    bpy.data.objects.remove(old_trunk, do_unlink=True)

    trunk_height = 6.2 if upright_asymmetric30 else (6.4 if broad30 else (
        6.6 if round30 else (6.8 if dense30 else (7.3 if compact else 10.4))
    ))
    if use_refined_trunk:
        trunk_seed = 20260930 if upright_asymmetric30 else 20260929
        trunk = create_stylized_trunk(
            "Camphor_Trunk_Stylized",
            trunk_height,
            trunk_material,
            size="large",
            seed=trunk_seed,
        )
    else:
        trunk = tapered_segment(
            "Camphor_Trunk_Straight",
            Vector((0.0, 0.0, 0.0)), Vector((0.0, 0.0, trunk_height)),
            0.46, 0.14, trunk_material, 12,
        )
        trunk["asset_type"] = "stylized_large_single_trunk"

    # The coordinates describe crown-group centres. Each group is the complete
    # accepted 480-card v10 crown rather than a small procedural ellipsoid.
    overlap_spheres = []
    if broad30:
        # Keep thirty groups, but redistribute them instead of adding another
        # layer. Five lower groups wrap the trunk, while large anchors and
        # smaller bridges break the former equal-size, horizontal-row rhythm.
        # radius, azimuth degrees, height, size bias. Using polar coordinates
        # makes the horizontal mass near-circular by construction; the uneven
        # angles and heights keep it from reading as several perfect rings.
        placements = [
            (2.0, 18.0, 4.4, 1.12), (2.2, 92.0, 4.7, 0.98),
            (2.3, 166.0, 4.8, 1.04), (2.0, 238.0, 4.3, 0.92),
            (2.2, 309.0, 4.9, 1.03),
            (4.1, 4.0, 6.2, 1.00), (4.3, 44.0, 6.6, 1.14),
            (4.0, 84.0, 6.3, 0.90), (4.5, 126.0, 6.5, 1.18),
            (4.2, 166.0, 6.1, 0.96), (4.4, 207.0, 6.7, 1.08),
            (4.0, 248.0, 6.3, 0.94), (4.5, 287.0, 6.6, 1.11),
            (4.2, 329.0, 6.2, 0.88),
            (4.2, 22.0, 7.9, 1.07), (3.7, 63.0, 8.4, 0.91),
            (4.5, 104.0, 7.8, 1.20), (3.9, 147.0, 8.2, 0.87),
            (4.3, 187.0, 7.7, 1.13), (3.6, 229.0, 8.5, 0.90),
            (4.5, 269.0, 7.9, 1.18), (3.8, 311.0, 8.3, 0.94),
            (2.6, 350.0, 8.7, 1.05),
            (3.1, 35.0, 9.5, 0.92), (3.3, 106.0, 9.8, 1.08),
            (3.0, 178.0, 9.4, 0.95), (3.2, 252.0, 9.7, 1.11),
            (2.7, 320.0, 10.0, 1.02),
            (1.4, 75.0, 10.8, 0.94), (1.2, 248.0, 11.2, 1.05),
        ]
        rng = random.Random(20260926)
        crown_specs = []
        source_dimensions = Vector((7.70, 5.77, 3.80))
        crown_bounds = []
        for radius, angle_degrees, z, size_bias in placements:
            angle = math.radians(angle_degrees)
            x = math.cos(angle) * radius
            y = math.sin(angle) * radius
            radius_x = rng.uniform(2.05, 2.45) * size_bias
            radii = Vector((
                radius_x,
                radius_x * rng.uniform(0.76, 0.96),
                radius_x * rng.uniform(0.62, 0.80),
            ))
            scale_vector = Vector((
                radii.x * 2.0 / source_dimensions.x,
                radii.y * 2.0 / source_dimensions.y,
                radii.z * 2.0 / source_dimensions.z,
            ))
            center = Vector((
                x + rng.uniform(-0.15, 0.15),
                y + rng.uniform(-0.15, 0.15),
                z + rng.uniform(-0.12, 0.12),
            ))
            # Gentle pitch and roll vary the old-crown silhouette without
            # turning the groups into the rejected chaotic small-ball tree.
            rotation = Vector((
                math.radians(rng.uniform(-9.0, 9.0)),
                math.radians(rng.uniform(-11.0, 11.0)),
                rng.uniform(-math.pi, math.pi),
            ))
            crown_specs.append((center, scale_vector, rotation))
            rotation_matrix = Euler(tuple(rotation), "XYZ").to_matrix()
            extent_x = math.sqrt(sum(
                (rotation_matrix[0][axis] * radii[axis]) ** 2
                for axis in range(3)
            ))
            extent_y = math.sqrt(sum(
                (rotation_matrix[1][axis] * radii[axis]) ** 2
                for axis in range(3)
            ))
            extent_z = math.sqrt(sum(
                (rotation_matrix[2][axis] * radii[axis]) ** 2
                for axis in range(3)
            ))
            crown_bounds.append((
                center.x - extent_x, center.x + extent_x,
                center.y - extent_y, center.y + extent_y,
                center.z - extent_z, center.z + extent_z,
            ))
            effective_radius = (radii.x * radii.y * radii.z) ** (1.0 / 3.0)
            overlap_spheres.append((center, effective_radius))
        assert len(crown_specs) == 30
        span_x = max(bound[1] for bound in crown_bounds) - min(
            bound[0] for bound in crown_bounds
        )
        span_y = max(bound[3] for bound in crown_bounds) - min(
            bound[2] for bound in crown_bounds
        )
        crown_min_z = min(bound[4] for bound in crown_bounds)
        crown_max_z = max(bound[5] for bound in crown_bounds)
        crown_vertical_span = crown_max_z - crown_min_z
        horizontal_aspect = max(span_x, span_y) / min(span_x, span_y)
        crown_breadth_ratio = min(span_x, span_y) / crown_vertical_span
        assert horizontal_aspect <= 1.12, (
            f"Broad crown is not horizontally round: {span_x:.2f} x {span_y:.2f}"
        )
        assert crown_breadth_ratio >= 1.18, (
            "Broad crown is too tall for an isolated spreading tree: "
            f"horizontal={min(span_x, span_y):.2f}, vertical={crown_vertical_span:.2f}"
        )
    elif upright_asymmetric30:
        # Thirty old-crown groups form one irregular upright oval rather than
        # five level shelves. The low skirt hides the trunk early, unequal
        # shoulders create a readable gesture, and the crown drifts slightly
        # toward its offset apex without becoming a leaning tree.
        # radius, azimuth degrees, height, size bias.
        placements = [
            (2.1, 15.0, 4.10, 0.98), (2.4, 86.0, 4.50, 0.88),
            (2.2, 158.0, 4.25, 1.04), (2.3, 231.0, 4.70, 0.86),
            (2.0, 307.0, 4.35, 0.94),
            (4.0, 2.0, 5.90, 1.10), (3.7, 43.0, 6.30, 0.98),
            (4.0, 88.0, 5.70, 1.16), (3.6, 132.0, 6.80, 0.90),
            (4.1, 176.0, 6.10, 1.06), (3.8, 221.0, 7.00, 1.13),
            (4.0, 266.0, 6.50, 0.92), (3.6, 318.0, 7.30, 1.00),
            (3.7, 20.0, 8.00, 1.18), (3.3, 62.0, 8.80, 0.88),
            (3.8, 105.0, 7.90, 1.08), (3.4, 151.0, 9.20, 0.98),
            (3.9, 196.0, 8.40, 1.14), (3.2, 239.0, 9.60, 0.90),
            (3.8, 283.0, 8.90, 1.05), (3.1, 331.0, 10.00, 0.94),
            (3.0, 8.0, 10.60, 1.06), (2.8, 68.0, 11.20, 0.93),
            (3.1, 126.0, 10.80, 1.12), (2.6, 185.0, 11.80, 0.90),
            (2.9, 246.0, 11.40, 1.00), (2.5, 310.0, 12.10, 0.96),
            (1.5, 35.0, 13.00, 0.92), (1.6, 165.0, 13.40, 1.02),
            (0.8, 285.0, 14.10, 0.82),
        ]
        rng = random.Random(20260927)
        crown_specs = []
        source_dimensions = Vector((7.70, 5.77, 3.80))
        crown_bounds = []
        for radius, angle_degrees, z, size_bias in placements:
            angle = math.radians(angle_degrees)
            # A restrained height-dependent drift offsets the crown peak and
            # breaks bilateral symmetry without making the trunk look bent.
            height_drift = max(0.0, z - 8.0) / 6.1
            center = Vector((
                math.cos(angle) * radius + height_drift * 0.42
                    + rng.uniform(-0.16, 0.16),
                math.sin(angle) * radius - height_drift * 0.24
                    + rng.uniform(-0.16, 0.16),
                z + rng.uniform(-0.13, 0.13),
            ))
            base_radius = rng.uniform(1.90, 2.35) * size_bias
            radii = Vector((
                base_radius * rng.uniform(0.92, 1.08),
                base_radius * rng.uniform(0.90, 1.08),
                base_radius * rng.uniform(0.78, 0.98),
            ))
            scale_vector = Vector((
                radii.x * 2.0 / source_dimensions.x,
                radii.y * 2.0 / source_dimensions.y,
                radii.z * 2.0 / source_dimensions.z,
            ))
            rotation = Vector((
                math.radians(rng.uniform(-12.0, 12.0)),
                math.radians(rng.uniform(-12.0, 12.0)),
                rng.uniform(-math.pi, math.pi),
            ))
            crown_specs.append((center, scale_vector, rotation))
            rotation_matrix = Euler(tuple(rotation), "XYZ").to_matrix()
            extent_x = math.sqrt(sum(
                (rotation_matrix[0][axis] * radii[axis]) ** 2
                for axis in range(3)
            ))
            extent_y = math.sqrt(sum(
                (rotation_matrix[1][axis] * radii[axis]) ** 2
                for axis in range(3)
            ))
            extent_z = math.sqrt(sum(
                (rotation_matrix[2][axis] * radii[axis]) ** 2
                for axis in range(3)
            ))
            crown_bounds.append((
                center.x - extent_x, center.x + extent_x,
                center.y - extent_y, center.y + extent_y,
                center.z - extent_z, center.z + extent_z,
            ))
            effective_radius = (radii.x * radii.y * radii.z) ** (1.0 / 3.0)
            overlap_spheres.append((center, effective_radius))
        assert len(crown_specs) == 30
        span_x = max(bound[1] for bound in crown_bounds) - min(
            bound[0] for bound in crown_bounds
        )
        span_y = max(bound[3] for bound in crown_bounds) - min(
            bound[2] for bound in crown_bounds
        )
        crown_min_z = min(bound[4] for bound in crown_bounds)
        crown_max_z = max(bound[5] for bound in crown_bounds)
        crown_vertical_span = crown_max_z - crown_min_z
        horizontal_aspect = max(span_x, span_y) / min(span_x, span_y)
        crown_height_ratio = crown_vertical_span / min(span_x, span_y)
        assert horizontal_aspect <= 1.12, (
            f"Upright crown is not horizontally round: {span_x:.2f} x {span_y:.2f}"
        )
        assert 2.0 <= crown_min_z <= 3.0, (
            f"Upright crown lower edge is outside target: {crown_min_z:.2f}"
        )
        assert 0.95 <= crown_height_ratio <= 1.25, (
            "Upright crown lost its oval proportion: "
            f"horizontal={min(span_x, span_y):.2f}, vertical={crown_vertical_span:.2f}"
        )
    elif round30:
        # Staggered three-dimensional lattice: adjacent groups intersect, but
        # no horizontal slice becomes a solid packed slab.
        centres = [
            (-3.8, -1.2, 7.1), (-1.4, -2.0, 7.1), (1.3, -1.9, 7.1),
            (3.7, -1.0, 7.1), (2.2, 1.5, 7.1), (-1.8, 1.7, 7.1),
            (-4.0, 0.7, 8.7), (-2.5, -1.4, 8.7), (-0.2, -0.5, 8.7),
            (2.2, -1.5, 8.7), (4.0, 0.6, 8.7), (1.7, 2.2, 8.7),
            (-1.1, 2.3, 8.7),
            (-3.7, -1.0, 10.3), (-1.5, -2.0, 10.3), (1.1, -1.8, 10.3),
            (3.6, -0.6, 10.3), (2.5, 1.6, 10.3), (0.1, 1.1, 10.3),
            (-2.4, 1.5, 10.3),
            (-3.1, 0.3, 11.9), (-1.6, -1.4, 11.9), (0.9, -1.5, 11.9),
            (3.0, 0.1, 11.9), (1.5, 1.8, 11.9), (-1.3, 1.7, 11.9),
            (-2.0, 0.0, 13.4), (-0.3, -1.0, 13.4), (2.0, 0.3, 13.4),
            (0.4, 1.4, 13.4),
        ]
        rng = random.Random(20260923)
        crown_specs = []
        source_dimensions = Vector((7.70, 5.77, 3.80))
        for x, y, z in centres:
            base_radius = rng.uniform(1.65, 2.15)
            radii = Vector((
                base_radius * rng.uniform(0.92, 1.08),
                base_radius * rng.uniform(0.90, 1.08),
                base_radius * rng.uniform(0.93, 1.10),
            ))
            scale_vector = Vector((
                radii.x * 2.0 / source_dimensions.x,
                radii.y * 2.0 / source_dimensions.y,
                radii.z * 2.0 / source_dimensions.z,
            ))
            center = Vector((
                x + rng.uniform(-0.12, 0.12),
                y + rng.uniform(-0.12, 0.12),
                z + rng.uniform(-0.10, 0.10),
            ))
            crown_specs.append((center, scale_vector, rng.uniform(-math.pi, math.pi)))
            effective_radius = (radii.x * radii.y * radii.z) ** (1.0 / 3.0)
            overlap_spheres.append((center, effective_radius))
        assert len(crown_specs) == 30
    elif dense30:
        crown_specs = []
        rng = random.Random(20260922)
        # Six closely spaced layers form one continuous crown. Every layer has
        # an inner group; the remaining groups overlap around its perimeter.
        layer_specs = [
            (7.3, 6, 3.30, 2.35, 0.67, 0.15),
            (8.5, 7, 3.75, 2.70, 0.68, 0.62),
            (9.7, 7, 3.65, 2.60, 0.67, 1.08),
            (10.9, 5, 3.00, 2.15, 0.65, 0.32),
            (12.1, 3, 1.90, 1.35, 0.63, 0.86),
            (13.3, 2, 0.90, 0.65, 0.61, 0.05),
        ]
        for z, count, radius_x, radius_y, scale, phase in layer_specs:
            for index in range(count):
                if index == 0:
                    x = rng.uniform(-0.28, 0.28)
                    y = rng.uniform(-0.22, 0.22)
                else:
                    angle = phase + math.tau * (index - 1) / max(1, count - 1)
                    radial = rng.uniform(0.70, 0.88)
                    x = math.cos(angle) * radius_x * radial
                    y = math.sin(angle) * radius_y * radial
                crown_specs.append((
                    ((x, y, z + rng.uniform(-0.16, 0.16)),
                     scale * rng.uniform(0.96, 1.04),
                     rng.uniform(-math.pi, math.pi))
                ))
        assert len(crown_specs) == 30
    else:
        crown_specs = (
        [
            ((-2.1, -0.7, 7.9), 0.60, -0.48),
            ((0.0, -1.5, 7.8), 0.62, 0.22),
            ((2.1, -0.4, 8.1), 0.60, 0.76),
            ((-0.8, 1.5, 8.2), 0.61, -0.92),
            ((-1.8, -0.5, 10.4), 0.59, 1.18),
            ((0.2, -1.0, 10.6), 0.62, -0.16),
            ((1.8, 0.5, 10.5), 0.59, 0.58),
            ((-0.3, 1.3, 10.8), 0.61, -0.72),
            ((-0.8, -0.1, 12.9), 0.58, 0.94),
            ((1.0, 0.2, 13.1), 0.58, 0.08),
        ] if compact else [
            ((-4.1, -1.5, 10.2), 0.72, -0.48),
            ((-1.1, -2.7, 10.5), 0.74, 0.22),
            ((2.4, -2.1, 10.4), 0.73, 0.76),
            ((4.2, 0.5, 10.7), 0.70, -0.92),
            ((-2.8, 2.3, 11.1), 0.73, 1.18),
            ((1.1, 2.6, 11.5), 0.75, -0.16),
            ((-3.0, -0.5, 14.1), 0.68, 0.58),
            ((0.3, -1.5, 14.5), 0.72, -0.72),
            ((3.1, 0.8, 14.3), 0.68, 0.94),
            ((-0.2, 1.4, 17.3), 0.67, 0.08),
        ])
    crowns = []
    old_crown_center_z = 4.08
    for index, (center_values, scale, rotation_value) in enumerate(crown_specs):
        crown = source_crown if index == 0 else source_crown.copy()
        if index > 0:
            crown.data = source_crown.data
            bpy.context.collection.objects.link(crown)
        center = Vector(center_values)
        scale_vector = scale if isinstance(scale, Vector) else Vector((scale, scale, scale))
        rotation = (
            Euler(tuple(rotation_value), "XYZ")
            if isinstance(rotation_value, Vector)
            else Euler((0.0, 0.0, rotation_value), "XYZ")
        )
        scaled_center = Vector((0.0, 0.0, old_crown_center_z * scale_vector.z))
        crown.name = f"Camphor_Foliage_OldCrownGroup_{index + 1:02d}"
        crown.location = center - rotation.to_matrix() @ scaled_center
        crown.rotation_euler = rotation
        crown.scale = scale_vector
        crown["asset_type"] = "accepted_v10_crown_group"
        crown["logical_card_count"] = 480
        crowns.append(crown)

    trunk["crown_group_count"] = len(crowns)
    trunk["logical_card_count"] = len(crowns) * 480
    if broad30 or upright_asymmetric30:
        trunk["horizontal_span_x"] = span_x
        trunk["horizontal_span_y"] = span_y
        trunk["horizontal_aspect"] = horizontal_aspect
        trunk["crown_min_z"] = crown_min_z
        trunk["crown_max_z"] = crown_max_z
        trunk["crown_vertical_span"] = crown_vertical_span
        if broad30:
            trunk["crown_breadth_ratio"] = crown_breadth_ratio
        if upright_asymmetric30:
            trunk["crown_height_ratio"] = crown_height_ratio
    if overlap_spheres:
        ratios = []
        neighbours = [0] * len(overlap_spheres)
        for first in range(len(overlap_spheres)):
            center_a, radius_a = overlap_spheres[first]
            for second in range(first + 1, len(overlap_spheres)):
                center_b, radius_b = overlap_spheres[second]
                distance = (center_a - center_b).length
                if distance >= radius_a + radius_b:
                    continue
                if distance <= abs(radius_a - radius_b):
                    intersection = 4.0 * math.pi * min(radius_a, radius_b) ** 3 / 3.0
                else:
                    intersection = (
                        math.pi * (radius_a + radius_b - distance) ** 2
                        * (distance * distance + 2.0 * distance * (radius_a + radius_b)
                           - 3.0 * (radius_a - radius_b) ** 2)
                        / (12.0 * distance)
                    )
                smaller_volume = 4.0 * math.pi * min(radius_a, radius_b) ** 3 / 3.0
                ratio = intersection / smaller_volume
                ratios.append(ratio)
                if ratio >= 0.03:
                    neighbours[first] += 1
                    neighbours[second] += 1
        trunk["overlap_pair_count"] = len(ratios)
        trunk["overlap_ratio_mean"] = sum(ratios) / max(1, len(ratios))
        trunk["overlap_ratio_max"] = max(ratios, default=0.0)
        trunk["isolated_group_count"] = sum(count == 0 for count in neighbours)
    return trunk, crowns


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
trunk_refined_mat = flat_material(
    "M_Trunk_WarmDark", (0.115, 0.080, 0.058)
)
if "--tree-small-broad-canopy" in sys.argv:
    trunk, foliage = create_tree(
        trunk_refined_mat,
        leaf_mat,
        crown_layout="branch_guided",
        use_refined_trunk=True,
    )
    model_path = os.path.join(MODEL_DIR, "tree_small_broad_canopy.glb")
    export_selected(model_path, [trunk, foliage])
    source_path = os.path.join(SOURCE_DIR, "tree_small_broad_canopy.blend")
    bpy.ops.wm.save_as_mainfile(filepath=source_path)
    print(f"SMALL_BROAD_CANOPY_BUILD_COMPLETE cards={foliage['card_count']}")
    print(model_path)
    print(source_path)
elif "--tree-medium-upright-asymmetric-canopy" in sys.argv:
    trunk, crowns = create_camphor_from_old_crowns(
        trunk_refined_mat,
        leaf_mat,
        upright_asymmetric30=True,
        use_refined_trunk=True,
    )
    model_path = os.path.join(
        MODEL_DIR, "tree_medium_upright_asymmetric_canopy.glb"
    )
    export_selected(model_path, [trunk, *crowns])
    source_path = os.path.join(
        SOURCE_DIR, "tree_medium_upright_asymmetric_canopy.blend"
    )
    bpy.ops.wm.save_as_mainfile(filepath=source_path)
    print(
        "MEDIUM_UPRIGHT_ASYMMETRIC_CANOPY_BUILD_COMPLETE "
        f"crown_groups={len(crowns)} cards={len(crowns) * 480} "
        f"overlap_pairs={trunk['overlap_pair_count']} "
        f"overlap_mean={trunk['overlap_ratio_mean']:.3f} "
        f"overlap_max={trunk['overlap_ratio_max']:.3f} "
        f"isolated={trunk['isolated_group_count']} "
        f"horizontal_span={trunk['horizontal_span_x']:.2f}x"
        f"{trunk['horizontal_span_y']:.2f} "
        f"horizontal_aspect={trunk['horizontal_aspect']:.3f} "
        f"crown_z={trunk['crown_min_z']:.2f}..{trunk['crown_max_z']:.2f} "
        f"height_ratio={trunk['crown_height_ratio']:.3f}"
    )
    print(model_path)
    print(source_path)
elif "--tree-medium-upright-clustered-canopy" in sys.argv:
    trunk, crowns = create_camphor_from_old_crowns(
        trunk_mat, leaf_mat, round30=True
    )
    model_path = os.path.join(
        MODEL_DIR, "tree_medium_upright_clustered_canopy.glb"
    )
    export_selected(model_path, [trunk, *crowns])
    source_path = os.path.join(
        SOURCE_DIR, "tree_medium_upright_clustered_canopy.blend"
    )
    bpy.ops.wm.save_as_mainfile(filepath=source_path)
    print(
        "MEDIUM_UPRIGHT_CLUSTERED_CANOPY_BUILD_COMPLETE "
        f"crown_groups={len(crowns)} cards={len(crowns) * 480} "
        f"overlap_mean={trunk['overlap_ratio_mean']:.3f} "
        f"overlap_max={trunk['overlap_ratio_max']:.3f}"
    )
    print(model_path)
    print(source_path)
elif "--tree-medium-broad-clustered-canopy" in sys.argv:
    trunk, crowns = create_camphor_from_old_crowns(
        trunk_refined_mat,
        leaf_mat,
        broad30=True,
        use_refined_trunk=True,
    )
    model_path = os.path.join(
        MODEL_DIR, "tree_medium_broad_clustered_canopy.glb"
    )
    export_selected(model_path, [trunk, *crowns])
    source_path = os.path.join(
        SOURCE_DIR, "tree_medium_broad_clustered_canopy.blend"
    )
    bpy.ops.wm.save_as_mainfile(filepath=source_path)
    print(
        "MEDIUM_BROAD_CLUSTERED_CANOPY_BUILD_COMPLETE "
        f"crown_groups={len(crowns)} cards={len(crowns) * 480} "
        f"overlap_pairs={trunk['overlap_pair_count']} "
        f"overlap_mean={trunk['overlap_ratio_mean']:.3f} "
        f"overlap_max={trunk['overlap_ratio_max']:.3f} "
        f"isolated={trunk['isolated_group_count']} "
        f"horizontal_span={trunk['horizontal_span_x']:.2f}x"
        f"{trunk['horizontal_span_y']:.2f} "
        f"horizontal_aspect={trunk['horizontal_aspect']:.3f} "
        f"crown_z={trunk['crown_min_z']:.2f}..{trunk['crown_max_z']:.2f} "
        f"breadth_ratio={trunk['crown_breadth_ratio']:.3f}"
    )
    print(model_path)
    print(source_path)
elif "--tree-camphor-v1" in sys.argv:
    shadow_mat = flat_material("M_Camphor_Shadow_Proxy", (0.12, 0.10, 0.06), 1.0)
    trunk, foliage, shadow_proxy = create_camphor_tree(trunk_mat, leaf_mat, shadow_mat)
    model_path = os.path.join(MODEL_DIR, "tree_camphor_30clump_v1.glb")
    export_selected(model_path, [trunk, foliage, shadow_proxy])
    source_path = os.path.join(SOURCE_DIR, "tree_camphor_30clump_v1.blend")
    bpy.ops.wm.save_as_mainfile(filepath=source_path)
    print(
        "CAMPHOR_TREE_BUILD_COMPLETE "
        f"clumps={foliage['clump_count']} cards={foliage['card_count']}"
    )
    print(model_path)
    print(source_path)
elif "--tree-camphor-v2" in sys.argv:
    shadow_mat = flat_material("M_Camphor_Shadow_Proxy", (0.12, 0.10, 0.06), 1.0)
    trunk, foliage, shadow_proxy = create_camphor_tree(
        trunk_mat, leaf_mat, shadow_mat, dense_v2=True
    )
    model_path = os.path.join(MODEL_DIR, "tree_camphor_30clump_v2_dense.glb")
    # Keep the proxy in the Blender source for later experiments, but do not
    # ship it in the gameplay GLB. Dense groves use foliage/trunk shading only.
    export_selected(model_path, [trunk, foliage])
    source_path = os.path.join(SOURCE_DIR, "tree_camphor_30clump_v2_dense.blend")
    bpy.ops.wm.save_as_mainfile(filepath=source_path)
    print(
        "CAMPHOR_TREE_V2_BUILD_COMPLETE "
        f"clumps={foliage['clump_count']} cards={foliage['card_count']}"
    )
    print(model_path)
    print(source_path)
elif "--tree-camphor-v3" in sys.argv:
    trunk, crowns = create_camphor_from_old_crowns(trunk_mat, leaf_mat)
    model_path = os.path.join(MODEL_DIR, "tree_camphor_10crown_v3.glb")
    export_selected(model_path, [trunk, *crowns])
    source_path = os.path.join(SOURCE_DIR, "tree_camphor_10crown_v3.blend")
    bpy.ops.wm.save_as_mainfile(filepath=source_path)
    print(
        "CAMPHOR_TREE_V3_BUILD_COMPLETE "
        f"crown_groups={len(crowns)} cards={len(crowns) * 480}"
    )
    print(model_path)
    print(source_path)
elif "--tree-camphor-v4" in sys.argv:
    trunk, crowns = create_camphor_from_old_crowns(
        trunk_mat, leaf_mat, compact=True
    )
    model_path = os.path.join(MODEL_DIR, "tree_camphor_10crown_v4_compact.glb")
    export_selected(model_path, [trunk, *crowns])
    source_path = os.path.join(SOURCE_DIR, "tree_camphor_10crown_v4_compact.blend")
    bpy.ops.wm.save_as_mainfile(filepath=source_path)
    print(
        "CAMPHOR_TREE_V4_BUILD_COMPLETE "
        f"crown_groups={len(crowns)} cards={len(crowns) * 480}"
    )
    print(model_path)
    print(source_path)
elif "--tree-camphor-v5" in sys.argv:
    trunk, crowns = create_camphor_from_old_crowns(
        trunk_mat, leaf_mat, dense30=True
    )
    model_path = os.path.join(MODEL_DIR, "tree_camphor_30crown_v5_dense.glb")
    export_selected(model_path, [trunk, *crowns])
    source_path = os.path.join(SOURCE_DIR, "tree_camphor_30crown_v5_dense.blend")
    bpy.ops.wm.save_as_mainfile(filepath=source_path)
    print(
        "CAMPHOR_TREE_V5_BUILD_COMPLETE "
        f"crown_groups={len(crowns)} cards={len(crowns) * 480}"
    )
    print(model_path)
    print(source_path)
elif "--tree-camphor-v6" in sys.argv:
    trunk, crowns = create_camphor_from_old_crowns(
        trunk_mat, leaf_mat, round30=True
    )
    model_path = os.path.join(MODEL_DIR, "tree_camphor_30round_v6.glb")
    export_selected(model_path, [trunk, *crowns])
    source_path = os.path.join(SOURCE_DIR, "tree_camphor_30round_v6.blend")
    bpy.ops.wm.save_as_mainfile(filepath=source_path)
    print(
        "CAMPHOR_TREE_V6_BUILD_COMPLETE "
        f"crown_groups={len(crowns)} cards={len(crowns) * 480} "
        f"overlap_pairs={trunk['overlap_pair_count']} "
        f"overlap_mean={trunk['overlap_ratio_mean']:.3f} "
        f"overlap_max={trunk['overlap_ratio_max']:.3f} "
        f"isolated={trunk['isolated_group_count']}"
    )
    print(model_path)
    print(source_path)
elif "--tree-refined-v10" in sys.argv:
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
