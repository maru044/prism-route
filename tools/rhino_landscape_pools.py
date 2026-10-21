# -*- coding: utf-8 -*-
"""Bounded CAD -> world-space mask test exporter. No coverage mesh generation.
Run export_test() in the connected Rhino. Source solids are read only.
"""
from __future__ import unicode_literals,division
import Rhino,scriptcontext as sc,System,math,os,io,json,re
G=Rhino.Geometry
ROOT='D:/Prism Route/prism-route'
CACHE=ROOT+'/.landscape_mask_build'
CAD_LAYER='参考::种植边界'
DEFAULT_WIDTH_M=6.0
_role_path=ROOT+'/tools/map_1021_surface_roles.py'
_roles={'__file__':_role_path}
exec(compile(open(_role_path,'rb').read().decode('utf-8'),_role_path,'exec'),_roles)
_role_policy=_roles['read_policy']()

def curve_width(attributes):
 """Full maximum band width in metres. Name [w=8] overrides user text."""
 values=re.findall(r'\[w\s*=\s*([^\]]*)\]',attributes.Name or '',re.I)
 if len(values)>1:raise ValueError('Use only one [w=...] per curve')
 value=values[0] if values else attributes.GetUserString('world_mask_width_m')
 width=DEFAULT_WIDTH_M if value is None else float(value)
 if math.isnan(width) or math.isinf(width) or width<=0:
  raise ValueError('World mask width must be a finite positive number in metres')
 return width

def read_cad_curves():
 """Read the user's existing curves. Never create, replace, rename or show them."""
 result=[]
 for o in objects():
  layer=sc.doc.Layers[o.Attributes.LayerIndex]
  if layer.FullPath!=CAD_LAYER and not layer.FullPath.startswith(CAD_LAYER+'::'):continue
  if o.IsHidden or not layer.IsVisible or not isinstance(o.Geometry,G.Curve):continue
  c=o.Geometry
  if not c.IsValid or c.GetLength()<.01:
   raise ValueError('Use a valid open or closed centreline: '+str(o.Id))
  result.append((o,curve_width(o.Attributes)))
 if not result:raise ValueError('No visible CAD centrelines in '+CAD_LAYER)
 return sorted(result,key=lambda item:((item[0].Name or ''),str(item[0].Id)))
LAND=set(['9c6e4638-fa65-4d06-b84d-21feb0ab3b1b','c1228167-d010-44ad-8775-757dd4984934',
'e7a0e133-f284-4cd4-8796-349bb8638efc','7f48c0e6-3eff-429b-b3b0-92d2ba679c0f',
'9ed1bc59-e9fa-4024-8095-564d74c4c87c','92714fcc-8762-4105-8ee9-d6796c31dc9f',
'6ff4660f-d023-461f-a4ac-9f0038a79c6d','f6bf901b-4e02-49c2-8a1c-6382c255c941'])
def objects():
 e=Rhino.DocObjects.ObjectEnumeratorSettings();e.HiddenObjects=True;e.LockedObjects=True;e.NormalObjects=True
 return list(sc.doc.Objects.GetObjectList(e))
def meshes(curve_sources=None):
 p=G.MeshingParameters();p.SimplePlanes=True;p.RefineGrid=True;p.JaggedSeams=False
 p.GridMinCount=4;p.GridMaxCount=40;p.MaximumEdgeLength=8;p.MinimumEdgeLength=.25
 p.Tolerance=.04;p.RelativeTolerance=0;p.RefineAngle=.08
 parts=[];ray=G.Mesh();region=G.BoundingBox(G.Point3d(1100,850,-100),G.Point3d(1920,1560,200))
 hosts=set();families=set()
 for o,width in curve_sources or []:
  source_id=o.Attributes.GetUserString('mask_source_object_id')
  if source_id:
   host=sc.doc.Objects.FindId(System.Guid(source_id))
   if not host:raise ValueError('Missing CAD mask host: '+source_id)
   hosts.add(source_id);region.Union(host.Geometry.GetBoundingBox(True))
   family=o.Attributes.GetUserString('mask_island_family_layer')
   if family:families.add(family)
 for o in objects():
  if o.IsHidden:continue
  l=sc.doc.Layers[o.Attributes.LayerIndex]
  if not l.IsVisible or not isinstance(o.Geometry,(G.Brep,G.Mesh,G.Extrusion)):continue
  kind=None
  family_member=any(l.FullPath==family or l.FullPath.startswith(family+'::')for family in families)
  explicit_host=_role_policy['objects'].get(str(o.Id),{}).get('kind')=='Terrain'
  if str(o.Id) in LAND or str(o.Id)in hosts or family_member or explicit_host:kind='Terrain'
  elif l.FullPath.startswith('交通::'):
   i=o.Attributes.MaterialIndex
   if i>=0:
    c=sc.doc.Materials[i].DiffuseColor
    if max(int(c.R),int(c.G),int(c.B))<112:kind='Road'
  elif l.FullPath=='环境::沙滩':kind='Sand'
  if kind is None:continue
  kind=_roles['classify']({'id':str(o.Id),'kind':kind,'layer':l.FullPath},_role_policy)[0]
  bb=o.Geometry.GetBoundingBox(True)
  if bb.Max.X<region.Min.X or bb.Min.X>region.Max.X or bb.Max.Y<region.Min.Y or bb.Min.Y>region.Max.Y:continue
  m=G.Mesh()
  if isinstance(o.Geometry,G.Mesh):m.Append(o.Geometry)
  else:
   b=o.Geometry.ToBrep() if isinstance(o.Geometry,G.Extrusion) else o.Geometry
   for q in G.Mesh.CreateFromBrep(b,p):m.Append(q)
  m.Faces.ConvertQuadsToTriangles();m.Compact()
  assert m.IsValid
  parts.append((o,m,kind))
  if kind=='Terrain':ray.Append(m)
 return parts,ray
