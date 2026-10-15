# -*- coding: utf-8 -*-
"""Continuous ground and broad asymmetrical folds for the 1016 site.

No tunnel operations. Original terrain and user guides remain untouched.
Use exported CP elevations from build_landscape_1016_field_v03.py.
"""
from __future__ import division, unicode_literals
import Rhino, scriptcontext as sc, System, json, os, math, io
G=Rhino.Geometry
TAG='prism_landscape_1016_completion_v03'
OUT='D:/Prism Route/prism-route/docs/concepts/reference_1016_completion_v03'
SOURCES=['a4adc150-3ba0-4216-b8b5-8d21449e8f69','4c560a71-7757-47c1-8e6c-23bdf73081d6','493f74fe-8166-43ba-9dd3-b60a30144c9a']

def xyz(p):return [p.X,p.Y,p.Z]
def obj(s):return sc.doc.Objects.FindId(System.Guid(s))

def make_solid(top):
 top=top.DuplicateBrep()
 f=top.Faces[0];u=f.Domain(0).Mid;v=f.Domain(1).Mid
 if f.NormalAt(u,v).Z<0:top.Flip()
 edges=top.DuplicateNakedEdgeCurves(True,False);bottom=[];walls=[]
 for c in edges:
  q=c.ToNurbsCurve()
  for i in range(q.Points.Count):
   cp=q.Points[i];p=cp.Location;q.Points.SetPoint(i,G.Point3d(p.X,p.Y,-7),cp.Weight)
  loft=G.Brep.CreateFromLoft([c,q],G.Point3d.Unset,G.Point3d.Unset,G.LoftType.Straight,False)
  if not loft:raise RuntimeError('Boundary sidewall failed')
  walls.extend(loft);bottom.append(q)
 loops=G.Curve.JoinCurves(bottom,.01);floor=G.Brep.CreatePlanarBreps(loops,.01)
 if not floor:raise RuntimeError('Ground footprint did not close')
 parts=G.Brep.JoinBreps([top]+walls+list(floor),.01)
 if len(parts)!=1:raise RuntimeError('Ground shell failed to join')
 b=parts[0];b.JoinNakedEdges(.01)
 if not b.IsValid or not b.IsSolid:raise RuntimeError('Invalid/open ground solid')
 if b.SolidOrientation==G.BrepSolidOrientation.Inward:b.Flip()
 if b.SolidOrientation!=G.BrepSolidOrientation.Outward:raise RuntimeError('Ground orientation ambiguous')
 return b

def build():
 controls=json.load(open(OUT+'/elevation_controls.json'));bodies=[]
 for row in controls:
  sid=row['id'];face=row['face'];base=sc.sticky['1016_v03_source_'+sid]
  surf=sc.sticky['1016_v03_surface_'+sid+'_'+str(face)].Duplicate()
  for i in range(row['nu']):
   for j in range(row['nv']):
    cp=surf.Points.GetControlPoint(i,j);p=cp.Location;surf.Points.SetPoint(i,j,G.Point3d(p.X,p.Y,row['z'][i*row['nv']+j]),cp.Weight)
  top=base.Faces[face].DuplicateFace(False);si=top.AddSurface(surf)
  if not top.Faces[0].ChangeSurface(si):raise RuntimeError('Surface replacement failed')
  top.Faces[0].RebuildEdges(.005,True,True);top.Compact()
  if not top.IsValid:raise RuntimeError('Updated trimmed surface invalid')
  solid=make_solid(top)
  name={'a4adc150-3ba0-4216-b8b5-8d21449e8f69':'01_中部连续起伏与曲面坡岸','4c560a71-7757-47c1-8e6c-23bdf73081d6':'02_中低地衔接带','493f74fe-8166-43ba-9dd3-b60a30144c9a':'03_滨水低丘连续地面'}[sid]+'_'+str(face)
  bodies.append({'source':sid,'face':face,'name':name,'geometry':solid,'top':top})
  print(name,'valid',solid.IsValid,'solid',solid.IsSolid,'bounds',str(solid.GetBoundingBox(True)))
 sc.sticky[TAG]={'bodies':bodies,'reference_crc':{sid:int(obj(sid).Geometry.DataCRC(0))for sid in sc.sticky['landscape_1016_namespace']['IDS']},'source_crc':{sid:int(obj(sid).Geometry.DataCRC(0))for sid in SOURCES}}

def layer():
 name='1016_连续内湾地形补全_v03';i=sc.doc.Layers.FindByFullPath(name,-1)
 if i<0:
  l=Rhino.DocObjects.Layer();l.Name=name;l.Color=System.Drawing.Color.FromArgb(239,234,223);i=sc.doc.Layers.Add(l)
 return i

def publish():
 data=sc.sticky[TAG];undo=sc.doc.BeginUndoRecord('1016 连续起伏地形与低地补全')
 try:
  mode=next(m for m in Rhino.Display.DisplayModeDescription.GetDisplayModes()if m.EnglishName=='Shaded')
  mat=Rhino.DocObjects.Material();mat.Name='1016_v03_统一暖白形态验证';mat.DiffuseColor=System.Drawing.Color.FromArgb(239,234,223);mat.Shine=35;mat.Reflectivity=.1;mi=sc.doc.Materials.Add(mat)
  mesh=G.MeshingParameters();mesh.MaximumEdgeLength=5;mesh.Tolerance=.025;mesh.RefineGrid=True;mesh.JaggedSeams=False
  for b in data['bodies']:
   a=Rhino.DocObjects.ObjectAttributes();a.Name=b['name'];a.LayerIndex=layer();a.WireDensity=-1
   a.ColorSource=Rhino.DocObjects.ObjectColorSource.ColorFromObject;a.ObjectColor=System.Drawing.Color.FromArgb(239,234,223)
   a.MaterialSource=Rhino.DocObjects.ObjectMaterialSource.MaterialFromObject;a.MaterialIndex=mi;a.CustomMeshingParameters=mesh;a.SetDisplayModeOverride(mode)
   a.SetUserString('recipe',TAG);a.SetUserString('source_terrain',b['source']);a.SetUserString('no_new_tunnels','true')
   oid=sc.doc.Objects.AddBrep(b['geometry'],a);b['object_id']=str(oid)
  # Only the coastal originals and our own obsolete, disconnected ridge drafts.
  # The source upper parcel was already hidden by the user and remains hidden.
  for sid in SOURCES[1:]:sc.doc.Objects.Hide(System.Guid(sid),True)
  for row in sc.sticky['prism_landscape_1016_v01']['state']['objects'][2:]:sc.doc.Objects.Hide(System.Guid(row['id']),True)
 finally:sc.doc.EndUndoRecord(undo);sc.doc.Views.Redraw()
 print('Published continuous ground',len(data['bodies']))
