# -*- coding: utf-8 -*-
"""Landward alternative: cut the plateau, retain water, sculpt the connecting bridge.

Execute prepare, publish, verify, capture in Rhino; UTF-8 load with io.open.
Original objects are retained on a hidden backup layer, never replaced/deleted.
"""
from __future__ import division, unicode_literals
import Rhino, scriptcontext as sc, System, io, os, json, math
from System.Drawing import Color
from System.Drawing.Imaging import ImageFormat
G = Rhino.Geometry
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT,'docs','concepts','cliff_terraces_2026-10-14','rhino_design_B_inset_v02')
TAG = 'prism_cliff_terrace_inset_v02'
LAYER = '崖岸_内退曲面_B方案_v02'
MAIN = 'ad44a7ee-76bf-4eac-aff2-1f138675d8a6'
WALL_A = '85836254-d682-4d80-af5a-1033c51c2cca'
BRIDGE = '5fe43043-0e2d-49a6-a712-d1d18a396dc5'
TARGET = 'e6c5ceda-103d-48b7-af81-db0bcd3f4e41'
with io.open(os.path.join(ROOT,'tools','rhino_terrace_interwoven_v01.py'),encoding='utf-8') as f:
    source=f.read()
base={'__file__':os.path.join(ROOT,'tools','rhino_terrace_interwoven_v01.py'),'__name__':'base_recipe'}
exec(compile('\n'.join(source.splitlines()[1:]),base['__file__'],'exec'),base)
obj=base['obj'];smooth=base['smooth'];gauss=base['gauss'];xyz=base['xyz']
refined=base['refined'];surface=base['surface'];close_surfaces=base['close_surfaces']
save_document=base['save_document']

def write(name,data):
    if not os.path.isdir(OUT):os.makedirs(OUT)
    with io.open(os.path.join(OUT,name),'w',encoding='utf-8') as f:
        f.write(json.dumps(data,ensure_ascii=False,indent=2,default=str))

def width(s):return 220+35*math.sin(math.pi*s)+25*math.sin(2*math.pi*s)

def direction(site,p):
    ok,u,v=site.face.ClosestPoint(p)
    n=site.face.NormalAt(u,v);n.Z=0;n.Unitize()
    return -n

def make_mask(site):
    a=[];b=[]
    for i in range(161):
        s=.025+.95*i/160;p=site.rail.PointAt(site.rail.Domain.ParameterAt(s));n=direction(site,p)
        a.append(G.Point3d(p.X-n.X*4,p.Y-n.Y*4,-20))
        b.append(G.Point3d(p.X+n.X*width(s),p.Y+n.Y*width(s),-20))
    ca=G.Curve.CreateInterpolatedCurve(a,3);cb=G.Curve.CreateInterpolatedCurve(list(reversed(b)),3)
    loop=G.PolyCurve();loop.Append(ca);loop.Append(G.LineCurve(ca.PointAtEnd,cb.PointAtStart));loop.Append(cb);loop.Append(G.LineCurve(cb.PointAtEnd,ca.PointAtStart))
    return extrusion(loop)

def extrusion(loop):
    result=G.Extrusion.Create(loop,110,True).ToBrep()
    if result.GetBoundingBox(True).Max.Z<0:result.Transform(G.Transform.Translation(0,0,110))
    if not result.IsValid or not result.IsSolid:raise RuntimeError('Invalid footprint cutter')
    return result

