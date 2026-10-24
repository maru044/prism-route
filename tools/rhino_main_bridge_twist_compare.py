# -*- coding: utf-8 -*-
"""B2 spatial ribbon arch comparison; preserves B1 and every island/deck edit.
Only two towers and two stay groups differ. Both are explicit comparison assets.
"""
from __future__ import unicode_literals,division
import Rhino,scriptcontext as sc,System,math,json,io,os,types
G=Rhino.Geometry
B=types.ModuleType('main_bridge_recipe')
_p='D:/Prism Route/prism-route/tools/rhino_main_cable_bridge_B.py'
exec(compile(open(_p,'rb').read().decode('utf-8'),_p,'exec'),B.__dict__)
TAG='main_bridge_twist_compare_20261021'
OUT='D:/Prism Route/prism-route/docs/concepts/main_bridge_twist_comparison_2026-10-21'
LAYER_ROOT='交通::上层道路::环塔对比'
VERSIONS={'B1':LAYER_ROOT+'::B1_同侧原版','B2':LAYER_ROOT+'::B2_跨桥扭转'}
ROLES=['tower_1','tower_3','stays_1','stays_3']

def write(name,data):
 with io.open(OUT+'/'+name,'w',encoding='utf-8')as f:f.write(json.dumps(data,ensure_ascii=False,indent=2))

def prepare():
 assert TAG not in sc.sticky,'Reuse the existing comparison state.'
 d=sc.sticky[B.TAG];objects=B.objects();opts=Rhino.FileIO.SerializationOptions()
 assert d and B.obj(d['ids']['deck_paving'])
 for role in ['deck_body','deck_paving']:
  assert G.GeometryBase.GeometryEquals(B.obj(d['ids'][role]).Geometry,d['parts'][role]),'Road changed; resample before building'
 c={'baseline':{str(o.Id):int(o.Geometry.DataCRC(0))for o in objects},
 'before_attrs':{str(o.Id):o.Attributes.ToJSON(opts)for o in objects},'original':{},'towers':{},'ids':{},
 'view':Rhino.DocObjects.ViewportInfo(sc.doc.Views.ActiveView.ActiveViewport)}
 for role in ROLES:
  o=B.obj(d['ids'][role]);assert o
  c['original'][role]={'id':str(o.Id),'geometry':o.Geometry.Duplicate(),'attributes':o.Attributes.Duplicate()}
 sc.sticky[TAG]=c
 if not os.path.isdir(OUT):os.makedirs(OUT)
 audit=[]
 for i in [1,3]:
  rail=d['towers'][i]['rail'];p,t,n=B.frame(d['islands'][i]['station'])
  low=[rail.PointAt(rail.Domain.ParameterAt(j/1000.))for j in range(1000)]
  low=[q for q in low if 0<=q.Z<=65.]
  ny=[G.Vector3d.Multiply(q-p,n)for q in low]
  audit.append({'island':i+1,'B1_low_tower_center_lateral_range_m':[min(ny),max(ny)],'both_legs_same_side':max(ny)<0})
 c['B1_audit']=audit;write('B1_audit.json',audit)
 return {'baseline_objects':len(objects),'B1_audit':audit}

