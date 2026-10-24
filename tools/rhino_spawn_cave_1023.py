# -*- coding: utf-8 -*-
"""Staged native NURBS starting cave, integrated pedestrian ledge and rails.

Run functions explicitly in the live Rhino document. Construction intermediates
stay in scriptcontext.sticky, never on hidden document layers.
"""
from __future__ import unicode_literals, division
import Rhino, scriptcontext as sc, System, math, io, json
G=Rhino.Geometry
TAG='spawn_cave_model_1023'
ROOT='D:/Prism Route/prism-route'
OUT=ROOT+'/docs/concepts/spawn_cave_1023'
TERRAIN='577d868b-7597-4058-83f8-4b630606b305'
Q=G.Point3d(651.1922449843955,-368.44157405747984,33.)
N=G.Vector3d(-.7777442901023691,-.6285807976809043,0.)
A=G.Vector3d(-.6285807976809043,.7777442901023691,0.)

def state():return sc.sticky[TAG]
def xyz(p):return [p.X,p.Y,p.Z]
def unit(v):
 v=G.Vector3d(v);assert v.Unitize();return v
def smooth(t):
 t=max(0.,min(1.,t));return t*t*t*(10.-15.*t+6.*t*t)
def height(y):return 35.+18.*max(0.,(-220.-y)/262.50420930602417)**3
def objects():
 e=Rhino.DocObjects.ObjectEnumeratorSettings();e.NormalObjects=True;e.HiddenObjects=True;e.LockedObjects=True
 return list(sc.doc.Objects.GetObjectList(e))
def write(name,value):
 with io.open(OUT+'/'+name,'w',encoding='utf-8')as f:f.write(json.dumps(value,ensure_ascii=False,indent=2))
def solid(b):
 assert b and b.IsValid and b.IsSolid and b.IsManifold,'Invalid or open Brep'
 if b.SolidOrientation==G.BrepSolidOrientation.Inward:b.Flip()
 return b

def setup():
 d=state();b=d['original']
 ok,cs,pts=G.Intersect.Intersection.BrepPlane(b,G.Plane(G.Point3d(0,0,33),G.Vector3d.ZAxis),.001)
 joined=G.Curve.JoinCurves(cs,.002);assert len(joined)==1 and joined[0].IsClosed
 c=joined[0];ok,t=c.ClosestPoint(Q);assert ok and c.PointAt(t).DistanceTo(Q)<.005
 d['wall']=c;d['wall_station']=c.GetLength(G.Interval(c.Domain.T0,t));d['wall_length']=c.GetLength()
 d['parts']={};return {'baseline_objects':len(d['before']),'wall_length':d['wall_length']}

def wall(s):
 d=state();ok,t=d['wall'].LengthParameter((d['wall_station']+s)%d['wall_length']);assert ok
 p=d['wall'].PointAt(t);a=unit(d['wall'].TangentAt(t));a.Z=0.;a=unit(a)
 inward=unit(G.Vector3d(-a.Y,a.X,0.))
 assert G.Vector3d.Multiply(inward,N)>.7
 return p,a,inward

def arch(depth,width,h):
 plane=G.Plane(Q+N*depth,A,G.Vector3d.ZAxis)
 full=G.Ellipse(plane,width*.5,h).ToNurbsCurve()
 roof=full.Trim(full.Domain.T0,full.Domain.Mid);assert roof
 result=G.PolyCurve();result.Append(roof);result.Append(G.LineCurve(roof.PointAtEnd,roof.PointAtStart))
 assert result.IsClosed and result.IsPlanar(.001)
 return result

