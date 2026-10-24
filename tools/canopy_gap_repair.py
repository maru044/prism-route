"""Alpha-aware multi-view canopy audit/repair in Blender; no texture edits.

Uses BVH rays, interpolated UV alpha and the close-range Godot edge/view fade.
Only macroscopic, enclosed low-coverage regions qualify; fine leaf gaps and
the outer silhouette are deliberately retained. All distances are metres.
"""
import argparse
from collections import deque
import json
import math
import random
import hashlib
import shutil
from pathlib import Path
import sys
import time

import bpy
import numpy as np
from mathutils import Vector
from mathutils.bvhtree import BVHTree

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / '.vegetation_art_build/canopy_gaps_1023'
STEMS = {'broad':'tree_medium_broad_clustered_canopy',
         'upright':'tree_medium_upright_asymmetric_canopy'}
RECIPE = ROOT / 'assets/vegetation/source/canopy_gap_patches.json'


def geometry_signature(objects):
    """Bind patch coordinates to a specific authored layout, not just its name."""
    digest=hashlib.sha256()
    for obj in sorted(objects,key=lambda o:o.name):
        digest.update(obj.name.encode('utf-8'))
        digest.update(np.array(obj.matrix_world,dtype='<f4').tobytes())
        digest.update(np.array([tuple(v.co) for v in obj.data.vertices],dtype='<f4').tobytes())
    return digest.hexdigest()


