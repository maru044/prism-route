# -*- coding: utf-8 -*-
"""Ground the existing rising branch: one embankment + one three-pier SubD.

Run prepare(), build(), publish(), verify() as separate connected Rhino calls. Actual road geometry
is read only. No scene copies, CAD copies, or version layers are created.
"""
from __future__ import unicode_literals,division
import Rhino,scriptcontext as sc,System,math
G=Rhino.Geometry
TAG='branch_road_embankment_viaduct_1019'
ROAD='59dd95cc-d6f3-4378-ae67-d76fcbdf6ac8'
PIERS=[565.,675.,790.]

def obj(key):return sc.doc.Objects.FindId(System.Guid(key))
def smooth(t):
 t=max(0.,min(1.,t));return t*t*t*(10+t*(-15+6*t))

def frame(s):
 d=sc.sticky[TAG];c=d['route'];ok,t=c.LengthParameter(s);assert ok
 f=d['face'];p=c.PointAt(t)
 left=f.PointAt(f.Domain(0).T0,t);right=f.PointAt(f.Domain(0).T1,t)
 n=right-left;n.Z=0;span=n.Length;assert n.Unitize()
 a=G.Vector3d(-n.Y,n.X,0)
 if G.Vector3d.Multiply(a,c.TangentAt(t))<0:a=-a
 return p,a,n,span*.5,(right.Z-left.Z)/span

def point(s,y,z=None):
 p,a,n,w,roll=frame(s);p+=n*y
 p.Z=(p.Z+roll*y) if z is None else z
 return p

def ground(s,y=0):
 d=sc.sticky[TAG];p=point(s,y);p.Z+=1
 t=G.Intersect.Intersection.MeshRay(d['ground'],G.Ray3d(p,-G.Vector3d.ZAxis))
 if t<0:raise ValueError('Missing ground at station '+str(s))
 return p.Z-t

def perimeter(i0,i1,j0,j1):
 return ([(i,j0)for i in range(i0,i1)]+[(i1,j)for j in range(j0,j1)]
  +[(i,j1)for i in range(i1,i0,-1)]+[(i0,j)for j in range(j1,j0,-1)])

def prepare():
 road=obj(ROAD);assert road and isinstance(road.Geometry,G.Brep)
 d=sc.sticky.get(TAG,{})
 d['face']=road.Geometry.Faces[0];d['route']=d['face'].IsoCurve(1,d['face'].Domain(0).Mid)
 d['before']={str(o.Id):int(o.Geometry.DataCRC(0))for o in objects()
  if not o.Attributes.GetUserString('branch_road_role')}
 region=road.Geometry.GetBoundingBox(True);region.Inflate(45);m=G.Mesh();count=0
 for o in objects():
  l=sc.doc.Layers[o.Attributes.LayerIndex]
  if o.IsHidden or not l.IsVisible or not l.FullPath.startswith('地形::'):continue
  b=o.Geometry.GetBoundingBox(True)
  if b.Max.X<region.Min.X or b.Min.X>region.Max.X or b.Max.Y<region.Min.Y or b.Min.Y>region.Max.Y:continue
  g=o.Geometry
  if isinstance(g,G.Brep):
   for part in G.Mesh.CreateFromBrep(g,G.MeshingParameters.FastRenderMesh):m.Append(part)
  elif isinstance(g,G.Mesh):m.Append(g)
  elif isinstance(g,G.SubD):m.Append(G.Mesh.CreateFromSubD(g,1))
  else:continue
  count+=1
 d['ground']=m;sc.sticky[TAG]=d
 return {'ground_objects':count,'ground_mesh_faces':int(m.Faces.Count)}

