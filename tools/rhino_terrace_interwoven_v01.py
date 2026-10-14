# -*- coding: utf-8 -*-
"""Native editable NURBS design B, respecting the authored cliff/road heights."""
from __future__ import division, unicode_literals
import Rhino, scriptcontext as sc, System, io, os, json, math
from System.Drawing import Color
from System.Drawing.Imaging import ImageFormat
G = Rhino.Geometry
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT,'docs','concepts','cliff_terraces_2026-10-14','rhino_design_B_v01')
TAG = 'prism_cliff_terrace_interwoven_v01'
LAYER = '崖岸_交错曲面_B方案_v01'
TARGET = 'e6c5ceda-103d-48b7-af81-db0bcd3f4e41'
ROAD_IDS = ['e3c7a11d-7bdd-47a6-b8ae-b426b6903567','4e756d0f-b36d-46a4-ada9-12ebe57462a2']
LOW_IDS = ['493f74fe-8166-43ba-9dd3-b60a30144c9a','4c560a71-7757-47c1-8e6c-23bdf73081d6','a4adc150-3ba0-4216-b8b5-8d21449e8f69']

def write(name,data):
    if not os.path.isdir(OUT): os.makedirs(OUT)
    with io.open(os.path.join(OUT,name),'w',encoding='utf-8') as f:
        f.write(json.dumps(data,ensure_ascii=False,indent=2,default=str))

def xyz(p): return [float(p.X),float(p.Y),float(p.Z)]
def obj(oid):
    o=sc.doc.Objects.FindId(System.Guid(oid))
    if o is None: raise RuntimeError('Missing source '+oid)
    return o
def smooth(x):
    x=max(0,min(1,x));return x*x*(3-2*x)
def gauss(s,c,w):return math.exp(-((s-c)/w)**2)

def refined(curve, passes=2):
    c=curve.ToNurbsCurve()
    for _ in range(passes):
        unique=sorted(set(float(t) for t in c.Knots))
        for a,b in zip(unique,unique[1:]):
            if b-a>1e-6:c.Knots.InsertKnot((a+b)*.5)
    return c

def surface(rail,rows):
    nu=len(rows);nv=len(rows[0])
    ns=G.NurbsSurface.Create(3,False,4,4,nu,nv)
    for i,t in enumerate(rail.Knots):ns.KnotsU[i]=t
    values=[0,0,0]+list(range(1,nv-3))+[nv-3,nv-3,nv-3]
    for j,t in enumerate(values):ns.KnotsV[j]=t
    for i in range(nu):
        for j in range(nv):ns.Points.SetPoint(i,j,rows[i][j])
    if not ns.IsValid:raise RuntimeError('Invalid NURBS grid')
    return ns

def close_surfaces(top,bottom):
    parts=[top.ToBrep(),bottom.ToBrep()]
    for v in [top.Domain(1).T0,top.Domain(1).T1]:
        a=top.IsoCurve(0,v);b=bottom.IsoCurve(0,v)
        side=G.Brep.CreateFromLoft([a,b],G.Point3d.Unset,G.Point3d.Unset,G.LoftType.Straight,False)
        parts.extend(side or [])
    for u in [top.Domain(0).T0,top.Domain(0).T1]:
        a=top.IsoCurve(1,u);b=bottom.IsoCurve(1,u)
        loop=G.PolyCurve()
        loop.Append(a)
        loop.Append(G.LineCurve(a.PointAtEnd,b.PointAtEnd))
        b.Reverse();loop.Append(b)
        loop.Append(G.LineCurve(b.PointAtEnd,a.PointAtStart))
        caps=G.Brep.CreatePlanarBreps(loop,.005)
        if not caps:raise RuntimeError('Cannot cap a shell end')
        parts.extend(caps)
    joined=G.Brep.JoinBreps(parts,.005)
    if not joined or len(joined)!=1:raise RuntimeError('Shell patches do not join')
    brep=joined[0]
    if not brep.IsValid or not brep.IsSolid:raise RuntimeError('Shell is not a valid solid')
    if brep.SolidOrientation==G.BrepSolidOrientation.Inward:brep.Flip()
    return brep

