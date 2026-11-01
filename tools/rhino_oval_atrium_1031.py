# -*- coding: utf-8 -*-
"""Native oval atrium: true excavated shell, interrupted descent and road exit.

Run stages separately in Rhino. Keep tentative booleans in sticky memory; commit
only verified geometry. Existing sources retain their IDs. All new parts have
one feature tag and an explicit inventory, including hidden collision helpers.
"""
from __future__ import unicode_literals, division
import Rhino,scriptcontext as sc,System,math,json,io,os,shutil
from System.Drawing import Color
G=Rhino.Geometry
ROOT='D:/Prism Route/prism-route'
OUT=ROOT+'/docs/oval_atrium_1031'
TAG='oval_atrium_1031'
LAYER='\u5efa\u7b51::\u692d\u5706\u4e0b\u884c\u4e2d\u5ead'
CX,CY=1086.01,302.52
ROOF,RIM,FLOOR=63.,72.6,35.
SOURCE={'oval':'78d43939-e418-428e-aad5-d51b08c73985',
        'roof':'ce36cdce-398b-44f5-b0b4-fe7f258106cf',
        'core':'de67bdb9-1d24-4d78-b864-a5f6bbd48ce6',
        'road':'0295f8be-063a-4f5d-90ff-5dabbf9fad42'}
EXIT=G.Point3d(1025.98919758323,369.773703213094,35.)
EXIT_DIR=EXIT-G.Point3d(CX,CY,35);EXIT_DIR.Unitize()
EXIT_ANGLE=math.degrees(math.atan2(EXIT_DIR.Y,EXIT_DIR.X))
ENTRY=-45.
WIDTH=9.
TOL=.005

def state():return sc.sticky[TAG]
def xyz(p):return [float(p.X),float(p.Y),float(p.Z)]
def write(name,value):
    with io.open(OUT+'/'+name,'w',encoding='utf-8') as f:
        f.write(json.dumps(value,ensure_ascii=False,indent=2,separators=(',',': ')))
def active_objects():
    e=Rhino.DocObjects.ObjectEnumeratorSettings()
    e.NormalObjects=True;e.HiddenObjects=True;e.LockedObjects=True
    return [o for o in sc.doc.Objects.GetObjectList(e) if not o.IsDeleted]
def obj(key):return sc.doc.Objects.FindId(System.Guid(SOURCE.get(key,key)))
def ellipse(a,b,z):return G.Ellipse(G.Plane(G.Point3d(CX,CY,z),G.Vector3d.ZAxis),a,b).ToNurbsCurve()
def solid(b):
    assert b and b.IsValid and b.IsSolid,'Expected a valid closed Brep'
    if b.SolidOrientation==G.BrepSolidOrientation.Inward:b.Flip()
    return b
def cylinder(a,b,z0,z1):return solid(G.Extrusion.Create(ellipse(a,b,z0),z1-z0,True).ToBrep())
def loft(rows):
    result=G.Brep.CreateFromLoft([ellipse(a,b,z) for a,b,z in rows],
        G.Point3d.Unset,G.Point3d.Unset,G.LoftType.Normal,False)
    assert result and len(result)==1 and result[0].IsValid
    return result[0]
def annular_shell(outer,inner):
    pieces=[loft(outer),loft(inner)]
    for index in [0,-1]:
        a,b,z=outer[index];aa,bb,zz=inner[index];assert abs(z-zz)<.001
        caps=G.Brep.CreatePlanarBreps([ellipse(a,b,z),ellipse(aa,bb,z)],TOL)
        assert caps and len(caps)==1;pieces.append(caps[0])
    joined=G.Brep.JoinBreps(pieces,TOL);assert joined and len(joined)==1
    return solid(joined[0])
def box_corridor(start,end,width,z0,z1):
    direction=end-start;direction.Z=0;length=direction.Length;direction.Unitize()
    transverse=G.Vector3d(-direction.Y,direction.X,0)
    plane=G.Plane(G.Point3d(start.X,start.Y,z0),direction,transverse)
    return solid(G.Box(plane,G.Interval(0,length),G.Interval(-width/2,width/2),G.Interval(0,z1-z0)).ToBrep())
def difference(source,cutter,label):
    pieces=G.Brep.CreateBooleanDifference(source,cutter,TOL)
    assert pieces and len(pieces)==1,label+' boolean did not return one body'
    return solid(pieces[0])
def prepare():
    assert TAG not in sc.sticky,'Atrium already initialized; inspect before rebuilding'
    assert not any(o.Attributes.GetUserString('feature')==TAG for o in active_objects())
    assert str(sc.doc.ModelUnitSystem)=='Meters'
    options=Rhino.FileIO.FileWriteOptions();options.SuppressDialogBoxes=True
    backup='D:/Prism Route/archive/oval_atrium_1031/map_before_atrium.3dm'
    assert not os.path.exists(backup),'Keep the existing atrium backup'
    objects=active_objects();settings=Rhino.FileIO.SerializationOptions()
    before={str(o.Id):{'crc':int(o.Geometry.DataCRC(0)),'attributes':o.Attributes.ToJSON(settings)} for o in objects}
    assert sc.doc.Write3dmFile(backup,options),'Full current-scene backup failed'
    sc.sticky[TAG]={'before':before,'objects':[],'categories':{},'materials':{},
        'backup':backup,'document':sc.doc.Path,'prepared':{},'routes':{},'modified_sources':[]}
    d=state()
    write('parameters.json',{'center':[CX,CY],'existing_outer_oval':[168.,111.6],
        'expanded_flat_rim':[132.,90.],'roof_opening':[110.,66.],'internal_excavation':[140.,96.],
        'levels':{'roof':ROOF,'rim':RIM,'first_landing':69.8,'second_landing':57.8,'third_landing':45.8,'exit':FLOOR},
        'drops':[[72.6,69.8],[60.6,57.8],[48.6,45.8]],'gallery_width':WIDTH,'entry_stair_width':8.,
        'exit_road_id':SOURCE['road'],'exit_edge':xyz(EXIT),'exit_direction':xyz(EXIT_DIR),
        'no_game_import':True,'preserve_planting':True})
    return {'backup':backup,'source_count':len(before),'modified_before_start':sc.doc.Modified}
def prepare_shell():
    d=state();cavity=cylinder(70.,48.,34.15,74.)
    raised=annular_shell([(84.,55.8,63.),(82.3,54.6,64.2),(79.,53.4,67.),(66.,45.,72.6)],
                         [(70.,48.,63.),(55.,33.,72.6)])
    roof=difference(obj('roof').Geometry,cavity,'roof oculus')
    d['prepared'].update(cavity=cavity,oval=raised,roof=roof)
    write('shell_preflight.json',{'oval_solid':raised.IsSolid,'roof_solid':roof.IsSolid,
        'roof_faces_after':roof.Faces.Count,'expanded_rim_clear_width_m':[11.,12.]})
    return {'raised_oval_valid':raised.IsValid,'raised_oval_faces':raised.Faces.Count,'roof_opening_valid':roof.IsSolid}
def prepare_core():
    d=state();cavity=d['prepared']['cavity']
    core=difference(obj('core').Geometry,cavity,'atrium excavation')
    start=G.Point3d(CX,CY,35)+EXIT_DIR*42
    end=EXIT+EXIT_DIR*.35
    tunnel=box_corridor(start,end,8.,34.82,40.25)
    core=difference(core,tunnel,'level exit tunnel')
    d['prepared'].update(core=core,tunnel=tunnel,exit_start=start,exit_end=end)
    return {'hollow_core_valid':core.IsSolid,'faces':core.Faces.Count,
        'cut_tunnel_length':start.DistanceTo(end),'exit_level':35.}

