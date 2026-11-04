"""Package one VRM per character with UV-audited alpha and model-specific springs."""
from pathlib import Path
import argparse,json,struct,hashlib,io,sys,re
import numpy as np
from PIL import Image,ImageDraw
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tools'))
from build_motion_review import Source,worlds
WORK=Path('D:/Prism Route/research/character_batch_20261104')

def accessor(vrm,index):
    a=vrm.g['accessors'][index];v=vrm.g['bufferViews'][a['bufferView']]
    types={5121:'u1',5123:'<u2',5125:'<u4',5126:'<f4'};dtype=np.dtype(types[a['componentType']])
    count={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4,'MAT4':16}[a['type']]
    assert not a.get('sparse')
    return np.ndarray((a['count'],count),dtype=dtype,buffer=vrm.binary,offset=v.get('byteOffset',0)+a.get('byteOffset',0),strides=(v.get('byteStride',count*dtype.itemsize),dtype.itemsize)).copy()

def alpha_audit(vrm):
    masks={};images={};reports=[]
    for mesh in vrm.g['meshes']:
        for primitive in mesh['primitives']:
            mid=primitive.get('material');material=vrm.g['materials'][mid];tex=material.get('pbrMetallicRoughness',{}).get('baseColorTexture')
            if not tex or 'TEXCOORD_0' not in primitive['attributes']:continue
            image_id=vrm.g['textures'][tex['index']]['source']
            if image_id not in images:
                view=vrm.g['bufferViews'][vrm.g['images'][image_id]['bufferView']]
                raw=vrm.binary[view.get('byteOffset',0):view.get('byteOffset',0)+view['byteLength']]
                image=Image.open(io.BytesIO(raw)).convert('RGBA');image.thumbnail((1024,1024))
                images[image_id]=np.asarray(image)[:,:,3]
            alpha=images[image_id];h,w=alpha.shape
            mask=masks.setdefault(mid,(Image.new('1',(w,h)),image_id))[0];draw=ImageDraw.Draw(mask)
            uv=(accessor(vrm,primitive['attributes']['TEXCOORD_0'])%1.0)*np.array([w-1,h-1])
            indices=accessor(vrm,primitive['indices']).reshape(-1,3)
            for tri in indices:draw.polygon([tuple(p) for p in uv[tri]],fill=1)
    for mid,m in enumerate(vrm.g['materials']):
        factor=m.get('pbrMetallicRoughness',{}).get('baseColorFactor',[1,1,1,1])[3]
        transparent=partial=middle=0.;lo=hi=255
        if mid in masks:
            mask,image_id=masks[mid];values=images[image_id][np.asarray(mask,dtype=bool)]
            if not len(values):values=images[image_id].ravel()
            assert len(values),m.get('name')
            lo=int(values.min());hi=int(values.max());transparent=float(np.mean(values<10));partial=float(np.mean((values>0)&(values<255)));middle=float(np.mean((values>20)&(values<235)))
        mode='BLEND' if factor<.999 or (middle>.05 and transparent<.01) else ('MASK' if transparent>.001 or partial>.01 else 'OPAQUE')
        m['alphaMode']=mode
        if mode=='MASK':m['alphaCutoff']=.35
        else:m.pop('alphaCutoff',None)
        toon=m.get('extensions',{}).get('VRMC_materials_mtoon',{})
        name=m.get('name','');toon['shadeColorFactor']=[.89,.79,.81] if any(s in name for s in ['颜','面','肌']) else [.78,.73,.85]
        toon['outlineWidthMode']='none'
        reports.append(dict(name=name,mode=mode,min_alpha=lo,max_alpha=hi,transparent_fraction=transparent,partial_fraction=partial,middle_fraction=middle))
    return reports