def build_cutter():
 d=state()
 specs=[(-7.,14.,3.85),(-4.,11.2,3.65),(0.,9.,3.5),(2.,7.9,3.35),(5.,6.25,3.15),(9.,4.95,3.02),(14.,4.5,3.),(18.,4.5,3.),(20.,4.5,3.)]
 curves=[arch(*spec)for spec in specs]
 result=G.Brep.CreateFromLoft(curves,G.Point3d.Unset,G.Point3d.Unset,G.LoftType.Normal,False)
 assert result and len(result)==1
 d['cutter']=solid(result[0].CapPlanarHoles(.001));d['cave_sections']=specs
 return {'cutter_valid':True,'faces':d['cutter'].Faces.Count}

def excavate():
 d=state();result=G.Brep.CreateBooleanDifference(d['original'],d['cutter'],.001)
 assert result and len(result)==1,'Cave cut must leave one connected closed terrain'
 d['terrain']=solid(result[0]);d['parts']['terrain']=d['terrain']
 return {'terrain_valid':True,'solid':True,'faces':d['terrain'].Faces.Count}

def road_frame(s):
 p,a,n=wall(s)
 apron=1.-smooth((s-7.)/9.)
 shift=-6.*smooth((s-78.)/40.)
 inner=shift;outer=3.5+1.35*apron+shift
 middle=(inner+outer)*.5
 center=p-n*middle
 base=33.+2.48*smooth((s-12.)/96.)
 blend=smooth((s-83.)/37.)
 z=base*(1.-blend)+height(center.Y)*blend
 # Bury the final 4m tail gradually so it meets, rather than duplicates, the
 # existing roof surface. The visible route continues on the return cut floor.
 z-=.025*smooth((s-120.)/4.)
 # Crossfall conforms smoothly to the existing roof only at the return.
 roll=blend*(height((p-n*(middle+.1)).Y)-height((p-n*(middle-.1)).Y))/.2
 return p,a,n,inner,outer,z,roll

def road_point(s,u,dz=0.):
 p,a,n,inner,outer,z,roll=road_frame(s)
 q=p-n*u;q.Z=z+roll*(u-(inner+outer)*.5)+dz;return q

def road_sections(s):
 p,a,n,inner,outer,z,roll=road_frame(s)
 width=outer-inner
 specs=[[(inner,0),(outer,0)],[(outer,0),(outer,-.35)],
  [(outer,-.35),(outer-width*.25,-.35),(inner+width*.25,-2.),(inner-.6,-2.)],
  [(inner-.6,-2.),(inner,0)]]
 return [G.LineCurve(*[road_point(s,u,h)for u,h in row])if len(row)==2 else G.NurbsCurve.Create(False,3,[road_point(s,u,h)for u,h in row])for row in specs]

def build_road():
 d=state();ss=[-8.+132.*i/88. for i in range(89)];rows=[road_sections(s)for s in ss];surfaces=[]
 for j in range(4):
  cs=[row[j].ToNurbsCurve()for row in rows];nv=cs[0].Points.Count
  pts=[c.Points[k].Location for c in cs for k in range(nv)]
  surf=G.NurbsSurface.CreateFromPoints(pts,len(rows),nv,3,nv-1);assert surf
  surfaces.append(surf.ToBrep())
 joined=G.Brep.JoinBreps(surfaces,.001);assert joined and len(joined)==1
 d['road_raw']=solid(joined[0].CapPlanarHoles(.001));d['road_stations']=ss
 return {'road_raw_faces':d['road_raw'].Faces.Count,'solid':True}

def trim_road():
 # The top begins exactly on the wall boundary. Only the hidden underside
 # penetrates 0.6m into the cliff as a deliberate structural anchor. Construct
 # this boundary directly: Boolean near-tangencies can reverse the walk surface.
 d=state();d['road']=solid(d['road_raw'].DuplicateBrep());d['parts']['road']=d['road']
 return {'road_faces':d['road'].Faces.Count,'solid':True}

