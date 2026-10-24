"""Refine only the existing supplemental patch against dense real edges.

The three original banks and planned bridge openings are unchanged. Candidate
controls are separate from the published controls until Rhino QA accepts them.
"""
from pathlib import Path
import json
import numpy as np
from repair_terrain_seams_1016 import Surface

OUT=Path(__file__).resolve().parents[1]/'docs/concepts/terrain_seams_1016_v01'

def main():
    g=json.loads((OUT/'missing_corner_grid.json').read_text())
    b=json.loads((OUT/'missing_corner_dense_boundary.json').read_text())
    old=json.loads((OUT/'missing_corner_controls.json').read_text())
    nu,nv=g['nu'],g['nv'];n=nu*nv
    xx,yy=np.meshgrid(g['xs'],g['ys'],indexing='ij')
    cp=np.c_[xx.ravel(),yy.ravel(),old['z'],np.ones(n)]
    s=Surface(dict(g,cp=cp.tolist(),degree_u=3,degree_v=3))
    xy=np.array([r['xy']for r in b]);height=np.array([r['height']for r in b])
    grad=np.array([r['gradient']for r in b]);ids=[r['source']for r in b]
    corners=np.array([xy[i]for i in range(len(xy))if ids[i]!=ids[i-1]])
    dc=np.linalg.norm(xy[:,None]-corners[None],axis=2).min(axis=1)
    ix,c=s.world_weights(xy)
    matrices=[];targets=[]
    for k in range(3):
        block=np.zeros((len(xy),n))
        for i in range(len(xy)):np.add.at(block[i],ix[i],c[i,k])
        matrices.append(block);targets.append(height if k==0 else grad[:,k-1])
    smooth=[]
    for axis in (0,1):
        coords=g['xs']if axis==0 else g['ys']
        for i in range(nu):
            for j in range(nv):
                k=i if axis==0 else j
                if k==0 or k==len(coords)-1:continue
                d0=coords[k]-coords[k-1];d1=coords[k+1]-coords[k]
                before=(i-1)*nv+j if axis==0 else i*nv+j-1
                after=(i+1)*nv+j if axis==0 else i*nv+j+1
                row=np.zeros(n);row[[before,i*nv+j,after]]=[1/d0,-1/d0-1/d1,1/d1]
                smooth.append(row*35)
    for i in range(nu-1):
        for j in range(nv-1):
            dx=g['xs'][i+1]-g['xs'][i];dy=g['ys'][j+1]-g['ys'][j]
            row=np.zeros(n);row[[i*nv+j,(i+1)*nv+j,i*nv+j+1,(i+1)*nv+j+1]]=[1,-1,-1,1]
            smooth.append(row*50/np.sqrt(dx*dy))
    oldz=np.array(old['z']);rows=np.array(smooth)
    weights=[np.full(len(xy),3000.),np.clip(dc/5,0,1)*400,np.clip(dc/5,0,1)*400]
    a=np.vstack([m*w[:,None]for m,w in zip(matrices,weights)]+[rows,np.eye(n)*5])
    rhs=np.concatenate([t*w for t,w in zip(targets,weights)]+[np.zeros(len(rows)),oldz*5])
    z=np.linalg.lstsq(a,rhs,rcond=1e-10)[0]
    def metrics(values):
        h=matrices[0]@values;gradient=np.c_[matrices[1]@values,matrices[2]@values]
        delta=h-height
        na=np.c_[-gradient,np.ones(len(xy))];nb=np.c_[-grad,np.ones(len(xy))]
        angle=np.degrees(np.arccos(np.clip((na*nb).sum(1)/np.linalg.norm(na,axis=1)/np.linalg.norm(nb,axis=1),-1,1)))
        return dict(max_height_error_m=float(abs(delta).max()),rms_height_error_m=float(np.sqrt((delta*delta).mean())),
                    max_height_error_away_from_corners_m=float(abs(delta[dc>3]).max()),
                    max_normal_angle_away_from_corners_deg=float(angle[dc>5].max()),
                    rms_normal_angle_away_from_corners_deg=float(np.sqrt((angle[dc>5]**2).mean())))
    report={'boundary_samples':len(xy),'before':metrics(oldz),'after':metrics(z),
            'controls_delta_max_m':float(abs(z-oldz).max()),'parents_unchanged':True,
            'known_limitation':'Original banks have incompatible heights at one triple corner; not an exact G1 join.'}
    (OUT/'missing_corner_refined_controls.json').write_text(json.dumps({'nu':nu,'nv':nv,'z':z.tolist()}))
    (OUT/'missing_corner_refinement_report.json').write_text(json.dumps(report,indent=2))
    print(json.dumps(report,indent=2))

if __name__=='__main__':main()
