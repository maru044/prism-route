# -*- coding: utf-8 -*-
"""Native, rebuildable saddle pavilion. Execute staged inside the open Rhino doc.

One continuous NURBS patch defines shell, diagrid, torn infill and the narrow
collapsed contact. No independent bridge, entry opening or interior is added.
"""
from __future__ import division, unicode_literals
import Rhino, scriptcontext as sc, System, math, json, io, os, time
from System.Drawing import Color
G = Rhino.Geometry
ROOT = 'D:/Prism Route/prism-route'
OUT = ROOT+'/docs/island_saddle_1030'
TAG = 'island_saddle_1030'
LAYER = '\u5efa\u7b51::\u5c9b\u9876\u503e\u8986\u66f2\u9762\u9057\u5740'
ROOF_ID = 'ce36cdce-398b-44f5-b0b4-fe7f258106cf'
OVAL_ID = '78d43939-e418-428e-aad5-d51b08c73985'
ROAD_ID = '0808d32c-6ebc-4105-9258-a0f755ac2752'
ROAD_BODY_ID = 'a4c9a543-2d8a-401c-bebe-b21f45031605'
PLAN_SCALE = .52
PLAN_CENTER = (1320.,415.)
GRID = 20
CONTACT_CREST_Z = 64.65
CONTACT_LANDING_DEPTH = 2.07

def state(): return sc.sticky[TAG]
def xyz(p): return [float(p.X),float(p.Y),float(p.Z)]
def write(name,data):
    with io.open(OUT+'/'+name,'w',encoding='utf-8') as f:
        f.write(json.dumps(data,ensure_ascii=False,indent=2))
def fingerprint():return {str(o.Id):int(o.Geometry.DataCRC(0)) for o in sc.doc.Objects}
def layer(path):
    index=sc.doc.Layers.FindByFullPath(path,-1)
    if index>=0:return index
    parent=System.Guid.Empty
    if '::' in path:parent=sc.doc.Layers[layer(path.rsplit('::',1)[0])].Id
    item=Rhino.DocObjects.Layer();item.Name=path.rsplit('::',1)[-1]
    if parent!=System.Guid.Empty:item.ParentLayerId=parent
    return sc.doc.Layers.Add(item)
def material(name,rgb,rough,metal=0.,opacity=1.):
    for index,existing in enumerate(sc.doc.Materials):
        if existing.Name=='PR_Saddle_'+name:return index
    item=Rhino.DocObjects.Material();item.Name='PR_Saddle_'+name
    item.DiffuseColor=Color.FromArgb(*rgb);item.Transparency=1.-opacity
    item.ToPhysicallyBased();p=item.PhysicallyBased
    p.BaseColor=Rhino.Display.Color4f(rgb[0]/255.,rgb[1]/255.,rgb[2]/255.,1.)
    p.Roughness=rough;p.Metallic=metal;p.Opacity=opacity
    return sc.doc.Materials.Add(item)
def add(geometry,name,category,mat='ivory',metadata=None):
    assert geometry and geometry.IsValid,'Invalid geometry: '+name
    attributes=Rhino.DocObjects.ObjectAttributes();attributes.Name='PR_Saddle_'+name
    attributes.LayerIndex=layer(LAYER+'::'+category)
    attributes.MaterialIndex=state()['materials'][mat]
    attributes.MaterialSource=Rhino.DocObjects.ObjectMaterialSource.MaterialFromObject
    attributes.ObjectColor=sc.doc.Materials[attributes.MaterialIndex].DiffuseColor
    attributes.SetUserString('feature',TAG);attributes.SetUserString('category',category)
    attributes.SetUserString('description','Continuous saddle shell; incidental pedestrian contact, no separate bridge')
    if metadata:
        for key,value in metadata.items():attributes.SetUserString(key,str(value))
    gid=sc.doc.Objects.Add(geometry,attributes);assert gid!=System.Guid.Empty
    state()['objects'].append(str(gid))
    state()['categories'][category]=state()['categories'].get(category,0)+1
    return gid
def source_mesh(sid):
    o=sc.doc.Objects.FindId(System.Guid(sid));assert o
    m=G.Mesh()
    for part in G.Mesh.CreateFromBrep(o.Geometry,G.MeshingParameters.FastRenderMesh):m.Append(part)
    m.Normals.ComputeNormals();m.Compact();return m
def ray_z(mesh,x,y):
    t=G.Intersect.Intersection.MeshRay(mesh,G.Ray3d(G.Point3d(x,y,200),-G.Vector3d.ZAxis))
    return 200.-t if t>=0 else None
def smooth(t):
    t=max(0.,min(1.,t));return t*t*(3.-2.*t)
def hermite(rows,t):
    # Smooth interpolating boundaries; repeated endpoints have one-sided tangents.
    i=0
    while i<len(rows)-2 and t>rows[i+1][0]:i+=1
    a,b=rows[i],rows[i+1];dt=b[0]-a[0];s=(t-a[0])/dt
    prev=rows[max(0,i-1)];nxt=rows[min(len(rows)-1,i+2)]
    result=[]
    for axis in range(1,4):
        ma=(b[axis]-prev[axis])/(b[0]-prev[0])
        mb=(nxt[axis]-a[axis])/(nxt[0]-a[0])
        result.append((2*s**3-3*s*s+1)*a[axis]+(s**3-2*s*s+s)*dt*ma+(-2*s**3+3*s*s)*b[axis]+(s**3-s*s)*dt*mb)
    return G.Point3d(*result)

