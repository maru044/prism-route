# -*- coding: utf-8 -*-
"""A1 double bridge: directly constructed NURBS shells and rolled apertures.

No SubD conversion. Stages prepare, frame_side, decks, assemble, publish, verify.
"""
from __future__ import unicode_literals,division
import Rhino,scriptcontext as sc,System,math,json,io,os
G=Rhino.Geometry
TAG='double_bridge_A1_NURBS_1020'
OUT='D:/Prism Route/prism-route/docs/concepts/double_bridge_A1_model_2026-10-20'
IDS=['5182ccac-8e3b-4322-8826-976a9254271b','0808d32c-6ebc-4105-9258-a0f755ac2752',
     '301ef8a8-0448-4086-b86d-3df7326e1caf','59dd95cc-d6f3-4378-ae67-d76fcbdf6ac8']

def objects():
 e=Rhino.DocObjects.ObjectEnumeratorSettings();e.NormalObjects=True;e.HiddenObjects=True;e.LockedObjects=True
 return list(sc.doc.Objects.GetObjectList(e))
def obj(k):return sc.doc.Objects.FindId(System.Guid(k))
def unit(v):v=G.Vector3d(v);assert v.Unitize();return v
def smooth(t):t=max(0.,min(1.,t));return t*t*(3-2*t)

def prepare():
 assert TAG not in sc.sticky,'Existing staged geometry: reuse rather than reset'
 fs=[obj(k).Geometry.Faces[1 if i==2 else 0]for i,k in enumerate(IDS)]
 ends=[]
 for i,f in enumerate(fs):
  along=0 if i==2 else 1;cross=1-along
  c=f.IsoCurve(along,f.Domain(cross).Mid)
  end=i in [0,3];t=c.Domain.T1 if end else c.Domain.T0
  p=c.PointAt(t);a=c.TangentAt(t)
  if i in [2,3]:a=-a
  edge=f.IsoCurve(cross,t);n=edge.PointAtEnd-edge.PointAtStart
  if G.Vector3d.Multiply(n,G.Vector3d(-.62,.78,0))<0:n=-n
  width=n.Length;n=unit(n)
  ends.append((p,unit(a),n,width))
 d={'before':{str(o.Id):int(o.Geometry.DataCRC(0))for o in objects()if o.Attributes.GetUserString('recipe')!=TAG},'ends':ends,
    'parts':{},'view':Rhino.DocObjects.ViewportInfo(sc.doc.Views.ActiveView.ActiveViewport),
    'display':sc.doc.Views.ActiveView.ActiveViewport.DisplayMode}
 for name,indices in [('upper',(0,1)),('lower',(2,3))]:
  a,b=[ends[i]for i in indices];L=a[0].DistanceTo(b[0])
  cps=[a[0],a[0]+a[1]*(L/3.),b[0]-b[1]*(L/3.),b[0]]
  c=G.NurbsCurve.Create(False,3,cps);c.Domain=G.Interval(0,1)
  d[name]={'curve':c,'length':L,'a':a,'b':b}
 d['length']=(d['upper']['length']+d['lower']['length'])*.5
 sc.sticky[TAG]=d
 return {'length':d['length'],'end_widths':[e[3]for e in ends],
         'upper_end_z':[ends[0][0].Z,ends[1][0].Z],
         'lower_end_z':[ends[2][0].Z,ends[3][0].Z]}

def road(name,x):
 d=sc.sticky[TAG];v=d[name];t=x/d['length'];c=v['curve']
 tt=max(0,min(1,t));p=c.PointAt(tt);a=unit(c.TangentAt(tt))
 if t<0:p+=a*x
 elif t>1:p+=a*(x-d['length'])
 n=unit(v['a'][2]*(1-tt)+v['b'][2]*tt)
 # Follow the actual supplied cross section, including the small crossfall.
 w=v['a'][3]*(1-tt)+v['b'][3]*tt
 return p,n,w

