# -*- coding: utf-8 -*-
"""Measured, in-memory church concept. Never adds objects or saves the Rhino map."""
import Rhino
import scriptcontext as sc
import System.Drawing as Drawing
import System.Drawing.Imaging as Imaging
import json, math, os

OUT = r'D:\Prism Route\prism-route\docs\concepts\church_1104'
CX, CY, FLOOR = 1620., 1050., 26.6
IVORY=Drawing.Color.FromArgb(222,216,198)
METAL=Drawing.Color.FromArgb(80,84,83)
GLASS=Drawing.Color.FromArgb(92,137,141)
BASE=Drawing.Color.FromArgb(171,163,144)

def p(x,y,z):return Rhino.Geometry.Point3d(CX+x,CY+y,z)
def box(x0,x1,y0,y1,z0,z1):
    return Rhino.Geometry.Box(Rhino.Geometry.Plane.WorldXY,Rhino.Geometry.Interval(CX+x0,CX+x1),Rhino.Geometry.Interval(CY+y0,CY+y1),Rhino.Geometry.Interval(z0,z1)).ToBrep()
def roof_z(x):return FLOOR+6.+5.2*pow(max(0.,1.-abs(x)/8.6),.7)
def finish(mesh):
    mesh.UnifyNormals();mesh.Normals.ComputeNormals();mesh.Compact();assert mesh.IsValid;return mesh
def rib(v):
    mesh=Rhino.Geometry.Mesh();count=81
    for i in range(count):
        x=-8.6+17.2*i/(count-1);z=roof_z(x)
        slope=(roof_z(min(8.6,x+.01))-roof_z(max(-8.6,x-.01)))/.02
        normal=Rhino.Geometry.Vector3d(-slope,0,1);normal.Unitize()
        for a,b in [(-1,-1),(1,-1),(1,1),(-1,1)]:mesh.Vertices.Add(p(x+a*.21*normal.X,v+b*.18,z+a*.21*normal.Z))
    for i in range(count-1):
        for j in range(4):mesh.Faces.AddFace(i*4+j,i*4+(j+1)%4,(i+1)*4+(j+1)%4,(i+1)*4+j)
    mesh.Faces.AddFace(3,2,1,0);n=(count-1)*4;mesh.Faces.AddFace(n,n+1,n+2,n+3)
    return finish(mesh)
def skin(x0,x1,v0,v1):
    mesh=Rhino.Geometry.Mesh();count=25
    for dz in [0.,-.22]:
        for y in [v0,v1]:
            for i in range(count):
                x=x0+(x1-x0)*i/(count-1);mesh.Vertices.Add(p(x,y,roof_z(x)+dz))
    for i in range(count-1):
        mesh.Faces.AddFace(i,i+1,count+i+1,count+i)
        n=2*count;mesh.Faces.AddFace(n+i,n+count+i,n+count+i+1,n+i+1)
        mesh.Faces.AddFace(i,n+i,n+i+1,i+1)
        mesh.Faces.AddFace(count+i,count+i+1,3*count+i+1,3*count+i)
    for i in [0,count-1]:mesh.Faces.AddFace(i,count+i,3*count+i,2*count+i)
    return finish(mesh)
