# -*- coding: utf-8 -*-
"""Complete the photographed T2 entrance; preserve the user's SubD patch.

Run in the live Rhino document. build() prepares two masses, publish() adds or
updates them, verify() checks traffic clearance and preservation. No snapshots
or extra scene files are produced. The route comes from the actual road face.
"""
from __future__ import unicode_literals, division
import Rhino, scriptcontext as sc, System, math
G=Rhino.Geometry
ROAD='47800a9c-ca72-4dc5-8203-d6d5d91d29a9'
PATCH='dde3c54b-940e-47f6-ae35-5b0c707872e4'
TAG='left_entry_t2_1018'
FRONT=1863.0
BACK=1668.0

def obj(s):return sc.doc.Objects.FindId(System.Guid(s))
def smooth(t):
    t=max(0,min(1,t));return t*t*t*(10+t*(-15+6*t))
def frame(s):
    c=sc.sticky[TAG]['route'];ok,t=c.LengthParameter(s);assert ok
    p=c.PointAt(t);a=c.TangentAt(t);a.Z=0;a.Unitize()
    return p,a,G.Vector3d(-a.Y,a.X,0)
def point(s,y,z):
    p,a,n=frame(s);return p+n*y+G.Vector3d.ZAxis*(z-p.Z)
def dims(s):
    flare=smooth((s-1798)/65)
    return 26.0+7*flare,10.1+2.7*(1-smooth((s-BACK)/44)),55+15*flare

def build():
    d=sc.sticky.get(TAG,{})
    if 'before'not in d:
        es=Rhino.DocObjects.ObjectEnumeratorSettings();es.HiddenObjects=True;es.LockedObjects=True;es.NormalObjects=True
        d['before']={str(o.Id):int(o.Geometry.DataCRC(0))for o in sc.doc.Objects.GetObjectList(es)}
        d['patch_crc']=int(obj(PATCH).Geometry.DataCRC(0))
    face=obj(ROAD).Geometry.Faces[0];c=face.IsoCurve(1,face.Domain(0).Mid);c.Reverse();d['route']=c;sc.sticky[TAG]=d
    N,M,K=64,40,5
    def at(t,j,k):
        theta=math.pi*j/M;f=k/K;side=math.cos(theta)
        # Feet lead the crown. A single rolled mouth replaces separate fins.
        leading=FRONT+19*abs(side)**1.55*(1+.10*side)+1.2*math.sin(math.pi*f)
        s=leading+(BACK-leading)*t
        p,a,n=frame(s);half,height,foot=dims(min(FRONT,s))
        yi=-half*side;zi=p.Z-.85+(height+.85)*math.sin(theta)**.60
        ground=-4.2
        yo=-foot*side;zo=ground+(p.Z+height+1.65-ground)*math.sin(theta)**.80
        return point(s,yi*(1-f)+yo*f,zi*(1-f)+zo*f)
    coords=[(j,0)for j in range(M+1)]+[(M,k)for k in range(1,K)]+[(j,K)for j in reversed(range(M+1))]+[(0,k)for k in reversed(range(1,K))]
    m=G.Mesh();lookup={}
    for i in range(N+1):
        for j,k in coords:lookup[i,j,k]=m.Vertices.Add(at(i/N,j,k))
    for i in range(N):
        for z in range(len(coords)):
            j,k=coords[z];jj,kk=coords[(z+1)%len(coords)]
            m.Faces.AddFace(lookup[i,j,k],lookup[i,jj,kk],lookup[i+1,jj,kk],lookup[i+1,j,k])
    for i in [0,N]:
        for j in range(1,M):
            for k in range(1,K):lookup[i,j,k]=m.Vertices.Add(at(i/N,j,k))
        for j in range(M):
            for k in range(K):m.Faces.AddFace(lookup[i,j,k],lookup[i,j+1,k],lookup[i,j+1,k+1],lookup[i,j,k+1])
    m.UnifyNormals();m.Weld(math.pi);m.Normals.ComputeNormals();m.Compact()
    assert m.IsValid and m.IsClosed
    sub=G.SubD.CreateFromMesh(m,G.SubDCreationOptions.Smooth);assert sub and sub.IsValid
    d['body']=sub
    # An embankment supports the rising road and closes the void below it.
    # The leading width grows gradually instead of exposing a blunt high cap.
    sections=[]
    for i in range(89):
        s=BACK+(1938-BACK)*i/88;p,a,n=frame(s);half,height,foot=dims(min(FRONT,s))
        lead=smooth((1938-s)/75);width=.65+(half+1.5-.65)*lead
        outer=width+8+26*lead;top=p.Z-.22;ground=-2.0
        yz=[(-outer,ground),(-outer-1,ground+.7),(-width-8,top*.62),(-width-2,top-.6),(-width,top),(0,top),(width,top),(width+2,top-.6),(width+8,top*.62),(outer+1,ground+.7),(outer,ground),(0,ground)]
        sections.append(G.NurbsCurve.Create(True,3,[point(s,y,z)for y,z in yz]))
    out=G.Brep.CreateFromLoft(sections,G.Point3d.Unset,G.Point3d.Unset,G.LoftType.Normal,False)
    assert out and len(out)==1
    b=out[0].CapPlanarHoles(.005);assert b and b.IsValid and b.IsSolid
    if b.SolidOrientation==G.BrepSolidOrientation.Inward:b.Flip()
    d['base']=b
    print('Prepared the T2 entrance: one continuous mouth/interior and one grounded embankment.')

