# -*- coding: utf-8 -*-
"""Site-specific buried court; staged native authoring, local excavation and audit."""
from __future__ import division,unicode_literals
import Rhino,scriptcontext as sc,System,math,json,io,os,time,random
G=Rhino.Geometry
ROOT='D:/Prism Route/prism-route'
OUT=ROOT+'/docs/concepts/coastal_sunken_archive_1103'
CACHE=ROOT+'/.current_map_build/sunken_archive_1103'
TAG='sunken_archive_1103'
LAYER='建筑::下沉环庭遗址'
FLOOR=11.5
ROOF=16.15
CX,CY=98.,1149.
_path=ROOT+'/tools/rhino_east_earth_pavilion_1102.py'
H={'__file__':_path};exec(compile(open(_path,'rb').read().decode('utf-8'),_path,'exec'),H)
finish=H['finish'];slab=H['slab'];beam=H['beam'];closed_curve=H['closed_curve'];plane_region=H['plane_region'];solid_skin=H['solid_skin'];layer=H['layer'];mesh_of=H['mesh_of'];xyz=H['xyz']

def state():return sc.sticky[TAG]
def write(name,data):
    with io.open(OUT+'/'+name,'w',encoding='utf-8') as f:f.write(json.dumps(data,ensure_ascii=False,indent=2))
def fingerprint():return H['fingerprint']()
def stage(g,name,category,material,collision=True):
    assert g and g.IsValid,name
    assert isinstance(g,G.Mesh) and (g.IsClosed or category=='vegetation') or isinstance(g,G.Brep) and g.IsSolid,name
    state()['parts'].append((g,name,category,material,collision))
def ground(x,y):
    mesh=sc.sticky['sunken_archive_site']['ground']
    t=G.Intersect.Intersection.MeshRay(mesh,G.Ray3d(G.Point3d(x,y,150),-G.Vector3d.ZAxis))
    if t>=0:return 150-t
    # The existing joined surfaces contain narrow seams. Interpolate only a local seam.
    for e in [.05,.2,.5,1.0]:
        values=[]
        for dx,dy in [(e,0),(-e,0),(0,e),(0,-e)]:
            q=G.Intersect.Intersection.MeshRay(mesh,G.Ray3d(G.Point3d(x+dx,y+dy,150),-G.Vector3d.ZAxis))
            if q>=0:values.append(150-q)
        if len(values)>=2:return sum(values)/len(values)
    raise AssertionError(('No nearby source surface',x,y))
def ellipse(a,b,x=CX,y=CY):return G.Ellipse(G.Plane(G.Point3d(x,y,0),G.Vector3d.ZAxis),a,b).ToNurbsCurve()
def rect(x0,y0,x1,y1):return G.PolylineCurve([G.Point3d(x0,y0,0),G.Point3d(x1,y0,0),G.Point3d(x1,y1,0),G.Point3d(x0,y1,0),G.Point3d(x0,y0,0)])
def ep(a,b,t,z=0):return G.Point3d(CX+a*math.cos(t),CY+b*math.sin(t),z)
def sector(t0,t1,a0,b0,a1,b1):
    pts=[ep(a1,b1,math.radians(t0+(t1-t0)*i/40)) for i in range(41)]
    pts += [ep(a0,b0,math.radians(t1+(t0-t1)*i/40)) for i in range(41)]
    pts.append(pts[0]);return G.PolylineCurve(pts)
def rim_wall(t0,t1,bottom,n=128):
    m=G.Mesh()
    for i in range(n+1):
        t=math.radians(t0+(t1-t0)*i/n)
        for a,b,z in [(24.92,17.92,bottom),(25.6,18.6,bottom),(25.6,18.6,None),(24.92,17.92,None)]:
            p=ep(a,b,t);p.Z=z if z is not None else max(bottom+.08,ground(p.X,p.Y)+.02);m.Vertices.Add(p)
    for i in range(n):
        for j in range(4):
            a=i*4+j;b=i*4+(j+1)%4;m.Faces.AddFace(a,b,b+4,a+4)
    m.Faces.AddFace(3,2,1,0);a=n*4;m.Faces.AddFace(a,a+1,a+2,a+3)
    return finish(m)
