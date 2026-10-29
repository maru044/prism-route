"""Download public, author-linked audio for a local listening page; no login/API keys."""
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor
from urllib.request import Request, urlopen
from urllib.parse import urljoin, urlparse
import hashlib
import html
import json
import re
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'docs/audio_research_1030/audition'
HEADERS = {'User-Agent': 'Mozilla/5.0 (audio audition download)'}


def fetch(url):
    if urlparse(url).scheme != 'https':
        raise ValueError('HTTPS required')
    with urlopen(Request(url, headers=HEADERS), timeout=45) as response:
        data = response.read(90 * 1024 * 1024 + 1)
        if len(data) > 90 * 1024 * 1024:
            raise ValueError('File exceeds audition size limit')
        return data


def sanitize_source_page(page):
    # Public author pages can embed unrelated map-service credentials. Keep
    # licensing/source evidence, but never archive those credentials in Git.
    return re.sub(r'(?<![\w-])[sp]k\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+',
                  '[redacted-map-service-token]', page)


def download(row):
    result = dict(row)
    try:
        page = fetch(row['source']).decode('utf-8')
        (OUT / 'source_pages' / (row['id'] + '.html')).write_text(sanitize_source_page(page), encoding='utf-8')
        normalized = html.unescape(page).replace('\\/', '/').replace('\\u002F', '/')
        if 'freesound.org' in urlparse(row['source']).netloc:
            sound_id = row['source'].rstrip('/').rsplit('/', 1)[1]
            urls = re.findall(r'https://[^\s<>"\x27]+\.mp3', normalized)
            urls = sorted(set(u for u in urls if '/previews/' in u and '/' + sound_id + '_' in u))
            high = [u for u in urls if '-hq.mp3' in u]
            if not high:
                raise ValueError('No author-page public HQ preview URL found; no guessed download URLs used')
            audio_url = high[0]
            quality = 'public_hq_preview'
            suffix = '.mp3'
        else:
            urls = [urljoin(row['source'], html.unescape(u)) for u in re.findall(r'href=["\x27]([^"\x27]+)["\x27]', page)]
            matches = [u for u in urls if urlparse(u).path.lower().endswith('.wav')]
            if not matches:
                raise ValueError('No public WAV attachment found')
            audio_url = matches[0]
            quality = 'original_attachment'
            suffix = '.wav'
        if urlparse(audio_url).hostname not in {'cdn.freesound.org', 'freesound.org', 'opengameart.org', 'www.opengameart.org'}:
            raise ValueError('Unexpected audio host: ' + str(urlparse(audio_url).hostname))
        name = row['id'] + ('_preview' if quality == 'public_hq_preview' else '_original') + suffix
        path = OUT / 'files' / name
        if not path.exists():
            data = fetch(audio_url)
            valid = data.startswith((b'RIFF', b'ID3', b'OggS', b'fLaC')) or (len(data)>2 and data[0] == 255 and data[1] & 224 == 224)
            if not valid:
                raise ValueError('Response is not recognizable audio')
            path.write_bytes(data)
        probe = subprocess.run([shutil.which('ffprobe') or 'ffprobe', '-v', 'error', '-show_format', '-show_streams', '-of', 'json', str(path)], capture_output=True, text=True, check=True)
        metadata = json.loads(probe.stdout)
        stream = next(s for s in metadata['streams'] if s['codec_type'] == 'audio')
        result.update(status='downloaded', file='files/' + name, download_url=audio_url,
                      quality=quality, bytes=path.stat().st_size,
                      sha256=hashlib.sha256(path.read_bytes()).hexdigest(),
                      downloaded_duration_seconds=float(metadata['format']['duration']),
                      codec=stream['codec_name'], sample_rate=int(stream['sample_rate']),
                      channels=stream['channels'], bit_rate=metadata['format'].get('bit_rate'))
        print(row['id'], quality, path.stat().st_size, 'bytes', flush=True)
    except Exception as error:
        result.update(status='failed', error=str(error))
        print(row['id'], 'FAILED', str(error), flush=True)
    return result


