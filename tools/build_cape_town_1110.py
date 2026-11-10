# -*- coding: utf-8 -*-
"""Feature-owned native author. Rhino: prepare/apply/export_source/save_native.
Python: --package. Reuses the proven sandbar mesh/UV/GLB pipeline.
"""
import os, io, json, math
ROOT=os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BASE={'__file__':os.path.join(ROOT,'tools','build_sandbar_pavilion_1109.py'),'__name__':'town_mesh_helpers'}
exec(compile(io.open(BASE['__file__'],encoding='utf-8-sig').read(),BASE['__file__'],'exec'),BASE)
FEATURE='cape_town_1110'
N=math.sqrt(.563**2+.827**2)
F=[.563/N,.827/N,0.];R=[F[1],-F[0],0.]
SITE=[2095.7,2209.4,0.]
FLOOR=1.44
BASE.update(FEATURE=FEATURE,SITE=SITE,FORWARD=F,RIGHT=R,FLOOR=FLOOR,
            CACHE=os.path.join(ROOT,'.current_map_build',FEATURE),OUT=os.path.join(ROOT,'assets','world',FEATURE))
COLORS={'sand':(235,218,194),'asphalt':(86,103,109),'slate':(90,113,132),'red':(161,66,48),
        'soil':(100,125,72),'paint':(161,196,190)}

def frame(x=0,z=0,a=0):BASE['_LOCAL_FRAME']=[x,z,a]
def cad(x,z,h):return BASE['cad'](x,z,h)
def gd(x,z,h):return BASE['godot'](cad(x,z,h))
def town(p):
    x,y=p[0]-SITE[0],p[1]-SITE[1]
    return [x*R[0]+y*R[1],x*F[0]+y*F[1],p[2]]
def box(x,z,w,d,b,t):return BASE['_box'](x,z,w,d,b,t)
def beam(a,b,w,d):return BASE['_beam'](a,b,w,d)
def plate(points,depth):return BASE['_plate'](points,depth)
def poly(points,b,t):return BASE['_horizontal'](points,b,t)
def merge(parts):
    import Rhino.Geometry as G
    result=G.Mesh()
    for p in parts:result.Append(p)
    assert result.IsValid and result.IsClosed
    return result
def add(name,mesh,mat='ivory',category='architecture',building='',collision=True,render=True,owner='',grain='y'):
    assert mesh.IsValid and mesh.IsClosed,name
    rows.append(dict(name=name,mesh=mesh,material_key=mat,category=category,building_id=building,
        collision=collision,render=render,owner=owner,grain=grain,texture_frame=list(BASE['_LOCAL_FRAME'] or [0,0,0])))
def ring(cx,cz,inner,outer,b,t,steps=72,gap=False):
    parts=[]
    for i in range(steps):
        a,beta=i*math.pi*2/steps,(i+1)*math.pi*2/steps
        if gap and math.radians(165)<(a+beta)/2<math.radians(195):continue
        parts.append(poly([[cx+math.sin(a)*inner,cz+math.cos(a)*inner],
            [cx+math.sin(a)*outer,cz+math.cos(a)*outer],
            [cx+math.sin(beta)*outer,cz+math.cos(beta)*outer],
            [cx+math.sin(beta)*inner,cz+math.cos(beta)*inner]],b,t))
    return merge(parts)
def road(a,b,width,height,mat,name):
    dx,dz=b[0]-a[0],b[1]-a[1];length=math.sqrt(dx*dx+dz*dz);px,pz=-dz/length*width/2,dx/length*width/2
    p=[[a[0]+px,a[1]+pz,height],[b[0]+px,b[1]+pz,height],[b[0]-px,b[1]-pz,height],[a[0]-px,a[1]-pz,height]]
    add(name,plate(p,.18),mat,'street')
def sample_ground(x,z):
    import Rhino.Geometry as G
    p=cad(x,z,100)
    ray=G.Ray3d(G.Point3d(*p),G.Vector3d(0,0,-1))
    hit=G.Intersect.Intersection.MeshRay(terrain_mesh,ray)
    return 100-hit if hit>=0 else None

