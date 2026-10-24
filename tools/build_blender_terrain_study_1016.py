"""Blender-native continuous base and independent S landform study.

Run with Blender --background --factory-startup --python this_file.
Rhino solids are read-only shape/context references, never the new control cage.
"""
from pathlib import Path
from collections import defaultdict
import bpy,bmesh,json,math,time
import numpy as np
from mathutils import Vector,geometry
from mathutils.bvhtree import BVHTree
from mathutils.kdtree import KDTree

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'docs/concepts/blender_terrain_1016_v01'
CENTER=np.array([1100.,1050.,0.])
START=time.perf_counter()
DATA=json.loads((OUT/'rhino_input.json').read_text(encoding='utf-8'))
GUIDES=json.loads((ROOT/'docs/concepts/reference_1016_completion_v03/dense_guides.json').read_text())
REPORT={'source_document':DATA['source_document'],'center_world_xyz':CENTER.tolist(),
        'method':'Fresh continuous quad control cage plus independent S landform; Rhino patches only serve as shape references.',
        'bridge_openings':'Unchanged context topology; no new connecting faces or tunnels.'}

def collection(name,hide_render=False):
    c=bpy.data.collections.new(name);bpy.context.scene.collection.children.link(c);c.hide_render=hide_render;return c

def material(name,color,rough=.3,metal=0.,coat=0.):
    m=bpy.data.materials.new(name);m.diffuse_color=(*color,1);m.use_nodes=True
    p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(*color,1)
    p.inputs['Roughness'].default_value=rough;p.inputs['Metallic'].default_value=metal;p.inputs['Coat Weight'].default_value=coat
    return m

def object_mesh(name,verts,faces,c,mat=None):
    mesh=bpy.data.meshes.new(name+'_mesh');mesh.from_pydata(verts,[],faces);mesh.update()
    obj=bpy.data.objects.new(name,mesh);c.objects.link(obj)
    if mat:obj.data.materials.append(mat)
    for f in mesh.polygons:f.use_smooth=True
    return obj

def inside(points,loops):
    points=np.asarray(points);result=np.zeros(len(points),dtype=bool)
    for loop in loops:
        p=np.array(loop['points'])-CENTER[:2];hit=np.zeros(len(points),dtype=bool)
        # Even/odd on the complete polygon set preserves water holes.
        for a,b in zip(p,np.roll(p,-1,axis=0)):
            test=(a[1]>points[:,1])!=(b[1]>points[:,1])
            if abs(b[1]-a[1])<1e-12:continue
            cross=(b[0]-a[0])*(points[:,1]-a[1])/(b[1]-a[1])+a[0]
            hit^=test&(points[:,0]<cross)
        result^=hit
    return result

