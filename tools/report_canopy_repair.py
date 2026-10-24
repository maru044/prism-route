"""Package measured audit data and matched Godot screenshots for review.

Standard Python with Pillow; this only arranges actual renders, no retouching.
"""
from pathlib import Path
import hashlib
import json
from PIL import Image, ImageDraw, ImageFont

ROOT=Path(__file__).resolve().parents[1]
BUILD=ROOT/'.vegetation_art_build/canopy_gaps_1023'
DEST=ROOT/'screenshots'
STEMS={'broad':'tree_medium_broad_clustered_canopy','upright':'tree_medium_upright_asymmetric_canopy'}


def main():
    DEST.mkdir(exist_ok=True)
    font=ImageFont.truetype('C:/Windows/Fonts/msyh.ttc',22)
    canvas=Image.new('RGB',(1400,1472),'#18232d');draw=ImageDraw.Draw(canvas)
    # Use the original imported Godot baseline, with identical cameras/materials.
    for row,(key,index,label) in enumerate([('broad',1,'宽冠大树'),('upright',0,'直立大树')]):
        for column,stage in enumerate(('before','after')):
            pic=Image.open(BUILD/f'{stage}_{key}_{index}.png').convert('RGB')
            pic=pic.crop((420,130,1170,870)).resize((700,690),Image.Resampling.LANCZOS)
            canvas.paste(pic,(column*700,row*736+46))
            draw.text((column*700+18,row*736+9),label+' · '+('修补前' if stage=='before' else '修补后'),font=font,fill='white')
    canvas.save(DEST/'canopy_gap_repair_comparison.png')
    validation=json.loads((BUILD/'validation.json').read_text(encoding='utf-8'))
    result={'method':'alpha-aware BVH, 16 selection views and 16 held-out views per tree',
        'ray_grid':[128,128],'depth_threshold_m':1.5,'min_region_area_m2':.075,
        'view_area_note':'Sum of projected observations, not unique physical surface area.',
        'baseline_triangles':57788,'repaired_triangles':59836,'species':{}}
    for key,stem in STEMS.items():
        before=json.loads((BUILD/(key+'_before.json')).read_text())
        after=json.loads((BUILD/(key+'_after.json')).read_text())
        row={'selection_before_m2':before['total_macro_hole_area_m2'],
            'selection_after_m2':after['total_macro_hole_area_m2'],
            'selection_reduction':1-after['total_macro_hole_area_m2']/before['total_macro_hole_area_m2'],
            'validation':validation[key],'patches':after['patches'],'added_leaf_cards':after['added_logical_cards'],
            'assets':{}}
        for path in [ROOT/'assets/vegetation/source'/(stem+'.blend'),ROOT/'assets/vegetation/models'/(stem+'.glb')]:
            row['assets'][str(path.relative_to(ROOT)).replace('\\','/')]= {'bytes':path.stat().st_size,'sha256':hashlib.sha256(path.read_bytes()).hexdigest()}
        result['species'][key]=row
    (DEST/'canopy_gap_repair_metrics.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8')


if __name__=='__main__':main()