def layer(path):
    index=sc.doc.Layers.FindByFullPath(path,-1)
    if index>=0:return index
    parent=System.Guid.Empty
    if '::' in path:parent=sc.doc.Layers[layer(path.rsplit('::',1)[0])].Id
    item=Rhino.DocObjects.Layer();item.Name=path.rsplit('::',1)[-1]
    if parent!=System.Guid.Empty:item.ParentLayerId=parent
    return sc.doc.Layers.Add(item)
def material(name,rgb,rough,metal=0.,opacity=1.):
    existing=sc.doc.Materials.Find('PR_Atrium_'+name,True)
    if existing>=0:return existing
    item=Rhino.DocObjects.Material();item.Name='PR_Atrium_'+name
    item.DiffuseColor=Color.FromArgb(*rgb);item.Transparency=1.-opacity
    item.ToPhysicallyBased();p=item.PhysicallyBased
    p.BaseColor=Rhino.Display.Color4f(rgb[0]/255.,rgb[1]/255.,rgb[2]/255.,1.)
    p.Roughness=rough;p.Metallic=metal;p.Opacity=opacity
    return sc.doc.Materials.Add(item)
def add(geometry,name,category,mat='ivory',metadata=None):
    assert geometry and geometry.IsValid,'Invalid geometry: '+name
    at=Rhino.DocObjects.ObjectAttributes();at.Name='PR_Atrium_'+name
    at.LayerIndex=layer(LAYER+'::'+category);at.MaterialIndex=state()['materials'][mat]
    at.MaterialSource=Rhino.DocObjects.ObjectMaterialSource.MaterialFromObject
    at.ObjectColor=sc.doc.Materials[at.MaterialIndex].DiffuseColor
    at.SetUserString('feature',TAG);at.SetUserString('category',category)
    if metadata:
        for key,value in metadata.items():at.SetUserString(key,str(value))
    gid=sc.doc.Objects.Add(geometry,at);assert gid!=System.Guid.Empty
    d=state();d['objects'].append(str(gid));d['categories'][category]=d['categories'].get(category,0)+1
    return gid
def point(a,b,z,angle):
    t=math.radians(angle);return G.Point3d(CX+a*math.cos(t),CY+b*math.sin(t),z)
def wall_axes(z):
    f=max(0.,min(1.,(z-63.)/9.6))
    return 70.-15.*f,48.-15.*f
def gallery_margin(z):
    t=max(0.,min(1.,(65.-z)/2.));t=t*t*(3.-2.*t)
    return .25+1.2*t
def mesh_finish(m):
    m.Vertices.CombineIdentical(True,True);m.UnifyNormals();m.Normals.ComputeNormals();m.Compact()
    assert m.IsValid and m.IsClosed,'Expected closed valid mesh'
    if m.SolidOrientation()<0:m.Flip(True,True,True)
    return m
def band_mesh(samples,thickness=.55):
    # Samples are ordered outer/inner cross-sections of a curved slab.
    m=G.Mesh()
    for outer,inner in samples:
        for p in [outer,inner,G.Point3d(outer.X,outer.Y,outer.Z-thickness),G.Point3d(inner.X,inner.Y,inner.Z-thickness)]:m.Vertices.Add(p)
    for i in range(len(samples)-1):
        j=i*4;k=j+4
        for face in [(j,k,k+1,j+1),(j+2,j+3,k+3,k+2),(j,j+2,k+2,k),(j+1,k+1,k+3,j+3)]:m.Faces.AddFace(*face)
    m.Faces.AddFace(0,1,3,2);j=(len(samples)-1)*4;m.Faces.AddFace(j,j+2,j+3,j+1)
    return mesh_finish(m)
def gallery_samples(start,end,z,width=WIDTH):
    n=max(2,int(math.ceil((end-start)/1.5)))
    a,b=wall_axes(z);margin=gallery_margin(z);a-=margin;b-=margin
    return [(point(a,b,z,start+(end-start)*i/n),point(a-width,b-width,z,start+(end-start)*i/n)) for i in range(n+1)]
def pipe_mesh(start,end,r):
    v=end-start
    if v.Length<.001:return G.Mesh()
    body=G.Cylinder(G.Circle(G.Plane(start,v),r),v.Length).ToBrep(True,True)
    params=G.MeshingParameters.FastRenderMesh;result=G.Mesh()
    for m in G.Mesh.CreateFromBrep(body,params):result.Append(m)
    return result
def stage(geom,name,category,mat='ivory',metadata=None):
    assert geom.IsValid,name
    state().setdefault('parts',[]).append((geom,name,category,mat,metadata or {}))
def railing(samples,inner=True,glass=True):
    steel=G.Mesh();panels=G.Mesh();edge=[row[1 if inner else 0] for row in samples]
    for i in range(len(edge)-1):
        a,b=edge[i],edge[i+1];aa=a+G.Vector3d(0,0,1.12);bb=b+G.Vector3d(0,0,1.12)
        steel.Append(pipe_mesh(aa,bb,.045))
        if i%2==0 or i==len(edge)-2:steel.Append(pipe_mesh(a,aa,.045))
        if glass and i%7 not in [5,6]:
            va=G.Vector3d(a.X-CX,a.Y-CY,0);va.Unitize()
            vb=G.Vector3d(b.X-CX,b.Y-CY,0);vb.Unitize()
            p=a+G.Vector3d(0,0,1.02);q=b+G.Vector3d(0,0,1.02)
            panel=band_mesh([(p+va*.04,p-va*.04),(q+vb*.04,q-vb*.04)],.86)
            panels.Append(panel)
    return steel,panels
def prepare_routes():
    d=state();assert not d.get('parts'),'Inspect staged parts before retrying'
    liner=annular_shell([(70,48,34.2),(70,48,63)],[(69,47,34.2),(69,47,63)])
    liner=difference(liner,d['prepared']['tunnel'],'wall exit')
    stage(liner,'Elliptical_wall_liner','01_structure')
    stage(cylinder(69,47,34.2,35),'Lower_hall_floor','02_platforms','floor')
    end=d['prepared']['exit_end'];start=d['prepared']['exit_start']
    stage(box_corridor(start,end,7.8,34.2,35),'Level_road_connector','06_road_exit','floor')
    stages=[(-55.,90.,123.,135.,69.8,60.6),
            (123.,270.,303.,315.,57.8,48.6),
            (303.,EXIT_ANGLE+317.,EXIT_ANGLE+350.,EXIT_ANGLE+360.,45.8,35.)]
    allrails=G.Mesh();allglass=G.Mesh();allbrackets=G.Mesh()
    route_data=[]
    for index,(a0,a1,a2,a3,top,bottom) in enumerate(stages):
        first=gallery_samples(a0,a1,top);last=gallery_samples(a2,a3,bottom)
        stage(band_mesh(first),'Gallery_%d'%(index+1),'02_platforms','floor')
        stage(band_mesh(last),'Departure_%d'%(index+1),'02_platforms','floor')
        count=int(math.ceil((top-bottom)/.16));riser=(top-bottom)/count
        steps=G.Mesh();smooth=[]
        for i in range(count+1):
            t=i/count;angle=a1+(a2-a1)*t;z=top-(top-bottom)*t
            wa,wb=wall_axes(z);margin=gallery_margin(z)
            outer=point(wa-margin,wb-margin,z,angle);inner=point(wa-margin-WIDTH,wb-margin-WIDTH,z,angle)
            smooth.append((outer,inner))
        for i in range(count):
            section=[];z=top-riser*i
            for outer,inner in smooth[i:i+2]:section.append((G.Point3d(outer.X,outer.Y,z),G.Point3d(inner.X,inner.Y,z)))
            steps.Append(band_mesh(section,.5+riser))
        stage(mesh_finish(steps),'Helical_treads_%d'%(index+1),'03_stairs','ivory',{'collision':'visual_only','risers':count,'riser_m':riser})
        stage(band_mesh(smooth,.12),'Helical_smooth_%d-colonly'%(index+1),'09_smooth_collision','floor',{'collision':'colonly','width_m':WIDTH,'risers':count})
        # Guard the void edges continuously, but leave drop departures open.
        combined=first+smooth[1:]+last[1:]
        for inner in [True,False]:
            rails,panels=railing(combined,inner,inner)
            allrails.Append(rails);allglass.Append(panels)
        a,b=first[0]
        for p,q in [(a+G.Vector3d(0,0,1.12),b+G.Vector3d(0,0,1.12)),(a,a+G.Vector3d(0,0,1.12)),(b,b+G.Vector3d(0,0,1.12))]:allrails.Append(pipe_mesh(p,q,.045))
        for j in range(2,len(first)-2,7):
            o,inn=first[j];rad=G.Vector3d(o.X-CX,o.Y-CY,0);rad.Unitize()
            anchor=o+rad*1.2-G.Vector3d(0,0,2.8)
            allbrackets.Append(pipe_mesh(inn-G.Vector3d(0,0,.5),anchor,.12))
        route_data.append({'index':index+1,'angles':[a0,a1,a2,a3],'elevations':[top,bottom],
            'stair_risers':count,'stair_riser_m':riser,'width_m':WIDTH,'samples':[[xyz(o),xyz(i)] for o,i in combined]})
    stage(mesh_finish(allrails),'Gallery_guardrails','04_metal','steel')
    stage(mesh_finish(allglass),'Gallery_glass_balustrades','05_glass','glass')
    stage(mesh_finish(allbrackets),'Gallery_wall_brackets','04_metal','steel')
    d['routes']['internal']=route_data
    return {'staged_parts':len(d['parts']),'flights':len(stages),'risers':[x['stair_risers'] for x in route_data]}