def build_tower(i):
 c=sc.sticky[TAG];d=sc.sticky[B.TAG];assert i in [1,3]
 scale=1. if i==1 else .80;flip=1. if i==1 else -1.
 land=22.;foot_x=40. if i==1 else 26.
 # One open arch rail, capped only at its two submerged foundation feet.
 # The rail bends in all three axes; its feet straddle the existing roadway.
 local=[(foot_x,-22,1.5),(foot_x,-22,24),(foot_x-8,-24,78),(foot_x-36,-22,145),(foot_x-54,-8,194),
        (foot_x-46,5,216),(foot_x-26,15,196),(foot_x-10,24,146),(foot_x+5,24,82),(foot_x+5,land,28),(foot_x+5,land,1.5)]
 points=[B.tower_local(i,x*flip,y,z*scale)for x,y,z in local]
 rail=G.NurbsCurve.Create(False,3,points);count=97;sections=[];r=None;previous=None
 p,t,n=B.frame(d['islands'][i]['station']);t.Z=0;t=B.unit(t)
 frames=[]
 for j in range(count):
  u=j/(count-1.);par=rail.Domain.ParameterAt(u);q=rail.PointAt(par);a=B.unit(rail.TangentAt(par))
  if r is None:r=B.unit(t-a*G.Vector3d.Multiply(t,a))
  else:r.Transform(G.Transform.Rotation(previous,a,G.Point3d.Origin));r=B.unit(r-a*G.Vector3d.Multiply(r,a))
  previous=G.Vector3d(a);rw=G.Vector3d(r)
  twist=math.radians(85.*B.smooth(u)+25.*math.sin(math.pi*u))*flip
  rw.Rotate(twist,a);bn=B.unit(G.Vector3d.CrossProduct(a,rw))
  f=max(0.,min(1.,q.Z/(210.*scale)))
  width=(5.2+4.3*(1-f)**2)*(.90 if i==3 else 1.)
  thick=(1.55+.85*(1-f))*(.95 if i==3 else 1.)
  sections.append(G.Ellipse(G.Plane(q,rw,bn),width,thick).ToNurbsCurve())
  frames.append({'u':u,'center':B.xyz(q),'width_axis':B.xyz(rw),'twist_degrees':math.degrees(twist)})
 body=B.solid_loft(sections)
 assert body.IsValid and body.IsSolid and body.IsManifold
 feet=[rail.PointAtStart,rail.PointAtEnd];base=B.obj(B.BASES[i]).Geometry
 assert all(base.IsPointInside(q,.01,False)for q in feet),(i,'feet must land on the existing base')
 reference=G.Plane(feet[0],feet[1],rail.PointAt(rail.Domain.Mid))
 nonplanar=max(abs(reference.DistanceTo(rail.PointAt(rail.Domain.ParameterAt(j/100.))))for j in range(101))
 mesh=B.mesh(body,1.6)
 c['towers'][i]={'body':body,'rail':rail,'mesh':mesh,'sections':sections,'frames':frames,'foot_points':feet,
 'audit':{'island':i+1,'native_nurbs_solid':True,'faces':body.Faces.Count,'no_naked_edges':not any(e.Valence==G.EdgeAdjacency.Naked for e in body.Edges),
 'foot_lateral_m':[-22.,land],'foot_spacing_m':feet[0].DistanceTo(feet[1]),
 'previous_wide_comparison_spacing_m':math.sqrt((40.)**2+(111. if i==1 else 123.)**2),
 'feet_inside_original_base':True,'section_rotation_degrees':85.*flip,'rail_nonplanarity_m':nonplanar}}
 return c['towers'][i]['audit']

def check_towers():
 c=sc.sticky[TAG];d=sc.sticky[B.TAG];hits=[];lowest=[]
 for j in range(401):
  s=d['length']*j/400.
  for y in [-9.5,-5,0,5,9.5]:
   p=B.point(s,y);ray=G.Ray3d(p+G.Vector3d(0,0,.15),G.Vector3d.ZAxis)
   for i,v in c['towers'].items():
    dist=G.Intersect.Intersection.MeshRay(v['mesh'],ray)
    if dist>=0:
     lowest.append(dist+.15)
     if dist<5.85:hits.append([s,y,i,dist+.15])
 c['tower_clearance']={'road_samples':2005,'intrusions':hits,'min_overhead_tower_m':min(lowest)if lowest else None}
 assert not hits,hits[:20]
 return c['tower_clearance']

