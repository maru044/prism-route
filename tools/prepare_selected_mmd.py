"""Resolve the user-authored shortlist into immutable source-role build jobs."""
import hashlib
import json
from pathlib import Path
import re
import shutil

ROOT=Path(__file__).resolve().parents[1]
CACHE=ROOT/'.model_import_build/mmd_selected'


def digest(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def key(value):return hashlib.sha256(json.dumps(value,ensure_ascii=False).encode('utf-8')).hexdigest()[:20]


def main():
    readme=ROOT/'docs/motion_selection/README.md';text=readme.read_text(encoding='utf-8')
    catalog=json.loads((ROOT/'tools/mmd_preview/catalog.json').read_text(encoding='utf-8'))
    config=json.loads((ROOT/'tools/mmd_preview/preview_config.json').read_text(encoding='utf-8'))
    source=Path(catalog['source_root']);files={r['file']:r for r in catalog['files']}
    packs=[];decision=None
    for block in re.split(r'(?=^## |^### |^#### )',text,flags=re.M):
        if block.startswith('## 二、'):decision='KEEP'
        elif block.startswith('## 三、'):decision='MAYBE'
        elif block.startswith('## 六、'):decision='KEEP'
        elif block.startswith('## '):decision=None
        if not (block.startswith('### ') or block.startswith('#### ')) or decision is None:continue
        if '**目录 / 来源**' not in block:continue
        folder=re.search(r'\*\*目录 / 来源\*\*：`([^`]+)`',block).group(1)
        interval=re.search(r'\*\*帧区间\*\*：\s*(\d+)\s*~\s*(\d+)',block)
        start,end=map(int,interval.groups());roles=[]
        for slot,name in re.findall(r'Slot ([ABC]):\s*`([^`]+)`',block):
            relative=folder+'/'+name
            row=files[relative];path=source/relative
            assert digest(path)==row['sha256'],relative
            assert not row['missing_controls'],relative
            role={'id':slot,'source_file':relative,'source_path':str(path),'source_sha256':row['sha256'],
                  'source_frame_end':row['bone_end'],'reference':'B' if slot=='B' else 'A'}
            roles.append(role)
        assert roles and len({r['id'] for r in roles})==len(roles)
        pid='mmd_'+hashlib.sha256(folder.encode('utf-8')).hexdigest()[:12]
        pack={'id':pid,'label':folder,'decision':decision,'frame_start':start,'frame_end':end,'fps':30,'duration':(end-start)/30,
              'roles':roles,'loop_policy':'manual_preview_only; no source seam modification','translation_policy':'shared_world'}
        for role in roles:
            role['clip_id']=pid+'_'+role['id'].lower()
            if folder=='Loop 03':
                role['reused_resource']='res://assets/characters/mmd_validation/shared/shared_mmd_role_'+role['id'].lower()+'.tres'
                role['reused_reference']='res://assets/characters/mmd_validation/shared/shared_mmd_role_'+role['id'].lower()+'_reference.json'
            else:role['baked_glb']=str(CACHE/(role['clip_id']+'.glb'))
        packs.append(pack)
    assert sum(p['decision']=='KEEP' for p in packs)==19
    assert sum(len(p['roles']) for p in packs if p['decision']=='KEEP')==38
    assert sum(p['decision']=='MAYBE' for p in packs)==2
    CACHE.mkdir(parents=True,exist_ok=True)
    plan={'schema':1,'readme_sha256':digest(readme),'source_root':str(source),'reference_models':config['reference_models'],
          'reference_model_sha256':{r:digest(Path(p)) for r,p in config['reference_models'].items()},'packs':packs}
    (CACHE/'plan.json').write_text(json.dumps(plan,ensure_ascii=False,indent=2),encoding='utf-8')
    jobs=[]
    for pack in packs:
        if pack['decision']!='KEEP':continue
        for role in pack['roles']:
            if 'reused_resource' not in role:jobs.append({**role,'pack':pack['id'],'frame_start':pack['frame_start'],'frame_end':pack['frame_end']})
    assert len(jobs)==36
    (CACHE/'jobs.json').write_text(json.dumps({**plan,'jobs':jobs},ensure_ascii=False,indent=2),encoding='utf-8')
    selection_path=ROOT/'docs/motion_selection/mmd_source_selection.json'
    backup=selection_path.with_name('mmd_source_selection.before_import_20261103.json')
    if not backup.exists():shutil.copy2(selection_path,backup)
    takes={}
    for pack in packs:
        ids=[(r['id'],hashlib.sha256(r['source_file'].encode('utf-8')).hexdigest()[:16]) for r in pack['roles']]
        source_key=key(ids);take=key([source_key,pack['frame_start'],pack['frame_end']])
        takes[take]={'id':take,'source_key':source_key,'folder_id':hashlib.sha256(pack['label'].encode('utf-8')).hexdigest()[:16],
                     'source_folder':pack['label'],'decision':pack['decision'],'roles':[{'slot':r['id'],'file':r['source_file'],'sha256':r['source_sha256']} for r in pack['roles']],
                     'fps':30,'frame_start':pack['frame_start'],'frame_end':pack['frame_end'],'note':'README confirmed shortlist; first-listed partner variant.',
                     'rough_special_preview':False,'authority':'docs/motion_selection/README.md','reference_models':config['reference_models']}
    selection_path.write_text(json.dumps({'schema':1,'source_root':str(source),'takes':takes},ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print(json.dumps({'keep_groups':19,'shared_tracks':38,'reuse_tracks':2,'new_jobs':36,'maybe_groups':2,'selection_backup':str(backup)}))


if __name__=='__main__':main()
