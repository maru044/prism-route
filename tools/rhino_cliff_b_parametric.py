# -*- coding: utf-8 -*-
"""Full road-facing Cliff B prototype. Execute run(stage) inside Rhino 8.

Independent capped components avoid a kilometre-scale Boolean/fillet operation.
Original objects are retained. Only objects tagged by this recipe are generated.
"""
from __future__ import division, unicode_literals
import json
import math
import io
import os
from collections import Counter
import Rhino
import scriptcontext as sc
import System
from System.Drawing import Color

G = Rhino.Geometry
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CONFIG = os.path.join(ROOT, 'tools', 'rhino_cliff_b_parametric.json')
STATE = os.path.join(ROOT, '.map_1012_build', 'cliff_b_parametric_state.json')
REPORT = os.path.join(ROOT, 'docs', 'CLIFF_B_PARAMETRIC_MODEL_REPORT.json')
TAG = 'prism_cliff_b_parametric_v01'
TOL = 0.01
META = None


def read_config():
    with io.open(CONFIG, encoding='utf-8') as f:
        return json.load(f)


def source_object(key):
    o = sc.doc.Objects.FindId(System.Guid(read_config()[key]))
    if o is None:
        raise RuntimeError('Source object missing: ' + key)
    return o


def curves():
    cfg = read_config()
    cliff = source_object('cliff_id').Geometry
    perimeter = min(cliff.Edges, key=lambda e: e.GetBoundingBox(True).Max.Z).DuplicateCurve()
    road = source_object('road_id').Geometry.Edges[cfg['outer_road_edge']].DuplicateCurve()
    road.Transform(G.Transform.PlanarProjection(G.Plane.WorldXY))
    return perimeter, road


def load_state():
    if os.path.exists(STATE) and os.path.getsize(STATE) > 2:
        with io.open(STATE, encoding='utf-8') as f:
            return json.load(f)
    return {'tag': TAG, 'stages': [], 'objects': [], 'source_visibility': {}}


def save_state(state):
    folder = os.path.dirname(STATE)
    if not os.path.isdir(folder):
        os.makedirs(folder)
    body = json.dumps(state, ensure_ascii=False, indent=2)
    with io.open(STATE, 'w', encoding='utf-8') as f:
        f.write(body)


def layer(name, rgb, parent=None):
    full = parent.FullPath + '::' + name if parent else name
    index = sc.doc.Layers.FindByFullPath(full, -1)
    if index < 0:
        value = Rhino.DocObjects.Layer()
        value.Name = name
        value.Color = Color.FromArgb(*rgb)
        if parent:
            value.ParentLayerId = parent.Id
        index = sc.doc.Layers.Add(value)
    return sc.doc.Layers[index]


def material(name, rgb, transparency=0):
    for m in sc.doc.Materials:
        if m.Name == name:
            return m.Index
    m = Rhino.DocObjects.Material()
    m.Name = name
    m.DiffuseColor = Color.FromArgb(*rgb)
    m.SpecularColor = Color.FromArgb(35, 35, 35)
    m.Shine = 3
    m.Transparency = transparency
    if transparency:
        m.IndexOfRefraction = 1.333
    return sc.doc.Materials.Add(m)


