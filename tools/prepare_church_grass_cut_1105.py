"""Rasterize the actual paving triangles, retaining the neighboring meadow."""
from pathlib import Path
import json,hashlib
import numpy as np
from scipy.ndimage import maximum_filter
ROOT=Path(__file__).resolve().parents[1]
DEST=ROOT/'assets/world/church_ruins_1105'
CACHE=ROOT/'.current_map_build/church_ruins_1105'

def main():
    source=json.loads((CACHE/'source.json').read_text(encoding='utf8'));raw=(CACHE/'source.bin').read_bytes();triangles=[];ids=[]
    for row in source['objects']:
        if row['category']!='07_pathway' and 'MainFloorPlinth' not in row['name']:continue
        n=row['vertex_count'];p=np.frombuffer(raw,'<f4',n*3,row['offset']).reshape(-1,3).astype(float)
        p-=np.array(source['native_center']);p=p[:,[0,2,1]];p[:,2]*=-1
        indices=np.frombuffer(raw,'<u4',row['index_count'],row['offset']+n*12).reshape(-1,3)
        tris=p[indices];normals=np.cross(tris[:,1]-tris[:,0],tris[:,2]-tris[:,0]);length=np.linalg.norm(normals,axis=1)
        keep=np.abs(normals[:,1])>.7*np.maximum(length,1e-10)
        triangles.extend(tris[keep]);ids.append(row['id'])
    tris=np.array(triangles);pixel=.2;margin=.8
    low=np.floor((tris[:,:,[0,2]].min((0,1))-2)/pixel)*pixel;high=np.ceil((tris[:,:,[0,2]].max((0,1))+2)/pixel)*pixel
    width,height=np.ceil((high-low)/pixel).astype(int);image=np.full((height,width),-10000.,dtype='<f4')
    for tri in tris:
        xy=(tri[:,[0,2]]-low)/pixel-.5
        a,b,c=xy;den=(b[1]-c[1])*(a[0]-c[0])+(c[0]-b[0])*(a[1]-c[1])
        if abs(den)<1e-9:continue
        x0,y0=np.maximum(np.floor(xy.min(0)).astype(int),0);x1,y1=np.minimum(np.ceil(xy.max(0)).astype(int),[width-1,height-1])
        yy,xx=np.mgrid[y0:y1+1,x0:x1+1]
        u=((b[1]-c[1])*(xx-c[0])+(c[0]-b[0])*(yy-c[1]))/den
        v=((c[1]-a[1])*(xx-c[0])+(a[0]-c[0])*(yy-c[1]))/den;w=1-u-v
        mask=(u>=-1e-5)&(v>=-1e-5)&(w>=-1e-5)
        view=image[y0:y1+1,x0:x1+1];values=u*tri[0,1]+v*tri[1,1]+w*tri[2,1]
        view[mask]=np.maximum(view[mask],values[mask])
    image=maximum_filter(image,size=2*round(margin/pixel)+1,mode='constant',cval=-10000.)
    (DEST/'grass_cut.rf').write_bytes(image.astype('<f4').tobytes())
    candidates=json.loads((ROOT/'assets/world/current_map_validation/grass_cells.json').read_text(encoding='utf8'))['cells']
    cells=[c for c in candidates if c[0]*24<high[0] and (c[0]+1)*24>low[0] and c[2]*24<high[1] and (c[2]+1)*24>low[1] and c[1]*24<46 and (c[1]+1)*24>29]
    config=dict(version=1,origin_xz=low.tolist(),extent_xz=(high-low).tolist(),size=[int(width),int(height)],pixel_size=pixel,edge_margin_m=margin,height_below_m=12.,height_above_m=2.,cells=cells,paving_source_ids=ids,mask_sha256=hashlib.sha256((DEST/'grass_cut.rf').read_bytes()).hexdigest(),source_geometry_sha256=hashlib.sha256((DEST/'church.glb').read_bytes()).hexdigest(),covered_area_m2=float(np.count_nonzero(image>-9999)*pixel**2))
    (DEST/'ground_grass.json').write_text(json.dumps(config,ensure_ascii=False,indent=2)+'\n',encoding='utf8')
    print('CHURCH_GRASS_CUT',len(cells),'cells',round(config['covered_area_m2'],2),'m2')

if __name__=='__main__':main()
