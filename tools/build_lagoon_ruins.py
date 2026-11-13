# -*- coding: utf-8 -*-
"""Rhino: prepare(), apply(), export_source(), save_native(). Python: --package."""
from __future__ import division, unicode_literals

import io
import math
import os
import shutil

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FEATURE = 'north_lagoon_ruins'
CACHE = os.path.join(ROOT, '.current_map_build', FEATURE)
OUTPUT = os.path.join(ROOT, 'assets', 'world', FEATURE)
HELPER_PATH = os.path.join(ROOT, 'tools', 'build_sandbar_pavilion_1109.py')
BASE = {'__file__': HELPER_PATH, '__name__': 'lagoon_mesh_helpers'}
with io.open(HELPER_PATH, encoding='utf-8-sig') as source:
    exec(compile(source.read(), HELPER_PATH, 'exec'), BASE)
BASE.update(FEATURE=FEATURE, CACHE=CACHE, OUT=CACHE, _furniture=[])

SITES = {
    'InnerShore': ((930.3, 1216.2), (-.90, .44), 1.55, '01_内岸残墙'),
    'Sandbar': ((780.4, 1479.7), (-.72, .69), 1.50, '02_沙洲外侧残片'),
    'Foreground': ((1075.3, 1514.2), (-.72, .69), 1.65, '03_主弧肋与断台'),
}
WATER_ID = '3861e9e6-1993-4c9a-9445-ddd4e3b687a2'
BED_ID = 'a2b4d386-d01a-4559-a8f7-28e5c8b93563'
BRIDGE_DECK_ID = '63c66d8c-cc9e-4399-b804-6042fb2e4a40'
LAYER_PATH = '建筑::北泻湖白色遗迹'


def _cad(site, point):
    (x, y), (ux, uy), scale, _ = SITES[site]
    u, v, z = point
    factor = scale/math.hypot(ux, uy)
    return x + (ux*u + uy*v)*factor, y + (uy*u - ux*v)*factor, z


def _loft(site, sections):
    import Rhino.Geometry as G

    mesh = G.Mesh()
    sides = len(sections[0])
    for section in sections:
        for point in section:
            mesh.Vertices.Add(*_cad(site, point))
    for ring in range(len(sections)-1):
        for i in range(sides):
            a = ring*sides+i
            b = ring*sides+(i+1)%sides
            mesh.Faces.AddFace(a, b, b+sides)
            mesh.Faces.AddFace(a, b+sides, a+sides)
    end = (len(sections)-1)*sides
    for i in range(1, sides-1):
        mesh.Faces.AddFace(0, i+1, i)
        mesh.Faces.AddFace(end, end+i, end+i+1)
    mesh.UnifyNormals()
    if mesh.SolidOrientation() < 0:
        mesh.Flip(True, True, True)
    mesh.Normals.ComputeNormals()
    assert mesh.IsValid and mesh.IsClosed
    return mesh


def _slab(site, outline, top, base=-.86, bevel=.25, tilt=(0., 0.)):
    cx = sum(p[0] for p in outline)/len(outline)
    cy = sum(p[1] for p in outline)/len(outline)
    sections = []
    for offset, height in [(bevel, base), (0., top-bevel), (bevel, top)]:
        ring = []
        for x, y in outline:
            dx, dy = x-cx, y-cy
            s = 1. - offset/math.hypot(dx, dy)
            z = height + (dx*tilt[0]+dy*tilt[1] if height != base else 0.)
            ring.append((cx+dx*s, cy+dy*s, z))
        sections.append(ring)
    return _loft(site, sections)


def _wall(site, samples):
    sections = []
    for x, y, half_width, top in samples:
        sections.append([(x,y-half_width,-.86), (x,y+half_width,-.86),
                         (x,y+half_width*.92,top-.32), (x,y+half_width*.68,top),
                         (x,y-half_width*.68,top), (x,y-half_width*.92,top-.32)])
    return _loft(site, sections)


