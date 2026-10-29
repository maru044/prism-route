extends Node3D
## V6 branching leaf-cluster cards on actual wall boundaries. Shared art factory with preview.
const CLUSTERS=preload("res://scripts/world/wall_leaf_clusters.gd")
const ENTRY="res://assets/world/architecture_details_1029/preview_entry.json"
const MIRROR_LAYER=1<<19
var placements: Array[Dictionary]=[]
var batches: Array[MultiMeshInstance3D]=[]
var report: Dictionary={}
var options: Dictionary
var material: ShaderMaterial
var source: Dictionary
var texture: Texture2D
var mesh_cache: Dictionary={}
var cluster_scale:=1.35

func initialize(records: Array[Dictionary],settings: Dictionary) -> void:
    options=settings.cluster_projection;cluster_scale=float(settings.get("plant_scale",1.35))
    var entry: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(ENTRY))
    source=entry.sources[0];texture=load(str(source.texture));material=CLUSTERS.create_material(texture)
    var counts: Dictionary={"main":0,"ruin":0}
    var path_counts: Dictionary={"main":0,"ruin":0}
    var patch_counts: Dictionary={"main":0,"ruin":0}
    var rng:=RandomNumberGenerator.new();rng.seed=int(settings.plant_seed)
    for row: Dictionary in records:
        var mesh: MeshInstance3D=row.mesh
        if mesh.get_aabb().size.y<3.:continue
        var buckets: Dictionary={}
        var bottom: float=(mesh.global_transform*mesh.get_aabb()).position.y
        for path: Array in upper_paths(mesh):
            var length:=0.
            for segment: Dictionary in path:length+=segment.a.distance_to(segment.b)
            if length<float(options.min_path_m):continue
            path_counts[row.group]+=1
            var center:=minf(length*.5,rng.randf_range(4.,8.))
            while center<length:
                var middle:=sample_path(path,center)
                if in_scope(middle.point,row.group):
                    var seed_value:=rng.randi()
                    var layout:=CLUSTERS.create_layout(seed_value)
                    patch_counts[row.group]+=1
                    for leaf: Dictionary in layout:
                        var distance: float=center+float(leaf.x)
                        if distance<.45 or distance>length-.45:continue
                        var anchor:=sample_path(path,distance)
                        var top: Vector3=anchor.point
                        if not in_scope(top,row.group):continue
                        var bounds: Array=source.cell_bounds[int(leaf.cell)]
                        var size: float=leaf.size*cluster_scale
                        var leaf_bottom: float=top.y-float(leaf.depth)-(float(bounds[3])-float(bounds[1]))*size
                        if leaf_bottom<bottom+.12:continue
                        var normal: Vector3=anchor.normal
                        var right:=Vector3.UP.cross(normal).normalized()
                        var origin:=top+Vector3.UP*(-float(leaf.depth)+(float(bounds[1])-.5)*size)+normal*float(leaf.z)
                        var basis:=Basis(right,Vector3.UP,normal)*Basis(Vector3.BACK,float(leaf.angle))
                        var transform:=global_transform.affine_inverse()*Transform3D(basis.scaled(Vector3.ONE*size),origin)
                        var key: String=str(leaf.cell)+"_"+str(leaf.mirror)
                        if not buckets.has(key):buckets[key]=[]
                        var item: Dictionary={"top":top,"normal":normal,"position":origin,"size":size,"base_size":leaf.size,"depth":leaf.depth,"offset":leaf.z,"role":leaf.role,"path_id":leaf.path_id,"cell":int(leaf.cell),"mirror":bool(leaf.mirror),"group":row.group,"source_id":row.id,"seed":rng.randf(),"transform":transform}
                        buckets[key].append(item);placements.append(item);counts[row.group]+=1
                # Unequal patch intervals and independent seeds avoid repeating garlands.
                center+=rng.randf_range(12.,23.)
        for key: String in buckets:
            var rows: Array=buckets[key]
            rows.sort_custom(func(a,b):return a.seed<b.seed)
            var first: Dictionary=rows[0]
            if not mesh_cache.has(key):mesh_cache[key]=CLUSTERS.cluster_mesh(source,int(first.cell),bool(first.mirror))
            var mm:=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D;mm.mesh=mesh_cache[key];mm.instance_count=rows.size()
            for i in rows.size():mm.set_instance_transform(i,rows[i].transform)
            var node:=MultiMeshInstance3D.new();node.name="LeafClustersV6_"+row.group+"_"+str(batches.size());node.multimesh=mm;node.material_override=material;node.layers=1|MIRROR_LAYER
            node.visibility_range_end=float(settings.plant_draw_distance_m);node.visibility_range_end_margin=30.
            node.set_meta("placement_rows",rows);add_child(node);CLUSTERS.apply_palette(node);batches.append(node)
    report={"revision":entry.revision,"texture":texture.resource_path,"texture_sha256":FileAccess.get_sha256(texture.resource_path),"shader":material.shader.resource_path,"shader_sha256":FileAccess.get_sha256(material.shader.resource_path),"shared_factory":"res://scripts/world/wall_leaf_clusters.gd","factory_sha256":FileAccess.get_sha256("res://scripts/world/wall_leaf_clusters.gd"),"clusters":counts,"patches":patch_counts,"upper_paths":path_counts,"batches":batches.size(),"receiver_meshes":records.size(),"individual_leaves":0,"card_size_m":[1.45*cluster_scale,2.2*cluster_scale],"cluster_scale":cluster_scale,"placement":"connected growth sources, branching guide paths, body/connector/tip modules along actual upper boundaries"}
    print("WORLD_CLUSTER_LAYER_READY ",JSON.stringify(report))