def export_test():
 if not os.path.isdir(CACHE):os.makedirs(CACHE)
 before={str(o.Id):o.Geometry.DataCRC(0) for o in objects()}
 sources=read_cad_curves()
 parts,ray=meshes(sources)
 # Read actual CAD centerlines, including hand edits and newly drawn curves.
 curves=[]
 for o,width in sources:
  c=o.Geometry;oid=o.Id;name=o.Name or str(oid)
  count=max(100,int(math.ceil(c.GetLength()/.35)));ts=c.DivideByCount(count,True);points=[]
  for k,t in enumerate(ts):
   q=c.PointAt(t);points.append([q.X,q.Y])
  # Bounded sparse height samples. Fine boundary shape still comes from CAD.
  heights=[]
  # Tagged roof strokes sample their own host, rather than the first overlapping
  # upper/lower storey hit by a world-space ray.
  source_id=o.Attributes.GetUserString('mask_source_object_id');curve_ray=ray
  if source_id:
   source=sc.doc.Objects.FindId(System.Guid(source_id));assert source
   curve_ray=G.Mesh()
   for q in G.Mesh.CreateFromBrep(source.Geometry,G.MeshingParameters.FastRenderMesh):curve_ray.Append(q)
  for k in range(0,len(points),8):
   x,y=points[k];d=G.Intersect.Intersection.MeshRay(curve_ray,G.Ray3d(G.Point3d(x,y,160),G.Vector3d(0,0,-1)))
   heights.append([k,160-d if d>=0 else -1000])
  if heights[-1][0]!=len(points)-1:
   x,y=points[-1];d=G.Intersect.Intersection.MeshRay(curve_ray,G.Ray3d(G.Point3d(x,y,160),G.Vector3d(0,0,-1)));heights.append([len(points)-1,160-d if d>=0 else -1000])
  if not any(h[1]>-500 for h in heights):
   raise ValueError('CAD curve is outside the exported terrain: '+name)
  curves.append({'id':str(oid),'name':name,'width_m':width,'closed':bool(c.IsClosed),
   'source_object_id':source_id,'points_xy':points,'heights':heights})
 records=[];stream=System.IO.FileStream(CACHE+'/source.bin',System.IO.FileMode.Create);writer=System.IO.BinaryWriter(stream)
 try:
  for o,m,kind in parts:
   pos=m.Vertices.ToFloatArray();idx=m.Faces.ToIntArray(True);offset=stream.Position
   for arr in [pos,idx]:
    raw=System.Array.CreateInstance(System.Byte,arr.Length*4);System.Buffer.BlockCopy(arr,0,raw,0,raw.Length);writer.Write(raw)
   records.append({'id':str(o.Id),'name':o.Name or kind,'kind':kind,'offset':int(offset),'vertex_count':int(m.Vertices.Count),'index_count':int(idx.Length)})
 finally:writer.Close()
 result={'source':sc.doc.Path,'native_center':[1450,1150,0],'mask_resolution':4096,'mesh_tolerance_m':.04,'mesh_max_edge_m':8,'mesh_angle_rad':.08,'objects':records,'curves':curves}
 with io.open(CACHE+'/source.json','w',encoding='utf-8') as f:f.write(json.dumps(result,ensure_ascii=False))
 assert before=={str(o.Id):o.Geometry.DataCRC(0) for o in objects()}
 sc.sticky['wm_export']=result
 return {'objects':len(records),'triangles':sum(r['index_count']//3 for r in records),'curves':len(curves),'curve_samples':sum(len(c['points_xy']) for c in curves),'unchanged_terrain':True}