def inside_piece(part,cutter):
    # Area centroids of a crescent can be outside the actual trimmed face.
    inside=outside=0
    for f in part.Faces:
        for i in range(41):
            for j in range(41):
                u=f.Domain(0).ParameterAt((i+.5)/41);v=f.Domain(1).ParameterAt((j+.5)/41)
                if f.IsPointOnFace(u,v)!=G.PointFaceRelation.Interior:continue
                if cutter.IsPointInside(f.PointAt(u,v),.01,True):inside+=1
                else:outside+=1
    if not inside and not outside:
        # Very small trimmed islands can fall between all domain-grid samples.
        mp=G.MeshingParameters();mp.MaximumEdgeLength=15;mp.Tolerance=.03
        for mesh in G.Mesh.CreateFromBrep(part,mp) or []:
            for face in mesh.Faces:
                ids=[face.A,face.B,face.C]+([face.D] if face.IsQuad else [])
                p=G.Point3d(sum(mesh.Vertices[k].X for k in ids)/len(ids),sum(mesh.Vertices[k].Y for k in ids)/len(ids),sum(mesh.Vertices[k].Z for k in ids)/len(ids))
                if cutter.IsPointInside(p,.02,False):inside+=1
                else:outside+=1
    if inside and outside:raise RuntimeError('Cutter left a mixed inside/outside piece: %d/%d'%(inside,outside))
    if not inside and not outside:raise RuntimeError('Could not classify trimmed face')
    return inside>0

def roof_height(p,fallback):
    main=obj(MAIN).Geometry
    line=G.LineCurve(G.Point3d(p.X,p.Y,-10),G.Point3d(p.X,p.Y,80))
    ok,over,hits=G.Intersect.Intersection.CurveBrep(line,main,.01)
    return min(60.7,max(x.Z for x in hits)) if hits else fallback

def band(site,kind):
    rail=refined(site.rail.Trim(site.rail.Domain.ParameterAt(.025),site.rail.Domain.ParameterAt(.975)),2)
    rows=[];bottom=[]
    for i in range(rail.Points.Count):
        p=rail.Points[i].Location;s=(rail.GrevilleParameter(i)-site.rail.Domain.T0)/site.rail.Domain.Length
        n=direction(site,p);h=max(.9,p.Z)
        taper=smooth((s-.025)/.065)*smooth((.975-s)/.065)
        if kind=='main':
            front=(68+31*math.sin(4*math.pi*s+.4)+28*gauss(s,.61,.12))*taper
            back=width(s)
            high=roof_height(p+n*back,h)
            crest=h*(.52+.10*math.sin(5*math.pi*s))
        else:
            front=(8+18*math.sin(3*math.pi*s)**2)*taper
            back=front+(48+25*math.sin(4*math.pi*s+.9)**2)*taper+8
            high=h*(.61+.11*math.sin(4*math.pi*s+.7))
            crest=h*(.28+.11*math.sin(5*math.pi*s+1))
        feet=max(gauss(s,.17,.042),gauss(s,.315,.032),gauss(s,.72,.035),gauss(s,.9,.045))
        top_row=[];bottom_row=[]
        for j in range(8):
            f=j/7;d=front+(back-front)*f;position=p+n*d
            # Cross-slope and longitudinal oscillation, not flat terrace slabs.
            z=crest+(high-crest)*smooth(f)+h*.065*math.sin(math.pi*f)*math.sin(6*math.pi*s+.7)
            z=max(.6,min(60.7,z))
            bulk=min(1,feet*1.7)*smooth((1-f)/.60)
            under=max(0,(z-3.8)*(1-bulk))
            reserve=site.road_floor(position)
            if isinstance(reserve,tuple):
                needed,weight=reserve;under=under*(1-weight)+max(under,needed)*weight;z=max(z,under+3.8)
            z=min(60.7,z);under=min(under,z-.35)
            top_row.append(G.Point3d(position.X,position.Y,z));bottom_row.append(G.Point3d(position.X,position.Y,under))
        rows.append(top_row);bottom.append(bottom_row)
    top=surface(rail,rows);underside=surface(rail,bottom)
    return top,close_surfaces(top,underside)

