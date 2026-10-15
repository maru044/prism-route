# -*- coding: utf-8 -*-
"""Replace the retained bridge-side concave shoulder with a convex volume.

ARCHIVED FAILED EXPERIMENT: build() previously stalled Rhino. Do not run it
on the working document. See reference_1016_completion_v03/RECOVERY_STATUS.md;
the saved scene uses the closed-mesh v05 method instead.

Retain its front edge and end cuts. Raise the bridge-side join with the crown.
No tunnel cuts, new cavities, or bridge-height changes.
"""
from __future__ import division, unicode_literals
import Rhino, scriptcontext as sc, System, math, json
G=Rhino.Geometry
SOURCE='8d61be24-ad05-42dc-a1e3-5eec0bcf4f5d'
TAG='prism_landscape_1016_convex_shoulder_v04'
OUT='D:/Prism Route/prism-route/docs/concepts/reference_1016_completion_v03'

def build():
 old=sc.doc.Objects.FindId(System.Guid(SOURCE)).Geometry
 top=old.Faces[4].DuplicateFace(False);top.Faces.ShrinkFaces()
 original=top.Faces[0].UnderlyingSurface().ToNurbsSurface();s=original.Duplicate()
 # The visible shoulder is a trimmed fraction of the original loft. Build
 # the convex profile across that ACTUAL width, not across the hidden loft.
 for knots,subdiv in [(s.KnotsU,5),(s.KnotsV,8)]:
  distinct=sorted(set(float(k)for k in knots))
  for a,b in zip(distinct,distinct[1:]):
   for j in range(1,subdiv):knots.InsertKnot(a+(b-a)*j/subdiv)
 trimcurves=[tr.DuplicateCurve()for tr in top.Faces[0].Loops[0].Trims]
 uv_boundary=G.Curve.JoinCurves(trimcurves,.00001)[0]
 def ease(x):
  x=max(0.,min(1.,x));return x*x*(3-2*x)
 nu=s.Points.CountU;nv=s.Points.CountV
 profiles=[]
 for i in range(nu):
  u=sum(s.KnotsU[i+k]for k in range(s.Degree(0)))/s.Degree(0)
  line=G.Line(G.Point3d(u,-1,0),G.Point3d(u,6,0))
  events=G.Intersect.Intersection.CurveLine(uv_boundary,line,.00001,.00001)
  vs=[e.PointA.Y for e in events]
  if not vs:continue
  back=max(vs);front=min(vs)
  if back-front<.01:continue
  strength=ease((u-1380.)/35.)*ease((1670.-u)/35.)
  if strength==0:continue
  zfront=original.PointAt(u,front).Z;zback=original.PointAt(u,back).Z
  raised_back=max(zback,45.)
  for j in range(nv):
   v=sum(s.KnotsV[j+k]for k in range(s.Degree(1)))/s.Degree(1)
   fraction=max(0.,min(1.,(v-front)/(back-front)))
   # A fast rise and a rounded crown above the back landing: convex, not a bowl.
   desired=zfront+(raised_back-zfront)*math.sin(math.pi*.5*fraction)+6*math.sin(math.pi*fraction)**2
   cp=s.Points.GetControlPoint(i,j);p=cp.Location
   if j==0:continue
   s.Points.SetPoint(i,j,G.Point3d(p.X,p.Y,p.Z+(desired-p.Z)*strength),cp.Weight)
  profiles.append({'u':u,'front_z':zfront,'old_back_z':zback,'new_back_target_z':raised_back,'strength':strength})
 idx=top.AddSurface(s);top.Faces[0].ChangeSurface(idx);top.Faces[0].RebuildEdges(.001,True,True);top.Compact()
 # Its bridge-side boundary cuts through the old loft rather than following
 # a V edge. That boundary rises with the new convex top; rebuild its wall.
 walls=[];floor=[]
 for c in top.DuplicateNakedEdgeCurves(True,False):
  q=c.ToNurbsCurve()
  for j in range(q.Points.Count):
   cp=q.Points[j];p=cp.Location;q.Points.SetPoint(j,G.Point3d(p.X,p.Y,-2),cp.Weight)
  walls.extend(G.Brep.CreateFromLoft([c,q],G.Point3d.Unset,G.Point3d.Unset,G.LoftType.Straight,False));floor.append(q)
 floor=G.Brep.CreatePlanarBreps(G.Curve.JoinCurves(floor,.005),.005)
 joined=G.Brep.JoinBreps([top]+walls+list(floor),.005)
 if not joined or len(joined)!=1:raise RuntimeError('Shoulder perimeter did not reconnect')
 body=joined[0];body.JoinNakedEdges(.005)
 sc.sticky['1016_convex_debug']={'body':body,'top':top,'surface':s,'original':original}
 if not body.IsValid or not body.IsSolid:raise RuntimeError('Convex shoulder is not a valid solid')
 if body.SolidOrientation==G.BrepSolidOrientation.Inward:body.Flip()
 if body.SolidOrientation!=G.BrepSolidOrientation.Outward:raise RuntimeError('Orientation ambiguous')
 edge_errors=[]
 for tr in top.Faces[0].Loops[0].Trims:
  c=tr.DuplicateCurve()
  # End cuts and low/front perimeter stay fixed. The high-side join is raised.
  if tr.IsoStatus==G.IsoStatus.South or abs(c.PointAtEnd.X-c.PointAtStart.X)<.1:
   for i in range(101):
    p=c.PointAtNormalizedLength(i/100.);edge_errors.append(original.PointAt(p.X,p.Y).DistanceTo(s.PointAt(p.X,p.Y)))
 report={'recipe':TAG,'source':SOURCE,'valid':body.IsValid,'closed':body.IsSolid,'orientation':str(body.SolidOrientation),'original_max_z':old.GetBoundingBox(True).Max.Z,'new_max_z':body.GetBoundingBox(True).Max.Z,'front_and_end_max_displacement_m':max(edge_errors),'bridge_side_boundary':'Raised with the crown; sidewall rebuilt to the same base.','bridge_unchanged':True,'tunnel_operations':0}
 sc.sticky[TAG]={'geometry':body,'top':top,'report':report}
 print(json.dumps(report))

def publish():
 d=sc.sticky[TAG];o=sc.doc.Objects.FindId(System.Guid(SOURCE))
 undo=sc.doc.BeginUndoRecord('1016 桥侧空槽改为鼓起实体')
 try:
  l=Rhino.DocObjects.Layer();l.Name='1016_桥侧鼓起曲面修正_v04';l.Color=System.Drawing.Color.FromArgb(239,234,223)
  li=sc.doc.Layers.FindByFullPath(l.Name,-1)
  if li<0:li=sc.doc.Layers.Add(l)
  a=o.Attributes.Duplicate();a.Name='桥侧鼓起实体_圆顺凸冠_保留两端开口';a.LayerIndex=li;a.Mode=Rhino.DocObjects.ObjectMode.Normal;a.WireDensity=-1
  a.ObjectColor=System.Drawing.Color.FromArgb(239,234,223);a.ColorSource=Rhino.DocObjects.ObjectColorSource.ColorFromObject
  a.SetUserString('recipe',TAG);a.SetUserString('preserved_source',SOURCE)
  oid=sc.doc.Objects.AddBrep(d['geometry'],a);d['object_id']=str(oid);sc.doc.Objects.Hide(o.Id,True)
 finally:sc.doc.EndUndoRecord(undo);sc.doc.Views.Redraw()
 with open(OUT+'/convex_shoulder_v04_report.json','w')as f:json.dump(d['report'],f,indent=2)
 print('Published convex shoulder',d['object_id'])
