"""Check the current runtime report against current sources, not historical renders."""
from pathlib import Path
import hashlib
import json

ROOT = Path(__file__).resolve().parents[1]


def main():
    entry = json.loads((ROOT / 'assets/world/architecture_details_1029/preview_entry.json').read_text(encoding='utf-8-sig'))
    report = json.loads((ROOT / entry.get('report_dir', 'res://docs/foliage_cluster_revision_1029/').removeprefix('res://') / 'entry_verification.json').read_text(encoding='utf-8-sig'))
    startup = report['startup']
    assert report['passed'] and report['checked_inside_launched_scene'], report
    assert startup['revision'] == entry['revision'] and startup['scene'] == entry['scene']
    for key in ['script', 'shader', 'texture']:
        assert startup[key] == entry[key], key
        path = ROOT / entry[key].removeprefix('res://')
        assert hashlib.sha256(path.read_bytes()).hexdigest() == startup[key + '_sha256'], 'Stale report: ' + key
    assert startup['texture_sha256'] == entry['texture_sha256']
    assert startup['default_view'] == entry['default_view']
    assert startup['painted_color'] == entry['painted_color'] and startup['parallax_enabled'] == entry['parallax_enabled']
    if 'factory' in entry:
        assert hashlib.sha256((ROOT / entry['factory'].removeprefix('res://')).read_bytes()).hexdigest() == startup['factory_sha256'], 'Stale factory report'
        assert startup['cluster_scale'] == entry['default_scale']
    assert all(report['aliases_same_script'].values())
    print(json.dumps({'passed': True, 'revision': startup['revision'], 'window_title': startup['window_title'],
                      'scene': startup['scene'], 'runtime_report_matches_current_sources': True}, ensure_ascii=True))
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
