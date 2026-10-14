# -*- coding: utf-8 -*-
"""Keep the v02 roofs; solid terrain dominates, with two road passages and
one deliberately limited shared-topology support zone on the east side.
"""
from __future__ import division, unicode_literals
import Rhino,scriptcontext as sc,System,io,os,json,math
from System.Drawing import Color
from System.Drawing.Imaging import ImageFormat
G=Rhino.Geometry
ROOT=os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT=os.path.join(ROOT,'docs','concepts','cliff_terraces_2026-10-15','hybrid_solid_v04')
TAG='prism_hybrid_solid_terrain_v04'
LAYER='崖岸_实体为主_局部连续支撑_v04'
SOURCES=[('6ff4660f-d023-461f-a4ac-9f0038a79c6d',1,'东侧实体主台'),
    ('de6391b1-e6fa-48bf-978c-b261e0d6d4b4',0,'西侧实体主台'),
    ('f0fd81ff-2de8-49cb-be97-a312dd9b3933',0,'中央实体连接'),
    ('f6bf901b-4e02-49c2-8a1c-6382c255c941',1,'湾缘实体低台')]
OPEN_START=.747;OPEN_END=.803

def obj(oid):
    o=sc.doc.Objects.FindId(System.Guid(oid))
    if o is None:raise RuntimeError('Missing '+oid)
    return o
def xyz(p):return [float(p.X),float(p.Y),float(p.Z)]
def write(name,data):
    if not os.path.isdir(OUT):os.makedirs(OUT)
    with io.open(os.path.join(OUT,name),'w',encoding='utf-8') as f:f.write(json.dumps(data,ensure_ascii=False,indent=2,default=str))
def oriented(g):
    if not g.IsValid or not g.IsSolid:raise RuntimeError('Expected valid closed Brep')
    if g.SolidOrientation==G.BrepSolidOrientation.Inward:g.Flip()
    return g

def body_from_roof(top,skin=False):
    parts=[top.DuplicateBrep()]
    if skin:
        bottom=top.DuplicateBrep();bottom.Transform(G.Transform.Translation(0,0,-3.8));parts.append(bottom)
    else:
        loops=[]
        for loop in top.Faces[0].Loops:
            c=loop.To3dCurve();c.Transform(G.Transform.PlanarProjection(G.Plane.WorldXY));c.Transform(G.Transform.Translation(0,0,-2));loops.append(c)
        caps=G.Brep.CreatePlanarBreps(loops,.005)
        if not caps:raise RuntimeError('Ground closure failed')
        parts.extend(caps)
    for e in top.Edges:
        a=e.DuplicateCurve();b=a.DuplicateCurve()
        if skin:b.Transform(G.Transform.Translation(0,0,-3.8))
        else:b.Transform(G.Transform.PlanarProjection(G.Plane.WorldXY));b.Transform(G.Transform.Translation(0,0,-2))
        sides=G.Brep.CreateFromLoft([a,b],G.Point3d.Unset,G.Point3d.Unset,G.LoftType.Straight,False)
        if not sides:raise RuntimeError('Side closure failed')
        parts.extend(sides)
    joined=G.Brep.JoinBreps(parts,.01)
    if not joined or len(joined)!=1:raise RuntimeError('Roof/side/base closure failed')
    return oriented(joined[0])

def slot(site):
    first=[];second=[]
    for i in range(35):
        s=OPEN_START+(OPEN_END-OPEN_START)*i/34;p=site.rail.PointAt(site.rail.Domain.ParameterAt(s))
        ok,u,v=site.face.ClosestPoint(p);n=-site.face.NormalAt(u,v);n.Z=0;n.Unitize()
        first.append(G.Point3d(p.X,p.Y,-12));q=p+n*360;second.append(G.Point3d(q.X,q.Y,-12))
    a=G.Curve.CreateInterpolatedCurve(first,3);b=G.Curve.CreateInterpolatedCurve(list(reversed(second)),3)
    loop=G.PolyCurve();loop.Append(a);loop.Append(G.LineCurve(a.PointAtEnd,b.PointAtStart));loop.Append(b);loop.Append(G.LineCurve(b.PointAtEnd,a.PointAtStart))
    g=G.Extrusion.Create(loop,90,True).ToBrep()
    if g.GetBoundingBox(True).Max.Z<0:g.Transform(G.Transform.Translation(0,0,90))
    return oriented(g)

