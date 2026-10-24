# -*- coding: utf-8 -*-
"""Main curved bridge B: raised deck, four courtyard shells, loop towers and stays.
Staged Rhino 8 recipe. Mutates only the eight placeholder-island objects and
publishes role-tagged finished assets. No hidden intermediate document objects.
"""
from __future__ import unicode_literals,division
import Rhino,scriptcontext as sc,System,math,json,io,os
G=Rhino.Geometry
TAG='main_cable_bridge_B_1020'
OUT='D:/Prism Route/prism-route/docs/concepts/main_cable_bridge_B_model_2026-10-20'
CURVE='5bd0e22f-8527-419b-be32-8db5b1c3232d'
TOPS=['580b55d4-797c-49fa-ba1d-f2c9d74e4d03','0c51b890-631a-4633-b1b4-1682b8736500','eda8bdb1-ff67-4448-a07f-e78e6914d209','88eb76d2-2c5c-4c70-b64a-dd922afa1433']
BASES=['4df36f45-d898-40ce-8a5d-7802a8711ae2','2068dd45-fc33-4cb3-b561-4cbfe1b7330a','886652a9-6613-4f5e-b1fc-01aa8b5259d7','73e5d619-0b3e-4b57-ba79-be508a583cba']
SHORE=['305479e8-59d9-4a89-bcf6-204f69186e51','ee277b2d-e4eb-4d39-80e6-c5d8a5d87d70']
ROOF='ce36cdce-398b-44f5-b0b4-fe7f258106cf'

def objects():
 e=Rhino.DocObjects.ObjectEnumeratorSettings();e.NormalObjects=True;e.HiddenObjects=True;e.LockedObjects=True
 return list(sc.doc.Objects.GetObjectList(e))
def obj(k):return sc.doc.Objects.FindId(System.Guid(k))
def xyz(p):return [p.X,p.Y,p.Z]
def unit(v):
 v=G.Vector3d(v);assert v.Unitize();return v
def smooth(t):
 t=max(0.,min(1.,t));return t*t*t*(10.-15*t+6*t*t)
def write(name,data):
 with io.open(OUT+'/'+name,'w',encoding='utf-8')as f:f.write(json.dumps(data,ensure_ascii=False,indent=2))
def mesh(b,step=2.):
 mp=G.MeshingParameters.Default;mp.Tolerance=.008;mp.MaximumEdgeLength=step;mp.MinimumEdgeLength=.03
 m=G.Mesh()
 for q in G.Mesh.CreateFromBrep(b,mp):m.Append(q)
 m.Normals.ComputeNormals();m.Compact();return m

def prepare():
 assert TAG not in sc.sticky,'Reuse staged state'
 assert sc.doc.Path.replace('\\','/').replace('//','/').lower()=='d:/prism route/map/map_current.3dm'
 if not os.path.isdir(OUT):os.makedirs(OUT)
 c=obj(CURVE).Geometry.DuplicateCurve();L=c.GetLength();ends=[]
 for i,k in enumerate(SHORE):
  f=obj(k).Geometry.Faces[0];cs=[f.IsoCurve(j,f.Domain(1-j).Mid)for j in [0,1]]
  along=0 if cs[0].GetLength()>cs[1].GetLength()else 1;a=cs[along];t=a.Domain.T1
  q=f.IsoCurve(1-along,t);tangent=unit(a.TangentAt(t))
  if i==1:tangent=-tangent
  ends.append({'p':a.PointAt(t),'t':tangent,'cross':q.PointAtEnd-q.PointAtStart,'width':q.GetLength()})
 d={'before':{str(o.Id):int(o.Geometry.DataCRC(0))for o in objects()if o.Attributes.GetUserString('recipe')!=TAG},
  'curve':c,'length':L,'ends':ends,'islands':[],'towers':{},'parts':{},'ids':{},
  'view':Rhino.DocObjects.ViewportInfo(sc.doc.Views.ActiveView.ActiveViewport),
  'roof_mesh':sc.sticky.get('main_B_roof_mesh')or mesh(obj(ROOF).Geometry,2.)}
 sc.sticky[TAG]=d
 for k in TOPS:
  b=obj(k).Geometry;bound=b.Faces[0].OuterLoop.To3dCurve();bb=b.GetBoundingBox(True);center=bb.Center;center.Z=0.
  ok,t=c.ClosestPoint(G.Point3d(center.X,center.Y,60));assert ok
  station=c.GetLength(G.Interval(c.Domain.T0,t))
  d['islands'].append({'center':center,'outline':bound,'station':station})
 return {'baseline_objects':len(d['before']),'route_length_m':L,'island_stations':[v['station']for v in d['islands']]}