def make_page(rows):
    cards = []
    overrides_path = OUT / 'listening_overrides.json'
    overrides = json.loads(overrides_path.read_text(encoding='utf-8')) if overrides_path.exists() else {}
    for row in rows:
        row = {**row, **overrides.get(row['id'], {})}
        esc = lambda value: html.escape(str(value), quote=True)
        if row['status'] != 'downloaded':
            cards.append('<article><h2>' + esc(row['category']) + '</h2><p>下载未完成</p></article>')
            continue
        quality = '作者上传的原文件' if row['quality'] == 'original_attachment' else '公开 HQ 压缩试听版 · 非原始 WAV/FLAC'
        if row.get('listening_file'):
            quality = '响度修正版 · 基于公开 HQ 压缩试听版'
        playback_file = row.get('listening_file', row['file'])
        note = '<p>' + esc(row['processing_note']) + '</p><a href="' + esc(row['file']) + '" target="_blank" rel="noopener noreferrer">原下载文件（音量较低） ↗</a>' if row.get('processing_note') else ''
        seconds = row['downloaded_duration_seconds']
        jump = ''.join('<button data-jump="' + str(t) + '">从 ' + str(t) + ' 秒听</button>' for t in [0, 20, 60] if t < seconds)
        cards.append(f'''<article><header><h2>{esc(row['category'])}</h2><span>{esc(quality)}</span></header>
<h3>{esc(row['title'])}</h3><p>{esc(row['author'])} · CC0 · {seconds:.1f} 秒 · {row['bytes']/1048576:.2f} MB</p>
<audio controls preload="metadata" src="{esc(playback_file)}"></audio><div class="jumps">{jump}</div>{note}<p class="playback-status" role="status"></p>
<a href="{esc(row['source'])}" target="_blank" rel="noopener noreferrer">作者与许可页面 ↗</a></article>''')
    document = '''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Project PR · 第一批音效试听</title><style>
*{box-sizing:border-box}body{margin:0;background:#121a1c;color:#e4ece8;font:16px/1.6 system-ui,"Microsoft YaHei",sans-serif}main{max-width:1100px;margin:auto;padding:40px 24px 70px}h1{font-size:30px;margin:0 0 12px}p{color:#adbfba;margin:8px 0 16px}.toolbar{display:flex;gap:20px;align-items:center;flex-wrap:wrap;padding:18px 0 26px}button{border:1px solid #4e6a60;background:#273e35;color:#e4f0e7;border-radius:8px;padding:8px 13px;cursor:pointer}.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(350px,1fr));gap:18px}article{background:#1d292a;border:1px solid #314141;padding:22px;border-radius:14px}header{display:flex;align-items:center;justify-content:space-between;gap:12px;flex-wrap:wrap}h2{font-size:22px;margin:0}h3{font-size:15px;font-weight:500;margin:14px 0 4px}span{font-size:12px;color:#d7c58e}audio{width:100%;margin:4px 0 12px}.jumps{display:flex;gap:8px;flex-wrap:wrap;margin:0 0 16px}a{color:#9cd1ba}small{color:#91aaa2}.volume{display:flex;gap:10px;align-items:center}input{accent-color:#9cd1ba}</style>
<main><h1>Project PR · 第一批音效试听</h1>
<p>海浪、海鸟、陆地鸟叫、风吹树叶、车辆启动、涉水。点击播放即可；播放新片段时会暂停其他片段。</p>
<small>原下载文件均保留。树叶声默认使用已标注的响度修正副本，其余片段未调整响度。Freesound 四项来源为公开压缩试听版；音效尚未接入游戏。</small>
<div class="toolbar"><button id="stop">全部停止</button><label class="volume">试听音量 <input id="volume" type="range" min="0" max="1" step="0.01" value="0.35"><output id="level">35%</output></label></div>
<section class="grid">''' + ''.join(cards) + '''</section><p><small>作者、来源、许可及文件哈希保存在 downloads.json；默认音量 35%，无自动播放。</small></p></main>
<script>const sounds=[...document.querySelectorAll('audio')];const volume=document.querySelector('#volume');sounds.forEach(a=>{a.volume=.35;a.addEventListener('error',()=>{a.closest('article').querySelector('.playback-status').textContent='播放失败，请刷新页面后重试，或打开原文件。'});a.addEventListener('play',()=>sounds.forEach(b=>{if(a!==b)b.pause()}))});document.querySelector('#stop').onclick=()=>sounds.forEach(a=>{a.pause();a.currentTime=0});volume.oninput=()=>{sounds.forEach(a=>a.volume=Number(volume.value));document.querySelector('#level').value=Math.round(volume.value*100)+'%'};document.querySelectorAll('[data-jump]').forEach(b=>b.onclick=()=>{let a=b.closest('article').querySelector('audio');a.currentTime=Number(b.dataset.jump);a.play().catch(e=>{a.closest('article').querySelector('.playback-status').textContent='无法播放：'+e.message})});</script></html>'''
    (OUT / 'index.html').write_text(document, encoding='utf-8')


def main():
    (OUT / 'files').mkdir(parents=True, exist_ok=True)
    (OUT / 'source_pages').mkdir(exist_ok=True)
    data = json.loads((ROOT / 'docs/audio_research_1030/candidates.json').read_text(encoding='utf-8'))
    with ThreadPoolExecutor(max_workers=4) as pool:
        rows = list(pool.map(download, data['candidates']))
    report = {'downloaded_on':'2026-10-30', 'game_integrated':False, 'items':rows}
    (OUT / 'downloads.json').write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding='utf-8')
    make_page(rows)
    print(json.dumps({'downloaded':sum(r['status']=='downloaded' for r in rows),'total':len(rows),'page':str(OUT/'index.html')}, ensure_ascii=True))
    return 0 if all(r['status']=='downloaded' for r in rows) else 1


if __name__ == '__main__':
    raise SystemExit(main())
