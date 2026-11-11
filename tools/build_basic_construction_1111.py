# -*- coding: utf-8 -*-
"""Rhino: export_source() builds the kit in memory. Python: --package.
No document objects, terrain changes, .3dm copies or component backup files.
"""
import os, io, json, math
ROOT=os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT=os.path.join(ROOT,'assets','construction','basic_kit')
CACHE=os.path.join(ROOT,'.current_map_build','construction_1111')

def dump(path,value):
    if not os.path.isdir(os.path.dirname(path)):os.makedirs(os.path.dirname(path))
    with io.open(path,'w',encoding='utf-8') as f:f.write(json.dumps(value,ensure_ascii=False,indent=2))

def export_source():
    import Rhino, Rhino.Geometry as G, scriptcontext as sc, System
    before=sc.doc.Modified;objects=[];definitions={}
    def component(key,label,kind,parts,collisions=None,**extra):
        definitions[key]=dict(label=label,kind=kind,collisions=collisions if collisions is not None else [dict(shape='box',size=s,position=p) for s,p,m in parts if m!='glass'],**extra)
        for index,(size,center,material) in enumerate(parts):
            x,y,z=center;w,h,d=size
            box=G.BoundingBox(G.Point3d(x-w/2,-z-d/2,y-h/2),G.Point3d(x+w/2,-z+d/2,y+h/2))
            mesh=G.Mesh.CreateFromBox(box,1,1,1);mesh.Unweld(0.,True);mesh.Faces.ConvertQuadsToTriangles();mesh.Normals.ComputeNormals()
            vertices=[[float(v.X),float(v.Z),-float(v.Y)] for v in mesh.Vertices]
            normals=[[float(n.X),float(n.Z),-float(n.Y)] for n in mesh.Normals]
            uvs=[]
            for p,n in zip(vertices,normals):
                axis=max(range(3),key=lambda k:abs(n[k]));uvs.append([p[0],p[2]] if axis==1 else ([p[0],p[1]] if axis==2 else [p[2],p[1]]))
            objects.append(dict(name=key+'__'+str(index),component=key,material=material,vertices=vertices,normals=normals,uvs=uvs,indices=[i for f in mesh.Faces for i in [f.A,f.B,f.C]]))
    component('floor',u'地板 / 楼板','cell',[([2,.2,2],[1,-.1,1],'timber')],footprint=[2,2])
    component('roof',u'平屋顶','cover',[([2,.2,2],[1,-.1,1],'roof')],footprint=[2,2])
    component('wall',u'实墙','edge',[([2,3.4,.18],[1,1.7,0],'wall')],separator=True,seals=True,passable=False)
    sides=[([.3,3.4,.18],[.15,1.7,0],'wall'),([.3,3.4,.18],[1.85,1.7,0],'wall')]
    header=([1.4,1.,.18],[1,2.9,0],'wall')
    component('door',u'门墙','edge',sides+[header],separator=True,seals=True,passable=True,opening=[1.4,2.4])
    component('arch',u'开放门洞','edge',sides+[header],separator=True,seals=False,passable=True,opening=[1.4,2.4])
    window=sides+[([1.4,.9,.18],[1,.45,0],'wall'),([1.4,1.,.18],[1,2.9,0],'wall'),
        ([1.4,.055,.22],[1,.925,0],'timber'),([1.4,.055,.22],[1,2.375,0],'timber'),
        ([.055,1.5,.22],[.325,1.65,0],'timber'),([.055,1.5,.22],[1.675,1.65,0],'timber'),
        ([1.3,1.4,.02],[1,1.65,0],'glass')]
    component('window',u'窗墙','edge',window,collisions=[dict(shape='box',size=[2,3.4,.18],position=[1,1.7,0])],separator=True,seals=True,passable=False)
    component('door_leaf',u'门扇','internal',[([1.36,2.37,.07],[.68,1.2,0],'timber')])
    stairs=[]
    for i in range(24):
        h=(i+1)*.15;stairs.append(([2,h,.25],[1,h/2,6-(i+.5)*.25],'timber'))
    component('stairs',u'直跑楼梯 2×6米','connector',stairs,collisions=[dict(shape='wedge',width=2.,length=6.,height=3.6)],footprint=[2,6],rise=3.6)
    component('entry_ramp',u'入口缓坡','ramp',[],collisions=[dict(shape='wedge',width=2.,length=2.,height=.2)],footprint=[2,2])
    ramp=G.Mesh()
    for x,y,z in [[0,0,0],[2,0,0],[0,0,2],[2,0,2],[0,.2,0],[2,.2,0]]:ramp.Vertices.Add(x,-z,y)
    for a,b,c in [[0,1,3],[0,3,2],[4,2,3],[4,3,5],[0,4,5],[0,5,1],[0,2,4],[1,5,3]]:ramp.Faces.AddFace(a,b,c)
    ramp.Unweld(0.,True);ramp.Normals.ComputeNormals()
    vertices=[[float(v.X),float(v.Z),-float(v.Y)] for v in ramp.Vertices]
    objects.append(dict(name='entry_ramp__0',component='entry_ramp',material='timber',vertices=vertices,normals=[[float(v.X),float(v.Z),-float(v.Y)] for v in ramp.Normals],uvs=[[p[0],p[2]] for p in vertices],indices=[i for f in ramp.Faces for i in [f.A,f.B,f.C]]))
    component('railing',u'平台栏杆','edge',[([2,.08,.08],[1,1.1,0],'metal'),([2,.045,.06],[1,.55,0],'metal'),([.07,1.1,.07],[.05,.55,0],'metal'),([.07,1.1,.07],[1.95,.55,0],'metal')],collisions=[dict(shape='box',size=[2,1.15,.10],position=[1,.575,0])],separator=False,seals=False,passable=False)
    plots=[]
    for sid,label,ground in [('484258f1-e149-466b-a104-8d1142a677ee',u'北侧低地',0.),('13bbe4f4-c1e1-4ec5-9bf0-4f1a41e7889b',u'青蓝平台',35.)]:
        obj=sc.doc.Objects.FindId(System.Guid(sid));assert obj is not None
        ok,poly=obj.Geometry.TryGetPolyline();assert ok and len(poly)==5 and obj.Geometry.IsClosed
        p=list(poly);assert all(abs(p[i].DistanceTo(p[i+1])-60)<.001 for i in range(4))
        ex=p[1]-p[0];ez=p[3]-p[0];ex.Unitize();ez.Unitize()
        # Preserve handedness: Rhino XY -> Godot X,-Z reverses planar winding.
        origin=p[1];ex=-ex
        plots.append(dict(id='lowland' if ground==0 else 'coastal',name=label,source_id=sid,size=60.,ground_height=ground,
            origin=[origin.X-1450,ground,1150-origin.Y],axis_x=[ex.X,0,-ex.Y],axis_z=[ez.X,0,-ez.Y],reference_curve_z=p[0].Z))
    furniture={
      'bed':dict(label=u'床',kind='furniture',scene='res://assets/furniture/prism/prism_geo_bed.tscn',footprint=[1.846,2.673],tags=['sleep','rest'],surface=.46,anchor='Anchor_Bed_Center',approach=[0,0,1.85],sleep_slots=1),
      'chair':dict(label=u'椅子',kind='furniture',scene='res://assets/furniture/prism/prism_geo_chair.tscn',footprint=[.984,.988],tags=['seat'],surface=.42,anchor='Anchor_Seat',approach=[0,0,.9]),
      'desk':dict(label=u'桌子',kind='furniture',scene='res://assets/furniture/prism/prism_geo_desk.tscn',footprint=[1.42,.6],tags=['work'],surface=.838,anchor='Anchor_Desk_Surface',approach=[0,0,.85])}
    definitions.update(furniture)
    data=dict(version=1,cell_size=2.,story_height=3.6,slab_thickness=.2,ground_floor_offset=.2,wall_height=3.4,plots=plots,definitions=definitions,objects=objects,rhino_document_modified=False)
    assert sc.doc.Modified==before
    dump(os.path.join(CACHE,'source.json'),data)
    return dict(parts=len(objects),definitions=len(definitions),plots=plots,document_modified=sc.doc.Modified)