def base_height(s):
 d=sc.sticky[TAG];L=d['length'];t=max(0,min(1,s/L));a,b=d['ends']
 z=a['p'].Z+(b['p'].Z-a['p'].Z)*smooth(t)
 z+=a['t'].Z*s*(1-smooth(s/35.))
 z-=b['t'].Z*(L-s)*(1-smooth((L-s)/35.))
 return z
def height(s):
 w=smooth(s/185.)*(1-smooth((s-310.)/200.))
 return base_height(s)*(1-w)+63.45*w

def frame(s):
 d=sc.sticky[TAG];L=d['length'];ss=max(0.,min(L,s));ok,t=d['curve'].LengthParameter(ss);assert ok
 p=d['curve'].PointAt(t);a=unit(d['curve'].TangentAt(t))
 # Preserve original plan alignment, matching the actual shore endpoints.
 for x,edge in [(0.,d['ends'][0]),(L,d['ends'][1])]:
  delta=edge['p']-d['curve'].PointAtStart if x==0 else edge['p']-d['curve'].PointAtEnd
  delta.Z=0;weight=1-smooth(abs(ss-x)/45.);p+=delta*weight
 if s<0:p+=d['ends'][0]['t']*s
 if s>L:p+=d['ends'][1]['t']*(s-L)
 p.Z=height(ss)
 if s<0:p.Z+=d['ends'][0]['t'].Z*s
 if s>L:p.Z+=d['ends'][1]['t'].Z*(s-L)
 n=unit(G.Vector3d(-a.Y,a.X,0))
 return p,a,n

def point(s,y,z=0.):
 p,a,n=frame(s);return p+n*y+G.Vector3d(0,0,z)

def solid_loft(cs,closed=False):
 result=G.Brep.CreateFromLoft(cs,G.Point3d.Unset,G.Point3d.Unset,G.LoftType.Normal,closed)
 assert result and len(result)==1
 b=result[0]
 if not closed:b=b.CapPlanarHoles(.003)
 assert b and b.IsValid and b.IsSolid and b.IsManifold
 if b.SolidOrientation==G.BrepSolidOrientation.Inward:b.Flip()
 return b

def deck_section(s):
 # Continuous deck with low lips and rounded underside, all at a common basis.
 h=.83
 shapes=[
 [(-11.3,-.11),(11.3,-.11)],
 [(11.3,-.11),(11.3,.4),(11.3,h),(11.65,h)],
 [(11.65,h),(12.3,h),(13.35,h),(13.35,.12)],
 [(13.35,.12),(13.35,-.9),(13.1,-1.45),(12.0,-1.60)],
 [(12.,-1.60),(9.,-2.0),(4.,-2.25),(-4.,-2.25),(-9.,-2.0),(-12.,-1.60)],
 [(-12.,-1.60),(-13.1,-1.45),(-13.35,-.9),(-13.35,.12)],
 [(-13.35,.12),(-13.35,h),(-12.3,h),(-11.65,h)],
 [(-11.65,h),(-11.3,h),(-11.3,.4),(-11.3,-.11)]]
 curves=[]
 for yz in shapes:
  pts=[point(s,y,z)for y,z in yz]
  curves.append(G.NurbsCurve.Create(False,len(pts)-1,pts))
 return curves