def prepare():
    height=sc.sticky['church_height_1104'];items=[]
    def add(g,c):items.append((g,c))
    add(box(-9,9,-18,18,24.75,FLOOR),BASE)
    add(box(-7,7,18,28,FLOOR-.3,FLOOR),BASE)
    for v in [-18,-12,-6,0,6,12,18]:
        add(rib(v),METAL)
        for side in [-1,1]:add(box(side*8.6-.28,side*8.6+.28,v-.38,v+.38,FLOOR,FLOOR+6.0),IVORY)
    for v in [-18,-12,-6,0,6,12]:
        for side in [-1,1]:
            add(box(side*8.55-.16,side*8.55+.16,v+.4,v+5.6,FLOOR,FLOOR+3.1),IVORY)
            if not (side==1 and v in [-6,6]):add(box(side*8.55-.08,side*8.55+.08,v+.5,v+5.5,FLOOR+3.3,FLOOR+5.65),GLASS)
        if v not in [-6,12]:add(skin(-8.6,-.45,v+.22,v+5.78),IVORY)
        if v not in [0,12]:add(skin(.45,8.6,v+.22,v+5.78),IVORY)
    # Front wall has a real doorway notch and a real circular opening.
    outline=[p(-8.6,18,FLOOR)]
    for i in range(61):
        x=-8.6+17.2*i/60.;outline.append(p(x,18,roof_z(x)))
    outline.extend([p(8.6,18,FLOOR),p(2,18,FLOOR),p(2,18,FLOOR+3.8),p(-2,18,FLOOR+3.8),p(-2,18,FLOOR),outline[0]])
    outer=Rhino.Geometry.PolylineCurve(outline)
    plane=Rhino.Geometry.Plane(p(0,18,FLOOR+7.6),Rhino.Geometry.Vector3d.XAxis,Rhino.Geometry.Vector3d.ZAxis)
    circle=Rhino.Geometry.Circle(plane,1.7).ToNurbsCurve()
    for wall in Rhino.Geometry.Brep.CreatePlanarBreps([outer,circle],.001):add(wall,IVORY)
    for pane in Rhino.Geometry.Brep.CreatePlanarBreps(Rhino.Geometry.Circle(Rhino.Geometry.Plane(p(0,17.97,FLOOR+7.6),Rhino.Geometry.Vector3d.XAxis,Rhino.Geometry.Vector3d.ZAxis),1.62).ToNurbsCurve(),.001):add(pane,GLASS)
    # Partially surviving bell frame inside the surveyed footprint.
    for x in [-8.1,-4.8]:
        for y in [11.6,14.9]:add(box(x-.22,x+.22,y-.22,y+.22,FLOOR,FLOOR+(16.4 if x==-8.1 else 14.6)),IVORY)
    add(box(-8.3,-4.6,11.4,11.9,FLOOR+13.4,FLOOR+13.85),METAL)
    add(box(-8.3,-7.6,11.4,15.1,FLOOR+16.0,FLOOR+16.4),IVORY)
    # Existing ring road -> 42 steps -> ground-following trail -> forecourt.
    road=(1761.103,1075.278,32.508);stair_length=15.84;bottom_x=road[0]-stair_length
    path=[];count=65
    for i in range(count):
        f=i/(count-1.);x=1620+(bottom_x-1620)*f;y=1078+(road[1]-1078)*f+7*math.sin(math.pi*f)
        hit=height(x,y);assert hit
        z=hit[0]+.08;path.append([x,y,z])
    path[0][2]=FLOOR
    mesh=Rhino.Geometry.Mesh()
    for i,q in enumerate(path):
        prev=path[max(0,i-1)];nxt=path[min(len(path)-1,i+1)];dx=nxt[0]-prev[0];dy=nxt[1]-prev[1];l=math.sqrt(dx*dx+dy*dy)
        for side in [-1,1]:
            x=q[0]-side*dy/l*1.2;y=q[1]+side*dx/l*1.2;hit=height(x,y);assert hit
            mesh.Vertices.Add(x,y,hit[0]+.09)
    for i in range(count-1):mesh.Faces.AddFace(i*2,i*2+2,i*2+3,i*2+1)
    add(finish(mesh),BASE)
    bottom=path[-1][2];rise=(road[2]-bottom)/42.;assert .12<rise<.19
    station=0.;number=0
    for flight in [14,14,14]:
        for j in range(flight):
            x=bottom_x+station;level=bottom+(number+1)*rise
            add(box(x-CX,x-CX+.32,road[1]-CY-1.3,road[1]-CY+1.3,level-.45,level),BASE)
            station+=.32;number+=1
        if number<42:
            level=bottom+number*rise;add(box(bottom_x+station-CX,bottom_x+station-CX+1.2,road[1]-CY-1.3,road[1]-CY+1.3,level-.45,level),BASE);station+=1.2
    # Two continuous stair stringer walls ensure the stair is not floating.
    for side in [-1,1]:
        mesh=Rhino.Geometry.Mesh();y=road[1]+side*1.3
        for i in range(15):
            f=i/14.;x=bottom_x+stair_length*f;ground=height(x,y);assert ground
            mesh.Vertices.Add(x,y,ground[0]-.25);mesh.Vertices.Add(x,y,bottom+(road[2]-bottom)*f-.18)
        for i in range(14):mesh.Faces.AddFace(i*2,i*2+1,i*2+3,i*2+2)
        add(finish(mesh),IVORY)
    footprint=[]
    for y in [-18,-9,0,9,18]:
        for x in [-9,-4.5,0,4.5,9]:
            h=height(CX+x,CY+y);footprint.append([CX+x,CY+y,h[0]])
    # Dense three-metre sampling for feasibility, including the entire hall.
    dense=[]
    for i in range(7):
        for j in range(13):
            x=CX-9+i*3.;y=CY-18+j*3.;hit=height(x,y);assert hit;dense.append([x,y,hit[0]])
    grades=[];length=0.
    for a,b in zip(path,path[1:]):
        horizontal=math.sqrt((a[0]-b[0])**2+(a[1]-b[1])**2);length+=horizontal;grades.append(abs(a[2]-b[2])/horizontal)
    forecourt=[]
    for i in range(8):
        for j in range(6):
            x=CX-7+i*2.;y=CY+18+j*2.;hit=height(x,y);assert hit;forecourt.append([x,y,hit[0]])
    overlaps=[]
    for obj in sc.doc.Objects:
        if obj.IsDeleted or obj.Geometry is None:continue
        layer=sc.doc.Layers[obj.Attributes.LayerIndex].FullPath
        if not layer.startswith('建筑::'):continue
        b=obj.Geometry.GetBoundingBox(True)
        if b.Max.X>CX-9 and b.Min.X<CX+9 and b.Max.Y>CY-18 and b.Min.Y<CY+28:overlaps.append(str(obj.Id))
    data={'map':sc.doc.Path,'center_xy':[CX,CY],'hall_size_m':[18,36],'floor_z':FLOOR,'roof_peak_z':FLOOR+11.2,'bell_frame_peak_z':FLOOR+16.4,'footprint_samples':dense,'terrain_min_z':min(q[2] for q in dense),'terrain_max_z':max(q[2] for q in dense),'maximum_concept_cut_m':max(0,max(q[2] for q in dense)-FLOOR),'maximum_concept_fill_m':max(0,FLOOR-min(q[2] for q in dense)),'forecourt_size_m':[14,10],'forecourt_samples':forecourt,'building_bbox_overlaps':overlaps,'path_width_m':2.4,'path_length_m':length,'path_max_sampled_grade':max(grades),'path_points':path,'road_join':list(road),'stair_steps':42,'stair_rise_m':rise,'stair_tread_m':.32,'stair_landings_m':1.2,'stair_total_run_m':stair_length,'concept_geometry_count':len(items),'geometry_valid':all(g.IsValid for g,c in items),'original_doc_objects_modified':0,'status':'measured_concept_only_not_final_collision_or_godot_acceptance'}
    if not os.path.isdir(OUT):os.makedirs(OUT)
    with open(os.path.join(OUT,'site_measurements.json'),'w') as f:json.dump(data,f,indent=2)
    sc.sticky['church_concept_items_1104']=items;sc.sticky['church_concept_data_1104']=data
    return data

