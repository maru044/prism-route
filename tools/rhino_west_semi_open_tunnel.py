# -*- coding: utf-8 -*-
"""West middle-level tunnel B: shared-surface leaning gallery and closed lining.

Run prepare(), build(), cut_host(key), publish(), verify() separately in Rhino.
No road editing, separate CAD copy or version layers. Current scene only.
"""
from __future__ import unicode_literals, division
import Rhino, scriptcontext as sc, System, math, bisect, json, os
G = Rhino.Geometry
TAG = 'west_semi_open_tunnel_B_1020'
ROAD = '301ef8a8-0448-4086-b86d-3df7326e1caf'
HOSTS = ['27172e67-243a-4398-9933-89de8ecae12d',
         '012ab31c-3bd7-4f32-8676-9592c584ca4c',
         'd01b8d98-9f3d-46e7-8737-7b60ad7a5657',
         'de6391b1-e6fa-48bf-978c-b261e0d6d4b4']
# Footprint intervals, unequal spans following the actually exposed cliff.
WINDOWS = [(484., 548.), (555., 619.), (626., 697.),
           (704., 773.), (780., 843.)]
OUT = 'D:/Prism Route/prism-route/docs/concepts/west_semi_open_tunnel_2026-10-20_v01'

def obj(key): return sc.doc.Objects.FindId(System.Guid(key))

def objects():
    e=Rhino.DocObjects.ObjectEnumeratorSettings()
    e.NormalObjects=True; e.HiddenObjects=True; e.LockedObjects=True
    return list(sc.doc.Objects.GetObjectList(e))

def smooth(t):
    t=max(0., min(1., t)); return t*t*t*(10.+t*(-15.+6.*t))

def mesh(g):
    if isinstance(g, G.SubD): return G.Mesh.CreateFromSubD(g, 2)
    m=G.Mesh()
    for q in G.Mesh.CreateFromBrep(g, G.MeshingParameters.FastRenderMesh):m.Append(q)
    return m

def frame(s):
    d=sc.sticky[TAG]; c=d['route']; f=d['face']; L=d['length']
    ss=max(0., min(L, s))
    if ss==0.: t=c.Domain.T0
    elif ss==L: t=c.Domain.T1
    else:
        ok,t=c.LengthParameter(ss); assert ok
    p=c.PointAt(t); a=c.TangentAt(t); a.Z=0; a.Unitize()
    p+=a*(s-ss)
    n=f.PointAt(t, f.Domain(1).T1)-f.PointAt(t, f.Domain(1).T0)
    n.Z=0; n.Unitize()
    return p,a,n

def point(s,y,z):
    p,a,n=frame(s); p+=n*y; p.Z=z; return p

def radius(s):
    """Outer shell follows the existing cliff rather than floating behind it."""
    d=sc.sticky[TAG]; xs=d['radius_s']; ys=d['radius_values']
    i=max(0,min(len(xs)-2,bisect.bisect_right(xs,s)-1))
    u=max(0.,min(1.,(s-xs[i])/(xs[i+1]-xs[i])))
    return ys[i]*(1-u)+ys[i+1]*u

