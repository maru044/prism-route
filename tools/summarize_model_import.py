"""Validate local VRM payloads and save small, redistributable test evidence."""
import json
import struct
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BUILD = ROOT / '.model_import_build'
LOCAL = ROOT / 'assets/characters/import_tests_local/keqing'


def inspect(path):
    payload = path.read_bytes()
    magic, version, length = struct.unpack_from('<III', payload)
    assert magic == 0x46546C67 and version == 2 and length == len(payload)
    size, kind = struct.unpack_from('<II', payload, 12)
    assert kind == 0x4E4F534A
    data = json.loads(payload[20:20+size])
    assert 'VRMC_vrm' in data['extensions']
    assert all('VRMC_materials_mtoon' in m.get('extensions', {}) for m in data['materials'])
    assert all('shadeMultiplyTexture' in m['extensions']['VRMC_materials_mtoon']
               for m in data['materials'] if m.get('pbrMetallicRoughness', {}).get('baseColorTexture'))
    assert data['meshes'] and data['images'] and data['skins']
    assert all('POSITION' in p['attributes'] and 'JOINTS_0' in p['attributes']
               for mesh in data['meshes'] for p in mesh['primitives'])
    return {
        'bytes': len(payload), 'meshes': len(data['meshes']),
        'primitives': sum(len(m['primitives']) for m in data['meshes']),
        'materials': len(data['materials']), 'mtoon_materials': len(data['materials']),
        'images': len(data['images']), 'skin_joints': len(data['skins'][0]['joints']),
        'morph_targets': len(data['meshes'][0]['primitives'][0].get('targets', [])),
        'humanoid_hips_node': data['nodes'][data['extensions']['VRMC_vrm']['humanoid']['humanBones']['hips']['node']]['name'],
    }


def main():
    conversion = json.loads((BUILD/'conversion_report.json').read_text(encoding='utf8'))
    validation = json.loads((BUILD/'godot_validation.json').read_text(encoding='utf8'))
    assert conversion['source_unchanged'] and conversion['max_weight_total_error'] <= 1e-6
    expected = json.loads((ROOT/'assets/characters/motion_review/catalog.json').read_text(encoding='utf8'))
    assert validation['clips'] == len(expected) == 42 and not validation['failures']
    # Keep this report about conversion operations and validation results.
    for field in ['source', 'source_sha256', 'asset_usage']:
        conversion.pop(field, None)
    conversion['removed_constraint_count'] = len(conversion.pop('removed_constraints'))
    report = {'date': '2026-10-09', 'conversion': conversion,
              'exported': {v: inspect(LOCAL/f'keqing_{v}.vrm') for v in ['before', 'fixed']},
              'godot_validation': validation,
              'existing_ganyu_review_regression': {'clips': 42, 'failures': []}}
    regression = (BUILD/'ganyu_regression.log').read_text(encoding='utf8')
    assert 'RESULT clips=42 failures=[]' in regression
    (ROOT/'docs/MMD_VRM_IMPORT_TEST_REPORT.json').write_text(
        json.dumps(report, ensure_ascii=False, indent=2)+'\n', encoding='utf8')
    print(json.dumps(report['exported'], ensure_ascii=False))


if __name__ == '__main__':
    main()
