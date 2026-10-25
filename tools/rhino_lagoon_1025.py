# -*- coding: utf-8 -*-
"""Native lagoon bathymetry and the two exterior exits; no in-document backups."""
from __future__ import unicode_literals, division
import Rhino, scriptcontext as sc, System, math, os, io, json
from System.Drawing import Color
G=Rhino.Geometry
TAG='lagoon_1025_final'
ROOT='D:/Prism Route/prism-route'
OUT=ROOT+'/docs/concepts/lagoon_1025'
SOUTH_WATER='79d2ce03-2e53-4c69-9a13-a18da1838f89'
SOUTH_BED='c5ae764e-2995-42f9-96a6-f0bf6c7420a6'
NORTH_WATER='3861e9e6-1993-4c9a-9445-ddd4e3b687a2'
NORTH_SAND=['0ca3494d-c2cb-4a06-bd27-eef387c1a3a8','a4ba5835-fa34-4c44-871d-f1ce086cd6ce',
 'a9cb81c3-c794-46d8-84e7-2b065b263dd1','8009b96a-6063-46bf-bc44-47c8d25ba1e6',
 '7c8b47c4-6535-4419-8add-0b72fc0738f4','c68be52a-34e5-4c4d-97ec-a4c3e96006a6']
BRIDGES=set(['a4c9a543-2d8a-401c-bebe-b21f45031605','0808d32c-6ebc-4105-9258-a0f755ac2752'])

def obj(key):return sc.doc.Objects.FindId(System.Guid(key))
def state():return sc.sticky[TAG]
def xyz(p):return [float(p.X),float(p.Y),float(p.Z)]
def smooth(t):
 t=max(0.,min(1.,t));return t*t*t*(10.-15.*t+6.*t*t)
def objects():
 e=Rhino.DocObjects.ObjectEnumeratorSettings();e.NormalObjects=True;e.HiddenObjects=True;e.LockedObjects=True
 return list(sc.doc.Objects.GetObjectList(e))
def write(name,data):
 if not os.path.isdir(OUT):os.makedirs(OUT)
 with io.open(OUT+'/'+name,'w',encoding='utf-8')as f:f.write(json.dumps(data,ensure_ascii=False,indent=2))
def brep(g):return g.ToBrep()if isinstance(g,G.Extrusion)else g.DuplicateBrep()
def outer(g):return [l.To3dCurve()for l in g.Loops if l.LoopType==G.BrepLoopType.Outer][0]
def unit(v):v=G.Vector3d(v);assert v.Unitize();return v

def prepare():
 assert sc.doc.Path.replace('\\','/').replace('//','/').lower()=='d:/prism route/map/map_current.3dm'
 assert TAG not in sc.sticky,'Reuse the existing staged session'
 opts=Rhino.FileIO.SerializationOptions()
 d={'before':{str(o.Id):(int(o.Geometry.DataCRC(0)),o.Attributes.ToJSON(opts))for o in objects()},
    'parts':{},'replace':{},'delete':[],'added':[],'modified':[], 'view':Rhino.DocObjects.ViewportInfo(sc.doc.Views.ActiveView.ActiveViewport)}
 sc.sticky[TAG]=d
 # Save the live document to an external file, without changing its working path.
 backup=ROOT+'/.lagoon_model_build/map_current_before_1025.3dm'
 if not os.path.isdir(os.path.dirname(backup)):os.makedirs(os.path.dirname(backup))
 options=Rhino.FileIO.FileWriteOptions();options.UpdateDocumentPath=False;options.SuppressDialogBoxes=True
 assert sc.doc.WriteFile(backup,options),'External backup failed'
 d['backup']=backup
 d['originals']={k:(obj(k).Geometry.Duplicate(),obj(k).Attributes.Duplicate())for k in [SOUTH_WATER,SOUTH_BED,NORTH_WATER]+NORTH_SAND}
 return {'objects':len(d['before']),'external_backup':backup,'in_document_backups':0}