def publish():
    d=sc.sticky[TAG];li=sc.doc.Layers.FindByFullPath('交通::隧道',-1);assert li>=0
    mi=next(i for i,m in enumerate(sc.doc.Materials)if m.Name=='隧道_暖白建筑复合面_PBR_非金属')
    d.setdefault('ids',{})
    undo=sc.doc.BeginUndoRecord('T2左侧入口_连续收口及落地')
    try:
        for role,name in [('body','左侧入口_连续洞唇拱腹与实心拱肩'),('base','左侧入口_渐入落地坡脚与路基')]:
            if role in d['ids']:
                assert sc.doc.Objects.Replace(System.Guid(d['ids'][role]),d[role]);continue
            a=Rhino.DocObjects.ObjectAttributes();a.Name=name;a.LayerIndex=li
            a.MaterialIndex=mi;a.MaterialSource=Rhino.DocObjects.ObjectMaterialSource.MaterialFromObject
            a.SetUserString('recipe',TAG);a.SetUserString('left_entry_role',role)
            oid=sc.doc.Objects.AddSubD(d[role],a)if role=='body'else sc.doc.Objects.AddBrep(d[role],a)
            assert oid!=System.Guid.Empty;d['ids'][role]=str(oid)
    finally:sc.doc.EndUndoRecord(undo)
    sc.doc.Views.Redraw()

def mesh(g):
    if isinstance(g,G.SubD):return G.Mesh.CreateFromSubD(g,2)
    m=G.Mesh();mp=G.MeshingParameters.FastRenderMesh
    for p in G.Mesh.CreateFromBrep(g,mp):m.Append(p)
    m.Weld(math.pi);m.UnifyNormals();return m

def clear_old_intrusions():
    """Only the two pre-existing solids found intersecting the traffic path."""
    d=sc.sticky[TAG];sections=[]
    for i in range(21):
        s=1660+150*i/20;p,a,n=frame(s);half,h,foot=dims(s);yz=[]
        for j in range(37):
            theta=math.pi*j/36;yz.append((-half*math.cos(theta),p.Z-.9+(h+.65)*math.sin(theta)**.60))
        yz.extend([(half,p.Z-2),(0,p.Z-2),(-half,p.Z-2)])
        sections.append(G.NurbsCurve.Create(True,3,[point(s,y,z)for y,z in yz]))
    cutter=G.Brep.CreateFromLoft(sections,G.Point3d.Unset,G.Point3d.Unset,G.LoftType.Normal,False)[0].CapPlanarHoles(.005)
    assert cutter.IsValid and cutter.IsSolid
    if cutter.SolidOrientation==G.BrepSolidOrientation.Inward:cutter.Flip()
    d['clearance_copies']={}
    for sid in ['6ff4660f-d023-461f-a4ac-9f0038a79c6d','96cf86e7-6e70-4f6d-9d49-14a22fbdef3c']:
        out=G.Brep.CreateBooleanDifference(obj(sid).Geometry,cutter,.01)
        assert out and all(b.IsValid and b.IsSolid for b in out)
        result=G.Brep()
        for b in out:result.Append(b)
        d['clearance_copies'][sid]=result
    for sid,g in d['clearance_copies'].items():assert sc.doc.Objects.Replace(System.Guid(sid),g)
    sc.doc.Views.Redraw()