def difference(parts,cutter):
    out=[]
    for g in parts:
        overlap=G.Brep.CreateBooleanIntersection(g,cutter,.01)
        if overlap and sum(G.VolumeMassProperties.Compute(x).Volume for x in overlap)>.005:
            result=G.Brep.CreateBooleanDifference(g,cutter,.01)
            if not result:raise RuntimeError('Subtraction failed')
            out.extend(oriented(x) for x in result)
        else:out.append(g)
    return out

def prepare():
    if any(o.Attributes.GetUserString('recipe')==TAG for o in sc.doc.Objects):raise RuntimeError('Hybrid already exists')
    original=sc.sticky.get('prism_cliff_terrace_inset_v02')
    if not original:raise RuntimeError('Original inset site state required')
    site=original['site'];opening=slot(site);bodies=[];skins=[];baseline=0;retained=0;roof_areas=[]
    for index,(oid,fi,name) in enumerate(SOURCES):
        top=obj(oid).Geometry.Faces[fi].DuplicateFace(False);full=body_from_roof(top);volume=G.VolumeMassProperties.Compute(full).Volume
        baseline+=volume;parts=[full]
        if index==0:
            parts=difference(parts,opening)
            skin=body_from_roof(top,True);clipped=G.Brep.CreateBooleanIntersection(skin,opening,.01)
            if not clipped:raise RuntimeError('Exact roof cover over local zone failed')
            skins.extend(oriented(x) for x in clipped)
        for corridor in original['corridors']:parts=difference(parts,corridor)
        for k,g in enumerate(parts):
            retained+=G.VolumeMassProperties.Compute(g).Volume
            bodies.append({'name':name+'_%02d'%k,'geometry':g,'source':oid})
        roof_areas.append({'source':oid,'area_m2':G.AreaMassProperties.Compute(top).Area})
    for corridor in original['corridors']:skins=difference(skins,corridor)
    # Reuse the verified topology method, fitting its crown to the actual v02
    # roof instead of copying the isolated demonstration's shape or elevation.
    path=os.path.join(ROOT,'tools','rhino_continuous_support_cell_v03.py')
    source=io.open(path,encoding='utf-8').read()
    source=source.replace('depth=7.5+3.5*math.sin(math.pi*f)**2+9.5*root_weight*math.sin(math.pi*f)**2',
        'depth=4.0+2.0*math.sin(math.pi*f)**2+5.5*root_weight*math.sin(math.pi*f)**2')
    ns={'__file__':path,'__name__':'hybrid_cell'};exec(compile('\n'.join(source.splitlines()[1:]),path,'exec'),ns)
    ns['TAG']=TAG+'_support';ns['OUT']=OUT
    face=obj(SOURCES[0][0]).Geometry.Faces[SOURCES[0][1]]
    def fitted_roof(site,q,f):
        s=ns['START']+(ns['END']-ns['START'])*q
        p=face.PointAt(site.rail.Domain.ParameterAt(s),face.Domain(1).ParameterAt(f));p.Z-=.65
        return p
    ns['roof']=fitted_roof;ns['build']();cell=sc.sticky[ns['TAG']]
    originals={str(o.Id):int(o.Geometry.DataCRC(0)) for o in sc.doc.Objects if isinstance(o.Geometry,(G.Brep,G.SubD,G.Extrusion))}
    plants=[r for r in original['state']['objects'] if r['group']=='03_种植区域']
    state={'recipe':TAG,'objects':[],'source_crc':originals,'open_zone_s':[OPEN_START,OPEN_END],
        'baseline_body_volume_sum_m3':baseline,'retained_solid_body_volume_sum_m3':retained,
        'retained_body_fraction':retained/baseline,'roof_areas':roof_areas,
        'design':'Original v02 top surfaces retained. Solid west/east/low tiers and ends; two road corridors; one limited east-side continuous support zone.',
        'support_method':'v03 shared topology adapted to the actual original roof','subd_control_faces':cell['state']['control_faces']}
    sc.sticky[TAG]={'site':site,'original':original,'opening':opening,'bodies':bodies,'skins':skins,'cell':cell,'plants':plants,'state':state}
    write('hybrid_prepare_report.json',state)
    print(json.dumps({'prepared':True,'solid_pieces':len(bodies),'local_roof_covers':len(skins),'retained_body_fraction':retained/baseline,'support_closed':bool(cell['subd'].IsSolid)},ensure_ascii=False))