def outside_axes(z):
    if z<=63.0001:return 84.,55.8
    if z>=72.5999:return 66.,45.
    # Query the actual curved shoulder, not a linear approximation of loft rows.
    plane=G.Plane(G.Point3d(CX,CY,z),G.Vector3d.ZAxis)
    ok,curves,points=G.Intersect.Intersection.BrepPlane(state()['prepared']['oval'],plane,TOL)
    assert ok and curves,'Missing shoulder section'
    bounds=[c.GetBoundingBox(True) for c in curves]
    return max((b.Max.X-b.Min.X)/2 for b in bounds),max((b.Max.Y-b.Min.Y)/2 for b in bounds)
def prepare_entry():
    count=60;steps=G.Mesh();smooth=[];bottom=63.
    for i in range(count+1):
        t=i/count;z=63.+9.6*t;angle=ENTRY-40.+40.*t
        a,b=outside_axes(z);smooth.append((point(a+8.6,b+8.6,z,angle),point(a+.35,b+.35,z,angle)))
    for i in range(count):
        z=63.+9.6*(i+1)/count
        section=[(G.Point3d(o.X,o.Y,z),G.Point3d(inn.X,inn.Y,z)) for o,inn in smooth[i:i+2]]
        # Each closed tread rests on the roof: no floating thin stairs.
        steps.Append(band_mesh(section,z-62.85))
    stage(mesh_finish(steps),'Exterior_sweeping_steps','03_stairs','ivory',{'collision':'visual_only','risers':60,'riser_m':.16})
    stage(band_mesh(smooth,.12),'Exterior_smooth-colonly','09_smooth_collision','floor',{'collision':'colonly'})
    # A radial head landing spans from the outer stair to the actual drop lip.
    tangent=G.Vector3d(-math.sin(math.radians(ENTRY)),math.cos(math.radians(ENTRY)),0)
    start=point(70.45,49.45,72.6,ENTRY);end=point(55.,33.,72.6,ENTRY)
    rows=[(start+tangent*4.3,start-tangent*4.3),(end+tangent*4.3,end-tangent*4.3)]
    stage(band_mesh(rows,.5),'Entry_head_landing','02_platforms','floor')
    rails=G.Mesh();glass=G.Mesh()
    for inside in [False,True]:
        m,g=railing(smooth,inside,False);rails.Append(m)
        # Side guards stop at the drop edge; there is no crossbar across it.
        m,g=railing(rows,inside,False);rails.Append(m)
    stage(mesh_finish(rails),'Entry_guardrails','04_metal','steel')
    state()['routes']['external']={'risers':count,'riser_m':.16,'width_m':8.25,'start':xyz(point(88.45,60.25,63,ENTRY-40)),
        'drop_lip':xyz(end),'samples':[[xyz(o),xyz(i)] for o,i in smooth]}
    return {'staged_parts':len(state()['parts']),'entry_risers':count,'rise':9.6}

def prepare_details():
    ribs=G.Mesh();bands=G.Mesh()
    for angle in range(0,360,15):
        rows=[]
        for z in [35.,45.,57.,63.,65.,67.,69.,71.,72.6]:
            a,b=wall_axes(z);rows.append(point(a-.12,b-.12,z,angle))
        for a,b in zip(rows,rows[1:]):ribs.Append(pipe_mesh(a,b,.14))
    for z in [35.15,45.1,57.1,63.05,72.65]:
        a,b=wall_axes(z);pts=[point(a-.12,b-.12,z,i*2.) for i in range(181)]
        for p,q in zip(pts,pts[1:]):bands.Append(pipe_mesh(p,q,.115 if z<70 else .16))
    stage(mesh_finish(ribs),'Curved_wall_ribs','04_metal','steel')
    stage(mesh_finish(bands),'Elliptical_edge_beams','04_metal','steel')
    rim=[]
    for i in range(201):
        angle=ENTRY+6.5+347.*i/200.
        p=point(55.22,33.22,72.6,angle);rim.append((p,p))
    metal,glass=railing(rim,True,True)
    stage(mesh_finish(metal),'Oculus_guardrails_except_entry','04_metal','steel')
    stage(mesh_finish(glass),'Oculus_glass_except_entry','05_glass','glass')
    # Shallow architectural floor inlays leave the hall free for later gameplay.
    for i,(a,b) in enumerate([(45.,28.),(24.,14.)]):
        inlay=annular_shell([(a,b,35.002),(a,b,35.014)],[(a-.22,b-.22,35.002),(a-.22,b-.22,35.014)])
        stage(inlay,'Floor_inlay_%d'%i,'02_platforms','steel')
    # A short covered portal through the solid island, open at both ends.
    d=state();s=d['prepared']['exit_start'];e=d['prepared']['exit_end']
    normal=G.Vector3d(-EXIT_DIR.Y,EXIT_DIR.X,0)
    portal_end=G.Point3d(CX,CY,35.)+EXIT_DIR*65.7
    # The road is separated from the solid core: finish the portal at the facade,
    # then use a short, open framed connector at precisely the road elevation.
    for side in [-1,1]:
        offset=normal*side*3.96
        a=s+offset;b=portal_end+offset
        stage(box_corridor(a,b,.24,35.,40.12),'Portal_side_%d'%side,'06_road_exit','ivory')
    stage(box_corridor(s,portal_end,8.1,40.03,40.24),'Portal_ceiling','06_road_exit','ivory')
    portal=G.Mesh()
    for t in [0.,.36,.72,.985]:
        mid=s+(portal_end-s)*t
        a=mid-normal*3.82;b=mid+normal*3.82
        aa=a+G.Vector3d(0,0,4.82);bb=b+G.Vector3d(0,0,4.82)
        for p,q in [(a,aa),(aa,bb),(bb,b)]:portal.Append(pipe_mesh(p,q,.09))
    stage(mesh_finish(portal),'Portal_frames','04_metal','steel')
    bridge_rails=G.Mesh();bridge_braces=G.Mesh()
    for side in [-1,1]:
        a=portal_end+normal*side*3.8;b=e+normal*side*3.8
        n=10
        for i in range(n):
            p=a+(b-a)*i/n;q=a+(b-a)*(i+1)/n
            aa=p+G.Vector3d(0,0,1.15);bb=q+G.Vector3d(0,0,1.15)
            bridge_rails.Append(pipe_mesh(aa,bb,.05));bridge_rails.Append(pipe_mesh(p,aa,.05))
        bridge_rails.Append(pipe_mesh(b,b+G.Vector3d(0,0,1.15),.05))
        bridge_braces.Append(pipe_mesh(a-G.Vector3d(0,0,.9),b-G.Vector3d(0,0,.9),.19))
        for t in [.35,.7,1.]:
            p=a+(b-a)*t-G.Vector3d(0,0,.9)
            anchor=a-EXIT_DIR*2.-G.Vector3d(0,0,8.)
            bridge_braces.Append(pipe_mesh(anchor,p,.2))
    stage(mesh_finish(bridge_rails),'Road_connector_guardrails','04_metal','steel')
    stage(mesh_finish(bridge_braces),'Road_connector_brackets','04_metal','steel')
    return {'staged_parts':len(d['parts']),'portal_clear_height_m':4.82}

