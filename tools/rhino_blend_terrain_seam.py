# -*- coding: utf-8 -*-
"""Run in Rhino Python: blend the named terrain copies, then validate and publish.

Requires RhinoCommon and the active map document. All geometry is calculated in
memory before an undoable document change. The two original objects are retained.
"""

import json
import math
import Rhino
import scriptcontext as sc
from System.Collections.Generic import List
from System.Drawing import Color


def named_brep(name):
    settings = Rhino.DocObjects.ObjectEnumeratorSettings()
    settings.HiddenObjects = True
    settings.LockedObjects = True
    matches = [o for o in sc.doc.Objects.GetObjectList(settings)
               if o.Attributes.Name == name and isinstance(o.Geometry, Rhino.Geometry.Brep)]
    if len(matches) != 1:
        raise ValueError('Expected exactly one Brep named ' + name)
    return matches[0]


def planar_curve(edge):
    curve = edge.DuplicateCurve()
    curve.Transform(Rhino.Geometry.Transform.PlanarProjection(Rhino.Geometry.Plane.WorldXY))
    return curve


def boundary_metrics(blend, targets, faces, count=1001):
    metrics = []
    for index, target, face in zip([0, 2], targets, faces):
        distances, angles = [], []
        for i in range(count):
            p = blend.Edges[index].PointAtNormalizedLength(float(i) / (count - 1))
            ok, t = target.ClosestPoint(p)
            if not ok:
                raise ValueError('Boundary projection failed')
            q = target.PointAt(t)
            distances.append(p.DistanceTo(q))
            ok, u, v = face.ClosestPoint(q)
            ok2, s, t = blend.Faces[0].ClosestPoint(p)
            if not ok or not ok2:
                raise ValueError('Normal evaluation failed')
            angle = math.degrees(Rhino.Geometry.Vector3d.VectorAngle(
                face.NormalAt(u, v), blend.Faces[0].NormalAt(s, t)))
            angles.append(min(angle, 180.0 - angle))
        metrics.append({'edge': index, 'distance_max_m': max(distances),
                        'normal_angle_max_deg': max(angles)})
    return metrics


def fit_boundary_rows(surface, targets, refine=False):
    """Fit Greville positions while preserving cross-boundary tangent vectors."""
    ns = surface.Duplicate().ToNurbsSurface()
    if refine:
        knots = sorted(set(list(ns.KnotsU)))
        for a, b in zip(knots[:-1], knots[1:]):
            if b - a > 1e-8:
                ns.KnotsU.InsertKnot((a + b) / 2.0)
    for row, adjacent, v, target in [
        (0, 1, ns.Domain(1).T0, targets[0]),
        (ns.Points.CountV - 1, ns.Points.CountV - 2, ns.Domain(1).T1, targets[1]),
    ]:
        curve = ns.IsoCurve(0, v).ToNurbsCurve()
        points = List[Rhino.Geometry.Point3d]()
        for i in range(curve.Points.Count):
            p = curve.PointAt(curve.GrevilleParameter(i))
            ok, t = target.ClosestPoint(p)
            if not ok:
                raise ValueError('Greville projection failed')
            points.Add(target.PointAt(t))
        if not curve.SetGrevillePoints(points):
            raise ValueError('Greville interpolation failed')
        for i in range(ns.Points.CountU):
            old = ns.Points.GetControlPoint(i, row).Location
            new = curve.Points[i].Location
            delta = new - old
            ns.Points.SetControlPoint(i, row, Rhino.Geometry.ControlPoint(new))
            adjacent_point = ns.Points.GetControlPoint(i, adjacent).Location
            ns.Points.SetControlPoint(i, adjacent,
                                      Rhino.Geometry.ControlPoint(adjacent_point + delta))
    return ns


