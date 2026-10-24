"""Curate real engine colour comparisons and verify restoring original colours."""
from pathlib import Path
import json
import numpy as np
from PIL import Image, ImageDraw, ImageFont

ROOT=Path(__file__).resolve().parents[1]
BUILD=ROOT/'.vegetation_art_build/color_1024'
DEST=ROOT/'screenshots'


def difference(a,b):
    a=np.array(Image.open(a).convert('RGB'),dtype=float)
    b=np.array(Image.open(b).convert('RGB'),dtype=float)
    d=np.abs(a-b)
    assert d.mean()<.01 and np.percentile(d,99)<=1
    return {'mean_absolute_byte_error':float(d.mean()),'p99_absolute_byte_error':float(np.percentile(d,99)),'maximum_absolute_byte_error':float(d.max())}


def main():
    DEST.mkdir(exist_ok=True)
    metrics=json.loads((BUILD/'runtime.json').read_text(encoding='utf-8'))
    metrics['mask_audit']=json.loads((BUILD/'mask_audit.json').read_text(encoding='utf-8'))
    metrics['original_colour_restore']={v:difference(BUILD/(v+'_original.png'),BUILD/(v+'_restored.png')) for v in ('frontlit','backlit')}
    metrics['grove_flower_unchanged']={str(i):difference(BUILD/'grove_flower_mode0.png',BUILD/('grove_flower_mode%d.png'%i)) for i in (1,2)}
    metrics['reference']='https://mui.com/material-ui/customization/color/'
    metrics['candidate_palette']={'deep':'#2E7D32','shadow':'#388E3C','main':'#66BB6A','light':'#81C784'}
    metrics['default_green_mode']='approved fresh green; no runtime comparison hotkeys'
    font=ImageFont.truetype('C:/Windows/Fonts/msyh.ttc',22)
    canvas=Image.new('RGB',(1600,980),'#18232d');draw=ImageDraw.Draw(canvas)
    for row,(view,name) in enumerate([('frontlit','顺光'),('backlit','逆光')]):
        for col,(tag,label) in enumerate([('original','原色'),('fresh','清脆叶绿 · 对比')]):
            picture=Image.open(BUILD/(view+'_'+tag+'.png')).convert('RGB').resize((800,450),Image.Resampling.LANCZOS)
            canvas.paste(picture,(col*800,row*490+40))
            draw.text((col*800+16,row*490+7),name+' / '+label,font=font,fill='white')
    canvas.save(DEST/'foliage_green_color_comparison.png')
    ground=Image.new('RGB',(1600,490),'#18232d');draw=ImageDraw.Draw(ground)
    for col,(tag,label) in enumerate([('legacy','原地面独立分区'),('shared','地面复用草的分区与配对底色')]):
        picture=Image.open(BUILD/('ground_'+tag+'.png')).convert('RGB').resize((800,450),Image.Resampling.LANCZOS)
        ground.paste(picture,(col*800,40));draw.text((col*800+16,7),label,font=font,fill='white')
    ground.save(DEST/'meadow_color_mask_comparison.png')
    swatches=Image.new('RGB',(1200,250),'#18232d');draw=ImageDraw.Draw(swatches)
    for i,(role,hex_value) in enumerate([('暗部','#388E3C'),('主色','#66BB6A'),('亮部','#81C784')]):
        draw.rectangle((i*400+12,12,i*400+388,185),fill=hex_value)
        draw.text((i*400+20,200),role+'  '+hex_value,font=font,fill='white')
    swatches.save(DEST/'foliage_green_palette.png')
    (DEST/'foliage_green_color_metrics.json').write_text(json.dumps(metrics,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print(json.dumps({'restore':metrics['original_colour_restore'],'flower':metrics['grove_flower_unchanged']},indent=2))


if __name__=='__main__':main()
