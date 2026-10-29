"""Prepare the approved local audition sources for game playback, preserving originals."""
from pathlib import Path
import hashlib
import json
import math
import shutil
import subprocess
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'docs/audio_research_1030/audition'
OUT = ROOT / 'assets/audio/world_1030'
FFMPEG = shutil.which('ffmpeg')


def run(args):
    subprocess.run([FFMPEG, '-v', 'error', '-n', *args], check=True)


def samples(path):
    return np.frombuffer(subprocess.check_output([FFMPEG, '-v', 'error', '-i', str(path), '-ac', '1', '-ar', '12000', '-f', 'f32le', '-']), dtype='<f4')


def regions(data, count, spacing, before, after):
    rate = 12000
    frame = 480
    env = np.sqrt(np.mean(data[:len(data)//frame*frame].reshape(-1, frame)**2, axis=1))
    picked = []
    for i in np.argsort(env)[::-1]:
        t = float(i)*.04
        if t < .2 or t > len(data)/rate-after:
            continue
        if all(abs(t-p) > spacing for p in picked):
            picked.append(t)
        if len(picked) == count:
            break
    return [(max(0., t-before), min(before+after, len(data)/rate-max(0., t-before))) for t in sorted(picked)]


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    sources = {r['id']:r for r in json.loads((SOURCE/'downloads.json').read_text(encoding='utf-8'))['items']}
    outputs = []
    def save(name, source_id, start=0., length=None, loop=False, source_override=None):
        row = sources[source_id]
        original = SOURCE/(source_override or row['file'])
        if source_override is None:
            assert hashlib.sha256(original.read_bytes()).hexdigest() == row['sha256']
        suffix = '.ogg' if loop else '.wav'
        target = OUT/(name+suffix)
        decoded = samples(original)
        if loop:
            filters = 'loudnorm=I=-22:TP=-3:LRA=10,highpass=f=45'
        else:
            section = decoded[int(start*12000):int((start+length)*12000)] if length else decoded
            rms = max(1e-8, float(np.sqrt(np.mean(section**2))))
            peak = max(1e-8, float(np.max(np.abs(section))))
            gain = min(10**(-22/20)/rms, 10**(-3/20)/peak)
            duration = length or len(decoded)/12000
            filters = f'volume={gain},afade=t=in:d=0.006,afade=t=out:st={max(0,duration-.035)}:d=0.035'
        args = ['-ss',str(start),'-i',str(original)]
        if length:args += ['-t',str(length)]
        args += ['-map_metadata','-1','-af',filters,'-ar','48000','-ac','2' if loop else '1']
        args += ['-c:a','libvorbis','-q:a','4'] if loop else ['-c:a','pcm_s16le']
        if not target.exists():run(args+[str(target)])
        run(['-i',str(target),'-f','null','-'])
        outputs.append({'file':target.name,'source_id':source_id,'source_url':row['source'],'author':row['author'],'license':row['license'],'source_quality':row['quality'],'source_sha256':hashlib.sha256(original.read_bytes()).hexdigest(),'source_file':str(original.relative_to(ROOT)).replace('\\','/'),'start_seconds':start,'length_seconds':length,'crossfade_loop':loop,'processing':filters,'sha256':hashlib.sha256(target.read_bytes()).hexdigest(),'bytes':target.stat().st_size})
    save('sea_waves','sea_waves',loop=True)
    save('wind_leaves','wind_leaves',start=35.,length=75.,loop=True,source_override='files/wind_leaves_listen_v3.mp3')
    gull = SOURCE/sources['sea_gulls']['file']
    for i,(start,length) in enumerate(regions(samples(gull),4,8.,.3,2.2)):
        save('gull_%02d'%(i+1),'sea_gulls',start,length)
    for i,(start,length) in enumerate([(0.,1.5),(1.15,1.8)]):
        save('bird_%02d'%(i+1),'land_birds',start,length)
    water = SOURCE/sources['wading_steps']['file']
    for i,(start,length) in enumerate(regions(samples(water),6,2.,.23,.8)):
        save('water_step_%02d'%(i+1),'wading_steps',start,length)
    save('vehicle_start','vehicle_start')
    (OUT/'manifest.json').write_text(json.dumps({'prepared_on':'2026-10-30','game_assets':outputs,'source_files_preserved':True,'wind_note':'Uses the loudness-corrected audition copy; original download remains untouched.'},ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    credits=['Project PR - world sound credits (CC0 1.0)','Derived game files are edited from the following sources.','Freesound materials use the public HQ compressed previews at this prototype stage.','']
    for row in sources.values():credits += [row['title']+' - '+row['author'],row['source'],'License: '+row['license'],'']
    (OUT/'CREDITS.txt').write_text('\n'.join(credits),encoding='utf-8')
    print(json.dumps({'assets':len(outputs),'size_mib':round(sum(r['bytes'] for r in outputs)/1048576,2),'clips':[{k:r[k] for k in ['file','start_seconds','length_seconds']} for r in outputs]},ensure_ascii=True))


if __name__ == '__main__':main()
