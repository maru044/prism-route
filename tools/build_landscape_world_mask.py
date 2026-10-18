"""Build the current Rhino region and CAD-authored world mask; no cover mesh.

Run with the workstation Python (numpy, Pillow, scipy, opencv). Intermediate
mesh buffers live in one ignored build directory; the final model is one GLB.
"""
from pathlib import Path
import json, struct, hashlib, argparse
import numpy as np
import cv2
from scipy.spatial import cKDTree
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
CACHE = ROOT / '.landscape_mask_build'
OUT = ROOT / 'assets/world/landscape_mask_test'

def build_glb(source):
    raw = (CACHE/'source.bin').read_bytes()
    center = np.asarray(source['native_center'], dtype=np.float32)
    blob = bytearray(); views=[]; accessors=[]; meshes=[]; nodes=[]; terrain=[]
    def array(a, component, shape, target, bounds=False):
        while len(blob)%4: blob.append(0)
        a=np.ascontiguousarray(a); start=len(blob); blob.extend(a.tobytes())
        view=len(views); views.append({'buffer':0,'byteOffset':start,'byteLength':a.nbytes,'target':target})
        acc={'bufferView':view,'componentType':component,'count':len(a),'type':shape}
        if bounds: acc.update(min=a.min(axis=0).astype(float).tolist(),max=a.max(axis=0).astype(float).tolist())
        accessors.append(acc);return len(accessors)-1
    for item in source['objects']:
        count=item['vertex_count']; offset=item['offset']
        p=np.frombuffer(raw,'<f4',count=count*3,offset=offset).reshape(-1,3).copy()
        ix=np.frombuffer(raw,'<u4',count=item['index_count'],offset=offset+count*12).copy()
        assert np.isfinite(p).all() and ix.max()<len(p)
        p-=center; p=p[:,[0,2,1]];p[:,2]*=-1
        tri=ix.reshape(-1,3)
        face=np.cross(p[tri[:,1]]-p[tri[:,0]],p[tri[:,2]]-p[tri[:,0]])
        normals=np.zeros_like(p)
        for j in range(3):np.add.at(normals,tri[:,j],face)
        normals/=np.maximum(np.linalg.norm(normals,axis=1,keepdims=True),1e-12)
        pi=array(p.astype('<f4'),5126,'VEC3',34962,True)
        ni=array(normals.astype('<f4'),5126,'VEC3',34962)
        ii=array(ix.astype('<u4'),5125,'SCALAR',34963)
        meshes.append({'primitives':[{'attributes':{'POSITION':pi,'NORMAL':ni},'indices':ii,'mode':4}]})
        nodes.append({'name':item['kind']+'_'+item['id'],'mesh':len(meshes)-1,'extras':{'source_id':item['id'],'source_name':item['name'],'kind':item['kind']}})
        if item['kind']=='Terrain':terrain.append((p,tri,face))
    gltf={'asset':{'version':'2.0','generator':'Prism Route CAD world-mask test'},'scene':0,'scenes':[{'nodes':list(range(len(nodes)))}],
          'nodes':nodes,'meshes':meshes,'buffers':[{'byteLength':len(blob)}],'bufferViews':views,'accessors':accessors}
    js=json.dumps(gltf,separators=(',',':')).encode();js+=b' '*((-len(js))%4)
    blob+=b'\0'*((-len(blob))%4)
    output=struct.pack('<III',0x46546C67,2,12+8+len(js)+8+len(blob))+struct.pack('<II',len(js),0x4E4F534A)+js+struct.pack('<II',len(blob),0x004E4942)+blob
    (OUT/'current_region.glb').write_bytes(output)
    return terrain

