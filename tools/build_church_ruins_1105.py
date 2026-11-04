# -*- coding: utf-8 -*-
"""Package native Church Ruins into GLB without touching existing tree assets."""
from pathlib import Path
import json, struct, hashlib
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
CACHE = ROOT / '.current_map_build/church_ruins_1105'
OUT = ROOT / 'assets/world/church_ruins_1105'

def world(p):
    return [p[0] - 1450.0, p[2], 1150.0 - p[1]]

def world_dir(d):
    return [d[0], d[2], -d[1]]

def build():
    OUT.mkdir(parents=True, exist_ok=True)
    source = json.loads((CACHE / 'source.json').read_text(encoding='utf-8'))
    raw = (CACHE / 'source.bin').read_bytes()
    
    blob = bytearray()
    views = []
    accessors = []
    meshes = []
    nodes = []

    def array(data, component, shape, target, bounds=False):
        while len(blob) % 4:
            blob.append(0)
        data = np.ascontiguousarray(data)
        offset = len(blob)
        blob.extend(data.tobytes())
        views.append(dict(buffer=0, byteOffset=offset, byteLength=data.nbytes, target=target))
        item = dict(bufferView=len(views) - 1, componentType=component, count=len(data), type=shape)
        if bounds:
            item.update(min=data.min(0).astype(float).tolist(), max=data.max(0).astype(float).tolist())
        accessors.append(item)
        return len(accessors) - 1

    for row in source['objects']:
        n = row['vertex_count']
        p = np.frombuffer(raw, '<f4', count=n * 3, offset=row['offset']).reshape(-1, 3).copy()
        p -= np.array(source['native_center'], dtype='<f4')
        p = p[:, [0, 2, 1]]
        p[:, 2] *= -1.0

        normal = np.frombuffer(raw, '<f4', count=n * 3, offset=row['normal_offset']).reshape(-1, 3).copy()
        normal = normal[:, [0, 2, 1]]
        normal[:, 2] *= -1.0

        indices = np.frombuffer(raw, '<u4', count=row['index_count'], offset=row['offset'] + n * 12)

        assert np.isfinite(p).all() and np.isfinite(normal).all()

        attrs = {
            'POSITION': array(p, 5126, 'VEC3', 34962, True),
            'NORMAL': array(normal, 5126, 'VEC3', 34962)
        }
        meshes.append(dict(primitives=[dict(attributes=attrs, indices=array(indices, 5125, 'SCALAR', 34963), mode=4)]))
        node_name = row['name'] if (row['category'] == 'collision_helpers' or row['name'].endswith('-colonly')) else row['kind'] + '_' + row['id']
        nodes.append(dict(name=node_name, mesh=len(meshes) - 1))

    gltf = dict(
        asset=dict(version='2.0', generator='Prism Route Church Ruins Exporter'),
        scene=0,
        scenes=[dict(nodes=list(range(len(nodes))))],
        nodes=nodes,
        meshes=meshes,
        buffers=[dict(byteLength=len(blob))],
        bufferViews=views,
        accessors=accessors
    )

    text = json.dumps(gltf, separators=(',', ':')).encode()
    text += b' ' * ((-len(text)) % 4)
    blob += b'\0' * ((-len(blob)) % 4)

    output = (
        struct.pack('<III', 0x46546c67, 2, 12 + 8 + len(text) + 8 + len(blob)) +
        struct.pack('<II', len(text), 0x4e4f534a) +
        text +
        struct.pack('<II', len(blob), 0x004e4942) +
        blob
    )

    glb_path = OUT / 'church.glb'
    glb_path.write_bytes(output)

    source['spawn_godot'] = world(source['spawn'])
    source['spawn_look_direction_godot'] = world_dir(source['spawn_look_direction'])
    source['spawn_source_id'] = "341ed473-83dd-4ec6-90c5-e9ab0f4cc316"
    source.update(
        triangles=sum(r['index_count'] // 3 for r in source['objects']),
        mesh_sha256=hashlib.sha256(output).hexdigest(),
        glb_bytes=len(output)
    )

    (OUT / 'manifest.json').write_text(json.dumps(source, ensure_ascii=False, indent=2), encoding='utf-8')
    print(json.dumps({
        'objects': len(nodes),
        'triangles': source['triangles'],
        'glb_bytes': len(output),
        'spawn_godot': source['spawn_godot']
    }))

if __name__ == '__main__':
    build()
