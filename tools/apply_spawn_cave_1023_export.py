"""Merge the spawn-area delta while preserving every other raw mesh byte."""
from pathlib import Path
import hashlib
import json
import shutil

ROOT=Path(__file__).resolve().parents[1]
CACHE=ROOT/'.current_map_build'
ASSET=ROOT/'assets/world/current_map_validation'
TERRAIN='577d868b-7597-4058-83f8-4b630606b305'

def block(raw,row):
    size=row['vertex_count']*12+row['index_count']*4
    data=raw[row['offset']:row['offset']+size]
    assert len(data)==size
    return data

def main():
    patch=json.loads((CACHE/'spawn_cave_1023_patch.json').read_text(encoding='utf-8'))
    source_path=CACHE/'source.json'
    source=json.loads(source_path.read_text(encoding='utf-8-sig'))
    assert patch['cad_unchanged'] and len(patch['objects'])==5
    raw=(CACHE/'source.bin').read_bytes()
    delta=(CACHE/'spawn_cave_1023_patch.bin').read_bytes()
    replacements={r['id']:r for r in patch['objects']}
    backup=CACHE/'spawn_cave_1023_game_before'
    backup.mkdir(exist_ok=True)
    # A reversible delta checkpoint, not another full map/grass-cache copy.
    if not (backup/'source.json').exists():
        shutil.copy2(source_path,backup/'source.json')
        old=next(r for r in source['objects'] if r['id']==TERRAIN)
        (backup/'old_changed_mesh.bin').write_bytes(block(raw,old))
        for name in ['metadata.json','tree_layout.json','tree_layout_metadata.json','grass_cells.json','grass_bake/manifest.json']:
            shutil.copy2(ASSET/name,backup/Path(name).name)
    before={r['id']:hashlib.sha256(block(raw,r)).hexdigest() for r in source['objects'] if r['id'] not in replacements}
    records=[]
    merged=bytearray()
    added=set()
    for row in source['objects']+patch['objects']:
        key=row['id']
        if key in added:continue
        added.add(key)
        replacement=replacements.get(key,row)
        data=block(delta if key in replacements else raw,replacement)
        record=dict(replacement)
        record.pop('export_index_count',None)
        record['offset']=len(merged)
        merged.extend(data)
        records.append(record)
    for row in records:
        if row['id'] in before:assert hashlib.sha256(block(merged,row)).hexdigest()==before[row['id']]
    source.update(objects=records,cad_object_count=patch['cad_object_count'],source=patch['source'],all_cad_geometry_and_attributes_unchanged=True)
    (CACHE/'source.bin').write_bytes(merged)
    source_path.write_text(json.dumps(source,ensure_ascii=False,indent=2),encoding='utf-8')
    report={'export_objects':len(records),'unchanged_raw_mesh_objects':len(before),'all_unrelated_raw_geometry_preserved':True,'patched_or_added_ids':list(replacements),'cad_unchanged':True}
    (ASSET/'review/spawn_cave_1023_export.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
    print(json.dumps(report))

if __name__=='__main__':main()