def bridge(site):
    face=obj(BRIDGE).Geometry.Faces[0];original=face.IsoCurve(1,face.Domain(0).Mid)
    rail=refined(original,1);rows=[];bottom=[]
    for i in range(rail.Points.Count):
        p=rail.Points[i].Location;t=rail.GrevilleParameter(i);s=(t-rail.Domain.T0)/rail.Domain.Length
        tangent=rail.TangentAt(t);n=G.Vector3d(-tangent.Y,tangent.X,0);n.Unitize()
        half=12+21*math.sin(math.pi*s)**.8+6*math.sin(3*math.pi*s)**2
        foot=max(gauss(s,.02,.045),gauss(s,.98,.045),gauss(s,.24,.027),gauss(s,.80,.027))
        a=[];b=[]
        for j in range(8):
            f=j/7;cross=2*f-1;q=p+n*(cross*half)
            z=p.Z-.45-2.8*abs(cross)**2*(.55+.45*math.sin(3*math.pi*s)**2)
            bulk=min(1,foot*1.7)*smooth(abs(cross)/.70)
            under=max(0,(z-4.0)*(1-bulk))
            reserve=site.road_floor(q)
            if isinstance(reserve,tuple):
                needed,weight=reserve;under=under*(1-weight)+max(under,needed)*weight
            under=min(z-.4,under)
            a.append(G.Point3d(q.X,q.Y,z));b.append(G.Point3d(q.X,q.Y,under))
        rows.append(a);bottom.append(b)
    top=surface(rail,rows);volume=close_surfaces(top,surface(rail,bottom))
    return {'top':top,'volume':volume,'road':obj(BRIDGE).Geometry.DuplicateBrep(),'road_curve':original}

def prepare():
    if any(o.Attributes.GetUserString('recipe')==TAG for o in sc.doc.Objects):raise RuntimeError('Inset design already published')
    site=base['Site']();mask=make_mask(site)
    loop=obj(MAIN).Geometry.Faces[0].Loops[0].To3dCurve()
    loop.Transform(G.Transform.PlanarProjection(G.Plane.WorldXY));loop.Transform(G.Transform.Translation(0,0,-20))
    footprint=extrusion(loop)
    preserved=[];removed=[]
    for oid in [MAIN,WALL_A]:
        pieces=obj(oid).Geometry.Split(mask,.01)
        if not pieces:raise RuntimeError('Plateau split failed')
        for g in pieces:
            if not g.IsValid:raise RuntimeError('Invalid terrain split')
            entry={'source':oid,'geometry':g,'area':G.AreaMassProperties.Compute(g).Area}
            (removed if inside_piece(g,mask) else preserved).append(entry)
    corridors=[base['tunnel'](site,r) for r in site.roads]
    shells=[];plants=[]
    for kind,name in [('main','陆侧主壳_顶面内切连续起伏'),('lower','湾缘低翼_内退曲面')]:
        top,volume=band(site,kind)
        parts=G.Brep.CreateBooleanIntersection(volume,footprint,.01)
        if not parts:raise RuntimeError('Could not clip shell to original land footprint')
        for k,part in enumerate(parts):
            if not part.IsValid or not part.IsSolid:raise RuntimeError('Clipped shell not solid')
            current=[part]
            for c in corridors:
                revised=[]
                for g in current:
                    intersection=G.Brep.CreateBooleanIntersection(g,c,.01)
                    if intersection and sum(G.VolumeMassProperties.Compute(x).Volume for x in intersection)>.005:
                        diff=G.Brep.CreateBooleanDifference(g,c,.01)
                        if not diff:raise RuntimeError('Passage Boolean failed')
                        revised.extend(diff)
                    else:revised.append(g)
                current=revised
            for j,g in enumerate(current):
                if not g.IsValid or not g.IsSolid:raise RuntimeError('Invalid passage shell')
                shells.append({'name':name+'_%d_%d'%(k,j),'geometry':g,'kind':kind})
        green=top.Trim(top.Domain(0),G.Interval(top.Domain(1).T0+.60,top.Domain(1).T1-.65))
        green.Transform(G.Transform.Translation(0,0,.30))
        pieces=green.ToBrep().Split(footprint,.01)
        for g in pieces or [green.ToBrep()]:
            if inside_piece(g,footprint):
                f=g.Faces[0]
                if f.NormalAt(f.Domain(0).Mid,f.Domain(1).Mid).Z<0:g.Flip()
                plants.append({'name':name+'_种植曲面','geometry':g})
    connection=bridge(site)
    sources=[MAIN,WALL_A,BRIDGE,TARGET]+base['ROAD_IDS']+base['LOW_IDS']
    state={'recipe':TAG,'objects':[],'source_geometry_crc':{oid:int(obj(oid).Geometry.DataCRC(0)) for oid in sources},
        'source_attributes':{oid:{'layer':obj(oid).Attributes.LayerIndex,'name':obj(oid).Attributes.Name} for oid in sources},
        'removed_top_area_m2':sum(r['area'] for r in removed if r['source']==MAIN),
        'design':'Landward inset; new main/low shells clipped to original top XY footprint; original road alignment becomes a sculptural bridge',
        'original_outward_root':base['LAYER'],'height_ceiling_m':60.918,'preserved_pieces':len(preserved)}
    sc.sticky[TAG]={'site':site,'mask':mask,'footprint':footprint,'preserved':preserved,'removed':removed,
        'shells':shells,'plants':plants,'bridge':connection,'corridors':corridors,'state':state}
    write('prepare_report.json',dict(state,shells=[{'name':s['name'],'solid':s['geometry'].IsSolid,'faces':s['geometry'].Faces.Count,'bounds':[xyz(s['geometry'].GetBoundingBox(True).Min),xyz(s['geometry'].GetBoundingBox(True).Max)]} for s in shells]))
    print(json.dumps({'prepared':True,'shells':len(shells),'planting_patches':len(plants),'preserved':len(preserved),'removed_top_area_m2':state['removed_top_area_m2']},ensure_ascii=False))