def cut_return():
 d=state();profiles=[]
 for i in range(39):
  s=72.+56.*i/38.;p,a,n,inner,outer,z,roll=road_frame(s)
  # Include a shallow inside shoulder at the roof return. Stay below the path
  # by 2cm while it is supported, then let the cut rise out of the roof.
  inner-=.6
  dz=-.02+.06*smooth((s-120.)/8.)
  corners=[road_point(s,inner,dz),road_point(s,outer+.1,dz),road_point(s,outer+.1,8.),road_point(s,inner,8.)]
  profiles.append(G.PolylineCurve(corners+[corners[0]]))
 rs=G.Brep.CreateFromLoft(profiles,G.Point3d.Unset,G.Point3d.Unset,G.LoftType.Normal,False)
 assert rs and len(rs)==1
 cutter=solid(rs[0].CapPlanarHoles(.001));d['return_cutter']=cutter
 rs=G.Brep.CreateBooleanDifference(d['terrain'],cutter,.01)
 assert rs and len(rs)==1,'Return cut must leave a single terrain'
 d['terrain']=solid(rs[0]);d['parts']['terrain']=d['terrain']
 return {'terrain_faces':d['terrain'].Faces.Count,'return_cut_solid':True}

def mesh(b,step=1.):
 p=G.MeshingParameters();p.Tolerance=.002;p.MaximumEdgeLength=step;p.MinimumEdgeLength=.005;p.RefineGrid=True;p.SimplePlanes=True
 m=G.Mesh()
 for q in G.Mesh.CreateFromBrep(b,p):m.Append(q)
 m.Normals.ComputeNormals();m.Compact();return m

def cache_meshes():
 d=state();d['terrain_mesh']=mesh(d['terrain'],2.);d['original_mesh']=mesh(d['original'],2.)
 d['road_mesh']=mesh(d['road'],.5)
 return {k:d[k].Faces.Count for k in ['terrain_mesh','original_mesh','road_mesh']}

def hit(m,p,direction):
 t=G.Intersect.Intersection.MeshRay(m,G.Ray3d(p,direction))
 return None if t<0 else p+direction*t

def check_cave():
 d=state();roof=[];bad=[];rows=[]
 for dep in [0.,.2,1.,2.,3.,5.,7.,10.,14.,18.,19.5]:
  center=Q+N*dep
  for across in [-1.,-.5,0.,.5,1.]:
   p=center+A*across+G.Vector3d(0,0,.2)
   floor=hit(d['terrain_mesh'],p,-G.Vector3d.ZAxis)
   ceiling=hit(d['terrain_mesh'],p,G.Vector3d.ZAxis)
   # The exact mouth boundary is a vertical side as well as a roof edge. Query
   # the original NURBS roof just inside it rather than a faceted wall chord.
   probe=p+N*.05 if dep==0. else p
   ok,cc,pp=G.Intersect.Intersection.CurveBrep(G.LineCurve(G.Point3d(probe.X,probe.Y,80),G.Point3d(probe.X,probe.Y,32)),d['original'],.001)
   tops=[v for v in pp if v.Z>36.5]
   top=max(tops,key=lambda v:v.Z)if tops else None
   if not floor or not ceiling or not top:bad.append([dep,across,'missing floor/ceiling']);continue
   clear=ceiling.Z-floor.Z;cover=top.Z-ceiling.Z
   if abs(floor.Z-33.)>.005 or clear<2.5 or cover<1.5:bad.append([dep,across,clear,cover,floor.Z])
   roof.append(cover);rows.append({'depth':dep,'across':across,'floor':floor.Z,'headroom':clear,'cover':cover})
 assert not bad,str(bad[:5])
 d['cave_check']={'samples':rows,'min_cover_sampled':min(roof),'minimum_headroom_sampled':min(r['headroom']for r in rows),'problems':bad}
 return {k:v for k,v in d['cave_check'].items()if k!='samples'}