class Site:
    def __init__(self):
        self.wall=obj(TARGET).Geometry
        self.face=self.wall.Faces[0]
        self.rail=self.face.IsoCurve(1,self.face.Domain(0).T0).ToNurbsCurve()
        self.roads=[]
        for oid in ROAD_IDS:
            r=obj(oid).Geometry
            c=r.Faces[0].IsoCurve(1,r.Faces[0].Domain(0).Mid)
            xy=c.DuplicateCurve();xy.Transform(G.Transform.PlanarProjection(G.Plane.WorldXY))
            ok,over,hits=G.Intersect.Intersection.CurveBrep(c,self.wall,.001)
            if not hits or len(hits)!=1:raise RuntimeError('Road/wall relationship changed')
            p=hits[0];ok,t=c.ClosestPoint(p)
            station=c.GetLength(G.Interval(c.Domain.T0,t))
            self.roads.append({'id':oid,'curve':c,'xy':xy,'hit':p,'station':station})
        self.low=[obj(x).Geometry for x in LOW_IDS]
        self.ground_cache={}

    def ground(self,p):
        key=(round(p.X/3),round(p.Y/3))
        if key not in self.ground_cache:
            line=G.LineCurve(G.Point3d(p.X,p.Y,-5),G.Point3d(p.X,p.Y,40))
            zs=[]
            for low in self.low:
                ok,over,hits=G.Intersect.Intersection.CurveBrep(line,low,.01)
                zs.extend(float(q.Z) for q in(hits or []))
            self.ground_cache[key]=max(zs) if zs else 0.0
        return self.ground_cache[key]

    def road_floor(self,p):
        requirement=-1
        for r in self.roads:
            ok,t=r['xy'].ClosestPoint(G.Point3d(p.X,p.Y,0))
            q=r['xy'].PointAt(t)
            distance=math.hypot(q.X-p.X,q.Y-p.Y)
            if distance<55:
                # Wide smooth influence prevents a kink in the sculpted underside.
                influence=1-smooth((distance-30)/25)
                z=r['curve'].PointAt(t).Z+13
                requirement=max(requirement,(z,influence),key=lambda x:x[0] if isinstance(x,tuple) else x)
        return requirement