def add(geometry, name, group, state, rgb=(242, 241, 233), transparency=0, solid=True):
    if geometry is None or not geometry.IsValid:
        raise RuntimeError('Invalid geometry: ' + name)
    if solid and isinstance(geometry, G.Brep) and not geometry.IsSolid:
        raise RuntimeError('Open component: ' + name)
    if solid and isinstance(geometry, G.Extrusion) and not geometry.IsSolid:
        raise RuntimeError('Open extrusion: ' + name)
    parent = layer(read_config()['layer'], (240, 239, 231))
    sub = layer(group, rgb, parent)
    attrs = Rhino.DocObjects.ObjectAttributes()
    attrs.Name = name
    attrs.WireDensity = -1
    attrs.LayerIndex = sub.Index
    attrs.ColorSource = Rhino.DocObjects.ObjectColorSource.ColorFromObject
    attrs.ObjectColor = Color.FromArgb(*rgb)
    attrs.MaterialSource = Rhino.DocObjects.ObjectMaterialSource.MaterialFromObject
    attrs.MaterialIndex = material(TAG + '_' + group, rgb, transparency)
    attrs.SetUserString('recipe', TAG)
    attrs.SetUserString('component', group)
    attrs.SetUserString('config', str(CONFIG))
    attrs.SetUserString('name', name)
    attrs.SetUserString('description', 'Cliff B full-scale parametric prototype / ' + group)
    oid = sc.doc.Objects.Add(geometry, attrs)
    if oid == System.Guid.Empty:
        raise RuntimeError('Rhino rejected ' + name)
    obj = sc.doc.Objects.FindId(oid)
    cfg = read_config()
    mp = G.MeshingParameters()
    mp.Tolerance = cfg['height_m'] * cfg['meshing_tolerance_ratio']
    mp.RelativeTolerance = 0
    mp.MaximumEdgeLength = cfg['height_m'] * cfg['meshing_max_edge_ratio']
    mp.MinimumEdgeLength = 0.05
    mp.RefineGrid = True
    mp.JaggedSeams = False
    obj.SetRenderMeshParameters(mp)
    if META:
        META(str(oid), name, 'Cliff B full-scale parametric prototype / ' + group)
    state['objects'].append({'id': str(oid), 'name': name, 'group': group})
    return oid


def flat_interpolated(points, closed=False):
    points = list(points)
    if closed:
        points.append(points[0])
    return G.Curve.CreateInterpolatedCurve(points, 3,
             G.CurveKnotStyle.ChordPeriodic if closed else G.CurveKnotStyle.Chord)


def frame(s, perimeter, road):
    p = road.PointAtNormalizedLength(s)
    ok, t = perimeter.ClosestPoint(p)
    if not ok:
        raise RuntimeError('Cannot project roadway')
    tangent = perimeter.TangentAt(t)
    tangent.Z = 0
    tangent.Unitize()
    outside = G.Vector3d(tangent.Y, -tangent.X, 0)
    # The inspected source perimeter is counter-clockwise in WorldXY.
    return p, tangent, outside


def point(s, offset, z, perimeter, road):
    p, _, n = frame(s, perimeter, road)
    p += n * offset
    p.Z = z
    return p


def ribbon(inner, outer, z, thickness, perimeter, road, start=0, end=1, samples=180):
    left, right = [], []
    for i in range(samples+1):
        s = start + (end-start) * i/samples
        a = inner(s) if callable(inner) else inner
        b = outer(s) if callable(outer) else outer
        left.append(point(s, a, z, perimeter, road))
        right.append(point(s, b, z, perimeter, road))
    a, b = flat_interpolated(left), flat_interpolated(right)
    b.Reverse()
    outline = G.PolyCurve()
    for c in [a, G.LineCurve(left[-1], right[-1]), b, G.LineCurve(right[0], left[0])]:
        if not outline.Append(c):
            raise RuntimeError('Cannot join ribbon boundary')
    if not outline.IsClosed:
        raise RuntimeError('Ribbon boundary is open')
    extrusion = G.Extrusion.Create(outline, -thickness, True)
    if extrusion is None or not extrusion.IsSolid:
        raise RuntimeError('Cannot cap ribbon')
    return extrusion


def rounded_roof(perimeter, cfg):
    h = cfg['height_m']
    depth = h * cfg['roof_thickness_ratio']
    width = h * cfg['roof_rollover_width_ratio']
    profiles = []
    for i in range(9):
        theta = -math.pi/2 + math.pi*i/8
        inset = width * (1-math.cos(theta))
        if inset < 1e-6:
            c = perimeter.DuplicateCurve()
        else:
            candidates = perimeter.Offset(G.Plane.WorldXY, -inset, TOL, G.CurveOffsetCornerStyle.Round)
            candidates = [c for c in candidates or [] if c.IsClosed]
            if len(candidates) != 1:
                raise RuntimeError('Roof inset requires a single closed contour')
            c = candidates[0]
        c.Transform(G.Transform.Translation(0, 0, h+depth/2*math.sin(theta)))
        profiles.append(c)
    shell = G.Brep.CreateFromLoft(profiles, G.Point3d.Unset, G.Point3d.Unset, G.LoftType.Normal, False)
    if shell is None or len(shell) != 1:
        raise RuntimeError('Cannot loft rounded roof')
    caps = list(G.Brep.CreatePlanarBreps(profiles[0], TOL) or [])
    caps += list(G.Brep.CreatePlanarBreps(profiles[-1], TOL) or [])
    joined = G.Brep.JoinBreps(list(shell)+caps, TOL)
    if joined is None or len(joined) != 1 or not joined[0].IsSolid:
        raise RuntimeError('Roof shell does not close')
    return joined[0]


