"""Validate disjoint offline worker outputs and publish a complete manifest."""
import hashlib
import json
import argparse
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / 'assets/world/current_map_validation'
BAKE = ASSETS / 'grass_bake'


def main():
    # Select matching worker count when resuming after changing parallelism.
    parser = argparse.ArgumentParser()
    parser.add_argument('--shards', type=int)
    args = parser.parse_args()
    expected = {'_'.join(map(str, c)) for c in json.loads((ASSETS / 'grass_cells.json').read_text(encoding='utf-8'))['cells']}
    parts = sorted(BAKE.glob('manifest_part_*.json'))
    if args.shards:
        parts = [p for p in parts if json.loads(p.read_text(encoding='utf-8')).get('shard_count') == args.shards]
    if not parts:
        raise RuntimeError('No offline shard manifests')
    merged = {}
    signature = None
    shard_ids = set()
    for path in parts:
        part = json.loads(path.read_text(encoding='utf-8'))
        signature = signature or part['signature']
        assert part['signature'] == signature, f'Stale shard: {path}'
        shard_ids.add(part['shard_index'])
        assert len(parts) == part['shard_count'], 'Missing shard manifests'
        for key, row in part['cells'].items():
            if key in merged:
                assert merged[key] == row, f'Conflicting deterministic cell: {key}'
            merged[key] = row
    assert shard_ids == set(range(len(parts))), 'Missing shard indexes'
    assert set(merged) == expected, f'Incomplete bake: missing {len(expected-set(merged))}, extra {len(set(merged)-expected)}'
    compressed = raw = instances = empty = 0
    for i, (key, row) in enumerate(sorted(merged.items())):
        content = (BAKE / f'{key}.grass').read_bytes()
        assert hashlib.sha256(content).hexdigest() == row['sha256'], f'Corrupt cell: {key}'
        assert len(content) == row['compressed_bytes']
        assert row['instances'] == row['root_count'] * 4
        assert row['raw_bytes'] == row['root_count'] * 56
        compressed += len(content)
        raw += row['raw_bytes']
        instances += row['instances']
        empty += row['instances'] == 0
        if i % 2000 == 0:
            print(f'Validated {i}/{len(merged)} cells', flush=True)
    manifest = {'version': 2, 'signature': signature, 'scope': 'full map', 'complete': True,
                'candidate_count': len(expected), 'cells': merged}
    temporary = BAKE / 'manifest.complete.json'
    temporary.write_text(json.dumps(manifest, separators=(',', ':')), encoding='utf-8')
    temporary.replace(BAKE / 'manifest.json')
    report = {'complete': True, 'cells': len(merged), 'empty': empty, 'instances': instances,
              'compressed_bytes': compressed, 'raw_root_bytes': raw,
              'expanded_matrix_bytes': instances * 64, 'signature': signature}
    (ASSETS / 'review/issue13_full_bake.json').write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
    print(json.dumps(report, indent=2))


if __name__ == '__main__':
    main()
