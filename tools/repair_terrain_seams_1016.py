"""Fit local C1 height continuity between the four existing terrain parcels.

Offline NumPy only; retain XY, NURBS knots, trimming, and hidden originals.
The saved controls are applied in Rhino one solid at a time.
"""
from pathlib import Path
import json
import numpy as np

OUT = Path(__file__).resolve().parents[1] / 'docs/concepts/terrain_seams_1016_v01'

def basis(t, knots, degree, count):
    t = np.asarray(t)
    span = np.clip(np.searchsorted(knots, t, side='right') - 1, degree, count - 1)
    n = np.zeros((len(t), degree + 1)); n[:, 0] = 1
    left, right = np.zeros_like(n), np.zeros_like(n)
    for j in range(1, degree + 1):
        left[:, j] = t - knots[span + 1 - j]
        right[:, j] = knots[span + j] - t
        saved = np.zeros(len(t))
        for r in range(j):
            temp = np.divide(n[:, r], right[:, r + 1] + left[:, j - r],
                             out=np.zeros(len(t)), where=np.abs(right[:, r + 1] + left[:, j - r]) > 1e-20)
            n[:, r] = saved + right[:, r + 1] * temp
            saved = left[:, j - r] * temp
        n[:, j] = saved
    return span, n

class Surface:
    def __init__(self, row):
        self.row = row
        self.nu, self.nv = row['nu'], row['nv']
        self.cp = np.asarray(row['cp'], float)
        self.ku = np.r_[row['knots_u'][0], row['knots_u'], row['knots_u'][-1]]
        self.kv = np.r_[row['knots_v'][0], row['knots_v'], row['knots_v'][-1]]
        self.pu, self.pv = row['degree_u'], row['degree_v']
        self.dom = np.array([[self.ku[self.pu], self.ku[self.nu]],
                             [self.kv[self.pv], self.kv[self.nv]]])
    def weights(self, uv):
        iu, bu = basis(uv[:, 0], self.ku, self.pu, self.nu)
        iv, bv = basis(uv[:, 1], self.kv, self.pv, self.nv)
        indices = ((iu[:, None, None] - self.pu + np.arange(self.pu+1)[None, :, None]) * self.nv
                   + iv[:, None, None] - self.pv + np.arange(self.pv+1)[None, None, :]).reshape(len(uv), -1)
        w = (bu[:, :, None]*bv[:, None, :]).reshape(len(uv), -1) * self.cp[indices, 3]
        w /= w.sum(axis=1)[:, None]
        return indices, w
    def evaluate(self, uv):
        ix, w = self.weights(uv)
        return (self.cp[ix, :3] * w[:, :, None]).sum(axis=1)
    def inverse(self, xy):
        uu, vv = np.meshgrid(np.linspace(*self.dom[0], 28), np.linspace(*self.dom[1], 28))
        seeds = np.c_[uu.ravel(), vv.ravel()]; points = self.evaluate(seeds)[:, :2]
        uv = np.concatenate([seeds[((x[:, None]-points[None])**2).sum(axis=2).argmin(axis=1)]
                             for x in np.array_split(xy, max(1, len(xy)//250))])
        for _ in range(18):
            p = self.evaluate(uv)[:, :2]
            du, dv = [], []
            for axis in range(2):
                eps = (self.dom[axis, 1]-self.dom[axis, 0])*1e-5
                up, dn = uv.copy(), uv.copy()
                up[:, axis] = np.minimum(up[:, axis]+eps, self.dom[axis, 1])
                dn[:, axis] = np.maximum(dn[:, axis]-eps, self.dom[axis, 0])
                derivative = (self.evaluate(up)[:, :2]-self.evaluate(dn)[:, :2]) / (up[:, axis]-dn[:, axis])[:, None]
                (du if axis == 0 else dv).extend(derivative)
            du, dv = np.asarray(du), np.asarray(dv)
            det = du[:, 0]*dv[:, 1]-du[:, 1]*dv[:, 0]
            det = np.where(np.abs(det)<1e-12, 1e-12, det)
            delta = p-xy
            step = np.c_[(delta[:, 0]*dv[:, 1]-delta[:, 1]*dv[:, 0])/det,
                         (du[:, 0]*delta[:, 1]-du[:, 1]*delta[:, 0])/det]
            step = np.clip(step, -(self.dom[:, 1]-self.dom[:, 0])*.15, (self.dom[:, 1]-self.dom[:, 0])*.15)
            uv = np.clip(uv-step, self.dom[:, 0], self.dom[:, 1])
        err = np.linalg.norm(self.evaluate(uv)[:, :2]-xy, axis=1)
        return uv, err
    def world_weights(self, uv):
        ix, w = self.weights(uv)
        # Different support sets at knot boundaries are combined in a fixed
        # 3x support so finite differences remain exact linear CP weights.
        sets = [(ix, w)]
        epsilons = []
        for axis in range(2):
            eps = (self.dom[axis, 1]-self.dom[axis, 0])*1e-6
            up, dn = uv.copy(), uv.copy()
            up[:, axis] = np.minimum(up[:, axis]+eps, self.dom[axis, 1])
            dn[:, axis] = np.maximum(dn[:, axis]-eps, self.dom[axis, 0])
            epsilons.append(up[:, axis]-dn[:, axis])
            sets.extend([self.weights(up), self.weights(dn)])
        indices = np.concatenate([s[0] for s in sets], axis=1)
        size = w.shape[1]; coeff = np.zeros((len(uv), 3, 5*size))
        coeff[:, 0, :size] = w
        for axis in range(2):
            coeff[:, axis+1, (1+axis*2)*size:(2+axis*2)*size] = sets[1+axis*2][1]/epsilons[axis][:, None]
            coeff[:, axis+1, (2+axis*2)*size:(3+axis*2)*size] = -sets[2+axis*2][1]/epsilons[axis][:, None]
        # Combine duplicate CP indices BEFORE derivative norms and the solve.
        # Opposite finite-difference weights otherwise cancel only in matvec,
        # falsely scaling gradient constraints down by six orders of magnitude.
        merged_indices=np.zeros_like(indices); merged_coeff=np.zeros_like(coeff)
        for row in range(len(uv)):
            unique,inv=np.unique(indices[row],return_inverse=True)
            merged_indices[row,:len(unique)]=unique
            for axis in range(3):
                np.add.at(merged_coeff[row,axis],inv,coeff[row,axis])
        indices,coeff=merged_indices,merged_coeff
        tangents = np.einsum('nki,nij->nkj', coeff[:, 1:], self.cp[indices, :2])
        a, b = tangents[:, 0, 0], tangents[:, 0, 1]
        c, d = tangents[:, 1, 0], tangents[:, 1, 1]
        det = a*d-b*c
        du, dv = coeff[:, 1].copy(), coeff[:, 2].copy()
        coeff[:, 1] = (d[:, None]*du-b[:, None]*dv)/det[:, None]
        coeff[:, 2] = (-c[:, None]*du+a[:, None]*dv)/det[:, None]
        return indices, coeff

def nearest_segments(xy, points):
    a, d = points[:-1, :2], np.diff(points[:, :2], axis=0)
    best = []
    for x in np.array_split(xy, max(1, len(xy)//300)):
        t = np.clip(((x[:, None]-a[None])*d[None]).sum(axis=2) / np.maximum((d*d).sum(axis=1), 1e-20)[None], 0, 1)
        delta = x[:, None]-a[None]-t[:, :, None]*d[None]
        dd = (delta*delta).sum(axis=2); j = dd.argmin(axis=1); ii = np.arange(len(x))
        best.append((np.sqrt(dd[ii, j]), j, t[ii, j]))
    return tuple(np.concatenate([v[k] for v in best]) for k in range(3))

def main():
    surfaces = [Surface(r) for r in json.loads((OUT/'live_surfaces.json').read_text())]
    edges = json.loads((OUT/'edges.json').read_text())
    seams = []
    # Exact known shared top boundaries, with only the overlapping central
    # trim segment retained on the first pair.
    for a, b, edge in [(0,1,2),(1,2,2),(2,3,1)]:
        points = np.asarray(edges[b]['edges'][edge], float)
        uva, erra = surfaces[a].inverse(points[:, :2]); uvb, errb = surfaces[b].inverse(points[:, :2])
        if a == 0:
            mask = points[:, 0] >= 760.01
            points, uva, uvb, erra, errb = points[mask], uva[mask], uvb[mask], erra[mask], errb[mask]
        if max(erra.max(),errb.max()) > .01:raise RuntimeError(('inverse error',a,b,erra.max(),errb.max()))
        ia, ca = surfaces[a].world_weights(uva); ib, cb = surfaces[b].world_weights(uvb)
        va = np.einsum('nki,ni->nk', ca, surfaces[a].cp[ia, 2])
        vb = np.einsum('nki,ni->nk', cb, surfaces[b].cp[ib, 2])
        seams.append(dict(a=a,b=b,points=points,uva=uva,uvb=uvb,ia=ia,ib=ib,ca=ca,cb=cb,values=(va+vb)*.5))
        print('BEFORE',a,b,'samples',len(points),'gap',abs(va[:,0]-vb[:,0]).max(),'gradient_delta',np.linalg.norm(va[:,1:]-vb[:,1:],axis=1).max(),flush=True)
    # Construct a common first-order height field in a 10 m core and blend
    # it into the unchanged shape over 75 m. This provides broad fairing;
    # the following constrained solve only closes its residual mismatch.
    offsets = np.cumsum([0]+[len(s.cp) for s in surfaces])
    original = np.concatenate([s.cp[:,2] for s in surfaces]); initial = original.copy()
    active_distance = np.full(len(initial),1e10)
    for i,s in enumerate(surfaces):
        targets, weights = [], []
        for seam in seams:
            if i not in (seam['a'],seam['b']):continue
            pts, values = seam['points'], seam['values']
            distance,j,t = nearest_segments(s.cp[:,:2],pts)
            foot = pts[j,:2]*(1-t[:,None])+pts[j+1,:2]*t[:,None]
            v = values[j]*(1-t[:,None])+values[j+1]*t[:,None]
            h = v[:,0]+((s.cp[:,:2]-foot)*v[:,1:]).sum(axis=1)
            x = np.clip((75-distance)/65,0,1); w = x*x*x*(10+x*(-15+6*x))
            # Fade at endpoints that do not meet another seam.
            targets.append(h); weights.append(w)
            active_distance[offsets[i]:offsets[i+1]] = np.minimum(active_distance[offsets[i]:offsets[i+1]],distance)
        if weights:
            weights=np.asarray(weights); total=weights.sum(axis=0); strength=weights.max(axis=0)
            h=(weights*np.asarray(targets)).sum(axis=0)/np.maximum(total,1e-20)
            initial[offsets[i]:offsets[i+1]]=s.cp[:,2]*(1-strength)+h*strength
    indices,coeffs=[] ,[]
    for seam in seams:
        n=len(seam['points'])
        ia=seam['ia']+offsets[seam['a']];ib=seam['ib']+offsets[seam['b']]
        ci=np.concatenate([ia,ib],axis=1)
        co=np.concatenate([seam['ca'],-seam['cb']],axis=2)
        co[:,1:]*=8
        indices.append(np.repeat(ci,3,axis=0));coeffs.append(co.reshape(n*3,-1))
    ix=np.concatenate(indices);co=np.concatenate(coeffs)
    # Weighted minimum-change correction; matrix-free normal equations.
    capacity=np.clip((65-active_distance)/55,0,1)**2
    capacity=np.maximum(capacity,1e-12)
    norm=np.sqrt((co*co*capacity[ix]).sum(axis=1));co/=np.maximum(norm,1e-12)[:,None]
    def A(x):return (co*x[ix]).sum(axis=1)
    def AT(y):return np.bincount(ix.ravel(),weights=(co*y[:,None]).ravel(),minlength=len(initial))*capacity
    rhs=-A(initial)
    lam=np.zeros(len(rhs));r=rhs.copy();d=r.copy();rr=r@r
    print('ROW_NORMS',float(norm.min()),float(norm.max()),flush=True)
    for k in range(4000):
        ad=A(AT(d))+1e-10*d
        alpha=rr/max(d@ad,1e-30);lam+=alpha*d;r-=alpha*ad
        rrnew=r@r
        if k%1000==0:print('SOLVE',k,float(np.sqrt(rrnew/len(r))),flush=True)
        if rrnew<1e-12:break
        d=r+(rrnew/rr)*d;rr=rrnew
    final=initial+AT(lam)
    controls=[];report=[]
    for i,s in enumerate(surfaces):
        s.cp[:,2]=final[offsets[i]:offsets[i+1]]
        controls.append({'id':s.row['id'],'nu':s.nu,'nv':s.nv,'z':s.cp[:,2].tolist()})
    for seam in seams:
        sa,sb=surfaces[seam['a']],surfaces[seam['b']]
        va=np.einsum('nki,ni->nk',seam['ca'],sa.cp[seam['ia'],2])
        vb=np.einsum('nki,ni->nk',seam['cb'],sb.cp[seam['ib'],2])
        gap=float(abs(va[:,0]-vb[:,0]).max());grad=float(np.linalg.norm(va[:,1:]-vb[:,1:],axis=1).max())
        report.append({'pair':[seam['a'],seam['b']],'samples':len(va),'max_vertical_gap_m':gap,'max_gradient_difference':grad})
        print('AFTER',report[-1],flush=True)
        delta=np.linalg.norm(va[:,1:]-vb[:,1:],axis=1); bad=delta.argsort()[-3:]
        print('WORST',[(seam['points'][j].tolist(),float(delta[j]))for j in bad],flush=True)
    (OUT/'repaired_controls.json').write_text(json.dumps(controls))
    (OUT/'fit_report.json').write_text(json.dumps({'seams':report,'max_cp_delta_m':float(abs(final-original).max()),'method':'common height and XY gradients, local 75m fairing, matrix-free CP fit'},indent=2))

if __name__=='__main__':main()
