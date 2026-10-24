# -*- coding: utf-8 -*-
"""Two restrained middle-level bridges. Native NURBS belly and integral parapets.

Run staged functions in Rhino. No automatic execution, no alternate CAD file.
"""
from __future__ import unicode_literals,division
import Rhino,scriptcontext as sc,System,math,os,io,json
G=Rhino.Geometry
TAG='middle_simple_bridges_1020'
OUT='D:/Prism Route/prism-route/docs/concepts/middle_links_2026-10-20'
SOURCES=['301ef8a8-0448-4086-b86d-3df7326e1caf',
 '0295f8be-063a-4f5d-90ff-5dabbf9fad42','47800a9c-ca72-4dc5-8203-d6d5d91d29a9']

def objects():
 e=Rhino.DocObjects.ObjectEnumeratorSettings();e.NormalObjects=True;e.HiddenObjects=True;e.LockedObjects=True
 return list(sc.doc.Objects.GetObjectList(e))

def obj(k):return sc.doc.Objects.FindId(System.Guid(k))
def vec(v):return [v.X,v.Y,v.Z]
def unit(v):
 v=G.Vector3d(v);assert v.Unitize();return v
def smooth(t):
 t=max(0.,min(1.,t));return t*t*(3.-2.*t)
def write(name,value):
 with io.open(OUT+'/'+name,'w',encoding='utf-8')as f:f.write(json.dumps(value,ensure_ascii=False,indent=2))

def prepare():
 assert TAG not in sc.sticky,'Reuse the existing staged session rather than resetting it'
 assert sc.doc.Path.replace('\\','/').replace('//','/').lower()=='d:/prism route/map/map_current.3dm'
 ends=[]
 for i,k in enumerate(SOURCES):
  f=obj(k).Geometry.Faces[1 if i==0 else 0]
  cs=[f.IsoCurve(j,f.Domain(1-j).Mid)for j in [0,1]]
  along=0 if cs[0].GetLength()>cs[1].GetLength()else 1;c=cs[along];row=[]
  for t in [c.Domain.T0,c.Domain.T1]:
   edge=f.IsoCurve(1-along,t);p=c.PointAt(t);a=unit(c.TangentAt(t))
   cross=edge.PointAtEnd-edge.PointAtStart
   row.append({'p':p,'t':a,'cross':cross,'width':cross.Length})
  ends.append(row)
 d={'before':{str(o.Id):int(o.Geometry.DataCRC(0))for o in objects()if o.Attributes.GetUserString('recipe')!=TAG},
    'view':Rhino.DocObjects.ViewportInfo(sc.doc.Views.ActiveView.ActiveViewport),
    'selected':[o.Id for o in sc.doc.Objects.GetSelectedObjects(False,False)],
    'ids':{},'sites':{},'host_changes':{}}
 for name,a,b,reverse in [('west',ends[0][1],ends[1][0],False),('east',ends[1][1],ends[2][1],True)]:
  L=a['p'].DistanceTo(b['p']);bt=-b['t']if reverse else b['t']
  c=G.NurbsCurve.Create(False,3,[a['p'],a['p']+a['t']*(L/3.),b['p']-bt*(L/3.),b['p']]);c.Domain=G.Interval(0,1)
  d['sites'][name]={'curve':c,'chord':L,'length':c.GetLength(),'a':a,'b':b,'reverse_b':reverse}
 sc.sticky[TAG]=d
 return {'baseline_objects':len(d['before']),'lengths_m':{k:v['length']for k,v in d['sites'].items()}}

