"""Inspect the actual PCK directory, hashes, contents and package size."""
from pathlib import Path
from collections import defaultdict
import argparse
import hashlib
import json
import re
import struct

ROOT = Path(__file__).resolve().parents[1]
BUILD = ROOT.parent / 'builds'
PACKAGE_FILES = (
    'PrismRoute1021.exe', 'PrismRoute1021.pck', 'PrismRoute1021.console.exe',
    'libvrm_physics.windows.template_release.x86_64.dll', 'icudt_godot.dat',
)
LOCAL_GRASS_MANIFESTS = (
    'assets/world/oval_atrium_1031/grass_bake/manifest.json',
    'assets/world/east_earth_pavilion_1102/grass_bake/manifest.json',
    'assets/world/terrain_repairs_1103/grass_bake/manifest.json',
    'assets/world/church_ruins_1105/grass_bake/manifest.json',
    'assets/world/cape_town_1110/grass_bake.json',
    'assets/world/npc_waypoint_ruins/grass_bake.json',
)
PACK_MAGIC = 0x43504447


def embedded_pack_start(executable):
    with executable.open('rb') as file:
        if file.read(2) != b'MZ' or executable.stat().st_size < 12:
            return None
        file.seek(-12, 2)
        footer_start = file.tell()
        size, magic = struct.unpack('<QI', file.read(12))
        start = footer_start - size
        if magic != PACK_MAGIC or start <= 0:
            return None
        file.seek(start)
        return start if file.read(4) == b'GDPC' else None


def read_directory(path):
    rows = []
    start = embedded_pack_start(path) if path.suffix.lower() == '.exe' else 0
    assert start is not None, f'No embedded PCK in {path}'
    with path.open('rb') as file:
        file.seek(start)
        magic, version, major, minor, patch, flags = struct.unpack('<6I', file.read(24))
        assert magic == PACK_MAGIC and version in [2, 3, 4] and not flags & 1
        base, = struct.unpack('<Q', file.read(8))
        if version in [3, 4] or flags & 2:
            base += start
        if version in [3, 4]:
            directory, = struct.unpack('<Q', file.read(8))
            file.seek(start + directory)
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
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--build', type=Path, default=BUILD)
    parser.add_argument('--report', type=Path, default=ROOT / '.current_map_build/export_1021_audit.json')
    parser.add_argument('--require-embedded', action='store_true')
    args = parser.parse_args()
    executable = args.build / 'PrismRoute1021.exe'
    embedded = executable.is_file() and embedded_pack_start(executable) is not None
    if args.require_embedded and not embedded:
        parser.error(f'No embedded PCK in {executable}')
    package = executable if embedded else args.build / 'PrismRoute1021.pck'
    rows = read_directory(package)
    by_path = {r['path']: r for r in rows}
    geometry_path = 'export_grass_geometry.json'
    dependency_report = ROOT / '.current_map_build/export_1021_dependencies.json'
    with package.open('rb') as file:
        def data_at(path):
            entry = by_path[path]
            file.seek(entry['offset'])
            return file.read(entry['bytes'])

        geometry_bytes = data_at(geometry_path)
        assert geometry_bytes == (ROOT / geometry_path).read_bytes(), 'Grass geometry manifest differs'
        geometry = json.loads(geometry_bytes)
        for source, fingerprint in geometry.items():
            entry = source.removeprefix('res://')
            imported = fingerprint['imported'].removeprefix('res://')
            remap = data_at(entry + '.import').decode('utf-8')
            assert f'path="{fingerprint["imported"]}"' in remap, f'Grass geometry remap differs: {source}'
            assert by_path[imported]['md5'] == fingerprint['imported_md5'], f'Grass geometry payload differs: {source}'

        required = json.loads(dependency_report.read_bytes())['resource_roots_and_dependencies']
        missing = []
        for resource in required:
            entry = resource.removeprefix('res://')
            if entry in by_path:
                continue
            remaps = [entry + suffix for suffix in ('.import', '.remap') if entry + suffix in by_path]
            targets = [
                match.removeprefix('res://')
                for remap in remaps
                for match in re.findall(r'^path(?:\.[\w.]+)?="([^"]+)"', data_at(remap).decode('utf-8'), re.MULTILINE)
            ]
            if not targets or any(target not in by_path for target in targets):
                missing.append((resource, targets))
        assert not missing, f'Missing package resources or remap targets: {missing}'

        local_cells = 0
        for manifest_path in LOCAL_GRASS_MANIFESTS:
            cells = json.loads(data_at(manifest_path))['cells']
            for key, cell in cells.items():
                if not cell['instances']:
                    continue
                path = cell['resource_path'].removeprefix('res://')
                entry = by_path[path]
                offset = int(cell.get('resource_offset', 0))
                size = int(cell['compressed_bytes'])
                assert 0 <= offset <= entry['bytes'] - size, (path, key)
                file.seek(entry['offset'] + offset)
                assert hashlib.sha256(file.read(size)).hexdigest() == cell['sha256'], (path, key)
                local_cells += 1
    categories = defaultdict(int)
    forbidden = []
    prefix = 'assets/world/current_map_validation/grass_bake/'
    manifest_path = ROOT / prefix / 'manifest.json'
    manifest = json.loads(manifest_path.read_text(encoding='utf-8'))
    grass_rows = {
        Path(row['path']).stem: row for row in rows
        if row['path'].startswith(prefix) and row['path'].endswith('.grass')
    }
    assert set(grass_rows) == set(manifest['cells'])
    source_checks = ['scripts/vegetation_lod_streamer.gd', 'scripts/map_1021_vegetation.gd', 'scripts/grass_instance_buffer.gd', 'scripts/grass_volume_streamer.gd', 'assets/world/current_map_validation/landscape_mask.res', 'assets/world/current_map_validation/surface_roles.json']
    with package.open('rb') as file:
        for row in rows:
            path = row['path']
            file.seek(row['offset']);data = file.read(row['bytes'])
            assert hashlib.md5(data).hexdigest() == row['md5'], path
            if path.startswith(prefix) and path.endswith('.grass'):
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
    files = [
        {'name': name, 'bytes': (args.build / name).stat().st_size}
        for name in PACKAGE_FILES if (args.build / name).is_file()
        and not (embedded and name == 'PrismRoute1021.pck')
    ]
    total = sum(p['bytes'] for p in files)
    report = {'passed': True, 'package_directory': str(args.build), 'files': files, 'total_bytes': total, 'total_decimal_GB': total/1e9, 'total_GiB': total/2**30, 'pck_files': len(rows), 'all_pck_md5_verified': True, 'baked_cells': len(grass_rows), 'all_grass_sha256_verified': True, 'grass_signature': manifest['signature'], 'signature_inputs_byte_identical': True, 'unwanted_files': forbidden, 'resource_bytes': dict(categories), 'largest_resources': sorted(rows, key=lambda r: -r['bytes'])[:10]}
    report['pck_embedded'] = embedded
    report['required_resources_verified'] = len(required)
    report['grass_geometry_imports_verified'] = len(geometry)
    report['local_grass_payloads_verified'] = local_cells
    args.report.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding='utf-8')
    print(json.dumps({k: v for k, v in report.items() if k != 'largest_resources'}, ensure_ascii=False, indent=2))


if __name__ == '__main__': main()