def gallery_pier(angle):
    t=math.radians(angle);radial=G.Vector3d(math.cos(t),math.sin(t),0);tangent=G.Vector3d(-math.sin(t),math.cos(t),0)
    sections=[]
    for z,a,b in [(FLOOR,.85,.54),(FLOOR+.30,.68,.45),(FLOOR+1.4,.48,.38),(FLOOR+2.8,.54,.43),(15.3,1.05,.60),(15.82,1.38,.72)]:
        p=ep(25.95,18.95,t,z);sections.append(G.Ellipse(G.Plane(p,tangent,radial),a,b).ToNurbsCurve())
    breps=G.Brep.CreateFromLoft(sections,G.Point3d.Unset,G.Point3d.Unset,G.LoftType.Normal,False);assert len(breps)==1
    result=breps[0].CapPlanarHoles(.002);assert result and result.IsValid and result.IsSolid
    if result.SolidOrientation==G.BrepSolidOrientation.Inward:result.Flip()
    return result
def rolled_eave():
    rail=G.Curve.CreateInterpolatedCurve([ep(25.18,18.18,math.pi+math.pi*i/128,15.75) for i in range(129)],3)
    pipes=G.Brep.CreatePipe(rail,.38,False,G.PipeCapMode.Round,True,.002,.04);assert len(pipes)==1
    return pipes[0]
def clip(curve,cutter):
    result=G.Curve.CreateBooleanIntersection(curve,cutter,.002);assert result
    return max(result,key=lambda c:G.AreaMassProperties.Compute(c).Area)
def subtract(curve,cutter):
    result=G.Curve.CreateBooleanDifference(curve,cutter,.002);assert result
    return list(result)
def prep():
    assert sc.doc.Path.replace('\\','/').lower()=='d:/prism route/map/map_current.3dm'
    assert TAG not in sc.sticky
    assert not any(o.Attributes.GetUserString('feature')==TAG for o in H['objects']())
    # User policy: retain the applied master, not full-document backup copies.
    # Staged geometry and original affected objects remain in memory for rollback.
    backup=None
    outer=ellipse(43,38,100,1145);court=ellipse(25,18);stair=rect(90.5,1160,103,1186)
    opens=G.Curve.CreateBooleanUnion([court,stair],.002);assert len(opens)==1
    roof_void=sector(184,224,24.85,17.85,42,36)
    cut=slab(outer,FLOOR-.65,110)
    sc.sticky[TAG]={'before':fingerprint(),'backup':backup,'parts':[],'replacements':{},'originals':{},'ids':[],
        'outer':outer,'court':court,'opening':opens[0],'sky':roof_void,'cut':cut,'materials':{},'host_ids':[r['id'] for r in sc.sticky['sunken_archive_site']['rows']]}
    s=state();s['stair_top']=ground(98,1182)+.06
    write('site_measurements.json',{'center':[CX,CY],'outer_axes_m':[86,76],'court_axes_m':[50,36],
        'floor':FLOOR,'roof_top':ROOF,'stair_top':s['stair_top'],'sea_rooms':False,'main_floors':1,
        'road_nearest':xyz(sc.sticky['sunken_archive_site']['road_point']),'road_plan_distance_m':152.,'backup':backup,
        'court_edge_original_heights':[[a,ground(ep(25,18,math.radians(a)).X,ep(25,18,math.radians(a)).Y)] for a in range(0,360,10)]})
    return {'backup':backup,'floor':FLOOR,'roof_top':ROOF,'stair_top':s['stair_top'],'hosts':len(s['host_ids'])}

