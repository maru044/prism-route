"""Merge only the lagoon delta, dropping the six retired flat sand patches."""
from pathlib import Path
import hashlib
import json

ROOT=Path(__file__).resolve().parents[1]
CACHE=ROOT/'.current_map_build'

def block(raw,row):
    size=row['vertex_count']*12+row['index_count']*4
    data=raw[row['offset']:row['offset']+size]
    assert len(data)==size
    return data

def main():
    patch=json.loads((CACHE/'lagoon_1026_patch.json').read_text(encoding='utf-8'))
    source=json.loads((CACHE/'source.json').read_text(encoding='utf-8-sig'))
    assert patch['cad_unchanged'] and source['native_center']==patch['native_center']
    raw=(CACHE/'source.bin').read_bytes()
    delta=(CACHE/'lagoon_1026_patch.bin').read_bytes()
    replacements={r['id']:r for r in patch['objects']}
    removed=set(patch['removed'])
    before={r['id']:hashlib.sha256(block(raw,r)).hexdigest() for r in source['objects']
        if r['id']not in replacements and r['id']not in removed}
    records=[];merged=bytearray();seen=set()
    for row in source['objects']+patch['objects']:
        key=row['id']
        if key in seen or key in removed:continue
        seen.add(key)
        replacement=replacements.get(key,row)
        data=block(delta if key in replacements else raw,replacement)
        record=dict(replacement);record.pop('export_index_count',None)
        record['offset']=len(merged);merged.extend(data);records.append(record)
    for row in records:
        if row['id']in before:assert hashlib.sha256(block(merged,row)).hexdigest()==before[row['id']]
    assert len(records)==202 and not(removed & seen)
    source.update(objects=records,cad_object_count=patch['cad_object_count'],
        source=patch['source'],all_cad_geometry_and_attributes_unchanged=True)
    (CACHE/'source.bin').write_bytes(merged)
    (CACHE/'source.json').write_text(json.dumps(source,ensure_ascii=False,indent=2),encoding='utf-8')
    report={'export_objects':len(records),'unchanged_raw_mesh_objects':len(before),
        'all_unrelated_raw_geometry_preserved':True,'patched_or_added_ids':list(replacements),
        'removed_ids':sorted(removed),'cad_unchanged':True}
    (ROOT/'assets/world/current_map_validation/review/lagoon_1026_export.json').write_text(
        json.dumps(report,indent=2),encoding='utf-8')
    print(json.dumps(report))

if __name__=='__main__':main()
