# -*- coding: utf-8 -*-
"""Local pavement clearance and the existing ring road's return tunnel.

Live Rhino stages: prepare_roads(), build_tunnel(), cut_wall(), publish().
Keep source object IDs. No duplicate CAD files or scene versions.
"""
from __future__ import unicode_literals,division
import Rhino,scriptcontext as sc,System,math,bisect
G=Rhino.Geometry
TAG='platform_roads_1020'
MAIN='47800a9c-ca72-4dc5-8203-d6d5d91d29a9'
UPPER='ee277b2d-e4eb-4d39-80e6-c5d8a5d87d70'
WALL='02590c34-07df-47ad-b3fa-e18bd74c8b3f'
FLOOR='9178570a-b44f-4316-917c-0ce86332f3dd'
BASE='bbea2185-f5e3-4821-a363-63f19f463bc4'
UPPER_GROUND='a2a15e34-a9db-4e6a-a4ce-be472804bd15'

def obj(key):return sc.doc.Objects.FindId(System.Guid(key))
def objects():
 e=Rhino.DocObjects.ObjectEnumeratorSettings();e.NormalObjects=True;e.HiddenObjects=True;e.LockedObjects=True
 return list(sc.doc.Objects.GetObjectList(e))
def smooth(t):
 t=max(0,min(1,t));return t*t*t*(10+t*(-15+6*t))
def mesh(g):
 m=G.Mesh()
 for q in G.Mesh.CreateFromBrep(g,G.MeshingParameters.FastRenderMesh):m.Append(q)
 return m
def elevation(m,p):
 h=G.Intersect.Intersection.MeshRay(m,G.Ray3d(G.Point3d(p.X,p.Y,100),-G.Vector3d.ZAxis))
 return None if h<0 else 100-h

