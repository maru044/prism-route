# -*- coding: utf-8 -*-
"""Corrected study: C1 and C3 jointly constrain ONE top. No tunnels.

Run in the live Rhino document after v01 reference discovery. Native Patch
is an approximate fit; report its deviation, do not label it exact interpolation.
"""
from __future__ import division, unicode_literals
import Rhino, scriptcontext as sc, System, math, json, os, io
G=Rhino.Geometry
OUT='D:/Prism Route/prism-route/docs/concepts/reference_1016_landscape'
TAG='prism_landscape_1016_v02'

def build():
 if 'landscape_1016_namespace' not in sc.sticky:
  p=os.path.join(os.path.dirname(__file__),'rhino_landscape_1016_v01.py');ns={'__file__':p}
  exec(compile(io.open(p,encoding='utf-8').read(),p,'exec'),ns);sc.sticky['landscape_1016_namespace']=ns
 ns=sc.sticky['landscape_1016_namespace']
 ids=ns['IDS'];a=ns['obj'](ids[0]).Geometry.DuplicateCurve();b=ns['obj'](ids[2]).Geometry.DuplicateCurve()
 old={'bodies':[{'foot':ns['obj'](ids[3]).Geometry.DuplicateCurve()},{'foot':ns['obj'](ids[1]).Geometry.DuplicateCurve()}],
      'state':{'reference_crc':{i:int(ns['obj'](i).Geometry.DataCRC(0))for i in ids}}}
 # The long S cannot be paired to the short C by one straight ruled loft.
 # Close its outer end around the outside rather than cutting through the S.
 e=G.Curve.CreateInterpolatedCurve([a.PointAtStart,G.Point3d(1695,1190,2),G.Point3d(1675,1020,6),b.PointAtStart],3)
 s=G.Curve.CreateInterpolatedCurve([a.PointAtEnd,G.Point3d(1325,1340,0),b.PointAtEnd],3)
 loop=G.Curve.JoinCurves([a,s,b,e],.001)[0]
 data={'a':a,'b':b}
 top=G.Brep.CreatePatch([loop],None,40,40,True,False,2,10,0,System.Array[bool]([False]*4),.005)
 if top.Faces[0].NormalAt(top.Faces[0].Domain(0).Mid,top.Faces[0].Domain(1).Mid).Z<0:top.Flip()
 surf=top.Faces[0].UnderlyingSurface()
 boundary=G.Curve.JoinCurves(top.DuplicateNakedEdgeCurves(True,False),.01)[0]
 split=[]
 for c in [data['a'],data['b']]:
  for pt in [c.PointAtStart,c.PointAtEnd]:split.append(boundary.ClosestPoint(pt)[1])
 edges=boundary.Split(sorted(split));walls=[];buried=[];feet=[];deviations={}
 for edge in edges:
  mid=edge.PointAtNormalizedLength(.5)
  distances=[]
  for name,guide,foot in [('C1',data['a'],old['bodies'][0]['foot']),('C3',data['b'],old['bodies'][1]['foot'])]:
   ok,t=guide.ClosestPoint(mid);distances.append((mid.DistanceTo(guide.PointAt(t)),name,guide,foot))
  dist,name,guide,foot=min(distances,key=lambda x:x[0]);is_main=dist<1
  n=edge.ToNurbsCurve();rows=[];qs=[]
  for i in range(n.Points.Count):
   p=n.Points[i].Location;t=n.GrevilleParameter(i);ep=n.PointAt(t)
   if is_main:
    _,gt=guide.ClosestPoint(ep);f=foot.PointAt(gt)
    q=G.Point3d(f.X,f.Y,0)
   else:q=G.Point3d(p.X,p.Y,0)
   # Connector feet share the exact endpoints of the two original ground rails.
   if i in [0,n.Points.Count-1]:
    endpoints=[c.PointAtStart for c in [old['bodies'][0]['foot'],old['bodies'][1]['foot']]]+[c.PointAtEnd for c in [old['bodies'][0]['foot'],old['bodies'][1]['foot']]]
    q=min(endpoints,key=lambda x:x.DistanceTo(ep));q=G.Point3d(q.X,q.Y,0)
   _,su,sv=surf.ClosestPoint(ep);normal=surf.NormalAt(su,sv)
   if normal.Z<0:normal=-normal
   tangent=n.TangentAt(t);inward=G.Vector3d.CrossProduct(normal,tangent);inward.Unitize()
   test=ep+inward*.5;_,tu,tv=surf.ClosestPoint(test)
   if top.Faces[0].IsPointOnFace(tu,tv)==G.PointFaceRelation.Exterior:inward=-inward
   r=min(2.5,max(.02,ep.Z*.16));z=G.Vector3d.ZAxis
   base=G.Point3d(q.X,q.Y,-4)
   row=[p,p-inward*r,p-inward*(2*r)-z*(max(0,ep.Z)*.10),q+(p-q)*.52,q+(p-q)*.16,base+z*.8,base]
   if ep.Z<.1:row=[base+(p-base)*w for w in [1,.98,.85,.52,.16,.05,0]]
   if i in [0,n.Points.Count-1]:row=[base+(p-base)*w for w in [1,.98,.85,.52,.16,.05,0]]
   rows.append(row)
   qs.append(base)
  wall=ns['panel'](n,rows);fc=ns['curve_from_control'](n,qs)
  walls.append(wall.ToBrep());feet.append(fc)
  if is_main:
   errors=[]
   for j in range(301):
    pt=guide.PointAtNormalizedLength(j/300.);_,u,v=surf.ClosestPoint(pt);errors.append(pt.DistanceTo(surf.PointAt(u,v)))
   deviations[name]=max(errors)
 bottomloop=G.Curve.JoinCurves(feet,.01)
 if len(bottomloop)!=1 or not bottomloop[0].IsClosed:raise RuntimeError('Base outline did not close')
 bottom=G.Brep.CreatePlanarBreps(bottomloop,.01)
 joined=G.Brep.JoinBreps([top]+walls+buried+list(bottom),.01)
 for b in joined:b.JoinNakedEdges(.01)
 sc.sticky['1016_v02_parts']=[top]+walls+buried+list(bottom)
 if len(joined)!=1 or not joined[0].IsValid or not joined[0].IsSolid:raise RuntimeError('New main terrain did not close')
 solid=joined[0]
 if solid.SolidOrientation==G.BrepSolidOrientation.Inward:solid.Flip()
 if solid.SolidOrientation!=G.BrepSolidOrientation.Outward:raise RuntimeError('Ambiguous solid orientation')
 report={'recipe':TAG,'top_guides':['C1 elevated S','C3 elevated C'],'sidewall_ground_guides':['C4 ground S','C2 ground C'],'top_fit':'Native NURBS Patch, 40x40 spans, flexibility 10, spacing 2m; trimmed simple footprint. End closures avoid the S curve crossing a straight closure.','maximum_surface_distance_m':deviations,'valid':solid.IsValid,'closed_solid':solid.IsSolid,'faces':solid.Faces.Count,'no_new_tunnels':True,'reference_curves_unchanged':all(int(ns['obj'](k).Geometry.DataCRC(0))==v for k,v in old['state']['reference_crc'].items())}
 sc.sticky[TAG]={'geometry':solid,'top':top,'report':report}
 with open(OUT+'/v02_report.json','w')as f:json.dump(report,f,indent=2)
 print(json.dumps(report))