def prepare():
    assert sc.doc.Path.replace('\\','/').lower().endswith('/map/map_current.3dm')
    assert TAG not in sc.sticky, 'Existing staged work; reuse it rather than reset originals'
    assert not any(o.Attributes.GetUserString('west_tunnel_role')for o in objects()), 'Published model: edit existing assets; do not recapture cut hosts as originals'
    road=obj(ROAD); f=road.Geometry.Faces[1]
    c=f.IsoCurve(0,f.Domain(1).Mid); assert c.GetLength()>900
    d={'face':f,'route':c,'length':c.GetLength(),
       'before':{str(o.Id):int(o.Geometry.DataCRC(0))for o in objects()},
       'source':{key:obj(key).Geometry.DuplicateBrep()for key in HOSTS},
       'copies':{},'view':Rhino.DocObjects.ViewportInfo(sc.doc.Views.ActiveView.ActiveViewport),
       'display':sc.doc.Views.ActiveView.ActiveViewport.DisplayMode,
       'selected':[o.Id for o in sc.doc.Objects.GetSelectedObjects(False,False)],
       'hidden':{str(o.Id):o.IsHidden for o in objects()}}
    sc.sticky[TAG]=d
    wall=mesh(d['source'][HOSTS[0]]); ss=[]; rr=[]; actual=[]
    for i in range(61):
        s=470+(854-470)*i/60.;p,a,n=frame(s); p.Z=41.25
        hits=G.Intersect.Intersection.MeshLine(wall,G.Line(p-n*85,p+n*5))
        vals=[-G.Vector3d.Multiply(q-p,n)for q in hits]if hits else []
        r=min(vals)if vals else 14.
        actual.append(r); ss.append(s); rr.append(max(12.6,min(31.,r+.95)))
    d['radius_s']=ss; d['radius_values']=rr
    return {'length_m':d['length'],'open_range_m':[WINDOWS[0][0],WINDOWS[-1][1]],
            'existing_cliff_distance_m':[min(actual),max(actual)],'objects':len(d['before'])}

def perimeter(i0,i1,j0,j1):
    return ([(i,j0)for i in range(i0,i1)]+[(i1,j)for j in range(j0,j1)]
           +[(i,j1)for i in range(i1,i0,-1)]+[(i0,j)for j in range(j1,j0,-1)])

def station_warp(s, zfrac, blend):
    """Lean + widened feet/shoulders; reparameterize shared wall, not stuck-on piers."""
    knots=[-8.]; mapped=[-8.]
    # Whole opening leans along the road by eight meters from foot to shoulder.
    lean=8.*zfrac
    shrink=4.5*abs(2*zfrac-1)**1.65
    for a,b in WINDOWS:
        knots += [a,b]; mapped += [a+blend*(lean+shrink),b+blend*(lean-shrink)]
    knots += [sc.sticky[TAG]['length']+8.]; mapped += [knots[-1]]
    k=max(0,min(len(knots)-2,bisect.bisect_right(knots,s)-1))
    t=(s-knots[k])/(knots[k+1]-knots[k])
    return mapped[k]*(1-t)+mapped[k+1]*t

