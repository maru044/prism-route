"""Read-only source audit for MMD batch planning; never imports or converts assets."""
import argparse
import hashlib
import json
import re
import struct
import time
import sys
import unicodedata
from collections import Counter, defaultdict
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[1]
BONE = np.dtype([('name','S15'),('frame','<u4'),('pos','<f4',(3,)),('rot','<f4',(4,)),('interp','u1',(64,))])
MORPH = np.dtype([('name','S15'),('frame','<u4'),('weight','<f4')])
CAMERA = np.dtype([('frame','<u4'),('values','<f4',(7,)),('interp','u1',(24,)),('fov','<u4'),('persp','u1')])
LIGHT = np.dtype([('frame','<u4'),('values','<f4',(6,))])
SHADOW = np.dtype([('frame','<u4'),('mode','u1'),('distance','<f4')])


def decode(raw):
    """Match installed MMD Tools' CP932 error-flag and 15-byte handling."""
    raw=bytes(raw)
    terminator=raw.find(b'\0',1)
    if terminator>=0:raw=raw[:terminator]
    if not raw:return ''
    if raw[:1]==b'\0':return '\ufffd'+raw[1:].decode('cp932',errors='replace').replace('?','\ufffd')
    return raw.decode('cp932',errors='replace')


def normalized(name):return unicodedata.normalize('NFKC',name)


def category(name):
    n=normalized(name)
    if re.search(r'腕.*IK|IK.*腕|arm.*ik|ik.*arm',n,re.I):return 'arm_ik'
    if n in ['全ての親','センター','センター2','グルーブ','グルーブ2','腰','操作中心']:return 'root'
    if re.search(r'^(下半身|上半身[0-9]*|首|頭)$',n):return 'torso'
    if re.search(r'^[左右](肩|腕|ひじ|肘|手首)$',n):return 'arm'
    if re.search(r'^[左右](肩|腕|ひじ|肘|手首)\+$',n):return 'arm_extension'
    if re.search(r'^[左右](足|ひざ|膝|足首|つま先)(?:D|EX|IK|IK親)?$',n):return 'leg'
    if any(x in n for x in ['捩','Twist','twist']):return 'twist_aux'
    if any(x in n for x in ['親指','人指','人差','中指','薬指','小指']):return 'finger'
    if any(x in n for x in ['目','眼','瞳','舌','jaw','Jaw']):return 'face_eye'
    if any(x in n for x in ['发','髪','発','袖','スカート','裙','摆','擺','带','帶','流苏','流蘇','アホ毛']):return 'hair_clothes'
    return 'model_specific'


def family(tag):
    value=normalized(tag).lower()
    for key,label in [('izumi','Izumi'),('maran','Maran'),('sin sack','SinSack'),('sin_sack','SinSack'),('kaat','Kaat'),('david','David'),('ディビット','David')]:
        if key in value:return label
    return tag or '(empty)'


def profile_sets():
    paths={'keqing':ROOT.parent/'research/mmd_validation_20261103/source_bones.json',
           'ganyu':ROOT/'assets/characters/mmd_validation/paired/role_b_source_bones.json'}
    result={}
    for name,path in paths.items():
        document=json.loads(path.read_text(encoding='utf-8'))
        pairs=document['bones'] if isinstance(document.get('bones'),list) else document.get('names',[])
        result[name]={pair[1] or pair[0] for pair in pairs}
    return result