def layer(child,color,visible=True):
    root=sc.doc.Layers.FindByFullPath(LAYER,-1)
    if root<0:
        l=Rhino.DocObjects.Layer();l.Name=LAYER;root=sc.doc.Layers.Add(l)
    index=sc.doc.Layers.FindByFullPath(LAYER+'::'+child,-1)
    if index<0:
        l=Rhino.DocObjects.Layer();l.Name=child;l.ParentLayerId=sc.doc.Layers[root].Id;l.Color=color;l.IsVisible=visible;index=sc.doc.Layers.Add(l)
    return index

def save_doc(path):
    options=Rhino.FileIO.FileWriteOptions();options.UpdateDocumentPath=False;options.IncludeRenderMeshes=False
    options.SuppressAllInput=True;options.SuppressDialogBoxes=True
    if not sc.doc.Write3dmFile(path,options):raise RuntimeError('Save failed '+path)

def publish():
    data=sc.sticky[TAG];state=data['state'];doc=sc.doc
    for oid,crc in state['source_crc'].items():
        if int(obj(oid).Geometry.DataCRC(0))!=crc:raise RuntimeError('Original changed '+oid)
    backup=os.path.join(os.path.dirname(ROOT),'map','map_before_hybrid_solid_v04.3dm')
    if os.path.exists(backup):raise RuntimeError('Preserve existing backup')
    save_doc(backup);state['backup']=backup
    undo=doc.BeginUndoRecord('实体地形与局部连续支撑 v04')
    try:
        white=Color.FromArgb(238,234,225);mat=Rhino.DocObjects.Material();mat.Name='实体与局部支撑_暖白高光';mat.DiffuseColor=white;mat.Shine=85;mat.Reflectivity=.16;mi=doc.Materials.Add(mat)
        mp=G.MeshingParameters();mp.Tolerance=.025;mp.RelativeTolerance=0;mp.MaximumEdgeLength=8;mp.RefineGrid=True;mp.JaggedSeams=False
        def add(g,name,group,attributes=None,subd=False):
            a=attributes.Duplicate() if attributes else Rhino.DocObjects.ObjectAttributes();a.Name=name;a.LayerIndex=layer(group,white)
            a.SetUserString('recipe',TAG)
            if not attributes:a.MaterialIndex=mi;a.MaterialSource=Rhino.DocObjects.ObjectMaterialSource.MaterialFromObject
            a.CustomMeshingParameters=mp
            oid=doc.Objects.AddSubD(g,a) if subd else doc.Objects.AddBrep(g,a)
            if oid==System.Guid.Empty:raise RuntimeError('Add failed')
            state['objects'].append({'id':str(oid),'name':name,'group':group})
        for r in data['bodies']:add(r['geometry'],r['name'],'01_连续实体底层')
        for i,g in enumerate(data['skins']):add(g,'保留原顶面_局部开敞区覆盖_%02d'%i,'02_原轮廓顶面')
        add(data['cell']['subd'],'东侧局部_连续双支脚与拱腹','03_局部连续支撑',subd=True)
        for i,r in enumerate(data['plants']):
            o=obj(r['id']);add(o.Geometry,'保留原种植顶面_%02d'%i,'04_种植顶面',o.Attributes)
        index=doc.Layers.FindByFullPath('崖岸_连续支柱与拱腹_局部验证_v03',-1)
        if index>=0:
            l=doc.Layers[index];l.IsVisible=False;doc.Layers.Modify(l,index,True)
        doc.Objects.UnselectAll()
    finally:doc.EndUndoRecord(undo);doc.Views.Redraw()
    state['draft_path']=os.path.join(os.path.dirname(ROOT),'map','map_hybrid_solid_v04.3dm');save_doc(state['draft_path']);write('generation_state.json',state)
    print(json.dumps({'published':True,'objects':len(state['objects']),'draft':state['draft_path']},ensure_ascii=False))