def build_blend(low, high, low_edge_index=3, high_edge_index=3, width=40.0):
    tolerance = sc.doc.ModelAbsoluteTolerance
    low, high = low.DuplicateBrep(), high.DuplicateBrep()
    low_edge, high_edge = low.Edges[low_edge_index], high.Edges[high_edge_index]
    low_xy, high_xy = planar_curve(low_edge), planar_curve(high_edge)
    parameters = []
    for p in [low_edge.PointAtStart, low_edge.PointAtEnd]:
        ok, t = high_xy.ClosestPoint(Rhino.Geometry.Point3d(p.X, p.Y, 0))
        if not ok:
            raise ValueError('Corresponding edge interval not found')
        parameters.append(t)
    interval = Rhino.Geometry.Interval(min(parameters), max(parameters))

    offset = None
    for distance in [width, -width]:
        curves = low_xy.Offset(Rhino.Geometry.Plane.WorldXY, distance, tolerance,
                               Rhino.Geometry.CurveOffsetCornerStyle.Smooth)
        if not curves or len(curves) != 1:
            continue
        p = curves[0].PointAtNormalizedLength(0.5)
        ok, u, v = low.Faces[0].ClosestPoint(p)
        if ok and low.Faces[0].IsPointOnFace(u, v) == Rhino.Geometry.PointFaceRelation.Interior:
            offset = curves[0]
            break
    if offset is None:
        raise ValueError('Inward transition boundary not found')
    cutter_curve = offset.Extend(Rhino.Geometry.CurveEnd.Both, 300.0,
                                Rhino.Geometry.CurveExtensionStyle.Smooth)
    cutter_curve.Translate(0, 0, -300)
    cutter = Rhino.Geometry.Surface.CreateExtrusion(
        cutter_curve, Rhino.Geometry.Vector3d(0, 0, 700)).ToBrep()
    pieces = low.Split(cutter, tolerance)
    if len(pieces) != 2 or not all(p.IsValid for p in pieces):
        raise ValueError('Expected two valid grassland split pieces')
    kept = max(pieces, key=lambda p: Rhino.Geometry.AreaMassProperties.Compute(p).Area)

    def offset_error(edge):
        curve = planar_curve(edge)
        total = 0.0
        for i in range(11):
            p = curve.PointAtNormalizedLength(i / 10.0)
            ok, t = offset.ClosestPoint(p)
            total += p.DistanceTo(offset.PointAt(t))
        return total
    cut_index = min(range(kept.Edges.Count), key=lambda i: offset_error(kept.Edges[i]))
    split_parameters = List[float]()
    split_parameters.Add(interval.T0)
    split_parameters.Add(interval.T1)
    high.Edges.SplitEdgeAtParameters(high_edge_index, split_parameters)
    high.Compact()
    # SplitEdge leaves new vertex tolerances unset. RebuildEdges also refits the
    # existing approximate 3D edges to the unchanged underlying surfaces.
    for brep in [kept, high]:
        for face in brep.Faces:
            face.RebuildEdges(0.00001, True, True)
    if not kept.IsValid or not high.IsValid:
        raise ValueError('Invalid split geometry')
    candidates = [e for e in high.Edges if abs(e.Domain.T0 - interval.T0) < 1e-6
                  and abs(e.Domain.T1 - interval.T1) < 1e-6]
    if len(candidates) != 1:
        raise ValueError('Corresponding split edge not found')
    low_edge, high_edge = kept.Edges[cut_index], candidates[0]
    reverse_high = low_edge.PointAtStart.DistanceTo(high_edge.PointAtEnd) < \
        low_edge.PointAtStart.DistanceTo(high_edge.PointAtStart)
    try:
        sc.doc.ModelAbsoluteTolerance = min(tolerance, 0.0001)
        blends = Rhino.Geometry.Brep.CreateBlendSurface(
            kept.Faces[0], low_edge, low_edge.Domain, False,
            Rhino.Geometry.BlendContinuity.Tangency,
            high.Faces[0], high_edge, high_edge.Domain, reverse_high,
            Rhino.Geometry.BlendContinuity.Tangency)
    finally:
        sc.doc.ModelAbsoluteTolerance = tolerance
    if not blends or len(blends) != 1:
        raise ValueError('Expected one tangent transition surface')
    surface = blends[0].Faces[0].ToNurbsSurface()
    for attempt in range(5):
        surface = fit_boundary_rows(surface, [low_edge, high_edge], attempt > 0)
        blend = surface.ToBrep()
        metrics = boundary_metrics(blend, [low_edge, high_edge],
                                   [kept.Faces[0], high.Faces[0]])
        joined = Rhino.Geometry.Brep.JoinBreps([kept, high, blend], tolerance)
        if (len(joined) == 1 and joined[0].IsValid and
                max(m['distance_max_m'] for m in metrics) <= tolerance and
                max(m['normal_angle_max_deg'] for m in metrics) < 0.1):
            interior = sum(e.Valence == Rhino.Geometry.EdgeAdjacency.Interior
                           for e in joined[0].Edges)
            if interior != 2:
                raise ValueError('Expected two joined interior seams')
            return joined[0], {'transition_width_m': width, 'matched_blend': metrics,
                               'joined_count': 1, 'faces': joined[0].Faces.Count,
                               'interior_edges': interior,
                               'document_tolerance_m': tolerance,
                               'control_points': [surface.Points.CountU, surface.Points.CountV]}
    raise ValueError('Transition did not reach distance/angle tolerances; no result published')


