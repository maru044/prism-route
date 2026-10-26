extends Node3D
## Default water renderer. One shared shader, explicit profiles, one bounded mirror.
const PROFILES := preload("res://scripts/water/water_profiles.gd")
const INTERACTION := preload("res://scripts/water/water_interaction.gd")
const SURFACE := preload("res://assets/water/water_surface.gdshader")
const PROXY := preload("res://assets/water/reflection_proxy.gdshader")
const SSR := preload("res://assets/water/water_ssr_opaque.gdshader")
const OLD := preload("res://assets/world/map_1012_test/water.gdshader")
const SKY_TEXTURE := preload("res://assets/environment/sky/fresh_cumulus_panorama_v2.png")
const REFLECTION_LAYER := 1 << 19
enum Style { ORIGINAL, SKY, PLANAR, NATIVE_SSR }
var style := Style.PLANAR
var clock := 0.0
var wind_strength := 0.0
var wind_source: Node
var actor_provider: Callable
var interaction = INTERACTION.new()
var interactions_enabled := true
var surface_detail := 1.0
var bodies: Array[Dictionary] = []
var proxy_records: Array[Dictionary] = []
var reflection: SubViewport
var mirror_camera: Camera3D
var main_environment: Environment
var original_ssr := false
var reflection_weight := 0.0
var reflected_objects := 0
var reflection_gpu_ms := 0.0
var visibility_clock := 0.0
var camera_provider: Callable
var sky_yaw := deg_to_rad(84.4)
var reflection_radius := 240.0
var wind_override := -1.0
var reflection_materials: Dictionary = {}

func initialize(environment: Environment, get_actor: Callable, get_camera: Callable = Callable()) -> void:
    main_environment = environment
    original_ssr = environment.ssr_enabled
    actor_provider = get_actor
    camera_provider = get_camera
    sky_yaw = environment.sky_rotation.y
    reflection = SubViewport.new()
    reflection.name = "WaterReflectionHDR"
    reflection.size = Vector2i(800,450)
    reflection.world_3d = get_world_3d()
    reflection.use_hdr_2d = true
    reflection.msaa_3d = Viewport.MSAA_2X
    reflection.mesh_lod_threshold = 4.0
    reflection.render_target_update_mode = SubViewport.UPDATE_DISABLED
    reflection.gui_disable_input = true
    reflection.audio_listener_enable_3d = false
    add_child(reflection)
    RenderingServer.viewport_set_measure_render_time(reflection.get_viewport_rid(),true)
    mirror_camera = Camera3D.new()
    mirror_camera.name = "MirrorOnlyCamera"
    mirror_camera.cull_mask = REFLECTION_LAYER
    mirror_camera.near = 0.04
    mirror_camera.far = 400.0
    # Reflect linear radiance, not an already ACES-tonemapped second image.
    var mirror_environment := environment.duplicate() as Environment
    mirror_environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
    mirror_environment.tonemap_exposure = 1.0
    mirror_environment.ssao_enabled = false
    mirror_environment.ssr_enabled = false
    mirror_environment.glow_enabled = false
    mirror_environment.fog_enabled = false
    mirror_environment.volumetric_fog_enabled = false
    mirror_camera.environment = mirror_environment
    reflection.add_child(mirror_camera)
    mirror_camera.make_current()
    apply_style(style)

func register_water(mesh: MeshInstance3D, id: String, profile: String = "") -> void:
    if profile.is_empty():profile = PROFILES.profile_for(id)
    var settings: Dictionary = PROFILES.SETTINGS[profile]
    var material := ShaderMaterial.new()
    material.shader = SURFACE
    material.set_shader_parameter("sky_panorama",SKY_TEXTURE)
    material.set_shader_parameter("sky_yaw",sky_yaw)
    material.set_shader_parameter("planar_color",reflection.get_texture())
    material.set_shader_parameter("shallow_color",settings.shallow)
    material.set_shader_parameter("deep_color",settings.deep)
    material.set_shader_parameter("absorption",settings.absorption)
    material.set_shader_parameter("exposure_to_wind",settings.wind)
    material.set_shader_parameter("see_bottom",settings.bottom)
    var baseline := ShaderMaterial.new();baseline.shader = OLD
    var ssr_material := ShaderMaterial.new();ssr_material.shader = SSR
    ssr_material.set_shader_parameter("deep_color",settings.deep)
    bodies.append({"mesh":mesh,"id":id,"profile":profile,"material":material,"baseline":baseline,"ssr":ssr_material})
    mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    mesh.material_override = baseline if style == Style.ORIGINAL else (ssr_material if style == Style.NATIVE_SSR else material)

func register_reflector(source: MeshInstance3D, color: Color, leaf: Texture2D = null) -> void:
    var proxy := MeshInstance3D.new()
    proxy.name = "ReflectionOnly_" + str(source.name)
    proxy.mesh = source.mesh
    proxy.layers = REFLECTION_LAYER
    proxy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    proxy.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
    proxy.lod_bias = 0.5
    var material := _reflection_material(source,color,leaf)
    proxy.material_override = material
    add_child(proxy)
    proxy.global_transform = source.global_transform
    proxy.visible = false
    proxy_records.append({"source":source,"proxy":proxy,"bounds":source.global_transform * source.get_aabb()})

