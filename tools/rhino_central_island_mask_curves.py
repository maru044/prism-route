# -*- coding: utf-8 -*-
"""CAD-only, closed planting/architecture mask boundaries; source bodies untouched.
The legacy open-centreline mask test uses a separate layer and is not regenerated.
"""
from __future__ import unicode_literals,division
import Rhino,scriptcontext as sc,System,math,json,io,os
G=Rhino.Geometry
TAG='central_island_material_mask_20261021'
LAYER='参考::建筑种植遮罩'
OUT='D:/Prism Route/prism-route/docs/concepts/central_island_mask_2026-10-21'
SOURCES=[('ce36cdce-398b-44f5-b0b4-fe7f258106cf',6.,'大岛顶盖'),
         ('78d43939-e418-428e-aad5-d51b08c73985',3.,'椭圆顶盖')]

def objects():
 e=Rhino.DocObjects.ObjectEnumeratorSettings();e.NormalObjects=True;e.HiddenObjects=True;e.LockedObjects=True
 return list(sc.doc.Objects.GetObjectList(e))

def obj(k):return sc.doc.Objects.FindId(System.Guid(k))

def write(name,data):
 if not os.path.isdir(OUT):os.makedirs(OUT)
 with io.open(OUT+'/'+name,'w',encoding='utf-8')as f:f.write(json.dumps(data,ensure_ascii=False,indent=2))

def prepare():
 assert TAG not in sc.sticky,'Use the current staged curves or directly edit the published references.'
 selected={str(o.Id)for o in sc.doc.Objects.GetSelectedObjects(False,False)}
 assert selected==set(k for k,w,n in SOURCES),'Selection differs from the two requested roof bodies'
 opts=Rhino.FileIO.SerializationOptions()
 d={'before':{str(o.Id):(int(o.Geometry.DataCRC(0)),o.Attributes.ToJSON(opts))for o in objects()},
 'curves':[],'view':Rhino.DocObjects.ViewportInfo(sc.doc.Views.ActiveView.ActiveViewport)}
 for k,width,name in SOURCES:
  o=obj(k);assert isinstance(o.Geometry,G.Brep)
  f=o.Geometry.Faces[3];normal=f.NormalAt(f.Domain(0).Mid,f.Domain(1).Mid)
  assert normal.Z>.99
  outer=f.OuterLoop.To3dCurve();bb=outer.GetBoundingBox(True);z=bb.Center.Z;assert bb.Max.Z-bb.Min.Z<.001
  plane=G.Plane(G.Point3d(0,0,z),G.Vector3d.ZAxis);area=G.AreaMassProperties.Compute(outer).Area
  candidates=[]
  for sign in [-1,1]:
   curves=outer.Offset(plane,sign*width,.002,G.CurveOffsetCornerStyle.Sharp)
   if not curves or len(curves)!=1:continue
   q=curves[0]
   if q.IsValid and q.IsClosed:
    inner_area=G.AreaMassProperties.Compute(q).Area
    if inner_area<area:candidates.append((q,inner_area))
  assert len(candidates)==1,(k,'Unique inward boundary required')
  inner,inner_area=candidates[0]
  selfhits=G.Intersect.Intersection.CurveSelf(inner,.002);assert selfhits is None or selfhits.Count==0
  distances=[]
  for j in range(301):
   p=inner.PointAtNormalizedLength(j/301.)
   assert outer.Contains(p,plane,.002)==G.PointContainment.Inside
   ok,t=outer.ClosestPoint(p);assert ok;distances.append(p.DistanceTo(outer.PointAt(t)))
  assert max(abs(v-width)for v in distances)<.015,(name,min(distances),max(distances))
  display=inner.DuplicateCurve();display.Translate(0,0,.08)
  d['curves'].append({'source_id':k,'name':name,'width':width,'surface_z':z,'curve':display,
  'source_area_m2':area,'planting_inside_area_m2':inner_area,'architectural_top_edge_area_m2':area-inner_area,
  'offset_distance_range_m':[min(distances),max(distances)]})
 sc.sticky[TAG]=d
 return [{'source_id':v['source_id'],'name':v['name'],'offset_m':v['width'],'offset_range_m':v['offset_distance_range_m']}for v in d['curves']]

