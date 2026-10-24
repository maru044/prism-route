"""Locally fair the envelope of overlapping solid-only shoreline parcels.

No tunnel/support geometry is sampled or replaced. Three preserved solids
become one trimmed, closed NURBS ground body; originals remain hidden.
"""
from pathlib import Path
import json
import numpy as np
from repair_terrain_seams_1016 import basis

OUT=Path(__file__).resolve().parents[1]/'docs/concepts/terrain_seams_1016_v01'

def blur(a,sigma):
    radius=int(np.ceil(sigma*3));x=np.arange(-radius,radius+1)
    kernel=np.exp(-.5*(x/sigma)**2);kernel/=kernel.sum()
    for axis in (0,1):
        pads=[(0,0),(0,0)];pads[axis]=(radius,radius)
        p=np.pad(a,pads,mode='edge');out=np.zeros_like(a)
        for k,w in enumerate(kernel):
            slices=[slice(None),slice(None)];slices[axis]=slice(k,k+a.shape[axis])
            out+=w*p[tuple(slices)]
        a=out
    return a

def main():
    d=json.loads((OUT/'overlap_height_samples.json').read_text())
    values=np.asarray([[np.nan if h is None else h for h in row]for row in d['heights']])
    inside=np.isfinite(values[:,:3]).any(axis=1)
    safe=np.where(np.isfinite(values[:,:3]),values[:,:3],-1e6)
    winner=safe.argmax(axis=1);winner[~inside]=3
    raw=np.maximum(safe.max(axis=1),0)
    raw=raw.reshape(d['nu'],d['nv']);winner=winner.reshape(raw.shape)
    # Extend the authored height field beyond its trim instead of sampling
    # unrelated background terrain. Otherwise a 60m/0m background boundary
    # creates oscillation inside the interpolating surface near the trim.
    known=inside.reshape(raw.shape).copy();raw[~known]=0
    for _ in range(max(raw.shape)):
        total=np.zeros_like(raw);count=np.zeros_like(raw)
        for axis in (0,1):
            for direction in (-1,1):
                shifted=np.roll(raw,direction,axis);valid=np.roll(known,direction,axis)
                sl=[slice(None),slice(None)];sl[axis]=0 if direction==1 else -1
                valid[tuple(sl)]=False
                total+=shifted*valid;count+=valid
        fill=(~known)&(count>0)
        if not fill.any():break
        raw[fill]=total[fill]/count[fill];known[fill]=True
    raw=blur(raw,.8)
    seed=np.zeros_like(raw)
    for axis in (0,1):
        a=[slice(None),slice(None)];b=list(a);a[axis]=slice(None,-1);b[axis]=slice(1,None)
        wa,wb=winner[tuple(a)],winner[tuple(b)]
        change=(wa!=wb)&(wa<3)&(wb<3)
        seed[tuple(a)]=np.maximum(seed[tuple(a)],change)
        seed[tuple(b)]=np.maximum(seed[tuple(b)],change)
    weight=blur(seed,7)
    weight=np.clip(weight/.055,0,1)
    # Preserve the northern abutment to the preexisting tunnel area.
    y=np.asarray(d['ys'])[None,:]
    t=np.clip((y-965)/45,0,1);weight*=t*t*(3-2*t)
    target=raw+weight*(blur(raw,5)-raw)
    matrices=[]
    for axis,n in [('u',d['nu']),('v',d['nv'])]:
        native=d['knots_'+axis];knots=np.r_[native[0],native,native[-1]]
        nodes=d['xs'] if axis=='u' else d['ys']
        span,w=basis(np.asarray(nodes),knots,3,n)
        matrix=np.zeros((n,n))
        for i in range(n):matrix[i,span[i]-3:span[i]+1]=w[i]
        matrices.append(matrix)
    cp=np.linalg.solve(matrices[0],target)
    cp=np.linalg.solve(matrices[1],cp.T).T
    residual=float(abs(matrices[0]@cp@matrices[1].T-target).max())
    (OUT/'overlap_repaired_controls.json').write_text(json.dumps({'nu':d['nu'],'nv':d['nv'],'z':cp.ravel().tolist()}))
    report={'grid':[d['nu'],d['nv']],'grid_spacing_m':3,'fairing_sigma_m':15,
            'max_sample_height_change_m':float(abs(target-raw)[inside.reshape(raw.shape)].max()),
            'interpolation_residual_m':residual,'preserved_abutment_y_max':965,
            'method':'single trimmed NURBS envelope, local smoothing around internal parcel overlaps'}
    (OUT/'overlap_fit_report.json').write_text(json.dumps(report,indent=2));print(json.dumps(report,indent=2))

if __name__=='__main__':main()
