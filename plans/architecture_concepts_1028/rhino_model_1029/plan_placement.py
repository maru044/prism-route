import json, heapq
from pathlib import Path
import numpy as np
from scipy import ndimage

HERE=Path(__file__).resolve().parent
r=json.loads((HERE.parent/'site_measurements/terrace_geometry_raw.json').read_text())
a=np.array([x[:3] for x in r['samples']]);step=3.
origin=a[:,:2].min(0);ij=np.rint((a[:,:2]-origin)/step).astype(int)
shape=ij.max(0)+1;z=np.full(shape,np.nan);z[ij[:,0],ij[:,1]]=a[:,2]
safe=ndimage.distance_transform_edt(np.isfinite(z))*step
F=np.array([444.,-129.]);L=np.array([-.4,1.]);L/=np.linalg.norm(L);R=np.array([L[1],-L[0]])
goalxy=F-30*L
startxy=np.array([568.,-268.])
start=tuple(ij[np.linalg.norm(a[:,:2]-startxy,axis=1).argmin()])
goal=tuple(ij[np.linalg.norm(a[:,:2]-goalxy,axis=1).argmin()])
queue=[(0.,start)];cost={start:0.};prev={}
neighbors=[(i,j) for i in [-1,0,1] for j in [-1,0,1] if i or j]
while queue:
    _,q=heapq.heappop(queue)
    if q==goal:break
    for dx,dy in neighbors:
        n=(q[0]+dx,q[1]+dy)
        if min(n)<0 or n[0]>=shape[0] or n[1]>=shape[1] or not np.isfinite(z[n]):continue
        if safe[n]<6 and np.linalg.norm((np.array(n)-start)*step)>15:continue
        d=step*np.hypot(dx,dy);grade=abs(z[n]-z[q])/d
        if grade>.40:continue
        c=cost[q]+d*(1+2.5*grade**2)
        if c<cost.get(n,1e20):
            cost[n]=c;prev[n]=q
            heur=step*np.hypot(n[0]-goal[0],n[1]-goal[1]);heapq.heappush(queue,(c+heur,n))
if goal not in cost:raise RuntimeError('No walkable approach')
q=goal;route=[q]
while q!=start:q=prev[q];route.append(q)
route=route[::-1];xy=origin+np.array(route)*step
def rdp(x,eps=2.5):
    if len(x)<3:return x
    v=x[-1]-x[0];s=np.clip(((x-x[0])@v)/(v@v),0,1)
    dist=np.linalg.norm(x-(x[0]+s[:,None]*v),axis=1);k=dist.argmax()
    if dist[k]>eps:return np.vstack([rdp(x[:k+1],eps)[:-1],rdp(x[k:],eps)])
    return x[[0,-1]]
nodes=rdp(xy);nodes[0]=startxy;nodes[-1]=goalxy
out={'front_center':F.tolist(),'long_axis':L.tolist(),'right_axis':R.tolist(),
     'width':30,'length':60,'entry_floor':60.45,'main_floor':61.05,'rear_floor':61.65,
     'lower_landing':55.05,'approach_nodes':nodes.tolist(),'astar_nodes':xy.tolist(),
     'astar_length':float(np.linalg.norm(np.diff(xy,axis=0),axis=1).sum()),
     'astar_max_grade':float(max(abs(z[tuple(b)]-z[tuple(c)])/np.linalg.norm((b-c)*step) for b,c in zip(np.array(route)[1:],np.array(route)[:-1])))}
(HERE/'placement_plan.json').write_text(json.dumps(out,indent=2))
print(json.dumps(out))