def build_deck():
 d=sc.sticky[TAG];L=d['length'];xs=[-1.5+(L+3)*i/240. for i in range(241)]
 profiles=[deck_section(s)for s in xs];parts=[]
 for j in range(8):
  nv=profiles[0][j].Points.Count
  pts=[c[j].Points[k].Location for c in profiles for k in range(nv)]
  sf=G.NurbsSurface.CreateFromPoints(pts,len(xs),nv,3,nv-1);assert sf
  parts.append(sf.ToBrep())
 joined=G.Brep.JoinBreps(parts,.002);assert joined and len(joined)==1
 body=joined[0].CapPlanarHoles(.002);assert body and body.IsValid and body.IsSolid
 if body.SolidOrientation==G.BrepSolidOrientation.Inward:body.Flip()
 curves=[G.LineCurve(point(-.04+(L+.08)*i/240.,-10),point(-.04+(L+.08)*i/240.,10))for i in range(241)]
 top=G.Brep.CreateFromLoft(curves,G.Point3d.Unset,G.Point3d.Unset,G.LoftType.Normal,False)[0]
 f=top.Faces[0]
 if f.NormalAt(f.Domain(0).Mid,f.Domain(1).Mid).Z<0:top.Flip()
 paving=G.Brep.CreateFromOffsetFace(top.Faces[0],-.18,.001,False,True)
 assert paving and paving.IsValid and paving.IsSolid
 d['parts']['deck_body']=body;d['parts']['deck_paving']=paving
 d['deck_mesh']=mesh(body,2.)
 return {'faces':body.Faces.Count,'paving_faces':paving.Faces.Count,'min_z':min(height(L*i/1000.)for i in range(1001)),'max_z':max(height(L*i/1000.)for i in range(1001))}

def edge(i,u):
 v=sc.sticky[TAG]['islands'][i];p=v['outline'].PointAtNormalizedLength(u%1.);p.Z=0.
 return p

def roof_z(i,u):
 return [24.,32.,22.,30.][i]+11.*math.cos(2*math.pi*u+.5)+4.5*math.sin(4*math.pi*u-.4)

def annular(i,base=False):
 v=sc.sticky[TAG]['islands'][i];c=v['center'];cs=[]
 for j in range(56):
  u=j/56.;p=edge(i,u);r=p-c;H=roof_z(i,u)
  yz=[(.46,4.2),(.65,4.2),(1.05,4.2),(1.075,2.4),(1.05,-1.6),(.62,-1.6),(.45,-1.6),(.43,1.4)]if base else[
   (.49,H),(.61,H+.5),(.88,H+1.5),(1.05,H),(1.075,H-1.5),(.99,H-4.0),(.68,H-3.2),(.49,H-2.8),(.47,H-1.3)]
  pts=[]
  for scale,z in yz:
   q=c+r*scale;q.Z=z;pts.append(q)
  cs.append(G.NurbsCurve.Create(True,3,pts))
 return solid_loft(cs,True)

def column(bottom,top,r0=2.2,r1=4.0):
 pts=[];dv=top-bottom
 for j in range(7):
  t=j/6.;p=bottom+dv*t
  # Broad feet and shoulders, narrow shaft, with a mild directional curve.
  offset=G.Vector3d(-dv.Y,dv.X,0.);offset=unit(offset)if offset.Length>.001 else G.Vector3d.XAxis
  p+=offset*(1.4*math.sin(math.pi*t))
  radius=r0*(1-t)+r1*t-1.6*math.sin(math.pi*t)
  radius=max(1.0,radius)
  pts.append(G.Ellipse(G.Plane(p,G.Vector3d.ZAxis),radius,radius*.72).ToNurbsCurve())
 return solid_loft(pts)

def build_island(i):
 d=sc.sticky[TAG];v=d['islands'][i];v['roof']=annular(i);v['base']=annular(i,True);columns=[]
 for j in range(8):
  u=(j+.18)/8.;c=v['center'];r=edge(i,u)-c
  bottom=c+r*.77;bottom.Z=2.8
  top=c+r*.78;top.Z=roof_z(i,u)-1.8
  columns.append(column(bottom,top,2.8,4.8))
 # Four flared bridge seats on each annular foundation.
 for ds in [-20.,20.]:
  for sign in [-1,1]:
   top=point(v['station']+ds,sign*12.1,-.55)
   nearest=min(range(120),key=lambda j:edge(i,j/120.).DistanceTo(G.Point3d(top.X,top.Y,0)))
   r=edge(i,nearest/120.)-v['center'];bottom=v['center']+r*.79;bottom.Z=2.8
   columns.append(column(bottom,top,3.6,5.5))
 group=G.Brep()
 for b in columns:group.Append(b)
 assert group.IsValid and group.IsSolid
 v['columns']=group;v['column_parts']=columns
 return {'island':i,'station':v['station'],'roof_faces':v['roof'].Faces.Count,'base_faces':v['base'].Faces.Count,'columns':len(columns),'roof_solid':v['roof'].IsSolid}

