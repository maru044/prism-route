# -*- coding: utf-8 -*-
"""Move meaningful open structure to T1/T2 tunnel mouths; preserve solid ends.

Use current v04 bodies, restore its isolated east pocket, open all affected
tiers at both road crossings, and build adapted continuous portal supports.
"""
from __future__ import division, unicode_literals
import Rhino,scriptcontext as sc,System,io,os,json,math
from System.Drawing import Color
from System.Drawing.Imaging import ImageFormat
G=Rhino.Geometry
ROOT=os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT=os.path.join(ROOT,'docs','concepts','cliff_terraces_2026-10-15','exposed_portals_v05')
TAG='prism_exposed_tunnel_portals_v05'
LAYER='崖岸_隧道入口外露支撑_v05'
p=os.path.join(ROOT,'tools','rhino_hybrid_solid_terrain_v04.py');base={'__file__':p,'__name__':'helpers'}
s=io.open(p,encoding='utf-8').read();exec(compile('\n'.join(s.splitlines()[1:]),p,'exec'),base)
obj=base['obj'];oriented=base['oriented'];difference=base['difference'];body_from_roof=base['body_from_roof'];save_doc=base['save_doc']

def write(name,data):
    if not os.path.isdir(OUT):os.makedirs(OUT)
    with io.open(os.path.join(OUT,name),'w',encoding='utf-8') as f:f.write(json.dumps(data,ensure_ascii=False,indent=2,default=str))
def xyz(p):return [float(p.X),float(p.Y),float(p.Z)]

def opening(site,start,end):
    a=[];b=[]
    for i in range(45):
        s=start+(end-start)*i/44;p=site.rail.PointAt(site.rail.Domain.ParameterAt(s))
        ok,u,v=site.face.ClosestPoint(p);n=-site.face.NormalAt(u,v);n.Z=0;n.Unitize()
        front=p-n*8;back=p+n*340;a.append(G.Point3d(front.X,front.Y,-12));b.append(G.Point3d(back.X,back.Y,-12))
    ca=G.Curve.CreateInterpolatedCurve(a,3);cb=G.Curve.CreateInterpolatedCurve(list(reversed(b)),3);loop=G.PolyCurve()
    loop.Append(ca);loop.Append(G.LineCurve(ca.PointAtEnd,cb.PointAtStart));loop.Append(cb);loop.Append(G.LineCurve(cb.PointAtEnd,ca.PointAtStart))
    g=G.Extrusion.Create(loop,90,True).ToBrep()
    if g.GetBoundingBox(True).Max.Z<0:g.Transform(G.Transform.Translation(0,0,90))
    return oriented(g)

def support_cell(site,spec,main_faces,low_face):
    p=os.path.join(ROOT,'tools','rhino_continuous_support_cell_v03.py');source=io.open(p,encoding='utf-8').read()
    source=source.replace('depth=7.5+3.5*math.sin(math.pi*f)**2+9.5*root_weight*math.sin(math.pi*f)**2',
        'depth=3.5+1.5*math.sin(math.pi*f)**2+4.5*root_weight*math.sin(math.pi*f)**2')
    source=source.replace('lean=1 if number==0 else -1','lean=-1 if number==0 else 1')
    source=source.replace('b=G.Point3d(p.X,p.Y,p.Z-depth);points[i,j]=b;bottom[i,j]=vertex(b)',
        "b=G.Point3d(p.X,p.Y,p.Z-depth)\n            reserve=site.road_floor(p)\n            if isinstance(reserve,tuple):\n                needed,weight=reserve;b.Z=min(p.Z-.35,b.Z*(1-weight)+max(b.Z,needed+1.5)*weight)\n            points[i,j]=b;bottom[i,j]=vertex(b)")
    ns={'__file__':p,'__name__':'portal_cell'};exec(compile('\n'.join(source.splitlines()[1:]),p,'exec'),ns)
    ns['TAG']=TAG+'_'+spec['name'];ns['OUT']=os.path.join(OUT,spec['name']);ns['START']=spec['start'];ns['END']=spec['end']
    if spec.get('single'):ns['ROOTS']=[(6,18,2,10)]
    face=low_face if spec['tier']=='low' else main_faces[0]
    def fitted(site,q,f):
        station=spec['start']+(spec['end']-spec['start'])*q;u=site.rail.Domain.ParameterAt(station)
        lo=.025;hi=.975
        if spec['tier']=='main' and spec.get('adapt_trim'):
            valid=[k/100 for k in range(1,100) if any(a.IsPointOnFace(u,a.Domain(1).ParameterAt(k/100))!=G.PointFaceRelation.Exterior for a in main_faces)]
            if not valid:raise RuntimeError('Upper portal extends beyond original trimmed roof')
            lo=min(valid)+.01;hi=max(valid)-.01
            if hi-lo<.035:raise RuntimeError('Upper portal roof too narrow')
        point=face.PointAt(u,face.Domain(1).ParameterAt(lo+(hi-lo)*f));point.Z-=.65
        return point
    ns['roof']=fitted;ns['build']();data=sc.sticky[ns['TAG']]
    data['spec']=spec
    return data