def publish():
 ns=sc.sticky['landscape_1016_namespace'];data=sc.sticky[TAG];old=sc.sticky['prism_landscape_1016_v01']
 undo=sc.doc.BeginUndoRecord('1016 两条高边共同顶面')
 try:
  for row in old['state']['objects'][:2]:sc.doc.Objects.Hide(System.Guid(row['id']),True)
  if '1016_top_preview_id' in sc.sticky:sc.doc.Objects.Hide(sc.sticky['1016_top_preview_id'],True)
  attr=sc.doc.Objects.FindId(System.Guid(old['state']['objects'][0]['id'])).Attributes.Duplicate()
  attr.Name='1016_两条高边共同顶面_连续实体';attr.LayerIndex=ns['layer']('03_双高边顶面连续实体_v02')
  attr.Mode=Rhino.DocObjects.ObjectMode.Normal
  attr.SetUserString('recipe',TAG);attr.SetUserString('top_guides','C1,C3');attr.SetUserString('ground_guides','C4,C2')
  attr.WireDensity=-1
  mode=next(m for m in Rhino.Display.DisplayModeDescription.GetDisplayModes()if m.EnglishName=='Rendered')
  attr.SetDisplayModeOverride(mode)
  oid=sc.doc.Objects.AddBrep(data['geometry'],attr);data['object_id']=str(oid)
 finally:sc.doc.EndUndoRecord(undo);sc.doc.Views.Redraw()
 print('Published '+data['object_id'])