def shell(site,spec):
    original=site.rail
    a=original.Domain.ParameterAt(spec['start']);b=original.Domain.ParameterAt(spec['end'])
    rail=refined(original.Trim(a,b),2)
    top_rows=[];bottom_rows=[]
    for i in range(rail.Points.Count):
        p=rail.Points[i].Location
        s=(rail.GrevilleParameter(i)-original.Domain.T0)/original.Domain.Length
        q=(s-spec['start'])/(spec['end']-spec['start'])
        ok,u,v=site.face.ClosestPoint(p)
        n=site.face.NormalAt(u,v);n.Z=0;n.Unitize()
        h=max(0,float(p.Z))
        end=smooth(q/.07)*smooth((1-q)/.07)
        if spec['kind']=='main':
            inner=0
            width=(120+28*math.sin(s*math.pi*3-.6)+35*gauss(s,.53,.16))*smooth(h/18)
            crest=h
            drop=min(h*.40,14+8*math.sin(s*math.pi*4+.5))
            feet=max(gauss(s,.225,.038),gauss(s,.395,.025),gauss(s,.645,.030),gauss(s,.860,.035))
        else:
            # The wings diverge from, cross below and return towards the main shell.
            inner=spec['offset']*math.sin(math.pi*q)**.85 + spec['sway']*math.sin(2*math.pi*q)
            width=(18+spec['width']*math.sin(math.pi*q)**.70)*smooth(h/14)
            crest=min(h-1.5,h*spec['height_ratio']+spec['wave']*math.sin(2*math.pi*q+spec['phase'])+3)
            crest=max(2,min(h,crest))
            drop=min(crest*.26,5+3*math.sin(q*math.pi*2+spec['phase']))
            feet=max(gauss(q,.08,.08),gauss(q,spec['foot'],.06),gauss(q,.95,.08))
        top=[];bottom=[]
        for j in range(8):
            f=j/7
            d=inner+width*f
            position=G.Point3d(p.X+n.X*d,p.Y+n.Y*d,0)
            z=crest-drop*f**1.25
            z=max(.8,min(h,z))
            ground=min(z-.35,site.ground(position)) if feet>.12 else 0
            # A finite contact patch, with the exposed edge descending into the
            # haunch. A lone Gaussian minimum would leave the NURBS floating.
            bulk=min(1,feet*1.65)*smooth(f/.50)
            underside=(z-3.2)*(1-bulk)+max(0,ground-.50)*bulk
            underside=max(0,min(z-.35,underside))
            reserve=site.road_floor(position)
            if isinstance(reserve,tuple):
                needed,weight=reserve
                underside=underside*(1-weight)+max(underside,needed)*weight
                z=max(z,underside+3.2)
            if z>h:
                z=h;underside=min(underside,z-.35)
            top.append(G.Point3d(position.X,position.Y,z))
            bottom.append(G.Point3d(position.X,position.Y,underside))
        top_rows.append(top);bottom_rows.append(bottom)
    top=surface(rail,top_rows);bottom=surface(rail,bottom_rows)
    volume=close_surfaces(top,bottom)
    # Planting zone uses the same surface, inside a broad unplanted white margin.
    green=top.Trim(top.Domain(0),G.Interval(top.Domain(1).T0+.58,top.Domain(1).T1-.65))
    green.Transform(G.Transform.Translation(0,0,.30))
    return {'name':spec['name'],'group':spec['group'],'volume':volume,'top':top,'green':green.ToBrep(),'spec':spec}

def tunnel(site,r):
    sections=[]
    length=r['curve'].GetLength()
    lo=max(0,r['station']-320);hi=min(length,r['station']+320)
    for i in range(45):
        station=lo+(hi-lo)*i/44
        ok,t=r['curve'].LengthParameter(station)
        p=r['curve'].PointAt(t);tangent=r['curve'].TangentAt(t)
        side=G.Vector3d(-tangent.Y,tangent.X,0);side.Unitize()
        def at(x,z):return p+side*x+G.Vector3d(0,0,z)
        crown=G.Curve.CreateInterpolatedCurve([at(x,z) for x,z in [(14,5.5),(13,8),(9,10.2),(0,11),(-9,10.2),(-13,8),(-14,5.5)]],3)
        c=G.PolyCurve()
        c.Append(G.LineCurve(at(-14,-.15),at(14,-.15)))
        c.Append(G.LineCurve(at(14,-.15),at(14,5.5)))
        c.Append(crown)
        c.Append(G.LineCurve(at(-14,5.5),at(-14,-.15)))
        sections.append(c)
    parts=list(G.Brep.CreateFromLoft(sections,G.Point3d.Unset,G.Point3d.Unset,G.LoftType.Normal,False) or [])
    for c in [sections[0],sections[-1]]:parts.extend(G.Brep.CreatePlanarBreps(c,.01) or [])
    joined=G.Brep.JoinBreps(parts,.01)
    if not joined or len(joined)!=1 or not joined[0].IsSolid:raise RuntimeError('Road clearance sweep failed')
    g=joined[0]
    if g.SolidOrientation==G.BrepSolidOrientation.Inward:g.Flip()
    return g

def save_document(path):
    options=Rhino.FileIO.FileWriteOptions()
    options.UpdateDocumentPath=False;options.IncludeRenderMeshes=False
    options.SuppressAllInput=True;options.SuppressDialogBoxes=True
    if not sc.doc.Write3dmFile(path,options):raise RuntimeError('Cannot save '+path)

