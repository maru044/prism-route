"""Apply the reviewed height-only grounding plan to the sparse planting save."""
from pathlib import Path
import json,hashlib,datetime
ROOT=Path(__file__).resolve().parents[1]
CACHE=ROOT/'.current_map_build/east_earth_pavilion_1102'
SAVE=ROOT/'assets/world/tree_planting/world_edits.json'

def apply():
    plan=json.loads((CACHE/'tree_grounding_plan.json').read_text())
    raw=SAVE.read_bytes();assert hashlib.sha256(raw).hexdigest()==plan['save_sha256'],'Planting changed after the plan; remeasure first'
    assert not plan['missing']
    data=json.loads(raw);original=json.loads(raw);edits={r['id']:r for r in data['trees']}
    for change in plan['changes']:
        before,after=change['before'],change['after'];assert before['id']==after['id']
        assert before['position'][0]==after['position'][0] and before['position'][2]==after['position'][2]
        assert all(before[k]==after[k] for k in ['yaw','scale','species','palette'])
        if before['id'] in edits:assert edits[before['id']]==before
        edits[after['id']]=after
    data['trees']=list(edits.values());assert data['removed']==original['removed']
    stamp=datetime.datetime.now().strftime('%Y%m%d_%H%M%S')
    backup=ROOT.parent/'archive/east_earth_pavilion_1102'/('world_edits_before_grounding_'+stamp+'.json')
    backup.parent.mkdir(parents=True,exist_ok=True);assert not backup.exists();backup.write_bytes(raw)
    temporary=SAVE.with_suffix('.json.tmp');temporary.write_text(json.dumps(data,ensure_ascii=False,indent='\t')+'\n',encoding='utf-8')
    assert hashlib.sha256(SAVE.read_bytes()).hexdigest()==plan['save_sha256']
    temporary.replace(SAVE)
    changes=[{'id':c['after']['id'],'before_y':c['before']['position'][1],'after_y':c['after']['position'][1],
        'position_xz':[c['after']['position'][0],c['after']['position'][2]],'surface_id':c['after']['surface']} for c in plan['changes']]
    report={'passed':True,'reviewed':len(plan['reviewed']),'changed':len(changes),'lowered':sum(c['after_y']<c['before_y'] for c in changes),
        'raised':sum(c['after_y']>c['before_y'] for c in changes),'missing_ground':plan['missing'],'backup':str(backup),
        'before_sha256':plan['save_sha256'],'after_sha256':hashlib.sha256(SAVE.read_bytes()).hexdigest(),
        'xz_rotation_scale_species_palette_preserved':True,'removed_ids_preserved':True,'changes':changes}
    (ROOT/'docs/east_earth_pavilion_1102/game/tree_grounding_report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print(json.dumps({k:report[k] for k in ['changed','lowered','raised','reviewed','backup']}))
if __name__=='__main__':apply()