def build():
    d=sc.sticky[TAG]; L=d['length']; stations=[-6.,-5.7,-5.,0.,L,L+5.,L+5.7,L+6.]
    stations += [L*i/270 for i in range(1,270)]
    for a,b in WINDOWS:
        stations += [a-3.,a,a+3.,b-3.,b,b+3.]
    stations=sorted(set(stations)); nx=len(stations)-1
    # Cross-section runs from outer buried foot, up the wall and vault, to inner foot.
    # Positive y is the hill interior; outer facade follows negative y.
    cross=[(0.,34.15),(0.,34.4),(0.,35.65),(0.,36.1),
           (0.,38.0),(0.,40.7),(.12,43.0),(.9,44.8),
           (2.4,46.0),(4.8,47.1),(8.,47.8),(12.,48.25),
           (16.,48.4),(20.,48.05),(24.,47.0),(26.,45.6),
           (27.4,43.6),(28.,40.9),(28.,38.0),(28.,35.65),
           (28.,34.4),(28.,34.15)]
    ny=len(cross)-1; m=G.Mesh(); inner={}; outer={}; pi={}; po={}
    # Window holes in both skins; gallery expands this 9.15m baseline by 1.45.
    holes=[]
    for a,b in WINDOWS:
        i0=stations.index(a); i1=stations.index(b); holes.append((i0,i1,2,7))
    def holecell(i,j): return any(a<=i<b and c<=j<e for a,b,c,e in holes)
    for i,s in enumerate(stations):
        r=radius(s)
        # Closed sections stay compact; only the gallery widens towards the real cliff.
        gallery=smooth((s-445)/35.)*(1-smooth((s-850)/35.))
        r=14.+(r-14.)*gallery
        for j,(y,z) in enumerate(cross):
            zf=max(0.,min(1.,(z-35.65)/(44.8-35.65)))
            blend=1.-smooth((j-7)/5.)
            sw=station_warp(s,zf,blend)
            y=-r+y*(r+14.)/28.
            # A quiet longitudinal roof variation; piers remain integrated with vault.
            wave=.45*math.sin((sw-480)*math.pi/150.)*gallery*smooth((z-42)/5)
            if z>35.65:z=35.65+(z-35.65)*(1.+.45*gallery)
            z+=wave
            # Thickness follows the arch normal; avoids a thin stuck-on outer facade.
            if j<=6:dy=-1.55;dz=0.
            elif j==7:dy=-1.35;dz=.7
            elif j==8:dy=-.9;dz=1.2
            elif j==9:dy=-.45;dz=1.55
            elif j<=14:dy=0.;dz=1.7
            elif j==15:dy=.7;dz=1.3
            elif j==16:dy=1.3;dz=.7
            else:dy=1.55;dz=0.
            p=point(sw,y,z); q=point(sw,y+dy,z+dz)
            pi[i,j]=p; po[i,j]=q
            inner[i,j]=m.Vertices.Add(p); outer[i,j]=m.Vertices.Add(q)
    for i in range(nx):
        for j in range(ny):
            if holecell(i,j):continue
            m.Faces.AddFace(inner[i,j],inner[i+1,j],inner[i+1,j+1],inner[i,j+1])
            m.Faces.AddFace(outer[i,j+1],outer[i+1,j+1],outer[i+1,j],outer[i,j])
    # A rolled thickness around the entire shell perimeter and all five apertures.
    for loop in [perimeter(0,nx,0,ny)]+[perimeter(*h)for h in holes]:
        last=[inner[k]for k in loop]
        for t in [.24,.76,1.]:
            ring=[]
            for k in loop:
                p=pi[k]+(po[k]-pi[k])*t
                ring.append(outer[k]if t==1 else m.Vertices.Add(p))
            for k in range(len(loop)):
                q=(k+1)%len(loop);m.Faces.AddFace(last[k],ring[k],ring[q],last[q])
            last=ring
    m.Vertices.CullUnused();m.UnifyNormals();m.Normals.ComputeNormals();m.Compact()
    if m.SolidOrientation()<0:m.Flip(True,True,True)
    assert m.IsValid and m.IsClosed and m.IsManifold()
    sub=G.SubD.CreateFromMesh(m,G.SubDCreationOptions.Smooth)
    assert sub and sub.IsValid and sub.IsSolid
    limit=G.Mesh.CreateFromSubD(sub,2)
    assert limit.IsClosed and len(limit.SplitDisjointPieces())==1
    d.update(body=sub,limit=limit,control=m,stations=stations,cross=cross)
    # Excavation envelope intersects existing cliff while remaining embedded in lining.
    # Cutter only trims pre-existing surfaces, not added back as duplicate geometry.
    sections=[]
    for i in range(191):
        s=-10+(L+20)*i/190.;r=radius(s)
        gal=smooth((s-445)/35.)*(1-smooth((s-850)/35.))
        r=14.+(r-14.)*gal
        half_in=14.45;out=r+2.0
        # Gallery expands this baseline upward, remaining below the 60m plateau.
        yz=[(-out,34.35),(-out,45.6),(-out+2.,47.0),(-out+6.,48.3),
            (-out+12.,49.05),(0.,49.15),(9.,48.25),(13.3,45.9),
            (half_in,42.),(half_in,34.35)]
        pts=[point(s,y,35.65+(z-35.65)*(1.+.45*gal)if z>35.65 else z)for y,z in yz]
        sections.append(G.PolylineCurve(pts+[pts[0]]))
    q=G.Brep.CreateFromLoft(sections,G.Point3d.Unset,G.Point3d.Unset,G.LoftType.Normal,False)
    assert q and len(q)==1
    cutter=q[0].CapPlanarHoles(.01);assert cutter and cutter.IsValid and cutter.IsSolid
    if cutter.SolidOrientation==G.BrepSolidOrientation.Inward:cutter.Flip()
    d['cutter']=cutter
    return {'body_valid':sub.IsValid,'solid':sub.IsSolid,'single_connected':True,
            'openings':len(WINDOWS),'control_faces':int(m.Faces.Count),
            'cutter_faces':cutter.Faces.Count}

