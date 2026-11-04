"""Prepare two local SubD control nets from the measured native terrain."""
import json
from pathlib import Path
import numpy as np

OUT=Path(__file__).resolve().parents[1]/'docs/terrain_seams_1102'

def smooth(a):
    a=np.clip(a,0,1)
    return a*a*(3-2*a)

def request():
    edges=json.loads((OUT/'edge_constraints.json').read_text())
    shore=np.array(next(r['points'] for r in edges if r['id'].startswith('c1228167') and r['edge']==14))
    upper=np.array(next(r['points'] for r in edges if r['id'].startswith('6ff4660f') and r['edge']==10))
    upper=upper[upper[:,1]>=1045.]
    lower=shore[(shore[:,1]>=1490.)&(shore[:,1]<=1640.)]
    bridge=np.array([[1630.,1469.,2.],[1600.,1483.,1.]])
    line=np.concatenate([upper,bridge,lower])[:,:2]
    length=np.r_[0,np.linalg.norm(np.diff(line,axis=0),axis=1).cumsum()]
    distance=np.linspace(0,length[-1],int(length[-1]/5)+1)
    centers=np.stack([np.interp(distance,length,line[:,axis]) for axis in range(2)],axis=1)
    centers=np.stack([np.convolve(np.pad(centers[:,axis],(2,2),mode='edge'),[.08,.22,.4,.22,.08],mode='valid') for axis in range(2)],axis=1)
    tangent=np.gradient(centers,axis=0)
    normal=np.stack([tangent[:,1],-tangent[:,0]],axis=1)
    normal/=np.linalg.norm(normal,axis=1)[:,None]
    taper=.35+.65*smooth(np.minimum(distance,distance[-1]-distance)/35.)
    cross=np.linspace(-24.,24.,13)
    east=centers[:,None,:]+normal[:,None,:]*cross[None,:,None]*taper[:,None,None]
    west_y=np.arange(1025,1291,5.)
    req={'east_xy':east.tolist(),'east_distance':distance.tolist(),'west_y':west_y.tolist(),'west_x':np.arange(260,391,1.).tolist()}
    (OUT/'sample_request.json').write_text(json.dumps(req),encoding='utf-8')

def build():
    request_data=json.loads((OUT/'sample_request.json').read_text())
    samples=json.loads((OUT/'control_samples.json').read_text())
    xy=np.array(request_data['east_xy'])
    old=np.array(samples['east_heights'])
    old=np.where(old>-20,old,-1.)
    distance=np.array(request_data['east_distance'])
    end_weight=smooth(np.minimum(distance,distance[-1]-distance)/25.)[:,None]
    cols=np.arange(old.shape[1])
    edge_weight=smooth(np.minimum(cols,old.shape[1]-1-cols)/2.2)[None,:]
    envelope=np.empty_like(old)
    for i in range(len(xy)):
        delta=np.linalg.norm(xy[i,:,None,:]-xy[i,None,:,:],axis=2)
        envelope[i]=(old[i,None,:]-.50*delta).max(axis=1)
    fair=np.apply_along_axis(lambda row:np.convolve(np.pad(row,(1,1),mode='edge'),[.2,.6,.2],mode='valid'),1,envelope)
    fair=np.apply_along_axis(lambda row:np.convolve(np.pad(row,(1,1),mode='edge'),[.15,.7,.15],mode='valid'),0,fair)
    bias=.22+.75*smooth(np.ptp(old,axis=1)/4.)
    top=old-.18+(np.maximum(fair,old)+bias[:,None]-old+.18)*edge_weight*end_weight
    # Small allowance where the limit surface crosses the old shoulder tip.
    # Keep this local: the surrounding low bank should retain its grade.
    for center, lift, radius in [([1649.030342,1458.802079],.65,12.),
                                 ([1638.243815,1481.753537],.25,9.)]:
        d2=np.sum((xy-np.array(center))**2,axis=2)
        top+=lift*np.exp(-d2/(2*radius**2))*edge_weight*end_weight
    # Native edge checks and the controller revealed that subdivision lowered
    # the central ridge below the old shell's exact NURBS edge by about 1 m.
    # Lift the ridge smoothly; retain the buried outside edges and low bank.
    center_y=xy[:,6,1]
    ridge=2.*smooth((center_y-1055.)/15.)*smooth((1465.-center_y)/30.)
    cross_distance=np.linalg.norm(xy-xy[:,6:7,:],axis=2)
    top+=ridge[:,None]*np.exp(-cross_distance**2/(2*10.**2))*edge_weight
    east=np.concatenate([xy,top[:,:,None]],axis=2)

    ys=np.array(request_data['west_y']);xs=np.array(request_data['west_x'])
    surveyed=np.array(samples['west_heights'])
    shores=[]
    for row in surveyed:
        valid=np.where(row>.15)[0]
        shores.append(xs[valid[-1]] if len(valid) else 325.)
    shores=np.array(shores)
    shores=np.convolve(np.pad(shores,(2,2),mode='edge'),[.08,.22,.4,.22,.08],mode='valid')
    end=smooth(np.minimum(ys-ys.min(),ys.max()-ys)/30.)
    # Width diminishes toward the far end: fill the missing triangular apron,
    # with the outer limit a little below water rather than a standing wall.
    width=(7.+42.*(1.-smooth((ys-1060.)/210.)))*end+2.
    u=np.linspace(0,1,13)
    x=shores[:,None]-24.*(1-u[None,:])+width[:,None]*u[None,:]
    yy=np.broadcast_to(ys[:,None],x.shape)
    ground=np.array([np.interp(row,xs,np.where(surveyed[i]>-20,surveyed[i],-.6)) for i,row in enumerate(x)])
    crest=np.maximum(ground[:,0],ground[:,1])+.7
    ramp=smooth(np.clip((u-.16)/.84,0,1))[None,:]
    apron=crest[:,None]*(1-ramp)-.6*ramp
    # Use one fair cross-section, rather than copying the discontinuous old
    # cliff into the new surface. Its inland edge remains buried in the host.
    inland=smooth(u/.22)[None,:]
    shaped=ground-.2+(apron-ground+.2)*inland
    west_top=ground-.2+(shaped-ground+.2)*end[:,None]
    west=np.stack([x,yy,west_top],axis=-1)
    cages={'east':{'points':east.tolist(),'thickness':2.,'name':'East_arc_faired_ground_seam'},
           'west':{'points':west.tolist(),'thickness':2.,'name':'West_missing_triangular_shore_apron'}}
    (OUT/'control_nets.json').write_text(json.dumps(cages,separators=(',',':')),encoding='utf-8')
    print(json.dumps({k:{'rows':len(v['points']),'columns':len(v['points'][0]),'max_z':float(np.array(v['points'])[:,:,2].max())} for k,v in cages.items()},indent=2))

if __name__=='__main__':
    import sys
    request() if '--request' in sys.argv else build()