def check_road():
 d=state();rows=[];bad=[];last=None;max_grade=0.
 for i in range(265):
  s=-7.+131.*i/264.;p,a,n,inner,outer,z,roll=road_frame(s)
  for f in [.12,.5,.88]:
   usable_inner=max(0.,inner)if s<78. else inner
   u=usable_inner+(outer-usable_inner)*f;point=road_point(s,u)
   hits=[hit(m,point+G.Vector3d(0,0,3),-G.Vector3d.ZAxis)for m in [d['terrain_mesh'],d['road_mesh']]]
   hits=[h for h in hits if h is not None];assert hits,'Unsupported road point'
   actual=max(hits,key=lambda h:h.Z);delta=actual.Z-point.Z
   if delta>.08 or delta<-.04:bad.append([s,f,delta])
   if f==.5:
    if last:
     horizontal=math.sqrt((actual.X-last.X)**2+(actual.Y-last.Y)**2)
     max_grade=max(max_grade,abs(actual.Z-last.Z)/horizontal)
    last=actual
   rows.append({'station':s,'fraction':f,'surface_z':actual.Z,'design_delta':delta})
 assert not bad,str(bad[:10]);assert max_grade<.065,max_grade
 d['road_check']={'sample_count':len(rows),'max_grade':max_grade,'max_design_error':max(abs(r['design_delta'])for r in rows),'problems':bad,'samples':rows}
 return {k:v for k,v in d['road_check'].items()if k!='samples'}

def walking_ground(s,u):
 d=state();p=road_point(s,u)
 hs=[hit(m,p+G.Vector3d(0,0,.2),-G.Vector3d.ZAxis)for m in [d['terrain_mesh'],d['road_mesh']]]
 hs=[h for h in hs if h is not None];assert hs
 h=max(hs,key=lambda v:v.Z);assert abs(h.Z-p.Z)<.03
 return h

def pipe(curve,radius):
 rs=G.Brep.CreatePipe(curve,radius,False,G.PipeCapMode.Flat,True,.001,.01)
 assert rs and len(rs)==1
 return solid(rs[0])

def build_rails():
 d=state();rail=G.Brep();posts=G.Brep();report=[]
 count=56;ss=[-7.8+130.*i/(count-1)for i in range(count)]
 for z,r in [(1.15,.035),(.55,.023)]:
  pts=[]
  for i in range(174):
   s=-7.8+130.*i/173.;p,a,n,inner,outer,h,roll=road_frame(s)
   pts.append(walking_ground(s,outer-.18)+G.Vector3d(0,0,z))
  c=G.Curve.CreateInterpolatedCurve(pts,3,G.CurveKnotStyle.Chord)
  rail.Append(pipe(c,r))
 # Short transverse return protects the free end of the cave apron.
 p,a,n,inner,outer,h,roll=road_frame(-7.8)
 for z,r in [(1.15,.035),(.55,.023)]:
  pts=[walking_ground(-7.8,u)+G.Vector3d(0,0,z)for u in [.15,(outer-.18+.15)*.5,outer-.18]]
  rail.Append(pipe(G.PolylineCurve(pts),r))
 bases=[]
 for s in ss:
  p,a,n,inner,outer,h,roll=road_frame(s);base=walking_ground(s,outer-.18);bases.append(base)
  report.append({'station':s,'base':xyz(base),'height':1.15})
 for u in [.15,2.35]:bases.append(walking_ground(-7.8,u))
 for base in bases:
  posts.Append(solid(G.Cylinder(G.Circle(G.Plane(base-G.Vector3d(0,0,.012),G.Vector3d.ZAxis),.029),1.162).ToBrep(True,True)))
 d['parts']['handrails']=solid(rail);d['parts']['posts']=solid(posts)
 d['rail_check']={'post_count':len(bases),'post_spacing_max_m':130./(count-1),'height_m':1.15,'base_checks':report,'apron_end_protected':True}
 return {k:v for k,v in d['rail_check'].items()if k!='base_checks'}