def package():
    import struct
    with io.open(os.path.join(CACHE,'source.json'),encoding='utf-8') as f:data=json.load(f)
    blob=bytearray();views=[];accessors=[];meshes=[];nodes=[];parts=[]
    def array(values,component,shape):
        while len(blob)%4:blob.append(0)
        flat=[n for v in values for n in v] if shape!='SCALAR' else values
        payload=struct.pack('<'+('f' if component==5126 else 'I')*len(flat),*flat);offset=len(blob);blob.extend(payload)
        views.append(dict(buffer=0,byteOffset=offset,byteLength=len(payload)))
        a=dict(bufferView=len(views)-1,componentType=component,count=len(values),type=shape)
        if shape=='VEC3':a.update(min=[min(v[j] for v in values) for j in range(3)],max=[max(v[j] for v in values) for j in range(3)])
        accessors.append(a);return len(accessors)-1
    for row in data.pop('objects'):
        attr=dict(POSITION=array(row['vertices'],5126,'VEC3'),NORMAL=array(row['normals'],5126,'VEC3'),TEXCOORD_0=array(row['uvs'],5126,'VEC2'))
        meshes.append(dict(primitives=[dict(attributes=attr,indices=array(row['indices'],5125,'SCALAR'))]));nodes.append(dict(name=row['name'],mesh=len(meshes)-1))
        parts.append(dict(name=row['name'],component=row['component'],material=row['material']))
    gltf=dict(asset=dict(version='2.0',generator='Prism Route / Rhino in-memory construction kit'),scene=0,scenes=[dict(nodes=list(range(len(nodes))))],nodes=nodes,meshes=meshes,buffers=[dict(byteLength=len(blob))],bufferViews=views,accessors=accessors)
    js=json.dumps(gltf,separators=(',',':')).encode('utf-8');js+=b' '*((-len(js))%4);blob+=b'\0'*((-len(blob))%4)
    glb=struct.pack('<III',0x46546c67,2,28+len(js)+len(blob))+struct.pack('<II',len(js),0x4e4f534a)+js+struct.pack('<II',len(blob),0x004e4942)+blob
    if not os.path.isdir(OUT):os.makedirs(OUT)
    with open(os.path.join(OUT,'kit.glb'),'wb') as f:f.write(glb)
    data['parts']=parts;dump(os.path.join(OUT,'catalog.json'),data)
    print(json.dumps(dict(parts=len(parts),glb_bytes=len(glb),definitions=len(data['definitions']))))

if __name__=='__main__':
    import argparse
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--package',action='store_true')
    if parser.parse_args().package:package()