def layer(child,color,visible=True):
    root=sc.doc.Layers.FindByFullPath(LAYER,-1)
    if root<0:
        l=Rhino.DocObjects.Layer();l.Name=LAYER;root=sc.doc.Layers.Add(l)
    path=LAYER+'::'+child;index=sc.doc.Layers.FindByFullPath(path,-1)
    if index<0:
        l=Rhino.DocObjects.Layer();l.Name=child;l.ParentLayerId=sc.doc.Layers[root].Id;l.Color=color;l.IsVisible=visible;index=sc.doc.Layers.Add(l)
    return index

def publish():
    data=sc.sticky[TAG];state=data['state'];doc=sc.doc
    for oid,crc in state['source_geometry_crc'].items():
        if int(obj(oid).Geometry.DataCRC(0))!=crc:raise RuntimeError('Source changed: '+oid)
    backup=os.path.join(os.path.dirname(ROOT),'map','map_before_terrace_inset_B_v02.3dm')
    if os.path.exists(backup):raise RuntimeError('Backup exists; preserve it')
    save_document(backup);state['backup']=backup
    record=doc.BeginUndoRecord('崖岸 内退曲面与艺术桥 B方案 v02')
    try:
        white=Color.FromArgb(238,233,223);green=Color.FromArgb(137,164,91)
        mat=Rhino.DocObjects.Material();mat.Name='内退B_暖白高光建筑涂层';mat.DiffuseColor=white;mat.Shine=90;mat.Reflectivity=.20;mi=doc.Materials.Add(mat)
        plant=Rhino.DocObjects.Material();plant.Name='内退B_草甸';plant.DiffuseColor=green;plant.Shine=8;gi=doc.Materials.Add(plant)
        def add(g,name,group,color,material=None,attributes=None,visible=True):
            a=attributes.Duplicate() if attributes else Rhino.DocObjects.ObjectAttributes();a.Name=name;a.LayerIndex=layer(group,color,visible)
            a.SetUserString('recipe',TAG);a.SetUserString('description','Landward cut-back architectural landform; draft native NURBS')
            if attributes and material is None and attributes.MaterialSource==Rhino.DocObjects.ObjectMaterialSource.MaterialFromLayer:
                original_layer=doc.Layers[attributes.LayerIndex]
                a.MaterialIndex=original_layer.RenderMaterialIndex;a.MaterialSource=Rhino.DocObjects.ObjectMaterialSource.MaterialFromObject
            if material is not None:a.MaterialIndex=material;a.MaterialSource=Rhino.DocObjects.ObjectMaterialSource.MaterialFromObject
            oid=doc.Objects.AddBrep(g,a)
            if oid==System.Guid.Empty:raise RuntimeError('Add failed '+name)
            state['objects'].append({'id':str(oid),'name':name,'group':group})
        for i,r in enumerate(data['preserved']):
            o=obj(r['source']);add(r['geometry'],'保留原地形_%02d'%i,'01_裁切后的原地形',o.Attributes.ObjectColor,attributes=o.Attributes)
        for s in data['shells']:add(s['geometry'],s['name'],'02_内退建筑曲面',white,mi)
        for i,s in enumerate(data['plants']):add(s['geometry'],s['name']+'_%02d'%i,'03_种植区域',green,gi)
        add(data['bridge']['volume'],'流线艺术桥_变宽扭转与落地支承','04_中央艺术桥',white,mi)
        add(data['bridge']['road'],'艺术桥_保留实际路面与两端接点','05_桥上道路',Color.Gray,attributes=obj(BRIDGE).Attributes)
        for i,g in enumerate(data['corridors']):add(g,'T%d_道路隧道净空'%(i+1),'07_隧道净空_辅助',Color.DeepSkyBlue,visible=False)
        # Keep original entities/geometry so the variant can be switched back.
        for oid in [MAIN,WALL_A,BRIDGE]:
            o=obj(oid);a=o.Attributes.Duplicate();a.LayerIndex=layer('08_原始顶面与桥_备份',Color.Gray,False)
            a.SetUserString('inset_source_layer',str(state['source_attributes'][oid]['layer']));doc.Objects.ModifyAttributes(o,a,True)
        oldroot=doc.Layers.FindByFullPath(base['LAYER'],-1)
        l=doc.Layers[oldroot];l.IsVisible=False;l.SetUserString('alternative','Outward option retained, compare using saved full scene');doc.Layers.Modify(l,oldroot,True)
    finally:doc.EndUndoRecord(record);doc.Views.Redraw()
    state['draft_path']=os.path.join(os.path.dirname(ROOT),'map','map_terrace_inset_B_v02.3dm')
    save_document(state['draft_path']);write('generation_state.json',state)
    print(json.dumps({'published':True,'objects':len(state['objects']),'draft':state['draft_path'],'backup':backup},ensure_ascii=False))