def ground(x,y):
 """Exact vertical intersections of authored land, ignoring the bridge overhead."""
 # Pick the low exterior storey, not the raised T1 roof over the portal.
 zs=[];line=G.LineCurve(G.Point3d(x,y,15),G.Point3d(x,y,-10))
 for o in objects():
  key=str(o.Id);layer=sc.doc.Layers[o.Attributes.LayerIndex].FullPath
  if key in BRIDGES or not layer.startswith('地形::') or o.IsHidden:continue
  g=o.Geometry;bb=g.GetBoundingBox(True)
  if x<bb.Min.X or x>bb.Max.X or y<bb.Min.Y or y>bb.Max.Y:continue
  if isinstance(g,G.Brep):
   ok,curves,points=G.Intersect.Intersection.CurveBrep(line,g,.0005)
   if ok:
    zs.extend(p.Z for p in points)
    for c in curves:zs.extend([c.PointAtStart.Z,c.PointAtEnd.Z])
  elif isinstance(g,G.Mesh):
   t=G.Intersect.Intersection.MeshRay(g,G.Ray3d(G.Point3d(x,y,15),-G.Vector3d.ZAxis))
   if t>=0:zs.append(15.-t)
 assert zs,'No ground at '+str((x,y))
 return max(zs)

def route(which,t):
 t=max(0.,min(1.,t))
 if which=='portal':
  # The opening under the existing artistic bridge reaches the low exterior land.
  return G.Point3d(1070.+3.*math.sin(math.pi*t)**2,470.+230.*t,0)
 return G.Point3d(600.-9.*math.sin(math.pi*t)**2,500.+240.*t,0)

def route_frame(which,t):
 p=route(which,t);a=unit(route(which,min(1.,t+.0001))-route(which,max(0.,t-.0001)))
 return p,a,G.Vector3d(-a.Y,a.X,0)

def top_height(which,t,lateral=0.):
 d=state()['exits'][which];p,a,n=route_frame(which,t)
 z=-.69+(d['end_z']+.69)*smooth(t)
 # Match the exact landing crossfall, and bury only the final centimetres.
 z+=d['crossfall']*lateral*smooth((t-.72)/.28)
 return z

def loft_solid(which,upward=False):
 curves=[];d=state()['exits'][which]
 for i in range(49):
  t=i/48.;p,a,n=route_frame(which,t)
  width=d['width']*(1.+.22*(1.-smooth(t/.16))+.18*smooth((t-.82)/.18))
  if upward:width-=.10
  left=top_height(which,t,-width/2.);right=top_height(which,t,width/2.)
  if upward:
   z0=left-1.8;z1=right-1.8
   upper_left=upper_right=160.
  else:
   # A filled bank reaches below the lake bed along its whole length; a slab
   # of constant thickness would float above the water halfway up the ramp.
   z0=z1=-2.0;upper_left=left;upper_right=right
  pts=[]
  for side,z in [(-1,z0),(1,z1),(1,upper_right),(-1,upper_left),(-1,z0)]:
   base_widen=4.0 if not upward and z==-2.0 else 0.0
   q=p+n*((width*.5+base_widen)*side);q.Z=z;pts.append(q)
  curves.append(G.PolylineCurve(pts))
 out=G.Brep.CreateFromLoft(curves,G.Point3d.Unset,G.Point3d.Unset,G.LoftType.Normal,False)
 assert out and len(out)==1
 b=out[0].CapPlanarHoles(.001);assert b and b.IsValid and b.IsSolid
 if b.SolidOrientation==G.BrepSolidOrientation.Inward:b.Flip()
 return b

