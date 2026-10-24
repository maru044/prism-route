"""Inspect the actual PCK directory, hashes, contents and package size."""
from pathlib import Path
from collections import defaultdict
import hashlib
import json
import struct

ROOT = Path(__file__).resolve().parents[1]
BUILD = ROOT.parent / 'builds/windows_1021'


def read_directory(path):
    rows = []
    with path.open('rb') as file:
        magic, version, major, minor, patch, flags = struct.unpack('<6I', file.read(24))
        assert magic == 0x43504447 and version in [2, 3, 4] and not flags & 1
        base, = struct.unpack('<Q', file.read(8))
        if version in [3, 4]:
            directory, = struct.unpack('<Q', file.read(8))
            file.seek(directory)
        else:
            file.read(64)
        count, = struct.unpack('<I', file.read(4))
        for _ in range(count):
            length, = struct.unpack('<I', file.read(4))
            name = file.read(length).decode('utf-8').rstrip('\0').removeprefix('res://')
            offset, size = struct.unpack('<QQ', file.read(16))
            md5 = file.read(16).hex()
            entry_flags, = struct.unpack('<I', file.read(4))
            assert entry_flags == 0
            rows.append(dict(path=name, offset=base+offset, bytes=size, md5=md5))
    return rows


def main():
    package = BUILD / 'PrismRoute1021.pck'
    rows = read_directory(package)
    by_path = {r['path']: r for r in rows}
    categories = defaultdict(int)
    forbidden = []
    prefix = 'assets/world/current_map_validation/grass_bake/'
    manifest_path = ROOT / prefix / 'manifest.json'
    manifest = json.loads(manifest_path.read_text(encoding='utf-8'))
    grass_rows = {Path(r['path']).stem: r for r in rows if r['path'].endswith('.grass')}
    assert set(grass_rows) == set(manifest['cells'])
    source_checks = ['scripts/vegetation_lod_streamer.gd', 'scripts/map_1021_vegetation.gd', 'scripts/grass_instance_buffer.gd', 'scripts/grass_volume_streamer.gd', 'assets/world/current_map_validation/landscape_mask.res', 'assets/world/current_map_validation/surface_roles.json']
    with package.open('rb') as file:
        for row in rows:
            path = row['path']
            file.seek(row['offset']);data = file.read(row['bytes'])
            assert hashlib.md5(data).hexdigest() == row['md5'], path
            if path.endswith('.grass'):
                assert hashlib.sha256(data).hexdigest() == manifest['cells'][Path(path).stem]['sha256'], path
                category = 'grass_baked_cells'
            elif 'current_region.glb-' in path: category = 'current_map_imported_mesh'
            elif 'rosendal_park_sunset' in path: category = 'sky_lighting_texture'
            elif path.startswith(prefix): category = 'grass_manifest'
            else: category = 'other_runtime_resources'
            categories[category] += row['bytes']
            if path in source_checks:
                assert data == (ROOT / path).read_bytes(), 'Bake-signature source differs: '+path
            if path.startswith(('docs/', 'screenshots/', 'archive/', 'experiments/', '.current_map_build/')) or '/review/' in path or path.endswith(('.3dm', '.blend', '.py')) or 'manifest_part_' in path:
                forbidden.append(path)
    assert not forbidden, forbidden
    assert all(path in by_path for path in source_checks)
    files = [{'name': p.name, 'bytes': p.stat().st_size} for p in BUILD.iterdir() if p.is_file() and p.suffix in ['.exe', '.pck', '.dll', '.dat']]
    total = sum(p['bytes'] for p in files)
    report = {'passed': True, 'package_directory': str(BUILD), 'files': files, 'total_bytes': total, 'total_decimal_GB': total/1e9, 'total_GiB': total/2**30, 'pck_files': len(rows), 'all_pck_md5_verified': True, 'baked_cells': len(grass_rows), 'all_grass_sha256_verified': True, 'grass_signature': manifest['signature'], 'signature_inputs_byte_identical': True, 'unwanted_files': forbidden, 'resource_bytes': dict(categories), 'largest_resources': sorted(rows, key=lambda r: -r['bytes'])[:10]}
    output = ROOT / '.current_map_build/export_1021_audit.json'
    output.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding='utf-8')
    print(json.dumps({k: v for k, v in report.items() if k != 'largest_resources'}, ensure_ascii=False, indent=2))


if __name__ == '__main__': main()