def solid_core(perimeter, road, cfg):
    points = []
    setback = cfg['height_m'] * cfg['core_setback_ratio']
    for i in range(480):
        p = perimeter.PointAtNormalizedLength(i/480)
        ok, t = road.ClosestPoint(p)
        q = road.PointAt(t)
        distance = p.DistanceTo(q)
        # Continue the setback through both entrances. Fading it at the road
        # endpoints would leave an opaque wedge across the driving clearance.
        weight = math.exp(-(distance/22)**4)
        ok, v = perimeter.ClosestPoint(p)
        tangent = perimeter.TangentAt(v)
        n = G.Vector3d(tangent.Y, -tangent.X, 0)
        n.Unitize()
        points.append(p - n * setback * weight)
    boundary = flat_interpolated(points, True)
    if boundary is None or not boundary.IsClosed:
        raise RuntimeError('Core contour did not close')
    intersections = G.Intersect.Intersection.CurveSelf(boundary, TOL)
    if intersections is not None and intersections.Count:
        raise RuntimeError('Core contour self-intersects')
    core = G.Extrusion.Create(boundary, cfg['height_m']*(1-cfg['roof_thickness_ratio']/2), True)
    if core is None or not core.IsSolid:
        raise RuntimeError('Core cannot be capped')
    return core


def begin(state):
    if state['stages']:
        return
    for key in ['cliff_id', 'roof_id', 'base_id', 'road_id', 'shallow_bed_id']:
        o = source_object(key)
        state['source_visibility'][str(o.Id)] = {'hidden': o.IsHidden, 'layer': o.Attributes.LayerIndex}
    backup = os.path.join(os.path.dirname(ROOT), 'map', 'map_before_cliffB_parametric_v01.3dm')
    if os.path.exists(backup):
        # A failed stage can be resumed without replacing the original backup.
        saved = Rhino.FileIO.File3dm.Read(backup)
        saved_ids = set(str(o.Id) for o in saved.Objects) if saved else set()
        if not all(oid in saved_ids for oid in state['source_visibility']):
            raise RuntimeError('Existing backup does not contain the source objects')
    else:
        options = Rhino.FileIO.FileWriteOptions()
        options.SuppressAllInput = True
        options.SuppressDialogBoxes = True
        options.IncludeRenderMeshes = False
        options.UpdateDocumentPath = False
        if not sc.doc.Write3dmFile(str(backup), options):
            raise RuntimeError('Cannot save original document backup')
    state['backup'] = str(backup)
    state['document_serial'] = int(sc.doc.RuntimeSerialNumber)
    save_state(state)


def foundation(state, cfg):
    perimeter, road = curves()
    # Compute all foundation components before adding any of them.
    core = solid_core(perimeter, road, cfg)
    roof = rounded_roof(perimeter, cfg)
    base = G.Extrusion.Create(perimeter, -cfg['height_m']*0.012, True)
    level = cfg['height_m'] * cfg['road_level_ratio']
    roadway = source_object('road_id').Geometry.DuplicateBrep()
    roadway.Transform(G.Transform.Translation(0, 0, level-35))
    deck = roadway.Faces[0].CreateExtrusion(G.LineCurve(G.Point3d.Origin, G.Point3d(0,0,-1.2)), True)
    if deck is None or not deck.IsSolid:
        raise RuntimeError('Road deck does not close')
    add(core, 'B_实体核心_道路侧退让', '01_实体核心', state)
    add(roof, 'B_连续厚屋盖_圆滑收边', '02_顶部厚壳', state)
    add(base, 'B_完整基础板', '03_底层平台', state, (233,231,222))
    add(deck, 'B_单层连续车行道路', '04_中层道路', state, (62,65,70))
    walk = ribbon(0, 3.6, level+0.10, .65, perimeter, road)
    add(walk, 'B_中层外缘步行带', '05_中层步行', state)
    parapet = ribbon(3.2,3.6,level+1.18,1.12,perimeter,road)
    add(parapet, 'B_中层连续矮护墙', '05_中层步行', state)
    print('FOUNDATION_OK core_solid=%s roof_solid=%s road_solid=%s' % (core.IsSolid,roof.IsSolid,deck.IsSolid))


