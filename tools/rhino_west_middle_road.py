# -*- coding: utf-8 -*-
"""Rebuild the west middle road from the user's two untouched edge curves.

Run build(), publish(), verify() separately in connected Rhino. This stage
creates the road and shoulders, not the later semi-open tunnel excavation.
No independent CAD file or version layer is written.
"""
from __future__ import unicode_literals, division
import Rhino, scriptcontext as sc, System, math
G = Rhino.Geometry
TAG = 'west_middle_road_1020'
ROAD = '301ef8a8-0448-4086-b86d-3df7326e1caf'
EDGES = ['30724a4e-2a94-43ae-a34b-766e8af01adb',
         '02d69638-fd15-4f7e-bdc1-b41ff19dd1f0']

def obj(key): return sc.doc.Objects.FindId(System.Guid(key))

def objects():
    e = Rhino.DocObjects.ObjectEnumeratorSettings()
    e.NormalObjects = True; e.HiddenObjects = True; e.LockedObjects = True
    return list(sc.doc.Objects.GetObjectList(e))

def build():
    a, b = [obj(k).Geometry for k in EDGES]
    d = sc.sticky.get(TAG, {})
    d['before'] = sc.sticky['west_road_1020_before']
    # Pair nearest points rather than equal curve parameters. The original
    # loft skewed cross sections to over 33 m despite its true 20 m width.
    road_sections = []; base_sections = []; frames = []; widths = []
    for i in range(261):
        p = a.PointAtNormalizedLength(i / 260.)
        ok, t = b.ClosestPoint(p); assert ok
        q = b.PointAt(t)
        n = q - p; w = n.Length; assert n.Unitize()
        c = (p + q) * .5; c.Z = 35.25
        widths.append(w); frames.append((c, n, w))
        road_sections.append(G.LineCurve(c - n * (w / 2), c + n * (w / 2)))
        def pt(y, z):
            v = c + n * y; v.Z = z; return v
        h = w / 2.
        # Shallow warm-white curb/shoulder with a buried underside. Central
        # foundation overlaps the asphalt underside by 4 cm, avoiding a gap.
        yz = [(-h-1.4,35.17),(-h-1.2,35.30),(-h-.45,35.30),
              (-h-.16,35.13),(h+.16,35.13),(h+.45,35.30),
              (h+1.2,35.30),(h+1.4,35.17),(h+1.4,34.02),
              (h+.9,33.82),(-h-.9,33.82),(-h-1.4,34.02)]
        pts = [pt(y,z) for y,z in yz]; pts.append(pts[0])
        base_sections.append(G.PolylineCurve(pts))
    top = G.Brep.CreateFromLoft(road_sections, G.Point3d.Unset,
                              G.Point3d.Unset, G.LoftType.Normal, False)
    assert top and len(top) == 1 and top[0].IsValid
    if top[0].Faces[0].NormalAt(top[0].Faces[0].Domain(0).Mid,
                              top[0].Faces[0].Domain(1).Mid).Z < 0:
        top[0].Flip()
    road = G.Brep.CreateFromOffsetFace(top[0].Faces[0], -.16, .002, False, True)
    assert road and road.IsValid and road.IsSolid
    bed = G.Brep.CreateFromLoft(base_sections, G.Point3d.Unset,
                              G.Point3d.Unset, G.LoftType.Normal, False)
    assert bed and len(bed) == 1
    bed = bed[0].CapPlanarHoles(.005)
    assert bed and bed.IsValid and bed.IsSolid
    for g in [road,bed]:
        if g.SolidOrientation == G.BrepSolidOrientation.Inward: g.Flip()
    d.update(road=road, bed=bed, frames=frames, top=top[0], widths=widths)
    sc.sticky[TAG] = d
    return {'width_min':min(widths),'width_max':max(widths),
            'road_faces':int(road.Faces.Count),'bed_faces':int(bed.Faces.Count)}