def frame(name,x):
 d=sc.sticky[TAG]['sites'][name];c=d['curve'];t=x/d['chord'];tt=max(0.,min(1.,t))
 p=c.PointAt(tt);a=unit(c.TangentAt(tt))
 if t<0:p+=a*x
 elif t>1:p+=a*(x-d['chord'])
 n=unit(G.Vector3d(-a.Y,a.X,0.))
 width=d['a']['width']*(1-tt)+d['b']['width']*tt
 # End crossfalls are taken from the source road sections, with orientation
 # aligned to the travel frame. The source sections here are almost horizontal.
 cross=[]
 for endpoint in [d['a'],d['b']]:
  v=unit(endpoint['cross'])
  if G.Vector3d.Multiply(v,n)<0:v=-v
  cross.append(v)
 roll=(cross[0].Z*(1-tt)+cross[1].Z*tt)
 n=unit(G.Vector3d(n.X,n.Y,roll))
 return p,a,n,width

def point(name,x,y,z):
 p,a,n,w=frame(name,x);return p+n*y+G.Vector3d(0,0,z)

def section(name,x):
 d=sc.sticky[TAG]['sites'][name];t=x/d['chord']
 mid=1.75 if name=='west'else 1.25;end=6.1 if name=='west'else 3.5
 depth=mid+(end-mid)*(2*t-1)**2
 flare=1.+.065*(2*t-1)**4
 h=.12+.83*smooth((x+5)/5.)*smooth((d['chord']+5-x)/5.)
 profiles=[
  [(-10.8,-.11),(10.8,-.11)],
  [(10.8,-.11),(10.8,.45*h),(10.8,h),(11.15,h)],
  [(11.15,h),(11.75,h),(12.2,h),(12.2,h-.65)],
  [(12.2,h-.65),(12.2,-(depth-.2)*.45),(12.2,-depth+.35),(11.2,-depth+.2)],
  [(11.2,-depth+.2),(9.2,-depth-.1),(4.,-depth-.45),(-4.,-depth-.45),(-9.2,-depth-.1),(-11.2,-depth+.2)],
  [(-11.2,-depth+.2),(-12.2,-depth+.35),(-12.2,-(depth-.2)*.45),(-12.2,h-.65)],
  [(-12.2,h-.65),(-12.2,h),(-11.75,h),(-11.15,h)],
  [(-11.15,h),(-10.8,h),(-10.8,.45*h),(-10.8,-.11)]]
 curves=[]
 for yz in profiles:
  pts=[point(name,x,y*flare,z)for y,z in yz]
  curves.append(G.LineCurve(*pts)if len(pts)==2 else G.NurbsCurve.Create(False,len(pts)-1,pts))
 return curves

def build(name):
 d=sc.sticky[TAG]['sites'][name];L=d['chord']
 xs=[-6.+(L+12)*i/48. for i in range(49)]
 sections=[section(name,x)for x in xs];parts=[]
 for j in range(8):
  # A common longitudinal control basis makes adjacent surface boundaries
  # exactly identical. Independent lofts otherwise choose different parameters.
  curves=[cs[j].ToNurbsCurve()for cs in sections];nv=curves[0].Points.Count
  pts=[c.Points[k].Location for c in curves for k in range(nv)]
  surface=G.NurbsSurface.CreateFromPoints(pts,len(xs),nv,3,nv-1)
  assert surface and surface.IsValid;parts.append(surface.ToBrep())
 joined=G.Brep.JoinBreps(parts,.001);assert joined and len(joined)==1
 body=joined[0].CapPlanarHoles(.001)
 d['debug_body']=body;d['debug_open']=joined[0]
 assert body and body.IsValid and body.IsSolid and body.IsManifold,('body',name,body.IsValid if body else None,body.IsSolid if body else None,body.Faces.Count if body else None)
 if body.SolidOrientation==G.BrepSolidOrientation.Inward:body.Flip()
 asphalt=[]
 for i in range(41):
  x=-.06+(L+.12)*i/40.;p,a,n,w=frame(name,x)
  asphalt.append(G.LineCurve(p-n*(w/2),p+n*(w/2)))
 top=G.Brep.CreateFromLoft(asphalt,G.Point3d.Unset,G.Point3d.Unset,G.LoftType.Normal,False)[0]
 f=top.Faces[0]
 if f.NormalAt(f.Domain(0).Mid,f.Domain(1).Mid).Z<0:top.Flip()
 paving=G.Brep.CreateFromOffsetFace(top.Faces[0],-.18,.001,False,True)
 assert paving and paving.IsValid and paving.IsSolid
 d['body']=body;d['paving']=paving
 return {'site':name,'body_faces':body.Faces.Count,'body_solid':body.IsSolid,'paving_faces':paving.Faces.Count,'length_m':d['length']}