def stations(perimeter, road, cfg):
    count = int(round(road.GetLength() / (cfg['height_m']*cfg['rib_span_ratio'])))
    count = max(3, count)
    cumulative = [0.0]
    previous = frame(.025, perimeter, road)[1]
    for i in range(1, 601):
        s = .025 + .95*i/600
        tangent = frame(s, perimeter, road)[1]
        angle = G.Vector3d.VectorAngle(previous, tangent)
        density = 1 + min(.65, angle*45)
        for node in cfg['nodes']:
            density *= 1 - .35*math.exp(-((s-node)/.045)**2)
        cumulative.append(cumulative[-1]+density)
        previous = tangent
    result = []
    for i in range(count):
        target = cumulative[-1]*(i+.5)/count
        j = next(j for j, value in enumerate(cumulative) if value >= target)
        result.append(.025+.95*j/600)
    return result


def tapered_member(points, radius, along):
    curve = flat_interpolated(points)
    profiles = []
    for i in range(13):
        u = i/12
        ok, t = curve.NormalizedLengthParameter(u)
        if not ok:
            raise RuntimeError('Cannot sample structural rail')
        p = curve.PointAt(t)
        tangent = curve.TangentAt(t)
        tangent.Unitize()
        x = along - tangent * (along*tangent)
        if not x.Unitize():
            x = G.Vector3d.XAxis
        y = G.Vector3d.CrossProduct(tangent, x)
        y.Unitize()
        r = radius(u)
        profiles.append(G.Ellipse(G.Plane(p,x,y), r*.68,r).ToNurbsCurve())
    loft = G.Brep.CreateFromLoft(profiles, G.Point3d.Unset, G.Point3d.Unset, G.LoftType.Normal, False)
    if loft is None or len(loft) != 1:
        raise RuntimeError('Member loft failed')
    member = loft[0].CapPlanarHoles(TOL)
    if member is None or not member.IsSolid:
        raise RuntimeError('Structural member did not close')
    return member


def structure(state, cfg, batch):
    perimeter, road = curves()
    samples = stations(perimeter, road, cfg)
    selected = range(batch*8,min((batch+1)*8,len(samples)))
    h = cfg['height_m']
    radius = h * cfg['rib_radius_ratio']
    offset = h * cfg['frame_outside_road_ratio']
    z0 = h * cfg['ground_level_ratio']-.05
    for index in selected:
        s = samples[index]
        p, tangent, normal = frame(s, perimeter, road)
        def at(n,z,d=0):
            q = p + normal*n + tangent*d
            q.Z = z
            return q
        span = road.GetLength()*(samples[min(index+1,len(samples)-1)]-samples[max(0,index-1)])/2
        span = span or h*cfg['rib_span_ratio']
        sway = .045*h*math.sin(s*math.pi*3)
        stem_points = [at(offset,z0),at(offset,.09*h),at(offset+1.2,.25*h,sway*.3),
                       at(offset+2,.40*h,sway*.8),at(offset+1,.56*h,sway)]
        stem = tapered_member(stem_points,lambda u:radius*(1.60-.55*u+.08*math.sin(u*math.pi)),tangent)
        add(stem, 'B_主肋_%02d_曲面支承' % index, '06_参数化主肋', state)
        for side in [-1,1]:
            branch_points = [at(offset+1,.50*h,sway),at(offset+1,.61*h,sway+side*span*.12),
                             at(offset-1,.76*h,side*span*.28),at(0,.88*h,side*span*.40),
                             at(-4.5,.965*h,side*span*.48)]
            branch = tapered_member(branch_points,lambda u:radius*(1.08-.43*u),tangent)
            add(branch, 'B_主肋_%02d_上分叉_%s' % (index,'L' if side<0 else 'R'), '06_参数化主肋', state)
        # Lower arm supports the human-scale gallery roof behind the stem.
        if all(abs(s-node)>.047 for node in cfg['nodes']):
            arm_points = [at(offset,.09*h),at(offset,.13*h),at(2,.17*h),at(-5,.19*h),at(-10,.19*h)]
            arm = tapered_member(arm_points,lambda u:radius*(.80-.39*u),tangent)
            add(arm,'B_主肋_%02d_底层廊檐支臂' % index,'07_底层支承',state)
    state['rib_station_parameters'] = samples
    state['road_length_m'] = road.GetLength()
    print('STRUCTURE_BATCH_OK batch=%s count=%s total_stations=%s' % (batch,len(list(selected)),len(samples)))


