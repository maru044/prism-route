# -*- coding: utf-8 -*-
"""Small, reversible tunnel completion against the existing live road surfaces.

Retain the approved coastal mouth. Replace the recessed western mouth with
a broader shared-topology volume and extend the coastal soffit under existing
covered ground. No terrain rebuild and no new road alignment.
"""
from __future__ import unicode_literals, division
import Rhino, scriptcontext as sc, System, math, io, json, os
G = Rhino.Geometry
ROOT = 'D:/Prism Route/prism-route'
OUT = ROOT+'/docs/concepts/tunnel_consolidation_2026-10-18'
TAG = 'tunnel_consolidation_1018_v01'
LAYER = '1018_隧道收拢_入口与内部_v01'

def init():
    assert TAG not in sc.sticky
    sc.sticky[TAG] = {'assets': [], 'hidden': [], 'published': []}
    if not os.path.isdir(OUT): os.makedirs(OUT)

def recipe(): return sc.sticky['portal_recipe']
def state(): return sc.sticky[TAG]
def smooth(t):
    t = max(0, min(1,t)); return t*t*t*(10+t*(-15+6*t))

def mouth():
    """Thick trumpet mouth. Common topology across soffit, lip and shoulders."""
    N,M,K = 64,40,5
    def at(t,j,k):
        theta = math.pi*j/M; f = k/K; side = math.cos(theta)
        front = 831-21*abs(side)**1.5*(1+.12*side)-2.2*math.sin(math.pi*f)
        s = front+(1009.3-front)*t
        p,a,n = recipe()['frame']('west',s)
        blend = smooth((s-831)/73)
        half = 26-9.3*blend
        crown_z = 43.2+4.4*smooth((s-847)/51)
        height = crown_z-p.Z-2.0
        # Existing soffit lies at 43.5 to 48 m. Exterior merges into it;
        # haunches reach the low terrain instead of ending at road height.
        foot = 56-15*blend; ground = -5.0
        yi = -half*side
        zi = p.Z-.8+(height+.8)*math.sin(theta)**.61
        yo = -foot*side
        zo = ground+(crown_z-ground)*math.sin(theta)**.76
        return p+n*(yi*(1-f)+yo*f)+G.Vector3d.ZAxis*((zi*(1-f)+zo*f)-p.Z)
    coords = [(j,0)for j in range(M+1)]+[(M,k)for k in range(1,K)]+[(j,K)for j in reversed(range(M+1))]+[(0,k)for k in reversed(range(1,K))]
    mesh=G.Mesh();lookup={}
    for i in range(N+1):
        for j,k in coords:lookup[i,j,k]=mesh.Vertices.Add(at(i/N,j,k))
    for i in range(N):
        for z in range(len(coords)):
            j,k=coords[z]; jj,kk=coords[(z+1)%len(coords)]
            mesh.Faces.AddFace(lookup[i,j,k],lookup[i,jj,kk],lookup[i+1,jj,kk],lookup[i+1,j,k])
    for i in [0,N]:
        for j in range(1,M):
            for k in range(1,K):lookup[i,j,k]=mesh.Vertices.Add(at(i/N,j,k))
        for j in range(M):
            for k in range(K):mesh.Faces.AddFace(lookup[i,j,k],lookup[i,j+1,k],lookup[i,j+1,k+1],lookup[i,j,k+1])
    mesh.UnifyNormals();mesh.Weld(math.pi);mesh.Normals.ComputeNormals();mesh.Compact()
    assert mesh.IsClosed and mesh.IsValid
    sub=G.SubD.CreateFromMesh(mesh,G.SubDCreationOptions.Smooth)
    assert sub and sub.IsValid
    state()['assets'].append(('01_入口_连续喇叭口与落地拱肩',sub))

def section(which,s,innerhalf,innerheight,outerhalf,outerheight,ground):
    p,a,n=recipe()['frame'](which,s)
    yz=[]
    for j in range(41):
        theta=math.pi*j/40
        yz.append((-innerhalf*math.cos(theta),p.Z-.7+(innerheight+.7)*math.sin(theta)**.61))
    for j in reversed(range(41)):
        theta=math.pi*j/40
        yz.append((-outerhalf*math.cos(theta),ground+(p.Z+outerheight-ground)*math.sin(theta)**.72))
    return G.NurbsCurve.Create(True,3,[p+n*y+G.Vector3d.ZAxis*(z-p.Z)for y,z in yz])