def nearest_line(points,poly):
    p=np.asarray(poly,float);a=p[:-1,:2];d=np.diff(p[:,:2],axis=0)
    all_d=[];all_h=[]
    for batch in np.array_split(points,max(1,len(points)//180)):
        v=batch[:,None]-a[None];t=np.clip((v*d[None]).sum(2)/np.maximum((d*d).sum(1),1e-15),0,1)
        dist2=((v-t[:,:,None]*d[None])**2).sum(2);j=dist2.argmin(1);ii=np.arange(len(batch))
        all_d.extend(np.sqrt(dist2[ii,j]));all_h.extend(p[j,2]*(1-t[ii,j])+p[j+1,2]*t[ii,j])
    return np.array(all_d),np.array(all_h)

def top_tree(records):
    vertices=[];faces=[];points=[]
    for r in records:
        p=np.asarray(r['vertices'])-CENTER;offset=len(vertices);vertices.extend(p.tolist())
        for t in r['triangles']:
            a,b,c=p[t]
            if np.cross(b-a,c-a)[2]>.000001:
                faces.append(tuple(offset+i for i in t));points.extend(p[t].tolist())
    tree=BVHTree.FromPolygons([Vector(p)for p in vertices],faces,all_triangles=True)
    kd=KDTree(len(points))
    for i,p in enumerate(points):kd.insert(p,i)
    kd.balance()
    return tree,kd

def sample_tree(xy,tree,kd=None,default=0.):
    out=[];hits=[]
    for x,y in xy:
        p,normal,face,d=tree.ray_cast(Vector((float(x),float(y),130)),Vector((0,0,-1)),200)
        ok=p is not None and p.z>-2
        if ok:z=p.z
        elif kd:
            q,idx,dist=kd.find(Vector((float(x),float(y),0)))
            z=q.z if dist<45 else default
        else:z=default
        out.append(z);hits.append(ok)
    return np.array(out),np.array(hits)

def topology(loops,spacing,clip_loops=None):
    p=np.vstack([np.array(r['points'])-CENTER[:2]for r in loops])
    lo=p.min(0);hi=p.max(0)
    xx,yy=np.meshgrid(np.arange(math.ceil(lo[0]/spacing)*spacing,hi[0],spacing),
                      np.arange(math.ceil(lo[1]/spacing)*spacing,hi[1],spacing))
    grid=np.c_[xx.ravel(),yy.ravel()];mask=inside(grid,loops)
    if clip_loops:mask&=inside(grid,clip_loops)
    points=grid[mask].tolist();edges=[]
    for loop in loops+(clip_loops or []):
        q=np.array(loop['points'])-CENTER[:2];start=len(points);points.extend(q.tolist())
        edges.extend((start+i,start+(i+1)%len(q))for i in range(len(q)))
    verts,_,faces,*_=geometry.delaunay_2d_cdt([Vector(p)for p in points],edges,[],0,.0002,False)
    v=np.array([list(p)for p in verts]);centers=np.array([v[list(f)].mean(0)for f in faces])
    keep=inside(centers,loops)
    if clip_loops:keep&=inside(centers,clip_loops)
    mesh=bpy.data.meshes.new('flat_cage_work');mesh.from_pydata(np.c_[v,np.zeros(len(v))].tolist(),[],[f for f,k in zip(faces,keep)if k]);mesh.update()
    bm=bmesh.new();bm.from_mesh(mesh)
    bmesh.ops.delete(bm,geom=[v for v in bm.verts if not v.link_faces],context='VERTS')
    bmesh.ops.join_triangles(bm,faces=list(bm.faces),angle_face_threshold=.001,angle_shape_threshold=1.2,
                             cmp_seam=False,cmp_sharp=False,cmp_uvs=False,cmp_vcols=False,cmp_materials=False)
    bm.to_mesh(mesh);bm.free();mesh.update()
    xy=np.array([[v.co.x,v.co.y]for v in mesh.vertices]);faces=[list(f.vertices)for f in mesh.polygons]
    edge_faces=defaultdict(list)
    for f in faces:
        for a,b in zip(f,f[1:]+f[:1]):edge_faces[tuple(sorted((a,b)))].append((a,b))
    boundary=[v[0]for v in edge_faces.values()if len(v)==1]
    bpy.data.meshes.remove(mesh)
    return xy,faces,boundary

def fair_z(z,faces,boundary,iterations,rate=.4):
    adjacency=[set()for _ in z]
    for f in faces:
        for a,b in zip(f,f[1:]+f[:1]):adjacency[a].add(b);adjacency[b].add(a)
    pinned=set(i for e in boundary for i in e)
    for _ in range(iterations):
        old=z.copy()
        for i,nb in enumerate(adjacency):
            if nb and i not in pinned:z[i]=old[i]*(1-rate)+old[list(nb)].mean()*rate
    return z

def fair_boundary(z,boundary):
    adjacency=defaultdict(set)
    for a,b in boundary:adjacency[a].add(b);adjacency[b].add(a)
    for _ in range(8):
        old=z.copy()
        for i,nb in adjacency.items():z[i]=old[i]*.75+old[list(nb)].mean()*.25
    return z

def solid_cage(name,xy,z,faces,boundary,c,mat):
    n=len(xy);ids=sorted(set(i for e in boundary for i in e));ring={i:n+j for j,i in enumerate(ids)}
    verts=np.c_[xy,z].tolist()
    verts.extend([float(xy[i,0]),float(xy[i,1]),float(max(z[i]-.9,-3))]for i in ids)
    bottom=len(verts);verts.extend(np.c_[xy,np.full(n,-8.)].tolist())
    allfaces=list(faces)+[[bottom+i for i in reversed(f)]for f in faces]
    for a,b in boundary:
        allfaces.append([b,a,ring[a],ring[b]])
        allfaces.append([ring[b],ring[a],bottom+a,bottom+b])
    obj=object_mesh(name,verts,allfaces,c,mat)
    bm=bmesh.new();bm.from_mesh(obj.data);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(obj.data);bm.free()
    sub=obj.modifiers.new('可调细分_保持低密度控制网','SUBSURF');sub.subdivision_type='CATMULL_CLARK';sub.levels=1;sub.render_levels=2
    obj['source_role']='Editable master mesh; subdivision is kept unapplied.'
    obj['top_cage_vertices']=n;obj['original_rhino_patches_required_for_editing']=False
    return obj

def height_control(name,xy,z,faces,controls,spacing):
    """Regular quad height cage avoids pinching from coastal trim topology."""
    source=bpy.data.meshes.new('height_interpolation_work')
    source.from_pydata(np.c_[xy,np.zeros(len(xy))].tolist(),[],faces);source.update();source.calc_loop_triangles()
    tris=[tuple(t.vertices)for t in source.loop_triangles]
    tree=BVHTree.FromPolygons([v.co.copy()for v in source.vertices],tris,all_triangles=True)
    lo=xy.min(0)-spacing*3;hi=xy.max(0)+spacing*3
    xs=np.arange(lo[0],hi[0]+spacing*.5,spacing);ys=np.arange(lo[1],hi[1]+spacing*.5,spacing)
    verts=[]
    for x in xs:
        for y in ys:
            p,n,fi,d=tree.find_nearest(Vector((float(x),float(y),0)))
            ids=tris[fi];a,b,c=[source.vertices[i].co for i in ids]
            bary=geometry.barycentric_transform(p,a,b,c,Vector((0,0,float(z[ids[0]]))),
                                                Vector((0,0,float(z[ids[1]]))),Vector((0,0,float(z[ids[2]]))))
            verts.append((float(x),float(y),bary.z))
    nv=len(ys);quads=[[i*nv+j,(i+1)*nv+j,(i+1)*nv+j+1,i*nv+j+1]for i in range(len(xs)-1)for j in range(nv-1)]
    obj=object_mesh(name,verts,quads,controls)
    sub=obj.modifiers.new('高度控制面_平滑','SUBSURF');sub.levels=2;sub.render_levels=2
    obj.hide_render=True;obj.hide_set(True);obj['role']='Editable regular quad height field. Move vertices in Z with proportional editing.'
    bpy.data.meshes.remove(source)
    return obj

def add_heightfield(owner,xy,z,faces,boundary,controls,spacing,base_control=None):
    control=height_control(owner.name+'_高度控制面',xy,z,faces,controls,spacing)
    n=len(xy);ring_count=len(set(i for e in boundary for i in e));bottom=n+ring_count
    attr=owner.data.attributes.new('height_weight','FLOAT','POINT')
    for i,v in enumerate(owner.data.vertices):
        v.co.z=0 if i<n else -.9 if i<bottom else -8
        attr.data[i].value=1. if i<bottom else 0.
    group=bpy.data.node_groups.new(owner.name+'_连续高度场','GeometryNodeTree')
    group.interface.new_socket(name='Geometry',in_out='INPUT',socket_type='NodeSocketGeometry')
    group.interface.new_socket(name='Geometry',in_out='OUTPUT',socket_type='NodeSocketGeometry')
    nodes=group.nodes;links=group.links
    inp=nodes.new('NodeGroupInput');out=nodes.new('NodeGroupOutput');pos=nodes.new('GeometryNodeInputPosition')
    sep=nodes.new('ShaderNodeSeparateXYZ');links.new(pos.outputs['Position'],sep.inputs[0])
    start=nodes.new('ShaderNodeCombineXYZ');links.new(sep.outputs['X'],start.inputs['X']);links.new(sep.outputs['Y'],start.inputs['Y']);start.inputs['Z'].default_value=130
    def ray(obj):
        info=nodes.new('GeometryNodeObjectInfo');info.transform_space='RELATIVE';info.inputs['Object'].default_value=obj
        r=nodes.new('GeometryNodeRaycast');r.data_type='FLOAT';r.inputs['Ray Direction'].default_value=(0,0,-1);r.inputs['Ray Length'].default_value=300
        links.new(info.outputs['Geometry'],r.inputs['Target Geometry']);links.new(start.outputs[0],r.inputs['Source Position'])
        q=nodes.new('ShaderNodeSeparateXYZ');links.new(r.outputs['Hit Position'],q.inputs[0]);return q.outputs['Z']
    height=ray(control)
    if base_control:
        add=nodes.new('ShaderNodeMath');add.operation='ADD';links.new(height,add.inputs[0]);links.new(ray(base_control),add.inputs[1]);height=add.outputs[0]
    named=nodes.new('GeometryNodeInputNamedAttribute');named.data_type='FLOAT';named.inputs['Name'].default_value='height_weight'
    mul=nodes.new('ShaderNodeMath');mul.operation='MULTIPLY';links.new(height,mul.inputs[0]);links.new(named.outputs['Attribute'],mul.inputs[1])
    offset=nodes.new('ShaderNodeCombineXYZ');links.new(mul.outputs[0],offset.inputs['Z'])
    setpos=nodes.new('GeometryNodeSetPosition');links.new(inp.outputs['Geometry'],setpos.inputs['Geometry']);links.new(offset.outputs[0],setpos.inputs['Offset']);links.new(setpos.outputs['Geometry'],out.inputs['Geometry'])
    mod=owner.modifiers.new('连续高度场_细分后求形','NODES');mod.node_group=group
    owner['height_control_object']=control.name
    owner['edit_instructions']='Edit footprint XY on this cage; edit elevations on the named regular height control surface.'
    if base_control:owner['follows_base_height_control']=base_control.name
    owner.data.update();bpy.context.view_layer.update()
    return control

def evaluated_tree(obj):
    bpy.context.view_layer.update();dg=bpy.context.evaluated_depsgraph_get();ev=obj.evaluated_get(dg)
    mesh=ev.to_mesh();mesh.calc_loop_triangles()
    verts=[v.co.copy()for v in mesh.vertices];faces=[tuple(t.vertices)for t in mesh.loop_triangles if t.normal.z>.05]
    result=BVHTree.FromPolygons(verts,faces,all_triangles=True);ev.to_mesh_clear();return result

def stats(obj):
    def check(mesh):
        bm=bmesh.new();bm.from_mesh(mesh)
        bad=sum(not e.is_manifold for e in bm.edges);components=0;unseen=set(bm.verts)
        while unseen:
            components+=1;todo=[unseen.pop()]
            while todo:
                for edge in todo.pop().link_edges:
                    for v in edge.verts:
                        if v in unseen:unseen.remove(v);todo.append(v)
        value={'vertices':len(bm.verts),'faces':len(bm.faces),'nonmanifold_edges':bad,'components':components,
               'quads':sum(len(f.verts)==4 for f in bm.faces),'z_range':[min(v.co.z for v in bm.verts),max(v.co.z for v in bm.verts)]}
        bm.free();return value
    result={'control':check(obj.data)}
    ev=obj.evaluated_get(bpy.context.evaluated_depsgraph_get());mesh=ev.to_mesh();result['evaluated']=check(mesh);ev.to_mesh_clear()
    return result

def camera(name,location,target,lens=44):
    d=bpy.data.cameras.new(name);o=bpy.data.objects.new(name,d);bpy.context.scene.collection.objects.link(o)
    o.location=Vector(location)-Vector(CENTER);q=(Vector(target)-Vector(location)).to_track_quat('-Z','Y');o.rotation_euler=q.to_euler()
    d.lens=lens;d.clip_end=12000;d.clip_start=.3;return o

def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    native=collection('01_重建地形_可编辑基底');context=collection('02_原场景拼接参照');refs=collection('90_Rhino旧地形_仅对照',True);guides=collection('03_参考主曲线',True);controls=collection('04_高度控制面_编辑源',True)
    white=material('暖白建筑涂层_柔和高光',(.85,.82,.75),.28,0,.14)
    green=material('保留草稿地形_灰绿',(.37,.43,.27),.78)
    road=material('道路_深灰',(.055,.065,.075),.78)
    sand=material('岸滩_暖浅沙',(.65,.55,.36),.9)
    water=material('海面',(.035,.28,.36),.18,.05,.15)
    source_records=[r for r in DATA['objects']if r['study_source']]
    for r in DATA['objects']:
        path=r['layer']
        if path=='水面' or '浅水示意' in path:continue
        ref=r['study_source'];c=refs if ref else context
        mat=road if '道路' in path or path=='路面' else sand if path=='沙滩' else green if path=='地形' or '裁切后的原地形' in path else white
        p=(np.array(r['vertices'])-CENTER).tolist();o=object_mesh(r['name'],p,r['triangles'],c,mat)
        o['rhino_id']=r['id'];o['rhino_layer']=path
        # Imported context stays a reference; do not model with these triangles.
        if not ref:
            adjacency=defaultdict(list)
            for f in o.data.polygons:
                for e in f.edge_keys:adjacency[tuple(sorted(e))].append(f.normal.copy())
            for e in o.data.edges:
                normals=adjacency[tuple(sorted(e.vertices))]
                e.use_edge_sharp=len(normals)==2 and normals[0].dot(normals[1])<.7
    for label,points in GUIDES.items():
        p=np.asarray(points)[::max(1,len(points)//90),:3]-CENTER
        d=bpy.data.curves.new(label,'CURVE');d.dimensions='3D';s=d.splines.new('POLY');s.points.add(len(p)-1)
        for q,co in zip(s.points,p):q.co=(*co,1)
        o=bpy.data.objects.new(label,d);guides.objects.link(o);o.hide_set(True)
        o['role']='Original design guide. C1 and C3 jointly define the S landform high edges.'
    main_records=[r for r in source_records if not r['feature_source']]
    main_tree,main_kd=top_tree(main_records);s_tree,s_kd=top_tree([r for r in source_records if r['feature_source']])
    xy,faces,boundary=topology(DATA['base_footprints'],20.)
    z,hits=sample_tree(xy,main_tree,main_kd,.15);z=np.maximum(z,0)
    z=fair_boundary(z,boundary)
    # Fallback broad folds keep the uncovered interior a complete ground mass.
    world=xy+CENTER[:2]
    for label,width in [('C5',80.),('C6',65.)]:
        dist,h=nearest_line(world,GUIDES[label]);fold=h*np.exp(-(dist/width)**2)
        z=np.maximum(z,fold*.65)
    z=fair_z(z,faces,boundary,7,.42)
    for label in ['C5','C6']:
        dist,h=nearest_line(world,GUIDES[label]);w=np.exp(-(dist/22.)**2)
        z=z*(1-w)+h*w
    base=solid_cage('基础地形_连续控制网',xy,z,faces,boundary,native,white)
    base_control=add_heightfield(base,xy,z,faces,boundary,controls,20.)
    base['world_grid_spacing_m']=20.;base['replaces_source_objects']=','.join(DATA['source_ids'])
    base_tree=evaluated_tree(base)
    fxy,ffaces,fboundary=topology(DATA['feature_footprints'],15.,DATA['base_footprints'])
    fworld=fxy+CENTER[:2];ground,_=sample_tree(fxy,base_tree,None,.2)
    raw,hit=sample_tree(fxy,s_tree,s_kd,0.)
    # Sample original high landform as a coarse shape reference, then fair it
    # on a fresh cage. The old Patch surfaces are not carried into the asset.
    raw=np.maximum(raw,ground)
    raw=fair_z(raw,ffaces,fboundary,4,.38)
    for label in ['C1','C3']:
        dist,h=nearest_line(fworld,GUIDES[label]);w=np.exp(-(dist/15.)**2)
        raw=raw*(1-w)+np.maximum(h,ground)*w
    ring=np.array([r['points']for r in DATA['feature_footprints']],dtype=object)
    borderdist=np.full(len(fxy),1e20)
    for loop in DATA['feature_footprints']:
        p=np.array(loop['points']);p=np.c_[p,np.zeros(len(p))];p=np.vstack([p,p[0]])
        d,_=nearest_line(fworld,p);borderdist=np.minimum(borderdist,d)
    t=np.clip(borderdist/24.,0,1);fade=t*t*t*(10+t*(-15+6*t))
    fz=ground+np.maximum(raw-ground,0)*fade-.20
    fz=np.minimum(fz,35.)
    feature=solid_cage('独立地形_S形隆起',fxy,fz,ffaces,fboundary,native,white)
    feature_control=add_heightfield(feature,fxy,fz-ground,ffaces,fboundary,controls,12.,base_control)
    feature['role']='Independent editable landform over the continuous base, not another patch of the base.'
    feature['guide_curves']='C1,C3';feature['skirt_blend_width_m']=24.
    # Adapt only existing low road vertices. Neither bridge topology nor its
    # elevation is changed, and no missing bridge segment is manufactured.
    feature_tree=evaluated_tree(feature);adapted=0;road_objs=0;road_comparisons=[]
    record_by_id={r['id']:r for r in DATA['objects']}
    for o in context.objects:
        path=o.get('rhino_layer','')
        if path!='路面' and '1016_恢复道路_'not in path:continue
        changed=0
        for v in o.data.vertices:
            if v.co.z>32:continue
            if not inside(np.array([[v.co.x,v.co.y]]),DATA['base_footprints'])[0]:continue
            h1,_=sample_tree(np.array([[v.co.x,v.co.y]]),base_tree,None,-8)
            h2,_=sample_tree(np.array([[v.co.x,v.co.y]]),feature_tree,None,-8)
            if max(h1[0],h2[0])>-1:v.co.z=max(h1[0],h2[0])+.13;changed+=1
        if changed:
            o.data.update();adapted+=changed;road_objs+=1;o['study_adaptation']='Low road vertices draped to the rebuilt terrain; original face connectivity retained.'
            r=record_by_id[o['rhino_id']]
            original=object_mesh('旧版道路对照_'+o.name,(np.array(r['vertices'])-CENTER).tolist(),r['triangles'],refs,road)
            road_comparisons.append((o,original))
    # One ocean surface replaces overlapping CAD preview water sheets.
    ocean=object_mesh('海面_场景参照',[[-16000,-16000,-.18],[16000,-16000,-.18],[16000,16000,-.18],[-16000,16000,-.18]],[[0,1,2,3]],context,water)
    scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=40;scene.cycles.use_denoising=True
    try:
        prefs=bpy.context.preferences.addons['cycles'].preferences;prefs.compute_device_type='OPTIX';prefs.refresh_devices()
        for d in prefs.devices:d.use=d.type=='OPTIX'
        scene.cycles.device='GPU'
    except Exception:scene.cycles.device='CPU'
    scene.world=bpy.data.worlds.new('柔和天空');scene.world.use_nodes=True
    scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.63,.72,.83,1)
    scene.world.node_tree.nodes['Background'].inputs[1].default_value=.45
    sun=bpy.data.lights.new('Sun','SUN');sun.energy=3.5;sun.angle=.10;sun.color=(1.,.94,.84)
    so=bpy.data.objects.new('Sun',sun);scene.collection.objects.link(so);so.rotation_euler=(math.radians(50),math.radians(-20),math.radians(-28))
    light=bpy.data.lights.new('大面积柔光','AREA');light.energy=1200000;light.shape='RECTANGLE';light.size=1500;light.size_y=700
    lo=bpy.data.objects.new('大面积柔光',light);scene.collection.objects.link(lo);lo.location=Vector((900,1100,1200))-Vector(CENTER)
    lo.rotation_euler=(Vector((1300,1100,0))-Vector((900,1100,1200))).to_track_quat('-Z','Y').to_euler()
    scene.view_settings.view_transform='AgX'
    scene.render.resolution_x=1600;scene.render.resolution_y=1050;scene.render.resolution_percentage=100
    scene.render.image_settings.file_format='PNG';scene.render.film_transparent=False
    cams=[camera('总览_与现有场景拼接',(2720,2100,1600),(1120,1040,10),44),
          camera('地形低视角',(2240,1610,430),(1270,1030,12),45),
          camera('独立S地形_近景',(2140,1560,280),(1510,1180,18),45),
          camera('基础地形_整体轮廓',(2450,2070,2300),(1120,1050,5),48)]
    scene.camera=cams[0]
    bpy.context.view_layer.update()
    REPORT['terrain']={o.name:stats(o)for o in [base,feature]}
    REPORT['low_road_adaptation']={'objects':road_objs,'vertices':adapted,'bridge_faces_added':0}
    REPORT['context_objects']=len(context.objects);REPORT['build_seconds']=time.perf_counter()-START
    REPORT['height_controls']={o.name:{'vertices':len(o.data.vertices),'faces':len(o.data.polygons)}for o in [base_control,feature_control]}
    for o in [base,feature]:
        if REPORT['terrain'][o.name]['evaluated']['nonmanifold_edges']:raise RuntimeError('Nonmanifold evaluated terrain '+o.name)
    bpy.ops.object.select_all(action='DESELECT');base.select_set(True);bpy.context.view_layer.objects.active=base
    for screen in bpy.data.screens:
        for area in screen.areas:
            if area.type=='VIEW_3D':area.spaces.active.region_3d.view_perspective='CAMERA';area.spaces.active.clip_end=15000
    refs.hide_viewport=True;guides.hide_viewport=True
    instructions=bpy.data.texts.new('README_地形试验')
    instructions.write('本文件含连续基础地形和独立S形隆起两个可编辑资产。\n01集合中的网格控制平面轮廓，保持细分和高度场修改器未应用。\n04集合中的两个规则四边形高度面控制高程；取消隐藏后进入编辑模式，用比例编辑沿Z调整。\n高度场在细分后求值，以避免裁剪边缘的不规则拓扑造成密集夹痕；S隆起会跟随基础高度面变化。\n90集合为原Rhino地形及原低位道路对照，默认禁用显示和渲染。\n03集合中的C1/C3等曲线是设计参考，尚未自动绑定至控制网。\n两版渲染使用相同相机、材质和光照；00为Rhino原版，01为Blender重建。\n本次没有新建隧道，也没有补上未来桥梁的断开。\n重跑生成脚本会重建试验文件，修改过的blend请另存，避免覆盖手工调整。\n世界坐标中心偏移为(1100,1050,0)米。')
    scene['source_world_center']=CENTER.tolist();scene['study_notes']='Two editable terrain assets; original Rhino terrain hidden in reference collection. No new tunnels. Planned bridge gaps preserved.'
    blend=OUT/'terrain_1016_blender_study.blend';bpy.ops.wm.save_as_mainfile(filepath=str(blend))
    feature.select_set(True)
    bpy.ops.export_scene.gltf(filepath=str(OUT/'terrain_1016_blender_study.glb'),export_format='GLB',use_selection=True,export_apply=True)
    refs.hide_viewport=False;refs.hide_render=False;base.hide_render=True;feature.hide_render=True
    for new,original in road_comparisons:new.hide_render=True
    scene.camera=cams[0];scene.render.filepath=str(OUT/'00_rhino_baseline.png');bpy.ops.render.render(write_still=True)
    refs.hide_viewport=True;refs.hide_render=True;base.hide_render=False;feature.hide_render=False
    for new,original in road_comparisons:new.hide_render=False
    for i,cam in enumerate(cams[:3]):
        scene.camera=cam;scene.render.filepath=str(OUT/('0%d_%s.png'%(i+1,'overview'if i==0 else 'low_view')))
        bpy.ops.render.render(write_still=True)
    scene.camera=cams[0]
    feature.select_set(False)
    bpy.ops.wm.save_as_mainfile(filepath=str(blend))
    REPORT['total_seconds']=time.perf_counter()-START
    (OUT/'build_report.json').write_text(json.dumps(REPORT,indent=2,ensure_ascii=False),encoding='utf-8')
    print('TERRAIN_STUDY_COMPLETE '+json.dumps(REPORT,ensure_ascii=False))

if __name__=='__main__':main()