def ground_space(state, cfg):
    perimeter, road = curves()
    h = cfg['height_m']
    inner = h*cfg['promenade_inner_offset_ratio']
    outer = h*cfg['promenade_outer_offset_ratio']
    def waterfront(s):
        return outer + sum(.11*h*math.exp(-((s-node)/.044)**2) for node in cfg['nodes'])
    slab = ribbon(inner,waterfront,h*cfg['ground_level_ratio'],h*cfg['ground_slab_thickness_ratio'],perimeter,road,.015,.985)
    add(slab,'B_全长峡谷步行平台_节点渐宽','03_底层平台',state,(235,233,223))
    for step,(width,z,depth) in enumerate([(2.2,.43,.65),(4.4,.24,.47)]):
        slab = ribbon(lambda s:waterfront(s)+(step*2.2),lambda s:waterfront(s)+width,z,depth,perimeter,road,.018,.982)
        add(slab,'B_亲水缓阶_%s' % (step+1),'08_亲水缓阶',state,(236,233,221))
    # Sky courts interrupt the lower roof; the single driving deck stays intact.
    spans = [(0.018,.173),(.267,.473),(.567,.773),(.867,.982)]
    for i,(a,b) in enumerate(spans):
        cover = ribbon(inner-5,-8.5,h*.19,h*.018,perimeter,road,a,b,70)
        add(cover,'B_底层连续廊檐_%s' % i,'09_底层廊檐',state)
    for i,s in enumerate(cfg['nodes']):
        a,b = s-.025,s+.025
        bench = ribbon(lambda u:waterfront(u)-2.3,lambda u:waterfront(u)-1.2,h*cfg['ground_level_ratio']+.47,.47,perimeter,road,a,b,25)
        add(bench,'B_观水坐凳_%s' % i,'10_停留节点',state,(239,237,229))
        back = ribbon(inner-3,inner-1,h*cfg['ground_level_ratio']+.48,.48,perimeter,road,a,b,25)
        add(back,'B_光庭内侧坐台_%s' % i,'10_停留节点',state,(239,237,229))
    water = source_object('shallow_bed_id').Geometry.DuplicateBrep()
    water.Transform(G.Transform.Translation(0,0,h*cfg['shallow_water_level_ratio']))
    add(water,'B_峡谷浅水_保留原沙底','11_浅水示意',state,(100,187,197),.55,False)
    for name,c in [('B_底部包络',perimeter),('B_道路侧生成引导线',road)]:
        add(c,name,'00_参数引导线',state,(90,150,200),solid=False)
    sub = layer('00_参数引导线',(90,150,200),layer(cfg['layer'],(240,239,231)))
    sub.IsVisible = False
    sub.CommitChanges()
    print('GROUND_SPACE_OK full_length_m=%s nodes=%s' % (road.GetLength(),len(cfg['nodes'])))


def update_core(state,cfg):
    perimeter,road = curves()
    core = solid_core(perimeter,road,cfg)
    record = next(r for r in state['objects'] if r['group']=='01_实体核心')
    if not sc.doc.Objects.Replace(System.Guid(record['id']),core):
        raise RuntimeError('Cannot update derived core')
    print('CORE_ENTRANCES_OPEN solid=%s' % core.IsSolid)


def mesh_for(geometry, maximum_edge=4):
    if isinstance(geometry,G.Extrusion):
        geometry = geometry.ToBrep()
    mp = G.MeshingParameters()
    mp.Tolerance = .08
    mp.RelativeTolerance = 0
    mp.MaximumEdgeLength = maximum_edge
    mp.MinimumEdgeLength = .08
    mp.GridAngle = math.radians(10)
    mp.RefineGrid = True
    mp.JaggedSeams = False
    mp.SimplePlanes = True
    mesh = G.Mesh()
    for part in G.Mesh.CreateFromBrep(geometry,mp) or []:
        mesh.Append(part)
    mesh.Normals.ComputeNormals()
    mesh.Compact()
    if not mesh.IsValid or mesh.Faces.Count == 0:
        raise RuntimeError('Cannot build inspection mesh')
    return mesh