def build_stays(i):
 c=sc.sticky[TAG];d=sc.sticky[B.TAG];v=c['towers'][i];s0=d['islands'][i]['station'];p,t,n=B.frame(s0)
 corridor=d['traffic_mesh'];bounds=(125.,745.,42)if i==1 else(655.,d['length']-8.,30)
 rail=v['rail'];candidates=[rail.PointAt(rail.Domain.ParameterAt(j/1600.))for j in range(1601)]
 output=G.Mesh();rows=[];skipped=[]
 for j in range(bounds[2]):
  s=bounds[0]+(bounds[1]-bounds[0])*j/(bounds[2]-1.)
  if abs(s-s0)<24.:continue
  scale=1. if i==1 else .80;goal=(140.+55*min(1.,abs(s-s0)/260.))*scale
  for sign in [-1,1]:
   # Each deck edge attaches to its corresponding side of the spatial arch.
   possibles=[q for q in candidates if G.Vector3d.Multiply(q-p,n)*sign>4. and q.Z>105.*scale]
   possibles=sorted(possibles,key=lambda q:abs(q.Z-goal))[:20]
   assert possibles
   anchor=min(possibles,key=lambda q:G.Vector3d.Multiply(q-p,t))if s<s0 else max(possibles,key=lambda q:G.Vector3d.Multiply(q-p,t))
   a=B.point(s,sign*12.7,.25);b=G.Point3d(anchor);line=G.Line(a,b)
   hits=G.Intersect.Intersection.MeshLine(corridor,line)
   if hits is not None and len(hits):skipped.append([s,sign]);continue
   plane=G.Plane(a,B.unit(b-a));tube=G.Mesh.CreateFromCylinder(G.Cylinder(G.Circle(plane,.17),a.DistanceTo(b)),1,10,True,True)
   assert tube and tube.IsClosed;output.Append(tube)
   rows.append({'station':s,'side':sign,'deck_anchor':B.xyz(a),'tower_anchor':B.xyz(b),'length_m':a.DistanceTo(b)})
 output.Normals.ComputeNormals();output.Compact();assert output.IsValid and output.IsClosed
 v['stays']=output;v['stay_rows']=rows;v['skipped']=skipped
 return {'island':i+1,'cables':len(rows),'excluded_for_clearance':len(skipped)}

def ensure_layer(path):
 found=sc.doc.Layers.FindByFullPath(path,-1)
 if found>=0:return found
 parts=path.split('::');parent=ensure_layer('::'.join(parts[:-1]))if len(parts)>1 else -1
 layer=Rhino.DocObjects.Layer();layer.Name=parts[-1]
 if parent>=0:layer.ParentLayerId=sc.doc.Layers[parent].Id
 return sc.doc.Layers.Add(layer)

def switch(version):
 assert version in VERSIONS
 assert not sc.sticky[TAG].get('B1_retired') or version=='B2','B1 was deleted at the user request.'
 # Turn the chosen one on before disabling the other; parent remains visible.
 for key in [version]+[k for k in VERSIONS if k!=version]:
  index=sc.doc.Layers.FindByFullPath(VERSIONS[key],-1)
  if index<0 and key=='B1'and sc.sticky[TAG].get('B1_retired'):continue
  assert index>=0
  l=sc.doc.Layers[index]
  desired=(key==version)
  if l.IsVisible!=desired or l.GetPersistentVisibility()!=desired:
   l.SetPersistentVisibility(desired);l.IsVisible=desired;assert sc.doc.Layers.Modify(l,index,True)
 sc.doc.Objects.UnselectAll();sc.doc.Views.Redraw();sc.sticky[TAG]['active_version']=version
 return version

