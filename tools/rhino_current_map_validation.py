# -*- coding: utf-8 -*-
"""Read-only staged export of the visible current Rhino map for Godot review."""
from __future__ import unicode_literals,division
import Rhino,scriptcontext as sc,System,os,io,json,math
G=Rhino.Geometry
TAG='current_map_validation_20261021'
ROOT='D:/Prism Route/prism-route'
CACHE=ROOT+'/.current_map_build'
_roles={}
_role_path=ROOT+'/tools/map_1021_surface_roles.py'
_roles['__file__']=_role_path
exec(compile(open(_role_path,'rb').read().decode('utf-8'),_role_path,'exec'),_roles)
_policy=_roles['read_policy']()

def objects():
 e=Rhino.DocObjects.ObjectEnumeratorSettings();e.NormalObjects=True;e.HiddenObjects=True;e.LockedObjects=True
 return list(sc.doc.Objects.GetObjectList(e))

def xyz(p):return [p.X,p.Y,p.Z]

def write(name,data):
 with io.open(CACHE+'/'+name,'w',encoding='utf-8')as f:f.write(json.dumps(data,ensure_ascii=False,indent=2))

def visible(o):
 if o.IsHidden:return False
 layer=sc.doc.Layers[o.Attributes.LayerIndex]
 while layer:
  if layer.IsDeleted or not layer.IsVisible:return False
  if layer.ParentLayerId==System.Guid.Empty:break
  layer=sc.doc.Layers.FindId(layer.ParentLayerId)
 return True

def _layer_kind(o):
 layer=sc.doc.Layers[o.Attributes.LayerIndex];name=o.Name or '';path=layer.FullPath
 if path.startswith('环境::水面')or'浅水'in name:return 'Water'
 if path.startswith('环境::沙滩'):return 'Sand'
 idx=o.Attributes.MaterialIndex
 if o.Attributes.MaterialSource!=Rhino.DocObjects.ObjectMaterialSource.MaterialFromObject:idx=layer.RenderMaterialIndex
 if idx>=0:
  color=sc.doc.Materials[idx].DiffuseColor
  if max(color.R,color.G,color.B)<115:return 'Road'
 if path.startswith('交通::'):return 'Structure'
 if path.startswith('建筑::主桥岛体'):
  return 'Terrain'if('屋盖'in name or'基座'in name)else'Structure'
 return 'Terrain'if path.startswith(('地形::','建筑::'))else'Structure'

def kind(o):
 layer=sc.doc.Layers[o.Attributes.LayerIndex]
 return _roles['classify']({'id':str(o.Id),'kind':_layer_kind(o),'layer':layer.FullPath},_policy)[0]

def mesh_parts(o):
 """Keep the CAD solid intact; export authored surface roles independently."""
 key=str(o.Id);g=o.Geometry;rule=_policy.get('mesh_partitions',{}).get(key)
 if not rule:return [(key,g,kind(o),{})]
 assert isinstance(g,G.Brep)
 roof=[];architecture=[];roof_faces=[]
 for i,face in enumerate(g.Faces):
  box=face.GetBoundingBox(True)
  # Only the original raised land roof has this full elevation range.
  if box.Min.Z>34.9 and box.Max.Z>52.:
   roof.append(face.DuplicateFace(False));roof_faces.append(i)
  else:architecture.append(face.DuplicateFace(False))
 assert len(roof)==1 and architecture,'Review changed cave surface topology'
 def combine(parts):
  b=G.Brep()
  for part in parts:b.Append(part)
  assert b.IsValid;return b
 return [(key,combine(roof),'Terrain',{'source_object_id':key,'mesh_part':'plantable_roof','cad_face_indices':roof_faces}),
  (rule['architecture_id'],combine(architecture),'Structure',{'source_object_id':key,'mesh_part':'cave_architecture','cad_face_indices':[i for i in range(g.Faces.Count)if i not in roof_faces]})]