def raised(geometry,face_index,meshes,start):
 f=geometry.Faces[face_index];c=f.IsoCurve(1,f.Domain(0).Mid);length=c.GetLength()
 count=int(math.ceil((length-start)/5));stations=[start+(length-start)*i/count for i in range(count+1)]
 needed=[]
 for s in stations:
  if s>=length-1e-6:t=c.Domain.T1
  else:
   ok,t=c.LengthParameter(s);assert ok
  require=0
  for j in range(7):
   p=f.PointAt(f.Domain(0).ParameterAt(j/6),t)
   hs=[elevation(m,p)for m in meshes];hs=[z for z in hs if z is not None and abs(z-p.Z)<4]
   if hs:require=max(require,max(hs)+.20-p.Z)
  needed.append(max(0,require))
 # A conservative smooth envelope: prevent the longitudinal correction from
 # tracking every tessellation fluctuation, while retaining positive cover.
 dilated=[max(needed[max(0,i-4):min(len(needed),i+5)])for i in range(len(needed))]
 amounts=[sum(dilated[max(0,i-2):min(len(needed),i+3)])/len(dilated[max(0,i-2):min(len(needed),i+3)])for i in range(len(needed))]
 def delta(s):
  if s<start:return 0
  i=max(0,min(len(stations)-2,bisect.bisect_right(stations,s)-1))
  f=(s-stations[i])/(stations[i+1]-stations[i]);f=max(0,min(1,f))
  return (amounts[i]*(1-f)+amounts[i+1]*f)*smooth((s-start)/35)
 surface=f.ToNurbsSurface()
 for j in range(surface.Points.CountV):
  p=surface.Points.GetControlPoint(surface.Points.CountU//2,j).Location
  ok,t=c.ClosestPoint(p);assert ok;s=c.GetLength(G.Interval(c.Domain.T0,t));dz=delta(s)
  for i in range(surface.Points.CountU):
   cp=surface.Points.GetControlPoint(i,j);p=cp.Location;p.Z+=dz
   assert surface.Points.SetPoint(i,j,p,cp.Weight)
 changed=G.Brep.CopyTrimCurves(f,surface,.005);assert changed and changed.IsValid
 result=G.Brep()
 for face in geometry.Faces:result.Append(changed if face.FaceIndex==face_index else face.DuplicateFace(False))
 assert result.IsValid
 return result,{'start_station':start,'maximum_control_raise_m':max(amounts),'length':length}

def prepare_roads():
 d=sc.sticky.get(TAG,{})
 if 'before'not in d:d['before']={str(o.Id):int(o.Geometry.DataCRC(0))for o in objects()}
 d['source']={key:obj(key).Geometry.DuplicateBrep()for key in [MAIN,UPPER,WALL]}
 d['ground']={key:mesh(obj(key).Geometry)for key in [FLOOR,BASE,UPPER_GROUND]}
 copies={};report={}
 copies[MAIN],report['main']=raised(d['source'][MAIN],0,[d['ground'][FLOOR],d['ground'][BASE]],1000.)
 copies[UPPER],report['upper']=raised(d['source'][UPPER],0,[d['ground'][UPPER_GROUND]],710.)
 d['copies']=copies;d['road_report']=report
 d['face']=copies[MAIN].Faces[0];d['route']=d['face'].IsoCurve(1,d['face'].Domain(0).Mid)
 sc.sticky[TAG]=d
 return report

def frame(s):
 d=sc.sticky[TAG];f=d['face'];c=d['route'];L=c.GetLength()
 if s>=L-1e-6:t=c.Domain.T1
 elif s<=0:t=c.Domain.T0
 else:
  ok,t=c.LengthParameter(s);assert ok
 p=c.PointAt(t);a=c.TangentAt(t);ds=s-max(0,min(L,s))
 if ds:p+=a*ds
 left=f.PointAt(f.Domain(0).T0,t);right=f.PointAt(f.Domain(0).T1,t)
 n=right-left;n.Z=0;span=n.Length;n.Unitize()
 return p,n,span*.5,(right.Z-left.Z)/span
def point(s,y,z):
 p,n,w,roll=frame(s);p+=n*y;p.Z=z+roll*y;return p
def loft(sections):
 pieces=G.Brep.CreateFromLoft(sections,G.Point3d.Unset,G.Point3d.Unset,G.LoftType.Normal,False)
 assert pieces and len(pieces)==1
 b=pieces[0].CapPlanarHoles(.005);assert b and b.IsValid and b.IsSolid
 if b.SolidOrientation==G.BrepSolidOrientation.Inward:b.Flip()
 return b

def build_tunnel():
 d=sc.sticky[TAG];lo=1828.;hi=d['route'].GetLength()+8;sections=[];cut=[]
 for i in range(79):
  s=lo+(hi-lo)*i/78;p,n,w,roll=frame(s)
  flare=1-smooth(min(s-lo,hi-s)/14)
  half=w+4+1.5*flare;height=10.5+.5*flare
  inner=[(-half*math.cos(math.pi*j/24),-1.0+(height+1)*math.sin(math.pi*j/24)**.65)for j in range(25)]
  outer=[(-(half+.95)*math.cos(math.pi*j/24),-1.0+(height+2)*math.sin(math.pi*j/24)**.65)for j in range(25)]
  yz=inner+list(reversed(outer));sections.append(G.NurbsCurve.Create(True,3,[point(s,y,p.Z+z)for y,z in yz]))
  # A slightly larger void cuts the old wall, with the lining rim covering
  # the join. Extended caps ensure the original end wall is fully crossed.
  ss=s if i not in [0,78] else (lo-12 if i==0 else hi+15)
  pp,nn,ww,rr=frame(ss);hh=ww+4.4+1.5*flare
  yz=[(-hh*math.cos(math.pi*j/24),-1.25+(height+1.65)*math.sin(math.pi*j/24)**.65)for j in range(25)]
  yz +=[(hh,-3),(0,-3),(-hh,-3)]
  cut.append(G.NurbsCurve.Create(True,3,[point(ss,y,pp.Z+z)for y,z in yz]))
 d['lining']=loft(sections);d['cutter']=loft(cut);d['range']=[lo,hi]
 return {'length_m':hi-lo,'lining_faces':d['lining'].Faces.Count,'closed':True}

def cut_wall():
 d=sc.sticky[TAG];parts=d['source'][WALL].Split(d['cutter'],.015)
 assert parts and len(parts)>1,'Wall opening did not split'
 kept=[];removed=[]
 for part in parts:
  center=G.AreaMassProperties.Compute(part).Centroid
  (removed if d['cutter'].IsPointInside(center,.03,False)else kept).append(part)
 assert removed and kept
 result=G.Brep()
 for part in kept:result.Append(part)
 assert result.IsValid;d['copies'][WALL]=result
 return {'split_parts':len(parts),'removed':len(removed),'retained_faces':result.Faces.Count}

def publish():
 d=sc.sticky[TAG];undo=sc.doc.BeginUndoRecord('平台道路贴地修正与环路回程隧道')
 try:
  for key,g in d['copies'].items():assert sc.doc.Objects.Replace(System.Guid(key),g)
  old=next((o for o in objects()if o.Attributes.GetUserString('recipe')==TAG),None)
  if old:assert sc.doc.Objects.Replace(old.Id,d['lining']);oid=old.Id
  else:
   a=Rhino.DocObjects.ObjectAttributes();a.Name='平台回程隧道_沿现有环路连续内壁与洞口'
   a.LayerIndex=sc.doc.Layers.FindByFullPath('交通::隧道',-1)
   a.MaterialIndex=next(i for i,m in enumerate(sc.doc.Materials)if m.Name=='隧道_暖白建筑复合面_PBR_非金属')
   a.MaterialSource=Rhino.DocObjects.ObjectMaterialSource.MaterialFromObject;a.WireDensity=-1;a.SetUserString('recipe',TAG)
   oid=sc.doc.Objects.AddBrep(d['lining'],a);assert oid!=System.Guid.Empty
  d['lining_id']=str(oid)
 finally:sc.doc.EndUndoRecord(undo)
 sc.doc.Objects.UnselectAll();sc.doc.Views.Redraw()
 return {'updated':list(d['copies']),'lining_id':d['lining_id']}
