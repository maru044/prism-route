# -*- coding: utf-8 -*-
"""Local deformation of the selected waterfront terrain, inside Rhino.

Requires the measured shoulder profile in sc.sticky. Keeps the object ID and
closed BRep; widens its edge into the existing bank instead of adding another
overlapping surface. Coons patches retain the three original inner boundaries.
Requires the original BRep and measured profile in sc.sticky. prepare() makes
the final lightweight geometry; commit() replaces the original object.
"""
from __future__ import division
import Rhino, scriptcontext as sc, System, math, json, io
G=Rhino.Geometry
TAG='lakeside_walk_seam_1102'

def smooth(x):
    x=max(0.,min(1.,x));return x*x*(3.-2.*x)

class BankMorph(G.SpaceMorph):
    def __init__(self, state):
        self.guide=state['guide'];self.profile=state['profile']
        self.PreserveStructure=False;self.QuickPreview=False;self.Tolerance=.008

    def MorphPoint(self,p):
        ok,t=self.guide.ClosestPoint(G.Point3d(p.X,p.Y,0))
        if not ok:return p
        q=self.guide.PointAt(t)
        distance=math.hypot(p.X-q.X,p.Y-q.Y)
        if distance>=35.:return p
        i=min(int(t),len(self.profile)-2);a=max(0.,min(1.,t-i))
        r0=self.profile[i];r1=self.profile[i+1]
        n=[r0['n'][k]*(1-a)+r1['n'][k]*a for k in range(2)]
        z=r0['p'][2]*(1-a)+r1['p'][2]*a
        host=r0['host_z']*(1-a)+r1['host_z']*a
        along=min(t,len(self.profile)-1-t)*5.
        weight=(1.-smooth(distance/35.))*smooth(along/20.)
        # Full lateral overlap at the exposed side; no vertical face remains
        # at the old perimeter. The outer edge is buried 15 cm in its host.
        return G.Point3d(p.X-12.*n[0]*weight,p.Y-12.*n[1]*weight,
                         p.Z+(host-z-.15)*weight*smooth((p.Z+7.)/5.))

def prepare():
    state=sc.sticky[TAG]
    source=state['original'];deform=BankMorph(state)
    centers=state['end_refinement']['centers']
    press=EndPress(centers)
    anchor=source.Edges[0].PointAtStart
    curves={}
    for ei in [0,12,13,14]:
        edge=source.Edges[ei]
        count=max(12,int(math.ceil(edge.GetLength()/2.5)))
        points=[]
        for k in range(count+1):
            original=edge.PointAtNormalizedLength(float(k)/count)
            p=press.MorphPoint(deform.MorphPoint(original))
            fade=smooth(math.hypot(original.X-anchor.X,original.Y-anchor.Y)/15.)
            points.append(original+(p-original)*fade)
        curves[ei]=G.Curve.CreateInterpolatedCurve(points,3)
    for ei in [1,2,10]:curves[ei]=source.Edges[ei].DuplicateCurve()
    tops=[G.Brep.CreateEdgeSurface([curves[i] for i in indices])
          for indices in [[0,13,2,10],[14,12,1,13]]]
    assert all(top and top.IsValid for top in tops)
    joined=G.Brep.JoinBreps(tops,.02);assert len(joined)==1
    top=joined[0];parts=[top];bottoms=[]
    projection=G.Transform.PlanarProjection(G.Plane(G.Point3d(0,0,-7),G.Vector3d.ZAxis))
    for edge in top.DuplicateNakedEdgeCurves(True,False):
        bottom=edge.DuplicateCurve();assert bottom.Transform(projection)
        bottoms.append(bottom)
        loft=G.Brep.CreateFromLoft([edge,bottom],G.Point3d.Unset,
                                  G.Point3d.Unset,G.LoftType.Straight,False)
        assert loft and len(loft)==1;parts.append(loft[0])
    caps=G.Brep.CreatePlanarBreps(bottoms,.02);assert caps;parts.extend(caps)
    joined=G.Brep.JoinBreps(parts,.02);assert len(joined)==1
    candidate=joined[0];candidate.Compact()
    if candidate.SolidOrientation==G.BrepSolidOrientation.Inward:candidate.Flip()
    assert candidate.IsValid and candidate.IsSolid
    state['candidate']=candidate
    return {'valid':candidate.IsValid,'solid':candidate.IsSolid,
            'faces':candidate.Faces.Count,'memory_bytes':int(candidate.MemoryEstimate())}

class EndPress(G.SpaceMorph):
    def __init__(self, centers):
        self.centers=centers;self.PreserveStructure=True

    def MorphPoint(self,p):
        dz=0.
        for x,y,h,r in self.centers:
            dd=((p.X-x)**2+(p.Y-y)**2)/(r*r)
            if dd<4.:
                dz-=h*math.exp(-dd*1.5)*(1.-smooth(dd/4.))
        return G.Point3d(p.X,p.Y,p.Z+dz*smooth((p.Z+7.)/5.))

def commit():
    state=sc.sticky[TAG]
    assert 'candidate' in state
    original=sc.doc.Objects.FindId(System.Guid(state['id']))
    assert original and original.Geometry.DataCRC(0)==state['original'].DataCRC(0)
    record=sc.doc.BeginUndoRecord('Smooth waterfront field perimeter')
    try:assert sc.doc.Objects.Replace(original.Id,state['candidate'])
    finally:sc.doc.EndUndoRecord(record)
    sc.doc.Objects.UnselectAll();sc.doc.Views.Redraw()
    return {'replaced_id':state['id']}