def layer(path,color):
 index=sc.doc.Layers.FindByFullPath(path,-1)
 if index>=0:return index
 parent=None
 if '::'in path:
  parent_path,name=path.rsplit('::',1);parent=sc.doc.Layers[layer(parent_path,color)].Id
 else:name=path
 row=Rhino.DocObjects.Layer();row.Name=name;row.Color=System.Drawing.Color.FromArgb(*color)
 if parent:row.ParentLayerId=parent
 return sc.doc.Layers.Add(row)

def display_mesh_parameters(terrain=False):
 if not terrain:return None
 p=G.MeshingParameters();p.Tolerance=.005;p.MaximumEdgeLength=3.
 p.MinimumEdgeLength=.04;p.GridAngle=.16;p.RefineAngle=.16;p.GridAspectRatio=0.;p.RefineGrid=True;p.SimplePlanes=True
 return p

def publish():
 d=state();assert d.get('cave_check')and d.get('road_check')and d.get('rail_check')
 # Ensure the user has not edited the original terrain during construction.
 target=sc.doc.Objects.FindId(System.Guid(TERRAIN))
 assert int(target.Geometry.DataCRC(0))==int(d['original'].DataCRC(0))or d.get('published')
 road_layer=layer('交通::出生地步道',(226,219,202))
 rail_layer=layer('交通::出生地步道::栏杆',(174,184,184))
 material=next((i for i,m in enumerate(sc.doc.Materials)if not m.IsDeleted and m.Name=='隧道_暖白建筑复合面_PBR_非金属'),None)
 rec=sc.doc.BeginUndoRecord('出生洞穴_喇叭口_人行缓坡与栏杆')
 try:
  assert sc.doc.Objects.Replace(System.Guid(TERRAIN),d['terrain'])
  attrs=d['attributes'].Duplicate();attrs.Name='出生地_上扬尖角_喇叭形初始洞穴_步行'
  attrs.CustomMeshingParameters=display_mesh_parameters(True)
  attrs.SetUserString('spawn_cave_recipe',TAG);attrs.SetUserString('spawn_cave_floor_m','33');attrs.SetUserString('spawn_cave_depth_m','20')
  assert sc.doc.Objects.ModifyAttributes(System.Guid(TERRAIN),attrs,True)
  ids=d.get('ids',{})
  for key,title in [('road','出生地步道_洞口平台_连续缓坡与崖壁承托_NURBS'),('handrails','出生地步道_连续扶手与中横杆_NURBS'),('posts','出生地步道_58根栏杆立柱_NURBS')]:
   geometry=d['parts'][key];attrs=Rhino.DocObjects.ObjectAttributes();attrs.Name=title
   attrs.LayerIndex=road_layer if key=='road'else rail_layer;attrs.WireDensity=-1
   attrs.CustomMeshingParameters=display_mesh_parameters(False)
   if material is not None and key=='road':attrs.MaterialIndex=material;attrs.MaterialSource=Rhino.DocObjects.ObjectMaterialSource.MaterialFromObject
   attrs.SetUserString('recipe',TAG);attrs.SetUserString('spawn_cave_part',key);attrs.SetUserString('surface_role','architecture');attrs.SetUserString('walkable','true'if key=='road'else'false')
   if key in ids:
    assert sc.doc.Objects.Replace(System.Guid(ids[key]),geometry);oid=System.Guid(ids[key]);sc.doc.Objects.ModifyAttributes(oid,attrs,True)
   else:
    oid=sc.doc.Objects.AddBrep(geometry,attrs);assert oid!=System.Guid.Empty
   ids[key]=str(oid)
   add=globals().get('add_object_metadata')
   if add:add(oid,title,'起始洞穴步行设施；真实NURBS实体，无房车和隐藏构造版本。')
  d['ids']=ids;d['published']=True
 finally:sc.doc.EndUndoRecord(rec)
 sc.doc.Objects.UnselectAll();sc.doc.Views.Redraw()
 return {'modified_terrain':TERRAIN,'added':d['ids'],'no_intermediates_in_document':True}

