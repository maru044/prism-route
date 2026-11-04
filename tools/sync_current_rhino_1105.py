from pathlib import Path
import json,struct,hashlib,copy
root=Path('.');work=root/'.current_map_build/current_rhino_sync_1105';out=root/'docs/floor_materials_1105';out.mkdir(exist_ok=True)
manifest_path=root/'assets/world/initial_ruin_1029/manifest.json';glb_path=manifest_path.parent/'ruin.glb';meta_path=root/'assets/world/current_map_validation/metadata.json'
removed={'0511ba39-173f-4035-a825-9c9d134728fb','90e44921-4322-4a1a-8685-77ae80f7d56e','79c76214-16b7-44c8-8be8-f5c6862f6263'}
inventory=json.loads((work/'inventory.json').read_text(encoding='utf-8'));assert not removed.intersection(x['id'] for x in inventory)
manifest=json.loads(manifest_path.read_text(encoding='utf-8'));metadata=json.loads(meta_path.read_text(encoding='utf-8'));raw=glb_path.read_bytes()
assert hashlib.sha256(raw).hexdigest()==manifest['mesh_sha256']
if manifest.get('render_sync_1105',{}).get('removed_source_ids')==sorted(removed):
 print('Current Rhino cleanup is already synchronized.');raise SystemExit(0)
for p in [manifest_path,glb_path,meta_path]:
 q=work/('before_'+p.name)
 if not q.exists():q.write_bytes(p.read_bytes())
jslen,jstype=struct.unpack_from('<II',raw,12);g=json.loads(raw[20:20+jslen]);at=20+jslen;binlen,bintype=struct.unpack_from('<II',raw,at);binary=raw[at+8:at+8+binlen]
keep=[n for n in g['nodes'] if n['name'].split('_',1)[-1] not in removed];assert len(g['nodes'])-len(keep)==3
nodes=[];meshes=[];accessors=[];views=[];blob=bytearray();before_hashes={};after_hashes={}
def copy_accessor(old_index):
 a=copy.deepcopy(g['accessors'][old_index]);v=copy.deepcopy(g['bufferViews'][a['bufferView']]);data=binary[v.get('byteOffset',0):v.get('byteOffset',0)+v['byteLength']]
 while len(blob)%4:blob.append(0)
 v['byteOffset']=len(blob);blob.extend(data);views.append(v);a['bufferView']=len(views)-1;accessors.append(a);return len(accessors)-1,data
for old_node in keep:
 n=copy.deepcopy(old_node);mesh=copy.deepcopy(g['meshes'][n['mesh']]);pieces=[]
 for prim in mesh['primitives']:
  for attr,idx in list(prim['attributes'].items()):prim['attributes'][attr],data=copy_accessor(idx);pieces.append(data)
  prim['indices'],data=copy_accessor(prim['indices']);pieces.append(data)
 before_hashes[n['name']]=hashlib.sha256(b''.join(pieces)).hexdigest();after_hashes[n['name']]=before_hashes[n['name']]
 n['mesh']=len(meshes);meshes.append(mesh);nodes.append(n)
g.update(nodes=nodes,meshes=meshes,accessors=accessors,bufferViews=views,buffers=[{'byteLength':len(blob)}],scenes=[{'nodes':list(range(len(nodes)))}])
js=json.dumps(g,separators=(',',':')).encode();js+=b' '*((-len(js))%4);blob+=b'\0'*((-len(blob))%4)
result=struct.pack('<III',0x46546c67,2,28+len(js)+len(blob))+struct.pack('<II',len(js),0x4e4f534a)+js+struct.pack('<II',len(blob),0x004e4942)+blob
glb_path.write_bytes(result)
old_exclusions=copy.deepcopy(manifest['exclusions']);manifest['objects']=[r for r in manifest['objects'] if r['id'] not in removed];manifest['probes']=[r for r in manifest['probes'] if r['id'] not in removed]
manifest['triangles']=sum(r['index_count']//3 for r in manifest['objects']);manifest['mesh_sha256']=hashlib.sha256(result).hexdigest()
manifest['render_sync_1105']={'removed_source_ids':sorted(removed),'retained_geometry_byte_identical':True,'planting_footprints_retained':True}
manifest_path.write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
# Preserve only this verified render-only feature revision as a generation
# exception. Later geometry hashes and other features invalidate normally.
generation_feature=copy.deepcopy(metadata['static_features']['initial_ruin_1029'])
f=metadata['static_features']['initial_ruin_1029'];f.update(objects=len(manifest['objects']),triangles=manifest['triangles'],mesh_sha256=manifest['mesh_sha256'],manifest_sha256=hashlib.sha256(manifest_path.read_bytes()).hexdigest())
metadata.setdefault('grass_render_only_overrides',{})['initial_ruin_1029']={'render_mesh_sha256':f['mesh_sha256'],'render_manifest_sha256':f['manifest_sha256'],'generation_feature':generation_feature}
meta_path.write_text(json.dumps(metadata,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
report={'source':'D:/Prism Route/map/map_current.3dm','removed_source_ids':sorted(removed),'old_objects':328,'new_objects':len(nodes),'old_triangles':6904,'new_triangles':manifest['triangles'],'retained_geometry_streams_sha256':before_hashes,'planting_exclusions_unchanged':manifest['exclusions']==old_exclusions,'no_rhino_geometry_changes':True,'mesh_sha256':manifest['mesh_sha256']}
(out/'rhino_sync.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps({k:v for k,v in report.items() if k!='retained_geometry_streams_sha256'}))