def interior():
    # The previous coastal mouth stopped at station 1265; the existing
    # overhead terrain continues to about 1680. Fill this missing interior.
    sections=[]
    for i in range(89):
        s=1256+441*i/88
        p,a,n=recipe()['frame']('east',s)
        flare=smooth((s-1634)/63)
        half=25+6*flare; height=13.2+2.5*flare
        sections.append(section('east',s,half,height,half+5+3*flare,height+2.8,p.Z-1.8))
    b=recipe()['loft'](sections)
    state()['assets'].append(('02_临水洞口后方_连续内壁与拱顶',b))

def base():
    sections=[]
    for i in range(65):
        s=756+253.3*i/64;p,a,n=recipe()['frame']('west',s)
        w=20-1*smooth((s-831)/73);top=p.Z-.20
        bottom=top-3.0-(top+1.5)*smooth((s-756)/82)
        yz=[(-w-3,bottom),(-w-4,bottom+1),(-w-1,top-1),(-w,top),(0,top),(w,top),(w+1,top-1),(w+4,bottom+1),(w+3,bottom),(0,bottom)]
        sections.append(G.NurbsCurve.Create(True,3,[p+n*y+G.Vector3d.ZAxis*(z-p.Z)for y,z in yz]))
    state()['assets'].append(('03_入口道路下方_连续落地路基',recipe()['loft'](sections)))

def coastal_floor():
    # Reuse the original UV-preserving trim, extending ONLY its existing
    # clearance footprint. Otherwise the old 35 m green surface cuts the road.
    old=sc.sticky['tunnel_portals_1017_v01']; saved_range=old['east_range'];saved_soil=old['soil_copy']
    try:
        old['east_range']=[saved_range[0],1705.0]
        recipe()['trim_coastal_floor']()
        b=old['soil_copy'];assert b.IsValid
        assert sc.doc.Objects.Replace(System.Guid('9178570a-b44f-4316-917c-0ce86332f3dd'),b)
        state()['floor_trim_extended']=True
    finally:old['east_range']=saved_range;old['soil_copy']=saved_soil

def shoulders():
    face=recipe()['obj'](recipe()['EAST']).Geometry.Faces[0]
    surface=face.UnderlyingSurface();N=148
    for sign in [-1,1]:
        mesh=G.Mesh()
        for i in range(N+1):
            s=1256+441*i/N;p,a,n=recipe()['frame']('east',s)
            uv=recipe()['uvpoint'](surface,p)
            ends=[face.PointAt(face.Domain(0).T0,uv.Y),face.PointAt(face.Domain(0).T1,uv.Y)]
            edge=max(ends,key=lambda q:sign*G.Vector3d.Multiply(q-p,n))
            outer=p+n*(sign*(24.8+6*smooth((s-1634)/63)) );outer.Z=p.Z-.05
            inner=edge+n*(sign*.05);inner.Z=edge.Z-.02
            for q in [inner,outer,outer-G.Vector3d.ZAxis*.40,inner-G.Vector3d.ZAxis*.40]:mesh.Vertices.Add(q)
        for i in range(N):
            for j in range(4):
                k=i*4+j;l=i*4+(j+1)%4;mesh.Faces.AddFace(k,l,l+4,k+4)
        mesh.Faces.AddFace(3,2,1,0);j=N*4;mesh.Faces.AddFace(j,j+1,j+2,j+3)
        mesh.UnifyNormals();mesh.Normals.ComputeNormals();mesh.Compact()
        assert mesh.IsValid and mesh.IsClosed
        state()['assets'].append(('04_洞内连续路肩_'+str(sign),mesh))