def finish_display():
    data=sc.sticky[TAG];state=data['state'];record=sc.doc.BeginUndoRecord('内退B 顶面法向与保留地形材质')
    try:
        for row in state['objects']:
            o=obj(row['id'])
            if row['group']=='03_种植区域':
                g=o.Geometry.DuplicateBrep();f=g.Faces[0]
                if f.NormalAt(f.Domain(0).Mid,f.Domain(1).Mid).Z<0:
                    g.Flip();sc.doc.Objects.Replace(o.Id,g)
            elif row['group'] in ['01_裁切后的原地形','05_桥上道路']:
                source=MAIN if row['group']=='01_裁切后的原地形' else BRIDGE
                old_layer=sc.doc.Layers[state['source_attributes'][source]['layer']]
                a=o.Attributes.Duplicate();a.MaterialIndex=old_layer.RenderMaterialIndex
                a.MaterialSource=Rhino.DocObjects.ObjectMaterialSource.MaterialFromObject
                sc.doc.Objects.ModifyAttributes(o,a,True)
    finally:sc.doc.EndUndoRecord(record);sc.doc.Views.Redraw()
    save_document(state['draft_path'])
    print(json.dumps({'display_finished':True}))

def refine_overlap():
    data=sc.sticky[TAG];state=data['state'];doc=sc.doc
    hill='a4adc150-3ba0-4216-b8b5-8d21449e8f69'
    if state.get('overlap_refined'):raise RuntimeError('Overlap already refined')
    source=obj(hill);parts=source.Geometry.Split(data['mask'],.01)
    if not parts:raise RuntimeError('Overlapping hill split failed')
    kept=[g for g in parts if not inside_piece(g,data['mask'])]
    if not kept:raise RuntimeError('Unexpected complete hill removal')
    mp=G.MeshingParameters();mp.Tolerance=.02;mp.RelativeTolerance=0;mp.MaximumEdgeLength=5;mp.MinimumEdgeLength=.15;mp.RefineGrid=True;mp.JaggedSeams=False
    record=doc.BeginUndoRecord('内退B 清除旧丘陵重叠并细化显示网格')
    try:
        old_layer=doc.Layers[state['source_attributes'][hill]['layer']]
        for i,g in enumerate(kept):
            a=source.Attributes.Duplicate();a.Name='保留海平面丘陵_裁切后_%02d'%i
            a.LayerIndex=layer('01_裁切后的原地形',Color.Gray);a.SetUserString('recipe',TAG)
            a.MaterialIndex=old_layer.RenderMaterialIndex;a.MaterialSource=Rhino.DocObjects.ObjectMaterialSource.MaterialFromObject
            oid=doc.Objects.AddBrep(g,a);state['objects'].append({'id':str(oid),'name':a.Name,'group':'01_裁切后的原地形'})
        a=source.Attributes.Duplicate();a.LayerIndex=layer('08_原始顶面与桥_备份',Color.Gray,False)
        a.SetUserString('inset_source_layer',str(state['source_attributes'][hill]['layer']));doc.Objects.ModifyAttributes(source,a,True)
        for row in state['objects']:
            if row['group'] not in ['02_内退建筑曲面','03_种植区域','04_中央艺术桥']:continue
            o=obj(row['id']);a=o.Attributes.Duplicate();a.CustomMeshingParameters=mp;doc.Objects.ModifyAttributes(o,a,True)
            obj(row['id']).CreateMeshes(G.MeshType.Render,mp,False)
    finally:doc.EndUndoRecord(record);doc.Views.Redraw()
    state['overlap_refined']=True;write('generation_state.json',state);save_document(state['draft_path'])
    print(json.dumps({'hill_preserved_pieces':len(kept),'custom_render_mesh_tolerance_m':.02}))