def prepare():
    if any(o.Attributes.GetUserString('recipe')==TAG for o in sc.doc.Objects):raise RuntimeError('Portal version already published')
    old=sc.sticky['prism_hybrid_solid_terrain_v04'];original=sc.sticky['prism_cliff_terrace_inset_v02'];site=original['site']
    centers=[]
    for r in site.roads:
        ok,t=site.rail.ClosestPoint(r['hit']);centers.append((t-site.rail.Domain.T0)/site.rail.Domain.Length)
    zones=[{'name':'T1','start':centers[0]-.045,'end':centers[0]+.045},
        {'name':'T2','start':centers[1]-.041,'end':centers[1]+.043}]
    cutters=[opening(site,z['start'],z['end']) for z in zones]
    bodies=[obj(r['id']).Geometry.DuplicateBrep() for r in old['state']['objects'] if r['group']=='01_连续实体底层']
    # Fill the previous, unrelated support pocket using its exact original roof.
    east=obj(base['SOURCES'][0][0]).Geometry.Faces[1].DuplicateFace(False)
    full=body_from_roof(east);restoration=G.Brep.CreateBooleanIntersection(full,old['opening'],.01)
    if not restoration:raise RuntimeError('Old east pocket restoration failed')
    restoration=[oriented(g) for g in restoration]
    for corridor in original['corridors']:restoration=difference(restoration,corridor)
    bodies.extend(restoration);initial_volume=sum(G.VolumeMassProperties.Compute(g).Volume for g in bodies)
    for cutter in cutters:bodies=difference(bodies,cutter)
    covers=[];main_faces=[];low_face=None
    for index,(oid,fi,name) in enumerate(base['SOURCES']):
        f=obj(oid).Geometry.Faces[fi];roof=f.DuplicateFace(False)
        if index<3:main_faces.append(f)
        else:low_face=f
        skin=body_from_roof(roof,True)
        for zi,cutter in enumerate(cutters):
            parts=G.Brep.CreateBooleanIntersection(skin,cutter,.01)
            if not parts:continue
            parts=[oriented(g) for g in parts]
            for corridor in original['corridors']:parts=difference(parts,corridor)
            covers.extend({'name':zones[zi]['name']+'_'+name+'_保留顶面','geometry':g,'portal':zones[zi]['name']} for g in parts)
    specs=[{'name':'T1_front','portal':'T1','tier':'low','start':centers[0]-.052,'end':centers[0]+.052},
        {'name':'T1_upper_fan','portal':'T1','tier':'main','start':.458,'end':.492,'single':True,'adapt_trim':True},
        {'name':'T2_front','portal':'T2','tier':'low','start':centers[1]-.048,'end':centers[1]+.052},
        {'name':'T2_rear','portal':'T2','tier':'main','start':centers[1]-.028,'end':centers[1]+.034}]
    cells=[support_cell(site,s,main_faces,low_face) for s in specs]
    plants=[r for r in old['state']['objects'] if r['group']=='04_种植顶面' and obj(r['id']) is not None]
    crc={str(o.Id):int(o.Geometry.DataCRC(0)) for o in sc.doc.Objects if isinstance(o.Geometry,(G.Brep,G.SubD,G.Extrusion)) and not o.IsDeleted}
    remaining=sum(G.VolumeMassProperties.Compute(g).Volume for g in bodies)
    state={'recipe':TAG,'objects':[],'source_crc':crc,'zones':zones,'cells':[c['spec'] for c in cells],
        'initial_body_volume_sum_m3':initial_volume,'remaining_body_volume_sum_m3':remaining,'body_retention_fraction':remaining/initial_volume,
        'old_unrelated_pocket_restored':True,'design':'Exposed layered continuous structure at both road portals; foreground and rear blocking masses removed locally; solid ends retained.'}
    sc.sticky[TAG]={'old':old,'original':original,'site':site,'zones':zones,'cutters':cutters,'bodies':bodies,'covers':covers,'cells':cells,'plants':plants,'state':state}
    write('prepare_report.json',state);print(json.dumps({'prepared':True,'bodies':len(bodies),'covers':len(covers),'continuous_cells':len(cells),'retained_body_fraction':remaining/initial_volume},ensure_ascii=False))

