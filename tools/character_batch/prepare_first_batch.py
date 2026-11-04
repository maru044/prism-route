"""Read original archives and stage only local source copies outside the project."""
from pathlib import Path, PurePosixPath
import argparse, hashlib, json, zipfile, subprocess, shutil
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
SOURCE = Path('D:/模型/20261008')
WORK = Path('D:/Prism Route/research/character_batch_20261104')

def decoded(info, legacy_encoding='gbk'):
    name = info.filename
    if not info.flag_bits & 0x800:
        try: name = name.encode('cp437').decode(legacy_encoding)
        except UnicodeError: pass
    return name.replace('\\', '/')

def main():
    global WORK
    parser = argparse.ArgumentParser()
    parser.add_argument('--profiles', type=Path, default=Path(__file__).parent / 'first_batch_profiles.json')
    parser.add_argument('--work-dir', type=Path, default=WORK)
    args = parser.parse_args(); WORK = args.work_dir
    profiles = json.loads(args.profiles.read_text(encoding='utf8'))['profiles']
    rows = []; WORK.mkdir(parents=True, exist_ok=True)
    for profile in profiles:
        sid, label, game, pattern, body = [profile[k] for k in ['id', 'label', 'game', 'archive_glob', 'body_pmx']]
        archives = list(SOURCE.glob(pattern)); assert len(archives) == 1, (pattern, archives)
        archive = archives[0]; folder = WORK / 'sources' / sid; folder.mkdir(parents=True, exist_ok=True)
        candidates = []; texts = []
        if archive.suffix.lower() == '.rar':
            cmd = ['C:\\Program Files\\7-Zip\\7z.exe', 'x', '-y', f'-o{folder}', str(archive)]
            subprocess.check_call(cmd, stdout=subprocess.DEVNULL)
            candidates = list(folder.rglob('*.pmx'))
            texts = [str(p) for p in folder.rglob('*.txt')] + [str(p) for p in folder.rglob('*.md')]
        else:
            with zipfile.ZipFile(archive) as z:
                for info in z.infolist():
                    name = profile.get('archive_path_overrides', {}).get(info.filename, decoded(info, profile['zip_encoding']))
                    parts = PurePosixPath(name)
                    assert not parts.is_absolute() and '..' not in parts.parts and ':' not in name
                    target = folder.joinpath(*parts.parts)
                    if info.is_dir():
                        target.mkdir(parents=True, exist_ok=True)
                        continue
                    target.parent.mkdir(parents=True, exist_ok=True)
                    data = z.read(info)
                    if not target.exists():
                        target.write_bytes(data)
                    else:
                        assert hashlib.sha256(target.read_bytes()).digest() == hashlib.sha256(data).digest()
                    if target.suffix.lower() == '.pmx':
                        candidates.append(target)
                    if target.suffix.lower() in ['.txt', '.md']:
                        texts.append(str(target))
        for placeholder in profile.get('placeholders', []):
            p = folder / placeholder
            if not p.exists():
                p.parent.mkdir(parents=True, exist_ok=True)
                img = Image.new('RGBA', (4, 4), (255, 255, 255, 255))
                img.save(p, format='PNG')
        for src, dst in profile.get('file_copies', {}).items():
            t = folder / dst
            s = folder / src
            if not t.exists() and s.exists():
                t.parent.mkdir(parents=True, exist_ok=True)
                shutil.copyfile(s, t)
        chosen = [p for p in candidates if p.name == body]; assert len(chosen) == 1, (sid, candidates)
        row = dict(
            id=sid, label=label, game=game, archive=str(archive), archive_sha256=hashlib.sha256(archive.read_bytes()).hexdigest(),
            source=str(chosen[0]), source_sha256=hashlib.sha256(chosen[0].read_bytes()).hexdigest(),
            other_pmx=[str(p) for p in candidates if p != chosen[0]], readmes=texts,
            output=f'assets/characters/roster/{sid}/{sid}.vrm', physics_prefixes=profile['physics_prefixes'],
            zip_encoding=profile['zip_encoding'], archive_path_overrides=profile.get('archive_path_overrides', {})
        )
        rows.append(row)
        print(label, 'body=', chosen[0].name, 'excluded PMX=', [p.name for p in candidates if p != chosen[0]])
    (WORK / 'batch.json').write_text(json.dumps(dict(schema=1, profiles=rows), ensure_ascii=False, indent=2) + '\n', encoding='utf8')

if __name__ == '__main__':
    main()