def prepare():
    if not (obj(TARGET).Attributes.Name or '').startswith('1014'):
        raise RuntimeError('Marked source identity changed')
    if any(o.Attributes.GetUserString('recipe')==TAG for o in sc.doc.Objects):
        raise RuntimeError('Design already exists; update or revert it deliberately.')
    site=Site()
    specs=[
        {'kind':'main','name':'主壳_连续抬升扭转_保留60米上缘','group':'01_连续抬升主壳','start':.018,'end':.982},
        {'kind':'wing','name':'西翼_长向起伏跨越绿谷','group':'02_西侧交错翼','start':.105,'end':.690,'offset':145,'sway':36,'width':66,'height_ratio':.60,'wave':8,'phase':.30,'foot':.38},
        {'kind':'wing','name':'东翼_回折下降开敞曲面','group':'03_东侧扭转翼','start':.480,'end':.955,'offset':190,'sway':-43,'width':78,'height_ratio':.65,'wave':8,'phase':1.25,'foot':.68},
    ]
    shells=[shell(site,s) for s in specs]
    corridors=[tunnel(site,r) for r in site.roads]
    metrics=[]
    for s in shells:
        volume=s['volume'];cuts=0
        for corridor in corridors:
            a=volume.GetBoundingBox(True);b=corridor.GetBoundingBox(True)
            if a.Max.X<b.Min.X or b.Max.X<a.Min.X or a.Max.Y<b.Min.Y or b.Max.Y<a.Min.Y or a.Max.Z<b.Min.Z or b.Max.Z<a.Min.Z:continue
            overlap=G.Brep.CreateBooleanIntersection(volume,corridor,.01)
            if overlap:
                overlap_volume=sum(G.VolumeMassProperties.Compute(x).Volume for x in overlap)
                if overlap_volume>.005:
                    pieces=G.Brep.CreateBooleanDifference(volume,corridor,.01)
                    if not pieces or any(not x.IsValid or not x.IsSolid for x in pieces):raise RuntimeError('Tunnel subtraction failed')
                    if len(pieces)!=1:raise RuntimeError('Tunnel cuts disconnected the shell; revise supports')
                    volume=pieces[0];cuts+=1
        s['volume']=volume
        bounds=volume.GetBoundingBox(True)
        if bounds.Max.Z>60.001 or bounds.Min.Z<-.001:raise RuntimeError('Height envelope violated')
        metrics.append({'name':s['name'],'valid':bool(volume.IsValid),'solid':bool(volume.IsSolid),'faces':int(volume.Faces.Count),
            'bounds':[xyz(bounds.Min),xyz(bounds.Max)],'tunnel_boolean_cuts':cuts,'planting_area_m2':float(G.AreaMassProperties.Compute(s['green']).Area)})
    state={'document_serial':int(sc.doc.RuntimeSerialNumber),'source_id':TARGET,'source_name':obj(TARGET).Attributes.Name,
        'source_layer_index':int(obj(TARGET).Attributes.LayerIndex),'recipe':TAG,'specs':specs,'metrics':metrics,
        'road_crossings':[{'id':r['id'],'point':xyz(r['hit']),'station_m':float(r['station'])} for r in site.roads],
        'objects':[],'height_ceiling_m':60,'native_geometry':'NURBS surfaces and closed Breps; no mesh replacement'}
    state['source_geometry_crc']={oid:int(obj(oid).Geometry.DataCRC(0)) for oid in [TARGET]+ROAD_IDS+LOW_IDS}
    sc.sticky[TAG]={'site':site,'shells':shells,'corridors':corridors,'state':state}
    write('prepare_report.json',state)
    print(json.dumps({'prepared':True,'metrics':metrics},ensure_ascii=False))