def cut_host(key):
    d=sc.sticky[TAG];g=d['source'][key]
    pieces=g.Split(d['cutter'],.015)
    if not pieces or len(pieces)<2:return {'id':key,'split':0,'changed':False}
    kept=[];removed=[]
    for q in pieces:
        # A trimmed U-shaped strip's area centroid can lie far off its surface.
        # Sample actual tessellated faces, then project back onto the trimmed Brep.
        qm=mesh(q);pts=[];step=max(1,int(qm.Faces.Count/101))
        for i in range(0,qm.Faces.Count,step):
            f=qm.Faces[i]
            p=(G.Point3d(qm.Vertices[f.A])+G.Point3d(qm.Vertices[f.B])+G.Point3d(qm.Vertices[f.C]))/3.
            pts.append(q.ClosestPoint(p))
        assert pts
        inside=sum(1 for p in pts if d['cutter'].IsPointInside(p,.02,False))>len(pts)*.5
        (removed if inside else kept).append(q)
    if not removed:return {'id':key,'split':len(pieces),'changed':False}
    assert kept,'Entire host would be removed'
    result=G.Brep()
    for q in kept:result.Append(q)
    assert result.IsValid
    d['copies'][key]=result
    return {'id':key,'split':len(pieces),'removed':len(removed),
            'kept':len(kept),'faces':result.Faces.Count,'valid':result.IsValid}

def build_base():
    """Continuous closed floor, shoulder and buried underside, under both wall feet."""
    d=sc.sticky[TAG];L=d['length'];sections=[]
    for i in range(241):
        s=-6+(L+12)*i/240.;r=radius(s)
        gal=smooth((s-445)/35.)*(1-smooth((s-850)/35.))
        r=14.+(r-14.)*gal
        # Top outside the 20m roadway forms continuous side walks/floor strips.
        # Roof/side-wall feet end at 34.15m and embed into this 33.15-35.14m base.
        yz=[(-r-1.9,35.0),(-r-1.65,35.14),(-r+.0,35.14),
            (-11.7,35.14),(-10.3,35.03),(0.,35.03),(10.3,35.03),
            (11.7,35.14),(14.,35.14),(15.65,35.14),(15.9,35.0),
            (15.9,33.5),(15.55,33.15),(10.,33.15),(0.,33.15),
            (-r+4.,33.15),(-r-1.55,33.15),(-r-1.9,33.5)]
        pts=[point(s,y,z)for y,z in yz]
        sections.append(G.PolylineCurve(pts+[pts[0]]))
    q=G.Brep.CreateFromLoft(sections,G.Point3d.Unset,G.Point3d.Unset,G.LoftType.Normal,False)
    assert q and len(q)==1
    base=q[0].CapPlanarHoles(.005);assert base and base.IsValid and base.IsSolid
    if base.SolidOrientation==G.BrepSolidOrientation.Inward:base.Flip()
    d['base']=base
    return {'floor_solid':True,'faces':base.Faces.Count,'wall_feet_embedded_m':1.,
            'floor_top_m':35.14,'buried_bottom_m':33.15}