def commit():
    d=state();assert not d['objects'],'Already committed: inspect existing objects'
    assert len(d.get('parts',[]))>=28
    for key in ['oval','roof','core']:solid(d['prepared'][key])
    for geom,name,category,mat,metadata in d['parts']:assert geom.IsValid,name
    d['materials']={'ivory':material('Ivory',(213,211,198),.76),
        'floor':material('Warm_floor',(194,190,175),.82),
        'steel':material('Weathered_metal',(111,103,83),.62,.55),
        'glass':material('Pale_glass',(142,191,195),.12,0.,.28)}
    d['undo_record']=sc.doc.BeginUndoRecord('Oval descending atrium 1031')
    sc.doc.Views.RedrawEnabled=False
    try:
        for key in ['oval','roof','core']:
            assert sc.doc.Objects.Replace(System.Guid(SOURCE[key]),d['prepared'][key])
            d['modified_sources'].append(SOURCE[key])
        # Retain exact original identity, layer and attributes on the three source solids.
        for geom,name,category,mat,metadata in d['parts']:add(geom,name,category,mat,metadata)
        helper=sc.doc.Layers[layer(LAYER+'::09_smooth_collision')]
        helper.IsVisible=False;helper.IsLocked=True;helper.CommitChanges()
        # Existing green planting guide circles would float across the excavated opening.
        # Preserve them as hidden references rather than deleting or changing planting data.
        d['hidden_references']=[]
        for sid in ['76c06be1-1acb-4bdd-a43c-c723e79666ca','2bcec7a3-6b73-460e-b722-7db09c2f0077']:
            o=obj(sid)
            if o and not o.IsHidden:
                assert sc.doc.Objects.Hide(o.Id,True);d['hidden_references'].append(sid)
    finally:
        sc.doc.EndUndoRecord(d['undo_record']);sc.doc.Views.RedrawEnabled=True;sc.doc.Views.Redraw()
    write('route_geometry.json',d['routes'])
    return {'objects':len(d['objects']),'categories':d['categories'],'sources_replaced':d['modified_sources']}

def feature_objects():return [o for o in active_objects() if o.Attributes.GetUserString('feature')==TAG]
def mesh_of(geometry):
    if isinstance(geometry,G.Mesh):return geometry.DuplicateMesh()
    if isinstance(geometry,G.Extrusion):geometry=geometry.ToBrep()
    m=G.Mesh()
    for part in G.Mesh.CreateFromBrep(geometry,G.MeshingParameters.FastRenderMesh):m.Append(part)
    return m
def ray_height(mesh,p):
    t=G.Intersect.Intersection.MeshRay(mesh,G.Ray3d(G.Point3d(p.X,p.Y,p.Z+2.),-G.Vector3d.ZAxis))
    return p.Z+2.-t if t>=0 else None
def audit():
    d=state();objects=active_objects();now={str(o.Id):o for o in objects}
    allowed=set(d['modified_sources']+d.get('hidden_references',[]))
    settings=Rhino.FileIO.SerializationOptions();changed=[];missing=[]
    for sid,entry in d['before'].items():
        if sid not in now:missing.append(sid);continue
        o=now[sid]
        if sid not in allowed and (int(o.Geometry.DataCRC(0))!=entry['crc'] or o.Attributes.ToJSON(settings)!=entry['attributes']):changed.append(sid)
    assert not changed and not missing,'Unrelated original scene objects changed'
    owned=feature_objects();assert set(str(o.Id) for o in owned)==set(d['objects'])
    invalid=[str(o.Id) for o in owned if not o.Geometry.IsValid];assert not invalid
    closed=[str(o.Id) for o in owned if isinstance(o.Geometry,G.Mesh) and not o.Geometry.IsClosed];assert not closed
    # Actual ray tests through new source solids verify the floor is visible through the oculus.
    shell=G.Mesh()
    for key in ['oval','roof','core']:shell.Append(mesh_of(obj(key).Geometry))
    oculus=[]
    for x,y in [(0,0),(25,0),(-25,0),(0,15),(0,-15)]:
        p=G.Point3d(CX+x,CY+y,75.)
        t=G.Intersect.Intersection.MeshRay(shell,G.Ray3d(p,-G.Vector3d.ZAxis))
        height=75.-t if t>=0 else None
        assert height is not None and abs(height-34.15)<.06,'Old solid still covers atrium'
        oculus.append(height)
    # Exit body/head clearance on center and both margins through every modified solid.
    blockers=[];s=d['prepared']['exit_start'];e=d['prepared']['exit_end'];side=G.Vector3d(-EXIT_DIR.Y,EXIT_DIR.X,0)
    for lateral in [-3.4,0.,3.4]:
        for z in [35.4,36.8,39.4]:
            start=G.Point3d(s.X,s.Y,z)+side*lateral;end=G.Point3d(e.X,e.Y,z)+side*lateral
            hits=G.Intersect.Intersection.MeshLine(shell,G.Line(start,end))
            if hits and len(hits):blockers.append({'side':lateral,'z':z,'hits':[xyz(p) for p in hits]})
    assert not blockers,'Exit tunnel blocked'
    results={'native_document':sc.doc.Path,'backup':d['backup'],'source_geometry_modified':d['modified_sources'],
        'unrelated_geometry_or_attributes_changed':changed,'original_objects_missing':missing,'feature_objects':len(owned),
        'categories':d['categories'],'invalid_objects':invalid,'unclosed_meshes':closed,'oculus_core_floor_hits_m':oculus,
        'exit_clearance_rays':9,'exit_blockers':blockers,'exit_level_m':35.,'one_way_drops_m':[2.8,2.8,2.8],
        'gallery_width_m':WIDTH,'smooth_collision_helpers':0 if d.get('ramp_revision_committed') else 4,'preserved_existing_planting':True,
        'no_godot_import_yet':not d.get('game_imported',False),'object_ids':d['objects']}
    if d.get('ramp_revision_committed'):
        results.update(ramps=4,unguarded_shortcut_terraces=6,vegetation_ground=True,revision_backup=d['ramp_revision_backup'])
    write('model_report.json',results);return {k:v for k,v in results.items() if k!='object_ids'}