def mesh(b,step=1.2):
 mp=G.MeshingParameters.Default;mp.Tolerance=.005;mp.MaximumEdgeLength=step;mp.MinimumEdgeLength=.02
 m=G.Mesh()
 for q in G.Mesh.CreateFromBrep(b,mp):m.Append(q)
 m.Normals.ComputeNormals();m.Compact();return m

def cache(name):
 d=sc.sticky[TAG];v=d['sites'][name];v['mesh']=mesh(v['body'])
 box=v['body'].GetBoundingBox(True);box.Inflate(7.);rows=[]
 for o in objects():
  if str(o.Id)not in d['before']or o.IsHidden:continue
  g=o.Geometry
  if not isinstance(g,(G.Brep,G.Mesh,G.SubD,G.Extrusion)):continue
  b=g.GetBoundingBox(True)
  if any([b.Max.X<box.Min.X,b.Min.X>box.Max.X,b.Max.Y<box.Min.Y,b.Min.Y>box.Max.Y,b.Max.Z<box.Min.Z,b.Min.Z>box.Max.Z+8]):continue
  if isinstance(g,G.Mesh):ms=[g]
  elif isinstance(g,G.SubD):ms=[G.Mesh.CreateFromSubD(g,2)]
  else:
   ms=list(o.GetMeshes(G.MeshType.Render)or[])
   if not ms:ms=[mesh(g.ToBrep()if isinstance(g,G.Extrusion)else g,3.)]
  merged=G.Mesh()
  for q in ms:merged.Append(q)
  merged.Normals.ComputeNormals();merged.Compact();rows.append((str(o.Id),merged))
 v['host_meshes']=rows
 return {'site':name,'new_mesh_faces':v['mesh'].Faces.Count,'nearby_objects':len(rows),'existing_mesh_faces':sum(m.Faces.Count for k,m in rows)}

def check(name):
 d=sc.sticky[TAG];v=d['sites'][name];m=v['mesh'];gaps=[];bad=[];hits=[];head=[]
 samples=sorted(set([v['chord']*i/120. for i in range(121)]+[.02,.15,.5,1.,2.,v['chord']-.02,v['chord']-.15,v['chord']-.5,v['chord']-1.,v['chord']-2.]))
 for x in samples:
  p,a,n,w=frame(name,x)
  for y in [-9.5,-5.,0.,5.,9.5]:
   q=p+n*y;down=G.Intersect.Intersection.MeshRay(m,G.Ray3d(q+G.Vector3d(0,0,.02),-G.Vector3d.ZAxis))
   if down<0:bad.append([x,y,'missing support'])
   else:gaps.append(down-.02)
   ray=G.Ray3d(q+G.Vector3d(0,0,.15),G.Vector3d.ZAxis)
   up=G.Intersect.Intersection.MeshRay(m,ray)
   if 0<=up<=5.85:bad.append([x,y,'new body overhead',up+.15])
   for k,host in v['host_meshes']:
    z=G.Intersect.Intersection.MeshRay(host,ray)
    if 0<=z<=5.85:hits.append([x,y,k,z+.15])
    if z>=0:head.append(z+.15)
 v['check']={'vertical_count':len(samples)*5,'support_gap_m':[min(gaps),max(gaps)],'new_body_problems':bad,
  'existing_intrusions':hits,'existing_min_headroom_m':min(head)if head else None}
 return {'site':name,'vertical_count':len(samples)*5,'support_gap_m':[min(gaps),max(gaps)],'new_body_problems':bad[:5],
 'existing_intrusion_count':len(hits),'existing_intrusion_sample':hits[:15],'existing_min_headroom_m':min(head)if head else None}