def layer(child,color):
    root=sc.doc.Layers.FindByFullPath(LAYER,-1)
    if root<0:
        l=Rhino.DocObjects.Layer();l.Name=LAYER;root=sc.doc.Layers.Add(l)
    index=sc.doc.Layers.FindByFullPath(LAYER+'::'+child,-1)
    if index<0:
        l=Rhino.DocObjects.Layer();l.Name=child;l.ParentLayerId=sc.doc.Layers[root].Id;l.Color=color;index=sc.doc.Layers.Add(l)
    return index

def publish():
    data=sc.sticky[TAG];state=data['state'];doc=sc.doc
    for oid,crc in state['source_crc'].items():
        if int(obj(oid).Geometry.DataCRC(0))!=crc:raise RuntimeError('Source changed '+oid)
    backup=os.path.join(os.path.dirname(ROOT),'map','map_before_exposed_portals_v05.3dm')
    if os.path.exists(backup):raise RuntimeError('Preserve existing backup')
    save_doc(backup);state['backup']=backup;undo=doc.BeginUndoRecord('两处隧道入口外露连续支撑 v05')
    try:
        white=Color.FromArgb(238,234,225);m=Rhino.DocObjects.Material();m.Name='入口曲面_暖白高光';m.DiffuseColor=white;m.Shine=85;m.Reflectivity=.16;mi=doc.Materials.Add(m)
        mp=G.MeshingParameters();mp.Tolerance=.025;mp.RelativeTolerance=0;mp.MaximumEdgeLength=8;mp.RefineGrid=True;mp.JaggedSeams=False
        def add(g,name,group,portal=None,attributes=None):
            a=attributes.Duplicate() if attributes else Rhino.DocObjects.ObjectAttributes();a.Name=name;a.LayerIndex=layer(group,white);a.SetUserString('recipe',TAG)
            if not attributes:a.MaterialIndex=mi;a.MaterialSource=Rhino.DocObjects.ObjectMaterialSource.MaterialFromObject
            a.CustomMeshingParameters=mp
            oid=doc.Objects.AddSubD(g,a) if isinstance(g,G.SubD) else doc.Objects.AddBrep(g,a)
            if oid==System.Guid.Empty:raise RuntimeError('Add failed')
            state['objects'].append({'id':str(oid),'name':name,'group':group,'portal':portal})
        for i,g in enumerate(data['bodies']):add(g,'保留实体与恢复旧空廊_%02d'%i,'01_实体段与端部')
        for r in data['covers']:add(r['geometry'],r['name'],'02_入口原顶面',r['portal'])
        for c in data['cells']:add(c['subd'],c['spec']['name']+'_连续展开支撑','03_入口外露连续结构',c['spec']['portal'])
        for i,r in enumerate(data['plants']):
            o=obj(r['id']);add(o.Geometry,'保留种植顶面_%02d'%i,'04_种植顶面',attributes=o.Attributes)
        index=doc.Layers.FindByFullPath(base['LAYER'],-1);l=doc.Layers[index];l.IsVisible=False;doc.Layers.Modify(l,index,True);doc.Objects.UnselectAll()
    finally:doc.EndUndoRecord(undo);doc.Views.Redraw()
    state['draft_path']=os.path.join(os.path.dirname(ROOT),'map','map_exposed_portals_v05.3dm');save_doc(state['draft_path']);write('generation_state.json',state)
    print(json.dumps({'published':True,'objects':len(state['objects']),'draft':state['draft_path']},ensure_ascii=False))