def publish():
 c=sc.sticky[TAG];assert 'tower_clearance'in c
 assert not c.get('B1_retired'),'Comparison finalized; edit the approved B2 objects directly.'
 old_layer=ensure_layer(VERSIONS['B1']);new_layer=ensure_layer(VERSIONS['B2'])
 undo=sc.doc.BeginUndoRecord('环塔跨桥扭转对比B2')
 try:
  for role in ROLES:
   original=c['original'][role];o=B.obj(original['id']);assert o
   a=original['attributes'].Duplicate();a.LayerIndex=old_layer;assert sc.doc.Objects.ModifyAttributes(o.Id,a,True)
   i=int(role.split('_')[1]);v=c['towers'][i];g=v['body']if role.startswith('tower_')else v['stays']
   a=original['attributes'].Duplicate();a.LayerIndex=new_layer;a.Name='主桥B2_岛%d_%s'%(i+1,'跨桥扭转带状环塔'if role.startswith('tower_')else '随扭转环塔重排的双侧斜拉索')
   a.SetUserString('recipe',TAG);a.SetUserString('main_bridge_B_role','comparison_B2_'+role)
   a.SetUserString('bridge_comparison_version','B2');a.SetUserString('bridge_comparison_role',role)
   a.SetUserString('description','用户要求的对比成品：两塔脚分别位于道路两侧，空间扭转塔身和旋转带状截面。B1在同级图层保留。')
   existing=next((o for o in B.objects()if o.Attributes.GetUserString('recipe')==TAG and o.Attributes.GetUserString('bridge_comparison_role')==role),None)
   if existing:
    assert sc.doc.Objects.Replace(existing.Id,g);oid=existing.Id;assert sc.doc.Objects.ModifyAttributes(oid,a,True)
   else:oid=sc.doc.Objects.AddMesh(g,a)if isinstance(g,G.Mesh)else sc.doc.Objects.AddBrep(g,a)
   assert oid!=System.Guid.Empty;c['ids'][role]=str(oid)
 finally:sc.doc.EndUndoRecord(undo)
 switch('B2');return c['ids']

def capture(name,camera,target):
 view=sc.doc.Views.ActiveView;vp=view.ActiveViewport
 vp.ChangeToPerspectiveProjection(True,42.);vp.SetCameraLocations(G.Point3d(*target),G.Point3d(*camera));vp.CameraUp=G.Vector3d.ZAxis
 sc.doc.Objects.UnselectAll();sc.doc.Views.Redraw()
 vc=Rhino.Display.ViewCapture();vc.Width=1800;vc.Height=1200;vc.DrawAxes=False;vc.DrawGrid=False;vc.DrawGridAxes=False
 bmp=vc.CaptureToBitmap(view);assert bmp
 path=OUT+'/'+name+'.png';bmp.Save(path,System.Drawing.Imaging.ImageFormat.Png);bmp.Dispose();return path