def _rib(site, samples, broken=True):
    sections = []
    for i, (x, y, z, half_width, half_depth) in enumerate(samples):
        p, q = samples[max(0, i-1)], samples[min(i+1, len(samples)-1)]
        dx, dy, dz = (q[j]-p[j] for j in range(3))
        plan = math.hypot(dx, dy)
        length = math.hypot(plan, dz)
        sx, sy = -dy/plan, dx/plan
        nx, ny, nz = -dx/plan*dz/length, -dy/plan*dz/length, plan/length
        ring = []
        for k, (w, h) in enumerate([(-.76,-1),(.76,-1),(1,-.71),(1,.71),
                                    (.76,1),(-.76,1),(-1,.71),(-1,-.71)]):
            chip = (0.,-.45,.3,-.7,.27,-.52,.18,-.2)[k] if broken and i == len(samples)-1 else 0.
            ring.append((x+sx*w*half_width+nx*h*half_depth+chip*dx/length,
                         y+sy*w*half_width+ny*h*half_depth+chip*dy/length,
                         z+nz*h*half_depth+chip*dz/length))
        sections.append(ring)
    return _loft(site, sections)


def _design():
    rows = []

    def add(site, name, mesh):
        rows.append(dict(site=site, name=site+'_'+name, mesh=mesh))

    site = 'Foreground'
    add(site, 'EntryApron', _slab(site, [(-55,0),(-50,-5),(-34,-8),(-31,3),(-44,8),(-53,6)], .54, tilt=(.018,.01)))
    add(site, 'DeckWest', _slab(site, [(-34,-11),(-15,-12),(-9,-8),(-11,5),(-22,10),(-31,7)], 1.12))
    add(site, 'DeckCenter', _slab(site, [(-12,-13),(12,-12),(20,-9),(19,2),(8,8),(-10,7)], .92, tilt=(-.008,.012)))
    add(site, 'DeckEast', _slab(site, [(21,-10),(34,-9),(43,-5),(45,0),(37,6),(22,5)], .54, tilt=(-.013,0)))
    add(site, 'FoundationWing', _slab(site, [(4,9),(19,7),(31,8),(29,11),(12,14),(6,14)], .18))
    add(site, 'MainRib', _rib(site, [(-34,16,-.81,2.9,1.06),(-32,13,1.15,2.87,1.07),
        (-29,9,3.55,2.77,1.03),(-25,4.5,5.65,2.6,.99),(-20,0,7.32,2.39,.93),
        (-14,-4.4,8.44,2.25,.86),(-8,-7.8,8.92,2.19,.80),(-3,-9.9,8.98,2.05,.76)]))
    add(site, 'MainRibFoot', _slab(site, [(-39,13),(-34,10),(-27,12),(-27,17),(-33,20),(-39,18)], .42))
    add(site, 'BrokenRib', _rib(site, [(47,17,-.84,2.17,.89),(45.5,14,.70,2.15,.87),
        (43,10.5,2.23,2.03,.80),(40.2,6.8,3.46,1.91,.76),(36.9,3.5,4.17,1.76,.72)]))
    add(site, 'DetachedSlab', _slab(site, [(50,3),(57,3),(63,5),(61,8),(54,9),(50,7)], .33, tilt=(.019,.01)))
    add(site, 'SeawardEdge', _wall(site, [(-18,-16,.88,.23),(-10,-18,1.12,.40),(2,-19,1.10,.47),(12,-18,.77,.32)]))

    site = 'InnerShore'
    add(site, 'OuterWall', _wall(site, [(-39,-1,1.1,.65),(-34,-5,1.7,1.5),(-27,-9,1.8,1.65),
        (-18,-12,1.7,1.68),(-7,-13,1.5,1.54),(2,-12,1.24,1.20),(6,-11,.81,.8)]))
    add(site, 'FoldedReturn', _wall(site, [(10,-10,1.25,1.05),(19,-8,1.55,1.73),
        (28,-4,1.65,1.73),(33,1,1.50,1.36),(34,6,.78,.56)]))
    add(site, 'InnerApron', _slab(site, [(-29,-5),(-16,-8),(2,-8),(8,-5),(4,3),(-16,6),(-28,4)], .38))
    add(site, 'RibFoot', _slab(site, [(0,9),(5,5),(14,4),(19,7),(17,13),(5,15)], .37))
    add(site, 'FallenRib', _rib(site, [(12,13,-.80,2.45,.94),(10,10,.8,2.30,.88),
        (6,6,2.42,2.13,.81),(1,2.3,3.56,1.92,.73),(-4,-.35,4.10,1.81,.67),(-9,-1.9,4.32,1.72,.62)]))
    add(site, 'DetachedCorner', _slab(site, [(-30,8),(-25,6),(-16,8),(-18,11),(-24,12),(-29,11)], .27, tilt=(.02,.01)))

    site = 'Sandbar'
    add(site, 'PierWest', _slab(site, [(-43,-5),(-33,-7),(-21,-6),(-19,-2),(-25,0),(-38,0)], .46, tilt=(.015,.012)))
    add(site, 'PierCenter', _slab(site, [(-16,-5),(0,-7),(8,-5),(9,-2),(1,0),(-15,0)], .30))
    add(site, 'PierEast', _slab(site, [(12,-6),(24,-6),(33,-4),(31,0),(21,1),(13,-1)], .53))
    add(site, 'Footings', _wall(site, [(1,7,.65,.18),(8,6,1.4,.48),(15,6,1.5,.47),(21,7,.82,.31)]))
    add(site, 'ShearedCanopy', _rib(site, [(17,8,-.80,2.8,.63),(19,5.5,.54,2.9,.66),
        (22,2.0,1.71,2.82,.65),(26,-1.1,2.27,2.68,.55),(31,-3.6,2.49,2.55,.48),(36,-4.8,2.33,2.02,.41)]))
    add(site, 'LoosePlate', _slab(site, [(-22,6),(-16,4),(-8,6),(-9,10),(-18,10)], .36, tilt=(.02,-.025)))
    add(site, 'SeawardCorner', _slab(site, [(37,1),(46,0),(49,3),(46,6),(38,6)], .23))
    return rows