def verification_mesh():
    data=sc.sticky[TAG];mp=G.MeshingParameters();mp.Tolerance=.04;mp.RelativeTolerance=0;mp.MaximumEdgeLength=8;mp.RefineGrid=True;mesh=G.Mesh();failures=[]
    for r in data['state']['objects']:
        g=obj(r['id']).Geometry
        if not g.IsValid:failures.append('Invalid '+r['name'])
        if r['group'] in ['04_种植顶面','06_SubD编辑源_隐藏']:continue
        if not g.IsSolid:failures.append('Open '+r['name'])
        parts=[G.Mesh.CreateFromSubD(g,3)] if isinstance(g,G.SubD) else G.Mesh.CreateFromBrep(g,mp)
        for m in parts or []:mesh.Append(m)
    return mesh,failures

def verify():
    data=sc.sticky[TAG];state=data['state'];mesh,failures=verification_mesh()
    for oid,crc in state['source_crc'].items():
        if int(obj(oid).Geometry.DataCRC(0))!=crc:failures.append('Source changed '+oid)
    b=mesh.GetBoundingBox(True)
    if b.Max.Z>60.918:failures.append('Height exceeded')
    passages=[]
    for index,r in enumerate(data['site'].roads):
        face=obj(r['id']).Geometry.Faces[0];curve=r['curve'];lo=max(0,r['station']-320);hi=min(curve.GetLength(),r['station']+320);bad=[];hits=0;minimum=1e10
        for i in range(129):
            ok,t=curve.LengthParameter(lo+(hi-lo)*i/128);ok,u,v=face.ClosestPoint(curve.PointAt(t))
            for f in [.03,.18,.34,.5,.66,.82,.97]:
                p=face.PointAt(face.Domain(0).ParameterAt(f),v);distance=G.Intersect.Intersection.MeshRay(mesh,G.Ray3d(p+G.Vector3d(0,0,.05),G.Vector3d.ZAxis))
                if distance>=0:
                    hits+=1;clearance=distance+.05;minimum=min(minimum,clearance)
                    if clearance<9.8:bad.append({'point':xyz(p),'clearance_m':clearance})
        if bad:failures.append('T%d clearance'%(index+1))
        passages.append({'road':'T%d'%(index+1),'samples':903,'hits':hits,'minimum_clearance_m':None if minimum==1e10 else minimum,'violations':bad})
    result={'failures':failures,'passages':passages,'maximum_height_m':b.Max.Z,'body_retention_fraction':state['body_retention_fraction'],
        'sources_unchanged':not any('Source changed' in s for s in failures),'limitations':'Closed components overlap at joins; not globally unioned/G2 certified. Sampled road rays do not certify full collision, structure or game traversal.'}
    write('verification_report.json',result);print(json.dumps({'failures':failures,'passages':passages,'maximum_height_m':b.Max.Z},ensure_ascii=False));return result

