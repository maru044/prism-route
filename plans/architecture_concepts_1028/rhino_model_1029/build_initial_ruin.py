# -*- coding: utf-8 -*-
"""Run inside the live Rhino bridge; Python 2/3 compatible, phased and additive."""
import Rhino
import scriptcontext as sc
import System
import System.Drawing as Drawing
import json, math, os
from Rhino.Geometry import Point3d as P, Vector3d as V

HERE = r'D:\Prism Route\plans\architecture_concepts_1028\rhino_model_1029'
STATE = os.path.join(HERE, 'build_state.json')
ROOT = u'建筑::初始三角遗迹'
TAG = 'PR_InitialTriangle_20261029_v1'
D = sc.doc
TOL = D.ModelAbsoluteTolerance
with open(os.path.join(HERE, 'placement_plan.json')) as f: PLAN = json.load(f)
FX,FY = PLAN['front_center']
LX,LY = PLAN['long_axis']
RX,RY = PLAN['right_axis']

def world(u,v,z): return P(FX+u*RX+v*LX, FY+u*RY+v*LY, z)
def local(x,y): return ((x-FX)*RX+(y-FY)*RY, (x-FX)*LX+(y-FY)*LY)
def width(v): return max(0.,15.-v*.25)
def floor_z(v):
    if v < 9.: return 60.45
    if v < 10.4: return 60.45+min(4,int((v-9.)/.35)+1)*.15
    if v < 47.5: return 61.05
    if v < 48.9: return 61.05+min(4,int((v-47.5)/.35)+1)*.15
    return 61.65
def roof_z(u,v): return 75.45+.20*u+.035*v
def constant_or_func(z,u,v): return z(u,v) if callable(z) else float(z)
def clean(points):
    out=[]
    for p in points:
        if not out or p.DistanceTo(out[-1])>TOL:out.append(p)
    if len(out)>2 and out[0].DistanceTo(out[-1])<TOL:out.pop()
    return out
def polycurve(points):
    p=clean(points)
    return Rhino.Geometry.PolylineCurve(p+[p[0]])
def cap(points):
    result=Rhino.Geometry.Brep.CreatePlanarBreps(polycurve(points),TOL)
    if not result or len(result)!=1:raise Exception('Non-planar or invalid cap')
    return result[0]
def polyhedron(bottom,top):
    bottom=clean(bottom);top=clean(top)
    if len(bottom)!=len(top):raise Exception('Mismatched solid rings')
    faces=[cap(bottom),cap(top)]
    for i in range(len(bottom)):
        j=(i+1)%len(bottom)
        face=Rhino.Geometry.Brep.CreateFromCornerPoints(bottom[i],bottom[j],top[j],top[i],TOL)
        if face is None:raise Exception('Degenerate solid side')
        faces.append(face)
    joined=Rhino.Geometry.Brep.JoinBreps(faces,TOL*2.)
    if not joined or len(joined)!=1 or not joined[0].IsSolid:raise Exception('Solid failed to close')
    b=joined[0]
    if b.SolidOrientation==Rhino.Geometry.BrepSolidOrientation.Inward:b.Flip()
    return b
def twisted_deck(bottom,top):
    # Differently directed end sections need two planar top triangles, not one twisted cap.
    faces=[cap(bottom),cap([top[0],top[1],top[2]]),cap([top[0],top[2],top[3]])]
    for i in range(4):
        j=(i+1)%4
        faces.append(Rhino.Geometry.Brep.CreateFromCornerPoints(bottom[i],bottom[j],top[j],top[i],TOL))
    joined=Rhino.Geometry.Brep.JoinBreps(faces,TOL*2.)
    if not joined or len(joined)!=1 or not joined[0].IsSolid:raise Exception('Transition deck did not close')
    b=joined[0]
    if b.SolidOrientation==Rhino.Geometry.BrepSolidOrientation.Inward:b.Flip()
    return b
def prism(poly,bottom,top):
    return polyhedron([world(u,v,constant_or_func(bottom,u,v)) for u,v in poly],
                      [world(u,v,constant_or_func(top,u,v)) for u,v in poly])
def box(u0,u1,v0,v1,z0,z1): return prism([(u0,v0),(u1,v0),(u1,v1),(u0,v1)],z0,z1)
def band(v0,v1,extra=0.):
    return [(-width(v0)-extra,v0),(width(v0)+extra,v0),(width(v1)+extra,v1),(-width(v1)-extra,v1)]