def build_exits():
 d=state();d['exits']={}
 for name,width in [('portal',12.),('ramp',14.)]:
  end,a,n=route_frame(name,1.)
  z=ground(end.X,end.Y);zl=ground((end-n*width/2.).X,(end-n*width/2.).Y);zr=ground((end+n*width/2.).X,(end+n*width/2.).Y)
  d['exits'][name]={'end_z':z-.015,'crossfall':(zr-zl)/width,'width':width,'start':xyz(route(name,0)),'end':xyz(end)}
  d['parts'][name]=loft_solid(name)
  samples=[]
  for i in range(501):
   t=i/500.;p=route(name,t);p.Z=top_height(name,t);samples.append(p)
  grades=[abs(b.Z-a.Z)/max(.0001,math.hypot(b.X-a.X,b.Y-a.Y))for a,b in zip(samples,samples[1:])]
  d['exits'][name]['max_grade']=max(grades)
  d['exits'][name]['length_m']=sum(a.DistanceTo(b)for a,b in zip(samples,samples[1:]))
  assert max(grades)<1./12.,'Exit ramp too steep'
 d['cutter']=loft_solid('ramp',True)
 d['portal_cutter']=loft_solid('portal',True)
 return d['exits']

def part_inside(part,cutter):
 """Split produces either outside pieces or the parcel within the excavation."""
 votes=[]
 for f in part.Faces:
  amp=G.AreaMassProperties.Compute(f)
  if not amp:continue
  p=amp.Centroid;ok,u,v=f.ClosestPoint(p)
  if ok:p=f.PointAt(u,v)
  votes.append((amp.Area,cutter.IsPointInside(p,.002,False)))
 total=sum(a for a,b in votes)
 return total>0 and sum(a for a,b in votes if b)/total>.80

def excavate_one(c,only_id=None):
 d=state();cb=c.GetBoundingBox(True);rows=[]
 for o in objects():
  key=str(o.Id);layer=sc.doc.Layers[o.Attributes.LayerIndex].FullPath
  if only_id and key!=only_id:continue
  if key in BRIDGES or not layer.startswith('地形::') or not isinstance(o.Geometry,G.Brep):continue
  b=d['replace'].get(key,o.Geometry);bb=b.GetBoundingBox(True)
  if bb.Max.X<cb.Min.X or bb.Min.X>cb.Max.X or bb.Max.Y<cb.Min.Y or bb.Min.Y>cb.Max.Y:continue
  if b.IsSolid:
   pieces=G.Brep.CreateBooleanDifference(b,c,.002)
   if not pieces:continue
   volume=G.VolumeMassProperties.Compute(b);new_volume=sum(G.VolumeMassProperties.Compute(x).Volume for x in pieces)
   if abs(volume.Volume-new_volume)<.001:continue
  else:
   split=b.Split(c,.002)
   if not split or len(split)<2:continue
   pieces=[x for x in split if not part_inside(x,c)]
   if len(pieces)==len(split):continue
   assert pieces,'Excavation removed a complete terrain object'
  combined=G.Brep()
  for part in pieces:combined.Append(part)
  combined.Compact();assert combined.IsValid
  d['replace'][key]=combined
  rows.append({'id':key,'name':o.Attributes.Name,'before_solid':b.IsSolid,'after_solid':combined.IsSolid,'before_faces':b.Faces.Count,'after_faces':combined.Faces.Count})
 return rows

def excavate():
 d=state();rows=excavate_one(d['cutter'])
 assert rows,'Ramp must open the existing closed end'
 # Only the low hill bank may be trimmed under the existing opening. Never
 # cut a bridge footing merely because its source object lives on a land layer.
 rows+=excavate_one(d['portal_cutter'],'9ed1bc59-e9fa-4024-8095-564d74c4c87c')
 d['excavation']=rows
 return rows

