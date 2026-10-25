# -*- coding: utf-8 -*-
"""Fill the confirmed gap between the south lagoon shoreline and low terrain.

Stage all geometry in memory. Preserve the existing portal excavation and join
the new floor to the original solid without coincident internal walls.
"""
from __future__ import division, unicode_literals
import Rhino, scriptcontext as sc, System, json, io
G = Rhino.Geometry
TERRAIN = '9ed1bc59-e9fa-4024-8095-564d74c4c87c'
TAG = 'hole_1026_confirmed'

def stage():
    d = sc.sticky[TAG]
    c = d['water']
    events = G.Intersect.Intersection.CurveCurve(c, G.LineCurve(
        G.Point3d(760,350,0), G.Point3d(760,550,0)), .0001, .0001)
    a = max([e for e in events if e.IsPoint], key=lambda e:e.PointA.Y)
    events = G.Intersect.Intersection.CurveCurve(c, G.LineCurve(
        G.Point3d(1000,500,0), G.Point3d(1200,500,0)), .0001, .0001)
    b = [e for e in events if e.IsPoint][0]
    arc = c.Trim(min(a.ParameterA,b.ParameterA),max(a.ParameterA,b.ParameterA))
    corner = G.Point3d(760,500,0)
    curves = G.Curve.JoinCurves([arc, G.LineCurve(arc.PointAtEnd,corner),
        G.LineCurve(corner,arc.PointAtStart)], .001)
    assert len(curves)==1 and curves[0].IsClosed
    foot = curves[0]
    if foot.ClosedCurveOrientation(G.Plane.WorldXY)==G.CurveOrientation.Clockwise:
        foot.Reverse()
    # Linear extensions preserve the original surface exactly inside its domain.
    # Smooth extrapolation of the Gaussian heightfield can overshoot badly.
    s = d['terrain'].Faces[9].UnderlyingSurface().Duplicate()
    for side in [G.IsoStatus.South,G.IsoStatus.North,G.IsoStatus.East,G.IsoStatus.West]:
        extended = s.Extend(side,100,False)
        if extended: s = extended
    prism = G.Extrusion.Create(foot,60,True).ToBrep()
    prism.Transform(G.Transform.Translation(0,0,-20))
    assert prism.GetBoundingBox(True).Max.Z > 30
    pieces = s.ToBrep().Split(prism,.001)
    assert pieces and len(pieces)>=2
    top = min(pieces,key=lambda p:abs(G.AreaMassProperties.Compute(p).Area-21423))
    assert 21000<G.AreaMassProperties.Compute(top).Area<22000
    rim = top.Loops[0].To3dCurve()
    bottom = rim.DuplicateCurve()
    bottom.Transform(G.Transform.PlanarProjection(G.Plane(
        G.Point3d(0,0,-7),G.Vector3d.ZAxis)))
    sides = G.Brep.CreateFromLoft([rim,bottom],G.Point3d.Unset,
        G.Point3d.Unset,G.LoftType.Normal,False)
    base = G.Brep.CreatePlanarBreps(bottom,.001)
    joined = G.Brep.JoinBreps([top,sides[0],base[0]],.002)
    assert joined and len(joined)==1 and joined[0].IsSolid
    patch = joined[0]
    patch.Faces.SplitKinkyFaces(.01,True)
    if patch.SolidOrientation==G.BrepSolidOrientation.Inward: patch.Flip()
    cut = G.Brep.CreateBooleanDifference(patch,
        sc.sticky['lagoon_1025_final']['portal_cutter'],.001)
    assert cut and len(cut)==1 and cut[0].IsValid and cut[0].IsSolid
    patch = cut[0]
    patch.Faces.SplitKinkyFaces(.01,True)
    d['exact_patch'] = patch
    d['exact_footprint'] = foot
    return {'patch_faces':patch.Faces.Count,'area_xy':G.AreaMassProperties.Compute(
        G.Brep.CreatePlanarBreps(foot,.001)[0]).Area}