def build_structure():
    s=state();assert not s['parts']
    stage(slab(s['outer'],FLOOR-.45,.45),'Continuous_foundation_and_court','floors','floor')
    # Retaining envelope and gallery occupy only the inland half.
    back=rect(45,1090,150,CY)
    outerwall=clip(s['outer'],back);innerwall=clip(ellipse(42.1,37.1,100,1145),back)
    # Independent curved back wall, with a narrow end closure at each end.
    for curve in subtract(outerwall,innerwall):stage(slab(curve,FLOOR,ROOF-FLOOR),'Buried_outer_envelope','walls','ivory')
    roof_regions=G.Brep.CreatePlanarBreps([s['outer'],s['opening']],.002);assert roof_regions
    # Plan boolean operations keep the collar and the gallery roof on identical boundaries.
    full=subtract(s['outer'],s['opening'])[0]
    roof_plan=clip(full,back)
    for i,c in enumerate(subtract(roof_plan,s['sky'])):stage(slab(c,ROOF-.55,.55),'Low_buried_roof_%02d'%i,'roofs','ivory')
    # Broad rolled inner eave, heavier where the wall meets its supports.
    stage(rolled_eave(),'Continuous_curved_inner_eave','structure','ivory')
    for j,a in enumerate(range(181,360,22)):
        stage(gallery_pier(a),'Inner_gallery_pier_%02d'%j,'structure','ivory')
    # Room partitions leave an uninterrupted inner promenade.
    for j,a in enumerate([242,286,331]):
        p=ep(29,22,math.radians(a),FLOOR+1.95);q=ep(39.8,33,math.radians(a),FLOOR+1.95)
        stage(beam(lambda t,p=p,q=q:p+(q-p)*t,0,1,.36,3.9,2),'Side_hall_partition_%d'%j,'walls','ivory')
    # Close the two buried gallery ends; courtyard-facing bays remain open.
    for j,(a,b) in enumerate([(55.7,73.0),(123.,142.4)]):
        stage(slab(rect(a,CY-.5,b,CY+.05),FLOOR,4.65),'Gallery_end_wall_%d'%j,'walls','ivory')
    for j,(a,b) in enumerate([(246,257),(303,315)]):
        stage(slab(sector(a,b,25.06,18.06,25.105,18.105),FLOOR+.16,3.70),'Curved_glass_remnant_%d'%j,'glass','glass')
    for j,a in enumerate([188,196,204,212,220]):
        t=math.radians(a);p=ep(25.5,18.5,t,15.86);q=ep(41.2,35,t,16.04)
        stage(beam(lambda k,p=p,q=q:p+(q-p)*k,0,1,.24,.38,12),'Exposed_skylight_beam_%02d'%j,'steel','steel')
    # Ground retaining lining follows the real, uneven courtyard rim.
    stage(rim_wall(180,360,ROOF),'Continuous_courtyard_upper_retainer','walls','ivory')
    for j,(a,b) in enumerate([(0,74),(106,180)]):stage(rim_wall(a,b,FLOOR),'Continuous_front_retainer_%d'%j,'walls','ivory')
    # Two flights and a generous intermediate landing, all below the old rim.
    top=s['stair_top'];n=16;rise=(top-FLOOR)/n;s['stair_route']=[]
    def stair_frame(t):
        p=G.Point3d(98-3*math.sin(math.pi*t),1182-18*t,0)
        tangent=G.Vector3d(-3*math.pi*math.cos(math.pi*t),-18,0);tangent.Unitize()
        return p,G.Vector3d(-tangent.Y,tangent.X,0)
    for i in range(n):
        p0,n0=stair_frame(i/n);p1,n1=stair_frame((i+1)/n);z=top-i*rise
        corners=[p0-n0*3.4,p0+n0*3.4,p1+n1*3.4,p1-n1*3.4];corners.append(corners[0])
        stage(slab(G.PolylineCurve(corners),z-.32,.32),'Entrance_step_%02d'%i,'stairs','floor',False)
        p,_=stair_frame((i+.5)/n);s['stair_route'].append([p.X,p.Y,z])
    stage(slab(rect(94.6,1161.5,101.4,1164),FLOOR-.32,.32),'Stair_lower_landing','stairs','floor')
    for side in [-1,1]:
        def rail(t,side=side):
            p,n0=stair_frame(t);p+=n0*(side*3.18);p.Z=top-(top-FLOOR)*t+1.05;return p
        stage(beam(rail,0,1,.055,.055,30),'Entry_hand_rail_'+str(side),'metal','dark')
        for j in range(7):
            p=rail(j/6.);q=p-G.Vector3d(0,0,1.05)
            stage(beam(lambda t,p=p,q=q:q+(p-q)*t,0,1,.055,.055,1),'Entry_rail_post_%s_%d'%(side,j),'metal','dark')
    # Three sculpted seating fragments, leaving the middle of the court open.
    for j,(a,b) in enumerate([(10,40),(125,155),(260,292)]):
        stage(slab(sector(a,b,16.5,11.2,17.2,11.9),FLOOR,.48),'Curved_seat_%d'%j,'furniture','ivory')
    planter=ellipse(5.5,3.2,94.0,1147.)
    stage(slab(planter,FLOOR,.24),'Reclaimed_court_soil','planter','soil')
    s['structure_built']=True
    return {'parts':len(s['parts']),'court':[50,36],'main_floor':FLOOR,'ceiling_clearance':ROOF-.55-FLOOR}

