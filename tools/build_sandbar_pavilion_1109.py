# -*- coding: utf-8 -*-
"""Rhino: prepare(), apply(), export_source(), save_native(); Python: --package.

One feature-owned source, no terrain edits, no full-map backups. Rhino's point
objects are serialized to manifest markers rather than relying on GLB points.
"""
import io
import json
import os
import math

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FEATURE = 'sandbar_pavilion_1109'
CACHE = os.path.join(ROOT, '.current_map_build', FEATURE)
OUT = os.path.join(ROOT, 'assets', 'world', FEATURE)
CENTER = [1450., 1150., 0.]
SITE = [620., 1280., 0.]
FORWARD = [-.6, -.8, 0.]
RIGHT = [.8, -.6, 0.]
FLOOR = .10
_LOCAL_FRAME = None

try:
    add_object_metadata
except NameError:
    # Also works from Rhino's normal script editor when MCP's helper is absent.
    def add_object_metadata(oid, name, description):
        import scriptcontext as sc
        obj=sc.doc.Objects.FindId(oid)
        attrs=obj.Attributes.Duplicate()
        attrs.SetUserString('name',name)
        attrs.SetUserString('description',description)
        sc.doc.Objects.ModifyAttributes(oid,attrs,True)


def cad(x, z, h):
    if _LOCAL_FRAME is not None:
        cx,cz,angle=_LOCAL_FRAME
        x,z=cx+math.cos(angle)*x+math.sin(angle)*z,cz-math.sin(angle)*x+math.cos(angle)*z
    return [SITE[0]+RIGHT[0]*x+FORWARD[0]*z,
            SITE[1]+RIGHT[1]*x+FORWARD[1]*z, h]


def godot(p):
    return [round(p[0]-CENTER[0], 6), round(p[2], 6), round(CENTER[1]-p[1], 6)]


def _dump(path, value):
    folder = os.path.dirname(path)
    if not os.path.isdir(folder):
        os.makedirs(folder)
    with io.open(path, 'w', encoding='utf-8') as stream:
        stream.write(json.dumps(value, ensure_ascii=False, indent=2))


def _all_objects():
    import Rhino, scriptcontext as sc
    settings=Rhino.DocObjects.ObjectEnumeratorSettings()
    settings.NormalObjects=True;settings.HiddenObjects=True;settings.LockedObjects=True
    settings.DeletedObjects=False
    return list(sc.doc.Objects.GetObjectList(settings))


def _fingerprint():
    import scriptcontext as sc
    result={}
    for o in _all_objects():
        a=o.Attributes
        if a.GetUserString('pr_feature')==FEATURE:continue
        user=a.GetUserStrings()
        result[str(o.Id)]=[o.Geometry.DataCRC(0),a.Name,a.LayerIndex,a.MaterialIndex,
            str(a.MaterialSource),str(a.ColorSource),a.ObjectColor.ToArgb(),str(a.Mode),
            sorted((k,user[k]) for k in user.AllKeys)]
    return result


def _polyhedron(polygons):
    import Rhino.Geometry as G
    mesh = G.Mesh()
    # Each face has its own vertices, preserving crisp folded-roof normals.
    for poly in polygons:
        start = mesh.Vertices.Count
        for p in poly:
            mesh.Vertices.Add(*p)
        for i in range(1, len(poly)-1):
            mesh.Faces.AddFace(start, start+i, start+i+1)
    mesh.Vertices.CombineIdentical(True, True)
    mesh.Weld(math.pi)
    mesh.UnifyNormals()
    mesh.Normals.ComputeNormals()
    if mesh.SolidOrientation() < 0:
        mesh.Flip(True, True, True)
    assert mesh.IsValid and mesh.IsClosed, 'Expected closed solid mesh'
    return mesh


def _plate(top, depth):
    bottom = [[p[0], p[1], p[2]-depth] for p in top]
    faces = [top, list(reversed(bottom))]
    for i in range(len(top)):
        j = (i+1) % len(top)
        faces.append([bottom[i], bottom[j], top[j], top[i]])
    return _polyhedron([[cad(*p) for p in face] for face in faces])


def _horizontal(poly, bottom, top):
    return _plate([[p[0], p[1], top] for p in poly], top-bottom)


def _box(x, z, w, d, bottom, top):
    return _horizontal([[x-w/2,z-d/2],[x+w/2,z-d/2],
                        [x+w/2,z+d/2],[x-w/2,z+d/2]], bottom, top)


def _beam(a, b, width, depth):
    import Rhino.Geometry as G
    pa, pb = G.Point3d(*cad(*a)), G.Point3d(*cad(*b))
    tangent = pb-pa
    tangent.Unitize()
    across = G.Vector3d.CrossProduct(tangent, G.Vector3d.ZAxis)
    if across.Length < .001:
        across = G.Vector3d(*RIGHT)
    across.Unitize()
    side = G.Vector3d.CrossProduct(tangent, across)
    side.Unitize()
    rings = []
    for p in [pa, pb]:
        ring=[]
        for sx,sy in [(-1,-1),(1,-1),(1,1),(-1,1)]:
            q=p+across*(sx*width/2)+side*(sy*depth/2)
            ring.append([q.X,q.Y,q.Z])
        rings.append(ring)
    faces = [list(reversed(rings[0])), rings[1]]
    for i in range(4):
        j = (i+1) % 4
        faces.append([rings[0][i],rings[0][j],rings[1][j],rings[1][i]])
    return _polyhedron(faces)


def _roof_height(tri, x, z):
    a, b, c = tri
    den = (b[1]-c[1])*(a[0]-c[0])+(c[0]-b[0])*(a[1]-c[1])
    u = ((b[1]-c[1])*(x-c[0])+(c[0]-b[0])*(z-c[1]))/den
    v = ((c[1]-a[1])*(x-c[0])+(a[0]-c[0])*(z-c[1]))/den
    return u*a[2]+v*b[2]+(1-u-v)*c[2]


def _clip_plane(poly, axis, limit, keep_less=True):
    result=[]
    for i,p in enumerate(poly):
        q=poly[(i+1)%len(poly)]
        a=p[axis]-limit;b=q[axis]-limit
        inside=a<=0 if keep_less else a>=0
        other=b<=0 if keep_less else b>=0
        if inside:result.append(p)
        if inside!=other:
            t=a/(a-b);result.append([p[j]+t*(q[j]-p[j]) for j in range(len(p))])
    return result


