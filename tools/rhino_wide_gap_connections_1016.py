# -*- coding: utf-8 -*-
"""Native solid connections across the two user-identified wide terrain gaps.

Use export_west(), then the offline builder, then install('west').
The preceding seam repairs and all bank bodies remain preserved.
"""
from __future__ import division, unicode_literals
import Rhino,scriptcontext as sc,System,json,io,math
G=Rhino.Geometry
OUT='D:/Prism Route/prism-route/docs/concepts/terrain_seams_1016_v01'

def export_west():
    low=sc.doc.Objects.FindId(System.Guid('c1228167-d010-44ad-8775-757dd4984934')).Geometry
    high=sc.doc.Objects.FindId(System.Guid('f81baad1-a64c-48e0-a17f-f3a3c620659a')).Geometry
    c=low.Faces[0].DuplicateFace(False).DuplicateNakedEdgeCurves(True,False)[0].ToNurbsCurve()
    unique=sorted(set(float(k)for k in c.Knots))
    for a,b in zip(unique,unique[1:]):
        n=max(1,int(math.ceil(c.PointAt(a).DistanceTo(c.PointAt(b))/3)))
        for j in range(1,n):c.Knots.InsertKnot(a+(b-a)*j/n)
    hf=high.Faces[6];flat=hf.Loops[0].To3dCurve()
    flat.Transform(G.Transform.PlanarProjection(G.Plane.WorldXY))
    fs=hf.UnderlyingSurface().Duplicate();fs.Transform(G.Transform.PlanarProjection(G.Plane.WorldXY))
    rows=[];widths=[]
    for i in range(c.Points.Count):
        t=c.GrevilleParameter(i);p=c.PointAt(t)
        ok,ct=flat.ClosestPoint(G.Point3d(p.X,p.Y,0));q=flat.PointAt(ct)
        frac=c.Domain.NormalizedParameterAt(t);fade=max(0,math.sin(math.pi*frac))**.5
        d=G.Vector3d(q.X-p.X,q.Y-p.Y,0);widths.append(d.Length);d.Unitize()
        lp=G.Point3d(p.X-d.X*15*fade,p.Y-d.Y*15*fade,p.Z)
        hp=G.Point3d(q.X+d.X*7*fade,q.Y+d.Y*7*fade,0)
        ok,lu,lv=low.Faces[0].ClosestPoint(lp)
        lp=low.Faces[0].PointAt(lu,lv);ln=low.Faces[0].NormalAt(lu,lv)
        ok,hu,hv=fs.ClosestPoint(hp)
        if not ok:raise RuntimeError('Upper rail projection failed')
        upper=hf.PointAt(hu,hv);hn=hf.NormalAt(hu,hv)
        rows.append({'t':t,'low':[lp.X,lp.Y,lp.Z],'high':[upper.X,upper.Y,upper.Z],
                     'low_gradient':[-ln.X/ln.Z,-ln.Y/ln.Z],
                     'high_gradient':[-hn.X/hn.Z,-hn.Y/hn.Z]})
    data={'degree':c.Degree,'knots':[float(k)for k in c.Knots],
          'cp':[[c.Points[i].Location.X,c.Points[i].Location.Y,c.Points[i].Location.Z,c.Points[i].Weight]for i in range(c.Points.Count)],'samples':rows}
    with io.open(OUT+'/west_wide_gap_rails.json','w',encoding='utf-8')as h:h.write(unicode(json.dumps(data)))
    print(json.dumps({'controls':len(rows),'original_gap_min_m':min(widths),'original_gap_max_m':max(widths),'examples':rows[::max(1,len(rows)//6)]}))

def install(name):
    with io.open(OUT+'/'+name+'_wide_gap_controls.json','r',encoding='utf-8')as h:r=json.load(h)
    s=G.NurbsSurface.Create(3,False,r['degree_u']+1,6,r['nu'],6)
    for i,k in enumerate(r['knots_u']):s.KnotsU[i]=k
    for j,k in enumerate([0]*5+[1]*5):s.KnotsV[j]=k
    for i in range(r['nu']):
        for j in range(6):s.Points.SetPoint(i,j,G.Point3d(*r['cp'][i][j]))
    p='D:/Prism Route/prism-route/tools/rhino_landscape_1016_completion_v03.py';helper={'__file__':p}
    with io.open(p,'r',encoding='utf-8')as h:exec(compile(h.read(),p,'exec'),helper)
    solid=helper['make_solid'](s.ToBrep())
    source=sc.doc.Objects.FindId(System.Guid('c1228167-d010-44ad-8775-757dd4984934'))
    labels={'east':'06_东侧','west':'07_西侧','west_end':'08_西侧道路转角收口'}
    a=source.Attributes.Duplicate();a.Name=labels.get(name,name)+'宽槽_跨槽连续曲面实体'
    a.RemoveDisplayModeOverride();a.WireDensity=-1;a.SetUserString('recipe','prism_wide_gap_blend_1016_v01')
    a.SetUserString('gap_region',name)
    mp=G.MeshingParameters();mp.MaximumEdgeLength=2;mp.Tolerance=.005;mp.RefineGrid=True;mp.JaggedSeams=False
    a.CustomMeshingParameters=mp
    key=name+'_wide_gap_id';u=sc.doc.BeginUndoRecord(name+' 宽槽跨接实体')
    try:
        prior=sc.sticky.get(key)
        if prior:
            sc.doc.Objects.Replace(System.Guid(prior),solid);oid=System.Guid(prior)
        else:oid=sc.doc.Objects.AddBrep(solid,a)
        sc.sticky[key]=str(oid)
    finally:sc.doc.EndUndoRecord(u)
    report={'id':str(oid),'valid':solid.IsValid,'closed':solid.IsSolid,'orientation':str(solid.SolidOrientation)}
    with io.open(OUT+'/'+name+'_wide_gap_published.json','w',encoding='utf-8')as h:h.write(unicode(json.dumps(report,indent=2)))
    sc.doc.Views.Redraw();print(json.dumps(report))

def export_west_end():
    with io.open(OUT+'/west_wide_gap_rails.json','r',encoding='utf-8')as h:previous=json.load(h)
    end=previous['samples'][-1];start=G.Point3d(*end['high']);landing=G.Point3d(*end['low'])
    high=sc.doc.Objects.FindId(System.Guid('f81baad1-a64c-48e0-a17f-f3a3c620659a')).Geometry;hf=high.Faces[6]
    target=G.Point3d(869.36482303897549,570.22235040560315,start.Z)
    candidates=[]
    for e in hf.DuplicateFace(False).DuplicateNakedEdgeCurves(True,False):
        flat=e.DuplicateCurve();flat.Transform(G.Transform.PlanarProjection(G.Plane.WorldXY))
        ok,a=flat.ClosestPoint(G.Point3d(start.X,start.Y,0));ok,b=flat.ClosestPoint(G.Point3d(target.X,target.Y,0))
        score=flat.PointAt(a).DistanceTo(G.Point3d(start.X,start.Y,0))+flat.PointAt(b).DistanceTo(G.Point3d(target.X,target.Y,0))
        candidates.append((score,e,a,b))
    score,e,a,b=min(candidates,key=lambda r:r[0]);c=e.Trim(min(a,b),max(a,b)).ToNurbsCurve()
    if a>b:c.Reverse()
    for a,b in zip(sorted(set(float(k)for k in c.Knots)),sorted(set(float(k)for k in c.Knots))[1:]):
        n=max(1,int(math.ceil(c.PointAt(a).DistanceTo(c.PointAt(b))/3)))
        for j in range(1,n):c.Knots.InsertKnot(a+(b-a)*j/n)
    low_ids=['9ed1bc59-e9fa-4024-8095-564d74c4c87c','92714fcc-8762-4105-8ee9-d6796c31dc9f','c1228167-d010-44ad-8775-757dd4984934']
    lows=[]
    for sid in low_ids:
        o=sc.doc.Objects.FindId(System.Guid(sid));m=G.Mesh()
        for q in o.GetMeshes(G.MeshType.Render):m.Append(q)
        lows.append((o.Geometry,m))
    vector=landing-start;normal=G.Vector3d(-c.TangentAtStart.Y,c.TangentAtStart.X,0);normal.Unitize()
    sign=1 if normal*vector>0 else -1
    width0=math.hypot(vector.X,vector.Y);rows=[]
    for i in range(c.Points.Count):
        t=c.GrevilleParameter(i);upper=c.PointAt(t);frac=c.Domain.NormalizedParameterAt(t)
        tangent=c.TangentAt(t);n=G.Vector3d(-tangent.Y*sign,tangent.X*sign,0);n.Unitize()
        width=width0+(45-width0)*(frac*frac*(3-2*frac))
        xy=upper+n*width
        if i==0:xy=landing
        hits=[];ray=G.Ray3d(G.Point3d(xy.X,xy.Y,150),G.Vector3d(0,0,-1))
        for b,m in lows:
            distance=G.Intersect.Intersection.MeshRay(m,ray)
            if distance>=0:hits.append((150-distance,b))
        if not hits:
            choices=[]
            for body,m in lows:
                for loop in body.Faces[0].Loops:
                    edge=loop.To3dCurve();flat=edge.DuplicateCurve()
                    flat.Transform(G.Transform.PlanarProjection(G.Plane.WorldXY))
                    ok,et=flat.ClosestPoint(G.Point3d(xy.X,xy.Y,0));q=flat.PointAt(et)
                    choices.append((q.DistanceTo(G.Point3d(xy.X,xy.Y,0)),edge.PointAt(et),body))
            distance,p,body=min(choices,key=lambda r:r[0])
        else:
            z,body=max(hits,key=lambda r:r[0]);p=G.Point3d(xy.X,xy.Y,z)
        ok,u,v=body.Faces[0].ClosestPoint(p);p=body.Faces[0].PointAt(u,v);ln=body.Faces[0].NormalAt(u,v)
        ok,hu,hv=hf.ClosestPoint(upper);hn=hf.NormalAt(hu,hv)
        rows.append({'t':t,'low':[p.X,p.Y,p.Z],'high':[upper.X,upper.Y,upper.Z],
                     'low_gradient':[-ln.X/ln.Z,-ln.Y/ln.Z],'high_gradient':[-hn.X/hn.Z,-hn.Y/hn.Z]})
    data={'degree':c.Degree,'knots':[float(k)for k in c.Knots],
          'cp':[[c.Points[i].Location.X,c.Points[i].Location.Y,c.Points[i].Location.Z,c.Points[i].Weight]for i in range(c.Points.Count)],'samples':rows}
    with io.open(OUT+'/west_end_wide_gap_rails.json','w',encoding='utf-8')as h:h.write(unicode(json.dumps(data)))
    print(json.dumps({'controls':len(rows),'length':c.GetLength(),'start':rows[0],'end':rows[-1]}))