def capture(which='overview'):
    d=state();vp=sc.doc.Views.ActiveView.ActiveViewport
    temporary=d.pop('temporary_clip',None)
    if temporary:
        old=obj(temporary)
        if old:assert sc.doc.Objects.Purge(old)
    views={'overview':((1268,90,196),(CX,CY,59)),
           'cutaway_road':((943,475,140),(CX,CY,52)),
           'cutaway_roof':((1255,122,150),(CX,CY,53)),
           'interior':((CX+32,CY-27,73),(CX-28,CY+12,46))}
    eye,target=views[which];eye=G.Point3d(*eye);target=G.Point3d(*target)
    vp.ChangeToPerspectiveProjection(True,38);vp.SetCameraLocations(target,eye)
    vp.DisplayMode=Rhino.Display.DisplayModeDescription.FindByName('Rendered')
    clip=None
    try:
        if which.startswith('cutaway'):
            normal=target-eye;normal.Z=0;normal.Unitize()
            clip=sc.doc.Objects.AddClippingPlane(G.Plane(G.Point3d(CX,CY,52),normal),180,100,vp.Id)
            o=obj(str(clip));g=o.ClippingPlaneGeometry
            ids=[System.Guid(SOURCE[k]) for k in ['oval','roof','core']]
            for sid in d['objects']:
                item=obj(sid)
                if item.Name in ['PR_Atrium_Elliptical_wall_liner','PR_Atrium_Curved_wall_ribs','PR_Atrium_Elliptical_edge_beams']:ids.append(item.Id)
            g.SetClipParticipation(System.Array[System.Guid](ids),System.Array[System.Int32]([]),False)
            g.ParticipationListsEnabled=True;o.CommitChanges()
            sc.doc.Objects.Hide(clip,True)
        sc.doc.Objects.UnselectAll();sc.doc.Views.Redraw()
        if not which.startswith('cutaway'):sc.doc.NamedViews.Add('OvalAtrium_'+which+'_1031',vp.Id)
        cap=Rhino.Display.ViewCapture();cap.Width=1800;cap.Height=1120
        cap.DrawGrid=False;cap.DrawAxes=False;cap.DrawGridAxes=False
        bitmap=cap.CaptureToBitmap(sc.doc.Views.ActiveView);assert bitmap
        path=OUT+'/'+which+'.png';bitmap.Save(path,System.Drawing.Imaging.ImageFormat.Png);bitmap.Dispose()
        return {'capture':path}
    finally:
        if clip:
            old=obj(str(clip))
            if old:assert sc.doc.Objects.Purge(old)
        sc.doc.Views.Redraw()

def verify_routes():
    d=state();shell=mesh_of(d['prepared']['oval']);buried=[]
    for i,row in enumerate(d['routes']['external']['samples']):
        for f in [.04,.5,.96]:
            a=G.Point3d(*row[0]);b=G.Point3d(*row[1]);p=a+(b-a)*f
            t=G.Intersect.Intersection.MeshRay(shell,G.Ray3d(G.Point3d(p.X,p.Y,90),-G.Vector3d.ZAxis))
            if t>=0 and 90-t>p.Z+.17:buried.append([i,f,90-t-p.Z])
    floors=G.Mesh()
    for geom,name,cat,mat,metadata in d['parts']:
        if cat in ['02_platforms','03_stairs','06_road_exit'] and 'Portal_' not in name:floors.Append(mesh_of(geom))
    p=point(54.5,32.5,72.6,ENTRY);drops=[(p,69.8)]
    for angle,upper,lower in [(135,60.6,57.8),(315,48.6,45.8)]:
        a,b=wall_axes(upper);drops.append((point(a-5.95,b-5.95,upper,angle+1.),lower))
    drop_hits=[]
    for p,expected in drops:
        t=G.Intersect.Intersection.MeshRay(floors,G.Ray3d(G.Point3d(p.X,p.Y,p.Z-.06),-G.Vector3d.ZAxis))
        h=p.Z-.06-t if t>=0 else None
        drop_hits.append([xyz(p),h,expected]);assert h is not None and abs(h-expected)<.02,'Missing receiving floor'
    blockers=[];s=d['prepared']['exit_start'];e=d['prepared']['exit_end'];side=G.Vector3d(-EXIT_DIR.Y,EXIT_DIR.X,0)
    m=G.Mesh()
    for sid in ['47456112-e53f-4799-aa9b-cfcc656da2ca','9885b6ab-30cd-4214-b68d-b5d1faa7c1d1','3b615b62-6ef5-40bc-941c-f6bee7cb51cb']:m.Append(mesh_of(obj(sid).Geometry))
    for lateral in [-3.4,0,3.4]:
        for z in [35.4,36.8,39.4]:
            a=G.Point3d(s.X,s.Y,z)+side*lateral;b=G.Point3d(e.X,e.Y,z)+side*lateral
            hits=G.Intersect.Intersection.MeshLine(m,G.Line(a,b))
            if hits and len(hits):blockers.append([lateral,z,len(hits)])
    assert not buried and not blockers,'Buried stairs or obstructed exit'
    result={'exterior_tread_samples':183,'buried_exterior_treads':buried,'drop_landing_rays':drop_hits,
        'existing_facade_exit_blockers':blockers,'controller_jump_height_m':7.*7./(2*22.),'drop_height_m':2.8}
    write('route_verification.json',result);return result

def smoothstep(t):return t*t*(3.-2.*t)
def grounded_band(samples,base):
    m=G.Mesh()
    for outer,inner in samples:
        for p in [outer,inner,G.Point3d(outer.X,outer.Y,base),G.Point3d(inner.X,inner.Y,base)]:m.Vertices.Add(p)
    for i in range(len(samples)-1):
        j=i*4;k=j+4
        for f in [(j,k,k+1,j+1),(j+2,j+3,k+3,k+2),(j,j+2,k+2,k),(j+1,k+1,k+3,j+3)]:m.Faces.AddFace(*f)
    m.Faces.AddFace(0,1,3,2);j=(len(samples)-1)*4;m.Faces.AddFace(j,j+2,j+3,j+1)
    return mesh_finish(m)
def pod(x,y,z,a,b,angle):
    plane=G.Plane(G.Point3d(x,y,z),G.Vector3d.ZAxis)
    c=G.Ellipse(plane,a,b).ToNurbsCurve();c.Rotate(math.radians(angle),G.Vector3d.ZAxis,plane.Origin)
    return solid(G.Extrusion.Create(c,-.65,True).ToBrep())
def vegetation_patch():
    n=128;rings=12;m=G.Mesh();cx=CX-1.5;cy=CY+1.;z=35.025
    m.Vertices.Add(cx,cy,z);m.TextureCoordinates.Add(cx/1.5,cy/1.5)
    for j in range(1,rings+1):
        for i in range(n):
            t=2*math.pi*i/n;r=j/rings
            f=1.+.055*math.sin(3*t+.4)+.028*math.sin(5*t-1.1)
            x=cx+44.*r*f*math.cos(t);y=cy+26.*r*f*math.sin(t)
            m.Vertices.Add(x,y,z);m.TextureCoordinates.Add(x/1.5,y/1.5)
    for i in range(n):m.Faces.AddFace(0,1+i,1+(i+1)%n)
    for j in range(rings-1):
        a=1+j*n;b=a+n
        for i in range(n):m.Faces.AddFace(a+i,b+i,b+(i+1)%n,a+(i+1)%n)
    top_count=m.Vertices.Count
    for p in list(m.Vertices):m.Vertices.Add(p.X,p.Y,34.98);m.TextureCoordinates.Add(p.X/1.5,p.Y/1.5)
    for f in list(m.Faces):
        if f.IsTriangle:m.Faces.AddFace(f.C+top_count,f.B+top_count,f.A+top_count)
        else:m.Faces.AddFace(f.D+top_count,f.C+top_count,f.B+top_count,f.A+top_count)
    outer=1+(rings-1)*n
    for i in range(n):
        a=outer+i;b=outer+(i+1)%n;m.Faces.AddFace(a,b,b+top_count,a+top_count)
    return mesh_finish(m)