def capture(name,mode='overview',restore=True):
 view=sc.doc.Views.ActiveView;vp=view.ActiveViewport;saved=Rhino.DocObjects.ViewportInfo(vp)
 hidden_for_capture=[]
 try:
  # The 36km water plane makes Rhino move the near clip plane through a small
  # cave. Temporarily suppress only that oversized backdrop for interior QA.
  if mode=='inside':
   for o in objects():
    if not o.IsHidden and sc.doc.Layers[o.Attributes.LayerIndex].FullPath.startswith('环境::水面')and o.Geometry.GetBoundingBox(True).Diagonal.Length>10000.:
     if sc.doc.Objects.Hide(o.Id,True):hidden_for_capture.append(o.Id)
  vp.ChangeToPerspectiveProjection(True,42.)
  if mode=='inside':
   eye=Q+N*15.+G.Vector3d(0,0,1.65);target=Q-N*80.+G.Vector3d(0,0,1.65)
  elif mode=='mouth':
   eye=Q-N*32.+A*9.+G.Vector3d(0,0,8.);target=Q+N*3.+G.Vector3d(0,0,1.5)
  else:
   eye=G.Point3d(795,-205,95);target=G.Point3d(623,-330,34)
  vp.SetCameraLocation(eye,False);vp.SetCameraTarget(target,False);vp.SetCameraDirection(target-eye,False)
  if mode=='overview':vp.ZoomBoundingBox(G.BoundingBox(G.Point3d(571,-382,26),G.Point3d(668,-270,44)))
  info=Rhino.DocObjects.ViewportInfo(vp);info.PerspectiveMinNearOverFar=1.e-8
  assert info.SetFrustumNearFar(.05,5000.)
  vp.SetViewProjection(info,False)
  sc.doc.Objects.UnselectAll();sc.doc.Views.Redraw()
  bitmap=view.CaptureToBitmap(System.Drawing.Size(1600,1000),False,False,False);assert bitmap
  path=OUT+'/'+name+'.png';bitmap.Save(path,System.Drawing.Imaging.ImageFormat.Png);bitmap.Dispose()
  return path
 finally:
  for oid in hidden_for_capture:sc.doc.Objects.Show(oid,True)
  if restore:vp.SetViewProjection(saved,True);sc.doc.Views.Redraw()

