"""Read back the GLB emitted by the browser; do not modify any geometry."""
from pathlib import Path
import json, struct, hashlib
import numpy as np

ROOT=Path(__file__).resolve().parent
path=ROOT/'exports/web-curved-architecture-v01.glb'
raw=path.read_bytes()
magic,version,length=struct.unpack_from('<III',raw)
assert magic==0x46546C67 and version==2 and length==len(raw)
json_length,json_type=struct.unpack_from('<II',raw,12)
document=json.loads(raw[20:20+json_length])
binary_offset=20+json_length
binary_length,binary_type=struct.unpack_from('<II',raw,binary_offset)
binary=raw[binary_offset+8:binary_offset+8+binary_length]
types={5126:np.dtype('<f4'),5125:np.dtype('<u4'),5123:np.dtype('<u2'),5121:np.dtype('u1')}
widths={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4,'MAT4':16}
def accessor(number):
    a=document['accessors'][number];v=document['bufferViews'][a['bufferView']]
    dtype=types[a['componentType']];width=widths[a['type']]
    offset=v.get('byteOffset',0)+a.get('byteOffset',0)
    stride=v.get('byteStride',dtype.itemsize*width)
    return np.ndarray((a['count'],width),dtype=dtype,buffer=binary,offset=offset,strides=(stride,dtype.itemsize)).copy()

reports=[]
for mesh_number,mesh in enumerate(document['meshes']):
    for primitive in mesh['primitives']:
        vertices=accessor(primitive['attributes']['POSITION'])
        faces=accessor(primitive['indices']).reshape(-1,3).astype(np.int64)
        assert np.isfinite(vertices).all()
        assert faces.min()>=0 and faces.max()<len(vertices)
        source_vertex_count=len(vertices)
        # glTF intentionally duplicates positions along UV/normal seams.
        # Audit positional topology without editing the exported mesh.
        _,first,remap=np.unique(np.round(vertices,5),axis=0,return_index=True,return_inverse=True)
        vertices=vertices[first];faces=remap[faces]
        edges=np.concatenate([faces[:,[0,1]],faces[:,[1,2]],faces[:,[2,0]]])
        edges.sort(axis=1);unique,counts=np.unique(edges,axis=0,return_counts=True)
        boundary_ids=np.unique(unique[counts==1])
        boundary_points=vertices[boundary_ids]
        cross=np.cross(vertices[faces[:,1]]-vertices[faces[:,0]],vertices[faces[:,2]]-vertices[faces[:,0]])
        areas=np.linalg.norm(cross,axis=1)*.5
        parent=np.arange(len(vertices));rank=np.zeros(len(vertices),dtype=np.int8)
        def root(i):
            while parent[i]!=i:
                parent[i]=parent[parent[i]];i=parent[i]
            return i
        for a,b in unique:
            a=root(a);b=root(b)
            if a==b:continue
            if rank[a]<rank[b]:a,b=b,a
            parent[b]=a
            if rank[a]==rank[b]:rank[a]+=1
        used=np.unique(faces)
        component_sizes={}
        for i in used:
            r=root(i);component_sizes[r]=component_sizes.get(r,0)+1
        normals=accessor(primitive['attributes']['NORMAL'])
        norm=np.linalg.norm(normals,axis=1)
        node_names=[n.get('name','unnamed') for n in document.get('nodes',[]) if n.get('mesh')==mesh_number]
        reports.append({'name':','.join(node_names) or mesh.get('name','unnamed'),'vertices':source_vertex_count,'topology_vertices':len(vertices),'triangles':len(faces),
            'bounds_min':vertices.min(axis=0).tolist(),'bounds_max':vertices.max(axis=0).tolist(),
            'finite_positions_and_normals':bool(np.isfinite(normals).all()),
            'boundary_edges':int((counts==1).sum()),'nonmanifold_edges':int((counts>2).sum()),
            'boundary_bounds':None if not len(boundary_points) else [boundary_points.min(axis=0).tolist(),boundary_points.max(axis=0).tolist()],
            'degenerate_triangles':int((areas<1e-8).sum()),'connected_components':len(component_sizes),
            'component_vertex_counts':sorted(component_sizes.values(),reverse=True),
            'minimum_normal_length':float(norm.min())})
report={'file':str(path),'sha256':hashlib.sha256(raw).hexdigest(),'bytes':len(raw),
        'architecture':reports,'total_triangles':sum(r['triangles'] for r in reports),
        'limitations':'Topology readback only. Components may overlap across meshes; curvature, self-intersection, visual reference fidelity and full road/game collision are not certified.'}
(ROOT/'exports/mesh-audit.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps(report,ensure_ascii=False))