def tower_local(i,x,y,z):
 v=sc.sticky[TAG]['islands'][i];p,t,n=frame(v['station'])
 t.Z=0;t=unit(t);p.Z=0
 return p+t*x+n*y+G.Vector3d(0,0,z)

def build_tower(i):
 d=sc.sticky[TAG];assert i in [1,3]
 scale=1. if i==1 else .80;flip=1. if i==1 else -1.
 local=[(-26,-38,3),(-38,-39,20),(-46,-34,70),(-60,-26,140),(-68,-12,197),(-51,-6,218),
  (-25,-8,210),(-2,-17,164),(9,-28,100),(15,-36,42),(7,-39,6),(-8,-40,0)]
 pts=[tower_local(i,x*flip,y,z*scale)for x,y,z in local]
 rail=G.NurbsCurve.Create(True,3,pts)
 p,t,n=frame(d['islands'][i]['station']);t.Z=0;t=unit(t)
 bn=unit(G.Vector3d.CrossProduct(t,G.Vector3d.ZAxis+n*.15));cs=[]
 for j in range(64):
  par=rail.Domain.ParameterAt(j/64.);q=rail.PointAt(par);a=unit(rail.TangentAt(par));r=unit(G.Vector3d.CrossProduct(bn,a))
  f=max(0.,min(1.,q.Z/(205.*scale)));rw=(4.8+9.0*(1-f)**2)*(.9 if i==3 else 1.);rt=3.2+1.2*(1-f)
  cs.append(G.Ellipse(G.Plane(q,r,bn),rw,rt).ToNurbsCurve())
 body=solid_loft(cs,True);d['towers'][i]={'body':body,'rail':rail,'sections':cs}
 return {'island':i,'faces':body.Faces.Count,'solid':body.IsSolid,'bbox':[xyz(body.GetBoundingBox(True).Min),xyz(body.GetBoundingBox(True).Max)]}

def island_layer():
 name='建筑::主桥岛体';i=sc.doc.Layers.FindByFullPath(name,-1)
 if i>=0:return i
 parent=sc.doc.Layers.FindByFullPath('建筑',-1);assert parent>=0
 layer=Rhino.DocObjects.Layer();layer.Name='主桥岛体';layer.ParentLayerId=sc.doc.Layers[parent].Id
 return sc.doc.Layers.Add(layer)