func sample_path(path: Array,distance: float) -> Dictionary:
    var passed:=0.
    for edge: Dictionary in path:
        var length: float=edge.a.distance_to(edge.b)
        if distance<=passed+length:
            return {"point":edge.a.lerp(edge.b,clampf((distance-passed)/length,0.,1.)),"normal":edge.normal}
        passed+=length
    return {"point":path.back().b,"normal":path.back().normal}

func in_scope(point: Vector3,group: String) -> bool:
    if group=="ruin":return point.y>=float(options.ruin_min_height_m)
    var bounds: Array=options.cliff_native_bounds
    var native:=Vector2(point.x+1450.,1150.-point.z)
    return point.y>=float(options.cliff_min_height_m) and native.x>=bounds[0] and native.x<=bounds[2] and native.y>=bounds[1] and native.y<=bounds[3]

func point_key(p: Vector3) -> String:
    return "%d,%d,%d"%[roundi(p.x*100.),roundi(p.y*100.),roundi(p.z*100.)]

func upper_paths(mesh: MeshInstance3D) -> Array[Array]:
    var edges: Dictionary={}
    var transform: Transform3D=mesh.global_transform
    for surface in mesh.mesh.get_surface_count():
        var arrays:=mesh.mesh.surface_get_arrays(surface)
        var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
        var normals: PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
        var indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
        for triangle in range(0,indices.size(),3):
            var ids: Array[int]=[indices[triangle],indices[triangle+1],indices[triangle+2]]
            var normal: Vector3=(transform.basis*(normals[ids[0]]+normals[ids[1]]+normals[ids[2]])).normalized()
            if absf(normal.y)>.28:continue
            var points: Array[Vector3]=[transform*vertices[ids[0]],transform*vertices[ids[1]],transform*vertices[ids[2]]]
            for k in 3:
                var a:=points[k];var b:=points[(k+1)%3];var other:=points[(k+2)%3]
                var horizontal:=Vector2(a.x-b.x,a.z-b.z).length()
                if horizontal<.12 or absf(a.y-b.y)>horizontal*.25:continue
                var ka:=point_key(a);var kb:=point_key(b)
                var key: String=ka+"|"+kb if ka<kb else kb+"|"+ka
                if edges.has(key):edges[key].count+=1
                else:edges[key]={"a":a,"b":b,"normal":Vector3(normal.x,0,normal.z).normalized(),"ka":ka,"kb":kb,"count":1,"top":other.y<minf(a.y,b.y)-.02}
    var border: Array[Dictionary]=[];var adjacency: Dictionary={}
    for edge: Dictionary in edges.values():
        if edge.count!=1 or not edge.top:continue
        var index:=border.size();border.append(edge)
        for key: String in [edge.ka,edge.kb]:
            if not adjacency.has(key):adjacency[key]=[]
            adjacency[key].append(index)
    var used: Dictionary={};var paths: Array[Array]=[]
    for start in border.size():
        if used.has(start):continue
        var path: Array[Dictionary]=[border[start]];used[start]=true
        for append_end in [true,false]:
            while true:
                var end: Dictionary=path.back() if append_end else path.front()
                var key: String=end.kb if append_end else end.ka
                var found:=-1
                for index: int in adjacency[key]:
                    if not used.has(index) and border[index].normal.dot(end.normal)>.85:found=index;break
                if found<0:break
                var next: Dictionary=border[found].duplicate()
                var flip: bool=(next.ka!=key) if append_end else (next.kb!=key)
                if flip:
                    var p: Vector3=next.a;next.a=next.b;next.b=p
                    var text: String=next.ka;next.ka=next.kb;next.kb=text
                if append_end:path.append(next)
                else:path.push_front(next)
                used[found]=true
        paths.append(path)
    return paths

func bind_environment(biome: ShaderMaterial) -> void:
    CLUSTERS.bind_environment(material,biome)
func set_cluster_scale(value: float) -> void:
    cluster_scale=value
    for node: MultiMeshInstance3D in batches:
        var rows: Array=node.get_meta("placement_rows")
        for i in rows.size():
            var row: Dictionary=rows[i];var size: float=float(row.base_size)*value
            var bounds: Array=source.cell_bounds[int(row.cell)]
            var position: Vector3=row.top+Vector3.UP*(-float(row.depth)+(float(bounds[1])-.5)*size)+row.normal*float(row.offset)
            var basis: Basis=node.multimesh.get_instance_transform(i).basis.orthonormalized()
            node.multimesh.set_instance_transform(i,Transform3D(basis.scaled(Vector3.ONE*size),position))
            row.size=size;row.position=position
    report.cluster_scale=value;report.card_size_m=[1.45*value,2.2*value]
func apply_settings(enabled: bool,settings: Dictionary) -> void:
    if not is_equal_approx(cluster_scale,float(settings.get("plant_scale",1.35))):set_cluster_scale(float(settings.get("plant_scale",1.35)))
    for node: MultiMeshInstance3D in batches:
        var rows: Array=node.get_meta("placement_rows")
        var group_enabled: bool=bool(settings.get("cliff_plants_enabled",true)) if rows[0].group=="main" else bool(settings.get("ruin_plants_enabled",true))
        node.visible=enabled and bool(settings.plants_enabled) and group_enabled
        var count:=0
        for row: Dictionary in node.get_meta("placement_rows"):
            if float(row.seed)<=float(settings.plant_density):count+=1
        node.multimesh.visible_instance_count=count
        CLUSTERS.apply_palette(node,Color(str(settings.plant_color)))

func clear() -> void:
    for node: MultiMeshInstance3D in batches:
        if is_instance_valid(node):node.free()
    batches.clear();placements.clear();mesh_cache.clear()
func _exit_tree() -> void:clear()