def _deck(poly, add, key, building):
    """Visible boards use the exact flat simplified collision top, not duplicates."""
    import Rhino
    boards=Rhino.Geometry.Mesh()
    for i in range(int(math.floor(min(p[0] for p in poly)/.22)),
                   int(math.ceil(max(p[0] for p in poly)/.22))):
        patch=_clip_plane(_clip_plane(poly,0,i*.22+.003,False),0,(i+1)*.22-.003)
        if len(patch)>=3:boards.Append(_horizontal(patch,.07,FLOOR))
    add(key+'_Deck',boards,'timber','deck',building=building,collision=False,grain='z')
    add(key+'_DeckBacking',_horizontal(poly,.025,.069),'stone','deck',building=building,collision=False)


def _resort_buildings(add):
    """V3: complete inhabited volumes, covered timber terraces and seamed roofs."""
    import Rhino
    global _LOCAL_FRAME, _buildings
    _buildings=[]
    def house(key,cx,cz,angle,width,depth,eave,ridge,lodge=False,cafe=False):
        global _LOCAL_FRAME
        _LOCAL_FRAME=[cx,cz,angle]
        half=width/2.;back=-depth/2.;front=depth/2.
        outline=[[-half,back],[half,back],[half,front],[-half,front]]
        if lodge:
            outline=[[-half,back],[half,back],[half,front],[-half+7,front],[-half+7,front+6],[-half,front+6]]
        add(key+'_Floor',_horizontal(outline,-.04,FLOOR),'stone','floor',building=key,render=False)
        porch=front-3.8
        _deck(_clip_plane(outline,1,porch,False),add,key,key)
        inside=_clip_plane(outline,1,porch)
        add(key+'_InteriorFloor',_horizontal(inside,.03,FLOOR),'stone','floor',building=key,collision=False)
        groups={}
        def append(material,mesh,collision=True,grain='y'):
            group=(material,collision,grain)
            if group not in groups:groups[group]=Rhino.Geometry.Mesh()
            groups[group].Append(mesh)
        def box(mat,x,z,w,d,b,t,collision=True,grain='y'):
            append(mat,_box(x,z,w,d,b,t),collision,grain)
        def solid_wall(x,z,w,d,h):
            box('timber',x,z,w,d,FLOOR,h)
            box('stone',x,z,w+.08,d+.08,FLOOR,.34)
        # Fully intact folded roof: the reception's taller white wing is secondary.
        h0=eave;h1=ridge;h2=eave+.28
        roofs=[
            ([[-half-1.,back-.9,h0],[-1.,back-.9,h1],[-1.,front+1.,h1+.18],[-half-1.,front+1.,h0+.28]],'teal'),
            ([[-1.,back-.9,h1],[half+1.,back-.9,h2],[half+1.,front+1.,h2+.28],[-1.,front+1.,h1+.18]],
             'ivory' if key=='reception' else 'teal')]
        if lodge:
            roofs.append(([[-half-1.,front+.5,h0+.28],[-half+7.6,front+.5,h0+.72],
                           [-half+7.6,front+6.8,h0+.55],[-half-1.,front+6.8,h0+.10]],'teal'))
        for poly,mat in roofs:
            append(mat,_plate(poly,.20),True,'z')
            append('timber',_plate([[p[0],p[1],p[2]-.205] for p in poly],.055),False,'x')
            # White perimeter fascia and physically raised metal seams.
            for i,p in enumerate(poly):
                q=poly[(i+1)%len(poly)]
                append('ivory',_beam([p[0],p[1],p[2]-.10],[q[0],q[1],q[2]-.10],.16,.24),False)
            for ti in range(1,len(poly)-1):
                tri=[poly[0],poly[ti],poly[ti+1]]
                lo=min(p[0] for p in tri);hi=max(p[0] for p in tri)
                for index in range(int(math.ceil(lo/.80)),int(math.floor(hi/.80))+1):
                    x=index*.80;hits=[]
                    for j,p in enumerate(tri):
                        q=tri[(j+1)%3]
                        if abs(p[0]-q[0])<1e-6:continue
                        t=(x-p[0])/(q[0]-p[0])
                        if 0<=t<=1:hits.append([x,p[1]+t*(q[1]-p[1]),p[2]+t*(q[2]-p[2])+.025])
                    if len(hits)==2 and abs(hits[0][1]-hits[1][1])>.1:
                        append(mat,_beam(hits[0],hits[1],.032,.045),False,'z')
        # Close the volume to the true folded soffit, not merely the eave datum.
        roof_shape=Rhino.Geometry.Mesh()
        for poly,mat in roofs:roof_shape.Append(_plate(poly,.20))
        def ceiling(x,z):
            hits=Rhino.Geometry.Intersect.Intersection.MeshLine(roof_shape,Rhino.Geometry.Line(
                Rhino.Geometry.Point3d(*cad(x,z,.5)),Rhino.Geometry.Point3d(*cad(x,z,9.))))
            assert hits,'Missing roof above wall'
            return min(p.Z for p in hits)
        def closure(poly,dx,dz,material):
            other=[[p[0]+dx,p[1]+dz,p[2]] for p in poly]
            faces=[poly,list(reversed(other))]
            for i in range(len(poly)):
                j=(i+1)%len(poly);faces.append([poly[i],other[i],other[j],poly[j]])
            append(material,_polyhedron([[cad(*p) for p in f] for f in faces]),True,'y')
        # Timber elevations have true recessed openings on the rear and sides.
        wall_top=eave-.30
        sill,head=.92,2.70
        for side in [-1,1]:
            x=side*(half-.20)
            windows=[back+(porch-back)*t for t in [.28,.72]]
            cursor=back
            for z in windows:
                size=1.6;lo,hi=z-size/2.,z+size/2.
                if lo>cursor:solid_wall(x,(cursor+lo)/2.,.40,lo-cursor,wall_top)
                box('timber',x,z,.40,size,FLOOR,sill)
                box('timber',x,z,.40,size,head,wall_top)
                box('sea_glass',x,z,.065,size-.10,sill+.05,head-.05)
                for edge in [lo,hi]:
                    box('ivory',side*(half+.025),edge,.065,.075,sill-.02,head+.02)
                    box('timber',x,edge,.40,.08,sill,head)
                for height in [sill,head]:
                    box('ivory',side*(half+.025),z,.065,size+.08,height-.035,height+.035,True,'z')
                box('timber',side*(half+.22),z,.56,size+.36,head+.13,head+.23,True,'z')
                # Short lower rail and corner battens give the long wall a base.
                box('timber',side*(half+.045),z,.09,size+.40,.58,.70,False,'z')
                cursor=hi
            if porch>cursor:solid_wall(x,(cursor+porch)/2.,.40,porch-cursor,wall_top)
        rear_ranges=[(-half,-2.4),(2.4,half)] if key=='reception' else [(-half,half)]
        rear_centers=[half*t for t in [-.72,-.30,.30,.72]]
        window_width=3.4 if key=='reception' else 2.6
        for left,right in rear_ranges:
            cursor=left
            for x in rear_centers:
                lo,hi=x-window_width/2.,x+window_width/2.
                if lo<=left+.2 or hi>=right-.2:continue
                if lo>cursor:solid_wall((cursor+lo)/2.,back+.2,lo-cursor,.40,wall_top)
                box('timber',x,back+.2,window_width,.40,FLOOR,sill)
                box('timber',x,back+.2,window_width,.40,head,wall_top)
                box('sea_glass',x,back+.20,window_width-.1,.065,sill+.05,head-.05)
                for edge in [lo,hi]:
                    box('ivory',edge,back-.025,.075,.065,sill-.02,head+.02)
                    box('timber',edge,back+.2,.08,.40,sill,head)
                for height in [sill,head]:
                    box('ivory',x,back-.025,window_width+.08,.065,height-.035,height+.035,True,'x')
                box('timber',x,back-.22,window_width+.40,.56,head+.13,head+.23,True,'x')
                # A partial privacy screen beside each window reads from behind.
                for j in range(4):
                    box('timber',lo+.12+j*.15,back-.16,.055,.10,sill+.08,head-.08)
                cursor=hi
            if cursor<right:solid_wall((cursor+right)/2.,back+.2,right-cursor,.40,wall_top)
        for side in [-1,1]:
            box('ivory',side*(half-.05),back+.12,.13,.26,FLOOR,eave-.24)
        # Two glazed room frontages flank an open, collision-clear entrance.
        door_half=2.4 if key=='reception' else 1.45
        add(key+'_EntryApron',_box(0,front+1.15,door_half*2.+1.6,2.3,-.04,.012),
            'stone','entry_apron',building=key)
        for z in [porch,back+.2]:
            for xl,xr in [(-half+.20,-1.),(-1.,half-.20)]:
                closure([[xl,z-.09,wall_top-.05],[xr,z-.09,wall_top-.05],
                    [xr,z-.09,ceiling(xr,z)+.015],[xl,z-.09,ceiling(xl,z)+.015]],0,.18,'timber')
        for x in [-half+.20,half-.20]:
            closure([[x-.20,back,wall_top-.05],[x-.20,porch,wall_top-.05],
                [x-.20,porch,ceiling(x,porch)+.015],[x-.20,back,ceiling(x,back)+.015]],.40,0,'timber')
        for side in [-1,1]:
            left,right=( -half+.4,-door_half) if side<0 else (door_half,half-.4)
            center=(left+right)/2.;span=right-left
            box('sea_glass',center,porch,span,.10,.42,wall_top-.12)
            box('stone',center,porch,span,.28,FLOOR,.42)
            box('timber',center,porch,span,.26,wall_top-.16,wall_top+.04,True,'x')
            divisions=max(2,int(span/2.6))
            for j in range(divisions+1):
                x=left+span*j/divisions
                box('bronze',x,porch,.075,.18,.38,wall_top+.04)
            # A timber screen at each facade edge, limited to a 2.8m bay.
            for j in range(9):
                x=side*(half-.7-j*.27)
                box('timber',x,porch+.40,.095,.18,.34,wall_top+.06)
            # Deep entrance reveals and warm soffit lighting, no real-time light.
            box('timber',side*(door_half+.12),porch+1.05,.24,2.35,FLOOR,wall_top+.05)
            box('lamp',side*(door_half+.30),porch+1.15,.07,.08,2.25,2.75,False)
            # One fixed built-in day seat per room: decorative until separately marked.
            box('timber',side*(half-3.7),porch-1.5,3.6,1.05,FLOOR,.46)
            box('coral',side*(half-3.7),porch-1.5,3.4,.95,.46,.52)
        box('timber',0,porch+1.05,door_half*2.+.5,2.35,wall_top-.05,wall_top+.13,True,'x')
        for side in [-1,1]:
            # Paired outer posts connect visibly to the roof underside.
            x=side*(half-.75)
            z=front-.35
            triangle=roofs[0][0][:3] if x< -1 else roofs[1][0][:3]
            top=_roof_height(triangle,x,z)-.20
            box('timber',x,z,.22,.26,FLOOR,top)
            box('stone',x,z,.42,.44,FLOOR,.30)
        if lodge:
            solid_wall(-half+.22,front+2.8,.44,6.0,eave-.30)
            solid_wall(-half+3.5,front+5.75,7.,.5,eave-.30)
            # Return alcove has complete privacy walls, rather than broken remains.
            for j in range(14):
                box('timber',-half+.7+j*.43,front+5.40,.10,.18,.35,eave-.45)
        if cafe:
            # Reception counter is deliberately off the entry's central walk line.
            box('timber',7.,porch-2.1,7.0,1.2,FLOOR,1.04)
            box('ivory',7.,porch-2.1,7.2,1.35,1.04,1.12,True,'x')
            for shelf in [1.6,2.2]:
                box('timber',7.,back+.65,6.5,.40,shelf,shelf+.08,False,'x')
        for (material,collision,grain),mesh in sorted(groups.items()):
            suffix='Solid' if collision else 'Detail'
            add(key+'_'+material+'_'+grain+'_'+suffix,mesh,material,material,building=key,
                collision=collision,grain=grain)
        def point(u,v,h):return godot(cad(u,v,h))
        direction=[RIGHT[0]*math.sin(angle)+FORWARD[0]*math.cos(angle),0,
                   -(RIGHT[1]*math.sin(angle)+FORWARD[1]*math.cos(angle))]
        _buildings.append(dict(id=key,center=point(0,0,FLOOR),forward=direction,
            floor_component=key+'_Floor',width_m=width,depth_m=depth+(6 if lodge else 0),
            roof_height_m=max(p[2] for poly,mat in roofs for p in poly),single_storey=True,
            floor_outline=[point(u,v,FLOOR) for u,v in outline],
            entry=point(0,front-.9,FLOOR),approach=point(0,front+2.3,0),
            interior=point(0,front-4.,FLOOR),route_start=point(0,front+2.3,.09),
            route_end=point(0,front-3.,FLOOR),route_forward=[-v for v in direction],
            facade_depth_m=3.8,art_revision='finished_resort_v3'))
        side_axis=[RIGHT[0]*math.cos(angle)-FORWARD[0]*math.sin(angle),0,
                   -(RIGHT[1]*math.cos(angle)-FORWARD[1]*math.sin(angle))]
        _buildings[-1]['facade_revision']='timber_all_sides'
        _buildings[-1]['rear_windows']=[dict(center=point(x,back+.20,1.80),outward=[-v for v in direction]) for x in rear_centers]
        _buildings[-1]['side_windows']=[dict(center=point(side*(half-.20),z,1.80),outward=[side*v for v in side_axis])
            for side in [-1,1] for z in [back+(porch-back)*t for t in [.28,.72]]]
        if cafe:
            # Reach the entrance through the forecourt instead of the side room.
            _LOCAL_FRAME=None
            _buildings[-1]['approach_waypoints']=[godot(cad(10,68,0))]
            _LOCAL_FRAME=[cx,cz,angle]
        if cafe:
            x,z=0,1.8
            poly=[[-.8,-.35],[-.55,-.6],[.65,-.5],[.85,.25],[.55,.5],[-.65,.5]]
            add('cafe_desk_Surface',_horizontal([[x+u,z+v] for u,v in poly],FLOOR+.738,FLOOR+.838),'timber','desk','cafe_desk',key,grain='x')
            add('cafe_desk_Base',_box(x,z,.56,.54,FLOOR,FLOOR+.738),'bronze','desk','cafe_desk',key)
            _furniture.append(dict(id='cafe_desk',type='desk',name_zh=u'咖啡木桌',local=[cx+x,cz+z,FLOOR],surface_height=.838,
                usable_surface=dict(width_m=1.10,depth_m=.45,center_local=[0,.838,0]),
                anchors=[['Anchor_Desk_Surface',cx+x,cz+z,FLOOR+.838,False],['Anchor_Front',cx+x,cz+z+1.22,FLOOR,True]]))
            for n,x in enumerate([-2.,2.]):
                z=1.5;k='cafe_seat_%02d'%(n+1)
                add(k+'_Surface',_box(x,z,.76,.68,FLOOR+.32,FLOOR+.42),'timber','seat',k,key)
                add(k+'_Base',_box(x,z,.52,.46,FLOOR,FLOOR+.32),'bronze','seat',k,key)
                add(k+'_Back',_box(x,z-.37,.78,.10,FLOOR+.32,FLOOR+.95),'coral','seat',k,key)
                _furniture.append(dict(id=k,type='chair',name_zh=u'咖啡露台座椅',local=[cx+x,cz+z,FLOOR],surface_height=.42,
                    usable_surface=dict(width_m=.60,depth_m=.45,center_local=[0,.42,0]),
                    anchors=[['Anchor_Seat',cx+x,cz+z,FLOOR+.42,False],['Anchor_Front',cx+x,cz+z+.85,FLOOR,True]]))
        _LOCAL_FRAME=None
    house('reception',0,-49,0,44,22,4.35,6.55)
    house('lodge_a',-55,-4,math.pi/2.,28,17,3.55,5.0,lodge=True)
    house('lodge_b',55,-2,-math.pi/2.,27,17,3.65,5.15,lodge=True)
    house('rest_hall',-37,48,0,28,15,3.35,4.0,cafe=True)
    # One compact leisure spot, on the existing dry sand, not an extended deck.
    for n,x in enumerate([-18.,-15.5]):
        z=60.;key='lounger_%02d'%(n+1)
        add(key+'_Surface',_box(x,z,.90,2.10,.37,.46),'ivory','bed',key,'leisure')
        legs=Rhino.Geometry.Mesh()
        for dx in [-.34,.34]:
            for dz in [-.8,.8]:legs.Append(_box(x+dx,z+dz,.10,.12,-.03,.37))
        add(key+'_Base',legs,'timber','bed',key,'leisure')
        add(key+'_Back',_plate([[x-.45,z-1.05,.92],[x+.45,z-1.05,.92],
            [x+.45,z-.65,.49],[x-.45,z-.65,.49]],.07),'coral','bed',key,'leisure')
        _furniture.append(dict(id=key,type='bed',name_zh=u'沙洲躺椅',local=[x,z,0],surface_height=.46,
            usable_surface=dict(width_m=.65,depth_m=1.10,center_local=[0,.46,0]),
            anchors=[['Anchor_Bed_Center',x,z,.46,False],['Anchor_Front',x,z+1.65,0,True]]))
    add('LeisureShadePole',_box(-16.75,58.65,.09,.09,-.03,2.70),'bronze','shade',building='leisure')
    canopy=Rhino.Geometry.Mesh()
    for i in range(8):
        a=i*math.pi/4.;b=(i+1)*math.pi/4.
        canopy.Append(_plate([[-16.75,58.65,2.85],
            [-16.75+2.35*math.cos(a),58.65+2.35*math.sin(a),2.42],
            [-16.75+2.35*math.cos(b),58.65+2.35*math.sin(b),2.42]],.035))
    add('LeisureShadeCanopy',canopy,'teal','shade',building='leisure',collision=False)