def trim_host(index):
    s=state();sid=s['host_ids'][index];o=sc.doc.Objects.FindId(System.Guid(sid));original=o.Geometry.DuplicateBrep()
    pieces=original.Split(s['cut'],.005)
    if not pieces or len(pieces)<2:return {'id':sid,'changed':False}
    outside=[]
    for b in pieces:
        mass=G.VolumeMassProperties.Compute(b) if b.IsSolid else G.AreaMassProperties.Compute(b)
        p=mass.Centroid
        inside=((p.X-100)/43.)**2+((p.Y-1145)/38.)**2<1.00001 and p.Z>FLOOR-.66
        if not inside:outside.append(b)
    if len(outside)==len(pieces):return {'id':sid,'changed':False,'split_outside_excavation':True}
    assert outside,'Trim classification failed '+sid
    joined=G.Brep();[joined.Append(b) for b in outside];joined.Compact();assert joined.IsValid
    s['originals'][sid]=(original,o.Attributes.Duplicate());s['replacements'][sid]=joined
    return {'id':sid,'changed':True,'pieces':len(pieces),'kept':len(outside),'valid':joined.IsValid}

def build_ground():
    s=state();collar=subtract(s['outer'],s['opening'])[0]
    back=clip(collar,rect(45,1090,150,CY));fronts=G.Curve.CreateBooleanIntersection(collar,rect(45,CY,150,1190),.002);assert fronts
    for i,c in enumerate(subtract(back,s['sky'])):
        region=plane_region(c)
        stage(solid_skin(region,lambda x,y:ground(x,y),lambda x,y:min(ROOF,ground(x,y)-.18),1.2),'Original_height_earth_cover_%d'%i,'terrain','grass')
    for j,front in enumerate(fronts):stage(solid_skin(plane_region(front),lambda x,y:ground(x,y),lambda x,y:FLOOR-.45,1.2),'Front_earth_retaining_collar_%d'%j,'terrain','grass')
    # Front rim rail is thin; bulk of the building remains below the source grade.
    for j,(a,b) in enumerate([(0,74),(106,180)]):
        def fn(t):
            p=ep(25.65,18.65,t);p.Z=ground(p.X,p.Y)+1.05;return p
        stage(beam(fn,math.radians(a),math.radians(b),.055,.055,64),'Court_rim_handrail_%d'%j,'metal','dark')
        for k in range(9):
            p=fn(math.radians(a+(b-a)*k/8));q=p-G.Vector3d(0,0,1.05)
            stage(beam(lambda t,p=p,q=q:q+(p-q)*t,0,1,.055,.055,1),'Court_rim_post_%d_%d'%(j,k),'metal','dark')
    s['ground_built']=True
    return {'parts':len(s['parts']),'replaced_hosts':list(s['replacements'])}

def build_access():
    s=state();top=s['stair_top']
    stage(slab(rect(93.5,1182.0,102.5,1188.0),top-.55,.55),'Short_entry_landing','access','floor')
    m=G.Mesh();count=64
    for i in range(count+1):
        t=i/count;p=G.Point3d(98-3*math.sin(math.pi*t),1182-18*t,0)
        tangent=G.Vector3d(-3*math.pi*math.cos(math.pi*t),-18,0);tangent.Unitize();side=G.Vector3d(-tangent.Y,tangent.X,0)
        left=p-side*3.3;right=p+side*3.3;z=top+(FLOOR-top)*t
        for q,h in [(left,FLOOR-.35),(right,FLOOR-.35),(right,z),(left,z)]:m.Vertices.Add(q.X,q.Y,h)
    for i in range(count):
        for j in range(4):
            a=4*i+j;b=4*i+(j+1)%4;m.Faces.AddFace(a,b,b+4,a+4)
    m.Faces.AddFace(3,2,1,0);a=4*count;m.Faces.AddFace(a,a+1,a+2,a+3)
    stage(finish(m),'Entrance_stairs_ramp-colonly','collision_helpers','floor')
    s['access_route']=[[98,1187.5,top],[98,1183,top],[98,1182,top]]
    s['access_max_grade']=None
    return {'short_landing_m':[9,6.0],'colonly_ramps':1,'external_path':False}