def publish():
 assert not any(o.Attributes.GetUserString('recipe')=='main_bridge_twist_compare_20261021'for o in objects()),'B2 is already published. Do not republish retired B1 towers or overwrite later island edits.'
 d=sc.sticky[TAG]
 d.setdefault('before_attrs',{str(o.Id):o.Attributes.ToJSON(Rhino.FileIO.SerializationOptions())for o in objects()if str(o.Id)in d['before']})
 white=next(i for i,m in enumerate(sc.doc.Materials)if m.Name=='隧道_暖白建筑复合面_PBR_非金属')
 structure_layer=island_layer();road_layer=sc.doc.Layers.FindByFullPath('交通::上层道路',-1)
 undo=sc.doc.BeginUndoRecord('主斜拉桥B_环塔与水庭四岛')
 try:
  entries=[]
  for i,v in enumerate(d['islands']):
   entries.extend([('island_%d_roof'%i,v['roof'],'主桥B_岛%d_连续曲面水庭屋盖'%(i+1),structure_layer,TOPS[i],False),
    ('island_%d_base'%i,v['base'],'主桥B_岛%d_环形临水基座'%(i+1),structure_layer,BASES[i],False),
    ('island_%d_columns'%i,v['columns'],'主桥B_岛%d_倾斜廊柱与桥面承托'%(i+1),structure_layer,None,False)])
  entries.extend([('deck_body',d['parts']['deck_body'],'主桥B_抬升穿岛连续桥腹与低护缘',road_layer,None,False),
   ('deck_paving',d['parts']['deck_paving'],'主桥B_沿原中线抬升20米路面',road_layer,None,True)])
  for i,v in d['towers'].items():
   entries.append(('tower_%d'%i,v['body'],'主桥B_岛%d_倾斜连续环塔'%(i+1),road_layer,None,False))
   if 'stays'in v:entries.append(('stays_%d'%i,v['stays'],'主桥B_岛%d_双侧空间斜拉索'%(i+1),road_layer,None,False))
  for role,g,name,layer,fixed,asphalt in entries:
   current=obj(fixed)if fixed else next((o for o in objects()if o.Attributes.GetUserString('main_bridge_B_role')==role),None)
   if current:
    assert sc.doc.Objects.Replace(current.Id,g),('Replace',role);oid=current.Id;a=current.Attributes.Duplicate()
   else:
    a=Rhino.DocObjects.ObjectAttributes();oid=None
   a.Name=name;a.LayerIndex=layer;a.WireDensity=-1;a.SetUserString('recipe',TAG);a.SetUserString('main_bridge_B_role',role)
   a.SetUserString('description','B方案成品构件；水庭岛体与环塔，不是隐藏中间件。')
   a.MaterialSource=Rhino.DocObjects.ObjectMaterialSource.MaterialFromObject;a.MaterialIndex=white
   if asphalt:
    source=obj(SHORE[0]).Attributes;a.MaterialIndex=source.MaterialIndex;a.MaterialSource=source.MaterialSource;a.ObjectColor=source.ObjectColor;a.ColorSource=source.ColorSource
   if oid:assert sc.doc.Objects.ModifyAttributes(oid,a,True)
   else:
    oid=sc.doc.Objects.AddMesh(g,a)if isinstance(g,G.Mesh)else sc.doc.Objects.AddBrep(g,a)
    assert oid!=System.Guid.Empty,role
   d['ids'][role]=str(oid)
 finally:sc.doc.EndUndoRecord(undo)
 sc.doc.Objects.UnselectAll();sc.doc.Views.Redraw()
 return d['ids']

def capture(name,camera,target):
 view=sc.doc.Views.ActiveView;vp=view.ActiveViewport
 vp.ChangeToPerspectiveProjection(True,42.);vp.SetCameraLocations(G.Point3d(*target),G.Point3d(*camera));vp.CameraUp=G.Vector3d.ZAxis
 sc.doc.Objects.UnselectAll();sc.doc.Views.Redraw()
 vc=Rhino.Display.ViewCapture();vc.Width=1800;vc.Height=1200;vc.DrawAxes=False;vc.DrawGrid=False;vc.DrawGridAxes=False
 bmp=vc.CaptureToBitmap(view);assert bmp
 path=OUT+'/'+name+'.png';bmp.Save(path,System.Drawing.Imaging.ImageFormat.Png);bmp.Dispose();return path

def traffic_mesh():
 d=sc.sticky[TAG];L=d['length'];m=G.Mesh();count=301
 for j in range(count):
  s=L*j/(count-1.)
  # Include clearance for the 0.17 m cable radius around the vehicle corridor.
  for y,z in [(-10.25,0.),(10.25,0.),(10.25,6.25),(-10.25,6.25)]:m.Vertices.Add(point(s,y,z))
 for j in range(count-1):
  for k in range(4):
   a=j*4+k;b=j*4+(k+1)%4;m.Faces.AddFace(a,b,b+4,a+4)
 m.Faces.AddFace(3,2,1,0);n=(count-1)*4;m.Faces.AddFace(n,n+1,n+2,n+3)
 m.Normals.ComputeNormals();m.Compact();d['traffic_mesh']=m
 return m