def prepare():
    assert not any(o.Attributes.GetUserString('feature')==TAG for o in sc.doc.Objects),'Existing saddle found; revise its feature instead of duplicating'
    assert str(sc.doc.ModelUnitSystem)=='Meters'
    options=Rhino.FileIO.FileWriteOptions();options.SuppressDialogBoxes=True
    backup=ROOT+'/.current_map_build/before_island_saddle_'+time.strftime('%Y%m%d_%H%M%S')+'.3dm'
    assert sc.doc.Write3dmFile(backup,options),'Cannot back up current native document'
    sc.sticky[TAG]={'before':fingerprint(),'objects':[],'categories':{},'materials':{},'backup':backup,'document':sc.doc.Path}
    d=state();d['roof']=source_mesh(ROOF_ID);d['road']=source_mesh(ROAD_ID);d['road_body']=source_mesh(ROAD_BODY_ID)
    for key,rgb,rough,metal,opacity in [
        ('ivory',(218,218,206),.72,.25,1.),('weathered',(151,123,94),.81,.28,1.),
        ('dark',(83,86,78),.80,.32,1.),('panel',(223,220,204),.83,0.,1.),
        ('glass',(150,179,179),.29,0.,.62)]:d['materials'][key]=material(key,rgb,rough,metal,opacity)
    target=G.Point3d(1086.01,302.52,63)
    edge=d['road_body'].ClosestMeshPoint(target,0).Point
    road=d['road'].ClosestMeshPoint(target,0).Point
    a=d['road'].ClosestMeshPoint(target+G.Vector3d(-8,0,0),0).Point
    b=d['road'].ClosestMeshPoint(target+G.Vector3d(8,0,0),0).Point
    tangent=b-a;tangent.Z=0;tangent.Unitize()
    normal=G.Vector3d(-tangent.Y,tangent.X,0)
    if G.Vector3d.Multiply(normal,road-edge)<0:normal=-normal
    # Contact rests on the ivory structural shoulder, outside the asphalt skin.
    toe=road-normal*.50
    toe_z=ray_z(d['road_body'],toe.X,toe.Y)
    assert toe_z is not None
    toe.Z=road.Z-.28
    d['toe']=toe;d['tangent']=tangent;d['road_edge']=road
    p0=toe-tangent*1.2;p1=toe+tangent*1.2
    d['back']=[(0.,p0.X,p0.Y,p0.Z),(.08,970.,430.,64.),(.18,942.,205.,75.5),(.35,980.,177.,79.),(.52,1055.,230.,77.),(.70,1170.,310.,75.),(1.,1350.,330.,87.7)]
    d['front']=[(0.,p1.X,p1.Y,p1.Z),(.08,980.,425.,63.),(.18,1000.,365.,63.05),(.35,1060.,345.,79.),(.52,1140.,400.,79.),(.70,1230.,450.,63.05),(1.,1400.,445.,63.05)]
    configure_marked_site()
    write('parameters.json',{'feature':TAG,'roof_id':ROOF_ID,'preserved_oval_id':OVAL_ID,'road_id':ROAD_ID,'road_body_id':ROAD_BODY_ID,
        'roof_datum_m':63.,'target_rise_m':25.,'contact_width_m':2.4,'toe':xyz(toe),'toe_tangent':xyz(tangent),
        'back_boundary':d['back'],'front_boundary':d['front'],'grid':[36,16],'steel_radius_m':.19,'chord_separation_m':.72,
        'design':'One continuous doubly curved shell with a collapsed corner touching the existing high-level road shoulder. Original oval and interior remain unchanged.'})
    return {'backup':backup,'contact_center':xyz(toe),'asphalt_near_edge':xyz(road),'shoulder_separation_m':toe.DistanceTo(road),'original_objects':len(d['before'])}

def configure_marked_site():
    d=state()
    with io.open(OUT+'/marked_placement.json','r',encoding='utf-8') as f:mark=json.load(f)
    poly=mark['projected_polygon'];target=G.Point3d((poly[0][0]+poly[-1][0])*.5,(poly[0][1]+poly[-1][1])*.5,63)
    road=d['road'].ClosestMeshPoint(target,0).Point
    a=d['road'].ClosestMeshPoint(target+G.Vector3d(-8,0,0),0).Point
    b=d['road'].ClosestMeshPoint(target+G.Vector3d(8,0,0),0).Point
    tangent=b-a;tangent.Z=0;tangent.Unitize();normal=G.Vector3d(-tangent.Y,tangent.X,0)
    if normal.Y<0:normal=-normal
    # Meet the actual asphalt lip rather than projecting 0.6 m onto the
    # sloping white fascia, which lies ~0.8 m below the walkable road.
    # The skin stops just outside the asphalt; NURBS end smoothing is allowed
    # for in the chord datum and verified against the true road surface.
    toe=road-normal*.015;toe.Z=road.Z-.36
    d['toe']=toe;d['tangent']=tangent;d['road_edge']=road
    a=toe+tangent*1.2;b=toe-tangent*1.2
    # The mark locates the pavilion, rather than prescribing a circular roof.
    # Preserve two distinct wing corners and a concave edge between them.
    back=[xyz(a)]+[[p[0],p[1],63.] for p in poly[1:4]]+[[1400.,435.,63.],[poly[5][0],poly[5][1],63.]]
    front=[xyz(b)]+[[p[0],p[1],63.] for p in reversed(poly[9:13])]+[[1320.,330.,63.],[poly[5][0],poly[5][1],63.]]
    d['back']=[tuple([i/float(len(back)-1)]+p) for i,p in enumerate(back)]
    d['front']=[tuple([i/float(len(front)-1)]+p) for i,p in enumerate(front)]
    outline=[hermite(d['back'],i/100.) for i in range(101)]+[hermite(d['front'],i/100.) for i in range(100,-1,-1)]
    d['outline']=[(p.X,p.Y) for p in outline]
    for i in range(15,50):
        t=i/100.;p=hermite(d['front'],t);z=ray_z(d['roof'],p.X,p.Y)
        if z is not None and p.Y<464:d['route_end_t']=t;break