def verify():
 d=state();opt=Rhino.FileIO.SerializationOptions();current={str(o.Id):o for o in objects()}
 unchanged=[];changed=[]
 for key,(crc,attrs)in d['before'].items():
  if key==TERRAIN:continue
  o=current.get(key)
  if o is None or int(o.Geometry.DataCRC(0))!=crc or o.Attributes.ToJSON(opt)!=attrs:changed.append(key)
  else:unchanged.append(key)
 assert not changed,str(changed)
 expected=set(d['before'])|set(d['ids'].values());assert set(current)==expected,'Unexpected document objects'
 parts={}
 for key,oid in [('terrain',TERRAIN)]+list(d['ids'].items()):
  b=current[oid].Geometry;assert isinstance(b,G.Brep)
  solid(b);naked=sum(1 for e in b.Edges if e.Valence==G.EdgeAdjacency.Naked)
  assert naked==0
  volume=G.VolumeMassProperties.Compute(b);assert volume and volume.Volume>0
  parts[key]={'id':oid,'valid':b.IsValid,'closed':b.IsSolid,'manifold':b.IsManifold,'outward':b.SolidOrientation==G.BrepSolidOrientation.Outward,'naked_edges':naked,'faces':b.Faces.Count,'volume_m3':volume.Volume,'layer':sc.doc.Layers[current[oid].Attributes.LayerIndex].FullPath}
 # Sample the character's exit corridor, including the cave/apron seam.
 corridor=[]
 for i in range(97):
  dep=-3.5+23.*i/96.
  for across in [-.4,0.,.4]:
   p=Q+N*dep+A*across
   hs=[hit(m,p+G.Vector3d(0,0,1.8),-G.Vector3d.ZAxis)for m in [d['terrain_mesh'],d['road_mesh']]]
   hs=[h for h in hs if h is not None];assert hs
   floor=max(hs,key=lambda v:v.Z);assert abs(floor.Z-33.)<.008
   for h in [.2,1.,1.8,2.]:assert not d['terrain'].IsPointInside(p+G.Vector3d(0,0,h),.001,True),'Blocked character corridor'
   corridor.append({'depth':dep,'across':across,'floor_z':floor.Z})
 # Roof cover across the full flared section, excluding points outside the wall.
 covers=[]
 for dep in [.15,.5,1.,2.,3.,5.,7.,10.,14.,18.,19.5]:
  for i in range(33):
   across=-4.4+8.8*i/32.;p=Q+N*dep+A*across
   if not d['original'].IsPointInside(p+G.Vector3d(0,0,.1),.001,True):continue
   if d['terrain'].IsPointInside(p+G.Vector3d(0,0,.1),.001,True):continue
   ok,cs,ps=G.Intersect.Intersection.CurveBrep(G.LineCurve(p+G.Vector3d(0,0,.1),p+G.Vector3d(0,0,12)),d['terrain'],.001)
   zs=sorted(q.Z for q in ps if q.Z>33.1)
   if len(zs)<2:continue
   covers.append({'depth':dep,'across':across,'cover_m':zs[-1]-zs[0]})
 assert len(covers)>100 and min(r['cover_m']for r in covers)>1.6
 tail=[];last=None;tail_grade=0.
 for i in range(161):
  s=120.+20.*i/160.;p,a,n,inner,outer,z,roll=road_frame(s)
  point=road_point(s,(inner+outer)*.5)
  hs=[hit(m,point+G.Vector3d(0,0,.3),-G.Vector3d.ZAxis)for m in [d['terrain_mesh'],d['road_mesh']]]
  hs=[h for h in hs if h is not None];assert hs
  actual=max(hs,key=lambda v:v.Z)
  if last:
   run=math.sqrt((actual.X-last.X)**2+(actual.Y-last.Y)**2);tail_grade=max(tail_grade,abs(actual.Z-last.Z)/run)
  last=actual;tail.append({'station':s,'ground_z':actual.Z})
 assert tail_grade<.065,tail_grade
 report={'cad_path':sc.doc.Path,'object_count':len(current),'unrelated_objects_unchanged':len(unchanged),'changed_unrelated':changed,'parts':parts,'cave':d['cave_check'],'road':d['road_check'],'rails':d['rail_check'],'character_exit_samples':len(corridor),'character_height_tested_m':2.,'full_section_roof_samples':len(covers),'minimum_full_section_roof_cover_m':min(r['cover_m']for r in covers),'roof_return_checks':len(tail),'roof_return_max_grade':tail_grade,'no_hidden_intermediate_objects':True,'game_export_updated':False}
 d['verification']=report;write('model_verification.json',report)
 return {k:v for k,v in report.items()if k not in ['cave','road','rails','parts']}

def save():
 d=state();assert d.get('verification')
 options=Rhino.FileIO.FileWriteOptions();options.SuppressDialogBoxes=True
 assert sc.doc.WriteFile(sc.doc.Path,options)
 loaded=Rhino.FileIO.File3dm.Read(sc.doc.Path);assert loaded
 for key in [TERRAIN]+list(d['ids'].values()):
  live=sc.doc.Objects.FindId(System.Guid(key));saved=loaded.Objects.FindId(System.Guid(key))
  assert saved and saved.Geometry.DataCRC(0)==live.Geometry.DataCRC(0)
 sc.doc.Modified=False
 report={'saved':True,'path':sc.doc.Path,'readback_geometry_verified':True,'saved_objects':len(list(loaded.Objects))}
 d['saved']=report;write('model_saved.json',report);return report
