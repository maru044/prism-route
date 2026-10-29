"""Merge manual terrain while retaining every unrelated CAD mesh byte."""
from pathlib import Path
import hashlib,json

ROOT=Path(__file__).resolve().parents[1]
CACHE=ROOT/'.current_map_build'
OUT=ROOT/'assets/world/current_map_validation/review'

def block(raw,row):
    size=row['vertex_count']*12+row['index_count']*4
    data=raw[row['offset']:row['offset']+size]
    assert len(data)==size
    return data

def main():
    patch=json.loads((CACHE/'manual_terrain_1028_patch.json').read_text(encoding='utf-8-sig'))
    source=json.loads((CACHE/'source.json').read_text(encoding='utf-8-sig'))
    assert patch['cad_unchanged'] and source['native_center']==patch['native_center']
    raw=(CACHE/'source.bin').read_bytes();delta=(CACHE/'manual_terrain_1028_patch.bin').read_bytes()
    replacements={r['id']:r for r in patch['objects']};assert len(replacements)==6
    before={r['id']:hashlib.sha256(block(raw,r)).hexdigest() for r in source['objects'] if r['id']not in replacements}
    # Small layout/manifest backups only; no duplicate whole-map mesh or bake.
    backup=CACHE/'manual_terrain_1028_before';backup.mkdir(exist_ok=True)
    for name in ['metadata.json','tree_layout.json','tree_layout_metadata.json','surface_roles.json']:
        src=ROOT/'assets/world/current_map_validation'/name
        if not (backup/name).exists():(backup/name).write_bytes(src.read_bytes())
    merged=bytearray();records=[];seen=set()
    for row in source['objects']+patch['objects']:
        key=row['id']
        if key in seen:continue
        seen.add(key);record=dict(replacements.get(key,row));record.pop('export_index_count',None)
        data=block(delta if key in replacements else raw,record)
        record['offset']=len(merged);merged.extend(data);records.append(record)
    for r in records:
        if r['id']in before:assert hashlib.sha256(block(merged,r)).hexdigest()==before[r['id']]
    assert len(records)==len(before)+6
    source.update(objects=records,source=patch['source'],cad_object_count=patch['cad_object_count'],all_cad_geometry_and_attributes_unchanged=True)
    (CACHE/'source.bin').write_bytes(merged)
    (CACHE/'source.json').write_text(json.dumps(source,ensure_ascii=False,indent=2),encoding='utf-8')
    report={'export_objects':len(records),'new_manual_terrain_objects':6,'unchanged_raw_mesh_objects':len(before),'unrelated_raw_geometry_preserved':True,'cad_unchanged_during_export':True}
    (OUT/'manual_terrain_1028_export.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
    print(json.dumps(report))

if __name__=='__main__':main()
