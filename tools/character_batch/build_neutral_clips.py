"""Share the exact reviewed animations used by the formal Ganyu controller."""
from pathlib import Path
import sys,json,hashlib
import numpy as np
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tools'))
from build_shared_humanoid_validation import write_clip
WORK=Path('D:/Prism Route/research/character_batch_20261104')

def main():
    source=WORK/'formal_ganyu_motion.json'
    assert source.exists(),'Run export_formal_ganyu_motion.gd before building shared NPC clips.'
    data=json.loads(source.read_text(encoding='utf8'));dest=ROOT/'assets/characters/roster/motions';reports=[];rows=[]
    rest=[np.array(m,dtype=float).reshape(4,4) for m in data['rest']]
    for clip in data['clips']:
        path=ROOT/clip['source'][6:]
        assert hashlib.sha256(path.read_bytes()).hexdigest()==clip['source_sha256'],'Formal motion changed after sampling'
        poses=[np.array(p,dtype=float).reshape(-1,4,4) for p in clip['poses']];name='shared_world_'+clip['id']
        result=write_clip(name,np.array(clip['times']),rest,poses,data['mapping'],data['pelvis'],data['body_root'],path,destination_dir=dest,reference_dir=WORK/'reports')
        result.update(controller=data['controller'],centering=data['centering'],formal_id=clip['id']);reports.append(result)
        label={'idle':'地图待机','walk':'地图步行','run':'地图跑步'}[clip['state']]+' · '+clip['id']
        row=dict(id=clip['state'],label=label,resource='res://assets/characters/roster/motions/'+name+'.tres',formal_id=clip['id'],formal_resource=clip['source'],formal_source_sha256=clip['source_sha256'],npc_enabled=True,status='included_in_locomotion_acceptance',acceptance_report='res://docs/character_locomotion_1104/acceptance.json')
        rows.append(row)
    (dest.parent/'neutral_clips.json').write_text(json.dumps(dict(source_controller=data['controller'],source_scene=data['scene'],clips=rows,build=reports),ensure_ascii=False,indent=2)+'\n',encoding='utf8')
    print([(r['formal_id'],r['duration'],r['frames']) for r in reports])

if __name__=='__main__':main()