def beam(a,b,w,h):
    direction=b-a;length=direction.Length
    return Rhino.Geometry.Box(Rhino.Geometry.Plane(a,direction),Rhino.Geometry.Interval(-w/2,w/2),Rhino.Geometry.Interval(-h/2,h/2),Rhino.Geometry.Interval(0,length)).ToBrep()
def cylinder(u,v,z,r,h):
    return Rhino.Geometry.Cylinder(Rhino.Geometry.Circle(Rhino.Geometry.Plane(world(u,v,z),V.ZAxis),r),h).ToBrep(True,True)

MATS={
 'ivory':(216,210,191), 'floor':(226,221,207), 'base':(174,171,154),
 'shadow':(153,154,144), 'cap':(200,194,174), 'cyan':(57,203,230),
 'dark':(43,73,81), 'case':(108,119,118)}
LAYERS={
 'foundation':u'01_地基与台基','entry':u'02_入口台阶与通路',
 'floor':u'03_地面与内阶','front':u'04_低墙与门',
 'colonnade':u'05_侧廊','highwall':u'06_高墙与扶壁',
 'roof':u'07_斜屋盖与梁架','dais':u'08_召唤台与遗物',
 'reference':u'00_辅助基准'}

class Builder(object):
    def __init__(self):
        if D.ModelUnitSystem!=Rhino.UnitSystem.Meters:raise Exception('Document units must be metres')
        if os.path.isfile(STATE):
            with open(STATE) as f:self.state=json.load(f)
        else:self.state={'tag':TAG,'phases':[],'objects':[],'checks':{},'placement':PLAN}
        self.stage=[];self.cache={};self.meshes=[]
        params=Rhino.Geometry.MeshingParameters()
        params.Tolerance=.02;params.MaximumEdgeLength=4.;params.MinimumEdgeLength=.1;params.RefineGrid=True
        for ident,face in [('577d868b-7597-4058-83f8-4b630606b305',2),('0e79433e-80e9-48f1-ab77-3786fdc3819f',None),('9713e301-b5a7-4acb-821d-d98484bc52de',None)]:
            o=D.Objects.FindId(System.Guid(ident))
            if o is None:raise Exception('Source terrain missing')
            geom=o.Geometry.Faces[face].DuplicateFace(False) if face is not None else o.Geometry
            mesh=Rhino.Geometry.Mesh()
            for part in Rhino.Geometry.Mesh.CreateFromBrep(geom,params):mesh.Append(part)
            mesh.Compact();self.meshes.append(mesh)
    def ground_xy(self,x,y):
        key=(round(x,3),round(y,3))
        if key not in self.cache:
            ray=Rhino.Geometry.Ray3d(P(x,y,200),V(0,0,-1));zs=[]
            for mesh in self.meshes:
                t=Rhino.Geometry.Intersect.Intersection.MeshRay(mesh,ray)
                if t>=0:zs.append(200.-t)
            if not zs:raise Exception('No ground at %.3f, %.3f'%(x,y))
            self.cache[key]=max(zs)
        return self.cache[key]
    def ground(self,u,v):
        p=world(u,v,0);return self.ground_xy(p.X,p.Y)
    def min_ground(self,poly):
        values=[]
        for i,p in enumerate(poly):
            q=poly[(i+1)%len(poly)]
            count=max(1,int(math.ceil(math.hypot(q[0]-p[0],q[1]-p[1])/.8)))
            for j in range(count+1):
                t=float(j)/count;values.append(self.ground(p[0]*(1-t)+q[0]*t,p[1]*(1-t)+q[1]*t))
        values.append(self.ground(sum(p[0] for p in poly)/len(poly),sum(p[1] for p in poly)/len(poly)))
        return min(values)
    def add(self,geom,category,name,mat='ivory',description=''):
        if geom is None or not geom.IsValid:raise Exception('Invalid geometry: '+name)
        if isinstance(geom,Rhino.Geometry.Brep) and not geom.IsSolid:raise Exception('Open solid: '+name)
        self.stage.append((geom,category,name,mat,description))
    def layer(self,path):
        existing=D.Layers.FindByFullPath(path,-1)
        if existing>=0:return existing
        idx=D.Layers.AddPath(path,Drawing.Color.FromArgb(216,210,191))
        if idx<0:raise Exception('Layer creation failed')
        return idx
    def material(self,key):
        name='PR_Ruin1029_'+key
        for m in D.Materials:
            if m.Name==name:return m.MaterialIndex
        m=Rhino.DocObjects.Material();m.Name=name;m.DiffuseColor=Drawing.Color.FromArgb(*MATS[key]);m.Shine=3
        if key=='cyan':m.EmissionColor=Drawing.Color.FromArgb(*MATS[key])
        return D.Materials.Add(m)
    def flush(self,phase):
        if phase in self.state['phases']:raise Exception('Phase already built: '+phase)
        if not self.stage:raise Exception('No geometry staged')
        mats={key:self.material(key) for key in MATS}
        layers={key:self.layer(ROOT+'::'+value) for key,value in LAYERS.items()}
        undo=D.BeginUndoRecord('Project PR triangular ruin '+phase)
        D.Views.RedrawEnabled=False
        try:
            for geom,category,name,mat,desc in self.stage:
                a=Rhino.DocObjects.ObjectAttributes();a.Name=name;a.LayerIndex=layers[category]
                a.MaterialIndex=mats[mat];a.MaterialSource=Rhino.DocObjects.ObjectMaterialSource.MaterialFromObject
                a.ObjectColor=Drawing.Color.FromArgb(*MATS[mat]);a.ColorSource=Rhino.DocObjects.ObjectColorSource.ColorFromObject
                a.SetUserString('pr_ruin_build',TAG);a.SetUserString('pr_ruin_phase',phase)
                a.SetUserString('description',desc or name)
                ident=D.Objects.AddBrep(geom,a)
                if ident==System.Guid.Empty:raise Exception('Document add failed: '+name)
                if 'add_object_metadata' in globals():add_object_metadata(ident,name,desc or name)
                self.state['objects'].append({'id':str(ident),'name':name,'category':category,'phase':phase})
            self.state['phases'].append(phase)
        finally:
            D.EndUndoRecord(undo);D.Views.RedrawEnabled=True
            with open(STATE,'w') as f:json.dump(self.state,f,ensure_ascii=True,indent=2)
        D.Views.Redraw()
        print(json.dumps({'phase':phase,'added':len(self.stage),'total_new':len(self.state['objects'])},ensure_ascii=True))

    def phase1(self):
        # Structural podium follows the actual hill; each segment embeds below its lowest support point.
        bands=[(0.,4.,60.2),(4.,9.,60.2),(9.,10.4,60.2),(10.4,17.,60.8),
               (17.,24.,60.8),(24.,31.,60.8),(31.,38.,60.8),(38.,45.,60.8),
               (45.,47.5,60.8),(47.5,48.9,60.8),(48.9,54.,61.4),(54.,60.,61.4)]
        embed=[]
        for i,(v0,v1,top) in enumerate(bands):
            p=band(v0,v1,.65);bottom=self.min_ground(p)-.65
            self.add(prism(p,bottom,top),'foundation','PR_Foundation_%02d'%i,'base','Terrain-supported stepped solid foundation; bottom embedded >=0.65m')
            embed.append({'v':[v0,v1],'bottom':bottom,'top':top})
        # Courtyard floor plates, four-riser internal flights, and rear landing.
        floor_ranges=[(0.,9.,60.45),(10.4,47.5,61.05),(48.9,60.,61.65)]
        for i,(v0,v1,zz) in enumerate(floor_ranges):
            self.add(prism(band(v0,v1),zz-.25,zz),'floor','PR_Courtyard_Floor_%02d'%i,'floor')
        for v0,z0 in [(9.,60.45),(47.5,61.05)]:
            for n in range(4):
                a=v0+n*.35;b=a+.35;top=z0+(n+1)*.15
                self.add(prism(band(a,b),z0-.25,top),'floor','PR_InternalStair_%.1f_%02d'%(v0,n),'floor')
        # Main entrance: two flights of 18 risers, 2.4m intermediate landing, and broad upper terrace.
        main_steps=[]
        for group,start_v,start_z in [(0,-27.,55.05),(1,-18.3,57.75)]:
            for n in range(18):
                a=start_v+n*.35;b=a+.35;top=start_z+(n+1)*.15
                poly=[(-3.6,a),(3.6,a),(3.6,b),(-3.6,b)]
                bottom=min(self.min_ground(poly)-.45,start_z-.2)
                self.add(prism(poly,bottom,top),'entry','PR_EntryFlight_%d_Tread_%02d'%(group+1,n+1),'floor')
                main_steps.append({'v0':a,'v1':b,'top':top,'riser':.15,'tread':.35})
        for name,a,b,zz in [('Lower',-30.,-27.,55.05),('Middle',-20.7,-18.3,57.75),('Upper',-12.,.05,60.45)]:
            poly=[(-4.2,a),(4.2,a),(4.2,b),(-4.2,b)]
            self.add(prism(poly,self.min_ground(poly)-.55,zz),'entry','PR_EntryLanding_'+name,'base')
            self.add(prism(poly,zz-.18,zz),'entry','PR_EntryLandingCap_'+name,'floor')
        # Side cheek walls retain the entrance stairs and touch terrain.
        for side in [-1.,1.]:
            for n,(a,b,zz) in enumerate([(-30.,-20.7,57.75),(-20.7,-12.,60.45),(-12.,-.2,60.45)]):
                p=[(side*4.0,a),(side*4.5,a),(side*4.5,b),(side*4.0,b)]
                low_top=[55.05,57.75,60.45][n]
                self.add(prism(p,self.min_ground(p)-.5,lambda u,v:low_top+(zz-low_top)*(v-a)/(b-a)+.42),'entry','PR_StairCheek_%d_%d'%(side,n),'cap')
        self.state['checks']['foundation_bands']=embed
        self.state['checks']['entry_stairs']={'risers':36,'riser_m':.15,'tread_m':.35,'width_m':7.2,'middle_landing_m':2.4,'total_rise_m':5.4}
        self.state['checks']['internal_stairs']={'flights':2,'risers_each':4,'riser_m':.15,'tread_m':.35}
        self.build_approach()
        self.flush('01_foundation_stairs')

    def build_approach(self):
        pts=[P(x,y,0.) for x,y in PLAN['approach_nodes']]
        # Local rounded corners avoid global cubic interpolation overshooting into a tight loop.
        rounded=[pts[0]]
        def line_to(end):
            start=rounded[-1];count=max(1,int(math.ceil(start.DistanceTo(end)/.75)))
            for j in range(1,count+1):rounded.append(start+(end-start)*(float(j)/count))
        for i in range(1,len(pts)-1):
            incoming=pts[i]-pts[i-1];outgoing=pts[i+1]-pts[i]
            trim=min(5.,incoming.Length*.25,outgoing.Length*.25)
            incoming.Unitize();outgoing.Unitize()
            a=pts[i]-incoming*trim;b=pts[i]+outgoing*trim
            line_to(a)
            for j in range(1,21):
                t=j/20.;p=a*(1-t)*(1-t)+pts[i]*(2*t*(1-t))+b*t*t
                rounded.append(p)
        line_to(pts[-1])
        curve=Rhino.Geometry.PolylineCurve(rounded)
        length=curve.GetLength()
        def frame(distance):
            ok,t=curve.LengthParameter(min(length,max(0.,distance)))
            p=curve.PointAt(t);tangent=curve.TangentAt(t);tangent.Z=0.;tangent.Unitize()
            right=V(tangent.Y,-tangent.X,0.)
            return p,right
        def strip(a,b,half=1.6):
            p,r=frame(a);q,s=frame(b)
            return [p-r*half,p+r*half,q+s*half,q-s*half]
        count=int(math.ceil(length/.25));distances=[length*i/count for i in range(count+1)]
        required=[]
        for d in distances:
            p,right=frame(d);heights=[]
            for j in range(7):
                q=p+right*(-1.6+j*3.2/6.);heights.append(self.ground_xy(q.X,q.Y))
            required.append(max(heights)+.10)
        start_z=35.40;end_z=55.05;riser=.15;risers=int(round((end_z-start_z)/riser))
        if max(required)>end_z+.025:raise Exception('Approach route exceeds lower landing height')
        positions=[]
        for n in range(1,risers+1):
            lower=start_z+(n-1)*riser
            where=next((distances[i] for i,h in enumerate(required) if h>lower+.001),length)
            positions.append(where)
        positions[-1]=min(positions[-1],length-3.)
        for i in range(len(positions)-2,-1,-1):
            gap=1.8 if (i+1)%18==0 else .37
            positions[i]=min(positions[i],positions[i+1]-gap)
        if positions[0]<2.:raise Exception('Insufficient approach length for stairs and landings')
        intervals=[(0.,positions[0],start_z)]
        for i,a in enumerate(positions):
            intervals.append((a,positions[i+1] if i+1<len(positions) else length,start_z+(i+1)*riser))
        clearances=[]
        for j,(a,b,zz) in enumerate(intervals):
            segments=max(1,int(math.ceil((b-a)/3.)))
            for sub in range(segments):
                da=a+(b-a)*sub/segments;db=a+(b-a)*(sub+1)/segments
                poly=strip(da,db)
                ground_values=[]
                for dd in [da,(da+db)/2.,db]:
                    p,right=frame(dd)
                    for u in [-1.6,0.,1.6]:
                        q=p+right*u;ground_values.append(self.ground_xy(q.X,q.Y))
                bottom=min(ground_values)-.40
                lower=[P(p.X,p.Y,bottom) for p in poly];upper=[P(p.X,p.Y,zz) for p in poly]
                try: geom=polyhedron(lower,upper)
                except:
                    print(json.dumps({'bad_approach_interval':[j,sub,da,db,zz],'corners':[[q.X,q.Y,q.Z] for q in upper]}))
                    raise
                self.add(geom,'entry','PR_Approach_%03d_%02d'%(j,sub),'floor','3.2m wide terrain-supported approach; 0.15m quantized risers and periodic 1.8m landings')
                clearances.append(zz-max(ground_values))
        # Shallow transition into the existing cave-exit walkway; existing railing remains intact.
        p,right_end=frame(0);q=P(576.,-271.5,0.)
        forward=p-q;forward.Unitize();right_start=V(forward.Y,-forward.X,0.)
        poly=[q-right_start*1.6,q+right_start*1.6,p+right_end*1.6,p-right_end*1.6]
        bottom=[P(x.X,x.Y,34.8) for x in poly]
        tops=[P(x.X,x.Y,35.2 if i<2 else start_z) for i,x in enumerate(poly)]
        self.add(twisted_deck(bottom,tops),'entry','PR_CaveWalk_Transition','floor','Short shallow bridge/deck from the existing cave walkway to solid inland terrain, 0.20m rise; both end cross-sections match adjoining paths')
        self.state['checks']['approach']={'length_m':length,'width_m':3.2,'risers':risers,'riser_m':riser,'minimum_tread_m':min(positions[i+1]-positions[i] for i in range(len(positions)-1)),'landing_interval_risers':18,'minimum_periodic_landing_m':1.8,'min_ground_clearance_samples_m':min(clearances),'start_z':start_z,'end_z':end_z,'step_stations':positions,'curve_nodes':PLAN['approach_nodes']}

    def phase2(self):
        # Low front wall, a 7.2m clear broken entry and framed ends.
        for side in [-1.,1.]:
            a,b=sorted([side*15.6,side*3.6])
            self.add(box(a,b,-.25,1.0,60.2,66.45),'front','PR_LowWall_%d'%side,'ivory')
            self.add(box(a,b,-.42,1.18,66.45,66.7),'front','PR_LowWall_Coping_%d'%side,'cap')
            for u in [side*4.45,side*14.95]:
                self.add(box(u-.8,u+.8,-.65,1.35,60.2,67.0),'front','PR_EntryPier_%+.2f'%u,'ivory')
                self.add(box(u-1.,u+1.,-.85,1.55,67.,67.3),'front','PR_EntryPierCap_%+.2f'%u,'cap')
        # Medium left side: open colonnade, continuous low sill, deep sloping header.
        for n,(a,b) in enumerate([(0,9),(9,10.4),(10.4,47.5),(47.5,48.9),(48.9,60)]):
            poly=[(-width(a)-.55,a),(-width(a)+.55,a),(-width(b)+.55,b),(-width(b)-.55,b)]
            z0=floor_z((a+b)/2.)-.25
            self.add(prism(poly,z0,z0+1.15),'colonnade','PR_LeftSill_%02d'%n,'ivory')
        poly=[(-15.7,0),(-14.3,0),(.7,60),(-.7,60)]
        self.add(prism(poly,lambda u,v:roof_z(u,v)-1.1,lambda u,v:roof_z(u,v)),'colonnade','PR_Left_SlopingLintel','ivory')
        for n,v in enumerate([0.,8.,16.,24.,32.,40.,48.,55.]):
            u=-width(v);zz=floor_z(v)
            self.add(box(u-.95,u+.95,v-.95,v+.95,zz-.25,zz+.38),'colonnade','PR_LeftColumnBase_%02d'%n,'base')
            low=[world(u-.58,v-.6,zz+.38),world(u+.58,v-.6,zz+.38),world(u+.58,v+.6,zz+.38),world(u-.58,v+.6,zz+.38)]
            top=[world(u-.48,v-.5,roof_z(u,v)-1.2),world(u+.48,v-.5,roof_z(u,v)-1.2),world(u+.48,v+.5,roof_z(u,v)-1.2),world(u-.48,v+.5,roof_z(u,v)-1.2)]
            self.add(polyhedron(low,top),'colonnade','PR_LeftColumn_%02d'%n,'ivory')
            self.add(box(u-.85,u+.85,v-.8,v+.8,roof_z(u,v)-1.3,roof_z(u,v)-.95),'colonnade','PR_LeftCapital_%02d'%n,'cap')
        # Tall right diagonal with recessed panels and projecting structural piers.
        poly=[(14.55,0),(15.65,0),(.65,60),(-.45,60)]
        self.add(prism(poly,60.2,lambda u,v:roof_z(u,v)+.12),'highwall','PR_Right_TallWall','ivory')
        for n,v in enumerate([0.,10.,20.,30.,40.,50.,57.]):
            u=width(v);top=roof_z(u,v)
            self.add(box(u-1.15,u+.95,v-.72,v+.72,60.2,top+.25),'highwall','PR_RightPier_%02d'%n,'cap')
            self.add(box(u-1.3,u+1.1,v-.9,v+.9,top+.25,top+.5),'highwall','PR_RightPierCap_%02d'%n,'ivory')
        # Four external buttresses have their own embedded footings.
        for n,v in enumerate([7.,20.,34.,47.]):
            u=width(v);zz=60.45;top=roof_z(u,v)-.2
            p=[(u+.15,v-1.7),(u+4.0,v-1.7),(u+4.0,v+1.7),(u+.15,v+1.7)]
            self.add(prism(p,self.min_ground(p)-.7,zz+.3),'foundation','PR_ButtressFoot_%02d'%n,'base')
            low=[world(u+.25,v-1.45,zz+.3),world(u+3.7,v-1.45,zz+.3),world(u+3.7,v+1.45,zz+.3),world(u+.25,v+1.45,zz+.3)]
            high=[world(u+.25,v-.65,top),world(u+1.05,v-.65,top),world(u+1.05,v+.65,top),world(u+.25,v+.65,top)]
            self.add(polyhedron(low,high),'highwall','PR_RightButtress_%02d'%n,'ivory')
        # A closed rear tip makes the pointed court read as one triangular building.
        self.add(prism([(-3.,48.),(-2.1,48.),(.7,60.),(-.7,60.)],61.4,lambda u,v:roof_z(u,v)),'colonnade','PR_RearTip_Infill','ivory')
        self.state['checks']['walls']={'nominal_heights_m':[6,12,18],'front_gate_clear_width_m':7.2,'colonnade_columns':8,'external_buttresses':4,'statues':0}
        self.flush('02_walls_colonnade')

    def phase3(self):
        # A real one-way inclined slab with an irregular broken front edge and two skylight slots.
        outline=[(-10.5,18),(-7.8,18.5),(-6.5,20.8),(-4.5,19.),(-2.8,22.3),(-1.2,20.),
                 (1.,21.),(1.2,29.5),(3.,32.5),(4.6,26.5),(4.5,20.1),(7.5,19.),(10.5,18.),(0.,60.)]
        roof=prism(outline,roof_z,lambda u,v:roof_z(u,v)+.55)
        for slot in [[(-1.9,35),(-1.1,35),(-1.1,43),(-1.9,43)],[(1.,41),(1.8,41),(1.8,47),(1.,47)]]:
            cutter=prism(slot,lambda u,v:roof_z(u,v)-1.,lambda u,v:roof_z(u,v)+2.)
            diff=Rhino.Geometry.Brep.CreateBooleanDifference(roof,cutter,TOL)
            if not diff or len(diff)!=1:raise Exception('Roof slot failed')
            roof=diff[0]
        self.add(roof,'roof','PR_Broken_InclinedRoof','ivory','0.55m thick one-way tilted roof; open edge notch and two skylight slots')
        for n,v in enumerate([19.,29.,39.,49.,57.]):
            w=width(v)+.15
            self.add(beam(world(-w,v,roof_z(-w,v)-.45),world(w,v,roof_z(w,v)-.45),.6,.9),'roof','PR_RoofCrossRib_%02d'%n,'cap')
        for side in [-1.,1.]:
            self.add(beam(world(side*width(18),18,roof_z(side*width(18),18)-.3),world(0.,60,roof_z(0,60)-.3),.7,.8),'roof','PR_RoofEdgeBeam_%d'%side,'cap')
        # Two angled piers flank rather than block the axial approach to the dais.
        for n,u in enumerate([-6.1,6.1]):
            v=22.;zz=61.05
            p=[(u-1.1,v-1.),(u+1.1,v-1.),(u+1.1,v+1.),(u-1.1,v+1.)]
            self.add(prism(p,zz-.25,zz+.35),'roof','PR_AngledPierBase_%d'%n,'base')
            shift=-.9 if u<0 else .9
            low=[world(a,b,zz+.35) for a,b in p]
            top=[world(u+shift-.5,v+.9,roof_z(u+shift,v+1.4)-.7),world(u+shift+.5,v+.9,roof_z(u+shift,v+1.4)-.7),world(u+shift+.5,v+1.9,roof_z(u+shift,v+1.4)-.7),world(u+shift-.5,v+1.9,roof_z(u+shift,v+1.4)-.7)]
            self.add(polyhedron(low,top),'roof','PR_AngledPier_%d'%n,'ivory')
        # Summoning platform: geometry only; the existing Godot hologram remains the character renderer.
        for n,(radius,z,h) in enumerate([(1.8,61.05,.15),(1.5,61.2,.15),(1.25,61.35,.15)]):
            self.add(cylinder(0.,25.,z,radius,h),'dais','PR_SummonStep_%d'%n,'cap' if n<2 else 'dark')
        for n,radius in enumerate([1.15,1.43]):
            torus=Rhino.Geometry.Torus(Rhino.Geometry.Plane(world(0,25,61.505 if n==0 else 61.355),V.ZAxis),radius,.025)
            self.add(torus.ToBrep(),'dais','PR_EmitterRing_%d'%n,'cyan')
        # Simple angled activation console and three closed collectible cases; no statues.
        low=[world(u,v,61.05) for u,v in [(1.8,23.5),(2.5,23.5),(2.5,24.15),(1.8,24.15)]]
        high=[world(u,v,z) for u,v,z in [(1.8,23.5,61.85),(2.5,23.5,61.85),(2.5,24.15,62.10),(1.8,24.15,62.10)]]
        self.add(polyhedron(low,high),'dais','PR_ActivationConsole','shadow')
        self.add(prism([(1.85,23.56),(2.45,23.56),(2.45,24.08),(1.85,24.08)],lambda u,v:61.85+(v-23.5)*.25/.65+.015,lambda u,v:61.85+(v-23.5)*.25/.65+.04),'dais','PR_ConsoleDisplay','cyan')
        for n,v in enumerate([16.,30.,43.]):
            u=width(v)-1.6;zz=floor_z(v)
            self.add(box(u-1.,u+.6,v-.65,v+.65,zz,zz+.8),'dais','PR_RelicLedge_%d'%n,'cap')
            self.add(box(u-.5,u+.35,v-.4,v+.4,zz+.8,zz+1.45),'dais','PR_ClosedRelicCase_%d'%n,'case')
            self.add(box(u-.53,u-.50,v-.23,v+.23,zz+1.05,zz+1.12),'dais','PR_RelicCaseLight_%d'%n,'cyan')
        # Three restrained angular fallen fragments off the axial walking route.
        for n,(u,v) in enumerate([(-7.8,16.),(7.5,13.),(-4.5,42.)]):
            z0=floor_z(v)
            self.add(prism([(u-1.2,v-.7),(u+1.0,v-.3),(u+.3,v+1.2)],z0,lambda a,b:z0+.35+.04*(a-u)+.06*(b-v)),'roof','PR_FallenFragment_%d'%n,'ivory')
        self.state['checks']['roof']={'thickness_m':.55,'skylight_slots':2,'ribs':5,'main_support_piers':2,'dais_under_remaining_roof':True}
        p=world(0,25,61.5)
        self.state['checks']['summon_anchor']=[p.X,p.Y,p.Z]
        self.flush('03_roof_summoning')

phase=globals().get('PR_RUIN_PHASE','')
if phase:
    builder=Builder()
    getattr(builder,phase)()