def ensure_layer(child,color,visible=True):
    root=sc.doc.Layers.FindByFullPath(LAYER,-1)
    if root<0:
        l=Rhino.DocObjects.Layer();l.Name=LAYER;root=sc.doc.Layers.Add(l)
    path=LAYER+'::'+child
    index=sc.doc.Layers.FindByFullPath(path,-1)
    if index<0:
        l=Rhino.DocObjects.Layer();l.Name=child;l.ParentLayerId=sc.doc.Layers[root].Id;l.Color=color;l.IsVisible=visible
        index=sc.doc.Layers.Add(l)
    return index

def publish():
    data=sc.sticky.get(TAG)
    if not data:raise RuntimeError('Prepare first')
    state=data['state'];doc=sc.doc
    if int(doc.RuntimeSerialNumber)!=state['document_serial']:raise RuntimeError('Document changed')
    for oid,crc in state['source_geometry_crc'].items():
        if int(obj(oid).Geometry.DataCRC(0))!=crc:raise RuntimeError('Source geometry changed since prepare: '+oid)
    backup=os.path.join(os.path.dirname(ROOT),'map','map_before_terrace_interwoven_B_v01.3dm')
    if os.path.exists(backup):raise RuntimeError('Backup already exists; do not overwrite')
    save_document(backup)
    state['backup']=backup
    record=doc.BeginUndoRecord('崖岸 B方案 连续交错曲面 v01')
    try:
        white=Color.FromArgb(238,233,221);green=Color.FromArgb(137,164,91)
        mat=Rhino.DocObjects.Material();mat.Name='崖岸B_暖白人工涂层';mat.DiffuseColor=white;mat.Shine=85;mat.Reflectivity=.16
        material_index=doc.Materials.Add(mat)
        plant=Rhino.DocObjects.Material();plant.Name='崖岸B_草甸种植顶面';plant.DiffuseColor=green;plant.Shine=8
        green_index=doc.Materials.Add(plant)
        def add(g,name,group,color,material=False,visible=True):
            a=Rhino.DocObjects.ObjectAttributes();a.Name=name;a.LayerIndex=ensure_layer(group,color,visible)
            a.SetUserString('recipe',TAG);a.SetUserString('source_object',TARGET)
            a.SetUserString('description','Interwoven rising/falling coastal shells, native NURBS, protected road passages')
            a.MaterialIndex=material_index if material else green_index
            a.MaterialSource=Rhino.DocObjects.ObjectMaterialSource.MaterialFromObject
            oid=doc.Objects.AddBrep(g,a)
            if oid==System.Guid.Empty:raise RuntimeError('Cannot add '+name)
            state['objects'].append({'id':str(oid),'name':name,'group':group})
        for s in data['shells']:
            add(s['volume'],s['name'],s['group'],white,True)
            add(s['green'],s['name']+'_种植曲面','04_种植顶面',green)
        # Preserve the low zero-height ends of the original arc, outside the new canopy.
        for label,lo,hi in [('西端',0,.018),('东端',.982,1)]:
            rail=data['site'].rail
            upper=rail.Trim(rail.Domain.ParameterAt(lo),rail.Domain.ParameterAt(hi)).ToNurbsCurve()
            lower=upper.DuplicateCurve().ToNurbsCurve()
            for i in range(lower.Points.Count):
                p=lower.Points[i].Location;p.Z=0
                lower.Points.SetPoint(i,p)
            parts=G.Brep.CreateFromLoft([upper,lower],G.Point3d.Unset,G.Point3d.Unset,G.LoftType.Straight,False)
            if not parts or any(not x.IsValid for x in parts):raise RuntimeError('End connection invalid')
            for j,g in enumerate(parts):add(g,label+'_保留落地过渡_%d'%j,'08_端部衔接',white,True)
        for i,c in enumerate(data['corridors']):add(c,'T%d_实际道路曲线净空体'%(i+1),'05_隧道净空_辅助',Color.DeepSkyBlue,False,False)
        original=obj(TARGET);a=original.Attributes.Duplicate()
        a.LayerIndex=ensure_layer('07_原弧面备份',Color.Gray,False)
        a.SetUserString('source_layer_index',str(state['source_layer_index']))
        doc.Objects.ModifyAttributes(original,a,True)
    finally:
        doc.EndUndoRecord(record);doc.Views.Redraw()
    write('generation_state.json',state)
    draft=os.path.join(os.path.dirname(ROOT),'map','map_terrace_interwoven_B_v01.3dm')
    if os.path.exists(draft):raise RuntimeError('Draft path already exists; preserve earlier copy')
    save_document(draft)
    state['draft_path']=draft
    write('generation_state.json',state)
    print(json.dumps({'published':True,'objects':len(state['objects']),'backup':backup,'draft':draft},ensure_ascii=False))

