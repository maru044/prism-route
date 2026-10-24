# -*- coding: utf-8 -*-
"""Add the missing terrain beside the retained western corner piece.

Footprint is the measured three-sided void in the union of existing land
footprints. This does not replace or deform the neighboring terrain objects.
"""
from __future__ import division, unicode_literals
import Rhino,scriptcontext as sc,System,json,io
G=Rhino.Geometry
OUT='D:/Prism Route/prism-route/docs/concepts/terrain_seams_1016_v01'
PARENTS=['1d532d53-1e77-48a8-97d9-8eff168923b9',
         '9ed1bc59-e9fa-4024-8095-564d74c4c87c',
         '92714fcc-8762-4105-8ee9-d6796c31dc9f']
TAG='prism_missing_terrain_corner_supplement_1016_v01'

def build(controls_file='missing_corner_refined_controls.json'):
    with io.open(OUT+'/missing_corner_grid.json','r',encoding='utf-8')as h:g=json.load(h)
    with io.open(OUT+'/'+controls_file,'r',encoding='utf-8')as h:r=json.load(h)
    s=G.NurbsSurface.Create(3,False,4,4,r['nu'],r['nv'])
    for i,k in enumerate(g['knots_u']):s.KnotsU[i]=k
    for j,k in enumerate(g['knots_v']):s.KnotsV[j]=k
    for i,x in enumerate(g['xs']):
        for j,y in enumerate(g['ys']):s.Points.SetPoint(i,j,G.Point3d(x,y,r['z'][i*r['nv']+j]))
    archive=Rhino.FileIO.File3dm.Read(OUT+'/missing_corner_footprint.3dm')
    hole=next(iter(archive.Objects)).Geometry.DuplicateCurve();archive.Dispose()
    missing_area=G.AreaMassProperties.Compute(hole).Area
    # Tiny overlap absorbs 3D-edge/planar-projection tolerance at the three
    # banks while preserving all neighbor geometry. The missing land itself
    # is 864m2; this is not another independently guessed outline.
    expanded=[]
    for signed in (-.08,.08):
        for c in hole.Offset(G.Plane.WorldXY,signed,.001,G.CurveOffsetCornerStyle.Sharp)or[]:
            props=G.AreaMassProperties.Compute(c)
            if c.IsClosed and props and props.Area>missing_area:expanded.append((props.Area,c))
    if expanded:hole=min(expanded,key=lambda r:r[0])[1]
    top=G.Brep.CreateTrimmedPlane(G.Plane.WorldXY,hole)
    # ChangeSurface rescales the UV trim curves to the new surface domain.
    # Both surfaces use world XY as UV, so retain their original coordinates
    # explicitly instead of allowing the hole to stretch to the grid bounds.
    trims=[(t.TrimIndex,t.DuplicateCurve())for t in top.Trims]
    si=top.AddSurface(s)
    if not top.Faces[0].ChangeSurface(si):raise RuntimeError('Surface map failed')
    for ti,c in trims:
        ci=top.Curves2D.Add(c)
        if not top.Trims[ti].SetTrimCurve(ci):raise RuntimeError('Trim restoration failed')
    top.Faces[0].RebuildEdges(.001,True,True);top.Compact()
    f=top.Faces[0];heights=[];normal_z=[]
    for i in range(1,90):
        for j in range(1,120):
            u=f.Domain(0).ParameterAt(i/90.);v=f.Domain(1).ParameterAt(j/120.)
            if f.IsPointOnFace(u,v)==G.PointFaceRelation.Exterior:continue
            heights.append(f.PointAt(u,v).Z);normal_z.append(f.NormalAt(u,v).Z)
    if min(heights)<=-6 or min(normal_z)<=0:raise RuntimeError('Folded/underground patch')
    p='D:/Prism Route/prism-route/tools/rhino_landscape_1016_completion_v03.py';helper={'__file__':p}
    with io.open(p,'r',encoding='utf-8')as h:exec(compile(h.read(),p,'exec'),helper)
    solid=helper['make_solid'](top)
    data={'solid':solid,'hole':hole,'crc':{sid:int(sc.doc.Objects.FindId(System.Guid(sid)).Geometry.DataCRC(0))for sid in PARENTS}}
    data['report']={'valid':solid.IsValid,'closed':solid.IsSolid,'outward':str(solid.SolidOrientation),
                    'area_m2':missing_area,'patch_footprint_area_m2':G.AreaMassProperties.Compute(hole).Area,
                    'bank_overlap_m':.08,'samples':len(heights),'controls_file':controls_file,
                    'sample_height_range_m':[min(heights),max(heights)],'min_sample_normal_z':min(normal_z)}
    sc.sticky[TAG]=data;print(json.dumps(data['report']))

def install():
    data=sc.sticky[TAG];a=sc.doc.Objects.FindId(System.Guid(PARENTS[1])).Attributes.Duplicate()
    a.Name='09_西侧三地形之间缺失区域_连续补全';a.RemoveDisplayModeOverride();a.WireDensity=-1
    a.SetUserString('recipe',TAG);a.SetUserString('adjacent_objects',','.join(PARENTS))
    a.SetUserString('purpose','Supplement actual 864m2 footprint void; retain all prior terrain')
    mp=G.MeshingParameters();mp.MaximumEdgeLength=1.5;mp.Tolerance=.005;mp.RefineGrid=True;mp.JaggedSeams=False
    a.CustomMeshingParameters=mp;undo=sc.doc.BeginUndoRecord('补全西侧864平方米缺失地形')
    try:
        if data.get('object_id'):raise RuntimeError('Already installed; do not duplicate')
        oid=sc.doc.Objects.AddBrep(data['solid'],a)
        if oid==System.Guid.Empty:raise RuntimeError('Add failed')
        data['object_id']=str(oid)
    finally:sc.doc.EndUndoRecord(undo)
    unchanged={sid:int(sc.doc.Objects.FindId(System.Guid(sid)).Geometry.DataCRC(0))==crc for sid,crc in data['crc'].items()}
    report=dict(data['report']);report.update({'id':str(oid),'parents_unchanged':unchanged})
    with io.open(OUT+'/missing_corner_published.json','w',encoding='utf-8')as h:h.write(unicode(json.dumps(report,indent=2)))
    sc.doc.Views.Redraw();print(json.dumps(report))