def prepare_terrain():
    import Rhino, Rhino.Geometry as G, scriptcontext as sc, System
    global terrain_mesh,coast,terrain_top
    obj=sc.doc.Objects.FindId(System.Guid('a2a15e34-a9db-4e6a-a4ce-be472804bd15'))
    host=obj.Geometry.Faces[8].DuplicateFace(False)
    params=G.MeshingParameters();params.MaximumEdgeLength=10.;params.MinimumEdgeLength=2.;params.GridMinCount=30;params.RefineGrid=True
    terrain_mesh=merge(G.Mesh.CreateFromBrep(host,params)) if False else G.Mesh()
    for m in G.Mesh.CreateFromBrep(host,params):terrain_mesh.Append(m)
    coast=obj.Geometry.Faces[8].OuterLoop.To3dCurve()
    coast.Transform(G.Transform.PlanarProjection(G.Plane.WorldXY))
    top=G.Mesh()
    terrain_mesh.Faces.ConvertQuadsToTriangles()
    for f in terrain_mesh.Faces:
        p=[[float(terrain_mesh.Vertices[i].X),float(terrain_mesh.Vertices[i].Y),float(terrain_mesh.Vertices[i].Z)] for i in [f.A,f.B,f.C]]
        p=BASE['_clip_plane'](p,1,1850.,False)
        if len(p)<3:continue
        start=top.Vertices.Count
        for q in p:
            ok,t=coast.ClosestPoint(G.Point3d(q[0],q[1],0))
            dist=coast.PointAt(t).DistanceTo(G.Point3d(q[0],q[1],0))
            u=max(0.,min(1.,dist/28.));u=u*u*(3-2*u)
            w=max(0.,min(1.,(q[1]-1850.)/35.));w=w*w*(3-2*w)
            target=max(q[2]+.025,.10+1.10*u)
            q[2]=q[2]+.025+w*(target-q[2]-.025)
            top.Vertices.Add(*q)
        for i in range(1,len(p)-1):top.Faces.AddFace(start,start+i,start+i+1)
    top.Vertices.CombineIdentical(True,True);top.Normals.ComputeNormals();top.UnifyNormals()
    terrain_top=top.DuplicateMesh()
    count=top.Vertices.Count;bottom=-6.
    boundary=[]
    for i in range(top.TopologyEdges.Count):
        if len(top.TopologyEdges.GetConnectedFaces(i))!=1:continue
        pair=top.TopologyEdges.GetTopologyVertices(i)
        boundary.append((top.TopologyVertices.MeshVertexIndices(pair.I)[0],top.TopologyVertices.MeshVertexIndices(pair.J)[0]))
    # Duplicate the full top triangulation at the bottom, preserving concavity.
    verts=[G.Point3d(v) for v in top.Vertices];faces=[(f.A,f.B,f.C) for f in top.Faces]
    for p in verts:top.Vertices.Add(p.X,p.Y,bottom)
    for a,b,c in faces:top.Faces.AddFace(c+count,b+count,a+count)
    for a,b in boundary:top.Faces.AddFace(a,b,b+count,a+count)
    top.UnifyNormals();top.Normals.ComputeNormals()
    if top.SolidOrientation()<0:top.Flip(True,True,True)
    add('site/graded_sand',top,'sand','terrain')

def prepare_access():
    import Rhino.Geometry as G,scriptcontext as sc,System
    frame()
    old=sc.doc.Objects.FindId(System.Guid('3f760bb7-a390-4660-9289-81f18adc3f48')).Geometry
    # Find the first asphalt boundary independently on each side of the new spur.
    starts=[]
    for x in [-3.5,3.5]:
        found=None
        for i in range(1800):
            v=-20-i*.5;p=cad(x,v,30)
            d=G.Intersect.Intersection.MeshRay(old,G.Ray3d(G.Point3d(*p),G.Vector3d(0,0,-1)))
            if d>=0:found=(v,30-d);break
        assert found is not None,'New approach missed the existing road'
        lo,hi=found[0],found[0]+.5
        for j in range(16):
            v=(lo+hi)/2;p=cad(x,v,30)
            d=G.Intersect.Intersection.MeshRay(old,G.Ray3d(G.Point3d(*p),G.Vector3d(0,0,-1)))
            if d>=0:lo=v;h=30-d
            else:hi=v
        starts.append([x,lo+.003,h])
    join=sum(p[1] for p in starts)/2;join_h=sum(p[2] for p in starts)/2
    add('street/approach',plate([starts[0],starts[1],[3.5,-13.03,1.22],[-3.5,-13.03,1.22]],.18),'asphalt','street')
    for sign in [-1,1]:
        add('street/approach_sidewalk_'+str(sign),plate([[sign*3.55,join+1,join_h+.10],[sign*6.55,join+1,join_h+.10],
            [sign*6.55,-23,1.32],[sign*3.55,-23,1.32]],.20),'ivory','street')
    # Low sand shoulders; blend their outside edges into the original support.
    parts=[]
    for i in range(int((-23-join)/6)+1):
        v1=join+1+i*6;v2=min(v1+6,-23)
        if v2<=v1:continue
        def rh(v):return 1.18+(join_h-.04-1.18)*((-23-v)/(-23-join))
        for sign in [-1,1]:
            for inner,outer in [(0,6.6),(6.6,15),(15,24)]:
                points=[]
                for x,v in [(inner,v1),(outer,v1),(outer,v2),(inner,v2)]:
                    ground=sample_ground(sign*x,v)
                    if ground is None:ground=-1.5
                    weight=max(0.,min(1.,(x-6.6)/17.4));weight=weight*weight*(3-2*weight)
                    points.append([sign*x,v,max(ground+.03,rh(v)*(1-weight)+(ground+.03)*weight)])
                parts.append(plate(points,8))
    add('site/approach_shoulders',merge(parts),'sand','terrain')
    routes.append(dict(id='road_join',points=[gd(0,join+2,join_h+.04),gd(0,-25,1.26)],width=7.))
    return join,join_h