def xyz(x,y,zfrac):
 lo,n0,w0=road('lower',x);hi,n1,w1=road('upper',x)
 n=unit(n0*(1-zfrac)+n1*zfrac);roll=n.Z;n.Z=0;n=unit(n)
 p=lo+(hi-lo)*zfrac+n*y
 p.Z=(lo.Z-3.15)*(1-zfrac)+(hi.Z+.02)*zfrac+y*roll
 return p

def surface(side,outer):
 d=sc.sticky[TAG];nu=17;nv=4;pts=[];L=d['length']
 for i in range(nu):
  u=i/(nu-1.);x=-7.+(L+14)*u
  for j in range(nv):
   v=j/3.
   # Inner side is outside all traffic envelopes; outer skin swells in depth.
   if outer:y=14.6+2.8*math.sin(math.pi*u)*(.62+.38*math.sin(math.pi*v))+.6*(v-.5)
   else:y=12.5+.4*math.sin(math.pi*u)*math.sin(math.pi*v)
   pts.append(xyz(x,side*y,v))
 s=G.NurbsSurface.CreateFromPoints(pts,nu,nv,3,3);assert s and s.IsValid
 s.SetDomain(0,G.Interval(0,1));s.SetDomain(1,G.Interval(0,1))
 return s

def uvloop(points):return G.NurbsCurve.Create(True,3,[G.Point3d(x,y,0)for x,y in points])

def profiles(side,inner=False):
 # A smooth periodic outer rim and two unequal slanting voids.
 outer=uvloop([(.02,0),(0,0),(0,.025),(0,.32),(0,.68),(0,.975),(0,1),(.025,1),
  (.33,1),(.67,1),(.975,1),(1,1),(1,.975),(1,.68),(1,.32),(1,.025),(1,0),(.975,0),(.67,0),(.33,0)])
 h1=[(.025,.46),(.035,.78),(.09,.94),(.28,.975),(.55,.975),(.745,.95),
     (.72,.83),(.55,.51),(.37,.19),(.20,.055),(.065,.13)]
 h2=[(.35,.06),(.47,.15),(.66,.49),(.82,.88),(.94,.95),(.975,.78),
     (.98,.38),(.95,.13),(.79,.035),(.51,.03)]
 if side>0:
  h1=[(1-x,y)for x,y in reversed(h1)];h2=[(1-x,y)for x,y in reversed(h2)]
 if inner:
  h1=[(x,.12+.74*y)for x,y in h1];h2=[(x,.12+.74*y)for x,y in h2]
 # Keep trims strictly within the parent surface so the periodic outer loop
 # is not split inconsistently where it happens to touch a UV-domain edge.
 transform=G.Transform.Scale(G.Plane.WorldXY,.994,.994,1.)
 outer.Transform(transform);outer.Translate(G.Vector3d(.003,.003,0))
 return [outer,uvloop(h1),uvloop(h2)]

def trimmed(s,loops):
 full=s.ToBrep();crvs=[s.Pushup(c,.0005)for c in loops];assert all(crvs)
 pieces=full.Faces[0].Split(crvs,.002);assert pieces and pieces.IsValid
 # Face.Split returns a Brep with separate faces, including the removed regions.
 keep=[]
 for f in pieces.Faces:
  # Retain the annular frame by an actual UV point in the left side post.
  if f.IsPointOnFace(.018,.5)!=G.PointFaceRelation.Exterior:keep.append(f.DuplicateFace(False))
 assert len(keep)==1,('trimmed faces',len(keep),pieces.Faces.Count)
 return keep[0]

def pair_edges(a,b):
 pairs=[];remaining=list(b.Edges)
 for e in a.Edges:
  p=e.PointAt(e.Domain.Mid)
  # Same UV boundaries, displaced laterally. Closest corresponding edge by length.
  q=min(remaining,key=lambda f:abs(f.GetLength()-e.GetLength())+f.PointAt(f.Domain.Mid).DistanceTo(p)*.1)
  remaining.remove(q);pairs.append((e,q))
 return pairs