def analyze(path,root,profiles):
    raw=path.read_bytes()
    assert raw.startswith(b'Vocaloid Motion Data 0002'),'unsupported signature'
    assert len(raw)>=54,'short header'
    offset=50
    sections={}
    blocks={}
    def read(name,dtype,required=False):
        nonlocal offset
        begin=offset
        if offset==len(raw) and not required:
            sections[name]=np.empty(0,dtype=dtype)
            blocks[name]=b''
            return
        if offset+4>len(raw):raise ValueError('truncated '+name+' count')
        count=struct.unpack_from('<I',raw,offset)[0]
        offset+=4
        end=offset+count*dtype.itemsize
        if end>len(raw):raise ValueError('truncated '+name+' records')
        sections[name]=np.frombuffer(raw,dtype=dtype,count=count,offset=offset)
        offset=end
        blocks[name]=raw[begin:end]
    for name,dtype in [('bone',BONE),('morph',MORPH),('camera',CAMERA),('light',LIGHT),('shadow',SHADOW)]:
        read(name,dtype,required=name in ['bone','morph'])
    property_begin=offset
    property_frames=[]
    visibility=[]
    ik_states=defaultdict(list)
    if offset<len(raw):
        count=struct.unpack_from('<I',raw,offset)[0]
        offset+=4
        for _ in range(count):
            frame,visible,ik_count=struct.unpack_from('<IBI',raw,offset)
            offset+=9
            property_frames.append(frame)
            visibility.append(visible)
            for _ in range(ik_count):
                if offset+21>len(raw):raise ValueError('truncated IK state')
                name=decode(raw[offset:offset+15])
                ik_states[name].append((frame,raw[offset+20]))
                offset+=21
    if offset>len(raw):raise ValueError('truncated property section')
    bones=sections['bone']
    names=[]
    dynamic=[]
    nonidentity=[]
    per_bone=[]
    duplicate_keys=0
    conflicting_duplicate_keys=0
    quaternion_zero=0
    nonfinite=0
    root_span=0.0
    bone_key_counts={}
    if len(bones):
        unique,first,inverse=np.unique(bones['name'],return_index=True,return_inverse=True)
        names=[decode(n) for n in unique]
        positions=bones['pos'].astype(np.float64)
        rotations=bones['rot'].astype(np.float64)
        nonfinite=int(np.count_nonzero(~np.isfinite(positions)))+int(np.count_nonzero(~np.isfinite(rotations)))
        qnorm=np.linalg.norm(rotations,axis=1)
        zero=qnorm<1e-12
        quaternion_zero=int(zero.sum())
        rotations[zero]=[0,0,0,1]
        qnorm[zero]=1
        rotations/=qnorm[:,None]
        difference=np.minimum(np.linalg.norm(rotations-rotations[first][inverse],axis=1),np.linalg.norm(rotations+rotations[first][inverse],axis=1))
        location_difference=np.linalg.norm(positions-positions[first][inverse],axis=1)
        moved=np.zeros(len(unique),dtype=np.float64)
        np.maximum.at(moved,inverse,np.maximum(location_difference,difference))
        nonzero=np.zeros(len(unique),dtype=np.float64)
        nonidentity_row=np.maximum(np.linalg.norm(positions,axis=1),np.minimum(np.linalg.norm(rotations-[0,0,0,1],axis=1),np.linalg.norm(rotations+[0,0,0,1],axis=1)))
        np.maximum.at(nonzero,inverse,nonidentity_row)
        dynamic=[name for i,name in enumerate(names) if moved[i]>1e-5]
        nonidentity=[name for i,name in enumerate(names) if nonzero[i]>1e-5]
        for i,name in enumerate(names):
            subset=bones[inverse==i]
            count=len(subset)
            duplicate_keys+=count-len(np.unique(subset['frame']))
            frames,counts=np.unique(subset['frame'],return_counts=True)
            for frame in frames[counts>1]:
                same=subset[subset['frame']==frame]
                if len({key.tobytes() for key in same})>1:conflicting_duplicate_keys+=1
            bone_key_counts[name]=count
            per_bone.append({'name':name,'keys':count,'dynamic':name in dynamic,'nonidentity':name in nonidentity,'category':category(name)})
            if category(name)=='root':root_span=max(root_span,float(np.linalg.norm(np.ptp(subset['pos'],axis=0))*.08))
    core_categories=['root','torso','arm','leg']
    core_names=[n for n in names if category(n) in core_categories]
    dynamic_core=[n for n in dynamic if category(n) in core_categories]
    body_like=len(core_names)>=6 and sum(category(n) in ['arm','leg'] for n in names)>=3
    actual_body_pose=sum(category(n) in core_categories for n in nonidentity)
    garment_pose=('skirt' in path.stem.lower() or 'rolledup' in path.stem.lower()) and not dynamic_core and actual_body_pose<=1
    if body_like and not garment_pose:kind='body_motion' if dynamic else 'body_pose'
    elif len(bones):kind='auxiliary_pose' if garment_pose else 'prop_or_auxiliary'
    elif len(sections['camera']):kind='camera'
    elif len(sections['morph']):kind='morph_only'
    elif len(sections['light']) or len(sections['shadow']):kind='light_shadow'
    else:kind='empty_or_properties'
    all_frames=[]
    for part in sections.values():
        if len(part):all_frames += [int(part['frame'].min()),int(part['frame'].max())]
    all_frames+=property_frames
    bone_start=int(bones['frame'].min()) if len(bones) else 0
    bone_end=int(bones['frame'].max()) if len(bones) else 0
    coverage={}
    for profile,target in profiles.items():
        missing=sorted(set(dynamic)-target)
        missing_core=[n for n in missing if category(n) in core_categories+['arm_ik']]
        aliases=[n for n in missing if normalized(n) in {normalized(x) for x in target}]
        required_missing=sorted(set(dynamic+nonidentity)-target)
        coverage[profile]={'dynamic_names':len(dynamic),'dynamic_matched':len(dynamic)-len(missing),
                           'dynamic_missing':missing,'core_dynamic_missing':missing_core,'unicode_alias_candidates':aliases,
                           'required_missing':required_missing,
                           'required_control_missing':[n for n in required_missing if category(n) in core_categories+['arm_ik','arm_extension']]}
    morphs=sections['morph']
    morph_names=sorted({decode(n) for n in morphs['name']}) if len(morphs) else []
    morph_nonzero_names=sorted({decode(n) for n,w in zip(morphs['name'],morphs['weight']) if abs(w)>1e-5})
    if len(morphs):nonfinite+=int(np.count_nonzero(~np.isfinite(morphs['weight'])))
    for part,field in [('camera','values'),('light','values'),('shadow','distance')]:
        nonfinite+=int(np.count_nonzero(~np.isfinite(sections[part][field])))
    property_bytes=raw[property_begin:offset]
    row={'file':path.relative_to(root).as_posix(),'folder':path.parent.relative_to(root).as_posix(),
         'top_folder':path.relative_to(root).parts[0],'bytes':len(raw),'model':decode(raw[30:50]),
         'family':family(decode(raw[30:50])),'kind':kind,'sections':{k:len(v) for k,v in sections.items()},
         'property_frames':len(property_frames),'frame_start':min(all_frames,default=0),'frame_end':max(all_frames,default=0),
         'bone_start':bone_start,'bone_end':bone_end,'bone_duration_s':(bone_end-bone_start)/30,
         'scene_duration_s':(max(all_frames,default=0)-min(all_frames,default=0))/30,
         'unique_bones':len(names),'dynamic_bones':len(dynamic),'dynamic_core_bones':len(dynamic_core),
         'bone_names':names,'dynamic_names':dynamic,'nonidentity_names':nonidentity,'bone_details':per_bone,'morph_names':morph_names,'morph_nonzero_names':morph_nonzero_names,
         'core_names':core_names,'coverage':coverage,'ik_names':sorted(ik_states),
         'ik_disabled_at_least_once':sorted(n for n,v in ik_states.items() if any(state==0 for _,state in v)),
         'ik_toggles':sorted(n for n,v in ik_states.items() if len({state for _,state in v})>1),
         'model_visibility_changes':len(set(visibility))>1,'visibility_hides':0 in visibility,
         'zero_quaternion_records':quaternion_zero,'nonfinite_values':nonfinite,
         'duplicate_bone_frame_keys':duplicate_keys,'conflicting_duplicate_bone_frames':conflicting_duplicate_keys,'trailing_bytes':len(raw)-offset,
         'encoding_replacement_names':[n for n in names if '\ufffd' in n],
         'root_span_m_hint':root_span,'sha256':hashlib.sha256(raw).hexdigest(),
         'bone_payload_sha256':hashlib.sha256(blocks['bone']).hexdigest(),
         'bone_ik_payload_sha256':hashlib.sha256(blocks['bone']+property_bytes).hexdigest(),
         'ik_version_name':bool(re.search(r'IK.?Arm|Arm.?IK|IK version',path.stem,re.I)) and not bool(re.search(r'no.?IK.?arms?',path.stem,re.I)),
         'fk_version_name':bool(re.search(r'no.?IK.?arms?',path.stem,re.I)),
         'arm_ik_dynamic':[n for n in dynamic if category(n)=='arm_ik']}
    return row