def add_physics(vrm,report):
    names={n.get('name'):i for i,n in enumerate(vrm.g['nodes'])};human=vrm.g['extensions']['VRMC_vrm']['humanoid']['humanBones'];node_world=worlds(vrm.local,vrm.parents)
    colliders=[];hair=[];clothes=[]
    def collider(key,end,radius,groups,offset=(0,0,0)):
        if key not in human or (end and end not in human):return
        node=human[key]['node'];world=node_world[node];inverse=np.linalg.inv(world)
        p=(inverse@np.r_[world[:3,3]+offset,1])[:3].tolist()
        shape={'offset':p,'radius':radius}
        if end:shape['tail']=(inverse@np.r_[node_world[human[end]['node']][:3,3],1])[:3].tolist()
        colliders.append(dict(node=node,shape={('capsule' if end else 'sphere'):shape}))
        for group in groups:group.append(len(colliders)-1)
    height=float(node_world[human['hips']['node']][1,3]);scale=np.clip(height/.95,.8,1.2)
    collider('head',None,.085*scale,[hair],np.array([0,.06*scale,0]))
    collider('neck','head',.032*scale,[hair])
    collider('chest','neck',.075*scale,[clothes])
    collider('hips','chest',.075*scale,[clothes])
    for side in ['left','right']:
        collider(side+'UpperArm',side+'LowerArm',.028*scale,[clothes,hair])
        collider(side+'LowerArm',side+'Hand',.023*scale,[clothes])
        collider(side+'UpperLeg',side+'LowerLeg',.047*scale,[clothes])
        collider(side+'LowerLeg',side+'Foot',.032*scale,[clothes])
    groups=[dict(name='Hair body',colliders=hair),dict(name='Clothes body',colliders=clothes)]
    springs=[]
    for chain in report['chains']:
        missing=[n for n in chain['nodes'] if n not in names];assert not missing,missing
        is_hair=chain['group']=='Hair';joints=[]
        for i,name in enumerate(chain['nodes']):
            joints.append(dict(node=names[name],stiffness=(1.4 if is_hair else 1.0)*(1-.35*i/max(1,len(chain['nodes'])-1)),gravityPower=.18 if is_hair else .25,gravityDir=[0,-1,0],dragForce=.8,hitRadius=.006 if is_hair else .009))
        springs.append(dict(name=chain['group']+' '+chain['attachment'],center=human['head' if is_hair else 'hips']['node'],joints=joints,colliderGroups=[0 if is_hair else 1]))
    vrm.g['extensions']['VRMC_springBone']=dict(specVersion='1.0',colliders=colliders,colliderGroups=groups,springs=springs)
    used=vrm.g.setdefault('extensionsUsed',[])
    if 'VRMC_springBone' not in used:used.append('VRMC_springBone')
    return dict(hair_chains=sum(c['group']=='Hair' for c in report['chains']),clothes_chains=sum(c['group']=='Clothes' for c in report['chains']),colliders=len(colliders),joints=sum(len(c['nodes']) for c in report['chains']))

