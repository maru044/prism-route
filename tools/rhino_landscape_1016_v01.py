# -*- coding: utf-8 -*-
"""1016 user-curve terrain: exact crest/ground guides, rolled NURBS grades.

No tunnel cutters, no passage subtraction. Original user curves are immutable.
"""
from __future__ import division, unicode_literals
import Rhino,scriptcontext as sc,System,math,os,json,io
from System.Drawing import Color
from System.Drawing.Imaging import ImageFormat
G=Rhino.Geometry
ROOT=os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT=os.path.join(ROOT,'docs','concepts','reference_1016_landscape')
TAG='prism_landscape_1016_v01'
LAYER='1016_参考曲线约束地形_v01'
IDS=['5bba916a-fb44-4963-a5e5-1065aac65880','d6b53d48-4639-4435-8509-0f47a510fbc6',
     '80b01a50-50f7-4da2-93f3-ac4029227b43','b9ce2f01-488b-4ff2-b1bc-68d162be4b4d',
     'dabacf09-9070-4dd2-8c5f-8b3c3c9f99ba','0749446b-9853-410f-b266-0394d730f140']

def obj(oid):
 o=sc.doc.Objects.FindId(System.Guid(oid))
 if o is None:raise RuntimeError('Missing source '+oid)
 return o
def xyz(p):return [float(p.X),float(p.Y),float(p.Z)]
def write(name,value):
 if not os.path.isdir(OUT):os.makedirs(OUT)
 with io.open(os.path.join(OUT,name),'w',encoding='utf-8') as f:f.write(json.dumps(value,ensure_ascii=False,indent=2,default=str))
def panel(guide,rows):
 nu=len(rows);nv=len(rows[0]);s=G.NurbsSurface.Create(3,False,guide.Order,4,nu,nv)
 for i,k in enumerate(guide.Knots):s.KnotsU[i]=k
 for j,k in enumerate([0,0,0]+list(range(1,nv-3))+[nv-3,nv-3,nv-3]):s.KnotsV[j]=k
 for i in range(nu):
  for j in range(nv):s.Points.SetPoint(i,j,rows[i][j])
 if not s.IsValid:raise RuntimeError('Invalid surface panel')
 return s
def curve_from_control(guide,points):
 c=guide.DuplicateCurve().ToNurbsCurve()
 for i,p in enumerate(points):c.Points.SetPoint(i,p)
 return c
def ruled(a,b):
 parts=G.Brep.CreateFromLoft([a,b],G.Point3d.Unset,G.Point3d.Unset,G.LoftType.Straight,False)
 if not parts:raise RuntimeError('Boundary return failed')
 return parts[0]
def refine_guides(u,f):
 knots=sorted(set(float(k)for k in u.Knots))
 for a,b in zip(knots,knots[1:]):
  if b-a>1e-7:
   u.Knots.InsertKnot((a+b)*.5)
   if f:f.Knots.InsertKnot((a+b)*.5)
 return u,f