def publish():
    d = sc.sticky[TAG]; source = obj(ROAD)
    # Match the existing east asphalt, rather than creating another material.
    asphalt = obj('47800a9c-ca72-4dc5-8203-d6d5d91d29a9').Attributes
    attr = source.Attributes.Duplicate()
    attr.Name = '西侧中层道路_连续20米路面'
    attr.MaterialIndex = asphalt.MaterialIndex; attr.MaterialSource = asphalt.MaterialSource
    attr.ObjectColor = asphalt.ObjectColor; attr.ColorSource = asphalt.ColorSource
    attr.SetUserString('west_middle_road_role','asphalt')
    attr.SetUserString('design_stage','Road only; semi-open tunnel excavation pending')
    mp = G.MeshingParameters(); mp.Tolerance = .025
    mp.MaximumEdgeLength = 4.; mp.RefineGrid = True; mp.JaggedSeams = False
    mp.RefineAngle = math.radians(5)
    assert sc.doc.Objects.Replace(source.Id,d['road'])
    assert sc.doc.Objects.ModifyAttributes(source.Id,attr,True)
    base_attr = attr.Duplicate(); base_attr.Name = '西侧中层道路_连续路肩与浅路基'
    material = obj('9a1978f8-f1dd-43db-8d9a-b25fdc8023b8').Attributes
    base_attr.MaterialIndex = material.MaterialIndex
    base_attr.MaterialSource = material.MaterialSource
    base_attr.ObjectColor = material.ObjectColor; base_attr.ColorSource = material.ColorSource
    base_attr.SetUserString('west_middle_road_role','foundation')
    existing = [o for o in objects() if o.Attributes.GetUserString('west_middle_road_role') == 'foundation']
    assert len(existing) <= 1
    if existing:
        k = existing[0].Id; assert sc.doc.Objects.Replace(k,d['bed'])
        assert sc.doc.Objects.ModifyAttributes(k,base_attr,True)
    else: k = sc.doc.Objects.AddBrep(d['bed'],base_attr)
    assert k != System.Guid.Empty
    d['bed_id'] = str(k)
    for k in [ROAD,d['bed_id']]:
        o = obj(k); a = o.Attributes.Duplicate(); a.CustomMeshingParameters = mp
        assert sc.doc.Objects.ModifyAttributes(o.Id,a,True)
    # Reapply names after custom render-mesh attributes have been committed.
    for k,name in [(ROAD,attr.Name),(d['bed_id'],base_attr.Name)]:
        o = obj(k); a = o.Attributes.Duplicate(); a.Name = name
        assert sc.doc.Objects.ModifyAttributes(o.Id,a,True)
    sc.doc.Views.Redraw()
    return {'road':ROAD,'foundation':d['bed_id']}

def verify():
    d = sc.sticky[TAG]
    before = d['before']; now = {str(o.Id):o for o in objects()}
    changed = [k for k,crc in before.items() if k in now and int(now[k].Geometry.DataCRC(0)) != crc]
    assert changed == [ROAD], changed
    assert not set(before).difference(now)
    assert set(now).difference(before) == set([d['bed_id']])
    for k in [ROAD,d['bed_id']]:
        assert now[k].Geometry.IsValid and now[k].Geometry.IsSolid
    # Dense edge checks compare the new XY perimeter against both untouched
    # original curves; geometry fitting, not merely a visual smoothness claim.
    surface = d['top'].Faces[0]; deviation = []
    for side,source in zip([surface.Domain(1).T0,surface.Domain(1).T1],EDGES):
        edge = surface.IsoCurve(0,side); original = obj(source).Geometry
        for i in range(1001):
            p = edge.PointAtNormalizedLength(i/1000.); p.Z = 35
            ok,t = original.ClosestPoint(p); assert ok
            deviation.append(p.DistanceTo(original.PointAt(t)))
    assert max(deviation) < .03, max(deviation)
    # Shoulder/foundation may touch the outer boundary but not the usable road.
    bed_mesh = G.Mesh()
    for m in G.Mesh.CreateFromBrep(d['bed'],G.MeshingParameters.FastRenderMesh): bed_mesh.Append(m)
    intrusion = 0
    for c,n,w in d['frames']:
        for frac in [-.49,0,.49]:
            p = c + n*(w*frac); p.Z += .01
            hits = G.Intersect.Intersection.MeshLine(bed_mesh,G.Line(p,p+G.Vector3d(0,0,7)))
            if hits and len(hits): intrusion += 1
    assert intrusion == 0
    return {'objects':len(now),'changed_originals':changed,
            'added':[d['bed_id']],'edge_deviation_max_m':max(deviation),
            'foundation_clearance_samples':len(d['frames'])*3,'intrusions':intrusion}
