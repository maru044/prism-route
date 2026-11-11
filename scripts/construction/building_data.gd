extends RefCounted
## Authoritative local-metre records; derived rooms never own construction state.
const CELL:=2.0
const STORY:=3.6
var plot_id:=""
var definitions: Dictionary
var pieces: Dictionary={}
var rooms: Array[Dictionary]=[]
var serial:=0
var room_serial:=0
var revision:=0
var undo_stack: Array[Dictionary]=[]
var redo_stack: Array[Dictionary]=[]

func initialize(id: String,catalog: Dictionary) -> void:
	plot_id=id;definitions=catalog

static func cell_key(story: int,x: int,z: int) -> String:return "%d:%d:%d"%[story,x,z]
static func edge_key(row: Dictionary) -> String:return "%d:%d:%d:%d"%[int(row.story),roundi(row.x/2.),roundi(row.z/2.),int(row.rotation)%2]
static func local_position(row: Dictionary) -> Vector3:
	return Vector3(row.x,(0. if row.definition=="entry_ramp" else .2)+(int(row.story)+(1 if row.definition=="roof" else 0))*STORY,row.z)
static func yaw(row: Dictionary,kind: String) -> float:
	return -PI*.5*(int(row.rotation)%2) if kind=="edge" else PI*.5*int(row.rotation)

func floor_map(story: int) -> Dictionary:
	var result: Dictionary={}
	for row: Dictionary in pieces.values():
		if row.definition=="floor" and int(row.story)==story:result[Vector2i(roundi(row.x/2.),roundi(row.z/2.))]=row.id
	return result

func edges(story: int) -> Dictionary:
	var result: Dictionary={}
	for row: Dictionary in pieces.values():
		if definitions[row.definition].kind=="edge" and int(row.story)==story:result[edge_key(row)]=row
	return result

static func between(story: int,p: Vector2i,q: Vector2i) -> String:
	if p.x!=q.x:return "%d:%d:%d:1"%[story,maxi(p.x,q.x),p.y]
	return "%d:%d:%d:0"%[story,p.x,maxi(p.y,q.y)]

func footprint(row: Dictionary) -> PackedVector2Array:
	var definition: Dictionary=definitions[row.definition]
	var size: Array=definition.get("footprint",[2.,.18])
	var centered: bool=definition.kind=="furniture"
	var base:=Vector2(-float(size[0])*.5,-float(size[1])*.5) if centered else Vector2.ZERO
	var output:=PackedVector2Array()
	for offset: Vector2 in [base,base+Vector2(size[0],0),base+Vector2(size[0],size[1]),base+Vector2(0,size[1])]:
		var p:=Basis(Vector3.UP,yaw(row,definition.kind))*Vector3(offset.x,0,offset.y)
		output.append(Vector2(row.x+p.x,row.z+p.z))
	return output

func occupied_cells(row: Dictionary) -> Array[Vector2i]:
	var polygon:=footprint(row);var result: Array[Vector2i]=[]
	var lo:=polygon[0];var hi:=lo
	for p: Vector2 in polygon:lo=lo.min(p);hi=hi.max(p)
	for x in range(floori(lo.x/2.),ceili(hi.x/2.)):
		for z in range(floori(lo.y/2.),ceili(hi.y/2.)):
			var rect:=PackedVector2Array([Vector2(x*2+.001,z*2+.001),Vector2(x*2+1.999,z*2+.001),Vector2(x*2+1.999,z*2+1.999),Vector2(x*2+.001,z*2+1.999)])
			if not Geometry2D.intersect_polygons(polygon,rect).is_empty():result.append(Vector2i(x,z))
	return result

func wall_crosses(row: Dictionary,polygon: PackedVector2Array) -> bool:
	var a:=Vector2(row.x,row.z);var b:=a+(Vector2(2,0) if int(row.rotation)%2==0 else Vector2(0,2))
	# Only crossings through the interior; touching a furniture boundary is rejected
	# with a small wall-thickness inset by placement clearances at the caller.
	for t in [.05,.25,.5,.75,.95]:
		if Geometry2D.is_point_in_polygon(a.lerp(b,t),polygon):return true
	return false