def refine():
    """Replace only recipe-owned objects after inspecting the first live view."""
    data=sc.sticky.get(TAG)
    if not data:raise RuntimeError('Prepared state missing')
    state=data['state'];site=Site()
    for oid,crc in state['source_geometry_crc'].items():
        if int(obj(oid).Geometry.DataCRC(0))!=crc:raise RuntimeError('Source changed: '+oid)
    shells=[shell(site,s) for s in state['specs']]
    for s in shells:
        for corridor in data['corridors']:
            result=G.Brep.CreateBooleanIntersection(s['volume'],corridor,.01)
            if result and sum(G.VolumeMassProperties.Compute(x).Volume for x in result)>.005:
                parts=G.Brep.CreateBooleanDifference(s['volume'],corridor,.01)
                if not parts or len(parts)!=1 or not parts[0].IsSolid:raise RuntimeError('Passage cut invalid')
                s['volume']=parts[0]
        bounds=s['volume'].GetBoundingBox(True)
        if not s['volume'].IsValid or not s['volume'].IsSolid or bounds.Max.Z>60.001 or bounds.Min.Z<-.001:
            raise RuntimeError('Refined shell failed preflight')
    green=Rhino.DocObjects.Material();green.Name='崖岸B_草甸种植顶面';green.DiffuseColor=Color.FromArgb(137,164,91);green.Shine=8
    record=sc.doc.BeginUndoRecord('崖岸 B方案 落地支承与种植顶面细化')
    try:
        gi=sc.doc.Materials.Add(green)
        for s in shells:
            for name,g in [(s['name'],s['volume']),(s['name']+'_种植曲面',s['green'])]:
                row=next(r for r in state['objects'] if r['name']==name)
                o=obj(row['id'])
                if o.Attributes.GetUserString('recipe')!=TAG:raise RuntimeError('Object ownership changed')
                if not sc.doc.Objects.Replace(o.Id,g):raise RuntimeError('Cannot replace '+name)
                if name.endswith('_种植曲面'):
                    o=obj(row['id']);a=o.Attributes.Duplicate();a.MaterialIndex=gi
                    a.MaterialSource=Rhino.DocObjects.ObjectMaterialSource.MaterialFromObject
                    sc.doc.Objects.ModifyAttributes(o,a,True)
    finally:sc.doc.EndUndoRecord(record);sc.doc.Views.Redraw()
    data['shells']=shells;data['site']=site
    state['metrics']=[{'name':s['name'],'solid':bool(s['volume'].IsSolid),'valid':bool(s['volume'].IsValid),
        'faces':int(s['volume'].Faces.Count),'bounds':[xyz(s['volume'].GetBoundingBox(True).Min),xyz(s['volume'].GetBoundingBox(True).Max)],
        'planting_area_m2':float(G.AreaMassProperties.Compute(s['green']).Area)} for s in shells]
    state['refinements']=['Continuous finite ground-contact haunches','Explicit grass material in Rhino Rendered mode']
    save_document(state['draft_path'])
    write('generation_state.json',state)
    print(json.dumps({'refined':True,'metrics':state['metrics']},ensure_ascii=False))