def prepare():
    import Rhino.Geometry as G
    import scriptcontext as sc
    from System import Guid

    assert sc.doc.Path.replace('\\', '/').lower() == os.path.join(os.path.dirname(ROOT), 'map', 'map_current.3dm').replace('\\', '/').lower()
    BASE['_protected'] = BASE['_fingerprint']()
    rows = _design()
    water = sc.doc.Objects.FindId(Guid(WATER_ID)).Geometry
    bed = sc.doc.Objects.FindId(Guid(BED_ID)).Geometry
    deck = sc.doc.Objects.FindId(Guid(BRIDGE_DECK_ID)).Geometry.DuplicateMesh()
    for i, v in enumerate(deck.Vertices):
        deck.Vertices.SetVertex(i, v.X, v.Y, 0.)
    boundaries = water.DuplicateEdgeCurves(True)
    report = {}
    for site in SITES:
        pieces = [row['mesh'] for row in rows if row['site'] == site]
        samples = {(round(p.X, 2), round(p.Y, 2)) for mesh in pieces for p in mesh.Vertices}
        report[site] = {'samples': len(samples), 'max_height': max(m.GetBoundingBox(True).Max.Z for m in pieces),
                        'bridge_clearance': float('inf'), 'shore_clearance': float('inf'), 'bottom_depth': [1., 0.]}
        info = report[site]
        for x, y in samples:
            p = G.Point3d(x, y, 0.)
            ray = G.LineCurve(G.Point3d(x,y,15.), G.Point3d(x,y,-2.))
            found, _, hits = G.Intersect.Intersection.CurveBrep(ray, water, .01)
            assert found and hits and abs(hits[0].Z) < .01, 'Outside lagoon at %s %s' % (site,p)
            found, _, hits = G.Intersect.Intersection.CurveBrep(ray, bed, .01)
            assert found and hits, 'Missing lakebed at %s %s' % (site,p)
            depth = -max(v.Z for v in hits)
            assert .06 < depth < .8, 'Shoreline or unexpected lakebed at %s %s' % (site,p)
            info['bottom_depth'] = [min(info['bottom_depth'][0],depth), max(info['bottom_depth'][1],depth)]
            info['bridge_clearance'] = min(info['bridge_clearance'], p.DistanceTo(deck.ClosestPoint(p)))
            for edge in boundaries:
                found, t = edge.ClosestPoint(p)
                if found:
                    info['shore_clearance'] = min(info['shore_clearance'], p.DistanceTo(edge.PointAt(t)))
        assert info['bridge_clearance'] > 25. and info['shore_clearance'] > 15., (site,info)
    BASE['_staged'] = rows
    return report