func validate(row: Dictionary) -> String:
	if not definitions.has(row.definition):return "未知组件"
	if int(row.story)<0 or int(row.story)>1:return "验证版支持两层"
	var d: Dictionary=definitions[row.definition];var kind: String=d.kind
	if kind=="internal":return "内部零件不能单独放置"
	var floors:=floor_map(int(row.story))
	if kind=="edge":
		if not is_zero_approx(fposmod(row.x,2.)) or not is_zero_approx(fposmod(row.z,2.)):return "墙体必须对齐2米边界"
		var p:=Vector2i(roundi(row.x/2.),roundi(row.z/2.));var q:=p-(Vector2i(0,1) if int(row.rotation)%2==0 else Vector2i(1,0))
		if p.x<0 or p.y<0 or p.x>30 or p.y>30 or (int(row.rotation)%2==0 and p.x==30) or (int(row.rotation)%2==1 and p.y==30):return "超出地块"
		if not floors.has(p) and not floors.has(q):return "墙体旁需要楼板"
		if row.definition!="railing":
			for furniture: Dictionary in pieces.values():
				if definitions[furniture.definition].kind=="furniture" and int(furniture.story)==int(row.story) and wall_crosses(row,footprint(furniture)):return "墙体穿过家具"
		return ""
	if kind!="furniture" and (not is_zero_approx(fposmod(row.x,2.)) or not is_zero_approx(fposmod(row.z,2.))):return "结构必须对齐2米网格"
	for p: Vector2 in footprint(row):
		if p.x<-.001 or p.y<-.001 or p.x>60.001 or p.y>60.001:return "超出地块"
	var cells:=occupied_cells(row)
	if kind=="cell":
		var c:=Vector2i(roundi(row.x/2.),roundi(row.z/2.))
		if floors.has(c):return "此处已有地板"
		if int(row.story)>0 and not floor_map(int(row.story)-1).has(c):return "上层楼板需要下层基础"
		for other: Dictionary in pieces.values():
			if other.definition=="roof" and int(other.story)+1==int(row.story) and c in occupied_cells(other):return "先移除同高度的下层屋顶"
			if other.definition=="stairs" and int(other.story)+1==int(row.story) and c in occupied_cells(other):return "保留楼梯上方开口"
	elif kind=="cover":
		for c: Vector2i in cells:
			if not floors.has(c):return "屋顶下需要有效楼层"
			if floor_map(int(row.story)+1).has(c):return "上层楼板已经提供天花板，不能重叠屋顶"
		for other: Dictionary in pieces.values():
			if other.definition=="roof" and int(other.story)==int(row.story) and Vector2i(roundi(row.x/2.),roundi(row.z/2.)) in occupied_cells(other):return "已有屋顶"
	elif kind=="ramp":
		if int(row.story)!=0:return "入口坡道仅用于地面"
	elif kind=="connector":
		if int(row.story)!=0:return "验证版楼梯连接一二层"
		for c: Vector2i in cells:
			if not floors.has(c):return "楼梯需要完整底层支撑"
			if floor_map(1).has(c):return "先移除楼梯上方楼板"
		var top:=Basis(Vector3.UP,yaw(row,kind))*Vector3(1,0,-1)+Vector3(row.x,0,row.z)
		if not floor_map(1).has(Vector2i(floori(top.x/2.),floori(top.z/2.))):return "楼梯上端需要二层落脚楼板"
	else:
		for c: Vector2i in cells:
			if not floors.has(c):return "家具需要完整楼板支撑"
		var polygon:=footprint(row)
		for edge: Dictionary in edges(int(row.story)).values():
			if wall_crosses(edge,polygon):return "家具跨越墙体"
		for other: Dictionary in pieces.values():
			if int(other.story)!=int(row.story) or not definitions[other.definition].kind in ["furniture","connector"]:continue
			if not Geometry2D.intersect_polygons(polygon,footprint(other)).is_empty():return "与家具或楼梯重叠"
	return ""

func _remember() -> void:
	undo_stack.append(snapshot())
	if undo_stack.size()>100:undo_stack.pop_front()
	redo_stack.clear()

