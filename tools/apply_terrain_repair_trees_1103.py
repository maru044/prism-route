"""Apply height-only overrides, retaining existing authored record bytes/values."""
from pathlib import Path
import copy,hashlib,json,math
ROOT=Path(__file__).resolve().parents[1]
CACHE=ROOT/'.current_map_build/terrain_repairs_1103'
SAVE=ROOT/'assets/world/tree_planting/world_edits.json'

def apply():
    plan=json.loads((CACHE/'tree_grounding_plan.json').read_text(encoding='utf-8'))
    raw=SAVE.read_bytes();assert hashlib.sha256(raw).hexdigest()==plan['save_sha256'],'User saved new edits; remeasure first'
    assert not plan['missing']
    original=json.loads(raw);data=copy.deepcopy(original);edits={r['id']:r for r in data['trees']}
    changed=[]
    for change in plan['changes']:
        before,after=change['before'],change['after'];sid=after['id']
        assert before['id']==sid and sid not in original['removed']
        if sid in edits:
            row=edits[sid]
            for key in ['species','palette']:assert row[key]==before[key]
            for key in ['yaw','scale']:assert math.isclose(row[key],before[key],abs_tol=1e-8)
            assert all(math.isclose(a,b,abs_tol=1e-7) for a,b in zip(row['position'],before['position']))
        else:row=copy.deepcopy(before)
        old=copy.deepcopy(row);row['position'][1]=after['position'][1];row['surface']=after['surface'];edits[sid]=row
        assert all(row[key]==old[key] for key in ['id','yaw','scale','species','palette'])
        assert row['position'][0]==old['position'][0] and row['position'][2]==old['position'][2]
        changed.append({'id':sid,'before_y':old['position'][1],'after_y':row['position'][1]})
    data['trees']=list(edits.values())
    assert data['removed']==original['removed']
    for key in original:
        if key!='trees':assert data[key]==original[key]
    if changed:
        tmp=SAVE.with_suffix('.json.tmp');tmp.write_text(json.dumps(data,ensure_ascii=False,indent='\t')+'\n',encoding='utf-8')
        assert hashlib.sha256(SAVE.read_bytes()).hexdigest()==plan['save_sha256'];tmp.replace(SAVE)
    report={'changed':len(changed),'reviewed':plan['reviewed'],'before_sha256':plan['save_sha256'],
        'after_sha256':hashlib.sha256(SAVE.read_bytes()).hexdigest(),'xz_rotation_scale_species_palette_preserved':True,
        'removals_preserved':True,'raised':sum(c['after_y']>c['before_y'] for c in changed),
        'lowered':sum(c['after_y']<c['before_y'] for c in changed),'changes':changed}
    initial_path=CACHE/'tree_grounding_initial_report.json'
    if initial_path.exists():
        initial=json.loads(initial_path.read_text())
        assert initial['after_sha256']==plan['save_sha256'],'A newer user save exists; keep stages separate'
        combined={r['id']:copy.deepcopy(r) for r in initial['changes']}
        for row in changed:
            if row['id'] in combined:combined[row['id']]['after_y']=row['after_y']
            else:combined[row['id']]=row
        report.update(changed=len(combined),changes=list(combined.values()),before_sha256=initial['before_sha256'],
                      refinement_changes=len(changed),raised=sum(r['after_y']>r['before_y'] for r in combined.values()),
                      lowered=sum(r['after_y']<r['before_y'] for r in combined.values()))
    (ROOT/'docs/terrain_seams_1102/tree_grounding_report.json').write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps({k:report[k] for k in ['changed','reviewed','raised','lowered']}))
if __name__=='__main__':apply()