def commit():
    s=state();assert s.get('ground_built') and not s['ids']
    current=fingerprint();changed=[sid for sid in s['before'] if current.get(sid)!=s['before'][sid]]
    assert set(changed)<=set(s['replacements']) and set(current)==set(s['before'])
    assert all(current[sid][0]==old[0] for sid,old in s['before'].items()),'Source geometry changed while staging'
    record=sc.doc.BeginUndoRecord('Buried coastal sunken court');sc.doc.Views.RedrawEnabled=False
    try:
        for key,rgb,rough,metal,alpha in [('ivory',(228,224,211),.78,.02,1),('floor',(202,199,185),.85,0,1),('grass',(228,224,211),.90,0,1),('steel',(125,89,64),.82,.22,1),('dark',(66,72,70),.6,.25,1),('glass',(123,161,168),.22,0,.35),('soil',(112,116,76),.96,0,1),('green',(103,123,65),.95,0,1)]:
            # Independent names; source material definitions remain unchanged.
            s['materials'][key]=H['material']('Sunken_'+key,rgb,rough,metal,alpha)
        for sid,geo in s['replacements'].items():assert sc.doc.Objects.Replace(System.Guid(sid),geo)
        for geo,name,cat,mat,collision in s['parts']:
            at=Rhino.DocObjects.ObjectAttributes();at.Name='PR_SunkenCourt_'+name;at.LayerIndex=layer(LAYER+'::'+cat)
            at.MaterialIndex=s['materials'][mat];at.MaterialSource=Rhino.DocObjects.ObjectMaterialSource.MaterialFromObject
            at.ObjectColor=sc.doc.Materials[at.MaterialIndex].DiffuseColor
            for k,v in [('feature',TAG),('category',cat),('material_key',mat),('collision','1' if collision else '0'),('generator','tools/rhino_sunken_archive_1103.py')]:at.SetUserString(k,v)
            sid=sc.doc.Objects.Add(geo,at);assert sid!=System.Guid.Empty;s['ids'].append(str(sid))
            if cat=='collision_helpers':sc.doc.Objects.Hide(sid,True)
        sc.doc.Groups.Add('PR_SunkenCourt_1103',[System.Guid(sid) for sid in s['ids']])
    except:
        for sid in s['ids']:sc.doc.Objects.Delete(System.Guid(sid),True)
        for sid,(g,at) in s['originals'].items():sc.doc.Objects.Replace(System.Guid(sid),g);sc.doc.Objects.ModifyAttributes(System.Guid(sid),at,True)
        s['ids']=[];raise
    finally:sc.doc.EndUndoRecord(record);sc.doc.Views.RedrawEnabled=True;sc.doc.Views.Redraw()
    return audit()

def audit():
    s=state();after=fingerprint();changed=[sid for sid in s['before'] if after.get(sid)!=s['before'][sid]]
    assert set(changed)==set(s['replacements']),changed
    result={'feature':TAG,'objects':len(s['ids']),'object_ids':s['ids'],'changed_source_ids':changed,'unrelated_objects_unchanged':len(s['before'])-len(changed),'backup':s['backup'],'floor':FLOOR,'roof_top':ROOF,'sea_rooms':False,'main_floors':1}
    write('model_report.json',result);return {k:result[k] for k in ['objects','changed_source_ids','unrelated_objects_unchanged']}

def camera(name='overview'):
    views={'overview':([-12,1246,94],[98,1147,14],44),'road':([255,1126,19.8],[98,1149,14],42),
        'entry':([98,1193,16],[98,1147,12.5],32),'court':([99,1161,13.2],[96,1127,14],26),
        'gallery':([78,1136,13.2],[105,1150,13.3],28),'coast':([-8,1244,13],[99,1147,16],40)}
    eye,aim,lens=views[name];vp=sc.doc.Views.ActiveView.ActiveViewport
    vp.SetCameraLocations(G.Point3d(*aim),G.Point3d(*eye));vp.Camera35mmLensLength=lens
    sc.doc.Objects.UnselectAll();sc.doc.Views.Redraw()
def capture(name='overview'):
    camera(name);vc=Rhino.Display.ViewCapture();vc.Width=1700;vc.Height=1050;vc.DrawAxes=False;vc.DrawGrid=False;vc.DrawGridAxes=False
    bmp=vc.CaptureToBitmap(sc.doc.Views.ActiveView);assert bmp
    path=OUT+'/model_'+name+'.png';bmp.Save(path,System.Drawing.Imaging.ImageFormat.Png);bmp.Dispose();return path
def save():
    audit()
    for name in ['overview','road','entry','court','gallery','coast']:
        camera(name);sc.doc.NamedViews.Add('SunkenCourt_'+name+'_1103',sc.doc.Views.ActiveView.ActiveViewport.Id)
    camera();assert Rhino.RhinoApp.RunScript('_-Save _Enter',False) and not sc.doc.Modified
    disk=Rhino.FileIO.File3dm.Read(sc.doc.Path);assert disk
    assert len([o for o in disk.Objects if o.Attributes.GetUserString('feature')==TAG])==len(state()['ids'])
    return {'saved':sc.doc.Path,'readback_verified':True,'objects':len(state()['ids'])}