def publish():
 d=sc.sticky[TAG];layer=sc.doc.Layers.FindByFullPath('交通::中层道路',-1);assert layer>=0
 mi=next(i for i,m in enumerate(sc.doc.Materials)if m.Name=='隧道_暖白建筑复合面_PBR_非金属')
 rec=sc.doc.BeginUndoRecord('东西中层连接桥_浅拱桥腹与低护缘')
 try:
  for site,label in [('west','西侧'),('east','东侧')]:
   v=d['sites'][site]
   for part,title in [('body','连续浅拱桥腹与一体低护缘'),('paving','20米路面')]:
    role=site+'_'+part;existing=next((o for o in objects()if o.Attributes.GetUserString('middle_bridge_role')==role),None)
    if existing:
     assert sc.doc.Objects.Replace(existing.Id,v[part]);oid=existing.Id
    else:
     a=Rhino.DocObjects.ObjectAttributes();a.Name=label+'中层连接桥_'+title;a.LayerIndex=layer;a.WireDensity=-1
     a.SetUserString('recipe',TAG);a.SetUserString('middle_bridge_role',role)
     if part=='body':a.MaterialIndex=mi;a.MaterialSource=Rhino.DocObjects.ObjectMaterialSource.MaterialFromObject
     else:
      source=obj(SOURCES[1]).Attributes;a.MaterialIndex=source.MaterialIndex;a.MaterialSource=source.MaterialSource
      a.ColorSource=source.ColorSource;a.ObjectColor=source.ObjectColor
     oid=sc.doc.Objects.AddBrep(v[part],a);assert oid!=System.Guid.Empty
    d['ids'][role]=str(oid)
 finally:sc.doc.EndUndoRecord(rec)
 sc.doc.Objects.UnselectAll();sc.doc.Views.Redraw();return d['ids']

def capture(name,camera,target):
 view=sc.doc.Views.ActiveView;vp=view.ActiveViewport
 vp.ChangeToPerspectiveProjection(True,42.);vp.SetCameraLocations(G.Point3d(*target),G.Point3d(*camera));vp.CameraUp=G.Vector3d.ZAxis
 sc.doc.Objects.UnselectAll();sc.doc.Views.Redraw()
 vc=Rhino.Display.ViewCapture();vc.Width=1600;vc.Height=1050;vc.DrawAxes=False;vc.DrawGrid=False;vc.DrawGridAxes=False
 bitmap=vc.CaptureToBitmap(view);assert bitmap
 path=OUT+'/'+name+'.png';bitmap.Save(path,System.Drawing.Imaging.ImageFormat.Png);bitmap.Dispose();return path

def check_longitudinal(name):
 v=sc.sticky[TAG]['sites'][name];hits=[];count=0
 for y in [-9.5,0.,9.5]:
  for z in [.25,1.5,4.5,6.]:
   pts=[point(name,-6+(v['chord']+12)*i/80.,y,z)for i in range(81)]
   for i in range(80):
    line=G.Line(pts[i],pts[i+1]);count+=1
    for k,m in [('new_body',v['mesh'])]+v['host_meshes']:
     intersections=G.Intersect.Intersection.MeshLine(m,line)
     if intersections is not None and len(intersections)>0:hits.append([y,z,i,k,vec(intersections[0])])
 v['longitudinal_check']={'segments':count,'hits':hits}
 return {'site':name,'segments':count,'hit_count':len(hits),'sample':hits[:10]}

