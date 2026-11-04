"""Arrange actual Godot renders and encode their native 1x playback captures."""
from pathlib import Path
import json
from PIL import Image, ImageDraw, ImageFont

ROOT=Path(__file__).resolve().parents[1]
BASE=ROOT/'docs/character_locomotion_1104'


def main():
    clips=json.loads((ROOT/'assets/characters/roster/neutral_clips.json').read_text(encoding='utf8'))['build']
    for motion,formal in [('walk','A05'),('run','A06')]:
        directory=(BASE/('frames_'+motion)).resolve()
        assert directory.parent==BASE.resolve()
        paths=sorted(directory.glob('*.png'));assert paths
        frames=[]
        for path in paths:
            with Image.open(path) as image:frames.append(image.convert('RGB').resize((960,540)))
        palette=frames[0].quantize(colors=256)
        frames=[im.quantize(palette=palette,dither=Image.Dither.NONE) for im in frames]
        duration=next(c['duration'] for c in clips if c['formal_id']==formal)*2
        # GIF stores 10 ms ticks; distribute rounding instead of speeding up
        # 30 fps captures by giving every frame the same truncated duration.
        ticks=[round(min(i*2/60,duration)*100) for i in range(len(frames))]+[round(duration*100)]
        delays=[10*(b-a) for a,b in zip(ticks,ticks[1:])]
        frames[0].save(BASE/(motion+'_comparison.gif'),save_all=True,append_images=frames[1:],duration=delays,loop=0,optimize=False,disposal=2)
        for path in paths:path.unlink()
        directory.rmdir()
        print(motion,len(frames),'frames',sum(delays),'ms')
    font=ImageFont.truetype('C:/Windows/Fonts/msyh.ttc',22)
    for batch in ['first','second']:
        rows=json.loads((ROOT/f'assets/characters/roster/{batch}_batch.json').read_text(encoding='utf8'))['profiles']
        for motion in ['walk','run']:
            sheet=Image.new('RGB',(280*len(rows),875),'#202936');draw=ImageDraw.Draw(sheet)
            for column,row in enumerate(rows):
                draw.text((column*280+65,8),row['label'],font=font,fill='white')
                for line,view in enumerate(['front','side']):
                    with Image.open(BASE/f'{row["id"]}_{motion}_{view}.png') as source:
                        cx=source.width//2;im=source.convert('RGB').crop((cx-240,0,cx+240,source.height));im.thumbnail((270,405));sheet.paste(im,(column*280+5,45+line*415))
            sheet.save(BASE/f'{batch}_{motion}_sheet.png')


if __name__=='__main__':main()