def build():
 d=sc.sticky[TAG]
 road=obj(ROAD);assert road and isinstance(road.Geometry,G.Brep)
 d['face']=road.Geometry.Faces[0];d['route']=d['face'].IsoCurve(1,d['face'].Domain(0).Mid)
 # Lofted closed sections produce the rounded solid starting road base.
 sections=[]
 for i in range(97):
  s=280+(520-280)*i/96;p,a,n,w,roll=frame(s)
  shoulder=w+.65;g=ground(s)
  detach=smooth((s-424)/96)
  bottom=(g-.8)*(1-detach)+(p.Z-1.2)*detach
  foot=shoulder+10*(1-detach)
  top=p.Z-.18
  yz=[(-shoulder,top),(-shoulder*.65,top),(0,top),(shoulder*.65,top),(shoulder,top),
      (shoulder+1.8*(1-detach),top-.3),
      (foot,bottom+.45),(foot,bottom),(foot*.5,bottom),(0,bottom),
      (-foot*.5,bottom),(-foot,bottom),(-foot,bottom+.45),
      (-shoulder-1.8*(1-detach),top-.3)]
  # Crossfall follows the original road; all section points remain coplanar.
  sections.append(G.NurbsCurve.Create(True,3,[point(s,y,z+roll*y)for y,z in yz]))
 loft=G.Brep.CreateFromLoft(sections,G.Point3d.Unset,G.Point3d.Unset,G.LoftType.Normal,False)
 assert loft and len(loft)==1
 base=loft[0].CapPlanarHoles(.005);assert base and base.IsValid and base.IsSolid
 if base.SolidOrientation==G.BrepSolidOrientation.Inward:base.Flip()
 d['base']=base
 # Shared-topology bridge belly and three flared piers, rather than pillars
 # intersecting a slab. Small end rows bury the closing caps in the hosts.
 lo,hi=430.,876.
 stations=sorted(set([lo,lo+.25,lo+.7,hi-.7,hi-.25,hi]+
  [lo+(hi-lo)*i/180 for i in range(1,180)]))
 nx=len(stations)-1
 cross=[-1,-.985,-.94,-.84,-.7,-.4,0,.4,.7,.84,.94,.985,1]
 ny=len(cross)-1;roots=[]
 for s,half in zip(PIERS,[38.,43.,47.]):
  i0=min(range(nx+1),key=lambda i:abs(stations[i]-(s-half)))
  i1=min(range(nx+1),key=lambda i:abs(stations[i]-(s+half)))
  roots.append((i0,i1,3,ny-3,s))
 m=G.Mesh();top={};bottom={};tp={};bp={}
 for i,s in enumerate(stations):
  p,a,n,w,roll=frame(s);width=w+1.45
  weight=max(math.exp(-((s-r)/42)**2)for r in PIERS)
  for j,f in enumerate(cross):
   y=width*f;edge=smooth((abs(f)-.94)/.06)
   z=p.Z+roll*y-.08-.22*edge
   t=point(s,y,z);b=point(s,y,z-(1.05+.65*(1-f*f)+1.05*weight*(1-f*f)))
   tp[i,j]=t;bp[i,j]=b
   top[i,j]=m.Vertices.Add(t);bottom[i,j]=m.Vertices.Add(b)
 for i in range(nx):
  for j in range(ny):
   m.Faces.AddFace(top[i,j],top[i+1,j],top[i+1,j+1],top[i,j+1])
   if not any(i0<=i<i1 and j0<=j<j1 for i0,i1,j0,j1,s in roots):
    m.Faces.AddFace(bottom[i,j+1],bottom[i+1,j+1],bottom[i+1,j],bottom[i,j])
 rim=perimeter(0,nx,0,ny);last=[top[k]for k in rim]
 for f in [.22,.58,.84,1.]:
  ring=[]
  for i,j in rim:
   a=tp[i,j];b=bp[i,j];p=G.Point3d(a.X,a.Y,a.Z+(b.Z-a.Z)*f)
   ring.append(bottom[i,j]if f==1 else m.Vertices.Add(p))
  for k in range(len(last)):
   q=(k+1)%len(last);m.Faces.AddFace(last[k],ring[k],ring[q],last[q])
  last=ring
 feet=[]
 for i0,i1,j0,j1,s in roots:
  boundary=perimeter(i0,i1,j0,j1);ring0=[bp[k]for k in boundary]
  p,a,n,w,roll=frame(s);center=point(s,0,sum(v.Z for v in ring0)/len(ring0))
  rx=max(abs(G.Vector3d.Multiply(v-center,a))for v in ring0)
  ry=max(abs(G.Vector3d.Multiply(v-center,n))for v in ring0)
  foot_z=min(ground(s-6),ground(s),ground(s+6))-.8
  last=[bottom[k]for k in boundary]
  for t,scale in [(.025,.84),(.07,.68),(.14,.50),(.26,.34),(.43,.22),(.64,.135),(.82,.11),(.94,.12),(1,.17)]:
   ring=[];rounding=smooth((t-.07)/.53)
   for v in ring0:
    delta=v-center;x=G.Vector3d.Multiply(delta,a);y=G.Vector3d.Multiply(delta,n)
    angle=math.atan2(y/ry,x/rx)
    x=x*(1-rounding)+rx*math.cos(angle)*rounding
    y=y*(1-rounding)+ry*math.sin(angle)*rounding
    q=center+a*(x*scale+2.0*smooth(t))+n*(y*scale*(1+.35*rounding))
    q.Z=v.Z+(foot_z-v.Z)*t;ring.append(m.Vertices.Add(q))
   for k in range(len(last)):
    q=(k+1)%len(last);m.Faces.AddFace(last[q],ring[q],ring[k],last[k])
   last=ring
  cap=m.Vertices.Add(point(s+2,0,foot_z))
  for k in range(len(last)):m.Faces.AddFace(last[(k+1)%len(last)],cap,last[k])
  feet.append({'station':s,'buried_z':foot_z,'deck_z':p.Z})
 m.Vertices.CullUnused();m.UnifyNormals();m.Normals.ComputeNormals();m.Compact()
 if m.SolidOrientation()<0:m.Flip(True,True,True)
 assert m.IsValid and m.IsClosed and m.IsManifold()
 sub=G.SubD.CreateFromMesh(m,G.SubDCreationOptions.Smooth)
 assert sub and sub.IsValid and sub.IsSolid
 limit=G.Mesh.CreateFromSubD(sub,2)
 assert limit.IsValid and limit.IsClosed and len(limit.SplitDisjointPieces())==1
 d.update(body=sub,limit=limit,control=m,feet=feet)
 return {'base_solid':True,'bridge_solid':True,'bridge_connected':True,'piers':feet,'control_faces':int(m.Faces.Count)}