def package(manifest_name='first_batch.json'):
    config=json.loads((WORK/'batch.json').read_text(encoding='utf8'));rows=[]
    for row in config['profiles']:
        report=json.loads((WORK/'reports'/f'{row["id"]}_build.json').read_text(encoding='utf8'))
        vrm=Source(WORK/'converted'/row['id']/'body.vrm');alpha=alpha_audit(vrm);physics=add_physics(vrm,report)
        raw=Path(row['source']).read_bytes();header_size=raw[8];encoding='utf-16-le' if raw[9]==0 else 'utf8';offset=9+header_size;texts=[]
        for _ in range(4):
            size=struct.unpack_from('<i',raw,offset)[0];offset+=4;texts.append(raw[offset:offset+size].decode(encoding));offset+=size
        original_comment=texts[2];match=re.search(r'模型(?:改造|编辑|制作)[：:]\s*([^\r\n]+)',original_comment)
        editor=match.group(1).strip() if match else 'Original archive credits'
        meta=vrm.g['extensions']['VRMC_vrm']['meta'];meta['authors']=['miHoYo',editor];meta['copyrightInformation']='Original model: miHoYo; MMD model: '+editor;meta['thirdPartyLicenses']=original_comment
        encoded=json.dumps(vrm.g,ensure_ascii=False,separators=(',',':')).encode();encoded+=b' '*((-len(encoded))%4)
        binary=vrm.binary;binary+=b'\0'*((-len(binary))%4)
        out=ROOT/row['output'];out.parent.mkdir(parents=True,exist_ok=True)
        out.write_bytes(struct.pack('<III',0x46546c67,2,28+len(encoded)+len(binary))+struct.pack('<II',len(encoded),0x4e4f534a)+encoded+struct.pack('<II',len(binary),0x004e4942)+binary)
        audit=dict(id=row['id'],label=row['label'],vertices=report['vertices'],bones=len(report['bones']),morphs=report['morphs'],materials=len(report['materials']),alpha=alpha,physics=physics,source_sha256=row['source_sha256'],source_unchanged=report['source_unchanged'],max_weight_total_error=report['max_weight_total_error'],foot_test=report['foot_after'],helper_links=report['helper_links'],chains=report['chains'],mesh_binary_preserved=hashlib.sha256(binary).hexdigest()==hashlib.sha256(vrm.binary).hexdigest(),output_sha256=hashlib.sha256(out.read_bytes()).hexdigest())
        audit['mesh_binary_sha256']=hashlib.sha256(binary).hexdigest()
        audit['alpha_method']='UV triangle coverage on RGBA texture thumbnails with maximum edge 1024; material factor alpha preserved; validated in Godot.'
        (out.parent/'build_report.json').write_text(json.dumps(audit,ensure_ascii=False,indent=2)+'\n',encoding='utf8')
        provenance=dict(archive=row['archive'],archive_sha256=row['archive_sha256'],body_pmx=Path(row['source']).name,source_sha256=row['source_sha256'],pmx_name=texts[0],pmx_english_name=texts[1],pmx_comment=texts[2],pmx_english_comment=texts[3],authors=meta['authors'],excluded_pmx=[Path(p).name for p in row['other_pmx']])
        if row.get('archive_path_overrides'):provenance['archive_path_overrides']=row['archive_path_overrides']
        (out.parent/'provenance.json').write_text(json.dumps(provenance,ensure_ascii=False,indent=2)+'\n',encoding='utf8')
        scenes=ROOT/'scenes/characters/roster';scenes.mkdir(parents=True,exist_ok=True)
        scene='[gd_scene load_steps=2 format=3]\n\n[ext_resource type="PackedScene" path="res://scenes/characters/shared_humanoid_actor.tscn" id="1"]\n\n[node name="'+row['id']+'" instance=ExtResource("1")]\nmodel_resource = "res://'+row['output']+'"\nmotion_resource = "res://assets/characters/roster/motions/shared_world_A01.tres"\nauto_play = true\n'
        (scenes/(row['id']+'.tscn')).write_text(scene,encoding='utf8')
        rows.append(dict(id=row['id'],label=row['label'],game=row['game'],model='res://'+row['output'],model_sha256=audit['output_sha256'],source_archive=row['archive'],source_sha256=row['source_sha256'],body_pmx=Path(row['source']).name,excluded_pmx=[Path(p).name for p in row['other_pmx']],physics=physics,bytes=out.stat().st_size))
        print(json.dumps(dict(id=row['id'],bytes=out.stat().st_size,physics=physics,alpha={mode:sum(r['mode']==mode for r in alpha) for mode in ['OPAQUE','MASK','BLEND']})))
    assert re.fullmatch(r'[a-z0-9_]+\.json',manifest_name),manifest_name
    dest=ROOT/'assets/characters/roster'/manifest_name;dest.write_text(json.dumps(dict(schema=1,profiles=rows),ensure_ascii=False,indent=2)+'\n',encoding='utf8')
    catalog=dest.parent/'catalog.json'
    current=json.loads(catalog.read_text(encoding='utf8'))['profiles'] if catalog.exists() else []
    merged={r['id']:r for r in current}
    for row in rows:merged[row['id']]=row
    catalog.write_text(json.dumps(dict(schema=1,profiles=list(merged.values())),ensure_ascii=False,indent=2)+'\n',encoding='utf8')

if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--work-dir',type=Path,default=WORK);parser.add_argument('--manifest-name',default='first_batch.json');args=parser.parse_args();WORK=args.work_dir
    package(args.manifest_name)
