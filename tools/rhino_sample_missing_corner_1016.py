# -*- coding: utf-8 -*-
"""Resample real neighboring top edges for the supplemental terrain only."""
from __future__ import division, unicode_literals
import Rhino,scriptcontext as sc,System,json,io,os,math
G=Rhino.Geometry
OUT='D:/Prism Route/prism-route/docs/concepts/terrain_seams_1016_v01'
IDS=['1d532d53-1e77-48a8-97d9-8eff168923b9',
     '9ed1bc59-e9fa-4024-8095-564d74c4c87c',
     '92714fcc-8762-4105-8ee9-d6796c31dc9f']

def sample():
    patch=sc.doc.Objects.FindId(System.Guid('adac435c-fe23-4fb1-98d3-e151d881ee4c'))
    backup=OUT+'/missing_corner_before_fairing.3dm'
    if not os.path.exists(backup):
        archive=Rhino.FileIO.File3dm();archive.Objects.AddBrep(patch.Geometry,patch.Attributes)
        if not archive.Write(backup,8):raise RuntimeError('Patch backup failed')
        archive.Dispose()
    archive=Rhino.FileIO.File3dm.Read(OUT+'/missing_corner_footprint.3dm')
    hole=next(iter(archive.Objects)).Geometry.DuplicateCurve();archive.Dispose()
    curves=[]
    for sid in IDS:
        face=sc.doc.Objects.FindId(System.Guid(sid)).Geometry.Faces[0]
        for edge in face.DuplicateFace(False).DuplicateNakedEdgeCurves(True,False):
            projected=edge.DuplicateCurve();projected.Transform(G.Transform.PlanarProjection(G.Plane.WorldXY))
            curves.append((sid,face,edge,projected))
    rows=[];n=int(math.ceil(hole.GetLength()/.25))
    for i in range(n):
        p=hole.PointAtNormalizedLength(i/n);choices=[]
        for sid,face,edge,projected in curves:
            ok,t=projected.ClosestPoint(p)
            if not ok:continue
            q=edge.PointAt(t);distance=p.DistanceTo(projected.PointAt(t))
            ok,u,v=face.ClosestPoint(q)
            if not ok:continue
            normal=face.NormalAt(u,v)
            if normal.Z<.05:continue
            choices.append((distance,q.Z,sid,[-normal.X/normal.Z,-normal.Y/normal.Z]))
        nearest=min(x[0]for x in choices)
        candidates=[x for x in choices if x[0]<=nearest+.015]
        d,z,sid,gradient=max(candidates,key=lambda x:x[1])
        rows.append({'xy':[p.X,p.Y],'height':z,'gradient':gradient,'source':sid,'plan_distance':d})
    with io.open(OUT+'/missing_corner_dense_boundary.json','w',encoding='utf-8')as h:h.write(unicode(json.dumps(rows)))
    print(json.dumps({'samples':n,'max_plan_distance':max(r['plan_distance']for r in rows),'backup':backup}))

if __name__=='__main__':sample()