def join():
    d = sc.sticky[TAG]
    # Both faces meet exactly at Y=500. Remove the interface walls first;
    # boolean union of nearly coincident closed solids can drop a component.
    source = d['terrain'].DuplicateBrep()
    wall = source.Faces[10].DuplicateFace(False)
    bb = wall.GetBoundingBox(True)
    assert abs(bb.Min.Y-500)<.001 and abs(bb.Max.Y-500)<.001
    source.Faces.RemoveAt(10)
    patch = d['exact_patch'].DuplicateBrep()
    walls = []
    for f in patch.Faces:
        bb = f.DuplicateFace(False).GetBoundingBox(True)
        if abs(bb.Min.Y-500)<.001 and abs(bb.Max.Y-500)<.001:
            walls.append(f.FaceIndex)
    assert walls, 'No shared wall on the new patch'
    for i in sorted(walls,reverse=True): patch.Faces.RemoveAt(i)
    joined = G.Brep.JoinBreps([source,patch],.002)
    d['joined_candidates'] = joined
    assert joined and len(joined)==1, 'Repair did not join into the existing object'
    final = joined[0]
    assert final.IsValid and final.IsSolid
    if final.SolidOrientation==G.BrepSolidOrientation.Inward: final.Flip()
    old_volume = G.VolumeMassProperties.Compute(d['terrain']).Volume
    new_volume = G.VolumeMassProperties.Compute(final).Volume
    assert old_volume+140000 < new_volume < old_volume+170000
    d['final'] = final
    return {'faces':final.Faces.Count,'valid':final.IsValid,'solid':final.IsSolid,
        'before_volume':old_volume,'after_volume':new_volume,
        'removed_interface_faces':len(walls)+1}

def publish():
    d = sc.sticky[TAG]
    assert 'final' in d and not d.get('published')
    serial = sc.doc.BeginUndoRecord('补齐南泻湖水面与桥下低地之间的缺口')
    try:
        assert sc.doc.Objects.Replace(System.Guid(TERRAIN),d['final'])
        o = sc.doc.Objects.FindId(System.Guid(TERRAIN))
        a = o.Attributes.Duplicate()
        a.SetUserString('shore_gap_repair','1026; joined NURBS floor; preserved portal')
        assert sc.doc.Objects.ModifyAttributes(o.Id,a,True)
        d['published'] = True
    finally:
        sc.doc.EndUndoRecord(serial)
        sc.doc.Views.Redraw()
    return {'replaced':TERRAIN,'added_objects':0,'hidden_backups':0}

def verify():
    d = sc.sticky[TAG]
    final = d['final']
    foot = d['exact_footprint']
    samples = 0
    misses = []
    for i in range(1,69):
        x = 760+5*i
        for j in range(1,35):
            y = 412+2.5*j
            if foot.Contains(G.Point3d(x,y,0),G.Plane.WorldXY,.001)!=G.PointContainment.Inside:
                continue
            ok,curves,points = G.Intersect.Intersection.CurveBrep(G.LineCurve(
                G.Point3d(x,y,20),G.Point3d(x,y,-9)),final,.001)
            samples += 1
            if not ok or not any(p.Z>-3 for p in points): misses.append([x,y])
    assert not misses, 'Uncovered floor samples: '+str(misses)
    # Re-run both previously authored exits against the staged replacement.
    previous = sc.sticky['lagoon_1025_final']['replace'][TERRAIN]
    try:
        sc.sticky['lagoon_1025_final']['replace'][TERRAIN] = final
        routes = sc.sticky['lagoon_1025_functions']['verify_routes']()
    finally:
        sc.sticky['lagoon_1025_final']['replace'][TERRAIN] = previous
    assert not routes['blockers']
    d['report'] = {'valid':final.IsValid,'solid':final.IsSolid,
        'naked_edges':sum(1 for e in final.Edges if e.Valence==G.EdgeAdjacency.Naked),
        'floor_samples':samples,'floor_misses':misses,'routes':routes,
        'filled_area_xy_m2':G.AreaMassProperties.Compute(
            G.Brep.CreatePlanarBreps(foot,.001)[0]).Area,
        'source_object':TERRAIN,'added_objects':0,'in_document_backups':0}
    assert d['report']['naked_edges']==0
    return d['report']