def verify():
    data=sc.sticky.get(TAG)
    if not data:raise RuntimeError('Prepared state missing')
    state=data['state'];site=data['site'];failures=[]
    for oid,crc in state['source_geometry_crc'].items():
        if int(obj(oid).Geometry.DataCRC(0))!=crc:failures.append('Source geometry changed '+oid)
    settings=G.MeshingParameters()
    settings.Tolerance=.06;settings.RelativeTolerance=0;settings.MinimumEdgeLength=.20
    settings.MaximumEdgeLength=12;settings.RefineGrid=True;settings.JaggedSeams=False
    aggregate=G.Mesh()
    geometry=[]
    for row in state['objects']:
        if row['group'] in ['05_隧道净空_辅助','08_端部衔接']:continue
        o=obj(row['id']);g=o.Geometry;b=g.GetBoundingBox(True)
        if not g.IsValid:failures.append('Invalid '+row['name'])
        if b.Max.Z>60.001:failures.append('Height ceiling exceeded '+row['name'])
        if row['group']!='04_种植顶面':
            if not g.IsSolid:failures.append('Open shell '+row['name'])
            for m in G.Mesh.CreateFromBrep(g,settings) or []:aggregate.Append(m)
        geometry.append({'id':row['id'],'name':row['name'],'valid':bool(g.IsValid),'solid':bool(g.IsSolid),
            'bbox':[xyz(b.Min),xyz(b.Max)]})
    passages=[]
    for index,r in enumerate(site.roads):
        road=obj(r['id']).Geometry.Faces[0];c=r['curve'];minimum=1e10;limiting=None;violations=[];rays=0;overhead=0
        lo=max(0,r['station']-300);hi=min(c.GetLength(),r['station']+300)
        for i in range(121):
            length=lo+(hi-lo)*i/120;ok,t=c.LengthParameter(length);center=c.PointAt(t)
            ok,u,v=road.ClosestPoint(center)
            for cross in [.03,.18,.34,.5,.66,.82,.97]:
                p=road.PointAt(road.Domain(0).ParameterAt(cross),v)
                origin=p+G.Vector3d(0,0,.05)
                distance=G.Intersect.Intersection.MeshRay(aggregate,G.Ray3d(origin,G.Vector3d.ZAxis))
                rays+=1
                if distance>=0:
                    overhead+=1
                    clearance=float(distance)+.05
                    if clearance<minimum:minimum=clearance;limiting=xyz(p)
                    if clearance<9.8:violations.append({'point':xyz(p),'clearance_m':clearance})
        if violations:failures.append('Insufficient T%d clearance'%(index+1))
        passages.append({'name':'T%d'%(index+1),'road_id':r['id'],'rays':rays,'overhead_hits':overhead,
            'minimum_vertical_clearance_m':None if minimum==1e10 else minimum,'limiting_road_point':limiting,
            'violations':violations,'scope':'600m along actual road; 121 stations x 7 points across its actual surface; upward ray mesh approximation at 0.06m tolerance'})
    result={'failures':failures,'geometry':geometry,'passages':passages,'source_geometry_crc_unchanged':not any('Source' in x for x in failures),
        'mesh_triangles':int(aggregate.Faces.Count),'geometry_type':'Original editable NURBS Breps; mesh only for diagnostic rays',
        'limitations':'Clearance samples are not complete collision/topology/engineering or game physics acceptance; shell intersections and terrain connections remain design-review scope.'}
    rear=data['shells'][0]['top'].IsoCurve(0,data['shells'][0]['top'].Domain(1).T0)
    gaps=[]
    for i in range(201):
        p=rear.PointAtNormalizedLength(i/200)
        ok,t=site.rail.ClosestPoint(p)
        gaps.append(p.DistanceTo(site.rail.PointAt(t)))
    result['main_upper_boundary_max_deviation_m']=max(gaps)
    if max(gaps)>.001:failures.append('Authored upper boundary changed')
    write('verification_report.json',result)
    print(json.dumps({'failures':failures,'passages':passages},ensure_ascii=False))
    return result