def publish():
 d=sc.sticky[TAG];layer=sc.doc.Layers.FindByFullPath('交通::中层道路',-1);assert layer>=0
 mi=next(i for i,m in enumerate(sc.doc.Materials)if m.Name=='隧道_暖白建筑复合面_PBR_非金属')
 d.setdefault('ids',{})
 undo=sc.doc.BeginUndoRecord('分支道路_渐起路基与三墩连续高架')
 try:
  for role,name in [('base','分支道路_渐起实心路基'),('body','分支道路_三墩连续曲面桥腹')]:
   old=next((o for o in objects()if o.Attributes.GetUserString('branch_road_role')==role),None)
   if old:
    assert sc.doc.Objects.Replace(old.Id,d[role]);oid=old.Id
   else:
    attr=Rhino.DocObjects.ObjectAttributes();attr.Name=name;attr.LayerIndex=layer
    attr.MaterialIndex=mi;attr.MaterialSource=Rhino.DocObjects.ObjectMaterialSource.MaterialFromObject
    attr.SetUserString('recipe',TAG);attr.SetUserString('branch_road_role',role)
    attr.SetUserString('source_road',ROAD);attr.WireDensity=-1
    oid=sc.doc.Objects.AddSubD(d[role],attr)if role=='body'else sc.doc.Objects.AddBrep(d[role],attr)
    assert oid!=System.Guid.Empty
   d['ids'][role]=str(oid)
 finally:sc.doc.EndUndoRecord(undo)
 sc.doc.Views.Redraw()
 return d['ids']

def objects():
 e=Rhino.DocObjects.ObjectEnumeratorSettings();e.HiddenObjects=True;e.LockedObjects=True;e.NormalObjects=True
 return list(sc.doc.Objects.GetObjectList(e))

def verify():
 d=sc.sticky[TAG];before=d['before']
 assert all(int(obj(key).Geometry.DataCRC(0))==crc for key,crc in before.items())
 m=G.Mesh();m.Append(d['limit'])
 for q in G.Mesh.CreateFromBrep(d['base'],G.MeshingParameters.FastRenderMesh):m.Append(q)
 collision=0;gaps=[];upper_hits=0
 for i in range(121):
  s=282+(865-282)*i/120;p,a,n,w,roll=frame(s)
  for y in [-w*.85,0,w*.85]:
   q=point(s,y);q.Z+=.15
   hit=G.Intersect.Intersection.MeshRay(m,G.Ray3d(q,-G.Vector3d.ZAxis))
   if hit>=0:
    gap=hit-.15;gaps.append(gap)
    if gap<-.03:collision+=1
   upper=G.Intersect.Intersection.MeshLine(m,G.Line(q+G.Vector3d(0,0,-.125),q+G.Vector3d(0,0,2.85)))
   if upper is not None and len(upper)>0:upper_hits+=1
 for f in d['feet']:
  s=f['station'];assert f['buried_z']<ground(s)
  assert d['limit'].IsPointInside(point(s,0,ground(s)),.005,False)
 return {'original_geometry_unchanged':True,'road_samples':len(gaps),'intrusion_samples':collision,
  'above_road_intrusions':upper_hits,'all_feet_grounded':True,
  'support_gap_min':min(gaps),'support_gap_max':max(gaps),'piers':3}
