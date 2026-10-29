extends RefCounted
## V6: modular painted clumps on connected, branching growth guides. No stem meshes.
const SHADER=preload("res://shaders/environment/wall_leaf_clusters_v6.gdshader")
const STYLE=preload("res://scripts/foliage_style.gd")
const PALETTE={"use_species_palette":1.,"species_palette_stage":3.,"species_deep_color":Color("4f7045"),"species_shadow_color":Color("64814b"),"species_mid_color":Color("8caa5c"),"species_light_color":Color("aabd71"),"species_accent_color":Color("8caa5c"),"species_accent_amount":0.,"species_seed":.29}
static func create_material(texture: Texture2D) -> ShaderMaterial:
    var material:=ShaderMaterial.new();material.shader=SHADER
    for pair: Array in [["albedo_texture",texture],["atlas_grid",Vector2(2,2)],["wind_strength",0.],["species_texture_detail",0.],["canopy_color_uniformity",0.],["foliage_backlight_fill",.035],["foliage_shadow_relief",.35],["species_art_direct_strength",.78],["wall_paint_strength",.8]]:material.set_shader_parameter(pair[0],pair[1])
    return material
static func apply_palette(node: GeometryInstance3D,tint: Color=Color.WHITE) -> void:
    for parameter: String in PALETTE:
        var value: Variant=PALETTE[parameter]
        node.set_instance_shader_parameter(parameter,value*tint if value is Color else value)
    node.set_instance_shader_parameter("use_tree_canopy_normal",0.)
static func bind_environment(material: ShaderMaterial,source: ShaderMaterial) -> void:
    if source!=null:STYLE.configure_green_biome(material,source)

static func create_layout(seed_value: int,target_clumps: int=64) -> Array[Dictionary]:
    return create_growth(seed_value,target_clumps).placements
static func create_growth(seed_value: int,target_clumps: int=64) -> Dictionary:
    var rng:=RandomNumberGenerator.new();rng.seed=seed_value
    var rows: Array[Dictionary]=[];var paths: Array[Dictionary]=[]
    var major:=Vector2(rng.randf_range(-3.3,-1.9),rng.randf_range(-.12,.1))
    var minor:=Vector2(rng.randf_range(2.8,3.8),rng.randf_range(-.08,.15))
    # Related shoots share a source. Each seed changes the guide lengths and branch sites.
    for colony in 2:
        var root: Vector2=major if colony==0 else minor
        var reach: float=1. if colony==0 else rng.randf_range(.50,.76)
        shoot(rows,paths,rng,root,root+Vector2(-rng.randf_range(1.6,2.2)*reach,rng.randf_range(.15,.55)),colony,-1,.8)
        shoot(rows,paths,rng,root,root+Vector2(rng.randf_range(1.5,2.4)*reach,rng.randf_range(.25,.8)),colony,-1,.9)
        var end:=root+Vector2(rng.randf_range(-.8,1.1)*reach,rng.randf_range(2.4,3.3)*reach)
        var main_id:=paths.size()
        shoot(rows,paths,rng,root,end,colony,-1,1.)
        var fork:=root.lerp(end,rng.randf_range(.3,.57))
        var side: float=-1. if rng.randf()>.5 else 1.
        shoot(rows,paths,rng,fork,fork+Vector2(side*rng.randf_range(.85,1.6)*reach,rng.randf_range(.7,1.4)*reach),colony,main_id,.75)
    if rows.size()>target_clumps:rows.resize(target_clumps)
    return {"placements":rows,"paths":paths}
static func shoot(rows: Array[Dictionary],paths: Array[Dictionary],rng: RandomNumberGenerator,start: Vector2,end: Vector2,colony: int,parent: int,weight: float) -> void:
    end.x=clampf(end.x,-5.25,5.25);end.y=minf(end.y,3.6)
    var delta:=end-start;var length:=delta.length()
    var bend:=Vector2(-delta.y,delta.x).normalized()*rng.randf_range(-.32,.32)
    var path_id:=paths.size();var steps:=maxi(2,ceili(length/.48))
    var points: Array[Vector2]=[]
    for i in steps+1:
        var t:=float(i)/steps
        var point:=start.lerp(end,t)+bend*sin(t*PI)
        points.append(point)
        if i==0 and parent>=0:continue
        var nearest:=INF
        for row: Dictionary in rows:nearest=minf(nearest,Vector2(row.x,row.depth).distance_to(point))
        if nearest<.31:continue
        var terminal: bool=t>.82 and delta.y>.5
        var role: String="tip" if terminal else ("connector" if parent>=0 or (t>.5 and delta.y<.8) else "body")
        var cell: int=2 if terminal else (1 if role=="connector" else (0 if rng.randf()>.5 else 3))
        var angle: float=clampf(-atan2(delta.x,maxf(.25,delta.y))*.45,-.65,.65)+rng.randf_range(-.12,.12)
        rows.append({"x":point.x,"depth":point.y,"size":rng.randf_range(1.65,2.15)*lerpf(.92,1.,weight),"angle":angle,"cell":cell,"mirror":rng.randf()>.5,"z":rng.randf_range(.025,.085),"role":role,"path_id":path_id,"colony":colony,"parent":parent})
    paths.append({"id":path_id,"parent":parent,"colony":colony,"points":points})

static func cluster_mesh(source: Dictionary,cell: int,mirror: bool,volume_lighting: bool=true) -> ArrayMesh:
    var vertices:=PackedVector3Array();var normals:=PackedVector3Array();var uvs:=PackedVector2Array();var indices:=PackedInt32Array();var colors:=PackedColorArray()
    var bounds: Array=source.cell_bounds[cell]
    var center:=Vector2((bounds[0]+bounds[2])*.5,(bounds[1]+bounds[3])*.5)
    if mirror:center.x=1.-center.x
    var radius:=Vector2(maxf(.1,(bounds[2]-bounds[0])*.5),maxf(.1,(bounds[3]-bounds[1])*.5))
    const N=12
    for y in N+1:
        for x in N+1:
            var uv:=Vector2(float(x)/N,float(y)/N)
            var q:=Vector2((uv.x-center.x)/radius.x,(center.y-uv.y)/radius.y)
            var z: float=.035*maxf(0.,1.-q.length_squared())
            vertices.append(Vector3(uv.x-.5,.5-uv.y,z))
            # A whole clump has an outward normal field like a tree crown.
            # A wall-wide crown would flatten every overlapping card together.
            normals.append(Vector3(q.x*.72,q.y*.72,1.).normalized() if volume_lighting else Vector3.BACK)
            var source_uv:=Vector2(1.-uv.x if mirror else uv.x,uv.y)
            uvs.append((source_uv+Vector2(cell%2,cell/2))*.5);colors.append(Color(0,.5,.5,1))
    for y in N:
        for x in N:
            var a:=y*(N+1)+x;var b:=a+1;var c:=a+N+1;var d:=c+1
            indices.append_array([a,b,c,b,d,c])
    var arrays:=[];arrays.resize(Mesh.ARRAY_MAX);arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_NORMAL]=normals;arrays[Mesh.ARRAY_TEX_UV]=uvs;arrays[Mesh.ARRAY_INDEX]=indices;arrays[Mesh.ARRAY_COLOR]=colors
    var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays);return mesh