def frame_side(side):
 d=sc.sticky[TAG];a=trimmed(surface(side,True),profiles(side));b=trimmed(surface(side,False),profiles(side,True))
 b.Flip()
 # Each skin is an untrimmed smooth NURBS carrying three smooth loop trims.
 # Roll the aperture through the FULL structural depth, tangent to both skins.
 patches=[a,b];blends=[]
 for e,f in pair_edges(a,b):
  rev=e.PointAt(e.Domain.ParameterAt(.25)).DistanceTo(f.PointAt(f.Domain.ParameterAt(.75)))<e.PointAt(e.Domain.ParameterAt(.25)).DistanceTo(f.PointAt(f.Domain.ParameterAt(.25)))
  q=G.Brep.CreateBlendSurface(a.Faces[0],e,e.Domain,False,G.BlendContinuity.Tangency,
                            b.Faces[0],f,f.Domain,rev,G.BlendContinuity.Tangency)
  assert q and len(q),('blend failed',side,e.EdgeIndex)
  patches.extend(q);blends.extend(q)
 joined=G.Brep.JoinBreps(patches,.005)
 assert joined and len(joined)==1,('join',side,len(joined)if joined else 0)
 body=joined[0];body.JoinNakedEdges(.005)
 d['debug_side']={'a':a,'b':b,'patches':patches,'body':body}
 assert body.IsValid and body.IsSolid,('not solid',body.IsValid,body.IsSolid)
 if body.SolidOrientation==G.BrepSolidOrientation.Inward:body.Flip()
 name='near'if side<0 else'far';d['parts'][name]=body
 d[name+'_skins']=[a,b];d[name+'_blends']=blends
 return {'part':name,'faces':body.Faces.Count,'solid':body.IsSolid,
         'nurbs_surfaces':all(isinstance(f.UnderlyingSurface(),G.NurbsSurface)for f in body.Faces),
         'blend_patches':len(blends),'naked_edges':sum(e.Valence==G.EdgeAdjacency.Naked for e in body.Edges)}

def decks():
 """Traffic surfaces only; the two spanning slabs belong to assemble()."""
 d=sc.sticky[TAG];L=d['length']
 for name in ['lower','upper']:
  asphalt=[]
  for i in range(33):
   x=-.08+(L+.16)*i/32.;p,n,w=road(name,x)
   asphalt.append(G.LineCurve(p-n*(w*.5),p+n*(w*.5)))
  top=G.Brep.CreateFromLoft(asphalt,G.Point3d.Unset,G.Point3d.Unset,G.LoftType.Normal,False)[0]
  face=top.Faces[0]
  if face.NormalAt(face.Domain(0).Mid,face.Domain(1).Mid).Z<0:top.Flip()
  paving=G.Brep.CreateFromOffsetFace(top.Faces[0],-.28 if name=='upper'else-.16,.001,False,True)
  assert paving and paving.IsValid and paving.IsSolid
  d[name+'_paving']=paving
 return {k:{'faces':d[k+'_paving'].Faces.Count,'solid':d[k+'_paving'].IsSolid}for k in ['upper','lower']}