def build_stays(i):
 d=sc.sticky[TAG];v=d['towers'][i];station=d['islands'][i]['station'];rail=v['rail']
 corridor=d.get('traffic_mesh')or traffic_mesh()
 p,t,n=frame(station);t.Z=0;t=unit(t)
 candidates=[rail.PointAt(rail.Domain.ParameterAt(j/800.))for j in range(800)]
 bounds=(125.,745.,42)if i==1 else(655.,d['length']-8.,30)
 meshout=G.Mesh();rows=[];skipped=[]
 for j in range(bounds[2]):
  s=bounds[0]+(bounds[1]-bounds[0])*j/(bounds[2]-1.)
  if abs(s-station)<24.:continue
  scale=1. if i==1 else .8;goal=(140.+55*min(1.,abs(s-station)/260.))*scale
  possibles=sorted(candidates,key=lambda q:abs(q.Z-goal))[:18]
  anchor=min(possibles,key=lambda q:G.Vector3d.Multiply(q-p,t))if s<station else max(possibles,key=lambda q:G.Vector3d.Multiply(q-p,t))
  for sign in [-1,1]:
   a=point(s,sign*12.7,.25);b=G.Point3d(anchor)
   line=G.Line(a,b);hits=G.Intersect.Intersection.MeshLine(corridor,line)
   if hits is not None and len(hits):
    skipped.append({'s':s,'side':sign,'reason':'traffic volume intersection'});continue
   length=a.DistanceTo(b);plane=G.Plane(a,unit(b-a));cyl=G.Cylinder(G.Circle(plane,.17),length)
   tube=G.Mesh.CreateFromCylinder(cyl,1,10,True,True);assert tube and tube.IsClosed
   meshout.Append(tube);rows.append({'station':s,'side':sign,'deck_anchor':xyz(a),'tower_anchor':xyz(b),'length_m':length})
 meshout.Normals.ComputeNormals();meshout.Compact();assert meshout.IsValid and meshout.IsClosed
 v['stays']=meshout;v['stay_rows']=rows;v['skipped']=skipped
 return {'island':i,'cables':len(rows),'rejected':len(skipped),'mesh_faces':meshout.Faces.Count}

def cache_new():
 d=sc.sticky[TAG];rows=[]
 rows.append(('deck_body',d['parts']['deck_body'],d['deck_mesh']))
 for i,v in enumerate(d['islands']):
  for role in ['roof','base','columns']:rows.append(('island_%d_%s'%(i,role),v[role],mesh(v[role],2.)))
 for i,v in d['towers'].items():
  rows.append(('tower_%d'%i,v['body'],mesh(v['body'],2.)))
 d['new_meshes']=rows
 return {'components':len(rows),'faces':sum(m.Faces.Count for k,b,m in rows)}