def verify():
 c=sc.sticky[TAG];d=sc.sticky[B.TAG];bad_geom=[];bad_attrs=[];missing=[]
 assert not c.get('B1_retired'),'Comparison finalized; current preservation and saved-file checks are in B1_removal.json.'
 options=Rhino.FileIO.SerializationOptions();oldids=[v['id']for v in c['original'].values()]
 for k,crc in c['baseline'].items():
  o=B.obj(k)
  if not o:missing.append(k);continue
  if int(o.Geometry.DataCRC(0))!=crc:bad_geom.append(k)
  if k in oldids:
   original=next(v for v in c['original'].values()if v['id']==k)
   expected=original['attributes'].Duplicate();expected.LayerIndex=sc.doc.Layers.FindByFullPath(VERSIONS['B1'],-1)
   if o.Attributes.ToJSON(options)!=expected.ToJSON(options):bad_attrs.append(k)
  elif o.Attributes.ToJSON(options)!=c['before_attrs'][k]:bad_attrs.append(k)
 assert not bad_geom and not bad_attrs and not missing,(bad_geom,bad_attrs,missing)
 components=[];footprints=[];anchorchecks=[];roadside=[]
 for role,k in c['ids'].items():
  o=B.obj(k);i=int(role.split('_')[1]);v=c['towers'][i];g=v['body']if role.startswith('tower_')else v['stays']
  assert G.GeometryBase.GeometryEquals(o.Geometry,g),role
  assert g.IsValid and(g.IsClosed if isinstance(g,G.Mesh)else g.IsSolid),role
  components.append({'role':role,'id':k,'type':g.GetType().Name,'valid':True,'closed':True,'faces':g.Faces.Count})
 for i,v in c['towers'].items():
  base=B.obj(B.BASES[i]).Geometry
  for foot in [0,-1]:
   sec=v['sections'][foot];supported=[]
   for k in range(64):
    q=sec.PointAt(sec.Domain.ParameterAt(k/64.));q.Z=2.8;supported.append(base.IsPointInside(q,.01,False))
   assert all(supported),(i,foot,'unsupported foot perimeter')
   footprints.append({'island':i+1,'foot':'sea'if foot==0 else 'land','foundation_supported_samples':sum(supported),'samples':64})
  for row in v['stay_rows']:
   a=G.Point3d(*row['deck_anchor']);b=G.Point3d(*row['tower_anchor'])
   ok=d['parts']['deck_body'].IsPointInside(a,.005,False)and v['body'].IsPointInside(b,.005,False)
   anchorchecks.append(ok)
  rail=v['rail'];low=[]
  for j in range(3001):
   q=rail.PointAt(rail.Domain.ParameterAt(j/3000.))
   if abs(q.Z-60.2)<.2:
    ok,t=d['curve'].ClosestPoint(q);assert ok
    s=d['curve'].GetLength(G.Interval(d['curve'].Domain.T0,t));p,along,n=B.frame(s)
    low.append(G.Vector3d.Multiply(q-p,n))
  assert low and min(low)<-20 and max(low)>20,(i,low)
  roadside.append({'island':i+1,'tower_axis_at_deck_height_lateral_range_m':[min(low),max(low)],'straddles_road':True})
 assert all(anchorchecks),'Cable ends must attach to the actual bodies'
 longitudinal=[];meshes=[]
 for i,v in c['towers'].items():meshes.extend([('tower_%d'%i,v['mesh']),('stays_%d'%i,v['stays'])])
 for y in [-9.,0.,9.]:
  for z in [.25,1.5,4.5,6.]:
   previous=B.point(0,y,z)
   for j in range(1,301):
    p=B.point(d['length']*j/300.,y,z);line=G.Line(previous,p)
    for role,m in meshes:
     hits=G.Intersect.Intersection.MeshLine(m,line)
     if hits is not None and len(hits):longitudinal.append([role,j,y,z])
    previous=p
 assert not longitudinal,longitudinal[:20]
 report={'B1_audit':c['B1_audit'],'B2_towers':[v['audit']for i,v in c['towers'].items()],
 'tower_at_road_height':roadside,'tower_footprints':footprints,'clearance':c['tower_clearance'],
 'longitudinal_vehicle_segments':3600,'longitudinal_intrusions':longitudinal,
 'cable_clearance_margin_m':.25,'cables':sum(len(v['stay_rows'])for i,v in c['towers'].items()),
 'both_cable_ends_inside_finished_bodies':sum(anchorchecks),'cable_end_pairs_checked':len(anchorchecks),
 'baseline_objects':len(c['baseline']),'live_objects':len(B.objects()),'active_layers':sum(not l.IsDeleted for l in sc.doc.Layers),
 'original_geometries_changed':bad_geom,'unexpected_attributes_changed':bad_attrs,'missing_originals':missing,
 'only_expected_original_attribute_change':'Four B1 objects moved to the explicit B1 comparison layer; geometry and all other object attributes retained.',
 'components':components,'layers':VERSIONS,'active_version':c['active_version'],
 'scope':'Visual comparison and sampled Rhino geometry clearance. Not structural certification or Godot collision acceptance.'}
 c['verification']=report;write('validation.json',report)
 return {k:report[k]for k in ['live_objects','active_layers','cables','both_cable_ends_inside_finished_bodies','original_geometries_changed','unexpected_attributes_changed']}

