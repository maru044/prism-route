"""Fair a height surface over the actual 864m2 three-sided footprint void.

The adjacent terrain and existing corner piece remain unchanged. Height and
gradient constraints come from their real boundary edges, not guessed offsets.
"""
from pathlib import Path
import json
import numpy as np
from repair_terrain_seams_1016 import Surface

OUT=Path(__file__).resolve().parents[1]/'docs/concepts/terrain_seams_1016_v01'

def main():
    grid=json.loads((OUT/'missing_corner_grid.json').read_text())
    boundary=json.loads((OUT/'missing_corner_boundary.json').read_text())
    nu,nv=grid['nu'],grid['nv'];xx,yy=np.meshgrid(grid['xs'],grid['ys'],indexing='ij')
    cp=np.c_[xx.ravel(),yy.ravel(),np.zeros(nu*nv),np.ones(nu*nv)]
    surface=Surface(dict(grid,cp=cp.tolist(),degree_u=3,degree_v=3))
    xy=np.array([r['xy']for r in boundary]);height=np.array([r['height']for r in boundary])
    gradients=np.array([r['gradient']for r in boundary])
    ix,c=surface.world_weights(xy)
    ids=[r['source']for r in boundary]
    corners=np.array([xy[i]for i in range(len(xy))if ids[i]!=ids[i-1]])
    corner_distance=np.linalg.norm(xy[:,None]-corners[None],axis=2).min(axis=1)
    gradient_weight=np.clip(corner_distance/5,0,1)*100
    matrix=[];rhs=[]
    for i in range(len(xy)):
        for axis in range(3):
            row=np.zeros(nu*nv);np.add.at(row,ix[i],c[i,axis])
            weight=1000 if axis==0 else gradient_weight[i]
            matrix.append(row*weight)
            rhs.append((height[i] if axis==0 else gradients[i,axis-1])*weight)
    # Penalize changes in slope in world units, allowing a broad connecting
    # landform rather than a saddle assembled from unrelated small panels.
    for axis in (0,1):
        coords=grid['xs'] if axis==0 else grid['ys']
        for i in range(nu):
            for j in range(nv):
                k=i if axis==0 else j
                if k==0 or k==len(coords)-1:continue
                d0=coords[k]-coords[k-1];d1=coords[k+1]-coords[k]
                before=(i-1)*nv+j if axis==0 else i*nv+j-1
                center=i*nv+j;after=(i+1)*nv+j if axis==0 else i*nv+j+1
                row=np.zeros(nu*nv)
                row[[before,center,after]]=[1/d0,-1/d0-1/d1,1/d1]
                matrix.append(row*25);rhs.append(0)
    # Include mixed curvature as well; omitting it permits diagonal saddles
    # with visible local ridges even when the two axial penalties are small.
    for i in range(nu-1):
        for j in range(nv-1):
            dx=grid['xs'][i+1]-grid['xs'][i];dy=grid['ys'][j+1]-grid['ys'][j]
            row=np.zeros(nu*nv)
            row[[i*nv+j,(i+1)*nv+j,i*nv+j+1,(i+1)*nv+j+1]]=[1,-1,-1,1]
            matrix.append(row*35/np.sqrt(dx*dy));rhs.append(0)
    # Weak bounded prior stabilizes extrapolation outside the trimmed void.
    origin=xy.mean(axis=0)
    plane=np.linalg.lstsq(np.c_[xy-origin,np.ones(len(xy))],height,rcond=None)[0]
    prior=np.clip(np.c_[cp[:,:2]-origin,np.ones(len(cp))]@plane,height.min()-1,height.max()+1)
    for i in range(nu*nv):
        row=np.zeros(nu*nv);row[i]=10;matrix.append(row);rhs.append(prior[i]*10)
    z=np.linalg.lstsq(np.array(matrix),np.array(rhs),rcond=1e-10)[0]
    surface.cp[:,2]=z
    actual=np.einsum('nki,ni->nk',c,z[ix])
    delta=actual[:,0]-height
    angles=[]
    for a,b,w in zip(actual[:,1:],gradients,gradient_weight):
        if w<95:continue
        na=np.r_[-a,1];nb=np.r_[-b,1]
        angles.append(float(np.degrees(np.arccos(np.clip((na@nb)/np.linalg.norm(na)/np.linalg.norm(nb),-1,1)))))
    report={'footprint_area_m2':864.3538471142542,'controls':[nu,nv],
            'boundary_samples':len(boundary),'max_boundary_height_error_m':float(abs(delta).max()),
            'rms_boundary_height_error_m':float(np.sqrt((delta*delta).mean())),
            'max_boundary_normal_angle_away_from_corners_deg':max(angles),
            'control_height_range_m':[float(z.min()),float(z.max())]}
    (OUT/'missing_corner_controls.json').write_text(json.dumps({'nu':nu,'nv':nv,'z':z.tolist()}))
    (OUT/'missing_corner_fit_report.json').write_text(json.dumps(report,indent=2))
    print(json.dumps(report,indent=2))

if __name__=='__main__':main()
