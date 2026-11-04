"""Compose the actual Godot captures, without generating or retouching model art."""
from pathlib import Path
import argparse,json
from PIL import Image,ImageDraw,ImageFont
ROOT=Path(__file__).resolve().parents[2]

def main():
    parser=argparse.ArgumentParser();parser.add_argument('--catalog',type=Path,default=ROOT/'assets/characters/roster/first_batch.json');parser.add_argument('--out',type=Path,default=ROOT/'docs/character_batch_1104');args=parser.parse_args()
    rows=json.loads(args.catalog.read_text(encoding='utf8'))['profiles']
    base=args.out;font=ImageFont.truetype('C:/Windows/Fonts/msyh.ttc',22)
    for output,views in [('contact_sheet.png',['front','side']),('walk_sheet.png',['walk_front','walk_side'])]:
        sheet=Image.new('RGB',(280*len(rows),875),'#202936');draw=ImageDraw.Draw(sheet)
        for i,row in enumerate(rows):
            draw.text((i*280+75,8),row['label'],font=font,fill='white')
            for j,view in enumerate(views):
                image=Image.open(base/f'{row["id"]}_{view}.png').convert('RGB');cx=image.width//2
                image=image.crop((cx-240,0,cx+240,image.height));image.thumbnail((270,405));sheet.paste(image,(i*280+5,45+j*415))
        sheet.save(base/output)
        print(output)

if __name__=='__main__':main()