def verify():
    data=sc.sticky[TAG];state=data['state'];failures=[];details=[];mesh=G.Mesh()
    mp=G.MeshingParameters();mp.Tolerance=.06;mp.RelativeTolerance=0;mp.MaximumEdgeLength=10;mp.MinimumEdgeLength=.20;mp.RefineGrid=True
    for oid,crc in state['source_geometry_crc'].items():
        if int(obj(oid).Geometry.DataCRC(0))!=crc:failures.append('Source changed '+oid)
    for row in state['objects']:
        g=obj(row['id']).Geometry;b=g.GetBoundingBox(True)
        if not g.IsValid:failures.append('Invalid '+row['name'])
        if row['group'] in ['02_内退建筑曲面','04_中央艺术桥']:
            if not g.IsSolid:failures.append('Open volume '+row['name'])
            if b.Max.Z>60.918:failures.append('Height exceeded '+row['name'])
            for m in G.Mesh.CreateFromBrep(g,mp) or []:mesh.Append(m)
        details.append({'id':row['id'],'name':row['name'],'valid':bool(g.IsValid),'solid':bool(g.IsSolid),'bounds':[xyz(b.Min),xyz(b.Max)]})
    passages=[]
    for index,r in enumerate(data['site'].roads):
        f=obj(r['id']).Geometry.Faces[0];c=r['curve'];lo=max(0,r['station']-320);hi=min(c.GetLength(),r['station']+320)
        hits=0;minimum=1e10;violations=[]
        for i in range(129):
            ok,t=c.LengthParameter(lo+(hi-lo)*i/128);ok,u,v=f.ClosestPoint(c.PointAt(t))
            for cross in [.03,.18,.34,.5,.66,.82,.97]:
                p=f.PointAt(f.Domain(0).ParameterAt(cross),v)
                distance=G.Intersect.Intersection.MeshRay(mesh,G.Ray3d(p+G.Vector3d(0,0,.05),G.Vector3d.ZAxis))
                if distance>=0:
                    hits+=1;clearance=distance+.05;minimum=min(minimum,clearance)
                    if clearance<9.8:violations.append({'point':xyz(p),'clearance_m':clearance})
        if violations:failures.append('T%d clearance too low'%(index+1))
        passages.append({'road':'T%d'%(index+1),'samples':903,'overhead_hits':hits,'minimum_vertical_clearance_m':None if minimum==1e10 else minimum,'violations':violations})
    result={'failures':failures,'objects':details,'passages':passages,'removed_original_top_area_m2':state['removed_top_area_m2'],
        'sources_unchanged':not any('Source changed' in s for s in failures),
        'limitations':'Design draft. Mesh ray samples are partial clearance checks, not a full collision or structural acceptance. Native trimmed terrain connections require seam detailing. No game export performed.'}
    write('verification_report.json',result);print(json.dumps({'failures':failures,'passages':passages},ensure_ascii=False));return result