def archive():
    """Save a portable native subset with editable design and relevant sources."""
    data=sc.sticky.get(TAG);state=data['state'];doc=sc.doc
    native=Rhino.FileIO.File3dm()
    native.Settings.ModelUnitSystem=doc.ModelUnitSystem
    native.Settings.ModelAbsoluteTolerance=doc.ModelAbsoluteTolerance
    layers={}
    materials={}
    for material in doc.Materials:
        if material.IsDeleted:continue
        nm=Rhino.DocObjects.Material();nm.CopyFrom(material)
        materials[int(material.Index)]=len(list(native.Materials))
        native.Materials.Add(nm)
    for layer in doc.Layers:
        if layer.IsDeleted:continue
        nl=Rhino.DocObjects.Layer();nl.CopyAttributesFrom(layer)
        nl.Name=layer.Name;nl.Id=layer.Id;nl.ParentLayerId=layer.ParentLayerId
        if nl.RenderMaterialIndex>=0:nl.RenderMaterialIndex=materials.get(int(nl.RenderMaterialIndex),-1)
        layers[int(layer.Index)]=len(list(native.Layers))
        native.Layers.Add(nl)
    ids=[row['id'] for row in state['objects']]+[TARGET]+ROAD_IDS+LOW_IDS+['ad44a7ee-76bf-4eac-aff2-1f138675d8a6']
    for oid in ids:
        o=obj(oid);a=o.Attributes.Duplicate();a.LayerIndex=layers[int(a.LayerIndex)]
        if a.MaterialIndex>=0:a.MaterialIndex=materials.get(int(a.MaterialIndex),-1)
        a.SetUserString('source_rhino_id',oid)
        native.Objects.Add(o.Geometry.Duplicate(),a)
    folder=os.path.join(OUT,'source')
    if not os.path.isdir(folder):os.makedirs(folder)
    path=os.path.join(folder,'terrace_B_design_and_context.3dm')
    if not native.Write(path,8):raise RuntimeError('Native archive write failed')
    reopened=Rhino.FileIO.File3dm.Read(path)
    if not reopened or reopened.Objects.Count!=len(ids):raise RuntimeError('Native archive verification failed')
    state['native_archive']=path
    state['archive_object_count']=len(ids)
    write('generation_state.json',state)
    print(json.dumps({'archive':path,'objects':len(ids),'units':str(reopened.Settings.ModelUnitSystem)},ensure_ascii=False))

def capture_views():
    data=sc.sticky.get(TAG);state=data['state'];view=sc.doc.Views.ActiveView;vp=view.ActiveViewport
    rows=[
        ('01_overview.png',[1250,3020,660],[1070,930,22],50),
        ('02_interwoven_bay.png',[1210,1460,95],[1100,690,36],48),
        ('03_T1_road_passage.png',[1100,735,30],[980,565,37],45),
        ('04_T2_road_passage.png',[1605,775,30],[1460,880,25],45),
    ]
    paths=[]
    for name,camera,target,lens in rows:
        vp.ChangeToPerspectiveProjection(True,lens)
        vp.SetCameraLocations(G.Point3d(*target),G.Point3d(*camera));sc.doc.Views.Redraw()
        cap=Rhino.Display.ViewCapture();cap.Width=1920;cap.Height=1080;cap.ScaleScreenItems=True
        cap.DrawGrid=False;cap.DrawGridAxes=False;cap.DrawAxes=False
        bitmap=cap.CaptureToBitmap(view)
        if bitmap is None:raise RuntimeError('Capture failed '+name)
        path=os.path.join(OUT,name);bitmap.Save(path,ImageFormat.Png);bitmap.Dispose();paths.append(path)
    vp.ChangeToPerspectiveProjection(True,50)
    vp.SetCameraLocations(G.Point3d(1070,930,22),G.Point3d(1250,3020,660));sc.doc.Views.Redraw()
    state['captures']=paths
    write('generation_state.json',state)
    save_document(state['draft_path'])
    print(json.dumps({'captures':paths,'active_view':'Design B overview'},ensure_ascii=False))

if __name__=='__main__':prepare()