def verify():
 d=sc.sticky[TAG];rows={}
 changed=[k for k,crc in d['before'].items()if obj(k)is None or int(obj(k).Geometry.DataCRC(0))!=crc]
 assert not changed,('Existing geometry was altered',changed)
 for name,v in d['sites'].items():
  b=v['body'];assert b.IsValid and b.IsSolid and b.IsManifold
  assert v['paving'].IsValid and v['paving'].IsSolid
  assert not v['check']['new_body_problems'] and not v['check']['existing_intrusions']
  assert v['check']['support_gap_m'][0]>0 and v['check']['support_gap_m'][1]<.18
  assert not v['longitudinal_check']['hits']
  graph={i:set(f.AdjacentFaces())for i,f in enumerate(b.Faces)}
  seen=set();todo=[0]
  while todo:
   i=todo.pop()
   if i in seen:continue
   seen.add(i);todo.extend(graph[i]-seen)
  assert len(seen)==b.Faces.Count
  top=max([f for f in v['paving'].Faces if abs(f.NormalAt(f.Domain(0).Mid,f.Domain(1).Mid).Z)>.9],
          key=lambda f:f.PointAt(f.Domain(0).Mid,f.Domain(1).Mid).Z)
  gaps=[];grades=[]
  for x,e in [(0.,v['a']),(v['chord'],v['b'])]:
   p,a,n,w=frame(name,x)
   for y in [-w/2,-w/4,0.,w/4,w/2]:
    q=p+n*y;ok,u,t=top.ClosestPoint(q);assert ok
    gaps.append(q.DistanceTo(top.PointAt(u,t)))
   q=p;ok,u,t=top.ClosestPoint(q);cs=[top.IsoCurve(i,top.Domain(1-i).Mid)for i in [0,1]]
   along=0 if cs[0].GetLength()>cs[1].GetLength()else 1
   curve=cs[along];ok,param=curve.ClosestPoint(q);newt=unit(curve.TangentAt(param))
   oldt=unit(e['t'])
   grades.append(math.degrees(math.acos(min(1.,abs(G.Vector3d.Multiply(newt,oldt))))))
  assert max(gaps)<.002 and max(grades)<.1,('road seam',name,gaps,grades)
  for part in ['body','paving']:
   oid=d['ids'][name+'_'+part];assert G.GeometryBase.GeometryEquals(obj(oid).Geometry,v[part])
  rows[name]={'length_m':v['length'],'gap_chord_m':v['chord'],'road_width_m':20.,
   'body_faces':b.Faces.Count,'body_valid':True,'body_solid':True,'manifold':True,'connected_components':1,
   'naked_edges':sum(e.Valence==G.EdgeAdjacency.Naked for e in b.Edges),'paving_faces':v['paving'].Faces.Count,
   'native_nurbs_side_surfaces':sum(isinstance(f.UnderlyingSurface(),G.NurbsSurface)for f in b.Faces),
   'road_join_max_gap_m':max(gaps),'road_join_max_tangent_angle_degrees':max(grades),
   'support_clearance':v['check'],'longitudinal_clearance':v['longitudinal_check']}
 report={'document':sc.doc.Path,'ids':d['ids'],'bridges':rows,'unchanged_original_objects':len(d['before']),
   'object_count':len(objects()),'active_layer_count':sum(not layer.IsDeleted for layer in sc.doc.Layers),
   'limitations':['Sampled Rhino geometry and clearance checks; Godot driving/collision and engineering load verification not performed.']}
 d['report']=report;write('model_validation.json',report)
 return report

def save_current():
 d=sc.sticky[TAG];assert 'report'in d
 assert sc.doc.Path.replace('\\','/').replace('//','/').lower()=='d:/prism route/map/map_current.3dm'
 assert Rhino.RhinoApp.RunScript('_Save',False)
 disk=Rhino.FileIO.File3dm.Read(sc.doc.Path);assert disk
 live={str(o.Id):int(o.Geometry.DataCRC(0))for o in objects()}
 saved={str(o.Id):int(o.Geometry.DataCRC(0))for o in disk.Objects}
 assert live==saved,'Saved object IDs or geometry CRC differ from live document'
 disk.Dispose();d['report']['saved_file_crc_matches']=True
 d['report']['saved_object_count']=len(saved);write('model_validation.json',d['report'])
 return {'saved':sc.doc.Path,'matched_objects':len(saved)}