func place(definition: String,story: int,x: float,z: float,rotation: int=0,remember:=true) -> Dictionary:
	var row: Dictionary={"definition":definition,"story":story,"x":x,"z":z,"rotation":posmod(rotation,4)}
	var error:=validate(row)
	if not error.is_empty():return {"ok":false,"error":error}
	if remember:_remember()
	if definitions[definition].kind=="edge":
		for id: String in pieces.keys():
			if definitions[pieces[id].definition].kind=="edge" and edge_key(pieces[id])==edge_key(row):pieces.erase(id)
	serial+=1;row.id=plot_id+"_piece_%05d"%serial;row.open=false;pieces[row.id]=row;revision+=1
	return {"ok":true,"id":row.id}

func remove(id: String,remember:=true) -> Dictionary:
	if not pieces.has(id):return {"ok":false,"error":"没有选中组件"}
	var row: Dictionary=pieces[id]
	if row.definition=="floor":
		var c:=Vector2i(roundi(row.x/2.),roundi(row.z/2.));var story:=int(row.story)
		for other: Dictionary in pieces.values():
			if other.id==id:continue
			var kind: String=definitions[other.definition].kind
			if int(other.story)==story and kind in ["furniture","connector","cover"] and c in occupied_cells(other):return {"ok":false,"error":"先移除楼板上的家具、楼梯或屋顶"}
			if int(other.story)==story+1 and other.definition=="floor" and c in occupied_cells(other):return {"ok":false,"error":"先移除上层楼板"}
			if int(other.story)==story and kind=="edge":
				var p:=Vector2i(roundi(other.x/2.),roundi(other.z/2.));var q:=p-(Vector2i(0,1) if int(other.rotation)%2==0 else Vector2i(1,0))
				if c==p or c==q:return {"ok":false,"error":"先移除相邻墙体或栏杆"}
	if remember:_remember()
	pieces.erase(id);revision+=1;return {"ok":true}

func snapshot() -> Dictionary:return {"plot_id":plot_id,"serial":serial,"room_serial":room_serial,"pieces":pieces.duplicate(true),"rooms":rooms.duplicate(true)}
func restore(data: Dictionary) -> void:
	pieces=data.pieces.duplicate(true);rooms.assign(data.rooms.duplicate(true));serial=int(data.serial);room_serial=int(data.room_serial);revision+=1
func undo() -> bool:
	if undo_stack.is_empty():return false
	redo_stack.append(snapshot());restore(undo_stack.pop_back());return true
func redo() -> bool:
	if redo_stack.is_empty():return false
	undo_stack.append(snapshot());restore(redo_stack.pop_back());return true