def publish():
    d=state();assert not d['published']
    layer=Rhino.DocObjects.Layer();layer.Name=LAYER
    li=sc.doc.Layers.FindByFullPath(LAYER,-1)
    if li<0:li=sc.doc.Layers.Add(layer)
    mi=recipe()['portal_material']()
    undo=sc.doc.BeginUndoRecord('隧道入口与内部简化补齐')
    try:
        for name,g in d['assets']:
            a=Rhino.DocObjects.ObjectAttributes();a.LayerIndex=li;a.Name=name
            a.MaterialIndex=mi;a.MaterialSource=Rhino.DocObjects.ObjectMaterialSource.MaterialFromObject
            a.SetUserString('recipe',TAG)
            if isinstance(g,G.SubD):oid=sc.doc.Objects.AddSubD(g,a)
            elif isinstance(g,G.Mesh):oid=sc.doc.Objects.AddMesh(g,a)
            else:oid=sc.doc.Objects.AddBrep(g,a)
            assert oid!=System.Guid.Empty
            d['published'].append({'id':str(oid),'name':name})
        for sid in ['4ab4c179-5166-43e9-99a7-d4f967954935','78f2ca34-3dcd-46a2-a807-6486d4e72ccc','277ed72c-6e7b-45aa-a753-0d7daf32afca']:
            assert sc.doc.Objects.Hide(System.Guid(sid),True);d['hidden'].append(sid)
    finally:sc.doc.EndUndoRecord(undo)
    sc.doc.Views.Redraw()

def check():
    d=state();report={'assets':[],'scope':'Local entrance consolidation and existing covered coastal road interior; no full road-network rebuild.','game_tested':False}
    assert len(d['assets'])==5
    report['existing_surface_crossings']=d.get('existing_crossings',{})
    report['coastal_floor_clearance_extended']=bool(d.get('floor_trim_extended'))
    for name,g in d['assets']:
        mesh=g.DuplicateMesh()if isinstance(g,G.Mesh)else recipe()['meshed'](g,3,.025)
        mesh.Weld(math.pi);mesh.UnifyNormals();mesh.Normals.ComputeNormals()
        assert mesh.IsValid and mesh.IsClosed
        row={'name':name,'valid':True,'closed':True,'intrusions':[],'minimum_clearance':None}
        if name.startswith(('01_','02_')):
            which='west'if name.startswith('01_')else'east'
            start,end=(840,1005)if which=='west'else(1260,1690)
            heights=[]
            for i in range(61):
                s=start+(end-start)*i/60;p,a,n=recipe()['frame'](which,s)
                width=9.0 if which=='west'else 19.0
                for y in [-width,0,width]:
                    for z in [1,3,6]:
                        q=p+n*y+G.Vector3d.ZAxis*z
                        if mesh.IsPointInside(q,.02,False):row['intrusions'].append([s,y,z])
                    q=p+n*y+G.Vector3d.ZAxis*.1
                    hit=G.Intersect.Intersection.MeshRay(mesh,G.Ray3d(q,G.Vector3d.ZAxis))
                    if hit>=0:heights.append(hit+.1)
            assert not row['intrusions']
            assert heights and min(heights)>6.5
            row['minimum_clearance']=min(heights)
        report['assets'].append(row)
    d['verification']=report
    with io.open(OUT+'/verification.json','w',encoding='utf8')as f:f.write(unicode(json.dumps(report,ensure_ascii=False,indent=2)))
    print(json.dumps(report,ensure_ascii=False))

def capture(name):
    c=Rhino.Display.ViewCapture();c.Width=1600;c.Height=1000;c.DrawGrid=False;c.DrawAxes=False;c.DrawGridAxes=False
    b=c.CaptureToBitmap(sc.doc.Views.ActiveView);b.Save(OUT+'/'+name+'.png',System.Drawing.Imaging.ImageFormat.Png);b.Dispose()

def save():
    d=state();assert d['verification']
    path='D:/Prism Route/map/map_1018_tunnel_consolidated_v01.3dm'
    assert not os.path.exists(path)
    assert sc.doc.SaveAs(path)
    Rhino.RhinoApp.RunScript('_-SaveAs "'+path.replace('/','\\')+'" _Enter _Yes',False)
    assert sc.doc.Path.replace('\\','/').lower()==path.lower() and not sc.doc.Modified
    with io.open(OUT+'/publication.json','w',encoding='utf8')as f:f.write(unicode(json.dumps({'scene':path,'objects':d['published'],'hidden_previous':d['hidden'],'modified_existing_floor_copy':'9178570a-b44f-4316-917c-0ce86332f3dd','previous_scene':'D:/Prism Route/map/map_1017_tunnel_portals_v01.3dm'},ensure_ascii=False,indent=2)))
    print(path)