def make_land(name,crest_id,foot_id=None,width=75):
 u=obj(crest_id).Geometry.DuplicateCurve().ToNurbsCurve()
 f=obj(foot_id).Geometry.DuplicateCurve().ToNurbsCurve()if foot_id else None
 u,f=refine_guides(u,f)
 plan=u.DuplicateCurve();plan.Transform(G.Transform.PlanarProjection(G.Plane.WorldXY))
 maxheight=max(u.PointAt(u.Domain.ParameterAt(i/100.)).Z for i in range(101))
 neighbors=[plan.PointAt(plan.Domain.ParameterAt(i/160.))for i in range(161)]
 front=[];back=[];floor=[];toe=[];metrics=[]
 for i in range(u.Points.Count):
  t=u.GrevilleParameter(i);p=u.Points[i].Location
  tangent=plan.TangentAt(t);n=G.Vector3d(-tangent.Y,tangent.X,0);n.Unitize()
  h=max(0,u.PointAt(t).Z);fraction=(t-u.Domain.T0)/u.Domain.Length
  curvature=plan.CurvatureAt(t).Length
  radius=1/curvature if curvature>1e-7 else 10000
  desired=width*(.20+.80*math.sqrt(h/max(maxheight,.01)))
  # Side-return widths adapt to the actual curve's tight turns; the crest
  # itself and the supplied ground curve are never rebuilt or displaced.
  desired=min(desired,radius*.82)
  # Only truly distant returning strands constrain width. Counting nearby
  # samples on the same arm would incorrectly reduce every grade to a thin band.
  near=[plan.PointAt(t).DistanceTo(q)for k,q in enumerate(neighbors)if abs(k/160.-fraction)>.30]if plan.GetLength()>800 else []
  if near:desired=min(desired,min(near)*.46)
  q=f.Points[i].Location if f else G.Point3d(p.X-n.X*(8+10*h/max(maxheight,.1)),p.Y-n.Y*(8+10*h/max(maxheight,.1)),0)
  q=G.Point3d(q.X,q.Y,0)
  outward=G.Vector3d.Multiply(q-p,n)
  d=max(5,desired,outward+9)
  if h<.01:d=3
  b=G.Point3d(p.X+n.X*d,p.Y+n.Y*d,0)
  r=min(2.6,h*.14,d*.16);rb=min(2.5,h*.1,d*.14)
  height=max(0,p.Z)
  z=G.Vector3d.ZAxis
  # Shared crest and collinear transverse derivatives: wall rolls into grade.
  front.append([q,q-n*rb,q+(p-q)*.28,q+(p-q)*.66,
                p-n*(2*r)-z*(height*.04),p-n*r,p])
  back.append([p,p+n*r,p+n*(2*r)-z*(height*.04),
               G.Point3d(p.X+(b.X-p.X)*.40,p.Y+(b.Y-p.Y)*.40,height*.68),
               G.Point3d(p.X+(b.X-p.X)*.75,p.Y+(b.Y-p.Y)*.75,height*.19),b-n*rb,b])
  floor.append(q);toe.append(b)
  metrics.append({'u_fraction':fraction,'crest_z':h,'return_width_m':d,'plan_curvature_radius_m':radius})
 wall=panel(u,front);grade=panel(u,back)
 foot=curve_from_control(u,floor);end=curve_from_control(u,toe)
 down_a=foot.DuplicateCurve();down_b=end.DuplicateCurve()
 down_a.Transform(G.Transform.Translation(0,0,-3));down_b.Transform(G.Transform.Translation(0,0,-3))
 pieces=[wall.ToBrep(),grade.ToBrep(),ruled(foot,down_a),ruled(down_a,down_b),ruled(down_b,end)]
 joined=G.Brep.JoinBreps(pieces,.005)
 if not joined or len(joined)!=1:raise RuntimeError(name+' panels failed to join')
 solid=joined[0].CapPlanarHoles(.005)
 if not solid or not solid.IsValid or not solid.IsSolid:
  naked=sum(e.Valence==G.EdgeAdjacency.Naked for e in joined[0].Edges)
  raise RuntimeError(name+' not closed: naked edges '+str(naked))
 if solid.SolidOrientation==G.BrepSolidOrientation.Inward:solid.Flip()
 return {'name':name,'geometry':solid,'wall':wall,'grade':grade,'guide':u,'foot':foot,
         'crest_source':crest_id,'foot_source':foot_id,'sections':metrics}

def prepare():
 previous=sc.sticky.get(TAG)
 bodies=[make_land('01_S形回折主地形',IDS[0],IDS[3],105),
         make_land('02_中层弧线下降地形',IDS[2],IDS[1],110),
         make_land('03_中部下降主脊',IDS[4],None,85),
         make_land('04_中部横向连接主脊',IDS[5],None,90)]
 state={'recipe':TAG,'objects':previous['state']['objects']if previous else [],
        'source_crc':previous['state']['source_crc']if previous else {str(o.Id):int(o.Geometry.DataCRC(0))for o in sc.doc.Objects},
        'reference_crc':{i:int(obj(i).Geometry.DataCRC(0))for i in IDS},
        'no_tunnels':True,'tunnel_cutters':0,'boolean_passage_subtractions':0,
        'design':'Exact user crest/ground guides; rolled cubic wall and continuous sloping land return, buried solid base. No invented leaf footprints.',
        'body_report':[{'name':b['name'],'crest_source':b['crest_source'],'ground_source':b['foot_source'],'valid':b['geometry'].IsValid,'solid':b['geometry'].IsSolid,'bounds':[xyz(b['geometry'].GetBoundingBox(True).Min),xyz(b['geometry'].GetBoundingBox(True).Max)]}for b in bodies]}
 sc.sticky[TAG]={'bodies':bodies,'state':state}
 write('prepare_report.json',state);print(json.dumps(state['body_report'],ensure_ascii=False))