def prepare_ramp_revision():
    d=state();assert not d.get('ramp_revision_committed'),'Inspect current ramps before revising again'
    owned=feature_objects();settings=Rhino.FileIO.SerializationOptions()
    d['revision_before']={str(o.Id):{'crc':int(o.Geometry.DataCRC(0)),'attributes':o.Attributes.ToJSON(settings)} for o in active_objects()}
    d['revision_original_owned']=[str(o.Id) for o in owned]
    # The user already removed some rails in Rhino. Start from the actual document.
    d['objects']=[str(o.Id) for o in owned]
    d['revision_parts']=[];d['ramp_samples']=[]
    for route in d['routes']['internal']:
        a0,a1,a2,a3=route['angles'];top,bottom=route['elevations'];samples=[]
        for i in range(97):
            t=i/96.;angle=a1+(a2-a1)*t;z=top-(top-bottom)*smoothstep(t)
            a,b=wall_axes(z);margin=gallery_margin(z)
            samples.append((point(a-margin,b-margin,z,angle),point(a-margin-WIDTH,b-margin-WIDTH,z,angle)))
        name='Helical_ramp_%d'%route['index']
        d['revision_parts'].append((band_mesh(samples,.65),name,'03_ramps','floor',{'collision':'visible_mesh','no_separate_collision_helper':True}))
        d['ramp_samples'].append({'name':name,'samples':[[xyz(o),xyz(i)] for o,i in samples]})
    outside=[]
    for i in range(121):
        t=i/120.;z=63.+9.6*smoothstep(t);a,b=outside_axes(z);angle=ENTRY-40.+40.*t
        outside.append((point(a+8.6,b+8.6,z,angle),point(a+.35,b+.35,z,angle)))
    d['revision_parts'].append((grounded_band(outside,62.85),'Exterior_sweeping_ramp','03_ramps','ivory',{'collision':'visible_mesh','no_separate_collision_helper':True}))
    d['ramp_samples'].append({'name':'Exterior_sweeping_ramp','samples':[[xyz(o),xyz(i)] for o,i in outside]})
    # Nonuniform gallery edges: broad viewing lobes alternate around the void.
    bulges=[[(0,13.,23.),(62.,9.,18.)],[(162.,14.,21.),(237.,8.,19.)],[(340.,11.,20.),(413.,15.,20.)]]
    for route,peaks in zip(d['routes']['internal'],bulges):
        a0,a1,a2,a3=route['angles'];top,bottom=route['elevations']
        samples=[];n=int(math.ceil((a1-a0)/1.25))
        for i in range(n+1):
            t=i/n;angle=a0+(a1-a0)*t;a,b=wall_axes(top);margin=gallery_margin(top)
            weight=min(1.,t*8.,(1.-t)*8.)
            extra=sum(size*math.exp(-((angle-center)/spread)**2) for center,size,spread in peaks)*weight
            samples.append((point(a-margin,b-margin,top,angle),point(a-margin-WIDTH-extra,b-margin-WIDTH-extra,top,angle)))
        d['revision_parts'].append((band_mesh(samples,.65),'Gallery_%d'%route['index'],'02_platforms','floor',{'unguarded_jump_edge':True}))
    terrace_rows=[(CX-3,CY+24.5,66.8,8,6.5,-12),(CX-14,CY+27.5,63.8,9,6.,10),(CX-25,CY+30.5,60.8,8.5,6.5,-8),
                  (CX+3,CY-33.5,54.8,8,6.,12),(CX+14,CY-31.,51.8,9,6.5,-10),(CX+25,CY-29.,48.8,8.5,6.,8)]
    for i,(x,y,z,a,b,angle) in enumerate(terrace_rows):
        d['revision_parts'].append((pod(x,y,z,a,b,angle),'Shortcut_terrace_%d'%(i+1),'07_staggered_terraces','floor',{'collision':'visible_mesh','unguarded_jump_edge':True}))
    d['terrace_rows']=terrace_rows
    d['revision_parts'].append((vegetation_patch(),'Central_vegetation_ground','08_vegetation_ground','ground',
        {'collision':'visual_only','texture':'res://assets/world/landscape_pools/grass_ground_albedo.png','uv_tile_m':1.5}))
    for geom,name,category,mat,meta in d['revision_parts']:assert geom.IsValid,name
    return {'ramp_parts':4,'shortcut_terraces':6,'vegetation_ground':True,'staged_parts':len(d['revision_parts']),
        'actual_existing_objects':len(owned),'top_opening_m':[110,66],'outer_oval_m':[168,111.6]}

def commit_ramp_revision():
    d=state();assert d.get('revision_parts') and not d.get('ramp_revision_committed')
    backup='D:/Prism Route/archive/oval_atrium_1031/map_before_ramp_revision.3dm'
    assert not os.path.exists(backup),'Keep the existing ramp revision backup'
    options=Rhino.FileIO.FileWriteOptions();options.SuppressDialogBoxes=True
    assert sc.doc.Write3dmFile(backup,options)
    d['ramp_revision_backup']=backup
    ground=material('Vegetation_ground',(155,165,112),.95)
    mat=sc.doc.Materials[ground];assert mat.SetBitmapTexture(ROOT+'/assets/world/landscape_pools/grass_ground_albedo.png');mat.CommitChanges()
    d['materials']['ground']=ground
    remove_names=['Gallery_1','Gallery_2','Gallery_3','Floor_inlay_0','Floor_inlay_1','Entry_guardrails',
        'Gallery_guardrails','Gallery_glass_balustrades','Oculus_guardrails_except_entry','Oculus_glass_except_entry',
        'Exterior_sweeping_steps','Exterior_smooth-colonly']
    remove_names+=['Helical_treads_%d'%i for i in range(1,4)]+['Helical_smooth_%d-colonly'%i for i in range(1,4)]
    remove_names=set('PR_Atrium_'+s for s in remove_names)
    remove=[o for o in feature_objects() if o.Name in remove_names]
    d['revision_removed_names']=[o.Name for o in remove]
    record=sc.doc.BeginUndoRecord('Atrium ramps, open edges and staggered terraces')
    helpers=sc.doc.Layers[layer(LAYER+'::09_smooth_collision')];old=(helpers.IsVisible,helpers.IsLocked)
    sc.doc.Views.RedrawEnabled=False
    try:
        helpers.IsVisible=True;helpers.IsLocked=False;helpers.CommitChanges()
        for o in remove:assert sc.doc.Objects.Delete(o.Id,True)
        for geom,name,cat,mat,metadata in d['revision_parts']:add(geom,name,cat,mat,metadata)
        d['objects']=[str(o.Id) for o in feature_objects()]
        d['categories']={}
        for o in feature_objects():
            cat=o.Attributes.GetUserString('category');d['categories'][cat]=d['categories'].get(cat,0)+1
        d['parts']=[(o.Geometry.Duplicate(),o.Name[len('PR_Atrium_'):],o.Attributes.GetUserString('category'),'floor',{}) for o in feature_objects()]
        d['ramp_revision_committed']=True
    finally:
        helpers.IsVisible,helpers.IsLocked=old;helpers.CommitChanges()
        sc.doc.EndUndoRecord(record);sc.doc.Views.RedrawEnabled=True;sc.doc.Views.Redraw()
    write('ramp_geometry.json',d['ramp_samples']);return {'objects':len(d['objects']),'categories':d['categories'],'backup':backup}