class Preview(Rhino.Display.DisplayConduit):
    def __init__(self):
        self.items=sc.sticky['church_concept_items_1104'];self.annotate=False;self.plan=False
    def CalculateBoundingBox(self,e):
        for g,c in self.items:e.IncludeBoundingBox(g.GetBoundingBox(True))
    def PostDrawObjects(self,e):
        for g,c in self.items:
            material=Rhino.Display.DisplayMaterial(c)
            if isinstance(g,Rhino.Geometry.Mesh):e.Display.DrawMeshShaded(g,material)
            else:e.Display.DrawBrepShaded(g,material)
    def DrawForeground(self,e):
        if self.annotate:
            cyan=Drawing.Color.FromArgb(0,166,187)
            ring=Rhino.Geometry.Circle(p(0,0,FLOOR+.2),29.)
            e.Display.DrawCurve(ring.ToNurbsCurve(),cyan,3)
            e.Display.DrawDot(p(0,0,FLOOR+23.),'A  CHURCH',cyan,Drawing.Color.White)
        if self.plan:
            color=Drawing.Color.FromArgb(0,130,150)
            route=sc.sticky['church_concept_data_1104']['path_points']
            e.Display.DrawCurve(Rhino.Geometry.PolylineCurve([Rhino.Geometry.Point3d(*q) for q in route]),color,2)
            e.Display.DrawDot(p(0,-5,FLOOR+20),'A  36 x 18 m',color,Drawing.Color.White)
            r=sc.sticky['church_concept_data_1104']['road_join']
            e.Display.DrawDot(Rhino.Geometry.Point3d(*r),'B  EXISTING ROAD',color,Drawing.Color.White)
            e.Display.DrawDot(Rhino.Geometry.Point3d(r[0]-9,r[1]-6,r[2]+2),'42 STEPS',color,Drawing.Color.White)

