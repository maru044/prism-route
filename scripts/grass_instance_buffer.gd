extends RefCounted
## Godot 3D MultiMesh: three matrix rows (12 floats) + INSTANCE_CUSTOM (4).
## Kept separate from shared tree/1012 construction to limit regression scope.
static func append_blades(rng: RandomNumberGenerator,x: float,z: float,local_y: float,normal: Vector3,near: Array,far: Array,near_data: Array,far_data: Array,fraction: float) -> void:
	for blade in 4:
		var offset:=Vector2.ZERO
		if blade>0:offset=Vector2(rng.randf_range(-.34,.34),rng.randf_range(-.34,.34))
		var y_offset:=-(normal.x*offset.x+normal.z*offset.y)/normal.y
		var yaw:=rng.randf_range(0,TAU);var width:=rng.randf_range(.88,1.28);var height:=rng.randf_range(.90,1.16)
		var transform:=Transform3D(Basis(Vector3.UP,yaw).scaled(Vector3(width,height,width)),Vector3(x+offset.x,local_y+y_offset+.025,z+offset.y))
		var biome:=rng.randf();var value:=rng.randf();var threshold:=rng.randf()
		if threshold<fraction:
			transform.basis=transform.basis.scaled(Vector3(1.32,1.04,1.32))
			far.append(transform);far_data.append(Color(biome,value,threshold/fraction,1))
		else:
			near.append(transform);near_data.append(Color(biome,value,(threshold-fraction)/(1-fraction),0))

static func from_roots(roots: PackedFloat64Array,states: PackedInt64Array,fraction: float,mesh_bounds: AABB,seed_value: int) -> Dictionary:
	assert(roots.size()==states.size()*6)
	var near: Array=[];var far: Array=[];var near_data: Array=[];var far_data: Array=[]
	var rng:=RandomNumberGenerator.new();rng.seed=seed_value
	for i in states.size():
		rng.state=states[i];var at:=i*6
		append_blades(rng,roots[at],roots[at+1],roots[at+2],Vector3(roots[at+3],roots[at+4],roots[at+5]),near,far,near_data,far_data,fraction)
	var data: Dictionary={"near":pack(near,near_data),"far":pack(far,far_data),"bounds":[],"bytes":0}
	for group: String in ["near","far"]:
		var b:=bounds(data[group],mesh_bounds)
		data.bounds.append([b.position.x,b.position.y,b.position.z,b.size.x,b.size.y,b.size.z])
		data.bytes+=(data[group] as PackedFloat32Array).size()*4
	return data

static func pack(transforms: Array,custom: Array) -> PackedFloat32Array:
	assert(transforms.size()==custom.size())
	var buffer:=PackedFloat32Array();buffer.resize(transforms.size()*16)
	for i in transforms.size():
		var t: Transform3D=transforms[i];var c: Color=custom[i];var at:=i*16
		buffer[at]=t.basis.x.x;buffer[at+1]=t.basis.y.x;buffer[at+2]=t.basis.z.x;buffer[at+3]=t.origin.x
		buffer[at+4]=t.basis.x.y;buffer[at+5]=t.basis.y.y;buffer[at+6]=t.basis.z.y;buffer[at+7]=t.origin.y
		buffer[at+8]=t.basis.x.z;buffer[at+9]=t.basis.y.z;buffer[at+10]=t.basis.z.z;buffer[at+11]=t.origin.z
		buffer[at+12]=c.r;buffer[at+13]=c.g;buffer[at+14]=c.b;buffer[at+15]=c.a
	return buffer

static func bounds(buffer: PackedFloat32Array,mesh_bounds: AABB) -> AABB:
	if buffer.is_empty():return AABB()
	var low:=Vector3(INF,INF,INF);var high:=-low
	# Grass is yaw-only with modest positive scales. A conservative common
	# radius includes width/height variation, interaction bending and wind.
	var radius:=mesh_bounds.size.length()*2.0+1.5
	for i in range(0,buffer.size(),16):
		var p:=Vector3(buffer[i+3],buffer[i+7],buffer[i+11])
		low=low.min(p);high=high.max(p)
	return AABB(low,high-low).grow(radius)

static func make_node(node_name: String,mesh: Mesh,material: Material,buffer: PackedFloat32Array,end: float,aabb: AABB) -> MultiMeshInstance3D:
	var mm:=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D
	mm.use_custom_data=true;mm.mesh=mesh;mm.instance_count=buffer.size()/16
	mm.custom_aabb=aabb;mm.buffer=buffer
	var node:=MultiMeshInstance3D.new();node.name=node_name;node.multimesh=mm
	node.material_override=material;node.visibility_range_begin=0;node.visibility_range_end=end
	node.set_meta("lod_begin",0.0);node.set_meta("lod_end",end)
	return node