def save_current():
 c=sc.sticky[TAG];assert 'verification'in c
 path=sc.doc.Path;assert path.replace('\\','/').replace('//','/').lower()=='d:/prism route/map/map_current.3dm'
 assert Rhino.RhinoApp.RunScript('_Save',False)
 saved=Rhino.FileIO.File3dm.Read(path);assert saved
 disk={str(o.Id):int(o.Geometry.DataCRC(0))for o in saved.Objects};live={str(o.Id):int(o.Geometry.DataCRC(0))for o in B.objects()}
 assert disk==live
 layerflags={l.FullPath:l.IsVisible for l in saved.Layers if not l.IsDeleted}
 assert layerflags[VERSIONS['B2']]and (VERSIONS['B1']not in layerflags if c.get('B1_retired')else not layerflags[VERSIONS['B1']])
 c['verification']['saved_file']={'path':path,'objects':len(disk),'all_ids_and_geometry_crc_match':True,'B2_visible_B1_off':True}
 write('validation.json',c['verification']);return c['verification']['saved_file']

def retire_b1():
 """User-approved removal of four B1 finished objects; B2 and the rest stay intact."""
 oldids=['a1623954-71ae-4c0d-830d-ced46440e17e','e7082218-d1ba-4ff2-adce-cfb81648ef81',
         '4d5c9137-ee88-4e63-9ac4-806da86fac32','020ca9f3-6ce4-463d-b274-f00621347643']
 path=sc.doc.Path;assert path.replace('\\','/').replace('//','/').lower()=='d:/prism route/map/map_current.3dm'
 index=sc.doc.Layers.FindByFullPath(VERSIONS['B1'],-1);assert index>=0
 objects=B.objects();on_layer=[str(o.Id)for o in objects if o.Attributes.LayerIndex==index]
 assert set(on_layer)==set(oldids),'Unexpected B1 contents; do not delete unrelated objects.'
 assert all(B.obj(k)for k in oldids)
 opts=Rhino.FileIO.SerializationOptions()
 before={str(o.Id):(int(o.Geometry.DataCRC(0)),o.Attributes.ToJSON(opts))for o in objects if str(o.Id)not in oldids}
 b2=[o for o in objects if o.Attributes.GetUserString('recipe')==TAG];assert len(b2)==4
 b2layer=sc.doc.Layers.FindByFullPath(VERSIONS['B2'],-1);assert b2layer>=0 and sc.doc.Layers[b2layer].IsVisible
 undo=sc.doc.BeginUndoRecord('用户确认B2_删除B1旧塔与拉索')
 try:
  for k in oldids:assert sc.doc.Objects.Delete(B.obj(k),True,True),k
  assert sc.doc.Layers.Delete(index,True),'B1 empty layer deletion failed'
 finally:sc.doc.EndUndoRecord(undo)
 after={str(o.Id):(int(o.Geometry.DataCRC(0)),o.Attributes.ToJSON(opts))for o in B.objects()}
 assert before==after,'A retained object changed unexpectedly'
 assert all(not B.obj(k)for k in oldids)
 if TAG in sc.sticky:sc.sticky[TAG]['B1_retired']=True
 sc.doc.Views.Redraw();assert Rhino.RhinoApp.RunScript('_Save',False)
 saved=Rhino.FileIO.File3dm.Read(path);assert saved
 disk={str(o.Id):int(o.Geometry.DataCRC(0))for o in saved.Objects}
 assert disk=={k:v[0]for k,v in after.items()}
 layerflags={l.FullPath:l.IsVisible for l in saved.Layers if not l.IsDeleted}
 assert VERSIONS['B1']not in layerflags and layerflags[VERSIONS['B2']]
 report={'date':'2026-10-21','user_approved_current_version':'B2','deleted_B1_object_ids':oldids,'deleted_empty_layer':VERSIONS['B1'],
 'retained_objects':len(after),'active_layers':sum(not l.IsDeleted for l in sc.doc.Layers),
 'all_retained_geometry_and_attributes_unchanged':True,'saved_file':path,'saved_ids_and_geometry_crc_match':True,'B2_visible':True}
 write('B1_removal.json',report)
 if TAG in sc.sticky:sc.sticky[TAG]['B1_removal']=report
 return report