def assemble():
 d=sc.sticky[TAG]
 # Remove the inner upper/lower strips and bridge those very same boundaries.
 # This forms one solid directly, with no separately intersecting deck solids.
 opened=[];boundary={}
 for name in ['near','far']:
  full=d['parts'][name];crc=d[name+'_skins'][1].Faces[0].UnderlyingSurface().DataCRC(0)
  idx=next(i for i,f in enumerate(full.Faces)if f.UnderlyingSurface().DataCRC(0)==crc)
  f=full.Faces[idx].DuplicateFace(False).Faces[0]
  split=f.Split([f.IsoCurve(0,.108),f.IsoCurve(0,.89)],.001)
  assert split and split.Faces.Count>=3,('inner strip split',name)
  middle=[q.DuplicateFace(False)for q in split.Faces if q.IsPointOnFace(.018,.5)!=G.PointFaceRelation.Exterior]
  assert len(middle)==1
  faces=middle+[q.DuplicateFace(False)for i,q in enumerate(full.Faces)if i!=idx]
  result=G.Brep.JoinBreps(faces,.003);assert result and len(result)==1
  result=result[0];assert result.IsValid
  loops=G.Curve.JoinCurves(result.DuplicateNakedEdgeCurves(True,False),.003)
  assert loops and len(loops)==2 and all(c.IsClosed for c in loops),('naked loops',name,len(loops)if loops else 0)
  loops=sorted(loops,key=lambda c:c.GetBoundingBox(True).Center.Z)
  opened.append(result);boundary[name]=loops
 spans=[]
 for j in range(2):
  a,b=boundary['near'][j],boundary['far'][j]
  for name,c,side in [('near',a,-1),('far',b,1)]:
   ref=xyz(-4.,side*12.5,.108 if j==0 else .89)
   ok,t=c.ClosestPoint(ref);assert ok;c.ChangeClosedCurveSeam(t)
  if G.Vector3d.Multiply(a.TangentAtStart,b.TangentAtStart)<0:
   b.Reverse();ok,t=b.ClosestPoint(xyz(-4.,12.5,.108 if j==0 else .89));b.ChangeClosedCurveSeam(t)
  lofted=G.Brep.CreateFromLoft([a,b],G.Point3d.Unset,G.Point3d.Unset,G.LoftType.Normal,False)
  assert lofted and len(lofted)==1;spans.extend(lofted)
 joined=G.Brep.JoinBreps(opened+spans,.003)
 assert joined and len(joined)==1,('joined parts',len(joined)if joined else 0)
 b=joined[0];assert b.IsValid and b.IsSolid and b.IsManifold
 if b.SolidOrientation==G.BrepSolidOrientation.Inward:b.Flip()
 d['deck_spans']=spans;d['opened']=opened
 d['body']=b
 return {'faces':b.Faces.Count,'solid':True,'manifold':True,
         'all_surfaces_nurbs':all(isinstance(f.UnderlyingSurface(),G.NurbsSurface)for f in b.Faces)}

def publish():
 d=sc.sticky[TAG];layer=sc.doc.Layers.FindByFullPath('交通::中层道路',-1);assert layer>=0
 mi=next(i for i,m in enumerate(sc.doc.Materials)if m.Name=='隧道_暖白建筑复合面_PBR_非金属')
 d.setdefault('ids',{});undo=sc.doc.BeginUndoRecord('A1双层桥_连续NURBS交织壳体')
 try:
  for role,key,name in [('shell','body','A1双层桥_连续NURBS桥腹与交织斜壳'),
    ('upper_road','upper_paving','A1双层桥_上层路面'),('lower_road','lower_paving','A1双层桥_下层路面')]:
   old=next((o for o in objects()if o.Attributes.GetUserString('double_bridge_A1_role')==role),None)
   if old:
    assert sc.doc.Objects.Replace(old.Id,d[key]);oid=old.Id
   else:
    a=Rhino.DocObjects.ObjectAttributes();a.LayerIndex=layer;a.Name=name;a.WireDensity=-1
    if role=='shell':a.MaterialIndex=mi;a.MaterialSource=Rhino.DocObjects.ObjectMaterialSource.MaterialFromObject
    else:
     ref=obj(IDS[0 if role=='upper_road'else 2]).Attributes
     a.MaterialIndex=ref.MaterialIndex;a.MaterialSource=ref.MaterialSource
     a.ObjectColor=ref.ObjectColor;a.ColorSource=ref.ColorSource
    a.SetUserString('recipe',TAG);a.SetUserString('double_bridge_A1_role',role)
    oid=sc.doc.Objects.AddBrep(d[key],a);assert oid!=System.Guid.Empty
   d['ids'][role]=str(oid)
 finally:sc.doc.EndUndoRecord(undo)
 sc.doc.Objects.UnselectAll();sc.doc.Views.Redraw();return d['ids']

def capture(name,camera,target):
 view=sc.doc.Views.ActiveView;vp=view.ActiveViewport
 vp.SetCameraLocations(G.Point3d(*target),G.Point3d(*camera));vp.CameraUp=G.Vector3d.ZAxis
 vp.ChangeToPerspectiveProjection(True,42.);sc.doc.Views.Redraw()
 vc=Rhino.Display.ViewCapture();vc.Width=1600;vc.Height=1050;vc.ScaleScreenItems=False
 vc.DrawAxes=False;vc.DrawGrid=False;vc.DrawGridAxes=False
 bitmap=vc.CaptureToBitmap(view);assert bitmap
 path=OUT+'/'+name+'.png';bitmap.Save(path,System.Drawing.Imaging.ImageFormat.Png);bitmap.Dispose();return path