def capture():
    view=sc.doc.Views.ActiveView;vp=view.ActiveViewport;doc_count=sc.doc.Objects.Count;modified=sc.doc.Modified
    conduit=Preview();sc.sticky['church_conduit_1104']=conduit
    def image(name):
        view.Redraw();cap=Rhino.Display.ViewCapture();cap.Width=1832;cap.Height=1172;cap.ScaleScreenItems=True;cap.DrawAxes=False;cap.DrawGrid=False;cap.DrawGridAxes=False
        bitmap=cap.CaptureToBitmap(view);assert bitmap;bitmap.Save(os.path.join(OUT,name),Imaging.ImageFormat.Png);bitmap.Dispose()
    vp.PushViewProjection()
    try:
        conduit.Enabled=True;conduit.annotate=True;image('exact_site_overview.png')
        conduit.annotate=False
        conduit.plan=True
        vp.SetToPlanView(Rhino.Geometry.Point3d(1685,1060,0),Rhino.Geometry.Vector3d.XAxis,Rhino.Geometry.Vector3d.YAxis,False)
        vp.ZoomBoundingBox(Rhino.Geometry.BoundingBox(Rhino.Geometry.Point3d(1580,1005,0),Rhino.Geometry.Point3d(1800,1115,55)))
        image('exact_site_plan.png')
        conduit.plan=False;vp.PopViewProjection();vp.PushViewProjection()
        vp.ChangeToPerspectiveProjection(True,40.)
        target=p(0,0,FLOOR+5.0)
        camera=p(62,98,FLOOR+64.)
        vp.SetCameraLocations(target,camera);vp.Camera35mmLensLength=40.
        image('massing_oblique.png')
        target=p(0,0,FLOOR+5.0);camera=p(33,56,FLOOR+21.)
        vp.SetCameraLocations(target,camera);vp.Camera35mmLensLength=35.
        image('massing_entrance.png')
    finally:
        conduit.Enabled=False;vp.PopViewProjection();view.Redraw()
    assert sc.doc.Objects.Count==doc_count and sc.doc.Modified==modified
    print(json.dumps({'captured':True,'document_objects_unchanged':True,'view_restored':True,'out':OUT}))
