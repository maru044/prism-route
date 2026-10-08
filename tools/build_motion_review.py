"""Bake the pinned CC0 clips to the current VRM bind skeleton (no Blender required).

Run inspect_motion_skeleton.gd first. Source bind transforms come from skin IBMs,
or the VRMA humanoid node hierarchy. Output uses absolute Godot bone poses.
"""
import json
import argparse
import math
import struct
from pathlib import Path
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
DEST = ROOT / 'assets/characters/motion_review'
WALK_PIVOT_FIX = {'A05', 'A39'}


def rotation(q):
    x, y, z, w = np.asarray(q) / np.linalg.norm(q)
    return np.array([[1-2*(y*y+z*z), 2*(x*y-z*w), 2*(x*z+y*w)],
                     [2*(x*y+z*w), 1-2*(x*x+z*z), 2*(y*z-x*w)],
                     [2*(x*z-y*w), 2*(y*z+x*w), 1-2*(x*x+y*y)]])


def quaternion(m):
    # Eigenvector method is stable at 180 degrees, unlike a trace-only formula.
    a, b, c = m[0]; d, e, f = m[1]; g, h, i = m[2]
    k = np.array([[a-e-i,b+d,c+g,h-f], [b+d,e-a-i,f+h,c-g],
                  [c+g,f+h,i-a-e,d-b], [h-f,c-g,d-b,a+e+i]]) / 3
    q = np.linalg.eigh(k)[1][:, -1]
    return q if q[3] >= 0 else -q


def transform(p, q, s=(1, 1, 1)):
    m = np.eye(4); m[:3, :3] = rotation(q) @ np.diag(s); m[:3, 3] = p
    return m


def worlds(local, parents):
    result = [None] * len(local)
    def get(i):
        if result[i] is None:
            result[i] = local[i] if parents[i] < 0 else get(parents[i]) @ local[i]
        return result[i]
    for i in range(len(local)): get(i)
    return result


def slerp(a, b, t):
    dot = np.dot(a, b)
    if dot < 0: b = -b; dot = -dot
    if dot > .9995:
        q = a + t*(b-a); return q / np.linalg.norm(q)
    angle = math.acos(np.clip(dot, -1, 1))
    return (math.sin((1-t)*angle)*a + math.sin(t*angle)*b) / math.sin(angle)