def main_height(x,y):
    dx=x-1305.;dy=y-415.;a=(.21*dx-.9777*dy)/165.
    height=14.+3.*a*a
    height-=3.*math.exp(-((x-1330.)/70.)**2-((y-420.)/70.)**2)
    height+=11.*math.exp(-((x-1435.)/40.)**2-((y-530.)/32.)**2)
    height+=20.*math.exp(-((x-1488.)/38.)**2-((y-334.)/28.)**2)
    return height

def contact_weight(x,y):
    toe=state()['toe']
    return (1.-smooth((x-1230.)/55.))*smooth((y-470.)/max(1.,toe.Y-12.-470.))

def compact_point(p):
    # Scale the pavilion in plan, with an identity region at the existing road
    # contact. Elevations remain unchanged; all members are regenerated round.
    weight=contact_weight(p.X,p.Y)
    scale=PLAN_SCALE+(1.-PLAN_SCALE)*weight
    return G.Point3d(PLAN_CENTER[0]+scale*(p.X-PLAN_CENTER[0]),PLAN_CENTER[1]+scale*(p.Y-PLAN_CENTER[1]),p.Z)

def field(u,v):
    x=1100.+420.*u;y=270.+340.*v
    dx=x-1305.;dy=y-415.
    a=(.21*dx-.9777*dy)/165.;b=(.9777*dx+.21*dy)/180.
    # True saddle: opposite curvature signs, a raised right wing, open void
    # beneath the main body. The footprint is traced from the user's red mark.
    height=main_height(x,y)
    z=63.+height*state().get('height_scale',1.)
    # Two depressed parts of the shell form its other roof contacts, keeping
    # the main saddle airborne without adding a freestanding column forest.
    for ax,ay in [(1167.,374.),(1380.,535.)]:
        anchor_height=main_height(ax,ay)*state().get('height_scale',1.)
        z-=(anchor_height+.24)*math.exp(-((x-ax)/24.)**2-((y-ay)/24.)**2)
    foot_blend=(1.-smooth((x-1240.)/40.))*smooth((y-410.)/35.)
    toe=state()['toe']
    # Rise before the actual island edge; the former 62.76 m chord datum
    # buried the connecting lobe beneath the 63 m host roof.
    rise=smooth((toe.Y-y)/38.)
    contact_z=toe.Z+(CONTACT_CREST_Z-toe.Z)*rise
    end=state().get('route_end_t',.35)
    root_a=hermite(state()['back'],end);root_b=hermite(state()['front'],end)
    direction=root_a-root_b;direction.Z=0;direction.Unitize()
    root=root_b+direction*(1.2/PLAN_SCALE)
    touchdown=math.exp(-((x-root.X)/20.)**2-((y-root.Y)/20.)**2)
    contact_z-=CONTACT_LANDING_DEPTH*touchdown
    z=z*(1.-foot_blend)+contact_z*foot_blend
    p=G.Point3d(x,y,z)
    return compact_point(p)
def point(u,v,offset=0.):
    s=state()['surface'];p=s.PointAt(u,v)
    if offset:p+=s.NormalAt(u,v)*offset
    return p
def make_surface():
    d=state();nu,nv=65,49
    # A height graph keeps the plan mapping injective at the tight collapsed
    # corner. Greville XY controls reproduce the linear plan exactly; the
    # sculpted elevation remains a smooth native bicubic NURBS surface.
    d['height_scale']=1.
    raw=max(field(i/100.,j/80.).Z for i in range(101) for j in range(81) if inside(i/100.,j/80.))
    d['height_scale']=(87.7-63.)/(raw-63.)
    surface=G.NurbsSurface.Create(3,False,4,4,nu,nv)
    surface.KnotsU.CreateUniformKnots(1.);surface.KnotsV.CreateUniformKnots(1.)
    surface.SetDomain(0,G.Interval(0,1));surface.SetDomain(1,G.Interval(0,1))
    for i in range(nu):
        u=sum(surface.KnotsU[k] for k in range(i,i+3))/3.
        for j in range(nv):
            v=sum(surface.KnotsV[k] for k in range(j,j+3))/3.
            surface.Points.SetPoint(i,j,field(u,v))
    assert surface.IsValid
    d['surface']=surface
    outline=[hermite(d['back'],i/80.) for i in range(81)]
    outline.extend(hermite(d['front'],i/80.) for i in range(80,-1,-1))
    d['outline']=[(p.X,p.Y) for p in outline]
    add(surface.ToBrep(),'MasterContinuousSurface','00_\u63a7\u5236\u6bcd\u9762',metadata={'source':'parameters.json','role':'Hidden editable NURBS height-graph master'})
    poly=[]
    for p in outline:
        q=compact_point(G.Point3d(p.X,p.Y,0))
        if not poly or q.DistanceTo(poly[-1])>.0001:poly.append(q)
    poly.append(poly[0])
    add(G.PolylineCurve(poly),'ShellPlanBoundary','00_\u63a7\u5236\u6bcd\u9762','dark')
    sc.doc.Layers[layer(LAYER+'::00_\u63a7\u5236\u6bcd\u9762')].IsVisible=False
    sc.doc.Layers[layer(LAYER+'::00_\u63a7\u5236\u6bcd\u9762')].IsLocked=True
    sc.doc.Layers[layer(LAYER+'::00_\u63a7\u5236\u6bcd\u9762')].CommitChanges()
    samples=[point(i/100.,j/60.) for i in range(101) for j in range(61) if inside(i/100.,j/60.)]
    d['surface_z']=[min(p.Z for p in samples),max(p.Z for p in samples)]
    world_outline=[xyz(compact_point(G.Point3d(x,y,0)))[:2] for x,y in d['outline']]
    d['world_outline']=world_outline
    normals=[surface.NormalAt(i/20.,j/20.).Z for i in range(21) for j in range(21)]
    assert min(normals)>0.,'Plan remapping folded the NURBS surface'
    write('height_graph.json',{'source_xy_bounds':[1100.,270.,1520.,610.],'degree':[3,3],'control_counts':[nu,nv],'height_scale':d['height_scale'],'source_outline':d['outline'],'outline':world_outline,'plan_scale':PLAN_SCALE,'plan_center':PLAN_CENTER,'road_contact_preserved':True,'minimum_normal_z':min(normals),'method':'bicubic NURBS saddle, compact plan with a fixed road contact; members regenerated from the transformed master'})
    with io.open(OUT+'/parameters.json','r',encoding='utf-8') as file:parameters=json.load(file)
    parameters['back_boundary']=d['back'];parameters['front_boundary']=d['front']
    parameters['toe']=xyz(d['toe']);parameters['toe_tangent']=xyz(d['tangent'])
    parameters['route_end_t']=d.get('route_end_t',.35);parameters['placement_reference']='marked_placement.json'
    parameters['plan_scale']=PLAN_SCALE;parameters['plan_center']=PLAN_CENTER
    parameters['grid']={'type':'two_diagonal_families','source_spacing_m':GRID,'main_body_spacing_m':GRID*PLAN_SCALE}
    parameters['grid_spacing_m']=GRID*PLAN_SCALE;parameters['height_graph']='height_graph.json'
    parameters['contact_crest_chord_z_m']=CONTACT_CREST_Z
    parameters['contact_landing_depth_m']=CONTACT_LANDING_DEPTH
    parameters['contact_skin']='Complete opaque watertight shell skin; narrow road lip, full suspended corner, smooth roof landing'
    parameters['contact_skin_end_t']=d.get('route_end_t',.35)+.002
    write('parameters.json',parameters)
    return {'surface_valid':surface.IsValid,'surface_z':d['surface_z'],'contact_width':2.4,'plan_folds':False}

