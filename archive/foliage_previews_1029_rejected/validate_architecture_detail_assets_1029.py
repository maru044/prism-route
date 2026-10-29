"""Read-only image/renderer analysis for generated architecture texture assets."""
from pathlib import Path
from PIL import Image
import hashlib,json
import numpy as np
ROOT=Path(__file__).resolve().parents[2]
ASSETS=ROOT/'assets/world/architecture_details_1029'
OUT=ROOT/'docs/architecture_details_1029'

def main():
    source={};failures=[]
    seam=np.array(Image.open(ASSETS/'seam_wear_mask_v1.png').convert('RGB'));h,w=seam.shape[:2]
    active=seam[:,:,0]>64;ys,xs=np.where(active)
    source['seam']={'dimensions':[w,h],'format':'RGB, red channel is linear data','sha256':hashlib.sha256((ASSETS/'seam_wear_mask_v1.png').read_bytes()).hexdigest(),'active_bounds':[int(xs.min()),int(ys.min()),int(xs.max()+1),int(ys.max()+1)],'samples_vertical_edges':[int(active[0].sum()),int(active[-1].sum())]}
    if not active[0].any() or not active[-1].any():failures.append('Seam does not reach longitudinal edges')
    if xs.min()<w*.2 or xs.max()>w*.8:failures.append('Seam mask extends outside its intended center band')
    atlas=Image.open(ASSETS/'foliage_leaf_mask_v2.png');p=np.array(atlas.convert('RGBA'));a=p[:,:,3];h,w=a.shape
    if atlas.mode!='RGBA' or a.min()!=0 or a.max()!=255:failures.append('Atlas is not a genuine RGBA cutout')
    plants={'dimensions':[w,h],'format':atlas.mode,'filename':'foliage_leaf_mask_v2.png','color_mode':'alpha silhouette only; existing project palette controls RGB','sha256':hashlib.sha256((ASSETS/'foliage_leaf_mask_v2.png').read_bytes()).hexdigest(),'transparent_fraction':float((a==0).mean()),'cells':[]}
    for y in range(2):
        for x in range(2):
            q=a[y*h//2:(y+1)*h//2,x*w//2:(x+1)*w//2];ys,xs=np.where(q>32)
            padding=[int(xs.min()),int(ys.min()),int(q.shape[1]-1-xs.max()),int(q.shape[0]-1-ys.max())]
            if min(padding)<16:failures.append('Atlas content is too close to a cell boundary')
            # Check all alpha, including faint antialias fringes, in a safety border.
            border=np.r_[q[:8].ravel(),q[-8:].ravel(),q[:,:8].ravel(),q[:,-8:].ravel()]
            if border.max()>1:failures.append('Atlas cell border contains visible stray alpha')
            plants['cells'].append({'cell':[x,y],'content_bounds':[int(xs.min()),int(ys.min()),int(xs.max()+1),int(ys.max()+1)],'padding_pixels':padding,'border_alpha_max':int(border.max())})
    source['plants']=plants
    before=json.loads((ROOT/'.current_map_build/decal_lab_before.json').read_text(encoding='utf-8'))
    unchanged={p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest()==digest for p,digest in before.items()}
    if not all(unchanged.values()):failures.append('Formal map or existing material changed')
    render={}
    for name in ['close_all','close_joints','close_clean','close_plants','leaf_recolor']:
        file=OUT/(name+'.png')
        if file.exists():render[name]=np.array(Image.open(file).convert('RGB')).astype(np.int16)
    comparisons={}
    for a_name,b_name,key in [('close_joints','close_clean','seams_visible'),('close_plants','close_clean','plants_visible'),('leaf_recolor','close_plants','palette_recolor_visible')]:
        if a_name in render and b_name in render:
            delta=np.abs(render[a_name]-render[b_name]).max(axis=2);changed=float((delta>=4).mean())
            comparisons[key]={'changed_pixel_fraction':changed}
            if changed<.0002:failures.append('Rendered material layer made no visible difference: '+key)
    result={'passed':not failures,'failures':failures,'sources':source,'formal_files_unchanged':unchanged,'render_comparisons':comparisons,'longitudinal_repeat':'shader mirrored sampling; no resampling/editing of generated PNGs'}
    (OUT/'asset_report.json').write_text(json.dumps(result,indent=2),encoding='utf-8')
    (ASSETS/'asset_manifest.json').write_text(json.dumps({'version':2,'generation':'built-in image_gen','sources':source,'atlas_layout':['narrow_leaf_cluster','broad_leaf_cluster','hanging_leaf_cluster','low_leaf_cluster'],'post_generation_pixel_edits':False,'shape_revised_with_imagegen':True,'shader_leaf_alpha_cutoff':.42,'shader_leaf_alpha_feather':.06,'runtime_uses_texture_rgb':False,'palette_source':'scripts/foliage_style.gd:GREEN_VALUES.species_mid_color'},indent=2),encoding='utf-8')
    print(json.dumps({'passed':result['passed'],'failures':failures,'render_comparisons':comparisons,'formal_map_unchanged':all(unchanged.values())}))
    return 0 if result['passed'] else 1
if __name__=='__main__':raise SystemExit(main())