def build_mask(source,resolution):
    center=np.asarray(source['native_center'],dtype=float)
    curves=[]
    for c in source['curves']:
        p=np.asarray(c['points_xy'],dtype=float)-center[:2]
        p[:,1]*=-1
        length=np.r_[0,np.cumsum(np.linalg.norm(np.diff(p,axis=0),axis=1))]
        fraction=length/max(length[-1],1)
        half=c['width_m']*.5*np.maximum(.005,np.sin(np.pi*fraction)**.4)
        tangent=np.gradient(p,axis=0);tangent/=np.maximum(np.linalg.norm(tangent,axis=1,keepdims=True),1e-8)
        normal=np.c_[-tangent[:,1],tangent[:,0]]
        polygon=np.r_[p+normal*half[:,None],(p-normal*half[:,None])[::-1]]
        hs=np.asarray(c['heights']);valid=hs[:,1]>-500
        height=np.interp(np.arange(len(p)),hs[valid,0],hs[valid,1])
        curves.append((p,polygon,half,height))
    points=np.concatenate([c[0] for c in curves]);heights=np.concatenate([c[3] for c in curves])
    origin=np.floor(points.min(axis=0)-24);extent=np.ceil(points.max(axis=0)+24)-origin
    high=resolution*2
    raster=np.zeros((high,high),np.uint8)
    for p,polygon,half,height in curves:
        pix=np.round((polygon-origin)/extent*high).astype(np.int32)
        cv2.fillPoly(raster,[pix],255,lineType=cv2.LINE_AA)
    binary=(raster>=128).astype(np.uint8)
    # Raster EDT only locates a bounded work band. Final distances are measured
    # against subpixel CAD boundary segments, not the quantized bitmap contour.
    outside=cv2.distanceTransform(1-binary,cv2.DIST_L2,cv2.DIST_MASK_PRECISE)
    coarse=cv2.resize(outside,(resolution,resolution),interpolation=cv2.INTER_AREA)*float(np.min(extent/high))
    del outside,raster,binary
    inside=np.zeros((resolution,resolution),dtype=bool)
    segment_a=[];segment_b=[]
    grid_x=origin[0]+(np.arange(resolution)+.5)*extent[0]/resolution
    for _,poly,_,_ in curves:
        a=poly;b=np.roll(poly,-1,axis=0)
        segment_a.append(a);segment_b.append(b)
        # Exact even-odd inclusion at texture sample centres; independent of
        # the supersampled raster, including the pointed endpoints.
        for row in range(resolution):
            y=origin[1]+(row+.5)*extent[1]/resolution
            active=(a[:,1]>y)!=(b[:,1]>y)
            aa=a[active];bb=b[active]
            if not len(aa):continue
            cuts=np.sort(aa[:,0]+(y-aa[:,1])*(bb[:,0]-aa[:,0])/(bb[:,1]-aa[:,1]))
            inside[row]|=(np.searchsorted(cuts,grid_x,side='right')%2)==1
    a=np.concatenate(segment_a);b=np.concatenate(segment_b);ab=b-a
    segments=cKDTree((a+b)*.5)
    sdf=np.full((resolution,resolution),18,dtype=np.float32)
    ys,xs=np.where(coarse<19)
    max_distance_error=0.0
    for start in range(0,len(xs),100000):
        sl=slice(start,start+100000)
        xy=np.c_[xs[sl]+.5,ys[sl]+.5]/resolution*extent+origin
        _,ix=segments.query(xy,k=8,workers=2)
        ap=xy[:,None,:]-a[ix];direction=ab[ix]
        t=np.clip(np.sum(ap*direction,axis=2)/np.maximum(np.sum(direction**2,axis=2),1e-16),0,1)
        distance=np.sqrt(np.min(np.sum((ap-t[:,:,None]*direction)**2,axis=2),axis=1))
        if start==0:
            # Check the candidate acceleration against ALL CAD segments. This
            # catches a long tip segment being skipped by the midpoint tree.
            test=xy[::max(1,len(xy)//256)]
            all_ap=test[:,None,:]-a
            all_t=np.clip(np.sum(all_ap*ab,axis=2)/np.maximum(np.sum(ab**2,axis=1),1e-16),0,1)
            exact=np.sqrt(np.min(np.sum((all_ap-all_t[:,:,None]*ab)**2,axis=2),axis=1))
            max_distance_error=float(np.max(np.abs(exact-distance[::max(1,len(xy)//256)])))
            assert max_distance_error<0.005, max_distance_error
        sdf[ys[sl],xs[sl]]=distance
    sdf[inside]*=-1
    del inside,coarse
    # Height is defined from sparse exact surface samples along the CAD curves,
    # not from rasterized terrain triangles. Guard upper/lower storeys separately.
    field=np.zeros((resolution,resolution),np.float32)
    ys,xs=np.where(np.abs(sdf)<18)
    tree=cKDTree(points)
    for start in range(0,len(xs),250000):
        sl=slice(start,start+250000)
        xy=np.c_[xs[sl]+.5,ys[sl]+.5]/resolution*extent+origin
        _,nearest=tree.query(xy,workers=2)
        field[ys[sl],xs[sl]]=heights[nearest]
    packed=np.stack([np.clip(sdf,-18,18),field],axis=-1).astype('<f2')
    packed.tofile(CACHE/'landscape_mask.rg16f')
    coverage=(1-np.clip(.5+sdf/(2*np.mean(extent/resolution)),0,1))
    Image.fromarray(np.uint8(coverage*255)).save(OUT/'cad_mask.png')
    return {'resolution':resolution,'supersample':2,'distance_method':'subpixel CAD-segment distance; exact even-odd sign',
            'origin_xz':origin.tolist(),'extent_xz':extent.tolist(),
            'meters_per_texel':(extent/resolution).tolist(),'sdf_range_m':18.0,
            'segment_distance_check_max_error_m':max_distance_error,
            'cad_white_area_m2':float(coverage.sum()*np.prod(extent/resolution))},sdf,field

def validate_coverage(terrain,mask,sdf,field):
    res=mask['resolution'];origin=np.asarray(mask['origin_xz']);extent=np.asarray(mask['extent_xz'])
    eligible=0.;white=0.;up_samples=0
    for p,tri,face in terrain:
        cent=p[tri].mean(axis=1);normal=face/np.maximum(np.linalg.norm(face,axis=1,keepdims=True),1e-10)
        uv=(cent[:,[0,2]]-origin)/extent
        valid=(normal[:,1]>.65)&(uv>=0).all(axis=1)&(uv<=1).all(axis=1)
        cent=cent[valid];area=np.abs(face[valid,1])*.5;up_samples+=len(area)
        pix=np.clip((uv[valid]*res).astype(int),0,res-1)
        d=sdf[pix[:,1],pix[:,0]];h=field[pix[:,1],pix[:,0]]
        selected=(d<0)&(np.abs(cent[:,1]-h)<6)
        eligible+=area.sum();white+=area[selected].sum()
    return {'upward_triangle_samples':up_samples,'weighted_upward_grass_fraction':float(1-white/max(eligible,1)),
            'note':'Area-weighted triangle sampling, with overlapping source components; not an exact land-union percentage.'}

def main():
    ap=argparse.ArgumentParser();ap.add_argument('--resolution',type=int,default=4096);args=ap.parse_args()
    OUT.mkdir(parents=True,exist_ok=True)
    source=json.loads((CACHE/'source.json').read_text(encoding='utf-8-sig'))
    terrain=build_glb(source)
    print('Current region GLB ready',flush=True)
    meta,sdf,height=build_mask(source,args.resolution)
    meta.update(source_document=source['source'],native_center=source['native_center'],
                mesh_tolerance_m=source['mesh_tolerance_m'],mesh_angle_rad=source['mesh_angle_rad'],mesh_max_edge_m=source['mesh_max_edge_m'],
                objects=len(source['objects']),triangles=sum(r['index_count']//3 for r in source['objects']),
                mesh_sha256=hashlib.sha256((OUT/'current_region.glb').read_bytes()).hexdigest(),
                validation=validate_coverage(terrain,meta,sdf,height))
    # Camera target on the low-court stroke; current Rhino Z maps to Godot Y.
    c=source['curves'][min(2,len(source['curves'])-1)];k=len(c['points_xy'])//2
    x,y=c['points_xy'][k];hs=np.asarray(c['heights']);z=float(np.interp(k,hs[:,0],hs[:,1]))
    meta['near_target']=[x-source['native_center'][0],z,source['native_center'][1]-y]
    (OUT/'metadata.json').write_text(json.dumps(meta,ensure_ascii=False,indent=2),encoding='utf-8')
    (OUT/'cad_layout.json').write_text(json.dumps(source['curves'],ensure_ascii=False,separators=(',',':')),encoding='utf-8')
    print(json.dumps(meta,ensure_ascii=False,indent=2),flush=True)

if __name__=='__main__':main()