def publish():
    d=sc.sticky[TAG];assert d['copies'],'No cliff opening was created'
    assert not any(obj(key).Attributes.GetUserString('vertical_wall_recipe')for key in d['copies']), 'Wall subsequently rebuilt vertically: discard cached twisted host copies and rebuild excavation before publishing'
    layer=sc.doc.Layers.FindByFullPath('交通::隧道',-1);assert layer>=0
    mi=next(i for i,m in enumerate(sc.doc.Materials)if m.Name=='隧道_暖白建筑复合面_PBR_非金属')
    undo=sc.doc.BeginUndoRecord('西侧中层_B方案倾斜曲面拱肩与连续封闭隧道')
    try:
        for key,g in d['copies'].items():assert sc.doc.Objects.Replace(System.Guid(key),g)
        old=next((o for o in objects()if o.Attributes.GetUserString('west_tunnel_role')=='lining'),None)
        if old:
            assert sc.doc.Objects.Replace(old.Id,d['body']);oid=old.Id
        else:
            a=Rhino.DocObjects.ObjectAttributes();a.LayerIndex=layer
            a.Name='西侧中层隧道_B_倾斜流线拱肩与连续拱顶内壁'
            a.MaterialIndex=mi;a.MaterialSource=Rhino.DocObjects.ObjectMaterialSource.MaterialFromObject
            a.WireDensity=-1;a.SetUserString('recipe',TAG);a.SetUserString('west_tunnel_role','lining')
            a.SetUserString('source_road',ROAD);a.SetUserString('open_station_range','484-843 m; five apertures')
            oid=sc.doc.Objects.AddSubD(d['body'],a);assert oid!=System.Guid.Empty
        d['body_id']=str(oid)
        if 'base'in d:
            old=next((o for o in objects()if o.Attributes.GetUserString('west_tunnel_role')=='floor'),None)
            if old:
                assert sc.doc.Objects.Replace(old.Id,d['base']);oid=old.Id
            else:
                a=Rhino.DocObjects.ObjectAttributes();a.LayerIndex=layer
                a.Name='西侧中层隧道_B_连续底板与崖壁搭接基座'
                a.MaterialIndex=mi;a.MaterialSource=Rhino.DocObjects.ObjectMaterialSource.MaterialFromObject
                a.WireDensity=-1;a.SetUserString('recipe',TAG);a.SetUserString('west_tunnel_role','floor')
                a.SetUserString('source_road',ROAD)
                oid=sc.doc.Objects.AddBrep(d['base'],a);assert oid!=System.Guid.Empty
            d['base_id']=str(oid)
    finally:sc.doc.EndUndoRecord(undo)
    sc.doc.Objects.UnselectAll();sc.doc.Views.Redraw()
    return {'body':d['body_id'],'floor':d.get('base_id'),'changed_hosts':list(d['copies'])}

def verify():
    d=sc.sticky[TAG];now={str(o.Id):o for o in objects()}
    changed=[k for k,crc in d['before'].items()if k in now and int(now[k].Geometry.DataCRC(0))!=crc]
    assert set(changed)==set(d['copies']),changed
    assert not set(d['before']).difference(now)
    added=[d['body_id']]+([d['base_id']]if 'base_id'in d else [])
    assert set(now).difference(d['before'])==set(added)
    m=mesh(now[d['body_id']].Geometry);obstacles=G.Mesh()
    if 'base_id'in d:m.Append(mesh(now[d['base_id']].Geometry))
    for key in d['copies']:
        obstacles.Append(mesh(now[key].Geometry))
    m.Append(obstacles);intrusions=[];ceilings=[]
    for i in range(301):
        s=d['length']*i/300.
        for y in [-9.6,-5.,0.,5.,9.6]:
            p=point(s,y,35.30)
            hits=G.Intersect.Intersection.MeshLine(m,G.Line(p,p+G.Vector3d(0,0,6.0)))
            if hits and len(hits):intrusions.append([s,y])
            t=G.Intersect.Intersection.MeshRay(m,G.Ray3d(p,G.Vector3d.ZAxis))
            if t>=0:ceilings.append(t+.05)
    # Check gallery's external sightlines against BOTH lining and retained cliff.
    openings=[]
    for a,b in WINDOWS:
        s=(a+b)*.5
        for z in [38.,40.5,43.]:
            p=point(s,-9.8,z);q=point(s,-radius(s)-8.,z)
            hits=G.Intersect.Intersection.MeshLine(m,G.Line(p,q))
            openings.append({'station':s,'z':z,'blocked':bool(hits and len(hits))})
    floor_gaps=[];floor_misses=[];feet_misses=[]
    if 'base_id'in d:
        fm=mesh(now[d['base_id']].Geometry)
        for i in range(201):
            s=d['length']*i/200.
            for y in [-10.,0.,10.]:
                t=G.Intersect.Intersection.MeshRay(fm,G.Ray3d(point(s,y,35.35),-G.Vector3d.ZAxis))
                if t<0:floor_misses.append([s,y])
                else:floor_gaps.append(t-.10)
            # Continuous floor under every side wall, including the widened opening transition.
            gal=smooth((s-445)/35.)*(1-smooth((s-850)/35.))
            r=14.+(radius(s)-14.)*gal
            for y in [-r-.7,14.7]:
                if not now[d['base_id']].Geometry.IsPointInside(point(s,y,34.4),.01,False):feet_misses.append([s,y])
    report={'objects':len(now),'changed_originals':changed,'added':added,
            'road_geometry_unchanged':int(obj(ROAD).Geometry.DataCRC(0))==d['before'][ROAD],
            'road_clearance_samples':1505,'intrusions':intrusions,
            'minimum_sampled_headroom_m':min(ceilings)if ceilings else None,
            'gallery_sightlines':openings,'body_valid':now[d['body_id']].Geometry.IsValid,
            'body_solid':now[d['body_id']].Geometry.IsSolid,
            'floor_misses':floor_misses,'wall_foot_floor_misses':feet_misses,
            'floor_below_road_m':[min(floor_gaps),max(floor_gaps)]if floor_gaps else None}
    d['report']=report
    return report

