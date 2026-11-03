"""Create a lightweight read-only source browser index; never selects/bakes clips."""
import hashlib
import json
import re
import sys
from collections import defaultdict
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'tools/mmd_preview'
AUDIT=ROOT/'docs/research/mmd_batch_20261103'


def stable_id(value):return hashlib.sha256(value.encode('utf-8')).hexdigest()[:16]


def main():
    sys.stdout.reconfigure(encoding='utf-8')
    summary=json.loads((AUDIT/'summary.json').read_text(encoding='utf-8'))
    source=Path(summary['source'])
    rows=json.loads((AUDIT/'files.json').read_text(encoding='utf-8'))
    dependencies=json.loads((AUDIT/'text_dependencies.json').read_text(encoding='utf-8'))
    files=[];by_folder=defaultdict(list)
    for row in rows:
        if row['kind'] not in ['body_motion','body_pose']:continue
        item={k:row[k] for k in ['file','folder','family','model','bone_start','bone_end','kind','sha256','bytes']}
        item['id']=stable_id(row['file'])
        item['label']=Path(row['file']).stem
        item['missing_controls']=sorted(set(row['coverage']['keqing']['required_control_missing']+row['coverage']['ganyu']['required_control_missing']))
        item['special_ik']=bool(item['missing_controls'])
        item['mtime_ns']=(source/row['file']).stat().st_mtime_ns
        files.append(item);by_folder[row['folder']].append(item)
    folders=[]
    for folder,items in sorted(by_folder.items()):
        primary=sorted(items,key=lambda r:(r['special_ik'],r['family']!='Izumi',r['label'].lower()))[0]
        partners=[r for r in items if r['family']!=primary['family']]
        partners.sort(key=lambda r:(r['special_ik'],r['bone_end']!=primary['bone_end'],abs(r['bone_end']-primary['bone_end']),r['label'].lower()))
        defaults=[primary['id'],partners[0]['id'] if partners else 'NONE','NONE']
        flags=[]
        if len(items)>2:flags.append('variants_or_multiple_clips')
        if len({r['bone_end'] for r in items})>1:flags.append('different_track_lengths')
        if any(r['special_ik'] for r in items):flags.append('contains_special_controls')
        auxiliaries=[r['file'] for r in rows if r['folder']==folder and r['kind']=='prop_or_auxiliary']
        if auxiliaries:flags.append('requires_prop_preview_omits')
        docs=[d for d in dependencies if d['file'].startswith(folder+'/') and d['flags']]
        if any('arm_ik_dependency' in d['flags'] for d in docs):flags.append('author_external_parent')
        if folder.startswith('Loop 27 '):
            other=[r for r in items if r['id'] not in defaults[:2]]
            if other:defaults[2]=other[0]['id']
            flags.append('three_role_candidate')
        if folder=='Motorcycle Photoshoot 2nd pose':flags.append('static_third_role_candidate')
        folders.append({'id':stable_id(folder),'folder':folder,'label':folder,'files':[r['id'] for r in items],
                        'suggested_roles':defaults,'flags':flags,'author_documents':[d['file'] for d in docs]})
        folders[-1]['auxiliary_files']=auxiliaries
    catalog={'schema':1,'source_root':str(source),'fps':30,'source_vmd_files':summary['vmd_parsed'],
             'body_files':len(files),'folder_count':len(folders),'files':files,'folders':folders,
             'grouping_policy':'Folders are candidates, not confirmed performances; role choices require review.'}
    OUT.mkdir(parents=True,exist_ok=True)
    (OUT/'catalog.json').write_text(json.dumps(catalog,ensure_ascii=False,indent=2),encoding='utf-8')
    config={'schema':1,'project_root':str(ROOT),'catalog':str(OUT/'catalog.json'),
            'selection_file':str(ROOT/'docs/motion_selection/mmd_source_selection.json'),
            'preview_blend':str(ROOT.parent/'research/mmd_source_preview_20261103/mmd_source_browser.blend'),
            'reference_scale':.08,'reference_models':{
                'A':'D:/模型/20261008/刻晴_by_原神_b0f08721a7da17df599896ac40dd2f22/刻晴/刻晴/刻晴.pmx',
                'B':'D:/模型/ganyu_by_原神_7381ccd84ee8763ce63b3ad638e1c49b/甘雨.pmx'}}
    for path in config['reference_models'].values():assert Path(path).is_file(),path
    (OUT/'preview_config.json').write_text(json.dumps(config,ensure_ascii=False,indent=2),encoding='utf-8')
    print(json.dumps({'body_files':len(files),'folder_candidates':len(folders),'source_vmd_files':summary['vmd_parsed'],
                      'selection_file_modified':False,'formal_bakes':0},ensure_ascii=False))


if __name__=='__main__':main()