def apply_saved_patches(trunk,objects,key):
    """Replay the reviewed repair during generation without rerunning the audit."""
    if trunk.get('canopy_gap_repair_version'):
        raise RuntimeError('Canopy patches already applied')
    bpy.context.view_layer.update()
    row=json.loads(RECIPE.read_text(encoding='utf-8'))[key]
    if geometry_signature(objects)!=row['base_geometry_sha256']:
        raise RuntimeError('Crown layout changed; rerun the alpha/depth audit before reusing patches')
    selected,cards=repair(objects,row['patch_locations'],key,limit=32)
    assert len(selected)==len(row['patch_locations']) and cards==row['added_logical_cards']
    trunk['canopy_gap_repair_version']='20261023_alpha_depth_v1'
    trunk['canopy_gap_repair_cards']=cards
    trunk['logical_card_count']=sum(len(o.data.polygons)//2 for o in objects)
    return cards


def smooth(a,b,x):
    t=max(0.,min(1.,(x-a)/(b-a)))
    return t*t*(3.-2.*t)


def box_mean(a,r):
    n=2*r+1
    p=np.pad(a.astype(float),r,mode='edge')
    s=np.pad(p,((1,0),(1,0))).cumsum(0).cumsum(1)
    return (s[n:,n:]-s[:-n,n:]-s[n:,:-n]+s[:-n,:-n])/(n*n)


def morph(a,r,dilate):
    p=np.pad(a,r,constant_values=not dilate)
    views=[p[y:y+a.shape[0],x:x+a.shape[1]]
           for y in range(2*r+1) for x in range(2*r+1)]
    return np.logical_or.reduce(views) if dilate else np.logical_and.reduce(views)


def local_min(a,r):
    p=np.pad(a,r,constant_values=np.inf)
    return np.minimum.reduce([p[y:y+a.shape[0],x:x+a.shape[1]]
        for y in range(2*r+1) for x in range(2*r+1)])


def local_max(a,r):return -local_min(-a,r)


def fill_holes(a):
    seen=np.zeros_like(a);q=deque()
    h,w=a.shape
    for y,x in [(y,x) for y in (0,h-1) for x in range(w)]+[(y,x) for x in (0,w-1) for y in range(h)]:
        if not a[y,x] and not seen[y,x]:seen[y,x]=True;q.append((y,x))
    while q:
        y,x=q.popleft()
        for dy,dx in ((1,0),(-1,0),(0,1),(0,-1)):
            yy,xx=y+dy,x+dx
            if 0<=yy<h and 0<=xx<w and not a[yy,xx] and not seen[yy,xx]:
                seen[yy,xx]=True;q.append((yy,xx))
    return ~seen


def components(a):
    a=a.copy();h,w=a.shape;found=[]
    for y,x in zip(*np.nonzero(a)):
        if not a[y,x]:continue
        a[y,x]=False;q=deque([(y,x)]);pixels=[]
        while q:
            yy,xx=q.popleft();pixels.append((yy,xx))
            for dy,dx in ((1,0),(-1,0),(0,1),(0,-1)):
                y2,x2=yy+dy,xx+dx
                if 0<=y2<h and 0<=x2<w and a[y2,x2]:
                    a[y2,x2]=False;q.append((y2,x2))
        found.append(pixels)
    return found


def foliage_objects():
    return [o for o in bpy.context.scene.objects if o.type=='MESH' and 'foliage' in o.name.lower()]


class AlphaTree:
    def __init__(self,objects):
        verts=[];tris=[];uvs=[]
        for obj in objects:
            mesh=obj.data;mesh.calc_loop_triangles();base=len(verts)
            verts.extend(obj.matrix_world@v.co for v in mesh.vertices)
            uv=mesh.uv_layers.active.data
            for t in mesh.loop_triangles:
                # Source has explicit coincident back faces; BVH is two-sided.
                poly=mesh.polygons[t.polygon_index]
                if poly.index%2==1 and len(mesh.polygons)%2==0:
                    previous=mesh.polygons[poly.index-1]
                    if (poly.center-previous.center).length<1e-6 and poly.normal.dot(previous.normal)<-.999:continue
                tris.append(tuple(base+i for i in t.vertices))
                uvs.append([tuple(uv[i].uv) for i in t.loops])
        self.bvh=BVHTree.FromPolygons(verts,tris,all_triangles=True)
        points=np.array([tuple(v) for v in verts]);self.bounds=np.array([points.min(0),points.max(0)])
        a=points[np.array(tris)];self.a=a[:,0];self.e1=a[:,1]-a[:,0];self.e2=a[:,2]-a[:,0]
        self.uv=np.array(uvs);self.d00=np.einsum('ij,ij->i',self.e1,self.e1)
        self.d01=np.einsum('ij,ij->i',self.e1,self.e2);self.d11=np.einsum('ij,ij->i',self.e2,self.e2)
        self.inv=1/(self.d00*self.d11-self.d01*self.d01)
        image=bpy.data.images.load(str(ROOT/'assets/vegetation/textures/leaf_clusters_witness_sparse_flat_v11.png'),check_existing=True)
        data=np.empty(len(image.pixels),dtype=np.float32);image.pixels.foreach_get(data)
        self.alpha=data.reshape(image.size[1],image.size[0],4)[:,:,3];self.height,self.width=self.alpha.shape
        self.capped=0

    def alpha_at(self,hit,index,normal,direction):
        d=np.array(hit)-self.a[index]
        d20=float(d@self.e1[index]);d21=float(d@self.e2[index])
        v=(self.d11[index]*d20-self.d01[index]*d21)*self.inv[index]
        w=(self.d00[index]*d21-self.d01[index]*d20)*self.inv[index]
        uv=self.uv[index,0]*(1-v-w)+self.uv[index,1]*v+self.uv[index,2]*w
        u=float(uv[0]%1);v=float(uv[1]%1);x=u*self.width-.5;y=v*self.height-.5
        ix=math.floor(x);iy=math.floor(y);fx=x-ix;fy=y-iy
        a=self.alpha[iy%self.height,ix%self.width]*(1-fx)*(1-fy)
        a+=self.alpha[iy%self.height,(ix+1)%self.width]*fx*(1-fy)
        a+=self.alpha[(iy+1)%self.height,ix%self.width]*(1-fx)*fy
        a+=self.alpha[(iy+1)%self.height,(ix+1)%self.width]*fx*fy
        uu=(u*2)%1;vv=(v*2)%1
        edge=smooth(0,.075,min(uu,1-uu,vv,1-vv))
        facing=abs(normal.dot(direction))
        return float(a)*edge*smooth(.02,.14,facing)

    def cast(self,origin,direction):
        current=origin.copy();first=None;travel=0.
        for _ in range(160):
            hit,normal,index,distance=self.bvh.ray_cast(current,direction,60.)
            if hit is None:return first,None
            travel+=distance
            if first is None:first=travel
            if self.alpha_at(hit,index,normal,direction)>=.5:return first,travel
            current=hit+direction*.0001;travel+=.0001
        self.capped+=1
        return first,None


def audit(tree,views,resolution=128,label='audit'):
    minimum,maximum=tree.bounds;center=(minimum+maximum)/2
    corners=np.array([(x,y,z) for x in (minimum[0],maximum[0]) for y in (minimum[1],maximum[1]) for z in (minimum[2],maximum[2])])-center
    results=[];candidates=[];masks=[]
    for j,(azimuth,elevation) in enumerate(views):
        phi=math.radians(azimuth);theta=math.radians(elevation)
        toward=np.array([math.cos(phi)*math.cos(theta),math.sin(phi)*math.cos(theta),math.sin(theta)])
        right=np.array([-math.sin(phi),math.cos(phi),0]);up=np.cross(toward,right)
        w=float(np.ptp(corners@right))*1.05;h=float(np.ptp(corners@up))*1.05
        x=(np.arange(resolution)+.5)/resolution*w-w/2;y=(np.arange(resolution)+.5)/resolution*h-h/2
        hit=np.full((resolution,resolution),np.nan);geom=hit.copy();direction=Vector(-toward)
        for iy,yy in enumerate(y):
            for ix,xx in enumerate(x):
                origin=Vector(center+toward*35+right*xx+up*yy)
                first,solid=tree.cast(origin,direction)
                if first is not None:geom[iy,ix]=first
                if solid is not None:hit[iy,ix]=solid
        mask=np.isfinite(hit)
        envelope=fill_holes(morph(morph(mask,2,True),2,False))
        interior=morph(envelope,3,False)
        # Five-ray-wide density rejects the atlas's intentional fine holes.
        through=interior&(box_mean(mask,2)<.50)
        front=local_max(local_min(np.where(mask,hit,60.),6),6)
        depth_difference=np.where(mask,hit-front,0.)
        # An opaque leaf several metres behind the rim still reads as a hole.
        # Detect spatially coherent depth pits, not merely total transparency.
        pits=interior&(depth_difference>1.5)&(box_mean(depth_difference>1.,1)>.50)
        macro=through|pits
        groups=[]
        for pixels in components(macro):
            area=len(pixels)*w*h/(resolution*resolution)
            if area<.075:continue
            ys,xs=np.array(pixels).T;px=float(x[xs].mean());py=float(y[ys].mean())
            ring=np.zeros_like(mask);ring[ys,xs]=True
            ring=morph(ring,4,True)&~ring&mask
            depths=hit[ring]
            if not depths.size:continue
            depth=float(np.median(front[ys,xs]))+.28
            point=center+toward*(35-depth)+right*px+up*py
            radius=min(.95,max(.30,math.sqrt(area/math.pi)*1.3))
            row={'area_m2':area,'point':point.tolist(),'radius_m':radius,'view':[azimuth,elevation],'pixels':len(pixels),
                 'through_pixels':int(through[ys,xs].sum()),'depth_pit_pixels':int(pits[ys,xs].sum())}
            groups.append(row);candidates.append(row)
        results.append({'view':[azimuth,elevation],'opaque_pixels':int(mask.sum()),'macro_holes':len(groups),'macro_hole_area_m2':sum(g['area_m2'] for g in groups)})
        masks.append((mask,macro))
        np.savez_compressed(OUT/(label+'_view_%02d.npz'%j),hit=hit,geometry=geom,macro=macro,
            center=center,toward=toward,right=right,up=up,width=w,height=h)
        print('CANOPY_VIEW',label,j+1,len(views),results[-1],flush=True)
    return {'views':results,'total_macro_hole_area_m2':sum(r['macro_hole_area_m2'] for r in results),
            'hole_observations':len(candidates),'capped_rays':tree.capped},candidates,masks


def oct_encode(n):
    n=n.normalized();x,y,z=n/(abs(n.x)+abs(n.y)+abs(n.z))
    if z<0:x,y=(1-abs(y))*(1 if x>=0 else -1),(1-abs(x))*(1 if y>=0 else -1)
    return (x*.5+.5,y*.5+.5)


def repair(objects,candidates,key,previous=(),limit=32):
    """Append a few crossed-card clusters into existing foliage meshes."""
    all_positions=np.array([tuple(o.matrix_world@v.co) for o in objects for v in o.data.vertices])
    minimum=all_positions.min(0);maximum=all_positions.max(0)
    canopy_center=(minimum+maximum)/2;canopy_radii=(maximum-minimum)/2
    selected=[]
    for candidate in sorted(candidates,key=lambda c:-c['area_m2']):
        p=Vector(candidate['point'])
        if any((p-Vector(row['point'])).length<.85 for row in [*previous,*selected]):continue
        if np.any(np.array(p)<minimum+.65) or np.any(np.array(p)>maximum-.65):continue
        selected.append(candidate)
        if len(selected)>=limit:break
    additions={}
    for number,row in enumerate(selected):
        point=Vector(row['point']);radius=min(.75,row['radius_m'])
        # Place within the nearest original crown group to retain its material,
        # one mesh per group, LOD clustering, and all existing geometry.
        obj=min(objects,key=lambda o:(o.matrix_world@sum((Vector(c) for c in o.bound_box),Vector())/8-point).length_squared)
        rng=random.Random((20261023 if key=='broad' else 20261024)+number*319+len(previous)*10007)
        inverse=obj.matrix_world.inverted();normal_inverse=obj.matrix_world.to_3x3().transposed()
        records=additions.setdefault(obj,[])
        for cell in range(8):
            normal=Vector((rng.uniform(-1,1),rng.uniform(-1,1),rng.uniform(-1,1))).normalized()
            axis=normal.cross(Vector((0,0,1)))
            if axis.length<.1:axis=normal.cross(Vector((0,1,0)))
            right=axis.normalized();up=normal.cross(right).normalized()
            offset=Vector((rng.uniform(-.32,.32),rng.uniform(-.32,.32),rng.uniform(-.32,.32)))*radius
            center=point+offset
            for pair in range(2):
                r=right if pair==0 else normal
                plane=r.cross(up).normalized()
                height=radius*rng.uniform(1.6,2.2);width=height*rng.uniform(.85,1.2)
                corners=[center-r*width/2-up*height/2,center+r*width/2-up*height/2,
                         center+r*width/2+up*height/2,center-r*width/2+up*height/2]
                if any(np.any(np.array(c)<minimum) or np.any(np.array(c)>maximum) for c in corners):continue
                local=[tuple(inverse@c) for c in corners]
                # Global volume normals keep these internal repairs from
                # introducing bright rectangular sheets or a dark inner shell.
                normals=[tuple((normal_inverse@Vector((np.array(c)-canopy_center)/(canopy_radii*canopy_radii))).normalized()) for c in corners]
                plane_local=(normal_inverse@plane).normalized();encoded=oct_encode(plane_local)
                region=(number+cell*2+pair)%4
                u0=.02+(.5 if region%2 else 0);v0=.02+(.5 if region<2 else 0)
                uv=[(u0,v0),(u0+.46,v0),(u0+.46,v0+.46),(u0,v0+.46)]
                records.append((local,normals,uv,(.75,*encoded,1.)))
    cards=0
    for obj,records in additions.items():
        old=obj.data;old.calc_loop_triangles()
        vertices=[tuple(v.co) for v in old.vertices];faces=[tuple(p.vertices) for p in old.polygons]
        uv_layer=old.uv_layers.active
        uvs=[tuple(uv_layer.data[i].uv) for i in range(len(old.loops))]
        normals=[(0,0,1)]*len(vertices)
        for loop,n in zip(old.loops,old.corner_normals):normals[loop.vertex_index]=tuple(n.vector)
        attr=old.color_attributes.active_color
        assert attr.domain=='POINT'
        colors=[tuple(c.color) for c in attr.data]
        for local,ns,uv,color in records:
            base=len(vertices);vertices.extend(local);vertices.extend(local)
            normals.extend(ns);normals.extend(ns);colors.extend([color]*8)
            faces.extend([(base,base+1,base+2,base+3),(base+7,base+6,base+5,base+4)])
            uvs.extend(uv);uvs.extend(reversed(uv));cards+=1
        mesh=bpy.data.meshes.new(old.name+'_GapRepair')
        mesh.from_pydata(vertices,[],faces);mesh.update()
        for mat in old.materials:mesh.materials.append(mat)
        for p in mesh.polygons:p.use_smooth=True
        mesh.normals_split_custom_set_from_vertices(normals)
        layer=mesh.uv_layers.new(name=uv_layer.name)
        assert len(layer.data)==len(uvs)
        for dst,uv in zip(layer.data,uvs):dst.uv=uv
        color_attr=mesh.color_attributes.new(name=attr.name,type=attr.data_type,domain='POINT')
        for dst,color in zip(color_attr.data,colors):dst.color=color
        mesh.color_attributes.active_color=color_attr
        obj.data=mesh;obj['canopy_gap_repair_cards']=len(records)
        obj['logical_card_count']=len(mesh.polygons)//2
    return selected,cards


def save_masks(masks,path):
    # Diagnostic pixels only, not authored plant textures.
    h,w=masks[0][0].shape;columns=4;rows=math.ceil(len(masks)/columns)
    image=np.zeros((rows*h,columns*w,4),dtype=np.float32);image[:,:,3]=1
    for i,(mask,macro) in enumerate(masks):
        tile=image[(i//columns)*h:(i//columns+1)*h,(i%columns)*w:(i%columns+1)*w]
        tile[mask,:3]=(.72,.8,.7);tile[macro,:3]=(1,.12,.08)
    im=bpy.data.images.new('CanopyGapDiagnostic',width=columns*w,height=rows*h,alpha=True)
    im.pixels.foreach_set(image.ravel());im.filepath_raw=str(path);im.file_format='PNG';im.save();bpy.data.images.remove(im)


def main():
    parser=argparse.ArgumentParser();parser.add_argument('--spec',choices=STEMS,action='append');parser.add_argument('--resolution',type=int,default=128)
    parser.add_argument('--apply',action='store_true')
    args=parser.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
    OUT.mkdir(parents=True,exist_ok=True)
    views=[(a,e) for e in (-12,18) for a in range(0,360,45)]
    for key in args.spec or STEMS:
        stem=STEMS[key];source=ROOT/'assets/vegetation/source'/(stem+'.blend')
        bpy.ops.wm.open_mainfile(filepath=str(source),load_ui=False)
        objects=foliage_objects();started=time.monotonic();tree=AlphaTree(objects)
        trunk=next(o for o in bpy.context.scene.objects if o.type=='MESH' and 'trunk' in o.name.lower())
        if args.apply and trunk.get('canopy_gap_repair_version'):
            raise RuntimeError('Already repaired; audit current file or restore the explicit checkpoint before rebuilding')
        print('CANOPY_SOURCE',key,len(objects),'bounds',tree.bounds.tolist(),flush=True)
        label=key+'_current' if trunk.get('canopy_gap_repair_version') else key
        report,candidates,masks=audit(tree,views,args.resolution,label)
        report.update({'spec':key,'source':str(source),'bounds':tree.bounds.tolist(),'seconds':time.monotonic()-started,'candidates':candidates})
        report_stem=label if label!=key else key+'_before'
        (OUT/(report_stem+'.json')).write_text(json.dumps(report,indent=2),encoding='utf-8')
        save_masks(masks,OUT/(report_stem+'_masks.png'))
        print('CANOPY_AUDIT_DONE',key,report['hole_observations'],report['total_macro_hole_area_m2'],flush=True)
        if not args.apply:continue
        base_signature=geometry_signature(objects)
        selected,cards=repair(objects,candidates,key,limit=32)
        repaired=AlphaTree(objects);after,remaining,after_masks=audit(repaired,views,args.resolution,key+'_after')
        after.update({'patches':len(selected),'added_logical_cards':cards,'patch_locations':selected,
            'before_macro_area_m2':report['total_macro_hole_area_m2']})
        (OUT/(key+'_after.json')).write_text(json.dumps(after,indent=2),encoding='utf-8')
        save_masks(after_masks,OUT/(key+'_after_masks.png'))
        assert after['total_macro_hole_area_m2']<report['total_macro_hole_area_m2'], 'No improvement; refusing to save source'
        assert repaired.capped==0 and cards<=512
        recipe=json.loads(RECIPE.read_text(encoding='utf-8')) if RECIPE.exists() else {}
        recipe[key]={'base_geometry_sha256':base_signature,'added_logical_cards':cards,'patch_locations':selected}
        RECIPE.write_text(json.dumps(recipe,indent=2)+'\n',encoding='utf-8')
        backup=OUT/'before';backup.mkdir(exist_ok=True)
        model=ROOT/'assets/vegetation/models'/(stem+'.glb')
        for path in (source,model):
            checkpoint=backup/path.name
            if not checkpoint.exists():shutil.copy2(path,checkpoint)
        trunk['canopy_gap_repair_version']='20261023_alpha_depth_v1'
        trunk['canopy_gap_repair_cards']=cards
        trunk['logical_card_count']=sum(len(o.data.polygons)//2 for o in objects)
        bpy.context.preferences.filepaths.save_version=0
        bpy.ops.wm.save_as_mainfile(filepath=str(source),compress=True)
        bpy.ops.object.select_all(action='DESELECT')
        for obj in [trunk,*objects]:obj.select_set(True)
        bpy.context.view_layer.objects.active=trunk
        bpy.ops.export_scene.gltf(filepath=str(model),export_format='GLB',use_selection=True,
            export_apply=True,export_yup=True,export_vertex_color='ACTIVE',export_materials='EXPORT')
        after['source_sha256']=hashlib.sha256(source.read_bytes()).hexdigest()
        after['glb_sha256']=hashlib.sha256(model.read_bytes()).hexdigest()
        (OUT/(key+'_after.json')).write_text(json.dumps(after,indent=2),encoding='utf-8')
        print('CANOPY_REPAIRED',key,cards,report['total_macro_hole_area_m2'],after['total_macro_hole_area_m2'],flush=True)


if __name__=='__main__':main()