func _reflection_material(source: MeshInstance3D, color: Color, leaf: Texture2D) -> ShaderMaterial:
    var original := source.material_override as ShaderMaterial
    if original != null and original.shader != null:
        var code: String = original.shader.code
        # The project's terrain and architecture shaders have explicit entry
        # points. Preserve their masks/colours/textures in the mirror, while
        # clipping submerged geometry without touching the original material.
        if code.contains("void vertex() {") and code.contains("void fragment() {"):
            var key := original.get_instance_id()
            if reflection_materials.has(key):return reflection_materials[key]
            code = code.replace("shader_type spatial;","shader_type spatial;\nvarying float water_reflection_world_y;")
            if not code.contains("shadows_disabled"):code = code.replace("render_mode ","render_mode shadows_disabled, ")
            code = code.replace("cull_back","cull_disabled")
            code = code.replace("void vertex() {","void vertex() {\nwater_reflection_world_y = (MODEL_MATRIX * vec4(VERTEX, 1.0)).y;")
            code = code.replace("void fragment() {","void fragment() {\nif (water_reflection_world_y < 0.003) { discard; }")
            var shader := Shader.new();shader.code = code
            var material := ShaderMaterial.new();material.shader = shader
            for uniform: Dictionary in original.shader.get_shader_uniform_list():
                var value: Variant = original.get_shader_parameter(uniform.name)
                if value != null:material.set_shader_parameter(uniform.name,value)
            reflection_materials[key] = material
            return material
    var fallback := ShaderMaterial.new();fallback.shader = PROXY
    fallback.set_shader_parameter("base_color",color)
    if leaf != null:
        fallback.set_shader_parameter("leaf_cutout",true)
        fallback.set_shader_parameter("leaf_texture",leaf)
    return fallback

func register_tree_streamer(streamer: Node) -> void:
    # Reuse medium crown meshes, palettes and fixed placement buffers. No second
    # population, grass streamer, or dependency on the reflected camera's LOD.
    var sources: Array = streamer.get("tree_lod1_nodes").duplicate()
    for node: MultiMeshInstance3D in streamer.get("tree_lod0_nodes"):
        if str(node.name).ends_with("_Trunks"):sources.append(node)
    for source: MultiMeshInstance3D in sources:
        var proxy := MultiMeshInstance3D.new()
        proxy.multimesh = source.multimesh
        proxy.layers = REFLECTION_LAYER
        proxy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        proxy.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
        if str(source.name).ends_with("_Trunks"):proxy.visibility_range_end = 160.0
        if source.material_override != null:
            proxy.material_override = source.material_override.duplicate() as Material
            if proxy.material_override is ShaderMaterial:
                proxy.material_override.set_shader_parameter("tree_lod_fade",Vector4(-1000,-999,10000,11000))
        add_child(proxy)
        proxy.global_transform = source.global_transform
        proxy.visible = false
        proxy_records.append({"source":source,"proxy":proxy,"bounds":source.global_transform * source.get_aabb()})

func apply_style(value: int) -> void:
    style = clampi(value,Style.ORIGINAL,Style.NATIVE_SSR)
    interaction.reset()
    if main_environment != null:main_environment.ssr_enabled = style == Style.NATIVE_SSR
    for row: Dictionary in bodies:
        row.mesh.material_override = row.baseline if style == Style.ORIGINAL else (row.ssr if style == Style.NATIVE_SSR else row.material)
    if reflection != null and style != Style.PLANAR:
        reflection.render_target_update_mode = SubViewport.UPDATE_DISABLED
        reflection_weight = 0.0
        reflected_objects = 0
        for row: Dictionary in proxy_records:row.proxy.hide()
    visibility_clock = 1.0

func active_camera() -> Camera3D:
    if camera_provider.is_valid():return camera_provider.call() as Camera3D
    return get_viewport().get_camera_3d()

func _physics_process(delta: float) -> void:
    if not interactions_enabled or style in [Style.ORIGINAL,Style.NATIVE_SSR]:
        interaction.expire(clock)
        return
    var actor: CharacterBody3D = actor_provider.call() if actor_provider.is_valid() else null
    interaction.tick(actor,clock,delta,get_world_3d().direct_space_state)