def check_traffic():
 d=sc.sticky[TAG];L=d['length'];support=[];newhits=[];existinghits=[];terrain=[];anchors=[]
 # Add old, unchanged adjacent architecture that overlaps the road plan bounds.
 bounds=d['parts']['deck_body'].GetBoundingBox(True);existing=[]
 for o in objects():
  key=str(o.Id)
  if key not in d['before']or key in TOPS+BASES or o.IsHidden:continue
  g=o.Geometry
  if not isinstance(g,(G.Brep,G.Mesh,G.SubD,G.Extrusion)):continue
  bb=g.GetBoundingBox(True)
  if any([bb.Max.X<bounds.Min.X-15,bb.Min.X>bounds.Max.X+15,bb.Max.Y<bounds.Min.Y-15,bb.Min.Y>bounds.Max.Y+15,bb.Max.Z<58.,bb.Min.Z>72.]):continue
  if isinstance(g,G.Mesh):m=g
  elif isinstance(g,G.SubD):m=G.Mesh.CreateFromSubD(g,2)
  else:
   ms=list(o.GetMeshes(G.MeshType.Render)or[])
   m=G.Mesh()
   for a in ms:m.Append(a)
   if not ms:m=mesh(g.ToBrep()if isinstance(g,G.Extrusion)else g,3.)
  existing.append((key,m))
 for j in range(401):
  s=L*j/400.
  for y in [-9.5,-5.,0.,5.,9.5]:
   p=point(s,y);origin=p+G.Vector3d(0,0,.02)
   down=G.Intersect.Intersection.MeshRay(d['deck_mesh'],G.Ray3d(origin,-G.Vector3d.ZAxis))
   support.append([s,y,down-.02 if down>=0 else None])
   ray=G.Ray3d(p+G.Vector3d(0,0,.15),G.Vector3d.ZAxis)
   for k,b,m in d['new_meshes']:
    up=G.Intersect.Intersection.MeshRay(m,ray)
    if 0<=up<5.85:newhits.append([s,y,k,up+.15])
   for k,m in existing:
    up=G.Intersect.Intersection.MeshRay(m,ray)
    if 0<=up<5.85:existinghits.append([s,y,k,up+.15])
   q=G.Point3d(p.X,p.Y,120.);t=G.Intersect.Intersection.MeshRay(d['roof_mesh'],G.Ray3d(q,-G.Vector3d.ZAxis))
   if t>=0:terrain.append([s,y,p.Z-(120.-t)])
 for i,v in d['towers'].items():
  for row in v['stay_rows']:
   a=G.Point3d(*row['deck_anchor'])
   anchors.append(d['parts']['deck_body'].IsPointInside(a,.005,False))
 grades=[abs((height(L*(j+1)/1000.)-height(L*j/1000.))/(L/1000.))for j in range(1000)]
 report={'road_samples':len(support),'support_missing':sum(row[2]is None for row in support),
 'support_gap_m':[min(row[2]for row in support if row[2]is not None),max(row[2]for row in support if row[2]is not None)],
 'new_intrusions':newhits,'existing_intrusions':existinghits,'existing_tested_objects':len(existing),
 'large_island_samples':len(terrain),'min_road_above_large_island_m':min(row[2]for row in terrain),
 'max_road_grade_percent':100*max(grades),'cable_deck_anchors_inside':sum(anchors),'cable_deck_anchors_total':len(anchors)}
 d['traffic_check']=report
 return report