def apply():
    import Rhino as R
    import scriptcontext as sc
    from System import Guid
    from System.Drawing import Color

    assert BASE['_fingerprint']() == BASE['_protected']
    layer_table = sc.doc.Layers
    root_index = layer_table.FindByFullPath(LAYER_PATH, -1)
    if root_index < 0:
        root = R.DocObjects.Layer()
        root.Name = LAYER_PATH.split('::')[-1]
        root.ParentLayerId = layer_table[layer_table.FindByFullPath('建筑', -1)].Id
        root_index = layer_table.Add(root)
    color = Color.FromArgb(235, 230, 218)
    material_index = next((i for i, m in enumerate(sc.doc.Materials) if m.Name == FEATURE), -1)
    if material_index < 0:
        material = R.DocObjects.Material()
        material.Name = FEATURE
        material.DiffuseColor = color
        material_index = sc.doc.Materials.Add(material)
    layers = {}
    for site, (_, _, _, name) in SITES.items():
        index = layer_table.FindByFullPath(LAYER_PATH+'::'+name, -1)
        if index < 0:
            layer = R.DocObjects.Layer()
            layer.Name = name
            layer.ParentLayerId = layer_table[root_index].Id
            layer.Color = color
            layer.RenderMaterialIndex = material_index
            index = layer_table.Add(layer)
        layers[site] = index

    previous = [o for o in BASE['_all_objects']() if o.Attributes.GetUserString('pr_feature') == FEATURE]
    retained = set()
    created = []
    try:
        for row in BASE['_staged']:
            existing = next((o for o in previous if o.Attributes.GetUserString('component_id') == row['name']
                             and o.Geometry.DataCRC(0) == row['mesh'].DataCRC(0)), None)
            if existing is not None:
                oid = existing.Id
            else:
                attrs = R.DocObjects.ObjectAttributes()
                attrs.Name = 'LagoonRuins_'+row['name']
                attrs.LayerIndex = layers[row['site']]
                attrs.MaterialSource = R.DocObjects.ObjectMaterialSource.MaterialFromLayer
                attrs.SetUserString('pr_feature', FEATURE)
                attrs.SetUserString('component_id', row['name'])
                oid = sc.doc.Objects.AddMesh(row['mesh'], attrs)
                assert oid != Guid.Empty, row['name']
                created.append(oid)
            retained.add(oid)
            row['id'] = str(oid)
    except Exception:
        for oid in created:
            sc.doc.Objects.Delete(oid, True)
        raise
    for old in previous:
        if old.Id not in retained:
            assert sc.doc.Objects.Delete(old, True, True)
    assert BASE['_fingerprint']() == BASE['_protected']
    sc.doc.Views.Redraw()
    return {'created': len(created), 'reused': len(retained)-len(created), 'total': len(retained)}


def export_source():
    import Rhino.Geometry as G
    import scriptcontext as sc
    from System import Guid

    assert BASE['_fingerprint']() == BASE['_protected']
    objects = []
    for site in SITES:
        batch = G.Mesh()
        for row in BASE['_staged']:
            if row['site'] == site:
                mesh = sc.doc.Objects.FindId(Guid(row['id'])).Geometry.DuplicateMesh()
                mesh.Unweld(.50, True)
                mesh.Normals.ComputeNormals()
                batch.Append(mesh)
        points = [[float(p.X), float(p.Y), float(p.Z)] for p in batch.Vertices]
        objects.append(dict(id=site, name=SITES[site][3],
            vertices=points, normals=[[float(n.X), float(n.Y), float(n.Z)] for n in batch.Normals],
            indices=[int(i) for f in batch.Faces for i in (f.A,f.B,f.C)], uvs=[p[:2] for p in points]))
    BASE['_dump'](os.path.join(CACHE, 'source.json'), dict(feature=FEATURE, objects=objects))
    return {'meshes': len(objects), 'triangles': sum(len(row['indices'])//3 for row in objects)}


def save_native():
    return BASE['save_native']()


def package():
    BASE['package']('ruins.glb', 'Prism Route / North Lagoon Ruins')
    if not os.path.isdir(OUTPUT):
        os.makedirs(OUTPUT)
    shutil.copyfile(os.path.join(CACHE, 'ruins.glb'), os.path.join(OUTPUT, 'ruins.glb'))


if __name__ == '__main__':
    import argparse
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--package', action='store_true', required=True)
    parser.parse_args()
    package()