def verify():
 d=sc.sticky[TAG];b=d['body'];m=d['body_mesh']
 graph={i:set()for i in range(b.Faces.Count)}
 for i,f in enumerate(b.Faces):graph[i].update(f.AdjacentFaces())
 seen=set();todo=[0]
 while todo:
  i=todo.pop()
  if i in seen:continue
  seen.add(i);todo.extend(graph[i]-seen)
 assert len(seen)==b.Faces.Count
 assert b.IsValid and b.IsSolid and b.IsManifold
 assert all(isinstance(f.UnderlyingSurface(),G.NurbsSurface)for f in b.Faces)
 support={}
 for name in ['lower','upper']:
  down=[];up=[];miss=[]
  for i in range(101):
   x=d['length']*i/100.;p,n,w=road(name,x)
   for y in [-9.5,-5.,0.,5.,9.5]:
    origin=p+n*y+G.Vector3d(0,0,.025)
    a=G.Intersect.Intersection.MeshRay(m,G.Ray3d(origin,-G.Vector3d.ZAxis))
    z=G.Intersect.Intersection.MeshRay(m,G.Ray3d(origin,G.Vector3d.ZAxis))
    if a<0:miss.append([i,y])
    else:down.append(a-.025)
    if z>=0:up.append(z+.025)
  thick=.28 if name=='upper'else.16
  assert not miss and min(down)>0 and max(down)<thick
  assert not up or min(up)>6.
  support[name]={'samples':505,'support_gap_m':[min(down),max(down)],
   'paving_thickness_m':thick,'minimum_paving_overlap_m':thick-max(down),
   'minimum_headroom_m':min(up)if up else None}
 # Only shell / rolled-reveal seams are designed tangent. Inner floor/wall
 # corners at the spanning slabs are intentionally not included in this metric.
 angles=[];gaps=[]
 for edge in b.Edges:
  adjacent=list(edge.AdjacentFaces())
  if len(adjacent)!=2 or any(i>=10 for i in adjacent):continue
  f1,f2=[b.Faces[i]for i in adjacent]
  for j in range(1,10):
   pt=edge.PointAt(edge.Domain.ParameterAt(j/10.))
   ok,u,v=f1.ClosestPoint(pt);assert ok
   ok,r,s=f2.ClosestPoint(pt);assert ok
   n1=unit(f1.NormalAt(u,v));n2=unit(f2.NormalAt(r,s))
   angles.append(math.degrees(math.acos(min(1.,abs(G.Vector3d.Multiply(n1,n2))))))
   gaps.append(f1.PointAt(u,v).DistanceTo(f2.PointAt(r,s)))
 assert max(angles)<.1 and max(gaps)<.003
 # Native endpoint cross sections, not an assumption of vertical alignment.
 seams=[]
 for name,indices in [('upper',(0,1)),('lower',(2,3))]:
  for x,k in [(0,indices[0]),(d['length'],indices[1])]:
   pt,n,w=road(name,x);p0,t0,n0,w0=d['ends'][k]
   seams.append(max((pt+n*(w*y)).DistanceTo(p0+n0*(w0*y))for y in [-.5,0,.5]))
 assert max(seams)<.001
 changed=[k for k,v in d['before'].items()if obj(k)is None or int(obj(k).Geometry.DataCRC(0))!=v]
 assert not changed
 for key in ['body','upper_paving','lower_paving']:
  assert d[key].IsValid and d[key].IsSolid
 assert all(not v['blockages']for v in d['existing_clearance'].values())
 report={'document':sc.doc.Path,'object_count':len(objects()),'layer_count':sum(not layer.IsDeleted for layer in sc.doc.Layers),
  'ids':d['ids'],'span_m':d['length'],'body':{'faces':b.Faces.Count,'solid':b.IsSolid,
  'manifold':b.IsManifold,'connected_face_components':1,'naked_edges':sum(e.Valence==G.EdgeAdjacency.Naked for e in b.Edges),
  'all_surfaces_native_nurbs':True},'traffic_support':support,
  'rolled_seams':{'sample_count':len(angles),'max_normal_angle_degrees':max(angles),'max_surface_gap_m':max(gaps)},
  'source_cross_section_max_join_error_m':max(seams),'unchanged_original_objects':len(d['before']),
  'existing_scene_clearance':d['existing_clearance'],
  'limitations':['Rhino geometry and sampled clearance validation only; no Godot driving/collision validation or engineering load verification.']}
 d['report']=report
 with io.open(OUT+'/validation.json','w',encoding='utf-8')as f:f.write(json.dumps(report,ensure_ascii=False,indent=2))
 return report