def uv_xy(x,y):return ((x-1100.)/420.,(y-270.)/340.)
def inside(u,v):
    x=1100.+u*420.;y=270.+v*340.;poly=state()['outline'];hit=False
    a=poly[-1]
    for b in poly:
        if (a[1]>y)!=(b[1]>y) and x<(b[0]-a[0])*(y-a[1])/(b[1]-a[1])+a[0]:hit=not hit
        a=b
    return hit

def tube(points,radius,sides=8):
    if len(points)<2:return None
    m=G.Mesh();last_x=None
    for i,p in enumerate(points):
        axis=points[min(len(points)-1,i+1)]-points[max(0,i-1)]
        if not axis.Unitize():return None
        x=G.Vector3d.CrossProduct(axis,G.Vector3d.ZAxis) if last_x is None else last_x-axis*G.Vector3d.Multiply(last_x,axis)
        if not x.Unitize():x=G.Vector3d.CrossProduct(axis,G.Vector3d.XAxis);x.Unitize()
        y=G.Vector3d.CrossProduct(axis,x);y.Unitize();last_x=x
        for j in range(sides):
            q=p+(x*math.cos(j*2*math.pi/sides)+y*math.sin(j*2*math.pi/sides))*radius
            m.Vertices.Add(q)
    for i in range(len(points)-1):
        for j in range(sides):m.Faces.AddFace(i*sides+j,i*sides+(j+1)%sides,(i+1)*sides+(j+1)%sides,(i+1)*sides+j)
    for j in range(1,sides-1):
        m.Faces.AddFace(0,j+1,j)
        start=(len(points)-1)*sides;m.Faces.AddFace(start,start+j,start+j+1)
    m.Normals.ComputeNormals();m.Compact();return m
def void(u,v):
    if u<.30 or v<.10 or v>.91:return False
    return ((u-.73)/.065)**2+((v-.55)/.14)**2<1 or ((u-.49)/.045)**2+((v-.72)/.12)**2<1
def axis_piece(uvs,radius,name,mat='ivory',offset=0.):
    pieces=[];current=[]
    for u,v in uvs:
        if not inside(u,v) or void(u,v):
            if len(current)>1:pieces.append(current)
            current=[]
        else:current.append((u,v))
    if len(current)>1:pieces.append(current)
    batch=G.Mesh()
    for piece in pieces:
        points=[point(u,v,offset) for u,v in piece]
        m=tube(points,radius)
        if m:batch.Append(m)
    if batch.Faces.Count:
        batch.Normals.ComputeNormals();batch.Compact()
        add(batch,name,'02_\u66f2\u9762\u94a2\u7f51\u67b6',mat,{'radius_m':radius,'surface_offset_m':offset})