class Source:
    def __init__(self, path):
        raw = path.read_bytes(); offset = 12
        while offset < len(raw):
            size, kind = struct.unpack_from('<II', raw, offset); offset += 8
            chunk = raw[offset:offset+size]; offset += size
            if kind == 0x4e4f534a: self.g = json.loads(chunk)
            if kind == 0x004e4942: self.binary = chunk
        nodes = self.g['nodes']; self.parents = [-1] * len(nodes)
        for i, node in enumerate(nodes):
            for child in node.get('children', []): self.parents[child] = i
        self.local = [transform(n.get('translation',[0,0,0]), n.get('rotation',[0,0,0,1]), n.get('scale',[1,1,1])) for n in nodes]
        self.rest = worlds(self.local, self.parents)
        if self.g.get('skins'):
            skin = self.g['skins'][0]
            mesh_id = next(i for i,n in enumerate(nodes) if n.get('skin') == 0)
            matrices = self.accessor(skin['inverseBindMatrices'])
            for i, joint in enumerate(skin['joints']):
                self.rest[joint] = self.rest[mesh_id] @ np.linalg.inv(matrices[i].reshape(4,4).T)
            self.mapping = {}
            names = {'root':'Root','pelvis':'Hips','spine_01':'Spine','spine_02':'Chest','spine_03':'UpperChest','neck_01':'Neck','head':'Head'}
            for side, suffix in [('Left','l'),('Right','r')]:
                for src, target in [('clavicle','Shoulder'),('upperarm','UpperArm'),('lowerarm','LowerArm'),('hand','Hand'),('thigh','UpperLeg'),('calf','LowerLeg'),('foot','Foot'),('ball','Toes')]: names[f'{src}_{suffix}'] = side+target
                for finger, target in [('index','Index'),('middle','Middle'),('ring','Ring'),('pinky','Little'),('thumb','Thumb')]:
                    segments = ['Metacarpal','Proximal','Distal'] if finger == 'thumb' else ['Proximal','Intermediate','Distal']
                    for j, segment in enumerate(segments,1): names[f'{finger}_{j:02}_{suffix}'] = side+target+segment
            for i,n in enumerate(nodes):
                if n.get('name') in names: self.mapping[names[n['name']]] = i
        else:
            humanoid = self.g['extensions']['VRMC_vrm_animation']['humanoid']['humanBones']
            self.mapping = {name[0].upper()+name[1:]: data['node'] for name,data in humanoid.items()}

    def accessor(self, index):
        a = self.g['accessors'][index]; v = self.g['bufferViews'][a['bufferView']]
        assert a['componentType'] == 5126 and not a.get('sparse'), 'Expected dense float sampler'
        count = {'SCALAR':1,'VEC3':3,'VEC4':4,'MAT4':16}[a['type']]
        return np.ndarray((a['count'],count),dtype='<f4',buffer=self.binary,
                          offset=v.get('byteOffset',0)+a.get('byteOffset',0),
                          strides=(v.get('byteStride',count*4),4)).copy().astype(float)

    def prepare(self, action):
        name = action.get('clip_name')
        clip = next((a for a in self.g['animations'] if a.get('name','') == name), self.g['animations'][0] if not name else None)
        assert clip is not None, action
        channels=[]
        for channel in clip['channels']:
            sampler = clip['samplers'][channel['sampler']]
            assert sampler.get('interpolation','LINEAR') in ['LINEAR','STEP'], 'Unsupported interpolation'
            channels.append((channel['target']['node'],channel['target']['path'],self.accessor(sampler['input'])[:,0],self.accessor(sampler['output']),sampler.get('interpolation','LINEAR')))
        return channels, min(c[2][0] for c in channels), max(c[2][-1] for c in channels)

    def pose(self, channels, time):
        trs = [{k: n.get(k,default) for k,default in [('translation',[0,0,0]),('rotation',[0,0,0,1]),('scale',[1,1,1])]} for n in self.g['nodes']]
        for node,path,times,values,interp in channels:
            i = max(0,min(len(times)-2,int(np.searchsorted(times,time,side='right')-1)))
            j = min(i+1,len(times)-1)
            t = np.clip((time-times[i])/max(1e-9,times[j]-times[i]),0,1)
            value = values[i] if interp == 'STEP' else (slerp(values[i],values[j],t) if path == 'rotation' else values[i]*(1-t)+values[j]*t)
            trs[node][path] = value
        return worlds([transform(n['translation'],n['rotation'],n['scale']) for n in trs],self.parents)


def numbers(values):
    return ', '.join(f'{float(x):.8g}' for x in values)


def quat_multiply(a, b):
    xyz = a[3]*b[:3] + b[3]*a[:3] + np.cross(a[:3], b[:3])
    return np.r_[xyz, a[3]*b[3]-np.dot(a[:3], b[:3])]


def quat_log(q):
    q = q / np.linalg.norm(q)
    if q[3] < 0: q = -q
    norm = np.linalg.norm(q[:3])
    return q[:3]*2 if norm < 1e-10 else q[:3]*(2*math.atan2(norm,q[3])/norm)


def quat_exp(vector):
    angle = np.linalg.norm(vector)
    if angle < 1e-10: return np.r_[vector/2,1.0]
    return np.r_[vector*(math.sin(angle/2)/angle),math.cos(angle/2)]