def prepare():
    import Rhino, scriptcontext as sc
    global _staged, _protected, _furniture, _LOCAL_FRAME
    _LOCAL_FRAME=None
    assert str(sc.doc.ModelUnitSystem) == 'Meters'
    _protected = _fingerprint()
    _staged = []
    _furniture = []
    def add(name, mesh, material, category, owner=None, building='pavilion',collision=True,render=True,grain='y'):
        _staged.append(dict(name=name, mesh=mesh, material_key=material,
                            category=category, owner=owner, building_id=building,collision=collision,render=render,
                            grain=grain,texture_frame=list(_LOCAL_FRAME) if _LOCAL_FRAME else [0,0,0]))
    add('LowAngularPlinth', _horizontal([[-4.65,-2.05],[-3.65,-2.4],
        [3.2,-2.4],[4.1,-1.45],[3.9,2.4],[-3.95,2.4],[-4.65,1.4]], -.04, FLOOR), 'stone', 'floor')
    a, b, c, d = [-2.65,-2.35,2.25], [3.8,-2.35,3.35], [4.45,1.65,3.0], [-2.65,2.2,3.15]
    # Remove the outermost corner: a short exposed frame, not a jagged huge ruin.
    def clip(polygon):
        result=[]
        for i,p in enumerate(polygon):
            q=polygon[(i+1)%len(polygon)]
            ip,iq=p[0]+p[1]<=5.5,q[0]+q[1]<=5.5
            if ip: result.append(p)
            if ip != iq:
                t=(5.5-p[0]-p[1])/(q[0]+q[1]-p[0]-p[1])
                result.append([p[j]+t*(q[j]-p[j]) for j in range(3)])
        return result
    add('MainFoldWest', _plate([a,b,d], .11), 'ivory', 'roof')
    add('MainFoldEastBrokenTip', _plate(clip([b,c,d]), .11), 'ivory', 'roof')
    e,f,g,h = [-5.05,-2.1,2.20],[-1.8,-2.1,2.90],[-1.2,2.5,2.50],[-4.65,2.5,2.50]
    add('SmallFoldWest', _plate([e,f,h], .09), 'ivory', 'roof')
    add('SmallFoldEast', _plate([f,g,h], .09), 'ivory', 'roof')
    frame = Rhino.Geometry.Mesh()
    for x,z,tri,thickness in [(-2.15,-1.7,[a,b,d],.11),(2.7,-1.7,[a,b,d],.11),
                             (3.2,1.35,[b,c,d],.11),(-4.25,-1.65,[e,f,h],.09),
                             (-4.0,1.7,[f,g,h],.09)]:
        top = _roof_height(tri,x,z)-thickness
        frame.Append(_box(x,z,.105,.13,FLOOR,top))
        frame.Append(_box(x,z,.24,.25,FLOOR,FLOOR+.045))
    for p,q,t in [(a,b,.11),(b,c,.11),(c,d,.11),(d,a,.11),(b,d,.11),
                  (e,f,.09),(f,g,.09),(g,h,.09),(h,e,.09),(f,h,.09)]:
        frame.Append(_beam([p[0],p[1],p[2]-t-.025], [q[0],q[1],q[2]-t-.025],.065,.055))
    # Two short ribs remain visible where the thin roof corner is missing.
    for t in [.72,.86]:
        p=[b[j]*(1-t)+c[j]*t for j in range(3)]
        q=[d[j]*.16+c[j]*.84 for j in range(3)]
        frame.Append(_beam([p[0],p[1],p[2]-.10],[q[0],q[1],q[2]-.10],.045,.045))
    add('BronzeFrameAndExposedRibs',frame,'bronze','frame')
    for key,x,z in [('seat_01',-2.75,.65),('seat_02',1.85,.65)]:
        poly=[[-.9,.35],[.9,.35],[0,-1.15]]
        add(key+'_Surface',_horizontal([[x+u,z+v] for u,v in poly],FLOOR+.32,FLOOR+.42),'stone','seat',key)
        add(key+'_Base',_horizontal([[x+u*.68,z+v*.68] for u,v in poly],FLOOR,FLOOR+.32),'stone','seat',key)
        _furniture.append(dict(id=key,type='chair',name_zh='三角石座',local=[x,z,FLOOR],surface_height=.42,
            usable_surface=dict(width_m=.90,depth_m=.45,center_local=[0,.42,0]),
            anchors=[['Anchor_Seat',x,z,FLOOR+.42,False],['Anchor_Front',x,z+1.,FLOOR,True]]))
    x,z=-.15,-.65
    poly=[[-.8,-.35],[-.55,-.6],[.65,-.5],[.85,.25],[.55,.5],[-.65,.5]]
    add('desk_01_Surface',_horizontal([[x+u,z+v] for u,v in poly],FLOOR+.738,FLOOR+.838),'stone','desk','desk_01')
    add('desk_01_Base',_box(x,z,.56,.54,FLOOR,FLOOR+.738),'stone','desk','desk_01')
    _furniture.append(dict(id='desk_01',type='desk',name_zh='折角石桌',local=[x,z,FLOOR],surface_height=.838,
        usable_surface=dict(width_m=1.10,depth_m=.45,center_local=[0,.838,0]),
        anchors=[['Anchor_Desk_Surface',x,z,FLOOR+.838,False],['Anchor_Front',x,z+1.22,FLOOR,True]]))
    for i,(x,z,angle) in enumerate([(-.12,3.1,.12),(.12,4.2,-.18),(-.08,5.3,.2),(.18,6.35,-.1)]):
        poly=[]
        for u,v in [(-.37,-.25),(.23,-.3),(.4,.08),(.18,.28),(-.35,.21)]:
            poly.append([x+u*math.cos(angle)-v*math.sin(angle),z+u*math.sin(angle)+v*math.cos(angle)])
        add('ShortStone_%02d'%(i+1),_horizontal(poly,-.045,.065-i*.006),'stone','stepping_stone')
    _resort_buildings(add)
    # Central pavilion keeps its original footprint, roof form and marker IDs.
    central=[[-4.65,-2.05],[-3.65,-2.4],[3.2,-2.4],[4.1,-1.45],[3.9,2.4],[-3.95,2.4],[-4.65,1.4]]
    _staged[0]['render']=False
    _deck(central,add,'pavilion','pavilion')
    soffit=Rhino.Geometry.Mesh();fascia=Rhino.Geometry.Mesh()
    for poly in [[a,b,d],clip([b,c,d]),[e,f,h],[f,g,h]]:
        soffit.Append(_plate([[p[0],p[1],p[2]-.12] for p in poly],.035))
        for i,p in enumerate(poly):
            q=poly[(i+1)%len(poly)]
            fascia.Append(_beam([p[0],p[1],p[2]-.035],[q[0],q[1],q[2]-.035],.055,.09))
    add('PavilionTimberSoffits',soffit,'timber','soffit',collision=False,grain='x')
    add('PavilionTealFascia',fascia,'teal','fascia',collision=False)
    for row in _staged:
        if row['name'].endswith('_Surface') and row['building_id']=='pavilion':
            row['material_key']='timber';row['grain']='x'
    assert 60<len(_staged)<140
    # Stage and validate all solids before mutating the Rhino document.
    for row in _staged:
        assert row['mesh'].IsValid and row['mesh'].IsClosed, row['name']
    # Check the real trimmed dry-sand face before any document mutation.
    import System
    dry=sc.doc.Objects.FindId(System.Guid('128eeb8f-63cc-4d45-9780-00d332074cdf')).Geometry.Faces[0]
    boundary=dry.OuterLoop.To3dCurve()
    minimum=1e9
    for row in _staged:
        if row['building_id']=='pavilion':continue
        for p in row['mesh'].Vertices:
            q=Rhino.Geometry.Point3d(p.X,p.Y,0)
            ok,u,v=dry.ClosestPoint(q)
            assert str(dry.IsPointOnFace(u,v))!='Exterior','Outside dry sand: '+row['name']
            ok,t=boundary.ClosestPoint(q)
            minimum=min(minimum,q.DistanceTo(boundary.PointAt(t)))
    assert minimum>2.,'Building too close to dry-sand boundary'
    _buildings[0]['minimum_dry_edge_clearance_m']=minimum
    return dict(staged_meshes=len(_staged),protected_objects=len(_protected),site=SITE,
                floor_m=FLOOR,seat_height_m=.42,desk_height_m=.838,minimum_dry_edge_clearance_m=minimum)