def capture(name, camera=None, target=None, mode='Rendered'):
    d=sc.sticky[TAG];view=sc.doc.Views.ActiveView;vp=view.ActiveViewport
    if camera is not None:
        vp.SetCameraLocations(G.Point3d(*target),G.Point3d(*camera))
        vp.CameraUp=G.Vector3d.ZAxis
        vp.ChangeToPerspectiveProjection(True,42.)
    display=next((m for m in Rhino.Display.DisplayModeDescription.GetDisplayModes()
                  if m.EnglishName==mode),None)
    if display:vp.DisplayMode=display
    sc.doc.Views.Redraw()
    vc=Rhino.Display.ViewCapture();vc.Width=1600;vc.Height=1050
    vc.ScaleScreenItems=False;vc.DrawAxes=False;vc.DrawGrid=False;vc.DrawGridAxes=False
    bitmap=vc.CaptureToBitmap(view);assert bitmap
    path=OUT+'/'+name+'.png';bitmap.Save(path,System.Drawing.Imaging.ImageFormat.Png);bitmap.Dispose()
    return path

def restore_view():
    d=sc.sticky[TAG];vp=sc.doc.Views.ActiveView.ActiveViewport
    vp.SetViewProjection(d['view'],False);vp.DisplayMode=d['display']
    sc.doc.Views.Redraw()

def save_current():
    d=sc.sticky[TAG];report=verify()
    assert not report['intrusions']
    assert not any(q['blocked']for q in report['gallery_sightlines'])
    assert not report['floor_misses'] and not report['wall_foot_floor_misses']
    assert report['body_valid'] and report['body_solid']
    assert obj(d['base_id']).Geometry.IsSolid
    assert Rhino.RhinoApp.RunScript('_Save',False),'Current scene save failed'
    return {'path':sc.doc.Path,'modified':sc.doc.Modified}

def verify_saved():
    d=sc.sticky[TAG];saved=Rhino.FileIO.File3dm.Read(sc.doc.Path);assert saved
    live={str(o.Id):int(o.Geometry.DataCRC(0))for o in objects()}
    disk={str(o.Id):int(o.Geometry.DataCRC(0))for o in saved.Objects}
    assert live==disk,'Saved geometry differs from live document'
    saved.Dispose()
    d['report']['saved_geometry_match']=True
    d['report']['saved_object_count']=len(disk)
    d['report']['wall_foot_vertex_samples']=d.get('foot_vertex_report')
    import io
    with io.open(OUT+'/validation.json','w',encoding='utf-8')as f:
        f.write(json.dumps(d['report'],ensure_ascii=False,indent=2))
    return {'all_saved_objects_match':True,'count':len(disk),'path':sc.doc.Path}
