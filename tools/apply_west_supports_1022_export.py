"""Replace only the verified west road support mesh in the current CAD export."""
from pathlib import Path
import hashlib
import json
import shutil

ROOT = Path(__file__).resolve().parents[1]
CACHE = ROOT / '.current_map_build'
ASSET = ROOT / 'assets/world/current_map_validation'
BODY = 'd348f4df-9b88-42a1-b57e-64023ce5f1ad'


def block(raw, row):
    count = row['vertex_count'] * 12 + row['index_count'] * 4
    result = raw[row['offset']:row['offset'] + count]
    assert len(result) == count
    return result


def main():
    patch = json.loads((CACHE / 'west_supports_1022_patch.json').read_text(encoding='utf-8'))
    source = json.loads((CACHE / 'source.json').read_text(encoding='utf-8-sig'))
    assert patch['saved_and_readback_verified']
    assert source['cad_object_count'] == patch['cad_object_count'] == 265
    assert [r['id'] for r in patch['objects']] == [BODY]
    assert len(source['objects']) == 201
    backup = CACHE / 'west_supports_1022_game_before'
    backup.mkdir(exist_ok=True)
    paths = [CACHE / 'source.json', CACHE / 'source.bin']
    paths += [ASSET / name for name in ['metadata.json', 'current_region.glb', 'grass_cells.json', 'tree_layout.json', 'tree_layout_metadata.json', 'grass_bake/manifest.json']]
    for path in paths:
        target = backup / path.name
        if not target.exists():
            shutil.copy2(path, target)
    raw = (CACHE / 'source.bin').read_bytes()
    delta = (CACHE / 'west_supports_1022_patch.bin').read_bytes()
    previous = {r['id']: hashlib.sha256(block(raw, r)).hexdigest() for r in source['objects']}
    records, merged = [], bytearray()
    for row in source['objects']:
        replacement = patch['objects'][0] if row['id'] == BODY else row
        data = block(delta if row['id'] == BODY else raw, replacement)
        record = dict(replacement)
        record.pop('export_index_count', None)
        record['offset'] = len(merged)
        merged.extend(data)
        records.append(record)
    for row in records:
        if row['id'] != BODY:
            assert hashlib.sha256(block(merged, row)).hexdigest() == previous[row['id']]
    source['objects'] = records
    (CACHE / 'source.bin').write_bytes(merged)
    (CACHE / 'source.json').write_text(json.dumps(source, ensure_ascii=False, indent=2), encoding='utf-8')
    report = {'export_objects': len(records), 'patched_ids': [BODY], 'unchanged_mesh_objects': 200, 'unchanged_raw_geometry_verified': True}
    (CACHE / 'west_supports_1022_export_preservation.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
    print(json.dumps(report))


if __name__ == '__main__':
    main()
