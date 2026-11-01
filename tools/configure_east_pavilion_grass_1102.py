"""Index complete affected grass cells, including newly raised roofs and old empty cells."""
from pathlib import Path
import json,hashlib
import numpy as np
ROOT=Path(__file__).resolve().parents[1]
def configure():
    assets=ROOT/'assets/world/east_earth_pavilion_1102'
    manifest=json.loads((assets/'manifest.json').read_text());support=manifest['grass_support'];width,height=support['size']
    grid=np.frombuffer((assets/'grass_support.rgf').read_bytes(),'<f4').reshape(height,width,2)
    z,x=np.nonzero(grid[:,:,1]<1.5)
    wx=support['origin_xz'][0]+x*support['pixel_size'];wz=support['origin_xz'][1]+z*support['pixel_size']
    columns=set(map(tuple,np.stack([np.floor(wx/24),np.floor(wz/24)],1).astype(int).tolist()))
    baseline=json.loads((ROOT/'assets/world/current_map_validation/grass_cells.json').read_text())
    cells={tuple(c) for c in baseline['cells'] if (c[0],c[2]) in columns}
    for iz,ix,px,pz in zip(z,x,wx,wz):
        if grid[iz,ix,1]>.5:cells.add((int(np.floor(px/24)),int(np.floor(grid[iz,ix,0]/24)),int(np.floor(pz/24))))
    config={'version':1,'cells':sorted(cells),'columns':len(columns),'cell_size_m':24,
        'grass_mesh':'res://assets/vegetation/models/grass_star_3card_v6.glb','palette':'green',
        'geometry_sha256':manifest['mesh_sha256'],'support_sha256':hashlib.sha256((assets/'grass_support.rgf').read_bytes()).hexdigest()}
    (assets/'ground_grass.json').write_text(json.dumps(config,indent=2)+'\n',encoding='utf-8')
    print(json.dumps({'cells':len(cells),'columns':len(columns)}))
if __name__=='__main__':configure()