def depth(p,boundary,mounds):
 ok,t=boundary.ClosestPoint(p);edge=p.DistanceTo(boundary.PointAt(t))
 z=-.62+.045*math.sin(p.X*.009)*math.cos(p.Y*.007)
 z=max(z,-.18-.46*smooth(edge/38.))
 for c in mounds:
  inside=c.Contains(p,G.Plane.WorldXY,.001)!=G.PointContainment.Outside
  ok,t=c.ClosestPoint(p);distance=p.DistanceTo(c.PointAt(t))
  weight=1. if inside else 1.-smooth(distance/30.)
  z=z*(1.-weight)+(-.23+.018*math.sin(p.X*.02))*weight
 return z

def make_bed(water,mounds):
 curve=outer(water);curve.Transform(G.Transform.PlanarProjection(G.Plane.WorldXY))
 b=G.Brep.CreatePlanarBreps(curve,.001)[0]
 base=b.Faces[0].UnderlyingSurface().ToNurbsSurface()
 bb=b.GetBoundingBox(True);nu=max(20,int(bb.Diagonal.X/20.)+4);nv=max(20,int(bb.Diagonal.Y/20.)+4)
 s=base.Rebuild(3,3,nu,nv)
 for i in [0,1]:s.SetDomain(i,base.Domain(i))
 for u in range(s.Points.CountU):
  for v in range(s.Points.CountV):
   p=s.Points.GetControlPoint(u,v).Location;p.Z=0.
   s.Points.SetPoint(u,v,G.Point3d(p.X,p.Y,depth(p,curve,mounds)))
 idx=b.Surfaces.Count;b.Append(s.ToBrep());assert b.Faces[0].ChangeSurface(idx)
 b.Faces.RemoveAt(1);assert b.Faces[0].RebuildEdges(.001,True,True);b.Compact();assert b.IsValid
 if b.Faces[0].NormalAt(b.Faces[0].Domain(0).Mid,b.Faces[0].Domain(1).Mid).Z<0:b.Flip()
 # A matching NURBS shore skirt reaches Z=0, closing the old wall-foot gap.
 low=outer(b);high=low.DuplicateCurve();high.Transform(G.Transform.PlanarProjection(G.Plane.WorldXY))
 rims=G.Brep.CreateFromLoft([low,high],G.Point3d.Unset,G.Point3d.Unset,G.LoftType.Normal,False)
 assert rims and len(rims)==1
 joined=G.Brep.JoinBreps([b,rims[0]],.002);assert joined and len(joined)==1 and joined[0].IsValid
 return joined[0],{'controls':[nu,nv],'depth_bbox':[b.GetBoundingBox(True).Min.Z,b.GetBoundingBox(True).Max.Z]}

def build_beds():
 d=state();south,sm=make_bed(obj(SOUTH_WATER).Geometry,[])
 mounds=[outer(obj(k).Geometry)for k in NORTH_SAND]
 north,nm=make_bed(obj(NORTH_WATER).Geometry,mounds)
 d['parts']['south_bed']=south;d['parts']['north_bed']=north
 water=obj(SOUTH_WATER).Geometry.DuplicateBrep();water.Transform(G.Transform.Translation(0,0,-.18))
 d['replace'][SOUTH_WATER]=water
 water=G.Brep.CreatePlanarBreps(outer(obj(NORTH_WATER).Geometry),.001)
 assert water and len(water)==1 and water[0].Loops.Count==1
 d['replace'][NORTH_WATER]=water[0];d['replace'][SOUTH_BED]=south
 d['delete']=NORTH_SAND[:]
 d['beds']={'south':sm,'north':nm,'north_filled_holes':6,'water_z':0.}
 return d['beds']