def verify_ramps():
    d=state();owned=feature_objects();settings=Rhino.FileIO.SerializationOptions()
    current={str(o.Id):o for o in active_objects()};unrelated=[]
    for sid,entry in d['revision_before'].items():
        if sid in d['objects'] or (sid in current and current[sid].Attributes.GetUserString('feature')==TAG):continue
        if sid not in current:
            # Removed source-owned treads/rails are deliberate, unrelated objects are not.
            if sid in d.get('revision_original_owned',[]):continue
            original=sc.doc.Objects.FindId(System.Guid(sid))
            if original and original.Attributes.GetUserString('feature')==TAG:continue
            unrelated.append(sid);continue
        o=current[sid]
        if int(o.Geometry.DataCRC(0))!=entry['crc'] or o.Attributes.ToJSON(settings)!=entry['attributes']:unrelated.append(sid)
    assert not unrelated,'Unrelated scene changed during ramp revision'
    forbidden=[o.Name for o in owned if 'treads' in o.Name or 'steps' in o.Name or 'colonly' in o.Name or 'Gallery_guard' in o.Name or o.Name=='PR_Atrium_Entry_guardrails']
    assert not forbidden,'Obsolete stair geometry remains'
    grades={};vertical=[]
    for row in d['ramp_samples']:
        result=[]
        for fraction in [.04,.5,.96]:
            previous=None
            for outer,inner in row['samples']:
                a=G.Point3d(*outer);b=G.Point3d(*inner);p=a+(b-a)*fraction
                if previous:
                    run=math.hypot(p.X-previous.X,p.Y-previous.Y);rise=abs(p.Z-previous.Z)
                    if run<.001 and rise>.001:vertical.append(row['name'])
                    result.append(rise/max(.001,run))
                previous=p
        grades[row['name']]=max(result)
    assert not vertical and max(grades.values())<.8,'Ramp exceeds normal character floor slope'
    assert len([o for o in owned if o.Attributes.GetUserString('category')=='03_ramps'])==4
    # Verify that successive shortcut pods overlap in plan and have usable headroom.
    pods=[o for o in owned if o.Name.startswith('PR_Atrium_Shortcut_terrace_')]
    overlaps=[]
    for group in [d['terrace_rows'][:3],d['terrace_rows'][3:]]:
        for a,b in zip(group,group[1:]):
            first=G.Point3d(a[0],a[1],a[2]);second=G.Point3d(b[0],b[1],b[2]);mid=(first+second)*.5
            hits=[]
            for row in [a,b]:
                m=mesh_of(pod(*row));t=G.Intersect.Intersection.MeshRay(m,G.Ray3d(G.Point3d(mid.X,mid.Y,80),-G.Vector3d.ZAxis))
                hits.append(t>=0)
            assert all(hits),'Shortcut requires an unintended long jump'
            overlaps.append({'top_z':a[2],'next_z':b[2],'drop_m':a[2]-b[2],'plan_overlap':True,'clear_height_m':a[2]-.65-b[2]})
    ground=[o for o in owned if o.Name=='PR_Atrium_Central_vegetation_ground'];assert len(ground)==1
    material=sc.doc.Materials[ground[0].Attributes.MaterialIndex];assert material.GetBitmapTexture()
    result={'ramps':4,'maximum_grades':grades,'maximum_slope_degrees':{k:math.degrees(math.atan(v)) for k,v in grades.items()},
        'obsolete_stairs_or_helpers':forbidden,'shortcut_terraces':len(pods),'pod_step_checks':overlaps,
        'ramp_rails':False,'unrelated_scene_changes':unrelated,'vegetation_texture':material.GetBitmapTexture().FileName}
    write('ramp_verification.json',result);return result

def named_part(name):
    matches=[o for o in feature_objects() if o.Name=='PR_Atrium_'+name]
    assert len(matches)==1,'Expected one current part: '+name
    return matches[0]

def prepare_exit_ground_fix():
    d=state();assert not d.get('exit_ground_fix_committed'),'Already applied; inspect the current model'
    settings=Rhino.FileIO.SerializationOptions()
    d['exit_ground_before']={str(o.Id):{'crc':int(o.Geometry.DataCRC(0)),'attributes':o.Attributes.ToJSON(settings)} for o in active_objects()}
    d['exit_ground_camera']={'eye':xyz(sc.doc.Views.ActiveView.ActiveViewport.CameraLocation),
        'target':xyz(sc.doc.Views.ActiveView.ActiveViewport.CameraTarget)}
    grass=named_part('Central_vegetation_ground').Geometry.DuplicateMesh()
    top_z=grass.GetBoundingBox(True).Max.Z;top=G.Mesh()
    for face in grass.Faces:
        indices=[face.A,face.B,face.C]+([face.D] if face.IsQuad else [])
        points=[grass.Vertices[i] for i in indices]
        if all(abs(p.Z-top_z)<.001 for p in points):
            start=top.Vertices.Count
            for p in points:top.Vertices.Add(p)
            if len(points)==3:top.Faces.AddFace(start,start+1,start+2)
            else:top.Faces.AddFace(start,start+1,start+2,start+3)
    top.Vertices.CombineIdentical(True,True);top.Compact()
    loops=top.GetNakedEdges();assert loops and len(loops)==1,'Expected one vegetation perimeter'
    curve=G.PolylineCurve([G.Point3d(p.X,p.Y,34.) for p in loops[0]])
    cutter=solid(G.Extrusion.Create(curve,2.,True).ToBrep())
    original_floor=named_part('Lower_hall_floor').Geometry.DuplicateBrep()
    # Construct one annular extrusion. Inner profiles are in the extrusion's
    # local XY plane, not in document coordinates.
    floor_ext=G.Extrusion.Create(ellipse(69,47,34.2),.8,True)
    inner=curve.DuplicateCurve();inner.Transform(G.Transform.Translation(0,0,.2))
    inner.Transform(G.Transform.PlaneToPlane(floor_ext.GetProfilePlane(0.),G.Plane.WorldXY))
    if inner.ClosedCurveOrientation()==G.CurveOrientation.CounterClockwise:inner.Reverse()
    assert floor_ext.AddInnerProfile(inner),'Vegetation floor inner profile failed'
    floor=solid(floor_ext.ToBrep())
    connector=difference(named_part('Level_road_connector').Geometry,original_floor,'remove overlapping entrance floor')
    for i in range(grass.Vertices.Count):
        p=grass.Vertices[i];z=35. if abs(p.Z-top_z)<.001 else 34.2
        grass.Vertices.SetVertex(i,p.X,p.Y,z)
    grass=mesh_finish(grass)
    # Shift the final flight along the same ellipse, retaining both height and width.
    route=d['routes']['internal'][2];a0,old_a1,old_a2,old_a3=route['angles'];top,bottom=route['elevations']
    a1=old_a1-25.;a2=old_a2-25.;samples=[]
    for i in range(97):
        t=i/96.;angle=a1+(a2-a1)*t;z=top-(top-bottom)*smoothstep(t)
        a,b=wall_axes(z);margin=gallery_margin(z)
        samples.append((point(a-margin,b-margin,z,angle),point(a-margin-WIDTH,b-margin-WIDTH,z,angle)))
    ramp=band_mesh(samples,.65)
    gallery=[];n=int(math.ceil((a1-a0)/1.25));peaks=[(340.,11.,20.),(413.,15.,20.)]
    for i in range(n+1):
        t=i/n;angle=a0+(a1-a0)*t;a,b=wall_axes(top);margin=gallery_margin(top)
        weight=min(1.,t*8.,(1.-t)*8.)
        extra=sum(size*math.exp(-((angle-center)/spread)**2) for center,size,spread in peaks)*weight
        gallery.append((point(a-margin,b-margin,top,angle),point(a-margin-WIDTH-extra,b-margin-WIDTH-extra,top,angle)))
    replacements={'Lower_hall_floor':floor,'Central_vegetation_ground':grass,'Level_road_connector':connector,
        'Helical_ramp_3':ramp,'Gallery_3':band_mesh(gallery,.65)}
    for name,geom in replacements.items():assert geom.IsValid,name
    d['exit_ground_prepared']={'replacements':replacements,'ramp_samples':samples,'angles':[a0,a1,a2,a2],
        'remove_id':str(named_part('Departure_3').Id),'perimeter':curve,'cutter':cutter}
    return {'replacement_parts':len(replacements),'grass_top_z_m':35.,'grass_thickness_m':.8,
        'ramp_retreat_degrees':25.,'bottom_departure_removed':True,'floor_and_connector_solid':floor.IsSolid and connector.IsSolid}

