"""Generate a perforated thick facade from openings, never from pipe rails.

Pure Python: clipped triangular parameter domain and rounded opening rims.
Rhino supplies the sampled road-facing frame. Geometry is a rebuildable mesh.
"""
from pathlib import Path
import json
import math
import random

ROOT = Path(__file__).resolve().parents[1]
WORK = ROOT / '.map_1012_build'
CFG = ROOT / 'tools' / 'cliff_b_shell_v02.json'


def build():
    frames = json.loads((WORK / 'cliff_b_v02_road_frames.json').read_text())
    cfg = json.loads(CFG.read_text(encoding='utf-8'))
    length, rows = frames['length'], frames['samples']
    rng = random.Random(cfg['seed'])
    widths = [rng.uniform(54, 96) for _ in range(cfg['bay_count'])]
    scale = (length - 12) / sum(widths)
    widths = [w * scale for w in widths]
    holes, cursor = [], 6.0
    for i, width in enumerate(widths):
        center = cursor + width / 2
        tilt = rng.uniform(-.28, .28)
        if i in [1, 4, 7, 10]:
            holes.append([center, 31.0 + rng.uniform(-2, 2), width*.385,
                          rng.uniform(25, 27), tilt, 'full_height'])
        else:
            lower_z = rng.uniform(15, 19)
            holes.append([center-width*.035, lower_z, width*rng.uniform(.35,.39),
                          lower_z-rng.uniform(1.4, 2.4), tilt, 'ground_arch'])
            upper_z = rng.uniform(44, 47)
            holes.append([center+width*rng.uniform(-.16,.16), upper_z,
                          width*rng.uniform(.32,.39), 57.8-upper_z,
                          -tilt*rng.uniform(.5,1.4), 'upper_light'])
            # Keep a broad web between the paired openings, including at
            # their closest tips; thin touching lips would fold on rounding.
            lower,upper=holes[-2:]
            lower[3]=min(lower[3],upper[1]-upper[3]-4.5-lower[1])
        cursor += width
    # Deform each opening in its own parameter domain. Different shoulders
    # and shifting centres avoid an array of identical elliptical windows.
    for hole in holes:
        hole.extend([rng.uniform(-.13,.13)*hole[2],rng.uniform(-.20,.24)])

    def signed(x, z):
        best, chosen = float('inf'), None
        for hole in holes:
            cx, cz, rx, rz, tilt, _, bend, taper = hole
            v = (z-cz)/rz
            width=rx*max(.25,1+taper*v)
            u = (x-cx-tilt*(z-cz)-bend*(v*v-.25))/width
            distance = (math.hypot(u,v)-1)*min(rx,rz)
            if distance < best:
                best, chosen = distance, hole
        return best, chosen

    points, lookup, faces = [], {}, []

    def vertex(x, z):
        key = (round(x,7), round(z,7))
        if key not in lookup:
            lookup[key] = len(points)
            points.append((x,z))
        return lookup[key]

    nx, nz = math.ceil(length/cfg['grid_x_m']), cfg['grid_z_steps']
    z0, z1 = .66, 59.8
    def clip(triangle):
        out = []
        for i, a in enumerate(triangle):
            b = triangle[(i+1)%3]
            fa, ha = signed(*a)
            fb, hb = signed(*b)
            if fa >= 0:
                out.append(a)
            if (fa >= 0) != (fb >= 0):
                # Solve on the grid edge. Radial projection can move the
                # crossing outside its cell and invert tiny cut triangles.
                lo,hi=0.0,1.0
                for _ in range(28):
                    t=(lo+hi)/2
                    value,_=signed(a[0]+t*(b[0]-a[0]),a[1]+t*(b[1]-a[1]))
                    if (value>=0)==(fa>=0):lo=t
                    else:hi=t
                t=(lo+hi)/2
                out.append((a[0]+t*(b[0]-a[0]),a[1]+t*(b[1]-a[1])))
        if len(out) >= 3:
            ids = [vertex(*p) for p in out]
            for j in range(1,len(ids)-1):
                if len(set([ids[0],ids[j],ids[j+1]])) == 3:
                    faces.append([ids[0],ids[j],ids[j+1]])
    for j in range(nz):
        za,zb = z0+(z1-z0)*j/nz,z0+(z1-z0)*(j+1)/nz
        for i in range(nx):
            xa,xb = length*i/nx,length*(i+1)/nx
            a,b,c,d = (xa,za),(xb,za),(xb,zb),(xa,zb)
            clip([a,b,c]);clip([a,c,d])

    edges = {}
    for face in faces:
        for a,b in zip(face,face[1:]+face[:1]):
            key = tuple(sorted((a,b)))
            if key in edges:
                edges[key] = None
            else:
                edges[key] = (a,b)
    boundary = [e for e in edges.values() if e is not None]

    def smooth(t):
        t = min(1,max(0,t))
        return t*t*(3-2*t)

    def mapped(x,z,depth):
        sample = x/length*(len(rows)-1)
        k = min(len(rows)-2,int(sample)); blend = sample-k
        q = [rows[k][i]*(1-blend)+rows[k+1][i]*blend for i in range(4)]
        normal_length = math.hypot(q[2],q[3]);q[2]/=normal_length;q[3]/=normal_length
        s, t = x/length, z/60
        outward = 11.8 + 2.5*math.sin(2*math.pi*s+1.1)+1.7*math.sin(7*math.pi*s-2*t)
        outward += 4.0*(1-smooth(t/.24))
        roof_blend = smooth((t-.68)/.315)
        offset = outward*(1-roof_blend)-4.0*roof_blend+depth
        return [q[0]+q[2]*offset,q[1]+q[3]*offset,z]

    thickness = cfg['thickness_m']
    vertices = [mapped(x,z,thickness/2) for x,z in points]
    vertices += [mapped(x,z,-thickness/2) for x,z in points]
    count = len(points)
    solid_faces = [f[::-1] for f in faces]+[[v+count for v in f] for f in faces]
    # Rounded hole lips: a half-circle swept along the opening boundary;
    # only the rim has a section, the support itself remains a thick sheet.
    boundary_vertices = sorted(set(v for edge in boundary for v in edge))
    rings = {0:{v:v for v in boundary_vertices},6:{v:v+count for v in boundary_vertices}}
    for ring in range(1,6):
        theta = math.pi*ring/6
        indices = {}
        for v in boundary_vertices:
            x,z = points[v];distance,hole = signed(x,z)
            if abs(distance) < .02:
                cx,cz,rx,rz,tilt,_,bend,taper = hole
                w=(z-cz)/rz;width=rx*(1+taper*w)
                u=(x-cx-tilt*(z-cz)-bend*(w*w-.25))/width
                du_dz=(-tilt-2*bend*w/rz)/width-u*taper/(rz*(1+taper*w))
                gx,gz = u/width,u*du_dz+w/rz
                norm=math.hypot(gx,gz);gx/=norm;gz/=norm
                shift=.42*math.sin(theta)
                x-=gx*shift;z-=gz*shift
            indices[v]=len(vertices)
            vertices.append(mapped(x,z,thickness/2*math.cos(theta)))
        rings[ring]=indices
    for ring in range(6):
        for a,b in boundary:
            solid_faces.append([rings[ring][a],rings[ring][b],rings[ring+1][b],rings[ring+1][a]])
    payload = {'vertices':vertices,'faces':solid_faces,'openings':holes,'parameter_points':points,'length_m':length,
               'seed':cfg['seed'],'basis':'perforated curved thick sheet, no cylindrical members',
               'parameter_vertices':len(points),'boundary_edges':len(boundary)}
    (WORK/'cliff_b_shell_v02_mesh.json').write_text(json.dumps(payload,separators=(',',':')),encoding='utf-8')
    print(json.dumps({k:payload[k] for k in ['length_m','basis','parameter_vertices','boundary_edges']}))
    print('vertices=%s faces=%s openings=%s' % (len(vertices),len(solid_faces),len(holes)))


if __name__ == '__main__':
    build()