def facade(parts,glass,timber,x1,z1,x2,z2,base,height,door=False):
    # Build wall piers around real recesses rather than placing glass on a blank box.
    dx,dz=x2-x1,z2-z1;length=math.sqrt(dx*dx+dz*dz);n=max(1,int(length/3.5))
    nx,nz=-dz/length,dx/length
    def member(a,b,low,high,w=.28):
        if high-low<.005:return
        parts.append(beam([x1+dx*a,z1+dz*a,(low+high)/2],[x1+dx*b,z1+dz*b,(low+high)/2],w,high-low))
    for i in range(n):
        a,b=float(i)/n,float(i+1)/n;gap=.22/length
        isdoor=door and i==n//2
        sill=base if isdoor else base+.82
        head=base+2.65
        member(a,a+gap,base,base+height);member(b-gap,b,base,base+height)
        member(a+gap,b-gap,base,sill);member(a+gap,b-gap,head,base+height)
        if not isdoor:
            # Inset glazing gives physical reveals and transparent openings.
            glass.append(beam([x1+dx*(a+gap)+nx*.06,z1+dz*(a+gap)+nz*.06,(sill+head)/2],
                [x1+dx*(b-gap)+nx*.06,z1+dz*(b-gap)+nz*.06,(sill+head)/2],.045,head-sill))
            timber.append(beam([x1+dx*(a+gap),z1+dz*(a+gap),sill],[x1+dx*(b-gap),z1+dz*(b-gap),sill],.38,.10))
        if i%2==0 and not isdoor:
            for k in range(3):
                t=a+gap+(k+.5)*.10/length
                timber.append(beam([x1+dx*t-nx*.20,z1+dz*t-nz*.20,sill],[x1+dx*t-nx*.20,z1+dz*t-nz*.20,head],.06,.10))