def verify_routes():
 d=state();sources=[]
 for o in objects():
  key=str(o.Id);path=sc.doc.Layers[o.Attributes.LayerIndex].FullPath
  if o.IsHidden or path.startswith(('环境::','参考::')):continue
  g=d['replace'].get(key,o.Geometry)
  if isinstance(g,G.Extrusion):g=g.ToBrep()
  if not isinstance(g,(G.Brep,G.Mesh)):continue
  bb=g.GetBoundingBox(True)
  if bb.Min.X>960 or bb.Max.X<575 or bb.Min.Y>755 or bb.Max.Y<430:continue
  sources.append((key,g,bb))
 errors=[];clearances={}
 for name in ['portal','ramp']:
  min_ceiling=1000.
  for i in range(61):
   t=i/60.;p,a,n=route_frame(name,t)
   for side in [-.35,0.,.35]:
    q=p+n*(d['exits'][name]['width']*side);z=top_height(name,t,d['exits'][name]['width']*side)
    q.Z=z+1.0
    line=G.LineCurve(G.Point3d(q.X,q.Y,z+.10),G.Point3d(q.X,q.Y,z+2.30))
    for key,g,bb in sources:
     if q.X<bb.Min.X or q.X>bb.Max.X or q.Y<bb.Min.Y or q.Y>bb.Max.Y:continue
     if isinstance(g,G.Brep):
      if g.IsSolid and g.IsPointInside(q,.001,True):errors.append([name,round(t,3),key,'inside'])
      if bb.Min.Z<=z+2.3 and bb.Max.Z>=z+.1:
       ok,cs,ps=G.Intersect.Intersection.CurveBrep(line,g,.001)
       if ok and(len(cs)or len(ps)):errors.append([name,round(t,3),key,'blocked'])
     else:
      hit=G.Intersect.Intersection.MeshLine(g,line.Line)
      if isinstance(hit,tuple):hit=hit[0]
      if hit:errors.append([name,round(t,3),key,'mesh_blocked'])
   # Centre-line headroom, including the actual bridge overhead.
   z=top_height(name,t);start=G.Point3d(p.X,p.Y,z+.10)
   ray_line=G.LineCurve(start,G.Point3d(p.X,p.Y,100.))
   for key,g,bb in sources:
    if not isinstance(g,G.Brep)or p.X<bb.Min.X or p.X>bb.Max.X or p.Y<bb.Min.Y or p.Y>bb.Max.Y:continue
    ok,cs,ps=G.Intersect.Intersection.CurveBrep(ray_line,g,.001)
    if ok:
     for q in ps:
      if q.Z>z+.10:min_ceiling=min(min_ceiling,q.Z-z)
  clearances[name]=None if min_ceiling==1000. else min_ceiling
  # Continuous paths catch a thin transverse wall between vertical samples.
  for side in [-.35,0.,.35]:
   points=[]
   for i in range(241):
    t=i/240.;p,a,n=route_frame(name,t);offset=d['exits'][name]['width']*side
    q=p+n*offset;q.Z=top_height(name,t,offset)+1.;points.append(q)
   path=G.PolylineCurve(points)
   for key,g,bb in sources:
    if not isinstance(g,G.Brep):continue
    ok,cs,ps=G.Intersect.Intersection.CurveBrep(path,g,.001)
    if ok and(len(cs)or len(ps)):errors.append([name,side,key,'continuous_path_blocked'])
 d['route_check']={'blockers':errors,'centerline_min_overhead_m':clearances,'samples_per_exit':183,'continuous_lanes_per_exit':3,'tested_height_m':2.3}
 return d['route_check']

def layer(path,color):
 parent=System.Guid.Empty
 for name in path.split('::'):
  full=name if parent==System.Guid.Empty else sc.doc.Layers.FindId(parent).FullPath+'::'+name
  idx=sc.doc.Layers.FindByFullPath(full,-1)
  if idx<0:
   l=Rhino.DocObjects.Layer();l.Name=name;l.ParentLayerId=parent;l.Color=color;idx=sc.doc.Layers.Add(l)
  parent=sc.doc.Layers[idx].Id
 return idx

def attributes(name,path,color):
 a=Rhino.DocObjects.ObjectAttributes();a.Name=name;a.LayerIndex=layer(path,color)
 a.ColorSource=Rhino.DocObjects.ObjectColorSource.ColorFromObject;a.ObjectColor=color
 a.SetUserString('recipe',TAG);a.SetUserString('final_model','true')
 return a