def verify():
    data=sc.sticky[TAG];state=data['state'];failures=[];mp=G.MeshingParameters();mp.Tolerance=.04;mp.RelativeTolerance=0;mp.MaximumEdgeLength=10;mp.RefineGrid=True;mesh=G.Mesh();rows=[]
    for oid,crc in state['source_crc'].items():
        if int(obj(oid).Geometry.DataCRC(0))!=crc:failures.append('Original changed '+oid)
    for row in state['objects']:
        g=obj(row['id']).Geometry
        if not g.IsValid:failures.append('Invalid '+row['name'])
        if row['group']=='04_种植顶面':continue
        if not g.IsSolid:failures.append('Open '+row['name'])
        ms=[G.Mesh.CreateFromSubD(g,3)] if isinstance(g,G.SubD) else G.Mesh.CreateFromBrep(g,mp)
        for m in ms or []:mesh.Append(m)
        rows.append({'id':row['id'],'valid':bool(g.IsValid),'solid':bool(g.IsSolid)})
    b=mesh.GetBoundingBox(True)
    if b.Max.Z>60.918:failures.append('Height exceeded')
    passages=[]
    for index,r in enumerate(data['site'].roads):
        face=obj(r['id']).Geometry.Faces[0];c=r['curve'];lo=max(0,r['station']-320);hi=min(c.GetLength(),r['station']+320);hits=0;minimum=1e10;bad=[]
        for i in range(129):
            ok,t=c.LengthParameter(lo+(hi-lo)*i/128);ok,u,v=face.ClosestPoint(c.PointAt(t))
            for f in [.03,.18,.34,.5,.66,.82,.97]:
                p=face.PointAt(face.Domain(0).ParameterAt(f),v)
                dist=G.Intersect.Intersection.MeshRay(mesh,G.Ray3d(p+G.Vector3d(0,0,.05),G.Vector3d.ZAxis))
                if dist>=0:
                    hits+=1;clearance=dist+.05;minimum=min(minimum,clearance)
                    if clearance<9.8:bad.append({'point':xyz(p),'clearance_m':clearance})
        if bad:failures.append('T%d clearance'%(index+1))
        passages.append({'road':'T%d'%(index+1),'samples':903,'overhead_hits':hits,'minimum_vertical_clearance_m':None if minimum==1e10 else minimum,'violations':bad})
    result={'failures':failures,'geometry':rows,'passages':passages,'maximum_height_m':b.Max.Z,'retained_body_fraction':state['retained_body_fraction'],
        'sources_unchanged':not any('Original changed' in s for s in failures),
        'limitations':'Retained fraction is the sum of per-body volumes, not a union-volume measurement. Independent closed bodies and the local SubD overlap at transitions; final seam/union detailing remains. Sampled clearance is not full collision or structural acceptance.'}
    write('verification_report.json',result);print(json.dumps({'failures':failures,'passages':passages,'retained_body_fraction':state['retained_body_fraction']},ensure_ascii=False))

def capture():
    data=sc.sticky[TAG];view=sc.doc.Views.ActiveView
    views=[('01_overall_solid_and_local_void.png',(1250,3020,710),(1060,880,25)),
        ('02_east_local_support.png',(1850,680,36),(1680,870,24)),('03_solid_west_end.png',(330,1510,105),(320,970,22)),
        ('04_T1_tunnel.png',(1110,810,62),(970,540,32))]
    for name,camera,target in views:
        view.ActiveViewport.SetCameraLocations(G.Point3d(*target),G.Point3d(*camera));sc.doc.Views.Redraw()
        c=Rhino.Display.ViewCapture();c.Width=1920;c.Height=1080;c.DrawGrid=False;c.DrawAxes=False;c.DrawGridAxes=False
        b=c.CaptureToBitmap(view);b.Save(os.path.join(OUT,name),ImageFormat.Png);b.Dispose()
    view.ActiveViewport.SetCameraLocations(G.Point3d(1060,880,25),G.Point3d(1250,3020,710));sc.doc.Views.Redraw();save_doc(data['state']['draft_path'])
    print(json.dumps({'captures':[v[0] for v in views]}))

