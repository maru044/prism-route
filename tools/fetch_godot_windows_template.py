"""Fetch only matching Windows release templates from the official TPZ by ranges."""
from pathlib import Path
import io
import json
import urllib.request
import zipfile

ROOT = Path(__file__).resolve().parents[1]
DEST = ROOT / '.current_map_build/export_templates'
TAG = '4.7.2-stable'


class RemoteZip(io.RawIOBase):
    def __init__(self, url, size):
        self.url, self.size, self.position = url, size, 0
        self.blocks = {}
        self.block_size = 4 * 1024 * 1024
        self.downloaded = 0

    def seekable(self): return True
    def readable(self): return True
    def tell(self): return self.position

    def seek(self, offset, whence=0):
        self.position = offset if whence == 0 else (self.position + offset if whence == 1 else self.size + offset)
        return self.position

    def read(self, count=-1):
        end = self.size if count < 0 else min(self.size, self.position + count)
        chunks = []
        while self.position < end:
            index = self.position // self.block_size
            start = index * self.block_size
            if index not in self.blocks:
                stop = min(self.size, start + self.block_size) - 1
                request = urllib.request.Request(self.url, headers={'Range': f'bytes={start}-{stop}', 'Accept-Encoding': 'identity'})
                with urllib.request.urlopen(request, timeout=60) as response:
                    assert response.status == 206, 'Server must support partial downloads'
                    payload = response.read()
                    assert len(payload) == stop - start + 1
                    self.blocks[index] = payload
                    self.downloaded += len(payload)
            payload = self.blocks[index]
            count = min(end - self.position, len(payload) - (self.position - start))
            chunks.append(payload[self.position - start:self.position - start + count])
            self.position += count
        return b''.join(chunks)


def main():
    url = f'https://api.github.com/repos/godotengine/godot-builds/releases/tags/{TAG}'
    with urllib.request.urlopen(url, timeout=30) as response:
        release = json.load(response)
    asset = next(a for a in release['assets'] if a['name'] == f'Godot_v{TAG}_export_templates.tpz')
    remote = RemoteZip(asset['browser_download_url'], asset['size'])
    DEST.mkdir(parents=True, exist_ok=True)
    extracted = []
    with zipfile.ZipFile(remote) as archive:
        names = [n for n in archive.namelist() if ('windows' in n.lower() and 'release' in n.lower() and 'x86_64' in n.lower()) or Path(n).name.startswith('icudt') or Path(n).name == 'version.txt']
        assert any('windows_release_x86_64.exe' in n for n in names), archive.namelist()
        for name in names:
            data = archive.read(name)  # ZIP validates the entry CRC before publishing.
            destination = DEST / Path(name).name
            destination.write_bytes(data)
            extracted.append({'name': destination.name, 'bytes': len(data)})
            print(json.dumps(extracted[-1]), flush=True)
    report = {'release': TAG, 'official_url': asset['browser_download_url'], 'archive_bytes': asset['size'], 'downloaded_bytes': remote.downloaded, 'files': extracted}
    (DEST / 'provenance.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
    print(json.dumps(report, indent=2))


if __name__ == '__main__': main()