def publish(meta):
 d=state();assert not d.get('published',False)
 assert 'beds'in d and 'excavation'in d and not d['route_check']['blockers']
 serial=sc.doc.BeginUndoRecord('泻湖湖底与通向外部的两个出口')
 sc.doc.Views.RedrawEnabled=False
 try:
  for key,g in d['replace'].items():
   assert sc.doc.Objects.Replace(System.Guid(key),g);d['modified'].append(key)
  for key in d['delete']:assert sc.doc.Objects.Delete(System.Guid(key),True)
  for key,name in [('portal','南泻湖出口一_桥下洞口_连续接地与外部低地'),('ramp','南泻湖出口二_封闭端开口_连续缓坡接外部地形')]:
   a=attributes(name,'交通::泻湖出口',Color.FromArgb(231,226,207))
   id=sc.doc.Objects.AddBrep(d['parts'][key],a);assert id!=System.Guid.Empty
   d['added'].append(str(id));d['exits'][key]['id']=str(id);meta(id,name,'Final NURBS exterior exit, not the waterfront steps.')
  a=attributes('北泻湖_连续水下湖底_六处水下浅滩_NURBS','环境::沙滩::水下湖底',Color.FromArgb(222,205,155))
  id=sc.doc.Objects.AddBrep(d['parts']['north_bed'],a);assert id!=System.Guid.Empty
  d['added'].append(str(id));meta(id,a.Name,'Final continuous lake bed beneath the filled water surface.')
  for key,name in [(SOUTH_BED,'南泻湖_连续起伏水下湖底_NURBS'),(SOUTH_WATER,'南泻湖_统一零米水位'),(NORTH_WATER,'北泻湖_完整水面_覆盖六处浅滩')]:
   o=obj(key);a=o.Attributes.Duplicate();a.Name=name
   if key==SOUTH_BED:a.LayerIndex=layer('环境::沙滩::水下湖底',Color.FromArgb(222,205,155))
   a.SetUserString('recipe',TAG);assert sc.doc.Objects.ModifyAttributes(o.Id,a,True)
  d['published']=True
 finally:
  sc.doc.Views.RedrawEnabled=True;sc.doc.EndUndoRecord(serial);sc.doc.Views.Redraw()
 return {'added':d['added'],'modified':d['modified'],'removed_old_sand_faces':d['delete'],'hidden_backups':0}

def verify():
 d=state();opts=Rhino.FileIO.SerializationOptions();allowed=set(d['modified']+d['delete']);unexpected=[]
 for o in objects():
  key=str(o.Id)
  if key in d['before'] and key not in allowed:
   if (int(o.Geometry.DataCRC(0)),o.Attributes.ToJSON(opts))!=d['before'][key]:unexpected.append(key)
 assert not unexpected,'Unrelated geometry/attributes changed: '+str(unexpected)
 for key in d['added']+d['modified']:assert obj(key) and obj(key).Geometry.IsValid
 for key in d['delete']:assert not obj(key)
 for key in [SOUTH_WATER,NORTH_WATER]:
  bb=obj(key).Geometry.GetBoundingBox(True);assert abs(bb.Min.Z)<.00001 and abs(bb.Max.Z)<.00001
 assert obj(NORTH_WATER).Geometry.Loops.Count==1
 report={'valid':True,'exits':d['exits'],'route_check':d['route_check'],'excavation':d['excavation'],'beds':d['beds'],
  'added':d['added'],'modified':d['modified'],'removed':d['delete'],'unrelated_changes':unexpected,'in_document_backups':0,'external_backup':d['backup']}
 write('model_report.json',report)
 return report

def save():
 options=Rhino.FileIO.FileWriteOptions();options.UpdateDocumentPath=True;options.SuppressDialogBoxes=True
 assert sc.doc.WriteFile(sc.doc.Path,options)
 return {'saved':sc.doc.Path}