def audit_clearance(state,cfg,batch):
    roadway = source_object('road_id').Geometry.DuplicateBrep()
    level = cfg['height_m']*cfg['road_level_ratio']
    roadway.Transform(G.Transform.Translation(0,0,level-35+.1))
    volume = roadway.Faces[0].CreateExtrusion(G.LineCurve(G.Point3d.Origin,G.Point3d(0,0,5.1)),True)
    road_mesh = mesh_for(volume)
    checks = state.setdefault('clearance_mesh_checks',[])
    for record in state['objects']:
        selected = record['group']=='01_实体核心' and batch==0
        if record['group'] in ['06_参数化主肋','07_底层支承']:
            index = int(record['name'].split('_')[2])
            selected = batch*8 <= index < (batch+1)*8
        if not selected:
            continue
        geometry = sc.doc.Objects.FindId(System.Guid(record['id'])).Geometry
        box = geometry.GetBoundingBox(True)
        if box.Max.Z<level+.1 or box.Min.Z>level+5.2:
            continue
        mesh = mesh_for(geometry)
        intersections = G.Intersect.Intersection.MeshMeshFast(mesh,road_mesh)
        count = len(intersections) if intersections else 0
        checks.append({'name':record['name'],'id':record['id'],'intersection_curves':count,'mesh_faces':int(mesh.Faces.Count)})
    print(json.dumps({'audit_batch':batch,'checks_total':len(checks),'collisions':[c['name'] for c in checks if c['intersection_curves']]},ensure_ascii=False))


def finish(state,cfg):
    required = ['foundation','ground']+['ribs_%s'%i for i in range(4)]+['audit_%s'%i for i in range(4)]
    if any(stage not in state['stages'] for stage in required):
        raise RuntimeError('Complete all generation and clearance stages first')
    collisions = [c for c in state.get('clearance_mesh_checks',[]) if c['intersection_curves']]
    if collisions:
        raise RuntimeError('Components intersect driving clearance: ' + str([c['name'] for c in collisions]))
    counts = Counter()
    invalid,open_solids = [],[]
    for record in state['objects']:
        obj = sc.doc.Objects.FindId(System.Guid(record['id']))
        if obj is None or not obj.Geometry.IsValid:
            invalid.append(record['name'])
            continue
        counts[record['group']] += 1
        g = obj.Geometry
        if record['group'] not in ['00_参数引导线','11_浅水示意'] and not g.IsSolid:
            open_solids.append(record['name'])
    if invalid or open_solids:
        raise RuntimeError('Invalid/open components: ' + str(invalid+open_solids))
    for key in ['cliff_id','roof_id','base_id','road_id']:
        obj = source_object(key)
        if not obj.IsHidden:
            sc.doc.Objects.Hide(obj,True)
    # The original sand bed remains visible below the new shallow-water sheet.
    roof_record = next(r for r in state['objects'] if r['group']=='02_顶部厚壳')
    roof_box = sc.doc.Objects.FindId(System.Guid(roof_record['id'])).Geometry.GetBoundingBox(True)
    state['report'] = {'layer':cfg['layer'],'generated_objects':len(state['objects']),
        'component_counts':dict(counts),'valid_geometry':not invalid,'all_architectural_components_solid':not open_solids,
        'road_length_m':state['road_length_m'],'rib_count':len(state['rib_station_parameters']),
        'roof_z_range_m':[roof_box.Min.Z,roof_box.Max.Z],
        'roof_thickness_m':roof_box.Max.Z-roof_box.Min.Z,
        'rounded_roof_edge_width_m':cfg['height_m']*cfg['roof_rollover_width_ratio'],
        'vehicle_clearance_height_m':5.1,'vehicle_clearance_floor_offset_m':.1,
        'clearance_mesh_tolerance_m':.08,'clearance_mesh_checks':state['clearance_mesh_checks'],
        'clearance_intersections':collisions,'water_level_m':cfg['height_m']*cfg['shallow_water_level_ratio'],
        'original_objects_retained':list(state['source_visibility']),
        'original_sand_bed_visible':not source_object('shallow_bed_id').IsHidden,
        'original_backup':state['backup'],'config':cfg,
        'scope':'Full road-facing Rhino prototype. Independent intersecting capped members; no large Boolean union. Mesh-based vehicle clearance check, not a gameplay or structural-engineering test.'}
    with io.open(REPORT,'w',encoding='utf-8') as f:
        f.write(json.dumps(state['report'],ensure_ascii=False,indent=2))
    print(json.dumps({k:state['report'][k] for k in ['generated_objects','rib_count','roof_thickness_m','valid_geometry','all_architectural_components_solid','clearance_intersections']},ensure_ascii=False))