def publish(low_obj, high_obj, geometry, report):
    backup_name, result_name = u'地形接缝_原始副本', u'地形接缝_混接结果'
    if sc.doc.Layers.FindByFullPath(result_name, -1) >= 0:
        raise ValueError('Review layer already exists; rename it before another run')
    undo = sc.doc.BeginUndoRecord('Terrain seam blended duplicate')
    try:
        backup_layer = Rhino.DocObjects.Layer()
        backup_layer.Name, backup_layer.IsVisible = backup_name, False
        backup_index = sc.doc.Layers.Add(backup_layer)
        for obj in [low_obj, high_obj]:
            attributes = obj.Attributes.Duplicate()
            attributes.LayerIndex = backup_index
            attributes.Name += u'_原始副本'
            attributes.Mode = Rhino.DocObjects.ObjectMode.Normal
            attributes.SetUserString('description', 'Original terrain copy before blending')
            sc.doc.Objects.AddBrep(obj.Geometry.DuplicateBrep(), attributes)
        result_layer = Rhino.DocObjects.Layer()
        result_layer.Name, result_layer.Color = result_name, Color.FromArgb(171, 193, 154)
        attributes = Rhino.DocObjects.ObjectAttributes()
        attributes.LayerIndex = sc.doc.Layers.Add(result_layer)
        attributes.Name = u'海平面草地_中层丘陵_混接副本'
        attributes.SetUserString('description', 'Terrain review copy with tangent transition')
        attributes.SetUserString('seam_report', json.dumps(report))
        result_id = sc.doc.Objects.AddBrep(geometry, attributes)
        sc.doc.Objects.Hide(low_obj.Id, True)
        sc.doc.Objects.Hide(high_obj.Id, True)
        sc.doc.Objects.UnselectAll()
    finally:
        sc.doc.EndUndoRecord(undo)
    sc.doc.Views.Redraw()
    return result_id


def main():
    if sc.doc.ModelUnitSystem != Rhino.UnitSystem.Meters:
        raise ValueError('This workflow expects a document in meters')
    low, high = named_brep(u'海平面草地'), named_brep(u'中层丘陵与平面')
    result, report = build_blend(low.Geometry, high.Geometry)
    result_id = publish(low, high, result, report)
    report['result_id'] = str(result_id)
    print(json.dumps(report, indent=2))


if __name__ == '__main__':
    main()