def publish():
 d=sc.sticky[TAG];index=sc.doc.Layers.FindByFullPath(LAYER,-1)
 color=System.Drawing.Color.FromArgb(30,175,95)
 if index<0:
  parent=sc.doc.Layers.FindByFullPath('参考',-1);assert parent>=0
  l=Rhino.DocObjects.Layer();l.Name=LAYER.split('::')[-1];l.ParentLayerId=sc.doc.Layers[parent].Id;l.Color=color
  index=sc.doc.Layers.Add(l);assert index>=0
 undo=sc.doc.BeginUndoRecord('中央大岛_仅绘制建筑种植遮罩边界')
 try:
  for v in d['curves']:
   a=Rhino.DocObjects.ObjectAttributes();a.LayerIndex=index;a.Name='遮罩_%s_内偏%g米_线内种植'%(v['name'],v['width'])
   a.ObjectColor=color;a.ColorSource=Rhino.DocObjects.ObjectColorSource.ColorFromObject;a.WireDensity=-1
   fields={'recipe':TAG,'mask_type':'closed_region_boundary','mask_source_object_id':v['source_id'],
   'mask_source_face_index':'3','mask_inward_offset_m':str(v['width']),'mask_inside':'planting',
   'mask_between_curve_and_source_top_edge':'architecture','mask_terrace_platform_default':'planting',
   'mask_island_family_layer':'建筑::崖壁B','mask_surface_z_m':str(v['surface_z']),'mask_display_lift_m':'0.08',
   'description':'仅材质遮罩参考：闭合线内为种植；线与原顶面边缘之间为建筑边缘带；阶梯平台为种植。不切分实体。'}
   for k,value in fields.items():a.SetUserString(k,value)
   existing=next((o for o in objects()if o.Attributes.GetUserString('recipe')==TAG and o.Attributes.GetUserString('mask_source_object_id')==v['source_id']),None)
   if existing:
    assert sc.doc.Objects.Replace(existing.Id,v['curve']);oid=existing.Id;assert sc.doc.Objects.ModifyAttributes(oid,a,True)
   else:oid=sc.doc.Objects.AddCurve(v['curve'],a)
   assert oid!=System.Guid.Empty;v['id']=str(oid)
 finally:sc.doc.EndUndoRecord(undo)
 sc.doc.Objects.UnselectAll();sc.doc.Views.Redraw()
 return [v['id']for v in d['curves']]

def verify_save():
 d=sc.sticky[TAG];opts=Rhino.FileIO.SerializationOptions();changed=[]
 for k,pair in d['before'].items():
  o=obj(k)
  if not o or(int(o.Geometry.DataCRC(0)),o.Attributes.ToJSON(opts))!=pair:changed.append(k)
 assert not changed,changed
 rows=[]
 for v in d['curves']:
  o=obj(v['id']);assert o and isinstance(o.Geometry,G.Curve)and o.Geometry.IsClosed and o.Geometry.IsValid
  assert G.GeometryBase.GeometryEquals(o.Geometry,v['curve'])
  rows.append({k:value for k,value in v.items()if k!='curve'})
 current=objects();assert len(current)==len(d['before'])+2
 path=sc.doc.Path;assert path.replace('\\','/').replace('//','/').lower()=='d:/prism route/map/map_current.3dm'
 assert Rhino.RhinoApp.RunScript('_Save',False)
 disk=Rhino.FileIO.File3dm.Read(path);assert disk
 saved={str(o.Id):int(o.Geometry.DataCRC(0))for o in disk.Objects};live={str(o.Id):int(o.Geometry.DataCRC(0))for o in current}
 assert saved==live
 report={'saved_file':path,'objects':len(current),'active_layers':sum(not l.IsDeleted for l in sc.doc.Layers),
 'new_curve_count':2,'original_geometry_and_attributes_unchanged':True,'saved_ids_and_geometry_crc_match':True,
 'layer':LAYER,'curves':rows,'terrace_rule':'Existing stepped platforms are planting by default; no separate architectural edge bands on terrace ledges.',
 'scope':'CAD reference curves only. No face splitting, material replacement, coverage mesh, engine mask export or game scene modification.',
 'legacy_open_centerline_mask_layer_unchanged':'参考::种植边界'}
 write('validation.json',report);d['verification']=report
 return report

def capture(name):
 view=sc.doc.Views.ActiveView;vc=Rhino.Display.ViewCapture();vc.Width=1800;vc.Height=1200
 vc.DrawAxes=False;vc.DrawGrid=False;vc.DrawGridAxes=False
 bmp=vc.CaptureToBitmap(view);assert bmp
 if not os.path.isdir(OUT):os.makedirs(OUT)
 path=OUT+'/'+name+'.png';bmp.Save(path,System.Drawing.Imaging.ImageFormat.Png);bmp.Dispose();return path