def rooftop(state,cfg):
    h = cfg['height_m']
    base_z = h * (1+cfg['roof_thickness_ratio']/2)
    profiles = []
    for i in range(10):
        theta = (math.pi/2-.001)*i/9
        center = G.Point3d(cfg['pavilion_center_xy'][0],cfg['pavilion_center_xy'][1],base_z+h*cfg['pavilion_height_ratio']*math.sin(theta))
        plane = G.Plane(center,G.Vector3d.ZAxis)
        a,b = [h*r*math.cos(theta) for r in cfg['pavilion_radii_ratio']]
        profiles.append(G.Ellipse(plane,a,b).ToNurbsCurve())
    loft = G.Brep.CreateFromLoft(profiles,G.Point3d.Unset,G.Point3d.Unset,G.LoftType.Normal,False)
    if loft is None or len(loft)!=1:
        raise RuntimeError('Cannot loft rooftop pavilion')
    pavilion = loft[0].CapPlanarHoles(TOL)
    add(pavilion,'B_低矮椭圆屋顶建筑','12_顶部建筑',state)
    for oid in cfg['rooftop_massing_ids']:
        obj = sc.doc.Objects.FindId(System.Guid(oid))
        if obj is None:
            continue
        state['source_visibility'].setdefault(oid,{'hidden':obj.IsHidden,'layer':obj.Attributes.LayerIndex})
        if not obj.IsHidden:
            sc.doc.Objects.Hide(obj,True)
    for record in state['objects']:
        obj = sc.doc.Objects.FindId(System.Guid(record['id']))
        attrs = obj.Attributes.Duplicate()
        attrs.WireDensity = -1
        sc.doc.Objects.ModifyAttributes(obj,attrs,True)
    print('ROOFTOP_OK pavilion_solid=%s' % pavilion.IsSolid)


def save_model():
    path = os.path.join(os.path.dirname(ROOT),'map','map_cliffB_parametric_v01.3dm')
    options = Rhino.FileIO.FileWriteOptions()
    options.SuppressAllInput = True
    options.SuppressDialogBoxes = True
    options.IncludeRenderMeshes = False
    options.UpdateDocumentPath = False
    if not sc.doc.Write3dmFile(path,options):
        raise RuntimeError('Cannot save prototype copy')
    print('MODEL_SAVED ' + path)


def preview(state,cfg):
    folder = os.path.join(ROOT,'docs','cliff_b_parametric_v01')
    if not os.path.isdir(folder):
        os.makedirs(folder)
    with io.open(os.path.join(folder,'.gdignore'),'w',encoding='utf-8') as f:
        f.write('\n')
    perimeter,road = curves()
    keep = set(r['id'] for r in state['objects'])
    keep.add(cfg['shallow_bed_id'])
    temporarily_hidden = []
    view = next(v for v in sc.doc.Views if v.ActiveViewport.IsPerspectiveProjection)
    sc.doc.Views.ActiveView = view
    vp = view.ActiveViewport
    vp.Camera35mmLensLength = 32
    vp.CameraUp = G.Vector3d.ZAxis
    vp.DisplayMode = Rhino.Display.DisplayModeDescription.FindByName('Shaded')
    cameras = [
        ('01_整体道路侧',G.Point3d(1260,1120,430),G.Point3d(1220,340,28)),
        ('02_中层道路',point(.34,1.8,36.8,perimeter,road),point(.46,16,22,perimeter,road)),
        ('03_峡谷底层',point(.52,55,12,perimeter,road),point(.62,-3,15,perimeter,road)),
        ('04_屋面收边',G.Point3d(1320,800,180),G.Point3d(1170,330,63))]
    capture = Rhino.Display.ViewCapture()
    capture.Width = 1600
    capture.Height = 1000
    capture.DrawGrid = False
    capture.DrawAxes = False
    capture.DrawGridAxes = False
    try:
        for obj in sc.doc.Objects:
            if not obj.IsDeleted and not obj.IsHidden and str(obj.Id) not in keep:
                if sc.doc.Objects.Hide(obj,True):
                    temporarily_hidden.append(obj.Id)
        for i,(name,location,target) in enumerate(cameras):
            vp.Camera35mmLensLength = 22 if i==2 else 32
            vp.SetCameraLocations(target,location)
            sc.doc.NamedViews.Add('B验证_'+name,vp.Id)
            view.Redraw()
            bitmap = capture.CaptureToBitmap(view)
            if bitmap is None:
                raise RuntimeError('Viewport capture failed')
            path = os.path.join(folder,['overview.png','road.png','canyon.png','roof.png'][i])
            bitmap.Save(path,System.Drawing.Imaging.ImageFormat.Png)
            bitmap.Dispose()
            print('VIEW_CAPTURE '+path)
    finally:
        for oid in temporarily_hidden:
            sc.doc.Objects.Show(oid,True)
        vp.SetCameraLocations(cameras[0][2],cameras[0][1])
        vp.Camera35mmLensLength = 32
        sc.doc.Views.Redraw()
    save_model()