def verify():
    d=sc.sticky[TAG];meshes={r:mesh(d[r])for r in ['body','base']}
    for m in meshes.values():assert m.IsValid and m.IsClosed
    failures=[];clearance=[]
    for i in range(71):
        s=BACK+3+(FRONT-BACK-6)*i/70;p,a,n=frame(s)
        for y in [-19,0,19]:
            for z in [1,3,6]:
                q=p+n*y+G.Vector3d.ZAxis*z
                for role,m in meshes.items():
                    if m.IsPointInside(q,.02,False):failures.append((s,y,z,role))
            q=p+n*y+G.Vector3d.ZAxis*.2
            h=G.Intersect.Intersection.MeshRay(meshes['body'],G.Ray3d(q,G.Vector3d.ZAxis))
            if h>=0:clearance.append(h+.2)
    intended=set(d.get('clearance_copies',{}))
    if obj(PATCH).Attributes.GetUserString('left_entry_role')=='side_cover':intended.add(PATCH)
    unchanged=all(obj(sid)and int(obj(sid).Geometry.DataCRC(0))==crc for sid,crc in d['before'].items()if sid not in intended)
    assert not failures,failures[:5]
    assert unchanged and (PATCH in intended or int(obj(PATCH).Geometry.DataCRC(0))==d['patch_crc'])
    assert clearance and min(clearance)>6.5
    d['verified']=True
    print('Closed/valid; minimum sampled new clearance %.3fm; user patch and unrelated original geometries unchanged.'%min(clearance))
    return {'minimum_clearance':min(clearance),'failures':failures,'unrelated_geometry_unchanged':unchanged,'localized_clearance_objects':list(intended)}

def repair_side_cover():
    """User-authorized replacement of their separate masking patch.

    A grounded, broad curved shoulder occludes old triangular seams and the
    adjacent open undercroft. This is a visual cover, not a terrain union.
    Replace the same object ID; no extra layer, snapshot or patch pile.
    """
    from System.Drawing import Color
    f=obj(ROAD).Geometry.Faces[0];route=f.IsoCurve(1,f.Domain(0).Mid);route.Reverse()
    ribs=[(1795,65,155,25.5),(1820,43,210,25),(1850,40,215,24),
          (1895,45,190,21),(1940,62,160,14),(1985,83,130,7),
          (2020,101,117,.5),(2035,104,115,-2)]
    def params(s):
        for a,b in zip(ribs[:-1],ribs[1:]):
            if s<=b[0]:
                t=max(0,min(1,(s-a[0])/(b[0]-a[0])))
                return [a[j]*(1-t)+b[j]*t for j in range(1,4)]
        return list(ribs[-1][1:])
    sections=[]
    for i in range(58):
        s=1795+240*i/57;ok,t=route.LengthParameter(s);assert ok
        p=route.PointAt(t);a=route.TangentAt(t);a.Z=0;a.Unitize();n=G.Vector3d(-a.Y,a.X,0)
        near,far,h=params(s);w=far-near;ground=-5.
        qz=[(near-3,ground),(near-4,ground+1),(near,1.2),
            (near+w*.10,h*.50),(near+w*.23,h*.90),(near+w*.43,h),
            (near+w*.70,h*.98),(far-2,h*.91),(far+3,h*.74),
            (far+5,ground+1),(far+3,ground),(near+w*.6,ground),(near+w*.25,ground)]
        sections.append(G.NurbsCurve.Create(True,3,[p-n*q+G.Vector3d.ZAxis*(z-p.Z)for q,z in qz]))
    out=G.Brep.CreateFromLoft(sections,G.Point3d.Unset,G.Point3d.Unset,G.LoftType.Loose,False)
    assert out and len(out)==1
    cover=out[0].CapPlanarHoles(.005);assert cover and cover.IsValid and cover.IsSolid
    if cover.SolidOrientation==G.BrepSolidOrientation.Inward:cover.Flip()
    name='建筑遮挡补体_暖白柔光';mi=next((i for i,m in enumerate(sc.doc.Materials)if m.Name==name),-1)
    if mi<0:
        m=Rhino.DocObjects.Material();m.Name=name;m.DiffuseColor=Color.FromArgb(241,237,228);m.ToPhysicallyBased()
        p=m.PhysicallyBased;p.BaseColor=Rhino.Display.Color4f(.945,.929,.894,1);p.Metallic=0;p.Roughness=.53;p.Specular=.38;p.Clearcoat=.02
        mi=sc.doc.Materials.Add(m)
    undo=sc.doc.BeginUndoRecord('入口侧连续坡肩遮挡补体')
    try:
        assert sc.doc.Objects.Replace(System.Guid(PATCH),cover)
        a=obj(PATCH).Attributes.Duplicate();a.Name='入口侧_连续坡肩遮挡补体'
        a.LayerIndex=sc.doc.Layers.FindByFullPath('地形::入口曲面与支撑',-1)
        a.MaterialIndex=mi;a.MaterialSource=Rhino.DocObjects.ObjectMaterialSource.MaterialFromObject
        a.SetUserString('left_entry_role','side_cover')
        a.SetUserString('purpose','Visual occluder replacing the user patch; covers adjacent triangular seams and open undercroft.')
        assert sc.doc.Objects.ModifyAttributes(System.Guid(PATCH),a,True)
    finally:sc.doc.EndUndoRecord(undo)
    sc.doc.Views.Redraw()
    return cover