def verify():
 d=sc.sticky[TAG];report={'traffic':d['traffic_check'],'ids':d['ids'],'baseline_count':len(d['before'])}
 unchanged=[];attrs_changed=[];missing=[]
 opts=Rhino.FileIO.SerializationOptions()
 for k,crc in d['before'].items():
  if k in TOPS+BASES:continue
  o=obj(k)
  if not o:missing.append(k);continue
  if int(o.Geometry.DataCRC(0))!=crc:unchanged.append(k)
  if o.Attributes.ToJSON(opts)!=d['before_attrs'][k]:attrs_changed.append(k)
 report.update({'unexpected_geometry_changes':unchanged,'unexpected_attribute_changes':attrs_changed,'missing_originals':missing})
 assert not unchanged and not attrs_changed and not missing,report
 geometry=[]
 for role,k in d['ids'].items():
  o=obj(k);g=o.Geometry
  staged=d['parts'][role]if role in d['parts']else None
  if role.startswith('island_'):
   tokens=role.split('_');staged=d['islands'][int(tokens[1])][tokens[2]]
  if role.startswith('tower_'):staged=d['towers'][int(role.split('_')[1])]['body']
  if role.startswith('stays_'):staged=d['towers'][int(role.split('_')[1])]['stays']
  assert G.GeometryBase.GeometryEquals(g,staged),role
  closed=g.IsClosed if isinstance(g,G.Mesh)else g.IsSolid
  assert g.IsValid and closed and not o.IsHidden,role
  geometry.append({'role':role,'id':k,'valid':g.IsValid,'closed':closed,'type':g.GetType().Name,'faces':g.Faces.Count})
 contacts=[]
 for i,v in enumerate(d['islands']):
  tops=[];feet=[]
  for j in range(8):
   u=(j+.18)/8.;r=edge(i,u)-v['center'];p=v['center']+r*.78;p.Z=roof_z(i,u)-1.8
   tops.append(v['roof'].IsPointInside(p,.01,False))
   p=v['center']+r*.77;p.Z=2.8;feet.append(v['base'].IsPointInside(p,.01,False))
  for ds in [-20.,20.]:
   for sign in [-1,1]:
    p=point(v['station']+ds,sign*12.1,-.55);tops.append(d['parts']['deck_body'].IsPointInside(p,.01,False))
    nearest=min(range(120),key=lambda j:edge(i,j/120.).DistanceTo(G.Point3d(p.X,p.Y,0)))
    p=v['center']+(edge(i,nearest/120.)-v['center'])*.79;p.Z=2.8;feet.append(v['base'].IsPointInside(p,.01,False))
  assert all(tops)and all(feet),(i,tops,feet)
  # Test just the shell/base; the bridge intentionally crosses the open courtyard above.
  ray=G.Ray3d(v['center']+G.Vector3d(0,0,80),-G.Vector3d.ZAxis)
  ringmeshes=[m for role,b,m in d['new_meshes']if role in ['island_%d_roof'%i,'island_%d_base'%i]]
  open_court=all(G.Intersect.Intersection.MeshRay(m,ray)<0 for m in ringmeshes)
  assert open_court,i
  contacts.append({'island':i+1,'column_top_contacts':sum(tops),'column_base_contacts':sum(feet),'courtyard_open':open_court})
 roots=[]
 for i,v in d['towers'].items():
  samples=[];rail=v['rail']
  for j in range(1000):
   p=rail.PointAt(rail.Domain.ParameterAt(j/1000.))
   if 0<p.Z<5.:
    p.Z=2.8;samples.append(d['islands'][i]['base'].IsPointInside(p,.01,False))
  assert samples and all(samples),i
  roots.append({'island':i+1,'root_center_samples':len(samples),'on_foundation':sum(samples)})
 # Actual paving surface is tested at both ends, across the usable road width.
 seams=[];paving=mesh(d['parts']['deck_paving'],2.)
 for s in [0.,d['length']]:
  for y in [-10.,-5.,0.,5.,10.]:
   p=point(s,y);q=paving.ClosestMeshPoint(p,1.);assert q
   seams.append(p.DistanceTo(q.Point))
 assert max(seams)<.01,seams
 traffic=d['traffic_check']
 assert not traffic['new_intrusions']and not traffic['existing_intrusions']and not traffic['support_missing']
 assert traffic['cable_deck_anchors_inside']==traffic['cable_deck_anchors_total']
 assert traffic['min_road_above_large_island_m']>.44
 report.update({'geometry':geometry,'island_contacts':contacts,'tower_foundations':roots,'max_paving_endpoint_deviation_m':max(seams),
 'live_objects':len(objects()),'active_layers':sum(not l.IsDeleted for l in sc.doc.Layers),'large_island_geometry_unchanged':int(obj(ROOF).Geometry.DataCRC(0))==d['before'][ROOF],
 'stays':[{'island':i+1,'cables':len(v['stay_rows']),'clearance_margin_m':.25}for i,v in d['towers'].items()],
 'scope':'Rhino valid/closed bodies, sampled 20m-wide road clearance to 6m, cable line clearance with radius margin, support contact samples. Not structural certification, exhaustive self-intersection or game collision validation.'})
 d['verification']=report;write('validation.json',report)
 return {k:report[k]for k in ['live_objects','active_layers','max_paving_endpoint_deviation_m','unexpected_geometry_changes','unexpected_attribute_changes','large_island_geometry_unchanged']}

def save_current():
 d=sc.sticky[TAG];assert 'verification'in d
 path=sc.doc.Path;assert path.replace('\\','/').lower()=='d:/prism route/map/map_current.3dm'
 assert Rhino.RhinoApp.RunScript('_Save',False)
 saved=Rhino.FileIO.File3dm.Read(path);assert saved
 disk={str(o.Id):int(o.Geometry.DataCRC(0))for o in saved.Objects}
 live={str(o.Id):int(o.Geometry.DataCRC(0))for o in objects()}
 assert disk==live,{'disk':len(disk),'live':len(live)}
 d['verification']['saved_file']={'path':path,'objects':len(disk),'all_object_ids_and_geometry_crc_match':True}
 write('validation.json',d['verification'])
 return d['verification']['saved_file']