def apply(colors_override=None, layer_name=u'沙洲观测亭', object_prefix='Sandbar_', description_prefix='Low sandbar pavilion'):
    import Rhino, scriptcontext as sc, System, System.Drawing as Drawing
    assert _fingerprint()==_protected, 'Unrelated Rhino geometry changed; restage first'
    layers={}
    colors={'ivory':(236,243,245),'stone':(82,102,112),'bronze':(88,74,56),'markers':(40,180,200),
            'teal':(44,143,147),'wall_concrete':(231,240,242),'timber':(178,117,59),
            'sea_glass':(37,117,135),'coral':(219,137,116),'lamp':(255,211,137)}
    if colors_override:colors.update(colors_override)
    root=sc.doc.Layers.FindByFullPath(u'建筑::'+layer_name,-1)
    if root<0:
        parent=sc.doc.Layers.FindByFullPath(u'建筑',-1)
        layer=Rhino.DocObjects.Layer();layer.Name=layer_name
        if parent>=0:layer.ParentLayerId=sc.doc.Layers[parent].Id
        root=sc.doc.Layers.Add(layer)
    for key,rgb in colors.items():
        full=sc.doc.Layers[root].FullPath+'::'+key
        index=sc.doc.Layers.FindByFullPath(full,-1)
        if index<0:
            layer=Rhino.DocObjects.Layer();layer.Name=key;layer.ParentLayerId=sc.doc.Layers[root].Id
            layer.Color=Drawing.Color.FromArgb(*rgb);index=sc.doc.Layers.Add(layer)
        material_name=FEATURE+'_'+key
        material_index=-1
        for mi in range(sc.doc.Materials.Count):
            if sc.doc.Materials[mi].Name==material_name:
                material_index=mi;break
        if material_index<0:
            material=Rhino.DocObjects.Material();material.Name=material_name
            material.DiffuseColor=Drawing.Color.FromArgb(*rgb)
            material.Shine=8
            material_index=sc.doc.Materials.Add(material)
        else:
            material=sc.doc.Materials[material_index]
            material.DiffuseColor=Drawing.Color.FromArgb(*rgb)
            material.CommitChanges()
        sc.doc.Layers[index].RenderMaterialIndex=material_index
        sc.doc.Layers[index].CommitChanges()
        layers[key]=index
    all_objects=_all_objects()
    previous=[o.Id for o in all_objects if o.Attributes.GetUserString('pr_feature')==FEATURE]
    reusable=dict((o.Attributes.GetUserString('component_id'),o) for o in all_objects if o.Id in previous)
    retained=[]
    created=[]
    def remove_owned(oid):
        obj=sc.doc.Objects.FindId(oid)
        assert obj is not None and obj.Attributes.GetUserString('pr_feature')==FEATURE
        # Hidden collision helpers require the ignoreModes overload; default
        # enumeration/deletion silently skips them and leaks on every rebuild.
        assert sc.doc.Objects.Delete(obj,True,True),'Cannot remove old feature component'
    try:
        for row in _staged:
            old=reusable.get(row['name'])
            if old is not None and old.Geometry.DataCRC(0)==row['mesh'].DataCRC(0):
                row['id']=str(old.Id);retained.append(old.Id)
                attrs=old.Attributes.Duplicate();attrs.LayerIndex=layers[row['material_key']]
                attrs.SetUserString('description',description_prefix+' / '+row['category'])
                attrs.MaterialSource=Rhino.DocObjects.ObjectMaterialSource.MaterialFromLayer
                attrs.Mode=Rhino.DocObjects.ObjectMode.Normal if row['render'] else Rhino.DocObjects.ObjectMode.Hidden
                sc.doc.Objects.ModifyAttributes(old.Id,attrs,True)
                continue
            attrs=Rhino.DocObjects.ObjectAttributes();attrs.Name=object_prefix+row['name']
            attrs.LayerIndex=layers[row['material_key']]
            attrs.Mode=Rhino.DocObjects.ObjectMode.Normal if row['render'] else Rhino.DocObjects.ObjectMode.Hidden
            attrs.SetUserString('pr_feature',FEATURE);attrs.SetUserString('component_id',row['name'])
            attrs.SetUserString('building_id',row['building_id'])
            attrs.MaterialSource=Rhino.DocObjects.ObjectMaterialSource.MaterialFromLayer
            oid=sc.doc.Objects.AddMesh(row['mesh'],attrs);assert oid!=System.Guid.Empty
            created.append(oid);row['id']=str(oid)
            add_object_metadata(oid,attrs.Name,description_prefix+' / '+row['category'])
        for furniture in _furniture:
            furniture['geometry_ids']=[r['id'] for r in _staged if r['owner']==furniture['id']]
            for a in furniture['anchors']:
                old=reusable.get(furniture['id']+'/'+a[0])
                p=cad(a[1],a[2],a[3])
                direction=furniture.get('forward_cad',FORWARD)
                direction=[-v if a[4] else v for v in direction]
                if old is not None and old.Geometry.Location.DistanceTo(Rhino.Geometry.Point3d(*p))<1e-7:
                    attrs=old.Attributes.Duplicate();attrs.SetUserString('forward_cad',json.dumps(direction))
                    sc.doc.Objects.ModifyAttributes(old.Id,attrs,True)
                    retained.append(old.Id);a.append(str(old.Id));continue
                attrs=Rhino.DocObjects.ObjectAttributes();attrs.Name=object_prefix+furniture['id']+'_'+a[0]
                attrs.LayerIndex=layers['markers'];attrs.SetUserString('pr_feature',FEATURE)
                attrs.SetUserString('component_id',furniture['id']+'/'+a[0])
                attrs.SetUserString('forward_cad',json.dumps(direction))
                attrs.SetUserString('instance_id',FEATURE+'_'+furniture['id'])
                oid=sc.doc.Objects.AddPoint(Rhino.Geometry.Point3d(*p),attrs)
                assert oid!=System.Guid.Empty;created.append(oid);a.append(str(oid))
                add_object_metadata(oid,attrs.Name,'Interaction marker; exported via manifest')
        assert _fingerprint()==_protected
    except:
        for oid in created:remove_owned(oid)
        raise
    for oid in previous:
        if oid not in retained:remove_owned(oid)
    owned=[o for o in _all_objects() if o.Attributes.GetUserString('pr_feature')==FEATURE]
    assert len(owned)==len(_staged)+sum(len(f['anchors']) for f in _furniture)
    assert len(set(o.Attributes.GetUserString('component_id') for o in owned))==len(owned)
    assert _fingerprint()==_protected
    sc.doc.Views.Redraw()
    return dict(meshes=len(_staged),markers=sum(len(f['anchors']) for f in _furniture),
                retained_objects=len(retained),replaced_feature_objects=len(previous)-len(retained),unrelated_objects_unchanged=True)