def fix_road_outlet():
    data=sc.sticky[TAG];state=data['state'];r=data['site'].roads[0];p=r['curve'].PointAtEnd;tangent=r['curve'].TangentAt(r['curve'].Domain.T1);tangent.Unitize()
    side=G.Vector3d(-tangent.Y,tangent.X,0);side.Unitize();sections=[]
    for length in [-35,0,45]:
        center=p+tangent*length
        def at(x,z):return center+side*x+G.Vector3d(0,0,z)
        crown=G.Curve.CreateInterpolatedCurve([at(x,z) for x,z in [(17,7),(15,10),(10,12),(0,13),(-10,12),(-15,10),(-17,7)]],3)
        loop=G.PolyCurve();loop.Append(G.LineCurve(at(-17,-.5),at(17,-.5)));loop.Append(G.LineCurve(at(17,-.5),at(17,7)));loop.Append(crown);loop.Append(G.LineCurve(at(-17,7),at(-17,-.5)));sections.append(loop)
    parts=list(G.Brep.CreateFromLoft(sections,G.Point3d.Unset,G.Point3d.Unset,G.LoftType.Normal,False))
    for loop in [sections[0],sections[-1]]:parts.extend(G.Brep.CreatePlanarBreps(loop,.01))
    joined=G.Brep.JoinBreps(parts,.01)
    if not joined or len(joined)!=1:raise RuntimeError('Outlet sweep closure failed')
    extension=oriented(joined[0]);updated=[];plant_updates=[]
    # Precompute all edits before touching the published objects.
    for row in state['objects']:
        o=obj(row['id'])
        if row['group'] in ['01_连续实体底层','02_原轮廓顶面']:
            pieces=difference([o.Geometry.DuplicateBrep()],extension)
            if len(pieces)!=1:raise RuntimeError('Outlet cut unexpectedly disconnected a body')
            updated.append((row,pieces[0]))
        elif row['group']=='04_种植顶面':
            pieces=o.Geometry.Split(extension,.01)
            if not pieces:continue
            classify=sc.sticky['inset_recipe_namespace']['inside_piece']
            kept=[g for g in pieces if not classify(g,extension)]
            if not kept:raise RuntimeError('Unexpected full planting removal')
            plant_updates.append((row,kept))
    undo=sc.doc.BeginUndoRecord('T1出口净空延伸与种植面裁切')
    try:
        for row,g in updated:
            if obj(row['id']).Attributes.GetUserString('recipe')!=TAG:raise RuntimeError('Ownership changed')
            if not sc.doc.Objects.Replace(System.Guid(row['id']),g):raise RuntimeError('Body update failed')
        for row,pieces in plant_updates:
            old=obj(row['id']);a=old.Attributes.Duplicate()
            if not sc.doc.Objects.Replace(old.Id,pieces[0]):raise RuntimeError('Planting update failed')
            for i,g in enumerate(pieces[1:]):
                extra=a.Duplicate();extra.Name=row['name']+'_出口裁切_%d'%i;oid=sc.doc.Objects.AddBrep(g,extra)
                state['objects'].append({'id':str(oid),'name':extra.Name,'group':row['group']})
    finally:sc.doc.EndUndoRecord(undo);sc.doc.Views.Redraw()
    state['T1_outlet_extension_m']=45;state['T1_outlet_width_m']=34
    write('generation_state.json',state);save_doc(state['draft_path']);print(json.dumps({'T1_outlet_extended':True,'planting_surfaces_updated':len(plant_updates)}))
