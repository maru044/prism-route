"""Build a solid quintic cross-gap ramp between two actual terrain banks.

This spans the missing tens-of-metres-wide region, rather than welding edges.
Rails overlap each bank and match sampled endpoint height gradients.
"""
from pathlib import Path
import json
import numpy as np
from repair_terrain_seams_1016 import basis

OUT=Path(__file__).resolve().parents[1]/'docs/concepts/terrain_seams_1016_v01'

def build(name):
    d=json.loads((OUT/(name+'_wide_gap_rails.json')).read_text())
    rows=d['samples'];degree=d['degree'];n=len(rows)
    knots=np.r_[d['knots'][0],d['knots'],d['knots'][-1]]
    span,w=basis(np.array([r['t']for r in rows]),knots,degree,n)
    matrix=np.zeros((n,n))
    for i in range(n):matrix[i,span[i]-degree:span[i]+1]=w[i]
    lo=np.array([r['low']for r in rows]);hi=np.array([r['high']for r in rows])
    xy=hi[:,:2]-lo[:,:2]
    d0=np.c_[xy,(xy*np.array([r['low_gradient']for r in rows])).sum(axis=1)]
    d1=np.c_[xy,(xy*np.array([r['high_gradient']for r in rows])).sum(axis=1)]
    sample=np.stack([lo,lo+d0/5,lo+2*d0/5,hi-2*d1/5,hi-d1/5,hi],axis=1)
    controls=np.linalg.solve(matrix,sample.reshape(n,-1)).reshape(n,6,3)
    result={'degree_u':degree,'knots_u':d['knots'],'nu':n,'nv':6,'cp':controls.tolist()}
    (OUT/(name+'_wide_gap_controls.json')).write_text(json.dumps(result))
    report={'rail_samples':n,'plan_width_min_m':float(np.linalg.norm(xy,axis=1).min()),
            'plan_width_max_m':float(np.linalg.norm(xy,axis=1).max()),
            'height_change_min_m':float((hi[:,2]-lo[:,2]).min()),
            'height_change_max_m':float((hi[:,2]-lo[:,2]).max()),
            'method':'quintic cross-section with matched endpoint first derivatives; solid base at -7m',
            'rail_interpolation_error_m':float(abs(matrix@controls.reshape(n,-1)-sample.reshape(n,-1)).max())}
    (OUT/(name+'_wide_gap_fit_report.json')).write_text(json.dumps(report,indent=2))
    print(json.dumps(report,indent=2))

if __name__=='__main__':
    import sys
    build(sys.argv[1] if len(sys.argv)>1 else 'east')