def commit_exit_ground_fix():
    d=state();assert d.get('exit_ground_prepared') and not d.get('exit_ground_fix_committed')
    backup='D:/Prism Route/archive/oval_atrium_1031/map_before_exit_ground_fix.3dm'
    assert not os.path.exists(backup),'Keep the existing exit/ground backup'
    options=Rhino.FileIO.FileWriteOptions();options.SuppressDialogBoxes=True
    assert sc.doc.Write3dmFile(backup,options)
    prepared=d['exit_ground_prepared'];record=sc.doc.BeginUndoRecord('Inset vegetation floor and clear exit ramp')
    d['exit_ground_modified_ids']=[];sc.doc.Views.RedrawEnabled=False
    try:
        for name,geom in prepared['replacements'].items():
            o=named_part(name);d['exit_ground_modified_ids'].append(str(o.Id))
            assert sc.doc.Objects.Replace(o.Id,geom)
        d['exit_ground_modified_ids'].append(prepared['remove_id'])
        assert sc.doc.Objects.Delete(System.Guid(prepared['remove_id']),True)
        d['routes']['internal'][2]['angles']=prepared['angles']
        d['routes']['internal'][2]['ends_on_open_lower_floor']=True
        d['routes']['internal'][2]['samples']=[[xyz(o),xyz(i)] for o,i in prepared['ramp_samples']]
        for row in d['ramp_samples']:
            if row['name']=='Helical_ramp_3':row['samples']=[[xyz(o),xyz(i)] for o,i in prepared['ramp_samples']]
        d['objects']=[str(o.Id) for o in feature_objects()];d['categories']={}
        for o in feature_objects():
            cat=o.Attributes.GetUserString('category');d['categories'][cat]=d['categories'].get(cat,0)+1
        d['parts']=[(o.Geometry.Duplicate(),o.Name[len('PR_Atrium_'):],o.Attributes.GetUserString('category'),'floor',{}) for o in feature_objects()]
        d['exit_ground_fix_committed']=True;d['exit_ground_backup']=backup
    finally:
        sc.doc.EndUndoRecord(record);sc.doc.Views.RedrawEnabled=True;sc.doc.Views.Redraw()
    write('route_geometry.json',d['routes']);write('ramp_geometry.json',d['ramp_samples'])
    return {'modified_ids':d['exit_ground_modified_ids'],'backup':backup,'current_feature_objects':len(d['objects'])}

def verify_exit_ground_fix():
    d=state();prepared=d['exit_ground_prepared'];owned=feature_objects();current={str(o.Id):o for o in active_objects()}
    settings=Rhino.FileIO.SerializationOptions();allowed=set(d['exit_ground_modified_ids']);changed=[]
    for sid,old in d['exit_ground_before'].items():
        if sid in allowed:continue
        o=current.get(sid)
        if not o or int(o.Geometry.DataCRC(0))!=old['crc'] or o.Attributes.ToJSON(settings)!=old['attributes']:changed.append(sid)
    assert not changed,'Unrelated objects changed'
    floor_mesh=mesh_of(named_part('Lower_hall_floor').Geometry);ground_mesh=named_part('Central_vegetation_ground').Geometry
    floor_hits=[];grass_hits=[]
    for x,y in [(0,0),(20,0),(-20,0),(0,12),(0,-12),(15,10),(-15,-10)]:
        origin=G.Point3d(CX+x,CY+y,36.)
        ray=G.Ray3d(origin,-G.Vector3d.ZAxis)
        floor_t=G.Intersect.Intersection.MeshRay(floor_mesh,ray)
        grass_t=G.Intersect.Intersection.MeshRay(ground_mesh,ray)
        assert floor_t<0,'Duplicate floor remains below grass'
        assert grass_t>=0 and abs(36.-grass_t-35.)<.002,'Missing vegetation floor'
        floor_hits.append(floor_t>=0);grass_hits.append(36.-grass_t)
    grass_volume=G.VolumeMassProperties.Compute(ground_mesh).Volume
    assert grass_volume>100.,'Vegetation remains a thin double surface'
    obstacles=G.Mesh()
    for name in ['Helical_ramp_3','Gallery_3','Portal_ceiling','Portal_side_-1','Portal_side_1','Portal_frames']:
        obstacles.Append(mesh_of(named_part(name).Geometry))
    s=d['prepared']['exit_start'];e=d['prepared']['exit_end'];side=G.Vector3d(-EXIT_DIR.Y,EXIT_DIR.X,0)
    blocked=[]
    for lateral in [-3.4,0,3.4]:
        for z in [35.35,36.8,39.3]:
            a=G.Point3d(s.X,s.Y,z)-EXIT_DIR*10.+side*lateral;b=G.Point3d(e.X,e.Y,z)+side*lateral
            hits=G.Intersect.Intersection.MeshLine(obstacles,G.Line(a,b))
            if hits and len(hits):blocked.append({'side':lateral,'z':z,'hits':[xyz(p) for p in hits]})
    assert not blocked,'Ramp still obstructs the portal'
    ramp_mesh=named_part('Helical_ramp_3').Geometry
    portal_mesh=G.Mesh()
    for name in ['Portal_ceiling','Portal_side_-1','Portal_side_1','Portal_frames']:portal_mesh.Append(mesh_of(named_part(name).Geometry))
    intersections=G.Intersect.Intersection.MeshMeshFast(ramp_mesh,portal_mesh)
    assert not intersections or len(intersections)==0,'Ramp intersects portal geometry'
    result={'unrelated_changes':changed,'vegetation_floor_samples':len(grass_hits),'duplicate_floor_under_vegetation':any(floor_hits),
        'vegetation_top_z_m':grass_hits,'vegetation_thickness_m':.8,'vegetation_solid_volume_m3':grass_volume,
        'exit_clearance_rays':9,'exit_blockers':blocked,'ramp_portal_intersections':0,
        'ramp_retreat_degrees':25.,'bottom_departure_removed':not any(o.Name=='PR_Atrium_Departure_3' for o in owned)}
    write('exit_ground_verification.json',result);return result

def save():
    d=state();audit()
    if d.get('ramp_revision_committed'):verify_ramps()
    else:verify_routes()
    if d.get('exit_ground_fix_committed'):verify_exit_ground_fix()
    options=Rhino.FileIO.FileWriteOptions();options.SuppressDialogBoxes=True
    standalone=OUT+'/oval_atrium.3dm'
    if os.path.exists(standalone):shutil.copy2(standalone,'D:/Prism Route/archive/oval_atrium_1031/oval_atrium_previous.3dm')
    helper_index=sc.doc.Layers.FindByFullPath(LAYER+'::09_smooth_collision',-1)
    helpers=sc.doc.Layers[helper_index] if helper_index>=0 else None
    old=(helpers.IsVisible,helpers.IsLocked) if helpers else None
    if helpers:helpers.IsVisible=True;helpers.IsLocked=False;helpers.CommitChanges()
    sc.doc.Objects.UnselectAll()
    try:
        # Include the raised oval shell, but not the huge island solids, in the reusable component.
        for sid in d['objects']+[SOURCE['oval']]:sc.doc.Objects.Select(System.Guid(sid))
        options.WriteSelectedObjectsOnly=True
        assert sc.doc.Write3dmFile(standalone,options),'Component save failed'
    finally:
        if helpers:helpers.IsVisible,helpers.IsLocked=old;helpers.CommitChanges()
        sc.doc.Objects.UnselectAll()
    file=Rhino.FileIO.File3dm.Read(standalone);assert file
    for item in file.AllLayers:
        if item.Name=='09_smooth_collision':item.IsVisible=False;item.IsLocked=True
    assert file.Write(standalone,8)
    assert len(list(file.Objects))==len(d['objects'])+1
    assert Rhino.RhinoApp.RunScript('_-Save _Enter',False)
    assert not sc.doc.Modified,'Main native save failed'
    return {'main':sc.doc.Path,'component':standalone,'new_feature_objects':len(d['objects'])}
