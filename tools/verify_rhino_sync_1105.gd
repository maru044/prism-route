extends SceneTree
const OUT="res://docs/floor_materials_1105/"
const STORE=preload("res://scripts/grass_baked_store.gd")
const REMOVED=["0511ba39-173f-4035-a825-9c9d134728fb","90e44921-4322-4a1a-8685-77ae80f7d56e","79c76214-16b7-44c8-8be8-f5c6862f6263"]
var world
var failures:Array[String]=[]
var report:Dictionary={}
func _initialize():call_deferred("run")
func check(ok:bool,message:String):
 if not ok:failures.append(message);push_error(message)
func settle(seconds:float):
 var start=Time.get_ticks_msec()
 while Time.get_ticks_msec()-start<seconds*1000.:await process_frame
func capture(label:String,eye:Vector3,target:Vector3):
 world.set_free(true);world.camera.global_position=eye;world.camera.look_at(target)
 await settle(8.)
 for attempt in 10:
  if world.vegetation.volume_streamer.queue.is_empty() and world.vegetation.volume_streamer.work.is_empty():break
  await settle(1.)
 await RenderingServer.frame_post_draw
 check(root.get_texture().get_image().save_png(OUT+label+".png")==OK,"Screenshot failed: "+label)
 print("RHINO_SYNC_CAPTURE ",label)
func run():
 create_timer(160).timeout.connect(func():push_error("Rhino sync validation timeout");quit(1))
 AudioServer.set_bus_mute(0,true);root.size=Vector2i(1920,1080)
 world=load("res://scenes/main.tscn").instantiate();world.automation_enabled=true;root.add_child(world)
 while not world.test_ready:await process_frame
 check(ProjectSettings.get_setting("application/run/main_scene")=="res://scenes/main.tscn","Wrong formal entry")
 var ruin=world.initial_ruin
 check(ruin.geometry.find_children("*","MeshInstance3D",true,false).size()==325,"Old ruin meshes still imported")
 for id:String in REMOVED:check(ruin.geometry.find_child("Structure_"+id,true,false)==null,"Deleted native base remains: "+id)
 var platform_checks:=0
 for row:Dictionary in ruin.planting_mask.manifest.objects:
  if not str(row.name).begins_with("PR_EntryLandingCap_"):continue
  var p:=Vector3((float(row.bounds[0][0])+float(row.bounds[1][0]))*.5-1450.,float(row.bounds[1][2]),1150.-(float(row.bounds[0][1])+float(row.bounds[1][1]))*.5)
  var q=PhysicsRayQueryParameters3D.create(p+Vector3.UP*.25,p-Vector3.UP*.3,32)
  var hit=world.get_world_3d().direct_space_state.intersect_ray(q)
  check(not hit.is_empty() and absf(hit.get("position",Vector3.ZERO).y-p.y)<.02,"Missing landing collision: "+str(row.name));platform_checks+=1
 var default_inventory:Array=JSON.parse_string(FileAccess.get_file_as_string("res://.current_map_build/current_rhino_sync_1105/inventory.json"))
 var defaults_checked:=0
 for row:Dictionary in default_inventory:
  if int(row.material.index)>=0 or not str(row.manifest).contains("current_map_validation"):continue
  var mesh=world.model.find_child("Structure_"+str(row.id),true,false)
  if mesh==null:continue
  check(mesh.material_override is ShaderMaterial,"Default native building lacks architecture shader: "+str(row.id));defaults_checked+=1
 var church=world.church_ruins;var stone_meshes:=0
 for row:Dictionary in church.manifest.objects:
  if row.material_key in ["path_flagstone","pavement_marble_ivory","weathered_limestone"] and church.meshes_by_source.has(row.id):
   var mat=church.meshes_by_source[row.id].material_override
   check(mat is ShaderMaterial and mat.shader.resource_path=="res://assets/world/cliff_b_test/architecture.gdshader","Church stone fallback failed");stone_meshes+=1
 check(church.colonly_ramps==7,"Church ramps changed")
 var expected:String=JSON.parse_string(FileAccess.get_file_as_string("res://assets/world/current_map_validation/grass_bake/manifest.json")).signature
 check(STORE.signature(world)==expected,"Grass bake generation signature changed")
 var old_feature_hash:String=world.metadata.static_features.initial_ruin_1029.mesh_sha256
 world.metadata.static_features.initial_ruin_1029.mesh_sha256="future_geometry_probe"
 check(STORE.signature(world)!=expected,"Future geometry edits do not invalidate render-only exception")
 world.metadata.static_features.initial_ruin_1029.mesh_sha256=old_feature_hash
 var old_ring_hash:String=world.metadata.static_features.upper_ring_1030.mesh_sha256
 world.metadata.static_features.upper_ring_1030.mesh_sha256="future_other_feature_probe"
 check(STORE.signature(world)!=expected,"Unrelated feature signature is pinned")
 world.metadata.static_features.upper_ring_1030.mesh_sha256=old_ring_hash
 check(world.vegetation.volume_streamer.store.last_error.is_empty(),"Grass cache rejected")
 check(church.local_grass_cells==12,"Church local grass cells missing")
 report={"formal_entry":"res://scenes/main.tscn","ruin_meshes":325,"removed_bases":3,"landing_collision_checks":platform_checks,"default_native_buildings_checked":defaults_checked,"church_stone_meshes":stone_meshes,"church_colonly_ramps":church.colonly_ramps,"grass_signature":STORE.signature(world),"grass_cache_status":world.vegetation.volume_streamer.store.last_error,"church_grass_cells":church.local_grass_cells,"adapter":RenderingServer.get_video_adapter_name()}
 if DisplayServer.get_name()!="headless":
  world.grass_wind.set_mode(world.grass_wind.Mode.BREEZE)
  await capture("after_initial_ruin",Vector3(-1009.409,63.919,1270.478),Vector3(-1004.95,59.,1282.9))
  var spawn:Vector3=world.vec(church.manifest.spawn_godot);var forward:Vector3=world.vec(church.manifest.spawn_look_direction_godot)
  await capture("after_church",spawn+Vector3.UP*1.7,spawn+forward*20.+Vector3.UP*3.)
 report["passed"]=failures.is_empty();report["failures"]=failures
 FileAccess.open(OUT+"validation.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  ")+"\n")
 print("RHINO_SYNC_VALIDATION ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