def export_source():
    import Rhino, scriptcontext as sc, System
    assert _fingerprint()==_protected
    rows=[]
    for item in _staged:
        mesh=sc.doc.Objects.FindId(System.Guid(item['id'])).Geometry.DuplicateMesh()
        mesh.Unweld(.001,True);mesh.Faces.ConvertQuadsToTriangles();mesh.Normals.ComputeNormals();mesh.Compact()
        row=dict((k,v) for k,v in item.items() if k not in ['mesh','owner'])
        row.update(kind='Structure',vertices=[[float(p.X),float(p.Y),float(p.Z)] for p in mesh.Vertices],
                   normals=[[float(p.X),float(p.Y),float(p.Z)] for p in mesh.Normals],
                   indices=[i for f in mesh.Faces for i in [f.A,f.B,f.C]])
        # Meter-scale UVs in each building's local axes; grain follows real members.
        cx,cz,angle=item['texture_frame']
        co,si=math.cos(angle),math.sin(angle)
        def local(p,normal=False):
            if normal:x,z=p.X*RIGHT[0]+p.Y*RIGHT[1],p.X*FORWARD[0]+p.Y*FORWARD[1]
            else:x,z=(p.X-SITE[0])*RIGHT[0]+(p.Y-SITE[1])*RIGHT[1]-cx,(p.X-SITE[0])*FORWARD[0]+(p.Y-SITE[1])*FORWARD[1]-cz
            return Rhino.Geometry.Vector3d(co*x-si*z,p.Z,si*x+co*z)
        uvs=[]
        grain={'x':Rhino.Geometry.Vector3d.XAxis,'y':Rhino.Geometry.Vector3d.YAxis,'z':Rhino.Geometry.Vector3d.ZAxis}[item['grain']]
        for p,n in zip(mesh.Vertices,mesh.Normals):
            v=local(p);normal=local(n,True);normal.Unitize()
            vertical=grain-normal*(grain*normal)
            if vertical.Length<.01:
                vertical=Rhino.Geometry.Vector3d.ZAxis-normal*normal.Z
            if vertical.Length<.01:vertical=Rhino.Geometry.Vector3d.XAxis-normal*normal.X
            vertical.Unitize();horizontal=Rhino.Geometry.Vector3d.CrossProduct(vertical,normal);horizontal.Unitize()
            uvs.append([float(v*horizontal),float(v*vertical)])
        row['uvs']=uvs
        rows.append(row)
    furniture=[]
    for item in _furniture:
        row=dict((k,v) for k,v in item.items() if k not in ['local','anchors'])
        row.update(instance_id=FEATURE+'_'+item['id'],position=godot(cad(*item['local'])),
                   forward=[-.6,0,.8],interaction_status='anchors_ready',motion_profiles=[])
        row['anchors']=[dict(name=a[0],position=godot(cad(a[1],a[2],a[3])),
                            forward=[.6,0,-.8] if a[4] else [-.6,0,.8],source_id=a[5]) for a in item['anchors']]
        furniture.append(row)
    manifest=dict(feature=FEATURE,native_center=CENTER,site_cad=SITE,forward=[-.6,0,.8],
        floor_height_m=FLOOR,max_height_m=6.8,interaction_status='anchors_ready',
        protected_objects_unchanged=True,terrain_modified=False,grass_rebake_required=False,
        objects=rows,interactions=dict(furniture=furniture),
        spawn=godot(cad(0,1.9,FLOOR+.04)),
        camera=dict(position=godot(cad(-9,11,4.5)),target=godot(cad(-.4,0,1.3)),fov=44.),
        materials=dict(
            ivory=dict(color=[.92,.95,.96],resource='cool_white_wall'),
            wall_concrete=dict(color=[.90,.94,.95],resource='cool_white_wall'),
            timber=dict(color=[.62,.36,.16],resource='honey_timber'),
            teal=dict(color=[.10,.47,.49],resource='sea_green_roof'),
            stone=dict(color=[.22,.28,.31],roughness=.86),
            sea_glass=dict(color=[.035,.28,.35],metallic=.12,roughness=.20),
            bronze=dict(color=[.24,.20,.15],metallic=.48,roughness=.46),
            coral=dict(color=[.74,.36,.27],roughness=.88),
            lamp=dict(color=[1.,.71,.34],roughness=.7,emission=.8)))
    manifest['art_revision']='finished_resort_v3'
    by_component=dict((r['name'],r['id']) for r in rows)
    for building in _buildings:
        building['floor_source_id']=by_component[building['floor_component']]
    manifest['buildings']=_buildings
    manifest['building_count']=5
    manifest['court_hub']=godot(cad(10,10,0))
    manifest['camera']=dict(position=godot(cad(-15,125,38)),target=godot(cad(-6,4,1.5)),fov=44.)
    manifest['detail_camera']=dict(position=godot(cad(31,-84,8.0)),target=godot(cad(2,-49,2.6)),fov=48.)
    _dump(os.path.join(CACHE,'source.json'),manifest)
    return dict(meshes=len(rows),triangles=sum(len(r['indices'])//3 for r in rows),furniture=len(furniture))


def save_native():
    import Rhino, scriptcontext as sc, System
    assert _fingerprint()==_protected
    path=sc.doc.Path
    assert os.path.normcase(path)==os.path.normcase(os.path.join(os.path.dirname(ROOT),'map','map_current.3dm'))
    old=Rhino.ApplicationSettings.FileSettings.CreateBackupFiles
    try:
        Rhino.ApplicationSettings.FileSettings.CreateBackupFiles=False
        opts=Rhino.FileIO.FileWriteOptions();opts.SuppressAllInput=True;opts.SuppressDialogBoxes=True;opts.UpdateDocumentPath=True
        assert sc.doc.WriteFile(path,opts),'Native save failed'
    finally:Rhino.ApplicationSettings.FileSettings.CreateBackupFiles=old
    saved=Rhino.FileIO.File3dm.Read(path)
    try:
        found=dict((str(o.Id),o.Geometry.DataCRC(0)) for o in saved.Objects)
        for row in _staged:
            assert found[row['id']]==sc.doc.Objects.FindId(System.Guid(row['id'])).Geometry.DataCRC(0)
        for item in _furniture:
            for anchor in item['anchors']:
                assert found[anchor[5]]==sc.doc.Objects.FindId(System.Guid(anchor[5])).Geometry.DataCRC(0)
        owned=[o for o in saved.Objects if o.Attributes.GetUserString('pr_feature')==FEATURE]
        assert len(owned)==len(_staged)+sum(len(f['anchors']) for f in _furniture)
        assert len(set(o.Attributes.GetUserString('component_id') for o in owned))==len(owned)
    finally:saved.Dispose()
    return dict(saved=path,verified_meshes=len(_staged),verified_markers=sum(len(f['anchors']) for f in _furniture),modified=sc.doc.Modified)


def package(filename='pavilion.glb',generator='Prism Route / Rhino sandbar pavilion'):
    import struct
    with io.open(os.path.join(CACHE,'source.json'),encoding='utf-8') as stream:
        source=json.load(stream)
    blob=bytearray();views=[];accessors=[];meshes=[];nodes=[]
    def array(values,component,shape,target):
        while len(blob)%4:blob.append(0)
        fmt='f' if component==5126 else 'I'
        flat=[n for row in values for n in row] if shape in ['VEC3','VEC2'] else values
        data=struct.pack('<'+fmt*len(flat),*flat);start=len(blob);blob.extend(data)
        views.append(dict(buffer=0,byteOffset=start,byteLength=len(data),target=target))
        a=dict(bufferView=len(views)-1,componentType=component,count=len(values),type=shape)
        if shape=='VEC3':a.update(min=[min(v[j] for v in values) for j in range(3)],max=[max(v[j] for v in values) for j in range(3)])
        accessors.append(a);return len(accessors)-1
    for row in source['objects']:
        p=[godot(v) for v in row.pop('vertices')]
        normals=[[v[0],v[2],-v[1]] for v in row.pop('normals')]
        ix=row.pop('indices')
        attrs=dict(POSITION=array(p,5126,'VEC3',34962),NORMAL=array(normals,5126,'VEC3',34962),TEXCOORD_0=array(row.pop('uvs'),5126,'VEC2',34962))
        meshes.append(dict(primitives=[dict(attributes=attrs,indices=array(ix,5125,'SCALAR',34963),mode=4)]))
        nodes.append(dict(name='Structure_'+row['id'],mesh=len(meshes)-1,extras=dict(source_id=row['id'],source_name=row['name'])))
        row.update(vertex_count=len(p),triangle_count=len(ix)//3)
    gltf=dict(asset=dict(version='2.0',generator=generator),scene=0,
        scenes=[dict(nodes=list(range(len(nodes))))],nodes=nodes,meshes=meshes,buffers=[dict(byteLength=len(blob))],bufferViews=views,accessors=accessors)
    js=json.dumps(gltf,separators=(',',':')).encode('utf-8');js+=b' '*((-len(js))%4);blob+=b'\0'*((-len(blob))%4)
    data=struct.pack('<III',0x46546C67,2,28+len(js)+len(blob))+struct.pack('<II',len(js),0x4E4F534A)+js+struct.pack('<II',len(blob),0x004E4942)+blob
    if not os.path.isdir(OUT):os.makedirs(OUT)
    with open(os.path.join(OUT,filename),'wb') as stream:stream.write(data)
    source['triangle_count']=sum(r['triangle_count'] for r in source['objects'])
    _dump(os.path.join(OUT,'manifest.json'),source)
    print(json.dumps(dict(meshes=len(meshes),triangles=source['triangle_count'],glb_bytes=len(data))))


if __name__=='__main__':
    import argparse
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--package',action='store_true')
    if parser.parse_args().package:package()