def capture():
    data=sc.sticky[TAG];view=sc.doc.Views.ActiveView
    views=[('01_overview.png',(1250,3020,710),(1060,880,25)),('02_inset_and_bridge.png',(1000,1610,370),(1050,580,35)),
        ('03_T1_passage.png',(1140,950,70),(920,490,33)),('04_bridge_structure.png',(1370,1040,145),(1110,620,42))]
    for name,camera,target in views:
        view.ActiveViewport.SetCameraLocations(G.Point3d(*target),G.Point3d(*camera));sc.doc.Views.Redraw()
        capture=Rhino.Display.ViewCapture();capture.Width=1920;capture.Height=1080;capture.ScaleScreenItems=False
        capture.DrawGrid=False;capture.DrawAxes=False;capture.DrawGridAxes=False
        bitmap=capture.CaptureToBitmap(view);bitmap.Save(os.path.join(OUT,name),ImageFormat.Png);bitmap.Dispose()
    view.ActiveViewport.SetCameraLocations(G.Point3d(1060,880,25),G.Point3d(1250,3020,710));sc.doc.Views.Redraw()
    save_document(data['state']['draft_path']);print(json.dumps({'captured':[v[0] for v in views],'draft':data['state']['draft_path']}))

def switch_variant(inset=True):
    """Switch complete alternatives, including their shared original context."""
    data=sc.sticky[TAG];state=data['state'];doc=sc.doc
    sources=[MAIN,WALL_A,BRIDGE,'a4adc150-3ba0-4216-b8b5-8d21449e8f69']
    for oid in sources:
        if int(obj(oid).Geometry.DataCRC(0))!=state['source_geometry_crc'][oid]:raise RuntimeError('Source changed '+oid)
    record=doc.BeginUndoRecord('切换内退与外展方案')
    try:
        for oid in sources:
            o=obj(oid);a=o.Attributes.Duplicate()
            a.LayerIndex=layer('08_原始顶面与桥_备份',Color.Gray,False) if inset else state['source_attributes'][oid]['layer']
            doc.Objects.ModifyAttributes(o,a,True)
        for name,visible in [(LAYER,inset),(base['LAYER'],not inset)]:
            index=doc.Layers.FindByFullPath(name,-1);l=doc.Layers[index];l.IsVisible=visible;doc.Layers.Modify(l,index,True)
    finally:doc.EndUndoRecord(record);doc.Views.Redraw()
    print(json.dumps({'active_variant':'inset' if inset else 'outward'}))