def house(index,x,z,a,w,d,storeys,public=False):
    frame(x,z,a);key='town_%02d'%index;wall=[];glass=[];timber=[];rails=[]
    # Chamfered corner shops and complete elevations, with different roof silhouettes.
    c=3.5 if public else .8
    outline=[[-w/2,-d/2],[w/2,-d/2],[w/2,d/2-c],[w/2-c,d/2],[-w/2+c,d/2],[-w/2,d/2-c]]
    add(key+'/plinth',poly([[p[0]*1.04,p[1]*1.05] for p in outline],1.20,FLOOR),'stone','floor',key)
    add(key+'/porch_floor',box(0,d/2+1.35,w-1,2.7,1.18,FLOOR),'ivory','floor',key)
    add(key+'/front_path',box(0,d/2+8.0,5.2,10.6,1.16,1.32),'ivory','street',key)
    for level in range(storeys):
        h=FLOOR+3.4*level
        name=key+'/floor_'+str(level)
        add(name,poly(outline,h-.16,h),'ivory','floor',key)
        for i in range(len(outline)):
            p,q=outline[i],outline[(i+1)%len(outline)]
            # Side stair doorway on right; back/front doors remain usable too.
            isdoor=(i==3 or i==1 or (i==5 and level>0) or (i==0 and level==0))
            facade(wall,glass,timber,p[0],p[1],q[0],q[1],h,3.24,isdoor)
        if level>0:
            # Front balcony projects toward the square; side landing meets actual doorway.
            add(key+'/balcony_'+str(level),box(0,d/2+1.05,w-2,2.1,h-.20,h),'ivory','floor',key)
            rails.append(box(0,d/2+2.06,w-2,.14,h,h+.28))
            rails.append(box(0,d/2+2.06,w-2,.09,h+.98,h+1.05))
            for sx in [-1,1]:
                if storeys==3 and level==1 and sx<0:continue
                rails.append(box(sx*(w/2-1),d/2+1.05,.10,2.1,h,h+1.05))
            # Continuous invisible guard ensures safe passage without dense pickets.
            add(key+'/balcony_guard_'+str(level),box(0,d/2+2.06,w-2,.10,h,h+1.05),'ivory','guard',key,True,False)
        # Open ground-level covered porch; no blocking front wall or giant opaque window.
    add(key+'/walls',merge(wall),'wall_concrete','walls',key)
    add(key+'/glazing',merge(glass),'sea_glass','glazing',key)
    add(key+'/timber_reveals',merge(timber),'timber','detail',key,False)
    # An offset internal wall stops the transparent shell reading as a warehouse.
    partitions=[]
    for level in range(storeys):
        h=FLOOR+3.4*level
        partitions.extend([box(-w*.20,-d*.13,w*.34,.18,h,h+2.75),box(w*.22,-d*.13,w*.24,.18,h,h+2.75)])
    add(key+'/room_partitions',merge(partitions),'wall_concrete','walls',key)
    if rails:add(key+'/rails',merge(rails),'ivory','guard',key)
    roof=FLOOR+3.4*storeys
    add(key+'/roof_core',box(0,0,w+.6,d+.6,roof-.16,roof+.16),'ivory','roof',key)
    # Distinct shallow gables/folded planes; solid core avoids daylight leaks.
    slope=.9+(.5 if index%3==0 else 0.)
    if public and index in [2,4,5]:
        # Wide pale butterfly roofs distinguish the public corners from homes.
        for sign in [-1,1]:
            top=[[0,-d/2-1,roof+.30],[sign*(w/2+1.5),-d/2-1,roof+1.1],
                [sign*(w/2+2),d/2+.8,roof+1.8],[sign*(w/2-2),d/2+3.6,roof+1.55],[0,d/2+3.6,roof+.25]]
            add(key+'/folded_canopy_'+str(sign),plate(top,.22),'ivory','roof',key)
        add(key+'/roof_spine',beam([0,-d/2-.8,roof+.2],[0,d/2+3.2,roof+.2],.30,.30),'stone','structure',key)
    elif not public and index in [8,11]:
        # Flat terrace silhouette with restrained timber pergola.
        parts=[]
        for sx in [-w/2+1,w/2-1]:
            for vz in [-d/2+1,d/2-1]:parts.append(box(sx,vz,.15,.15,roof,roof+1.8))
        for j in range(9):parts.append(box(0,-d/2+1+j*(d-2)/8,w-1,.12,roof+1.7,roof+1.85))
        add(key+'/roof_pergola',merge(parts),'timber','detail',key,False,True,grain='x')
        add(key+'/terrace_parapet',merge([box(-w/2,0,.20,d,roof,roof+.6),box(w/2,0,.20,d,roof,roof+.6),box(0,-d/2,w,.2,roof,roof+.6)]),'ivory','roof',key)
    else:
        for sign in [-1,1]:
            top=[[0,-d/2-1,roof+slope],[sign*(w/2+1),-d/2-1,roof+.22],
                 [sign*(w/2+1),d/2+2.6,roof+.32],[0,d/2+2.6,roof+slope+.10]]
            add(key+'/roof_'+str(sign),plate(top,.18),'teal' if index%3 else 'slate','roof',key)
        seams=[]
        for j in range(int((d+3)/1.4)):
            v=-d/2-1+j*1.4
            for sign in [-1,1]:seams.append(beam([0,v,roof+slope+.025],[sign*(w/2+1),v,roof+.26],.035,.045))
        add(key+'/roof_seams',merge(seams),'slate','detail',key,False)
    porch=[]
    for sx in [-w/2+1,w/2-1]:
        porch.append(box(sx,d/2+1.5,.23,.23,FLOOR,FLOOR+3.15))
    add(key+'/porch_posts',merge(porch),'timber','structure',key)
    if storeys==1:add(key+'/porch_canopy',plate([[-w/2-1,d/2-.2,FLOOR+3.2],[w/2+1,d/2-.2,FLOOR+3.2],
        [w/2+1,d/2+2.7,FLOOR+3.05],[-w/2-1,d/2+2.7,FLOOR+3.05]],.17),'ivory','roof',key)
    # Expressive shop fascia and sunshade are architectural, not ad hoc furniture.
    if public:
        add(key+'/shop_fascia',box(0,d/2+.18,w-4,.30,FLOOR+2.75,FLOOR+3.15),'paint','detail',key,False)
        add(key+'/shop_awning',plate([[-w/2+2,d/2+.25,FLOOR+2.72],[w/2-2,d/2+.25,FLOOR+2.72],
            [w/2-2,d/2+2.1,FLOOR+2.48],[-w/2+2,d/2+2.1,FLOOR+2.48]],.06),'coral' if index%2 else 'paint','detail',key,False)
    # Straight side flights, landing clear of the doorway. 22 risers / floor.
    for level in range(1,storeys):
        h=FLOOR+3.4*(level-1);sign=1 if level%2 else -1;sx=sign*(w/2+1.45)
        start=-d/2-1. if sign==1 else d/2+2.;end=start+sign*7.2
        steps=[]
        for k in range(22):steps.append(box(sx,start+sign*(k+.5)*7.2/22,1.8,7.2/22,h-.15,h+(k+1)*3.4/22))
        add(key+'/steps_'+str(level),merge(steps),'ivory','stairs',key,False)
        ramp=plate([[sx-.9,start,h],[sx+.9,start,h],[sx+.9,end,h+3.4],[sx-.9,end,h+3.4]],.20)
        add(key+'/stairs_'+str(level)+'-colonly',ramp,'stone','ramp',key,True,False)
        # Door is centered on side wall; wrap landing to its exact center bay.
        side_n=max(1,int((d-c)/3.5));fraction=(float(side_n//2)+.5)/side_n
        door_v=-d/2+(d-c)*fraction if sign==1 else d/2-c-(d-c)*fraction
        bound=door_v+sign*1.2
        add(key+'/landing_'+str(level),box(sign*(w/2+1.),(end+bound)/2,2.0,abs(bound-end),h+3.24,h+3.4),'ivory','floor',key)
        if sign<0:
            add(key+'/upper_stair_start',box(-w/2-.4,d/2+1.4,4.0,3.2,h-.20,h),'ivory','floor',key)
        else:
            add(key+'/lower_stair_start',box(sx,start-.65,2.4,2.2,1.18,1.32),'ivory','street',key)
        railparts=[beam([sx+sign,start,h+1.05],[sx+sign,end,h+4.45],.09,.09)]
        add(key+'/stair_rail_'+str(level),merge(railparts),'stone','guard',key,False)
        add(key+'/stair_guard_'+str(level),beam([sx+sign,start,h+.55],[sx+sign,end,h+3.95],.10,1.1),
            'stone','guard',key,True,False)
        routes.append(dict(id=key+'_flight_'+str(level),points=[gd(sx,start-sign*.3,h+.04),gd(sx,end+sign*.1,h+3.44),gd(sign*(w/2-.8),door_v,h+3.44)],width=1.8))
    buildings.append(dict(id=key,type='shop' if public else 'home',storeys=storeys,position=gd(0,0,FLOOR),
        forward=[math.sin(a)*R[0]+math.cos(a)*F[0],0,-math.sin(a)*R[1]-math.cos(a)*F[1]],
        width=w,depth=d,floor_component=key+'/floor_0',floor_height=FLOOR,storey_height=3.4,
        corners=[cad(p[0],p[1],FLOOR) for p in outline]))
    frame()

def bench(key,x,z,a=0):
    frame(x,z,a);h=1.32
    add(key+'/paving',box(0,.45,3.5,2.7,1.18,h),'ivory','street')
    add(key+'/seat',box(0,0,2.0,.55,h+.34,h+.420),'timber','furniture','',True,True,key,grain='x')
    add(key+'/feet',merge([box(s,0,.18,.42,h,h+.34) for s in [-.7,.7]]),'stone','furniture','',True,True,key)
    frame()
    co,si=math.cos(a),math.sin(a)
    front=[x+si*1.1,z+co*1.1,h]
    furniture.append(dict(id=key,type='chair',name_zh=u'海岬街角座椅',local=[x,z,h],surface_height=.420,
        usable_surface=dict(width_m=2.,depth_m=.55),yaw=a,anchors=[['Anchor_Seat',x,z,h+.420,False],['Anchor_Front',front[0],front[1],h,True]]))

def shrine():
    import Rhino.Geometry as G,scriptcontext as sc,System
    frame(-83,140,0);key='town_14';h=1.77;w=10.;d=8.
    add(key+'/foundation',box(0,0,12,11,1.20,h-.18),'stone','floor',key)
    add(key+'/floor_0',box(0,0,12,11,h-.18,h),'timber','floor',key)
    posts=[box(x,z,.28,.28,h,h+3.2) for x in [-4.7,4.7] for z in [-3.7,3.7]]
    add(key+'/posts',merge(posts),'timber','structure',key)
    walls=[];glass=[];wood=[]
    for p,q,door in [([-5,-4],[5,-4],False),([5,-4],[5,4],False),([-5,4],[-5,-4],False)]:
        facade(walls,glass,wood,p[0],p[1],q[0],q[1],h,3.2,door)
    add(key+'/walls',merge(walls),'timber','walls',key)
    add(key+'/glazing',merge(glass),'sea_glass','glazing',key)
    add(key+'/shutters',merge(wood),'timber','detail',key,False)
    for sign in [-1,1]:
        top=[[0,-5,h+5],[sign*4.5,-5,h+3.5],[sign*6.5,-5,h+3.8],[sign*6.5,5.8,h+3.8],[sign*4.5,5.8,h+3.5],[0,5.8,h+5]]
        add(key+'/upturned_roof_'+str(sign),plate(top,.22),'slate','roof',key)
    add(key+'/ridge',beam([0,-5.3,h+5.12],[0,6.1,h+5.12],.25,.30),'stone','roof',key)
    add(key+'/lintel',box(0,3.8,10.3,.35,h+2.8,h+3.2),'red','structure',key)
    steps=[box(0,5.5+(2.5-k)*.42,3.,.42,1.30,1.32+(k+1)*.15) for k in range(3)]
    add(key+'/steps',merge(steps),'stone','stairs',key,False)
    add(key+'/entry-colonly',plate([[-1.5,6.76,1.32],[1.5,6.76,1.32],[1.5,5.5,h],[-1.5,5.5,h]],.2),'stone','ramp',key,True,False)
    rope=[]
    for i in range(16):
        a=-4+i*.5;b=a+.5
        rope.append(beam([a,4.05,h+2.65+.14*(a/4)**2],[b,4.05,h+2.65+.14*(b/4)**2],.10,.10))
    add(key+'/shimenawa',merge(rope),'timber','detail',key,False)
    paper=[]
    for x in [-2.7,-.9,.9,2.7]:
        paper.extend([beam([x,4.07,h+2.55],[x-.08,4.07,h+2.30],.025,.19),
            beam([x-.08,4.07,h+2.30],[x+.12,4.07,h+2.22],.025,.19),
            beam([x+.12,4.07,h+2.22],[x-.10,4.07,h+1.96],.025,.19)])
    add(key+'/shide',merge(paper),'ivory','detail',key,False)
    table='shrine_table'
    add(table+'/top',box(0,1,1.6,.7,h+.758,h+.838),'timber','furniture',key,True,True,table,grain='x')
    add(table+'/legs',merge([box(x,1,.12,.6,h,h+.758) for x in [-.6,.6]]),'timber','furniture',key,True,True,table)
    frame()
    furniture.append(dict(id=table,type='desk',name_zh=u'神社供桌',local=[-83,141,h],surface_height=.838,usable_surface=dict(width_m=1.6,depth_m=.7),yaw=0,
        anchors=[['Anchor_Desk_Surface',-83,141,h+.838,False],['Anchor_Front',-83,142.2,h,True]]))
    buildings.append(dict(id=key,type='shrine',storeys=1,position=gd(-83,140,h),forward=[F[0],0,-F[1]],width=10,depth=8,
        floor_component=key+'/floor_0',floor_height=h,corners=[cad(-83+x,140+z,h) for x,z in [(-6,-5),(6,-5),(6,5),(-6,5)]]))
    road([-83,146.2],[-83,157],3.,1.32,'stone','shrine/short_approach')
    road([0,125],[-75,140],3.,1.32,'stone','shrine/path')
    # Actual water holes are authoritative: find a location offshore, both pillars wet.
    water=[sc.doc.Objects.FindId(System.Guid(s)).Geometry for s in ['a851549b-eb4e-4be2-bfc5-8052291a6c72','8540c7bb-0104-46f5-b3e2-24fa8d22424b']]
    wet_v=None
    for v in range(160,401,2):
        good=True
        for x in [-86,-83,-80]:
            p=cad(x,v,0);curve=G.LineCurve(G.Point3d(p[0],p[1],10),G.Point3d(p[0],p[1],-10))
            if not any(len(G.Intersect.Intersection.CurveBrep(curve,b,.01)[2])>0 for b in water):good=False
        if good:wet_v=v+4;break
    assert wet_v is not None,'Could not locate offshore torii'
    frame(-83,wet_v,0)
    add('torii/pillars',merge([box(x,0,.48,.55,-2.8,5.25) for x in [-2.7,2.7]]),'red','torii')
    add('torii/lintel',box(0,0,7.2,.65,4.90,5.32),'red','torii')
    add('torii/tie',box(0,0,6.5,.34,3.60,3.88),'red','torii')
    add('torii/cap',merge([beam([-3.8,0,5.6],[0,0,5.43],.78,.20),beam([0,0,5.43],[3.8,0,5.6],.78,.20)]),'stone','torii')
    add('torii/feet',merge([box(x,0,.85,.85,-2.8,.15) for x in [-2.7,2.7]]),'stone','torii')
    frame();return wet_v

def prepare():
    global rows,furniture,buildings,routes,metadata
    rows=[];furniture=[];buildings=[];routes=[];frame()
    BASE['_protected']=BASE['_fingerprint']()
    prepare_terrain();join,jh=prepare_access()
    add('street/roundabout',ring(0,0,13,20,1.05,1.22),'asphalt','street')
    add('street/sidewalk',ring(0,0,20.1,23,1.12,1.32,gap=True),'ivory','street')
    add('street/pedestrian_ring',ring(0,0,68.5,71.5,1.16,1.32),'ivory','street')
    add('square/island_rim',ring(0,0,11.8,12.4,1.2,1.47),'ivory','landscape')
    add('square/soil',ring(0,0,.1,11.8,1.18,1.38),'soil','landscape')
    # A fragmented tilted loop echoes the existing world language without a giant tower.
    pieces=[]
    for i in range(32):
        a=.12+i*math.pi*1.7/32;b=.12+(i+1)*math.pi*1.7/32
        pieces.append(beam([math.cos(a)*4,1+math.sin(a)*.8,5+math.sin(a)*4],
            [math.cos(b)*4,1+math.sin(b)*.8,5+math.sin(b)*4],.48,.58))
    add('square/broken_loop',merge(pieces),'ivory','landmark')
    for i,angle in enumerate([-150,-90,-30,30,90,150]):
        a=math.radians(angle);x,z=45*math.sin(a),45*math.cos(a)
        house(i+1,x,z,math.atan2(-x,-z),24 if i%2 else 22,17,3 if i in [1,4] else 2,True)
        x,z=92*math.sin(a),92*math.cos(a)
        house(i+7,x,z,math.atan2(-x,-z),18 if i%2 else 16,15,1 if i in [0,5] else 2)
    house(13,85,98,math.radians(-135),17,15,2)
    road([105,60],[76,89],3.,1.32,'ivory','street/home_13_branch')
    for i,angle in enumerate([0,60,120,180,240,300]):
        if angle==180:continue
        a=math.radians(angle);sx,sz=math.sin(a),math.cos(a)
        road([sx*23.05,sz*23.05],[sx*125,sz*125],3.,1.32,'ivory','street/spoke_'+str(i))
    for i,(x,z,a) in enumerate([(-12,24,0),(12,24,0),(-24,-12,-math.pi/2),(24,-12,math.pi/2)]):bench('bench_'+str(i+1),x,z,a)
    wet_v=shrine()
    # Validate all building envelopes against the native dry land, not screenshot scale.
    import Rhino.Geometry as G
    for b in buildings:
        for p in b['corners']:
            hit=G.Intersect.Intersection.MeshRay(terrain_mesh,G.Ray3d(G.Point3d(p[0],p[1],100),G.Vector3d(0,0,-1)))
            assert hit>=0,'Building outside native cape: '+b['id']
            assert 100-hit< b['floor_height']-.15,'Foundation buried in existing terrain: '+b['id']
    BASE['_staged']=rows;BASE['_furniture']=furniture;BASE['_buildings']=buildings
    for item in furniture:
        a=item['yaw'];item['forward_cad']=[math.sin(a)*R[0]+math.cos(a)*F[0],math.sin(a)*R[1]+math.cos(a)*F[1],0.]
    metadata=dict(road_join_v=join,road_join_height=jh,torii_v=wet_v,
        buildings=14,shrine_count=1,torii_count=1,protected_objects_unchanged=True)
    return dict(metadata,meshes=len(rows),triangles=sum(m['mesh'].Faces.TriangleCount for m in rows))

def apply():return BASE['apply'](COLORS,u'海岬小镇','CapeTown_','Cape town')
def save_native():return BASE['save_native']()
def export_source():
    result=BASE['export_source']()
    path=os.path.join(BASE['CACHE'],'source.json');data=json.load(io.open(path,encoding='utf-8'))
    data.update(feature=FEATURE,art_revision='cape_town_v1',site_cad=SITE,building_count=14,buildings=buildings,
        forward=[F[0],0,-F[1]],max_height_m=13.6,terrain_modified=False,terrain_overlay=True,grass_rebake_required=True,
        site_measurement=metadata,routes=routes,spawn=gd(0,-25,1.27),
        camera=dict(position=gd(-145,-175,100),target=gd(0,15,2),fov=48),
        detail_camera=dict(position=gd(-7,-35,3),target=gd(-18,15,5),fov=65),
        shrine_camera=dict(position=gd(-99,163,5),target=gd(-83,140,3),fov=62))
    data.pop('court_hub',None)
    data['materials'].update(sand=dict(color=[.88,.80,.68],resource='beach_sand'),
        asphalt=dict(color=[.24,.30,.33],roughness=.94),slate=dict(color=[.29,.39,.47],roughness=.66),
        red=dict(color=[.56,.15,.10],roughness=.82),soil=dict(color=[.36,.46,.22],roughness=.98),paint=dict(color=[.54,.70,.67],roughness=.85))
    for row,item in zip(data['interactions']['furniture'],furniture):
        a=item['yaw'];f=[math.sin(a)*R[0]+math.cos(a)*F[0],0,-math.sin(a)*R[1]-math.cos(a)*F[1]]
        row['forward']=f
        for anchor,source in zip(row['anchors'],item['anchors']):anchor['forward']=[-n if source[4] else n for n in f]
    BASE['_dump'](path,data)
    return result

def package(rebuild_geometry=True):
    if rebuild_geometry:BASE['package']('town.glb','Prism Route / Rhino cape town')
    # One half-float field: grass SDF / finished height / coast distance / footprint.
    # Beach is ONLY a shoreline strip. The clipped landward seam is not coastline.
    from PIL import Image,ImageDraw,ImageFilter
    import numpy as np
    from scipy.ndimage import distance_transform_edt
    from build_east_earth_pavilion_1102 import raster
    source=json.load(io.open(os.path.join(BASE['CACHE'],'source.json'),encoding='utf-8'))
    objects=[r for r in source['objects'] if r['category'] in ['terrain','street']]
    points=[BASE['godot'](p) for row in objects for p in row['vertices']]
    x0=math.floor(min(p[0] for p in points))-2;z0=math.floor(min(p[2] for p in points))-2
    x1=math.ceil(max(p[0] for p in points))+2;z1=math.ceil(max(p[2] for p in points))+2
    size=(int(x1-x0),int(z1-z0))
    image=Image.new('L',size,0);draw=ImageDraw.Draw(image)
    support=np.full((size[1],size[0]),-10000.,np.float32)
    coast=Image.new('L',size,255);coast_draw=ImageDraw.Draw(coast)
    for row in objects:
        vertices=[BASE['godot'](p) for p in row['vertices']]
        for i in range(0,len(row['indices']),3):
            poly=[(vertices[j][0]-x0,vertices[j][2]-z0) for j in row['indices'][i:i+3]]
            draw.polygon(poly,fill=255)
        if row['category']!='terrain':continue
        vertices=np.asarray(vertices);triangles=vertices[np.asarray(row['indices']).reshape(-1,3)]
        raster(triangles,np.array([x0,z0]),1.,support)
        if row['name']!='site/graded_sand':continue
        edges={}
        for tri in triangles:
            n=np.cross(tri[1]-tri[0],tri[2]-tri[0])
            if n[1]<=.72*np.linalg.norm(n):continue
            for i in range(3):
                a,b=tri[i],tri[(i+1)%3]
                key=tuple(sorted([(round(float(a[0]),3),round(float(a[2]),3)),(round(float(b[0]),3),round(float(b[2]),3))]))
                edges[key]=edges.get(key,0)+1
        for (a,b),count in edges.items():
            if count!=1 or (abs(a[1]+700)<.01 and abs(b[1]+700)<.01):continue
            coast_draw.line([(a[0]-x0,a[1]-z0),(b[0]-x0,b[1]-z0)],fill=0,width=1)
    hard=Image.new('L',size,0);hd=ImageDraw.Draw(hard)
    for row in source['objects']:
        if not row['collision'] or row['category']=='terrain':continue
        if row['category'] not in ['street','floor','walls','ramp','furniture','landscape','structure','guard']:continue
        vertices=[BASE['godot'](p) for p in row['vertices']]
        for i in range(0,len(row['indices']),3):
            hd.polygon([(vertices[j][0]-x0,vertices[j][2]-z0) for j in row['indices'][i:i+3]],fill=255)
    inside=support>-9999.
    coast_distance=distance_transform_edt(np.array(coast)>0)
    beach=inside&(coast_distance<20.)
    # Preserve the existing one-metre white road edge where the access grade meets it.
    old_root=os.path.join(ROOT,'assets','world','terrain_repairs_1103')
    previous=json.load(io.open(os.path.join(old_root,'manifest.json'),encoding='utf-8'))['road_shoulder']
    old_mask=np.fromfile(os.path.join(old_root,previous['mask_path']),dtype='<f2').reshape(previous['size'][1],previous['size'][0],2)
    zz,xx=np.mgrid[:size[1],:size[0]]
    ox=np.floor((xx+x0-previous['origin_xz'][0])/previous['pixel_size']).astype(int)
    oz=np.floor((zz+z0-previous['origin_xz'][1])/previous['pixel_size']).astype(int)
    valid=(ox>=0)&(oz>=0)&(ox<old_mask.shape[1])&(oz<old_mask.shape[0])
    old_data=old_mask[oz.clip(0,old_mask.shape[0]-1),ox.clip(0,old_mask.shape[1]-1)].astype(float)
    preserve=valid&inside&(old_data[:,:,0]<.55)&(old_data[:,:,1]>-9999.)&(np.abs(old_data[:,:,1]-support)<.6)
    hard_pixels=np.array(hard);hard_pixels[preserve]=255;hard=Image.fromarray(hard_pixels)
    excluded=(np.array(hard)>0)|beach
    eligible=inside&~excluded
    sdf=distance_transform_edt(eligible)-distance_transform_edt(~eligible)
    field=np.stack([np.clip(sdf,-1000,1000),support,np.minimum(coast_distance,2000),inside.astype(float)],axis=-1)
    field.astype('<f2').tofile(os.path.join(BASE['OUT'],'ground_field.rgba'))
    image=Image.fromarray((inside*255).astype('uint8')).filter(ImageFilter.MaxFilter(3))
    cells=json.load(io.open(os.path.join(ROOT,'assets','world','current_map_validation','grass_cells.json'),encoding='utf-8'))['cells']
    affected=set()
    for cell in cells:
        if cell[1] not in [-1,0]:continue
        xa=max(0,int(cell[0]*24-x0)-1);za=max(0,int(cell[2]*24-z0)-1)
        xb=min(image.width,int((cell[0]+1)*24-x0)+2);zb=min(image.height,int((cell[2]+1)*24-z0)+2)
        if xb>xa and zb>za and image.crop((xa,za,xb,zb)).getbbox():affected.add(tuple(cell))
    # Newly raised low terrain may occupy y=0 where only old y=-1 cells existed.
    zz,xx=np.where(eligible)
    for x,z in zip(xx,zz):affected.add((int(math.floor((x+x0)/24)),int(math.floor(float(support[z,x])/24)),int(math.floor((z+z0)/24))))
    path=os.path.join(BASE['OUT'],'manifest.json');manifest=json.load(io.open(path,encoding='utf-8'))
    manifest['ground_cut']=dict(origin=[x0,z0],extent=[x1-x0,z1-z0],size=list(size),pixel_size=1.,
        path='ground_field.rgba',format='RGBAH',min_height=-32,max_height=10,cells=[list(c) for c in sorted(affected)],
        beach_width_m=18.,beach_feather_m=4.,grass_coverage=.5,
        report=dict(land_m2=int(inside.sum()),grass_m2=int(eligible.sum()),beach_m2=int(beach.sum()),hardscape_m2=int((inside&(np.array(hard)>0)).sum())))
    BASE['_dump'](path,manifest)
    print(json.dumps(dict(affected_grass_cells=len(affected),mask_size=image.size,land_cover=manifest['ground_cut']['report'])))

if __name__=='__main__':
    import argparse
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--package',action='store_true');parser.add_argument('--ground-only',action='store_true')
    args=parser.parse_args()
    if args.package or args.ground_only:package(not args.ground_only)
