@tool
extends RefCounted
## Baseline stays read-only. Only explicit, stable per-tree edits are saved.
var baseline: Dictionary = {}
var edits: Dictionary = {}
var removed: Dictionary = {}
var baseline_sha := ""
var terrain_path := ""
var last_error := ""

func open(profile: Resource) -> bool:
	baseline.clear();edits.clear();removed.clear();last_error=""
	terrain_path=profile.terrain.resource_path if profile.terrain != null else ""
	baseline_sha=FileAccess.get_sha256(profile.baseline_layout) if not profile.baseline_layout.is_empty() else ""
	if not profile.baseline_layout.is_empty():
		var rows: Variant=JSON.parse_string(FileAccess.get_file_as_string(profile.baseline_layout))
		if not rows is Array:last_error="基准树位文件格式不正确";return false
		var rng:=RandomNumberGenerator.new();rng.seed=10122026
		for index in rows.size():
			var row: Variant=rows[index]
			if row is Dictionary:
				if not valid_record(row):last_error="树位记录缺少稳定编号或参数";return false
				if baseline.has(row.id):last_error="基准树位存在重复编号";return false
				baseline[row.id]=row.duplicate(true)
			elif row is Array and row.size() >= 6:
				# Reproduce the existing map's cell palette and RNG exactly once.
				var cell:=Vector2i(floori(float(row[0])/128.0),floori(float(row[2])/128.0))
				var value:=absi(cell.x*73856093 ^ cell.y*19349663 ^ 0x35B7)%100
				var color:=1 if value<7 else (2 if value<14 else (3 if value<20 else (4 if value<25 else 0)))
				var model:=0
				if int(row[5])==1:model=1 if color in [1,2] else (2 if color in [3,4] else (1 if rng.randf()<0.58 else 2))
				var id:="base_%06d"%index
				baseline[id]={"id":id,"position":[row[0],row[1],row[2]],"yaw":row[3],"scale":row[4],
					"species":["small","broad","upright"][model],"palette":["green","cherry","gold","orange","red"][color],"surface":""}
			else:last_error="不支持的基准树位格式";return false
	if FileAccess.file_exists(profile.test_edits_path):
		var data: Variant=JSON.parse_string(FileAccess.get_file_as_string(profile.test_edits_path))
		if not data is Dictionary or data.get("version",0)!=1:last_error="测试树位版本不正确";return false
		if data.get("baseline_sha256","")!=baseline_sha or data.get("terrain","")!=terrain_path:
			last_error="地形或基准树位已更换；请在配置中使用另一个测试保存路径";return false
		for row: Variant in data.get("trees",[]):
			if not row is Dictionary or not valid_record(row):last_error="测试树位记录损坏";return false
			if edits.has(row.id):last_error="测试树位存在重复编号";return false
			edits[row.id]=row.duplicate(true)
		for id: String in data.get("removed",[]):removed[id]=true
	return true

static func valid_record(row: Dictionary) -> bool:
	if not row.get("id",null) is String or row.id.is_empty():return false
	if not row.get("position",null) is Array or row.position.size()!=3:return false
	for value: Variant in row.position:
		if not (value is float or value is int) or not is_finite(float(value)):return false
	for name: String in ["yaw","scale"]:
		if not (row.get(name,null) is float or row.get(name,null) is int) or not is_finite(float(row[name])):return false
	return float(row.scale)>0 and row.get("species",null) is String and row.get("palette",null) is String

func all_records() -> Dictionary:
	var result:=baseline.duplicate()
	for id: String in removed:result.erase(id)
	for id: String in edits:result[id]=edits[id]
	return result

func capture(rows: Array[Dictionary], active_ids: Array[String]) -> void:
	var present: Dictionary={}
	for row: Dictionary in rows:
		present[row.id]=true;removed.erase(row.id)
		if baseline.has(row.id) and same_tree(row,baseline[row.id]):edits.erase(row.id)
		else:edits[row.id]=row.duplicate(true)
	for id: String in active_ids:
		if not present.has(id):
			edits.erase(id)
			if baseline.has(id):removed[id]=true

static func same_tree(a: Dictionary,b: Dictionary) -> bool:
	for name: String in ["id","species","palette","surface"]:
		if a.get(name,"")!=b.get(name,""):return false
	for axis in 3:
		if absf(float(a.position[axis])-float(b.position[axis]))>0.0002:return false
	return absf(float(a.yaw)-float(b.yaw))<0.00001 and absf(float(a.scale)-float(b.scale))<0.00001

func new_id() -> String:
	return "tree_"+Crypto.new().generate_random_bytes(12).hex_encode()

func save(path: String, profile: Resource) -> Error:
	last_error=""
	path=path.simplify_path()
	if path==profile.baseline_layout.simplify_path() or path==profile.terrain_metadata.simplify_path() or not (path.begins_with("res://") or path.begins_with("user://")) or path.get_extension().to_lower()!="json":
		last_error="只允许保存到独立的项目或用户目录测试文件";return ERR_INVALID_PARAMETER
	if FileAccess.file_exists(path):
		var existing: Variant=JSON.parse_string(FileAccess.get_file_as_string(path))
		if not existing is Dictionary or existing.get("version",0)!=1 or not existing.has("trees") or not existing.has("removed"):
			last_error="目标文件不是本工具的测试布局，不能覆盖";return ERR_INVALID_DATA
	for row: Dictionary in edits.values():
		if not valid_record(row) or profile.find_species(row.species)==null or profile.find_palette(row.palette)==null:
			last_error="树种、色板或树位参数无效";return ERR_INVALID_DATA
	var folder:=path.get_base_dir()
	var error:=DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	if error!=OK:last_error="无法创建测试目录";return error
	var temporary:=path+".tmp"
	var file:=FileAccess.open(temporary,FileAccess.WRITE)
	if file==null:last_error="无法写入测试布局";return FileAccess.get_open_error()
	file.store_string(JSON.stringify({"version":1,"terrain":terrain_path,"baseline_sha256":baseline_sha,
		"trees":edits.values(),"removed":removed.keys()},"\t"));file.close()
	if FileAccess.file_exists(path):
		error=DirAccess.copy_absolute(ProjectSettings.globalize_path(path),ProjectSettings.globalize_path(path+".bak"))
		if error!=OK:last_error="无法保存上一版备份";return error
	error=DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary),ProjectSettings.globalize_path(path))
	if error!=OK:last_error="无法替换测试布局";return error
	return OK
