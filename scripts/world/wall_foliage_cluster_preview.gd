extends Node3D
## Existing leaf-cluster silhouettes and the actual accepted tree shader.
## Placement varies within a top-rooted growth field; never individual leaves.
const SHADER=preload("res://shaders/environment/wall_leaf_clusters_v6.gdshader")
const CLUSTERS=preload("res://scripts/world/wall_leaf_clusters.gd")
const ENTRY="res://assets/world/architecture_details_1029/preview_entry.json"
var TEXTURE: Texture2D
var entry: Dictionary
var source_index:=0
var module_cell:=0
var current_view:=0
var verification_started:=false
var camera: Camera3D
var sun: DirectionalLight3D
var material: ShaderMaterial
var groups: Node3D
var batches: Array[MultiMeshInstance3D]=[]
var placements: Array[Dictionary]=[]
var ui: CanvasLayer
var ready_for_review:=false
var automation_enabled:=false
var yaw:=0.
var target:=Vector3(0,3.07,0)
var dragging:=false
var auto_orbit:=false
var clock:=0.
var volume_lighting:=true
var cluster_scale:=1.35
var wall_material: ShaderMaterial
var growth_paths: Array=[]

func _ready() -> void:
    entry=JSON.parse_string(FileAccess.get_file_as_string(ENTRY))
    get_window().title="Prism Route | "+str(entry.display_name)
    var environment:=Environment.new();environment.background_mode=Environment.BG_COLOR;environment.background_color=Color("c4d1dc");environment.tonemap_mode=Environment.TONE_MAPPER_LINEAR
    environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;environment.ambient_light_color=Color.WHITE;environment.ambient_light_energy=.45
    var env:=WorldEnvironment.new();env.environment=environment;add_child(env)
    sun=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-44,-58,0);sun.light_energy=1.25;sun.shadow_enabled=true;sun.directional_shadow_max_distance=40.;add_child(sun)
    box(Vector3(12,6.3,.16),Vector3(0,3.15,-.08),Color("f3eedf"))
    box(Vector3(12.1,.10,.12),Vector3(0,6.3,-.07),Color("f7f1e4"))
    box(Vector3(13.8,.04,3),Vector3(0,-.04,0),Color("e8e3dc"))
    box(Vector3(12,.012,.002),Vector3(0,2.37,.003),Color("c6c0b4"))
    box(Vector3(.012,6.3,.002),Vector3(2.82,3.15,.003),Color("c6c0b4"))
    groups=Node3D.new();groups.name="LeafClusterBatches";add_child(groups)
    material=CLUSTERS.create_material(null)
    volume_lighting=bool(entry.volume_lighting);cluster_scale=float(entry.default_scale)
    make_placements();set_source(0)
    camera=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.near=.05;camera.far=100.;add_child(camera);camera.make_current()
    set_view(int(entry.default_view));build_ui();ready_for_review=true
    print("WALL_FOLIAGE_CLUSTER_PREVIEW_READY ",JSON.stringify(preview_identity()))
    if "--verify-foliage-preview" in OS.get_cmdline_user_args():call_deferred("start_verification")

func preview_identity() -> Dictionary:
    return {"revision":entry.revision,"scene":scene_file_path,"script":get_script().resource_path,"script_sha256":FileAccess.get_sha256(get_script().resource_path),"shader":material.shader.resource_path,"shader_sha256":FileAccess.get_sha256(material.shader.resource_path),"texture":TEXTURE.resource_path,"texture_sha256":FileAccess.get_sha256(TEXTURE.resource_path),"default_view":current_view,"painted_color":true,"parallax_enabled":false,"volume_lighting":volume_lighting,"whole_groups":get_group_count(),"cluster_scale":cluster_scale,"factory_sha256":FileAccess.get_sha256("res://scripts/world/wall_leaf_clusters.gd"),"individual_leaves":0,"window_title":get_window().title}
func start_verification() -> void:
    if verification_started:return
    verification_started=true;automation_enabled=true
    var verifier: Node=load("res://tools/check_foliage_preview_runtime_1029.gd").new()
    verifier.preview=self;add_child(verifier);verifier.call_deferred("run")
func box(size: Vector3,at: Vector3,color: Color) -> void:
    var mesh:=BoxMesh.new();mesh.size=size
    var arrays:=mesh.get_mesh_arrays();arrays[Mesh.ARRAY_TEX_UV]=null;arrays[Mesh.ARRAY_TEX_UV2]=null
    var without_uv:=ArrayMesh.new();without_uv.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
    var paint: Material
    if size.y>5.:
        wall_material=ShaderMaterial.new();wall_material.shader=load("res://shaders/environment/architecture_details_1029.gdshader")
        for pair: Array in [["warm_white",Color("ebe5d5")],["detail_strength",.08],["normal_strength",0.],["texture_meters",6.],["joints_enabled",false],["plants_enabled",false],["macro_strength",.10],["macro_meters",7.],["weather_strength",.30],["weather_top_y",6.3]]:wall_material.set_shader_parameter(pair[0],pair[1])
        paint=wall_material
    else:
        var flat:=StandardMaterial3D.new();flat.albedo_color=color;flat.roughness=1.;paint=flat
    var node:=MeshInstance3D.new();node.mesh=without_uv;node.material_override=paint;node.position=at;add_child(node)

func make_placements() -> void:
    var growth:=CLUSTERS.create_growth(int(entry.placement_seed),int(entry.target_clumps))
    placements=growth.placements;growth_paths=growth.paths