def duplicates(rows,key):
    groups=defaultdict(list)
    for row in rows:groups[row[key]].append(row['file'])
    return [values for values in groups.values() if len(values)>1]


def stats(values):
    if not values:return {}
    a=np.asarray(values,dtype=float)
    return {'min':float(a.min()),'median':float(np.median(a)),'p90':float(np.quantile(a,.9)),'max':float(a.max()),'sum':float(a.sum())}


def main():
    sys.stdout.reconfigure(encoding='utf-8')
    parser=argparse.ArgumentParser()
    parser.add_argument('--source',type=Path,default=Path('D:/模型/20261008/Public R-18 Motions'))
    parser.add_argument('--output',type=Path,default=ROOT/'docs/research/mmd_batch_20261103')
    args=parser.parse_args()
    started=time.perf_counter()
    profiles=profile_sets()
    files=sorted(p for p in args.source.rglob('*') if p.is_file())
    rows=[]
    errors=[]
    for i,path in enumerate(p for p in files if p.suffix.lower()=='.vmd'):
        try:rows.append(analyze(path,args.source,profiles))
        except Exception as error:errors.append({'file':path.relative_to(args.source).as_posix(),'error':str(error)})
        if (i+1)%50==0:print('Scanned',i+1,'VMDs',flush=True)
    text_evidence=[]
    for path in files:
        if path.suffix.lower()!='.txt':continue
        raw=path.read_bytes()
        for encoding in ['utf-8-sig','cp932','cp1252']:
            try:text=raw.decode(encoding);break
            except UnicodeDecodeError:pass
        flags=[]
        if re.search(r'outside parent|external parent|\bOP\b',text,re.I):flags.append('external_parent_dependency')
        if re.search(r'IK arm',text,re.I):flags.append('arm_ik_dependency')
        if re.search(r'0.?2497',text):flags.append('author_loop_range_0_2497')
        if re.search(r'7\.90',text):flags.append('author_camera_group_offset_7_90')
        text_evidence.append({'file':path.relative_to(args.source).as_posix(),'flags':flags,'sha256':hashlib.sha256(raw).hexdigest()})
    body=[r for r in rows if r['kind'] in ['body_motion','body_pose']]
    unique_body={r['bone_ik_payload_sha256']:r for r in body}
    groups=defaultdict(list)
    for row in body:groups[row['folder']].append(row)
    folder_report=[]
    for folder,items in sorted(groups.items()):
        folder_report.append({'folder':folder,'files':len(items),'families':dict(Counter(r['family'] for r in items)),
                              'ranges':sorted({(r['bone_start'],r['bone_end']) for r in items}),
                              'has_ik_variant':any(r['ik_version_name'] or r['arm_ik_dynamic'] for r in items),
                              'tracks':[{'file':r['file'],'family':r['family'],'start':r['bone_start'],'end':r['bone_end']} for r in items]})
    summary={'date':'2026-11-03','source':str(args.source),'scope':'static audit only; no batch conversion or live Blender mutation',
             'files':len(files),'bytes':sum(p.stat().st_size for p in files),
             'extensions':dict(Counter(p.suffix.lower() for p in files)),
             'top_directories':len([p for p in args.source.iterdir() if p.is_dir()]),
             'vmd_parsed':len(rows),'parse_errors':errors,'types':dict(Counter(r['kind'] for r in rows)),
             'body_files':len(body),'body_families':dict(Counter(r['family'] for r in body)),
             'unique_body_ik_payloads':len(unique_body),'body_directories':len(groups),
             'multi_body_directories':sum(len(v)>1 for v in groups.values()),
             'duration_body_seconds':stats([r['bone_duration_s'] for r in body]),
             'duration_unique_body_seconds':stats([r['bone_duration_s'] for r in unique_body.values()]),
             'bone_key_count':sum(r['sections']['bone'] for r in rows),
             'morph_files':sum(r['sections']['morph']>0 for r in rows),
             'camera_files':sum(r['sections']['camera']>0 for r in rows),
             'property_files':sum(r['property_frames']>0 for r in rows),
             'ik_toggle_files':sum(bool(r['ik_toggles']) for r in body),
             'visibility_change_files':sum(r['model_visibility_changes'] for r in body),
             'nonfinite_files':[r['file'] for r in rows if r['nonfinite_values']],
             'duplicate_key_files':[r['file'] for r in rows if r['duplicate_bone_frame_keys']],
             'conflicting_duplicate_key_files':[r['file'] for r in rows if r['conflicting_duplicate_bone_frames']],
             'nonzero_trailing_bytes_files':[r['file'] for r in rows if r['trailing_bytes']],
             'encoding_replacement_files':[r['file'] for r in rows if r['encoding_replacement_names']],
             'body_start_nonzero':[r['file'] for r in body if r['bone_start']>0],
             'body_over_60s':sum(r['bone_duration_s']>60 for r in body),
             'body_over_120s':sum(r['bone_duration_s']>120 for r in body),
             'ik_variant_files':[r['file'] for r in body if r['ik_version_name'] or r['arm_ik_dynamic']],
             'external_parent_documents':[r for r in text_evidence if 'external_parent_dependency' in r['flags']],
             'unique_body_bake_frames':sum(r['bone_end']+1 for r in unique_body.values()),
             'raw_body_bake_frames':sum(r['bone_end']+1 for r in body),
             'elapsed_audit_s':time.perf_counter()-started}
    for profile in profiles:
        summary[profile+'_coverage']={
            'body_files_no_core_dynamic_missing':sum(not r['coverage'][profile]['core_dynamic_missing'] for r in body),
            'unique_body_no_core_dynamic_missing':sum(not r['coverage'][profile]['core_dynamic_missing'] for r in unique_body.values()),
            'body_files_no_required_control_missing':sum(not r['coverage'][profile]['required_control_missing'] for r in body),
            'unique_body_no_required_control_missing':sum(not r['coverage'][profile]['required_control_missing'] for r in unique_body.values()),
            'dynamic_missing_frequencies':dict(Counter(n for r in body for n in r['coverage'][profile]['dynamic_missing']).most_common(40)),
            'core_missing_files':[{'file':r['file'],'missing':r['coverage'][profile]['core_dynamic_missing']} for r in body if r['coverage'][profile]['core_dynamic_missing']],
            'required_control_missing_files':[{'file':r['file'],'missing':r['coverage'][profile]['required_control_missing']} for r in body if r['coverage'][profile]['required_control_missing']]}
    args.output.mkdir(parents=True,exist_ok=True)
    special=[r for r in body if r['coverage']['keqing']['required_control_missing']]
    fallbacks=[]
    for row in special:
        candidates=[r['file'] for r in body if r['folder']==row['folder'] and r['family']==row['family']
                    and r['bone_end']==row['bone_end'] and not r['coverage']['keqing']['required_control_missing']]
        if candidates:fallbacks.append({'file':row['file'],'candidates':candidates})
    disposition={'classification':'Static planning candidates only; no conversion/visual acceptance. Required-control classification agrees for the two current proxy rigs.',
                 'source_body_files':len(body),'unique_bone_ik_payloads':len(unique_body),
                 'standard_candidate_files':len(body)-len(special),
                 'standard_candidate_unique_payloads':sum(not r['coverage']['keqing']['required_control_missing'] for r in unique_body.values()),
                 'special_files':len(special),'special_unique_payloads':sum(bool(r['coverage']['keqing']['required_control_missing']) for r in unique_body.values()),
                 'same_folder_same_model_same_end_fk_fallback_candidates':fallbacks,
                 'special_tracks':[{'file':r['file'],'missing_controls':r['coverage']['keqing']['required_control_missing'],'payload':r['bone_ik_payload_sha256']} for r in special],
                 'candidate_queue':[{'file':r['file'],'bone_end':r['bone_end'],'payload':r['bone_ik_payload_sha256']} for r in unique_body.values() if not r['coverage']['keqing']['required_control_missing']],
                 'body_morph_files':sum(bool(r['sections']['morph']) for r in body),
                 'body_nonzero_morph_files':sum(bool(r['morph_nonzero_names']) for r in body),
                 'exact_duplicate_file_groups':len(duplicates(rows,'sha256'))}
    for name,data in [('summary.json',summary),('files.json',rows),('folders.json',folder_report),('text_dependencies.json',text_evidence),
                      ('disposition.json',disposition),('proxy_bone_names.json',{k:sorted(v) for k,v in profiles.items()}),
                      ('duplicates.json',{'full_file':duplicates(rows,'sha256'),'body_ik':duplicates(body,'bone_ik_payload_sha256'),'bone_only':duplicates(body,'bone_payload_sha256')})]:
        (args.output/name).write_text(json.dumps(data,ensure_ascii=False,indent=2),encoding='utf-8')
    display={k:v for k,v in summary.items() if not isinstance(v,list) and not k.endswith('_coverage')}
    print(json.dumps(display,ensure_ascii=False,indent=2))


if __name__=='__main__':main()