def reset_generated():
    """Explicit regeneration reset; never removes the originals or backup."""
    state = load_state()
    targets = []
    for record in state['objects']:
        obj = sc.doc.Objects.FindId(System.Guid(record['id']))
        if obj is not None:
            if obj.Attributes.GetUserString('recipe') != TAG:
                raise RuntimeError('Refusing to remove an object not owned by this recipe')
            targets.append(obj)
    undo = sc.doc.BeginUndoRecord('Reset only Cliff B generated prototype')
    try:
        for obj in targets:
            sc.doc.Objects.Delete(obj,True)
        for oid,visibility in state['source_visibility'].items():
            obj = sc.doc.Objects.FindId(System.Guid(oid))
            if obj is None:
                raise RuntimeError('Original source object missing during restoration')
            if visibility['hidden']:
                sc.doc.Objects.Hide(obj,True)
            else:
                sc.doc.Objects.Show(obj,True)
        if os.path.exists(STATE):
            os.remove(STATE)
    finally:
        sc.doc.EndUndoRecord(undo)
        sc.doc.Views.Redraw()
    print('RESET_GENERATED_ONLY count=%s originals_restored=true backup_retained=true' % len(targets))


def run(stage, metadata_callback=None):
    global META
    META = metadata_callback
    cfg = read_config()
    state = load_state()
    if stage in state['stages']:
        raise RuntimeError('Stage already completed: ' + stage)
    if state['stages'] and state['document_serial'] != sc.doc.RuntimeSerialNumber:
        raise RuntimeError('Active document changed')
    old_redraw = sc.doc.Views.RedrawEnabled
    undo = sc.doc.BeginUndoRecord('Cliff B parametric: ' + stage)
    before = len(state['objects'])
    try:
        sc.doc.Views.RedrawEnabled = False
        if stage == 'foundation':
            begin(state)
            foundation(state, cfg)
        elif stage.startswith('ribs_'):
            if 'foundation' not in state['stages']:
                raise RuntimeError('Build foundation first')
            structure(state,cfg,int(stage.split('_')[1]))
        elif stage == 'ground':
            ground_space(state,cfg)
        elif stage == 'core_update':
            update_core(state,cfg)
        elif stage.startswith('audit_'):
            audit_clearance(state,cfg,int(stage.split('_')[1]))
        elif stage == 'finish':
            finish(state,cfg)
            save_model()
        elif stage == 'rooftop':
            rooftop(state,cfg)
        elif stage == 'preview':
            preview(state,cfg)
        else:
            raise ValueError('Unknown stage: ' + stage)
        state['stages'].append(stage)
        save_state(state)
    except Exception:
        # Roll back only components newly added by this stage.
        for record in state['objects'][before:]:
            sc.doc.Objects.Delete(System.Guid(record['id']), True)
        raise
    finally:
        sc.doc.EndUndoRecord(undo)
        sc.doc.Views.RedrawEnabled = old_redraw
        sc.doc.Views.Redraw()
    print(json.dumps({'stage':stage,'objects_added':len(state['objects'])-before,'total':len(state['objects'])},ensure_ascii=False))