def layer(child,visible=True):
 root=sc.doc.Layers.FindByFullPath(LAYER,-1)
 if root<0:
  l=Rhino.DocObjects.Layer();l.Name=LAYER;root=sc.doc.Layers.Add(l)
 index=sc.doc.Layers.FindByFullPath(LAYER+'::'+child,-1)
 if index<0:
  l=Rhino.DocObjects.Layer();l.Name=child;l.ParentLayerId=sc.doc.Layers[root].Id;l.Color=Color.FromArgb(239,234,223);l.IsVisible=visible;index=sc.doc.Layers.Add(l)
 return index
def publish():
 data=sc.sticky[TAG];state=data['state'];doc=sc.doc
 if state['objects']:raise RuntimeError('Already published')
 for oid,crc in state['reference_crc'].items():
  if int(obj(oid).Geometry.DataCRC(0))!=crc:raise RuntimeError('Reference changed')
 undo=doc.BeginUndoRecord('1016 参考曲线约束地形 无新增隧道')
 try:
  m=Rhino.DocObjects.Material();m.Name='1016_暖白建筑表皮';m.DiffuseColor=Color.FromArgb(239,234,223);m.Shine=28;m.Reflectivity=.045;mi=doc.Materials.Add(m)
  mp=G.MeshingParameters();mp.Tolerance=.02;mp.RelativeTolerance=0;mp.MaximumEdgeLength=3;mp.RefineGrid=True;mp.JaggedSeams=False;mp.GridAngle=math.radians(6)
  for b in data['bodies']:
   a=Rhino.DocObjects.ObjectAttributes();a.Name=b['name'];a.LayerIndex=layer('01_曲线约束连续实体');a.MaterialIndex=mi;a.MaterialSource=Rhino.DocObjects.ObjectMaterialSource.MaterialFromObject;a.CustomMeshingParameters=mp
   a.SetUserString('recipe',TAG);a.SetUserString('crest_reference',b['crest_source']);a.SetUserString('no_tunnels','true')
   oid=doc.Objects.AddBrep(b['geometry'],a);state['objects'].append({'id':str(oid),'name':a.Name})
 finally:doc.EndUndoRecord(undo);doc.Views.Redraw()
 write('generation_state.json',state);print(json.dumps({'published':True,'bodies':len(state['objects']),'layer':LAYER,'no_tunnels':True},ensure_ascii=False))

def refine():
 prepare();data=sc.sticky[TAG];state=data['state'];doc=sc.doc
 undo=doc.BeginUndoRecord('1016 地形坡面展开')
 try:
  for row in state['objects']:
   b=next(b for b in data['bodies']if b['name']==row['name'])
   if not doc.Objects.Replace(System.Guid(row['id']),b['geometry']):raise RuntimeError('Replace failed')
 finally:doc.EndUndoRecord(undo);doc.Views.Redraw()
 write('generation_state.json',state)

def capture(name,camera=None,target=None,clean=True):
 v=sc.doc.Views.ActiveView;vp=v.ActiveViewport;vp.PushViewProjection();layers=[];mode=vp.DisplayMode
 try:
  # A clean shaded view judges geometry without the user's per-object wires.
  shaded=next((m for m in Rhino.Display.DisplayModeDescription.GetDisplayModes()if m.EnglishName=='Rendered'),None)
  if shaded:vp.DisplayMode=shaded
  if clean:
   for l in sc.doc.Layers:
    if l.FullPath in ['辅助线','标注','边线','参考边框','中层道路中线','上层道路中线']and l.IsVisible:
     layers.append(l.Id);l.IsVisible=False;l.CommitChanges()
  if camera:
   vp.SetCameraLocations(G.Point3d(*target),G.Point3d(*camera));vp.CameraUp=G.Vector3d.ZAxis;vp.Camera35mmLensLength=42
  sc.doc.Objects.UnselectAll();doc=sc.doc;doc.Views.Redraw()
  vc=Rhino.Display.ViewCapture();vc.Width=1800;vc.Height=1200;vc.DrawGrid=False;vc.DrawAxes=False
  bmp=vc.CaptureToBitmap(v);bmp.Save(os.path.join(OUT,name),ImageFormat.Png);bmp.Dispose()
 finally:
  for lid in layers:
   l=sc.doc.Layers.FindId(lid);l.IsVisible=True;l.CommitChanges()
  vp.DisplayMode=mode;vp.PopViewProjection();sc.doc.Views.Redraw()
 print(os.path.join(OUT,name))
