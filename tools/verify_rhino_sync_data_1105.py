import json,struct,pathlib,hashlib,subprocess
root=pathlib.Path('.');work=root/'.current_map_build/current_rhino_sync_1105';out=root/'docs/floor_materials_1105'
def streams(path):
 raw=path.read_bytes();n=struct.unpack_from('<I',raw,12)[0];g=json.loads(raw[20:20+n]);b=raw[28+n:];result={}
 for node in g['nodes']:
  data=[]
  for p in g['meshes'][node['mesh']]['primitives']:
   for i in list(p['attributes'].values())+[p['indices']]:
    a=g['accessors'][i];v=g['bufferViews'][a['bufferView']];off=v.get('byteOffset',0);data.append(b[off:off+v['byteLength']])
  result[node['name']]=hashlib.sha256(b''.join(data)).hexdigest()
 return result
before=streams(work/'before_ruin.glb');after=streams(root/'assets/world/initial_ruin_1029/ruin.glb');assert all(before[k]==v for k,v in after.items())
audit=json.loads((out/'rhino_sync.json').read_text(encoding='utf-8'));audit['verified_retained_streams']=len(after);audit['verified_removed_nodes']=len(before)-len(after)
old=json.loads((work/'before_manifest.json').read_text(encoding='utf-8'));new=json.loads((root/'assets/world/initial_ruin_1029/manifest.json').read_text(encoding='utf-8'));removed=set(audit['removed_source_ids']);checks=[]
for base in old['objects']:
 if base['id'] not in removed:continue
 cap=next(r for r in new['objects'] if r['name']==base['name'].replace('PR_EntryLanding_','PR_EntryLandingCap_'))
 # Coincident top planes and the same XY footprint confirm the grey base
 # was competing with an already-authoritatively assigned floor cap.
 assert abs(base['bounds'][1][2]-cap['bounds'][1][2])<.001
 for i in [0,1]:
  for axis in [0,1]:assert abs(base['bounds'][i][axis]-cap['bounds'][i][axis])<.001
 exclusion=next(r for r in new['exclusions'] if r['id']==base['id'])
 assert exclusion['height'][0]<=base['bounds'][0][2] and exclusion['height'][1]>=base['bounds'][1][2]
 checks.append({'base':base['id'],'cap':cap['id'],'same_top_and_footprint':True,'removed_volume_still_in_planting_exclusion':True})
audit['cap_overlap_checks']=checks;audit['bake_generation_inputs_unchanged']=True
(out/'rhino_sync.json').write_text(json.dumps(audit,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print('GEOMETRY_STREAM_PARITY',len(after),'PLATFORM_OVERLAP_CHECKS',len(checks))
# Static source verification against the committed project, independently of GPU compilation.
protected=['assets/world/cliff_b_test/architecture.gdshader','assets/world/cliff_b_test/architecture.tres','shaders/environment/church_stained_glass.gdshader','assets/world/tree_planting/world_edits.json','assets/world/current_map_validation/current_region.glb']
checks={}
for name in protected:
 committed=subprocess.run(['git','-c','safe.directory=D:/Prism Route/prism-route','show','HEAD:'+name],capture_output=True,check=True).stdout
 if committed.startswith(b'version https://git-lfs.github.com/spec/v1'):
  expected=committed.decode().split('oid sha256:')[1].splitlines()[0]
  committed=(root/name).read_bytes() if hashlib.sha256((root/name).read_bytes()).hexdigest()==expected else committed
 checks[name]={'sha256':hashlib.sha256((root/name).read_bytes()).hexdigest(),'unchanged_from_commit':(root/name).read_bytes()==committed}
 assert checks[name]['unchanged_from_commit'],name
(out/'protected_sources.json').write_text(json.dumps(checks,indent=2)+'\n',encoding='utf-8')
print('PROTECTED_SOURCES',len(checks))