def unify_top_surfaces():
    """Defer undesigned planting masks; retain hidden overlays for later editing."""
    data=sc.sticky[TAG];doc=sc.doc
    index=doc.Layers.FindByFullPath(LAYER+'::04_种植顶面',-1)
    if index<0:raise RuntimeError('Plant overlay layer missing')
    undo=doc.BeginUndoRecord('取消暂定种植分区，统一暖白顶面')
    try:
        l=doc.Layers[index];l.IsVisible=False
        l.SetPersistentVisibility(False)
        if not doc.Layers.Modify(l,index,True):raise RuntimeError('Layer update failed')
        rows=[r for r in data['state']['objects'] if r['group']=='04_种植顶面']
        for r in rows:
            o=obj(r['id'])
            if not o.IsHidden:doc.Objects.Hide(o.Id,True)
        if any(not obj(r['id']).IsHidden for r in rows):raise RuntimeError('Overlay hiding failed')
    finally:doc.EndUndoRecord(undo);doc.Views.Redraw()
    data['state']['top_surface_design']='Unified warm-white architectural surface; planting overlays hidden until actual planting design.'
    write('generation_state.json',data['state']);save_doc(data['state']['draft_path'])
    print(json.dumps({'uniform_white_top':True,'hidden_overlays':len(rows),'overlays_preserved':True}))

def capture():
    data=sc.sticky[TAG];view=sc.doc.Views.ActiveView;views=[]
    for i,r in enumerate(data['site'].roads):
        ok,t=r['curve'].LengthParameter(max(0,r['station']-145));camera=r['curve'].PointAt(t)+G.Vector3d(0,0,9)
        views.append(('0%d_T%d_road_approach.png'%(i+1,i+1),camera,r['hit']+G.Vector3d(0,0,9)))
    views.append(('03_overview.png',G.Point3d(1250,3020,710),G.Point3d(1060,880,25)))
    for name,camera,target in views:
        view.ActiveViewport.SetCameraLocations(target,camera);sc.doc.Views.Redraw();c=Rhino.Display.ViewCapture();c.Width=1920;c.Height=1080;c.DrawGrid=False;c.DrawAxes=False;c.DrawGridAxes=False
        b=c.CaptureToBitmap(view);b.Save(os.path.join(OUT,name),ImageFormat.Png);b.Dispose()
    view.ActiveViewport.SetCameraLocations(views[0][2],views[0][1]);sc.doc.Views.Redraw();save_doc(data['state']['draft_path']);print(json.dumps({'captures':[v[0] for v in views]}))

def conform_to_road_reserves():
    data=sc.sticky[TAG];state=data['state'];updates=[]
    for cell in data['cells']:
        row=next(r for r in state['objects'] if r['name']==cell['spec']['name']+'_连续展开支撑')
        road_index=0 if cell['spec']['portal']=='T1' else 1
        brep=cell['subd'].ToBrep(G.SubDToBrepOptions.DefaultPacked)
        parts=difference([oriented(brep)],data['original']['corridors'][road_index])
        if len(parts)!=1:raise RuntimeError('Road reserve disconnected a support; revise its foot layout')
        updates.append((row,cell,parts[0]))
    undo=sc.doc.BeginUndoRecord('入口拱腹匹配实际道路净空')
    try:
        source_index=layer('06_SubD编辑源_隐藏',Color.Gray)
        l=sc.doc.Layers[source_index];l.IsVisible=False;sc.doc.Layers.Modify(l,source_index,True)
        for row,cell,g in updates:
            o=obj(row['id'])
            if o.Attributes.GetUserString('recipe')!=TAG:raise RuntimeError('Ownership changed')
            a=o.Attributes.Duplicate();a.LayerIndex=source_index;a.Name=cell['spec']['name']+'_SubD编辑源';a.SetUserString('production_object',row['id'])
            backup=sc.doc.Objects.AddSubD(cell['subd'],a)
            state['objects'].append({'id':str(backup),'name':a.Name,'group':'06_SubD编辑源_隐藏','portal':cell['spec']['portal']})
            if not sc.doc.Objects.Replace(o.Id,g):raise RuntimeError('Support reserve update failed')
            cell['production_geometry']=g
    finally:sc.doc.EndUndoRecord(undo);sc.doc.Views.Redraw()
    state['road_fitted_supports']=len(updates);write('generation_state.json',state);save_doc(state['draft_path'])
    print(json.dumps({'road_fitted_supports':len(updates),'native_SubD_sources_preserved':True}))