func set_source(index: int) -> void:
    source_index=index;TEXTURE=load(str(entry.sources[index].texture))
    material.set_shader_parameter("albedo_texture",TEXTURE)
    rebuild_groups(current_view==3)
func cluster_mesh(cell: int,mirror: bool) -> ArrayMesh:
    return CLUSTERS.cluster_mesh(entry.sources[source_index],cell,mirror,volume_lighting)
func rebuild_groups(single: bool) -> void:
    for node: Node in groups.get_children():node.free()
    batches.clear()
    var active: Array=placements if not single else [{"x":0.,"depth":.8,"size":4.,"angle":0.,"cell":module_cell,"mirror":false,"z":.05}]
    for cell in 4:
        for mirror in [false,true]:
            var rows: Array=[]
            for row: Dictionary in active:
                if int(row.cell)==cell and bool(row.mirror)==mirror:rows.append(row)
            if rows.is_empty():continue
            var mm:=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D;mm.mesh=cluster_mesh(cell,mirror);mm.instance_count=rows.size()
            for i in rows.size():
                var row: Dictionary=rows[i];var bounds: Array=entry.sources[source_index].cell_bounds[cell]
                var size: float=row.size*cluster_scale
                var center_y: float=6.3-float(row.depth)+(float(bounds[1])-.5)*size
                mm.set_instance_transform(i,Transform3D(Basis(Vector3.BACK,float(row.angle)).scaled(Vector3.ONE*size),Vector3(row.x,center_y,row.z)))
            var node:=MultiMeshInstance3D.new();node.multimesh=mm;node.material_override=material;groups.add_child(node);batches.append(node)
            CLUSTERS.apply_palette(node)
func get_group_count() -> int:
    var count:=0
    for batch: MultiMeshInstance3D in batches:count+=batch.multimesh.instance_count
    return count
func set_module(which: int) -> void:
    module_cell=which;set_view(3)
func set_cluster_scale(value: float) -> void:
    cluster_scale=value;rebuild_groups(current_view==3)
func set_volume(value: bool) -> void:
    volume_lighting=value;rebuild_groups(current_view==3)
func set_view(which: int) -> void:
    current_view=which;rebuild_groups(which==3)
    yaw=.42 if which==1 else 0.
    target=Vector3(-2.,4.9,0) if which==2 else Vector3(0,3.07,0)
    camera.size=2.8 if which==2 else 7.15
    update_camera()
func update_camera() -> void:
    camera.position=target+Basis(Vector3.UP,yaw)*Vector3(0,0,14);camera.look_at(target)
func build_ui() -> void:
    ui=CanvasLayer.new();add_child(ui)
    var panel:=PanelContainer.new();ui.add_child(panel);panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
    panel.offset_left=16;panel.offset_top=-92;panel.offset_right=1520;panel.offset_bottom=-12
    var column:=VBoxContainer.new();panel.add_child(column)
    var row:=HBoxContainer.new();row.add_theme_constant_override("separation",10);column.add_child(row)
    var title:=Label.new();title.text="叶团 V6 · 生长与尺度";row.add_child(title)
    var selector:=OptionButton.new()
    for source: Dictionary in entry.sources:selector.add_item(source.name)
    selector.item_selected.connect(set_source);row.add_child(selector)
    var scale_label:=Label.new();scale_label.text="叶团尺度";row.add_child(scale_label)
    for value: float in entry.scale_options:
        var scale_button:=Button.new();scale_button.text="%.2f ×"%value;scale_button.pressed.connect(set_cluster_scale.bind(value));row.add_child(scale_button)
    row=HBoxContainer.new();row.add_theme_constant_override("separation",10);column.add_child(row)
    var detail:=CheckBox.new();detail.text="墙面材质";detail.button_pressed=true;row.add_child(detail)
    detail.toggled.connect(func(value):wall_material.set_shader_parameter("macro_strength",.10 if value else 0.);wall_material.set_shader_parameter("weather_strength",.30 if value else 0.))
    for pair: Array in [["整墙",0],["斜看",1],["近景",2],["单团",3]]:
        var button:=Button.new();button.text=pair[0];button.pressed.connect(set_view.bind(int(pair[1])));row.add_child(button)
    for pair: Array in [["主体",0],["连接",1],["末端",2]]:
        var module_button:=Button.new();module_button.text=pair[0];module_button.pressed.connect(set_module.bind(int(pair[1])));row.add_child(module_button)
    var volume:=CheckBox.new();volume.text="树木体积受光";volume.button_pressed=volume_lighting;volume.toggled.connect(set_volume);row.add_child(volume)
    var orbit:=CheckBox.new();orbit.text="自动摆镜";orbit.toggled.connect(func(value):auto_orbit=value;clock=0.);row.add_child(orbit)
    var label:=Label.new();label.text="右键旋转 · 滚轮缩放 · H 隐藏";row.add_child(label)
func _process(delta: float) -> void:
    if auto_orbit and not dragging and not automation_enabled:clock+=delta;yaw=sin(clock*.7)*.42;update_camera()
func _input(event: InputEvent) -> void:
    if automation_enabled:return
    if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode==KEY_H:ui.visible=not ui.visible;get_viewport().set_input_as_handled()
func _unhandled_input(event: InputEvent) -> void:
    if automation_enabled:return
    if event is InputEventMouseButton:
        if event.button_index==MOUSE_BUTTON_RIGHT:dragging=event.pressed
        if event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:camera.size=clampf(camera.size+(-.4 if event.button_index==MOUSE_BUTTON_WHEEL_UP else .4),1.5,11.)
    if event is InputEventMouseMotion and dragging:yaw=clampf(yaw-event.relative.x*.003,-.8,.8);update_camera()