def copy_as_band_centrelines():
 """Copy the two planting boundaries into the existing full-width stroke layer.
 Move each copy outward by half the intended band width; preserve all originals.
 """
 bandtag='central_island_material_bands_20261021';target='参考::种植边界'
 source_ids=['7404cff6-c36d-40b3-a24f-494802e636e6','76c06be1-1acb-4bdd-a43c-c723e79666ca']
 index=sc.doc.Layers.FindByFullPath(target,-1);assert index>=0
 opts=Rhino.FileIO.SerializationOptions();all_objects=objects()
 before={str(o.Id):(int(o.Geometry.DataCRC(0)),o.Attributes.ToJSON(opts))for o in all_objects if o.Attributes.GetUserString('recipe')!=bandtag}
 rows=[];newids=[]
 undo=sc.doc.BeginUndoRecord('种植边界_复制为闭合恒宽建筑中线')
 try:
  for key in source_ids:
   original=obj(key);assert original and original.Geometry.IsClosed
   attrs=original.Attributes;host_id=attrs.GetUserString('mask_source_object_id');host=obj(host_id);assert host
   width=float(attrs.GetUserString('mask_inward_offset_m'));half=width*.5
   boundary=original.Geometry;z=boundary.GetBoundingBox(True).Center.Z;plane=G.Plane(G.Point3d(0,0,z),G.Vector3d.ZAxis)
   area=G.AreaMassProperties.Compute(boundary).Area;candidates=[]
   for sign in [-1,1]:
    results=boundary.Offset(plane,sign*half,.002,G.CurveOffsetCornerStyle.Sharp)
    if not results or len(results)!=1:continue
    c=results[0]
    if c.IsClosed and c.IsValid and G.AreaMassProperties.Compute(c).Area>area:candidates.append(c)
   assert len(candidates)==1
   center=candidates[0];surface_z=float(attrs.GetUserString('mask_surface_z_m'));outer=host.Geometry.Faces[3].OuterLoop.To3dCurve()
   sourceplane=G.Plane(G.Point3d(0,0,surface_z),G.Vector3d.ZAxis);distances=[]
   for j in range(301):
    p=center.PointAtNormalizedLength(j/301.);p.Z=surface_z
    assert outer.Contains(p,sourceplane,.002)==G.PointContainment.Inside
    ok,t=outer.ClosestPoint(p);assert ok;distances.append(p.DistanceTo(outer.PointAt(t)))
   assert max(abs(v-half)for v in distances)<.015
   a=attrs.Duplicate();a.LayerIndex=index
   name='大岛顶盖'if width==6. else'椭圆顶盖'
   a.Name='建筑中线_%s_闭合恒宽 [w=%g]'%(name,width)
   for field in ['mask_inside','mask_between_curve_and_source_top_edge','mask_inward_offset_m']:
    a.SetUserString(field,None)
   for field,value in {'recipe':bandtag,'world_mask_width_m':str(width),'mask_type':'closed_centerline_band',
   'mask_copy_source_curve_id':key,'mask_centerline_offset_from_top_edge_m':str(half),
   'description':'建筑贴图中线；总宽向两侧各展开一半；闭合曲线恒宽不收尖。展开后的内边界与原种植边界重合，外边界贴顶面边缘。'}.items():a.SetUserString(field,value)
   existing=next((o for o in all_objects if o.Attributes.GetUserString('recipe')==bandtag and o.Attributes.GetUserString('mask_copy_source_curve_id')==key),None)
   if existing:
    assert sc.doc.Objects.Replace(existing.Id,center);oid=existing.Id;assert sc.doc.Objects.ModifyAttributes(oid,a,True)
   else:oid=sc.doc.Objects.AddCurve(center,a)
   assert oid!=System.Guid.Empty;newids.append(str(oid))
   rows.append({'id':str(oid),'source_curve':key,'source_object':host_id,'full_width_m':width,'half_width_m':half,
   'centerline_offset_from_top_edge_m':half,'measured_offset_range_m':[min(distances),max(distances)],'closed':True,'surface_z_m':surface_z})
 finally:sc.doc.EndUndoRecord(undo)
 after={str(o.Id):(int(o.Geometry.DataCRC(0)),o.Attributes.ToJSON(opts))for o in objects()if str(o.Id)in before}
 assert before==after
 sc.doc.Objects.UnselectAll();sc.doc.Views.Redraw()
 report={'target_layer':target,'new_curves':rows,'all_prior_geometry_and_attributes_unchanged':True,
 'original_boundary_curves_preserved':source_ids,'objects':len(objects()),'active_layers':sum(not l.IsDeleted for l in sc.doc.Layers)}
 sc.sticky[bandtag]=report;write('centerline_conversion.json',report)
 return report
