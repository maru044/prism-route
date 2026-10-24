"""Arrange actual A/B captures and check that switching back restores A."""
from pathlib import Path
import json
import numpy as np
from PIL import Image, ImageDraw, ImageFont

ROOT=Path(__file__).resolve().parents[1]
BUILD=ROOT/'.vegetation_art_build/backlight_1024'
DEST=ROOT/'screenshots'


def main():
    metrics=json.loads((BUILD/'runtime.json').read_text(encoding='utf-8'))
    metrics['image_restore_checks']={}
    for view in ('bridge','backlit','frontlit'):
        a=np.array(Image.open(BUILD/(view+'_a_original.png')).convert('RGB'),dtype=float)
        restored=np.array(Image.open(BUILD/(view+'_a_restore.png')).convert('RGB'),dtype=float)
        delta=np.abs(a-restored)
        metrics['image_restore_checks'][view]={'mean_absolute_byte_error':float(delta.mean()),
            'p99_absolute_byte_error':float(np.percentile(delta,99)),
            'maximum_absolute_byte_error':float(delta.max())}
        assert delta.mean()<.01 and np.percentile(delta,99)<=1, (view,'A did not restore')
        rows=[r for r in metrics['captures'] if r['view']==view]
        assert len({(r['draws'],r['primitives']) for r in rows})==1
    font=ImageFont.truetype('C:/Windows/Fonts/msyh.ttc',22)
    canvas=Image.new('RGB',(1200,620),'#18232d');draw=ImageDraw.Draw(canvas)
    for i,(tag,label) in enumerate([('a_original','A · 原版'),('b_soft','B · 收敛新版，补光 6%')]):
        picture=Image.open(BUILD/('backlit_'+tag+'.png')).convert('RGB')
        picture=picture.crop((540,210,1040,690)).resize((600,576),Image.Resampling.LANCZOS)
        canvas.paste(picture,(i*600,44));draw.text((i*600+16,8),label,font=font,fill='white')
    DEST.mkdir(exist_ok=True)
    canvas.save(DEST/'foliage_backlight_comparison.png')
    metrics['baseline_shader_hashes']=json.loads((BUILD/'baseline_shader_hashes.json').read_text())
    (DEST/'foliage_backlight_comparison_metrics.json').write_text(json.dumps(metrics,indent=2)+'\n',encoding='utf-8')
    print(json.dumps(metrics['image_restore_checks'],indent=2))


if __name__=='__main__':main()