func _process(delta: float) -> void:
    clock += delta
    interaction.expire(clock)
    wind_strength = wind_override if wind_override >= 0.0 else (float(wind_source.get("blend")) if is_instance_valid(wind_source) else 0.0)
    var camera := active_camera()
    if camera == null or reflection == null:return
    # Never change which camera the main viewport/vegetation streamer considers active.
    camera.cull_mask &= ~REFLECTION_LAYER
    var wants_mirror := style == Style.PLANAR and camera.global_position.y > 0.06 and camera.global_position.y < 260.0
    var water_visible := false
    if wants_mirror:
        for row: Dictionary in bodies:
            if row.mesh.is_visible_in_tree() and camera.is_position_in_frustum((row.mesh.global_transform * row.mesh.get_aabb()).get_center()):
                water_visible = true;break
        # Huge ocean AABBs may have an off-screen centre; sample frustum rays on Y=0.
        if not water_visible:
            var size: Vector2 = get_viewport().get_visible_rect().size
            for uv: Vector2 in [Vector2(.5,.65),Vector2(.15,.85),Vector2(.85,.85)]:
                var ray := camera.project_ray_normal(uv * size)
                if ray.y < -0.001:
                    var p: Vector3 = camera.global_position + ray * (-camera.global_position.y/ray.y)
                    for row: Dictionary in bodies:
                        if not row.mesh.is_visible_in_tree():continue
                        var box: AABB = row.mesh.global_transform * row.mesh.get_aabb()
                        if p.x >= box.position.x and p.x <= box.end.x and p.z >= box.position.z and p.z <= box.end.z:water_visible = true;break
    wants_mirror = wants_mirror and water_visible
    reflection_weight = move_toward(reflection_weight,1.0 if wants_mirror else 0.0,delta * 3.0)
    var rendering := style == Style.PLANAR and (wants_mirror or reflection_weight > 0.001)
    reflection.render_target_update_mode = SubViewport.UPDATE_ALWAYS if rendering else SubViewport.UPDATE_DISABLED
    if rendering:
        var size := Vector2i(Vector2(get_viewport().get("size")) * 0.5)
        size.x = maxi(size.x,128);size.y = maxi(size.y,72)
        if reflection.size != size:reflection.size = size
        mirror_camera.fov = camera.fov
        mirror_camera.keep_aspect = camera.keep_aspect
        mirror_camera.projection = camera.projection
        mirror_camera.size = camera.size
        var eye := camera.global_position;eye.y = -eye.y
        var forward := -camera.global_basis.z;forward.y = -forward.y
        var up := camera.global_basis.y;up.y = -up.y
        # Roll is arbitrary because sampling uses the matching view-projection.
        # Keep +Y upright: spherical crown billboards pivot about ground roots
        # and otherwise rotate their entire height below the water plane.
        if up.y < 0.0:up = -up
        mirror_camera.global_position = eye
        mirror_camera.look_at(eye+forward,up)
        visibility_clock += delta
        if visibility_clock >= 0.25:
            visibility_clock = 0.0
            reflected_objects = 0
            for row: Dictionary in proxy_records:
                var box: AABB = row.bounds
                var distance := camera.global_position.distance_to(camera.global_position.clamp(box.position,box.end))
                row.proxy.visible = row.source.is_visible_in_tree() and distance < reflection_radius + (20.0 if row.proxy.visible else 0.0)
                if row.proxy.visible:reflected_objects += 1
        reflection_gpu_ms = RenderingServer.viewport_get_measured_render_time_gpu(reflection.get_viewport_rid())
    else:reflection_gpu_ms = 0.0
    var vp := mirror_camera.get_camera_projection() * Projection(mirror_camera.global_transform.affine_inverse())
    for row: Dictionary in bodies:
        var material: ShaderMaterial = row.material
        material.set_shader_parameter("water_clock",clock)
        material.set_shader_parameter("wind_strength",wind_strength)
        material.set_shader_parameter("surface_detail",surface_detail)
        material.set_shader_parameter("planar_enabled",style == Style.PLANAR)
        material.set_shader_parameter("reflection_mix",reflection_weight)
        material.set_shader_parameter("reflection_vp",vp)
        material.set_shader_parameter("reflection_texel",Vector2.ONE / Vector2(reflection.size))
        var events: PackedVector4Array = interaction.packed_for(row.id) if interactions_enabled else PackedVector4Array()
        material.set_shader_parameter("event_count",events.size())
        events.resize(INTERACTION.MAX_EVENTS)
        material.set_shader_parameter("ripple_events",events)

func _input(event: InputEvent) -> void:
    # Let the existing actor controllers still handle these keys themselves.
    if event is InputEventKey and event.pressed and not event.echo:
        var key: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
        if key in [KEY_R,KEY_C]:interaction.reset()

func metrics() -> Dictionary:
    return {"style":style,"wind":wind_strength,"events":interaction.events.size(),"emitted":interaction.emitted,
        "reflection_gpu_ms":reflection_gpu_ms,"reflection_size":[reflection.size.x,reflection.size.y],
        "reflection_objects":reflected_objects,"reflection_active":reflection.render_target_update_mode != SubViewport.UPDATE_DISABLED,
        "reflection_weight":reflection_weight,"bodies":bodies.size(),"clock":clock}

func _exit_tree() -> void:
    if main_environment != null:main_environment.ssr_enabled = original_ssr
    if is_instance_valid(reflection):RenderingServer.viewport_set_measure_render_time(reflection.get_viewport_rid(),false)