def prepare():
 assert sc.doc.Path.replace('\\','/').replace('//','/').lower()=='d:/prism route/map/map_current.3dm'
 if not os.path.isdir(CACHE):os.makedirs(CACHE)
 opts=Rhino.FileIO.SerializationOptions();before={str(o.Id):(int(o.Geometry.DataCRC(0)),o.Attributes.ToJSON(opts))for o in objects()}
 selected=[o for o in objects()if visible(o)and isinstance(o.Geometry,(G.Brep,G.Mesh,G.SubD,G.Extrusion))]
 selected.sort(key=lambda o:str(o.Id))
 d={'before':before,'ids':[str(o.Id)for o in selected],'index':0,'records':[],'center':[1450,1150,0]}
 sc.sticky[TAG]=d
 stream=System.IO.FileStream(CACHE+'/source.bin',System.IO.FileMode.Create);stream.Close()
 write('inventory.json',[{'id':str(o.Id),'name':o.Name or'','layer':sc.doc.Layers[o.Attributes.LayerIndex].FullPath,
 'kind':kind(o),'type':o.Geometry.GetType().Name,'bounds':[xyz(o.Geometry.GetBoundingBox(True).Min),xyz(o.Geometry.GetBoundingBox(True).Max)]}for o in selected])
 return {'visible_geometry_objects':len(selected),'cad_objects':len(before)}

def batch(count=16):
 d=sc.sticky[TAG];records=[]
 p=G.MeshingParameters();p.SimplePlanes=True;p.RefineGrid=True;p.JaggedSeams=False
 p.GridMinCount=4;p.GridMaxCount=40;p.MaximumEdgeLength=8;p.MinimumEdgeLength=.08;p.Tolerance=.04;p.RelativeTolerance=0;p.RefineAngle=.10
 stream=System.IO.FileStream(CACHE+'/source.bin',System.IO.FileMode.Append);writer=System.IO.BinaryWriter(stream)
 try:
  for key in d['ids'][d['index']:d['index']+count]:
   o=sc.doc.Objects.FindId(System.Guid(key));assert o
   for export_id,g,role,extra in mesh_parts(o):
    m=G.Mesh()
    if isinstance(g,G.Mesh):m.Append(g)
    elif isinstance(g,G.SubD):m.Append(G.Mesh.CreateFromSubD(g,2))
    else:
     b=g.ToBrep()if isinstance(g,G.Extrusion)else g
     for q in G.Mesh.CreateFromBrep(b,p):m.Append(q)
    m.Faces.ConvertQuadsToTriangles();m.Normals.ComputeNormals();m.Compact();assert m.IsValid
    pos=m.Vertices.ToFloatArray();ix=m.Faces.ToIntArray(True);offset=stream.Position
    for array in [pos,ix]:
     raw=System.Array.CreateInstance(System.Byte,array.Length*4);System.Buffer.BlockCopy(array,0,raw,0,raw.Length);writer.Write(raw)
    row={'id':export_id,'name':(o.Name or'')+('_'+extra['mesh_part']if extra else''),'layer':sc.doc.Layers[o.Attributes.LayerIndex].FullPath,'kind':role,
     'offset':int(offset),'vertex_count':m.Vertices.Count,'index_count':ix.Length,'bounds':[xyz(m.GetBoundingBox(True).Min),xyz(m.GetBoundingBox(True).Max)],
     'collision':not('斜拉索'in(o.Name or''))and role!='Water'}
    row.update(extra);d['records'].append(row);records.append(row)
   d['index']+=1
 finally:writer.Close()
 return {'done':d['index'],'total':len(d['ids']),'triangles':sum(r['index_count']//3 for r in records)}

def finish():
 d=sc.sticky[TAG];assert d['index']==len(d['ids'])
 opts=Rhino.FileIO.SerializationOptions();after={str(o.Id):(int(o.Geometry.DataCRC(0)),o.Attributes.ToJSON(opts))for o in objects()}
 assert after==d['before'],'CAD modified during read-only export'
 with io.open(ROOT+'/.landscape_mask_build/source.json','r',encoding='utf-8-sig')as f:mask=json.load(f)
 result={'source':sc.doc.Path,'native_center':d['center'],'mask_resolution':4096,'mesh_tolerance_m':.04,'mesh_max_edge_m':8.,'mesh_angle_rad':.10,
 'objects':d['records'],'curves':mask['curves'],'cad_object_count':len(after),'all_cad_geometry_and_attributes_unchanged':True}
 write('source.json',result)
 return {'objects':len(d['records']),'triangles':sum(r['index_count']//3 for r in d['records']),'mask_curves':len(mask['curves']),'cad_unchanged':True}