func analyze() -> void:
	var old:=rooms.duplicate(true);var next: Array[Dictionary]=[]
	for story in range(2):
		var floors:=floor_map(story);var boundary:=edges(story);var seen: Dictionary={}
		var upper:=floor_map(story+1);var roofs: Dictionary={}
		for row: Dictionary in pieces.values():
			if row.definition=="roof" and int(row.story)==story:roofs[Vector2i(roundi(row.x/2.),roundi(row.z/2.))]=true
		var sorted_cells: Array=floors.keys();sorted_cells.sort_custom(func(a:Vector2i,b:Vector2i):return a.x<b.x or (a.x==b.x and a.y<b.y))
		for start: Vector2i in sorted_cells:
			if seen.has(start):continue
			var queue: Array[Vector2i]=[start];seen[start]=true;var cells: Array[String]=[];var sealed:=true;var covered:=true;var cursor:=0
			while cursor<queue.size():
				var p:=queue[cursor];cursor+=1;cells.append(cell_key(story,p.x,p.y));covered=covered and (upper.has(p) or roofs.has(p))
				for delta: Vector2i in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
					var q:=p+delta;var e: Dictionary=boundary.get(between(story,p,q),{});var def: Dictionary=definitions.get(e.get("definition",""),{})
					if floors.has(q):
						if not def.get("separator",false) and not seen.has(q):seen[q]=true;queue.append(q)
					elif not def.get("seals",false):sealed=false
			cells.sort();next.append({"id":"","story":story,"cells":cells,"sealed":sealed,"covered":covered,"exterior_connected":not sealed or not covered,"function":"generic","area":cells.size()*4.,"furniture":[]})
	# Open arches propagate exposure through the region graph; a floored terrace
	# is not sufficient evidence that the other side is indoors.
	var owner: Dictionary={}
	for i in next.size():
		for c: String in next[i].cells:owner[c]=i
	for iteration in range(next.size()):
		var changed:=false
		for row: Dictionary in pieces.values():
			if row.definition!="arch":continue
			var p:=Vector2i(roundi(row.x/2.),roundi(row.z/2.));var q:=p-(Vector2i(0,1) if int(row.rotation)%2==0 else Vector2i(1,0))
			var a: int=owner.get(cell_key(int(row.story),p.x,p.y),-1);var b: int=owner.get(cell_key(int(row.story),q.x,q.y),-1)
			if a<0 or b<0:continue
			if next[a].exterior_connected or next[b].exterior_connected:
				if not next[a].exterior_connected or not next[b].exterior_connected:changed=true
				next[a].exterior_connected=true;next[b].exterior_connected=true
		if not changed:break
	# Globally rank overlaps so one old identity cannot be inherited twice.
	var matches: Array[Dictionary]=[]
	for i in next.size():
		for j in old.size():
			var overlap:=0
			for c: String in next[i].cells:
				if c in old[j].cells:overlap+=1
			if overlap>0:matches.append({"n":i,"o":j,"weight":overlap})
	matches.sort_custom(func(a:Dictionary,b:Dictionary):return a.weight>b.weight or (a.weight==b.weight and (a.o<b.o or (a.o==b.o and a.n<b.n))))
	var used: Dictionary={}
	for match_row: Dictionary in matches:
		if next[match_row.n].id=="" and not used.has(match_row.o):next[match_row.n].id=old[match_row.o].id;used[match_row.o]=true
	for room: Dictionary in next:
		if room.id=="":room_serial+=1;room.id=plot_id+"_room_%04d"%room_serial
		room.kind="indoor" if room.sealed and room.covered and not room.exterior_connected else ("courtyard" if room.sealed and not room.covered else "open")
		for row: Dictionary in pieces.values():
			if definitions[row.definition].kind!="furniture" or int(row.story)!=int(room.story):continue
			var all_inside:=true
			for c: Vector2i in occupied_cells(row):
				if not cell_key(int(row.story),c.x,c.y) in room.cells:all_inside=false
			if all_inside:
				room.furniture.append(row.id)
				if row.definition=="bed":room.function="bedroom"
				elif row.definition=="desk" and room.function=="generic":room.function="work"
	rooms=next

func example() -> void:
	pieces.clear();rooms.clear();serial=0;room_serial=0
	for s in range(2):
		for x in range(20,34,2):
			for z in range(20,30,2):
				if s==1 and x==30 and z in [22,24,26]:continue
				assert(place("floor",s,x,z,0,false).ok)
	for x in range(20,34,2):
		assert(place("window" if x%4==0 else "wall",0,x,20,0,false).ok)
		assert(place("door" if x==26 else "wall",0,x,30,0,false).ok)
	for z in range(20,30,2):
		for x in [20,34]:assert(place("window" if z%4==0 else "wall",0,x,z,1,false).ok)
	for z in range(20,28,2):
		for x in [26,28]:assert(place("door" if z==24 else "wall",0,x,z,3 if x==28 and z==24 else 1,false).ok)
	for x in [20,22,24,28,30,32]:assert(place("arch" if x==30 else "wall",0,x,28,0,false).ok)
	for x in range(20,28,2):
		for z in [20,28]:assert(place("window" if z==20 else "wall",1,x,z,0,false).ok)
	for z in range(20,28,2):
		for x in [20,28]:assert(place("door" if x==28 and z==26 else "wall",1,x,z,1,false).ok)
	for x in range(20,28,2):
		for z in range(20,28,2):assert(place("roof",1,x,z,0,false).ok)
	for x in range(20,34,2):assert(place("railing",1,x,30,0,false).ok)
	for z in range(20,30,2):assert(place("railing",1,34,z,1,false).ok)
	for x in [28,30,32]:assert(place("railing",1,x,20,0,false).ok)
	for z in [22,24,26]:
		for x in [30,32]:assert(place("railing",1,x,z,1,false).ok)
	assert(place("railing",1,30,28,0,false).ok)
	assert(place("stairs",0,30,22,0,false).ok)
	assert(place("entry_ramp",0,26,30,0,false).ok)
	assert(place("bed",0,23,23,0,false).ok)
	assert(place("desk",1,24,24,2,false).ok)
	assert(place("chair",1,24,22,0,false).ok)
	undo_stack.clear();redo_stack.clear();analyze()