def close_periodic_values(times, original):
    """Join pose and discrete tangent in short windows around the loop seam.

    Both endpoints use their midpoint and mean velocity. Cubic Hermite curves
    connect them to the unchanged interior, rather than adding a held end frame.
    """
    values = np.asarray(original).copy()
    window = min(0.16, times[-1]*0.18)
    edge = max(3, int(np.searchsorted(times,window)))
    edge = min(edge,(len(times)-1)//2)
    start_velocity = (values[1]-values[0])/(times[1]-times[0])
    end_velocity = (values[-1]-values[-2])/(times[-1]-times[-2])
    seam = (values[0]+values[-1])/2
    velocity = (start_velocity+end_velocity)/2
    def hermite(t,p0,p1,v0,v1,duration):
        return ((2*t**3-3*t**2+1)*p0 + (t**3-2*t**2+t)*duration*v0
                + (-2*t**3+3*t**2)*p1 + (t**3-t**2)*duration*v1)
    left_velocity = (values[edge+1]-values[edge-1])/(times[edge+1]-times[edge-1])
    right = len(times)-1-edge
    right_velocity = (values[right+1]-values[right-1])/(times[right+1]-times[right-1])
    for i in range(edge+1):
        values[i] = hermite(times[i]/times[edge],seam,original[edge],velocity,left_velocity,times[edge])
    duration = times[-1]-times[right]
    for i in range(right,len(times)):
        values[i] = hermite((times[i]-times[right])/duration,original[right],seam,right_velocity,velocity,duration)
    # Godot's baked tracks use linear/spherical interpolation. Match the actual
    # one-sided segment slopes, not only the analytical Hermite endpoint tangent.
    values[0] = values[-1] = seam
    values[1] = seam+velocity*(times[1]-times[0])
    values[-2] = seam-velocity*(times[-1]-times[-2])
    return values


def close_walk_loop(times, rotations, positions):
    closed = {}
    for bone, quaternions in rotations.items():
        reference = np.asarray(quaternions[0])
        inverse = reference*np.array([-1,-1,-1,1])
        vectors = np.array([quat_log(quat_multiply(inverse,np.asarray(q))) for q in quaternions])
        assert np.max(np.linalg.norm(vectors,axis=1)) < math.pi, 'Quaternion log branch crossed'
        vectors = close_periodic_values(times,vectors)
        closed[bone] = [quat_multiply(reference,quat_exp(v)) for v in vectors]
        closed[bone][-1] = closed[bone][0].copy()
    return closed, close_periodic_values(times,np.asarray(positions))


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--target', type=Path, default=ROOT/'.godot/motion_target_rest.json')
    parser.add_argument('--dest', type=Path, default=DEST)
    parser.add_argument('--ids', help='Comma-separated manifest IDs; default is all 42')
    args = parser.parse_args()
    destination = args.dest
    manifest = json.loads((ROOT/'docs/MOTION_DOWNLOAD_MANIFEST.json').read_text(encoding='utf8'))
    target = json.loads(args.target.read_text(encoding='utf8'))
    if args.ids:
        requested = set(args.ids.split(','))
        available = {a['id'] for a in manifest['actions']}
        assert requested <= available, f'Unknown action IDs: {requested-available}'
        manifest['actions'] = [a for a in manifest['actions'] if a['id'] in requested]
    bones = target['bones']; parents = [b['parent'] for b in bones]
    local = [transform(b['position'],b['rotation'],b['scale']) for b in bones]
    rest = worlds(local,parents); indices = {b['name']:i for i,b in enumerate(bones)}
    sources = {f['id']:Source(ROOT/'assets/characters/motion_sources/independent_cc0'/f['file']) for f in manifest['files']}
    destination.mkdir(parents=True,exist_ok=True); metadata=[]
    for action in manifest['actions']:
        src = sources[action['file_id']]; channels,start,end = src.prepare(action)
        length=end-start; times=np.linspace(0,length,max(2,math.ceil(length*30)+1))
        mapping={indices[n]:j for n,j in src.mapping.items() if n in indices and 'Eye' not in n}
        hips=indices['Hips']; ship=src.mapping['Hips']; scale=rest[hips][1,3]/src.rest[ship][1,3]
        target_center = (rest[indices['LeftUpperLeg']][:3,3] + rest[indices['RightUpperLeg']][:3,3]) / 2
        source_center = (src.rest[src.mapping['LeftUpperLeg']][:3,3] + src.rest[src.mapping['RightUpperLeg']][:3,3]) / 2
        pelvis_scale = target_center[1] / source_center[1]
        pivot_difference = pelvis_scale * (source_center-src.rest[ship][:3,3]) - (target_center-rest[hips][:3,3])
        global_hips = []
        rotations={i:[] for i in mapping}; positions=[]
        for time in times:
            pose=src.pose(channels,start+time); output=[None]*len(bones)
            def solve(i):
                if output[i] is not None: return output[i]
                parent=np.eye(4) if parents[i]<0 else solve(parents[i])
                value=parent@local[i]
                if i in mapping:
                    j=mapping[i]; desired=pose[j][:3,:3]@np.linalg.inv(src.rest[j][:3,:3])@rest[i][:3,:3]
                    # Strip any authored scaling; preserve the target mesh proportions.
                    u,_,vt=np.linalg.svd(desired); value[:3,:3]=u@vt
                    if i==hips:
                        value[:3,3]=rest[i][:3,3]+(pose[j][:3,3]-src.rest[j][:3,3])*scale
                        if action['id'] in WALK_PIVOT_FIX:
                            # The MMD Hips pivot lies ~24 cm below the leg roots.
                            # Align the anatomical pelvis in X/Z instead of rotating
                            # this extra lever arm; retain the accepted vertical motion.
                            delta_rotation = pose[j][:3,:3] @ np.linalg.inv(src.rest[j][:3,:3])
                            corrected = rest[i][:3,3] + (pose[j][:3,3]-src.rest[j][:3,3])*pelvis_scale + (delta_rotation-np.eye(3))@pivot_difference
                            value[[0,2],3] = corrected[[0,2]]
                        global_hips.append(value[:3,3].copy())
                    relative=np.linalg.inv(parent)@value
                    q=quaternion(relative[:3,:3])
                    if rotations[i] and np.dot(q,rotations[i][-1])<0: q=-q
                    rotations[i].append(q)
                    if i==hips: positions.append(relative[:3,3].copy())
                output[i]=value; return value
            for i in range(len(bones)): solve(i)
        assert all(np.isfinite(q).all() for rows in rotations.values() for q in rows)
        if action['id'] in WALK_PIVOT_FIX:
            rotations, positions = close_walk_loop(times,rotations,positions)
        lines=['[gd_resource type="Animation" format=3]','', '[resource]',f'resource_name = "{action["id"]}"',f'length = {length:.8g}']
        tracks=[(i,'rotation_3d',qs) for i,qs in rotations.items()]+[(hips,'position_3d',positions)]
        for track,(i,kind,values) in enumerate(tracks):
            path=target['path']+':'+bones[i]['name']
            keys = np.column_stack((times, np.ones(len(times)), np.asarray(values)))
            wrap = 'true' if action['id'] in WALK_PIVOT_FIX else 'false'
            lines += [f'tracks/{track}/type = "{kind}"',f'tracks/{track}/path = NodePath("{path}")',f'tracks/{track}/interp = 1',f'tracks/{track}/loop_wrap = {wrap}',f'tracks/{track}/keys = PackedFloat32Array('+numbers(keys.ravel())+')']
        (destination/f'{action["id"]}.tres').write_text('\n'.join(lines)+'\n',encoding='utf8')
        entry = dict(action,status="retarget_baked_review_pending",duration=length,tracks=len(tracks),frames=len(times),retarget_hip_scale=scale)
        if action['id'] in WALK_PIVOT_FIX:
            entry.update(horizontal_pelvis_scale=pelvis_scale,
                         in_place_anchor_xz=np.mean(global_hips,axis=0)[[0,2]].tolist(),
                         loop_closure='matched_endpoints_and_segment_velocity_short_hermite_windows')
            if destination.resolve() == DEST.resolve():
                entry.update(before_walk_fix_path=f'res://assets/characters/motion_review/archive/{action["id"]}_before_walk_fix.tres',
                             before_loop_fix_path=f'res://assets/characters/motion_review/archive/{action["id"]}_before_loop_fix.tres')
        metadata.append(entry)
        print(action['id'],action['label_zh'],round(length,3),len(tracks),flush=True)
    (destination/'catalog.json').write_text(json.dumps(metadata,ensure_ascii=False,indent=2)+'\n',encoding='utf8')


if __name__ == '__main__': main()