def frame():
    d=state()
    # Diagonal families live on the same NURBS graph, clipped by the curved plan.
    for family in [1,-1]:
        for diagonal in range(-1500,2401,GRID):
            uv=[]
            for step in range(211):
                x=1100.+step*2.;y=family*x+diagonal
                if 270<=y<=610:uv.append(uv_xy(x,y))
            if len(uv)<2:continue
            axis_piece(uv,.19,'Diagrid_%d_%d'%(family,diagonal),'ivory')
            if ((diagonal+1500)//GRID)%2==0:axis_piece(uv,.13,'LowerChord_%d_%d'%(family,diagonal),'weathered',-.72)
    # Curved edge chords remain part of the same shell including the contact tip.
    for key,name in [('back','InnerRaisedEdge'),('front','OuterCollapsedEdge')]:
        coords=[hermite(d[key],i/300.) for i in range(301)]
        uv=[uv_xy(p.X,p.Y) for p in coords]
        # Boundary samples may differ by a microscopic winding tolerance.
        batch=G.Mesh();lower=G.Mesh()
        positions=[point(u,v) for u,v in uv]
        batch.Append(tube(positions,.29));lower.Append(tube([point(u,v,-.72) for u,v in uv],.17))
        add(batch,name,'02_\u66f2\u9762\u94a2\u7f51\u67b6','ivory')
        add(lower,name+'_Lower','02_\u66f2\u9762\u94a2\u7f51\u67b6','weathered')
        add(G.Curve.CreateInterpolatedCurve([point(u,v) for u,v in uv],3),name+'_Control','00_\u63a7\u5236\u6bcd\u9762','dark')
    webs=G.Mesh();nodes=G.Mesh()
    for i,x in enumerate(range(1110,1520,GRID)):
        for j,y in enumerate(range(280,610,GRID)):
            u,v=uv_xy(x,y)
            if not inside(u,v) or void(u,v):continue
            if (i+j)%2==0:
                a=point(u,v);uu,vv=uv_xy(x+5,y+5)
                if not inside(uu,vv):continue
                b=point(uu,vv,-.72)
                m=tube([a,b],.085,6)
                if m:webs.Append(m)
                nodes.Append(G.Mesh.CreateFromSphere(G.Sphere(a,.24),8,4))
    for m,name,mat in [(webs,'WebDiagonals','dark'),(nodes,'Nodes','weathered')]:
        m.Normals.ComputeNormals();m.Compact();add(m,name,'03_\u8282\u70b9\u4e0e\u8179\u6746',mat)
    sc.doc.Views.Redraw()
    return {'frame_objects':d['categories'].get('02_\u66f2\u9762\u94a2\u7f51\u67b6',0),'nodes':nodes.Vertices.Count,'chord_depth_m':.72}

def panel(uvs,name,mat,metadata=None):
    m=G.Mesh();count=len(uvs)
    for offset in [.29,.23]:
        for u,v in uvs:m.Vertices.Add(point(u,v,offset))
    for j in range(1,count-1):
        m.Faces.AddFace(0,j,j+1);m.Faces.AddFace(count,count+j+1,count+j)
    for j in range(count):m.Faces.AddFace(j,(j+1)%count,(j+1)%count+count,j+count)
    m.Normals.ComputeNormals();m.Compact()
    add(m,name,'04_\u6b8b\u5b58\u66f2\u9762\u8868\u76ae' if not name.startswith('ContactSkin') else '05_\u4e0b\u5782\u89d2\u90e8\u6b8b\u5b58\u9762\u677f',mat,metadata or {'surface_uv':json.dumps(uvs)})
def contact_section(t):
    d=state();a=hermite(d['back'],t);b=hermite(d['front'],t)
    # Infill the entire suspended corner. Narrow the surviving sheet only
    # after it reaches the island and merges with the broken roof cladding.
    fraction=1.-.72*smooth((t-.22)/.13)
    return b,b+(a-b)*fraction

def polygon_contains(x,y,polygon):
    hit=False;a=polygon[-1]
    for b in polygon:
        if (a[1]>y)!=(b[1]>y) and x<(b[0]-a[0])*(y-a[1])/(b[1]-a[1])+a[0]:hit=not hit
        a=b
    return hit

def contact_skin():
    d=state();longitudinal=144;transverse=36;end=d.get('route_end_t',.35)+.002
    mesh=G.Mesh();rows=[]
    for offset in [.29,.23]:
        for i in range(longitudinal+1):
            b,a=contact_section(end*i/longitudinal);row=[]
            for j in range(transverse+1):
                q=b+(a-b)*(j/float(transverse));u,v=uv_xy(q.X,q.Y)
                mesh.Vertices.Add(point(u,v,offset));row.append((u,v))
            if offset==.29:rows.append(row)
    stride=transverse+1;count=(longitudinal+1)*stride
    for i in range(longitudinal):
        for j in range(transverse):
            k=i*stride+j
            mesh.Faces.AddFace(k,k+1,k+stride+1,k+stride)
            mesh.Faces.AddFace(k+count,k+stride+count,k+stride+1+count,k+1+count)
    perimeter=list(range(stride))
    perimeter.extend(i*stride+transverse for i in range(1,longitudinal+1))
    perimeter.extend(longitudinal*stride+j for j in range(transverse-1,-1,-1))
    perimeter.extend(i*stride for i in range(longitudinal-1,0,-1))
    for a,b in zip(perimeter,perimeter[1:]+perimeter[:1]):mesh.Faces.AddFace(a,b,b+count,a+count)
    mesh.UnifyNormals();mesh.Normals.ComputeNormals();mesh.Compact()
    if mesh.SolidOrientation()<0:mesh.Flip(True,True,True)
    assert mesh.IsClosed and mesh.IsValid,'Continuous corner skin is not watertight'
    sid=add(mesh,'ContactSkin_Continuous','05_\u4e0b\u5782\u89d2\u90e8\u6b8b\u5b58\u9762\u677f','panel',
        {'role':'Complete opaque surviving curved shell skin, including all suspended bays','watertight':True,'minimum_contact_width_m':2.4,'collision_source':'Use this closed skin for later game collision, not frame tubes'})
    d['contact_skin_id']=str(sid);d['contact_skin_rows']=rows
    # Fine flush panel seams keep the repaired opaque sheet legible as the
    # pavilion's existing diagrid skin; they are decorative, not collisions.
    seams=G.Mesh()
    for family in [1,-1]:
        for diagonal in range(-1500,2401,GRID):
            previous=None
            for step in range(841):
                x=1100.+step*.5;y=family*x+diagonal
                if not polygon_contains(x,y,d['contact_skin_outline']):
                    previous=None;continue
                u,v=uv_xy(x,y);p=point(u,v,.294)
                actual=ray_z(mesh,p.X,p.Y)
                if actual is None:
                    previous=None;continue
                # Follow the finished polygonal skin, whose chord can differ
                # from the analytic master by centimetres. This avoids dashed
                # z-fighting on an otherwise flush continuous panel seam.
                p.Z=actual+.015
                if previous is not None:
                    old,ou,ov=previous;axis=p-old;axis.Unitize()
                    side=G.Vector3d.CrossProduct(axis,state()['surface'].NormalAt(u,v))
                    side.Unitize();side*=.04
                    k=seams.Vertices.Count
                    for q in [old-side,old+side,p+side,p-side]:seams.Vertices.Add(q)
                    seams.Faces.AddFace(k,k+1,k+2,k+3)
                previous=(p,u,v)
    seams.Normals.ComputeNormals();seams.Compact()
    add(seams,'ContactSkin_FlushPanelSeams','05_\u4e0b\u5782\u89d2\u90e8\u6b8b\u5b58\u9762\u677f','weathered',
        {'role':'Flush visual panel seams; exclude from gameplay collision','width_m':.08})
    return {'object':str(sid),'watertight':mesh.IsClosed,'quads':mesh.Faces.QuadCount}

def skin():
    d=state();kept=0;total=0
    # Continue a short distance beyond the landing so the curved sheet's
    # polygonal hem overlaps supported roof rather than ending at a ray seam.
    end=d.get('route_end_t',.35)+.002
    sections=[contact_section(end*i/144.) for i in range(145)]
    d['contact_skin_outline']=[(b.X,b.Y) for b,a in sections]+[(a.X,a.Y) for b,a in reversed(sections)]
    # Larger connected surviving patches with ragged margins; most bays stay open.
    # Diamond infill shares the two diagonal families, rather than square tiles.
    for i,k1 in enumerate(range(-1500,-450,GRID)):
        for j,k2 in enumerate(range(1340,2140,GRID)):
            x=(k2-k1)*.5;y=(k1+k2)*.5+GRID*.5
            u,v=uv_xy(x,y)
            if not inside(u,v):continue
            total+=1
            score=math.sin(u*19.+v*6.)*.45+math.cos(u*8.-v*12.)*.30
            weather=((i*73856093 ^ j*19349663 ^ 1030)%101)/100.
            wing=((x-1488.)/38.)**2+((y-334.)/28.)**2<1.1
            if void(u,v) or (score+.2*weather<.24 and not (wing and weather>.25)):continue
            radius=GRID*.5-.4
            uv=[uv_xy(x-radius,y),uv_xy(x,y-radius),uv_xy(x+radius,y),uv_xy(x,y+radius)]
            if not all(inside(uu,vv) for uu,vv in uv):continue
            if any(polygon_contains(1100.+uu*420.,270.+vv*340.,d['contact_skin_outline']) for uu,vv in uv):continue
            if weather>.88:uv=uv[:3]
            panel(uv,'Skin_%02d_%02d'%(i,j),'glass' if weather>.62 else 'panel');kept+=1
    # Surviving skin follows the shell geometry from road to supported roof.
    route=[]
    for i in range(37):
        t=d.get('route_end_t',.27)*i/36.;a=hermite(d['back'],t);b=hermite(d['front'],t)
        direction=a-b;direction.Z=0;width=direction.Length;direction.Unitize()
        # An original skin strip lies just inside the curved outer boundary.
        # Keep the original walking strip 2.4 m wide after the plan remapping.
        bu,bv=uv_xy(b.X,b.Y);outer_world=point(bu,bv)
        left=0.;right=width
        for iteration in range(18):
            distance=(left+right)*.5;candidate=b+direction*distance
            cu,cv=uv_xy(candidate.X,candidate.Y)
            if point(cu,cv).DistanceTo(outer_world)<2.4:left=distance
            else:right=distance
        inner=b+direction*right
        route.append((uv_xy(inner.X,inner.Y),uv_xy(b.X,b.Y)))
    contact_result=contact_skin()
    d['route']=[xyz(point((a[0]+b[0])*.5,(a[1]+b[1])*.5,.29)) for a,b in route]
    sc.doc.Views.Redraw();return {'retained_main_panels':kept,'main_bays':total,'continuous_skin':contact_result}

def supports():
    # Only short shoes anchor existing low shell locations to the actual roof.
    # They are architectural frame feet; the contact has no new bridge support.
    d=state();feet=[]
    for u in [d.get('route_end_t',.27),.40,.62,.84,1.]:
        p=hermite(d['front'],u);uv=uv_xy(p.X,p.Y)
        top=point(uv[0],uv[1],-.72);z=ray_z(d['roof'],top.X,top.Y)
        if z is None or top.Z<z:continue
        base=G.Point3d(top.X,top.Y,z+.05)
        if top.DistanceTo(base)>3.:continue
        shoe=G.Box(G.Plane(base,G.Vector3d.ZAxis),G.Interval(-.65,.65),G.Interval(-.65,.65),G.Interval(0,.16)).ToBrep()
        add(shoe,'RoofShoe_%g'%u,'06_\u5c4b\u9876\u77ed\u652f\u5ea7','weathered')
        if top.DistanceTo(base)>.17:add(tube([base+G.Vector3d(0,0,.16),top],.20),'RoofFoot_%g'%u,'06_\u5c4b\u9876\u77ed\u652f\u5ea7','ivory')
        feet.append(xyz(base))
    for i,(x,y) in enumerate([(1167.,374.),(1380.,535.)]):
        uu,vv=uv_xy(x,y);top=point(uu,vv)
        z=ray_z(d['roof'],top.X,top.Y);assert z is not None
        base=G.Point3d(top.X,top.Y,z+.03)
        shoe=G.Box(G.Plane(base,G.Vector3d.ZAxis),G.Interval(-1.1,1.1),G.Interval(-.6,.6),G.Interval(0,.13)).ToBrep()
        add(shoe,'CurvedShellShoe_%d'%i,'06_\u5c4b\u9876\u77ed\u652f\u5ea7','weathered')
        if top.Z>base.Z+.16:add(tube([base+G.Vector3d(0,0,.13),top],.20),'CurvedShellFoot_%d'%i,'06_\u5c4b\u9876\u77ed\u652f\u5ea7','ivory')
        feet.append(xyz(base))
    d['feet']=feet;return {'roof_shoes':feet}

def audit():
    d=state();invalid=[];triangles=0;oval_min=1e9
    for sid in d['objects']:
        o=sc.doc.Objects.FindId(System.Guid(sid));assert o,'New object missing'
        if not o.Geometry.IsValid:invalid.append(sid)
        if isinstance(o.Geometry,G.Mesh):
            triangles+=o.Geometry.Faces.TriangleCount+o.Geometry.Faces.QuadCount*2
            for p in o.Geometry.Vertices:oval_min=min(oval_min,((float(p.X)-1086.01)/84.)**2+((float(p.Y)-302.52)/55.8)**2)
    changed=[]
    for sid,crc in d['before'].items():
        o=sc.doc.Objects.FindId(System.Guid(sid))
        if o is None or int(o.Geometry.DataCRC(0))!=crc:changed.append(sid)
    assert not changed,'Existing source geometry changed: '+str(changed)
    assert not invalid,'Invalid generated geometry'
    assert oval_min>1.05,'Shell intrudes into the preserved oval footprint'
    points=[G.Point3d(*p) for p in d['route']];grade=0.
    for a,b in zip(points,points[1:]):grade=max(grade,abs(b.Z-a.Z)/max(.001,math.hypot(b.X-a.X,b.Y-a.Y)))
    end=points[-1];roof_z=ray_z(d['roof'],end.X,end.Y)
    assert roof_z is not None,'Collapsed corner does not reach supported roof'
    toe=d['toe'];tangent=d['tangent']
    contact=[point(*(uv_xy(toe.X+tangent.X*(-1.2+j*.12),toe.Y+tangent.Y*(-1.2+j*.12))+(.29,))) for j in range(21)]
    asphalt_hits=[]
    for p in contact:
        road_z=ray_z(d['road'],p.X,p.Y)
        if road_z is not None:asphalt_hits.append(xyz(p))
    contact_width=contact[0].DistanceTo(contact[-1])
    assert 2.2<contact_width<2.6,'Human-scale contact width changed'
    assert not asphalt_hits,'Contact overlaps the asphalt'
    contact_height_errors=[];contact_plan_gaps=[]
    for p in contact:
        road_point=d['road'].ClosestMeshPoint(p,0).Point
        contact_height_errors.append(p.Z-road_point.Z)
        contact_plan_gaps.append(math.hypot(p.X-road_point.X,p.Y-road_point.Y))
    assert max(abs(h) for h in contact_height_errors)<.10,'Contact has a step above the actual road'
    assert max(contact_plan_gaps)<.06,'Contact stops short of the actual road edge'
    assert abs(end.Z-roof_z)<.15,'Walking skin floats above the roof'
    assert grade<.25,'Incidental walking surface is too steep'
    skin=sc.doc.Objects.FindId(System.Guid(d['contact_skin_id'])).Geometry
    assert skin.IsClosed and not skin.GetNakedEdges(),'The walking skin has open edges'
    skin_misses=[];clearance=[];largest_skin_error=0.;route_sample_count=0
    for row_index,row in enumerate(d['contact_skin_rows']):
        # MeshRay on its floating-point boundary can miss by submillimetres;
        # check interiors of every transverse bay, not exact boundary vertices.
        if row_index==len(d['contact_skin_rows'])-1:continue
        next_row=d['contact_skin_rows'][row_index+1]
        for j in range(len(row)-1):
            u=(row[j][0]+row[j+1][0]+next_row[j][0]+next_row[j+1][0])*.25
            v=(row[j][1]+row[j+1][1]+next_row[j][1]+next_row[j+1][1])*.25
            p=point(u,v,.29);actual=ray_z(skin,p.X,p.Y);route_sample_count+=1
            if actual is None:skin_misses.append([row_index,j]);continue
            largest_skin_error=max(largest_skin_error,abs(actual-p.Z))
            roof=ray_z(d['roof'],p.X,p.Y)
            if roof is not None and p.DistanceTo(end)>15.:clearance.append(actual-roof)
    assert not skin_misses,'Missing walking skin bays: '+str(skin_misses[:8])
    assert min(clearance)>1.,'The lifted transition is still buried in the host roof'
    # Check both margins and center of a 2.4 m route on the actual mesh,
    # including the entire road contact and the roof landing.
    route_grades=[];landing_errors=[];minimum_width=1e9;last=None
    for i in range(145):
        t=d.get('route_end_t',.35)*i/144.
        a=hermite(d['back'],t);b=hermite(d['front'],t)
        direction=a-b;direction.Z=0;direction.Unitize()
        outer=point(*(uv_xy(b.X,b.Y)+(.29,)));low=0.;high=(a-b).Length
        for iteration in range(24):
            distance=(low+high)*.5;q=b+direction*distance
            candidate=point(*(uv_xy(q.X,q.Y)+(.29,)))
            if math.hypot(candidate.X-outer.X,candidate.Y-outer.Y)<2.4:low=distance
            else:high=distance
        heights=[]
        for fraction in [.015,.5,.985]:
            q=b+direction*high*fraction;p=point(*(uv_xy(q.X,q.Y)+(.29,)))
            actual=ray_z(skin,p.X,p.Y);assert actual is not None,'Walking corridor has a hole'
            p.Z=actual;heights.append(p)
            if i==144:landing_errors.append(actual-ray_z(d['roof'],p.X,p.Y))
        if last:
            for old,new in zip(last,heights):
                route_grades.append(abs(new.Z-old.Z)/max(.001,math.hypot(new.X-old.X,new.Y-old.Y)))
        last=heights
    assert max(route_grades)<.25,'Actual walking mesh has an excessive slope'
    assert min(landing_errors)>-.02 and max(landing_errors)<.10,'Walking mesh does not meet the roof smoothly'
    verification={'skin_watertight':True,'interior_bays_tested':route_sample_count,'missing_bays':skin_misses,
        'minimum_roof_clearance_outside_landing_15m':min(clearance),'maximum_master_to_skin_error_m':largest_skin_error,
        'walk_corridor_width_m':2.4,'walk_corridor_samples':145*3,'maximum_actual_mesh_grade':max(route_grades),
        'road_contact_height_errors_m':contact_height_errors,'road_contact_plan_gaps_m':contact_plan_gaps,
        'landing_height_errors_m':landing_errors,'pre_revision_backup':d.get('pre_transition_backup','')}
    write('transition_verification.json',verification)
    body=[compact_point(G.Point3d(x,y,0)) for x,y in d['outline'] if contact_weight(x,y)<.001]
    body_bounds=[max(p.X for p in body)-min(p.X for p in body),max(p.Y for p in body)-min(p.Y for p in body)]
    result={'document':d['document'],'backup':d['backup'],'objects':len(d['objects']),'categories':d['categories'],'triangles':triangles,
        'surface_elevation_m':d['surface_z'],'roof_datum_m':63.,'approximate_rise_m':d['surface_z'][1]+.29-63.,
        'contact_width_m':contact_width,'contact_points':list(map(xyz,contact)),'plan_scale':PLAN_SCALE,'main_body_bounds_xy_m':body_bounds,'main_body_area_scale':PLAN_SCALE**2,'precompact_backup':d.get('precompact_backup',''),
        'contact_asphalt_samples':asphalt_hits,'maximum_route_grade':grade,'route_end':xyz(end),'route_end_roof_z':roof_z,
        'source_geometry_unchanged':not changed,'oval_and_interior_unchanged':True,'minimum_oval_ellipse_q':oval_min,'placement_reference':'marked_placement.json','invalid':invalid,'feet':d.get('feet',[]),'object_ids':d['objects'],'transition_verification':verification}
    write('model_report.json',result);write('walking_surface_samples.json',d['route'])
    return {k:v for k,v in result.items() if k not in ['object_ids','contact_points']}

def capture(which='overview'):
    vp=sc.doc.Views.ActiveView.ActiveViewport
    if which.startswith('transition'):
        view=state()['transition_view'];eye=G.Point3d(*view['eye']);target=G.Point3d(*view['target'])
    elif which.startswith('compact'):
        view=state()['compact_view'];eye=G.Point3d(*view['eye']);target=G.Point3d(*view['target'])
    elif which=='overview':eye=G.Point3d(960,185,165);target=G.Point3d(1325,415,75)
    elif which=='marked':
        with io.open(OUT+'/marked_placement.json','r',encoding='utf-8') as f:mark=json.load(f)
        eye=G.Point3d(*mark['camera']);target=G.Point3d(*mark['target'])
    elif which=='contact':eye=G.Point3d(1135,655,110);target=G.Point3d(1210,505,64)
    elif which=='roof':eye=G.Point3d(1120,560,380);target=G.Point3d(1110,300,68)
    else:raise ValueError(which)
    vp.ChangeToPerspectiveProjection(True,38)
    vp.SetCameraLocations(target,eye);vp.DisplayMode=Rhino.Display.DisplayModeDescription.FindByName('Rendered')
    sc.doc.Objects.UnselectAll();sc.doc.Views.Redraw()
    sc.doc.NamedViews.Add('IslandSaddle_'+which+'_1030',vp.Id)
    cap=Rhino.Display.ViewCapture();cap.Width=1700;cap.Height=1050
    cap.DrawGrid=False;cap.DrawAxes=False;cap.DrawGridAxes=False
    bitmap=cap.CaptureToBitmap(sc.doc.Views.ActiveView);assert bitmap
    path=OUT+'/'+which+'.png';bitmap.Save(path,System.Drawing.Imaging.ImageFormat.Png);bitmap.Dispose()
    return {'capture':path}
def save():
    report=audit();d=state()
    options=Rhino.FileIO.FileWriteOptions();options.SuppressDialogBoxes=True
    standalone=OUT+'/island_saddle_shell.3dm'
    revision=2
    while os.path.exists(standalone):
        standalone=OUT+'/island_saddle_shell_v%d.3dm'%revision;revision+=1
    temporary_layers=[]
    for item in sc.doc.Layers:
        if item.FullPath.startswith(LAYER+'::') and (item.Name.startswith('00_') or item.Name.startswith('07_')):
            temporary_layers.append((item.Index,item.IsVisible,item.IsLocked))
            item.IsVisible=True;item.IsLocked=False;item.CommitChanges()
    sc.doc.Objects.UnselectAll()
    try:
        for sid in d['objects']:sc.doc.Objects.Select(System.Guid(sid))
        options.WriteSelectedObjectsOnly=True
        assert sc.doc.Write3dmFile(standalone,options),'Standalone save failed'
    finally:
        for index,visible,locked in temporary_layers:
            item=sc.doc.Layers[index];item.IsVisible=visible;item.IsLocked=locked;item.CommitChanges()
        sc.doc.Objects.UnselectAll()
    file=Rhino.FileIO.File3dm.Read(standalone);assert file
    for item in file.AllLayers:
        if (item.Name.startswith('00_') or item.Name.startswith('07_')) and 'Saddle' not in item.Name:
            item.IsVisible=False;item.IsLocked=True
    assert file.Write(standalone,8),'Standalone layer-state save failed'
    assert sc.doc.Path==d['document']
    assert Rhino.RhinoApp.RunScript('_-Save _Enter',False)
    assert not sc.doc.Modified,'Native save failed'
    return {'saved_document':d['document'],'standalone':standalone,'objects':len(d['objects'])}
