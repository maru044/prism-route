"""Merge the verified live-Rhino road patch without remeshing unrelated objects."""
from pathlib import Path
import json
import shutil

ROOT = Path(__file__).resolve().parents[1]
CACHE = ROOT / '.current_map_build'

def main():
    patch = json.loads((CACHE / 'outer_roads_1022_patch.json').read_text(encoding='utf-8'))
    assert patch['saved_and_readback_verified']
    source = json.loads((CACHE / 'source.json').read_text(encoding='utf-8-sig'))
    assert source['cad_object_count'] in [patch['cad_object_count'] - 2, patch['cad_object_count']], 'Source changed outside the road patch'
    backup = CACHE / 'outer_roads_1022_game_before'
    backup.mkdir(exist_ok=True)
    paths = [CACHE / 'source.json', CACHE / 'source.bin']
    asset = ROOT / 'assets/world/current_map_validation'
    paths += [asset / name for name in ['metadata.json', 'current_region.glb', 'grass_cells.json', 'tree_layout.json', 'tree_layout_metadata.json']]
    paths += [asset / 'grass_bake/manifest.json']
    for path in paths:
        target = backup / path.name
        if not target.exists(): shutil.copy2(path, target)
    raw = (CACHE / 'source.bin').read_bytes()
    delta = (CACHE / 'outer_roads_1022_patch.bin').read_bytes()
    replacements = {r['id']: r for r in patch['objects']}
    records = []
    merged = bytearray()
    for row in source['objects'] + [r for r in patch['objects'] if r['id'] not in {o['id'] for o in source['objects']}]:
        original = replacements.get(row['id'], row)
        data = delta if row['id'] in replacements else raw
        count = original['vertex_count'] * 12 + original['index_count'] * 4
        record = dict(original)
        record.pop('export_index_count', None)
        record['offset'] = len(merged)
        merged.extend(data[original['offset']:original['offset'] + count])
        records.append(record)
    assert len(records) == len(source['objects']) + len([r for r in patch['objects'] if r['id'] not in {o['id'] for o in source['objects']}])
    source.update(objects=records, cad_object_count=patch['cad_object_count'])
    (CACHE / 'source.bin').write_bytes(merged)
    (CACHE / 'source.json').write_text(json.dumps(source, ensure_ascii=False, indent=2), encoding='utf-8')
    print(json.dumps({'export_objects':len(records),'patched_objects':len(replacements),'unchanged_objects':len(records)-len(replacements)}))

if __name__ == '__main__':
    main()
