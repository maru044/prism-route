extends Node
## Verifies the actual, manually launched current scene and source identities.
var preview
var out: String
var failures: Array[String]=[]
func check(ok: bool,message: String) -> void:
    if not ok:failures.append(message);push_error(message)
func frames(n: int) -> void:
    for i in n:await get_tree().process_frame
func capture(name: String) -> void:
    await frames(8);await RenderingServer.frame_post_draw
    check(get_tree().root.get_texture().get_image().save_png(out+name+".png")==OK,"Capture failed: "+name)
func run() -> void:
    get_tree().create_timer(35).timeout.connect(func():get_tree().quit(1))
    out=str(preview.entry.report_dir);DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
    var startup: Dictionary=preview.preview_identity()
    check(get_tree().current_scene==preview,"Check did not run in the actual launched scene")
    check(startup.scene==preview.entry.scene or startup.scene in preview.entry.aliases,"Unexpected entry scene")
    check(startup.script==preview.entry.script and startup.shader==preview.entry.shader,"Stale preview implementation")
    check(startup.texture==preview.entry.texture and startup.texture_sha256==preview.entry.texture_sha256,"Wrong restored texture")
    check(startup.default_view==preview.entry.default_view and startup.volume_lighting==preview.entry.volume_lighting,"Startup defaults differ")
    check(startup.whole_groups==preview.placements.size() and startup.whole_groups>16 and startup.individual_leaves==0,"Invalid cluster representation")
    check(preview.TEXTURE.get_image().has_mipmaps(),"Restored texture lacks mipmaps")
    check(preview.material.get_shader_parameter("canopy_color_uniformity")==0. and preview.material.get_shader_parameter("wind_strength")==0.,"Tree material setup is wrong")
    check(is_equal_approx(startup.cluster_scale,float(preview.entry.default_scale)),"Wrong default cluster scale")
    var roles: Dictionary={};var children:=0
    for row: Dictionary in preview.placements:
        roles[row.role]=int(roles.get(row.role,0))+1
        if int(row.parent)>=0:children+=1
    check(roles.has("body") and roles.has("connector") and roles.has("tip") and children>0,"Missing growth hierarchy")
    var layout: String=JSON.stringify(preview.placements)
    for batch: MultiMeshInstance3D in preview.batches:
        for i in batch.multimesh.instance_count:
            var basis:=batch.multimesh.get_instance_transform(i).basis
            check(absf(basis.x.length()-basis.y.length())<.00001,"Anisotropic leaf-cluster scaling")
    await capture("game_startup_current")
    preview.ui.hide();preview.set_view(0)
    for scale_value: float in preview.entry.scale_options:
        preview.set_cluster_scale(scale_value);await capture("scale_%.2f"%scale_value)
    preview.set_cluster_scale(float(preview.entry.default_scale));await capture("v6_wall")
    preview.set_view(2);await capture("v6_close")
    var volume_image: Image=get_tree().root.get_texture().get_image()
    preview.set_volume(false);await capture("v6_flat_card_lighting")
    var flat_image: Image=get_tree().root.get_texture().get_image()
    var samples:=0;var changed:=0;var difference:=0.
    for y in range(0,volume_image.get_height(),4):
        for x in range(0,volume_image.get_width(),4):
            var a: Color=volume_image.get_pixel(x,y);var b: Color=flat_image.get_pixel(x,y)
            if a.g>a.r*1.2 and a.g>a.b*1.2:
                var delta: float=absf(a.r-b.r)+absf(a.g-b.g)+absf(a.b-b.b)
                samples+=1;difference+=delta
                if delta>.04:changed+=1
    var lighting_delta: Dictionary={"green_samples":samples,"changed_fraction":float(changed)/maxi(1,samples),"mean_rgb_difference":difference/maxi(1,samples)}
    check(samples>1000 and lighting_delta.changed_fraction>.08 and lighting_delta.mean_rgb_difference>.012,"Volume lighting has no visible contribution")
    preview.set_volume(true)
    preview.set_view(0);preview.set_source(1);await capture("old_v2_wall")
    preview.set_source(2);await capture("existing_shrub_wall")
    preview.set_source(0);check(JSON.stringify(preview.placements)==layout,"Asset comparison changed placement")
    preview.set_view(1);await capture("v6_oblique")
    preview.set_view(3);check(preview.get_group_count()==1,"Single cluster mode is incorrect");await capture("v6_single")
    for cell in 3:
        preview.set_module(cell);await capture("module_"+str(cell))
    preview.set_view(0);preview.ui.show();await capture("game_ui")
    var unchanged: Dictionary={}
    var before: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://.current_map_build/foliage_v5_before/hashes.json"))
    for path: String in before:
        if path.ends_with("trial_settings.json"):continue # World rollout is now explicitly authorized.
        unchanged[path]=FileAccess.get_sha256("res://"+path)==before[path];check(unchanged[path],"Source asset or world-disable setting changed: "+path)
    var aliases: Dictionary={}
    for path: String in preview.entry.aliases:
        var alias: Node=load(path).instantiate();aliases[path]=alias.get_script().resource_path==preview.entry.script
        check(aliases[path],"Stale scene alias: "+path);alias.free()
    var report: Dictionary={"passed":failures.is_empty(),"failures":failures,"startup":startup,"aliases_same_script":aliases,"checked_inside_launched_scene":true,"launched_with_verification_flag":"--verify-foliage-preview" in OS.get_cmdline_user_args(),"adapter":RenderingServer.get_video_adapter_name(),"unchanged_assets":unchanged,"wall_shader_derived_from_tree_shader":true,"roles":roles,"growth_paths":preview.growth_paths.size(),"placements_identical_across_sources":true,"volume_lighting_image_difference":lighting_delta}
    FileAccess.open(out+"entry_verification.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    FileAccess.open(out+"placements.json",FileAccess.WRITE).store_string(JSON.stringify(preview.placements,"  "))
    print("FOLIAGE_PREVIEW_ENTRY_VERIFIED ",JSON.stringify(report));get_tree().quit(0 if failures.is_empty() else 1)