def save_current():
 d=sc.sticky[TAG];assert 'report'in d
 assert sc.doc.Path.replace('\\','/').replace('//','/').lower()=='d:/prism route/map/map_current.3dm'
 assert Rhino.RhinoApp.RunScript('_Save',False)
 saved=Rhino.FileIO.File3dm.Read(sc.doc.Path);assert saved
 current={str(o.Id):int(o.Geometry.DataCRC(0))for o in objects()}
 disk={str(o.Id):int(o.Geometry.DataCRC(0))for o in saved.Objects}
 assert current==disk, 'Saved file does not match current document'
 saved.Dispose();d['report']['saved_file_crc_matches']=True
 d['report']['saved_object_count']=len(disk)
 with io.open(OUT+'/validation.json','w',encoding='utf-8')as f:f.write(json.dumps(d['report'],ensure_ascii=False,indent=2))
 return {'saved':sc.doc.Path,'matched_objects':len(disk)}


def cache_validation_meshes():
 d=sc.sticky[TAG];mp=G.MeshingParameters.Default
 mp.MinimumEdgeLength=.05;mp.MaximumEdgeLength=1.5;mp.Tolerance=.005
 m=G.Mesh()
 for q in G.Mesh.CreateFromBrep(d['body'],mp):m.Append(q)
 m.Normals.ComputeNormals();m.Compact();d['body_mesh']=m
 box=d['body'].GetBoundingBox(True);cached=[]
 for o in objects():
  if str(o.Id)not in d['before']or o.IsHidden:continue
  g=o.Geometry
  if not isinstance(g,(G.Brep,G.Mesh,G.SubD,G.Extrusion)):continue
  b=g.GetBoundingBox(True)
  if any([b.Max.X<box.Min.X,b.Min.X>box.Max.X,b.Max.Y<box.Min.Y,b.Min.Y>box.Max.Y,b.Max.Z<box.Min.Z,b.Min.Z>box.Max.Z+6]):continue
  if isinstance(g,G.Mesh):ms=[g]
  elif isinstance(g,G.SubD):ms=[G.Mesh.CreateFromSubD(g,2)]
  else:
   ms=list(o.GetMeshes(G.MeshType.Render)or[])
   if not ms:ms=list(G.Mesh.CreateFromBrep(g.ToBrep()if isinstance(g,G.Extrusion)else g,mp))
  assert ms,('Missing validation mesh',str(o.Id))
  cached.append((str(o.Id),ms))
 d['existing_meshes']=cached
 return {'body_mesh_faces':m.Faces.Count,'nearby_existing_objects':len(cached)}


def verify_scene_clearance():
 d=sc.sticky[TAG];out={}
 for name in ['lower','upper']:
  blocked=[]
  for i in range(101):
   pt,n,w=road(name,d['length']*i/100.)
   for y in [-9.5,0,9.5]:
    ray=G.Ray3d(pt+n*y+G.Vector3d(0,0,.15),G.Vector3d.ZAxis)
    for key,ms in d['existing_meshes']:
     hits=[G.Intersect.Intersection.MeshRay(q,ray)for q in ms]
     hits=[t for t in hits if 0<=t<=5.85]
     if hits:blocked.append([i,y,key,min(hits)+.15])
  out[name]={'tested_verticals':303,'blockages':blocked}
 d['existing_clearance']=out
 assert all(not v['blockages']for v in out.values()),out
 return out
