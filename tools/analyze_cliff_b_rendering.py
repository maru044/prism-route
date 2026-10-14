"""Measure unchanged fixed ROIs; read pixels only, never retouch render output."""
from pathlib import Path
import json
import struct
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SHOTS = ROOT/'screenshots/cliff_b_rendering_20261014'
REGIONS = {
    'gallery_wall': ('gallery', (100, 100, 600, 450)),
    'gallery_road': ('gallery', (350, 800, 1000, 1000)),
    'base_underside': ('base', (1100, 100, 1700, 250)),
    'base_sunlit_floor': ('base', (100, 700, 700, 950)),
}

def pixels(name):
    return np.asarray(Image.open(SHOTS/(name+'.png')).convert('RGB'), dtype=float)

def audit_mesh():
    glb = (ROOT/'assets/world/cliff_b_test/cliff_b_world.glb').read_bytes()
    length = struct.unpack_from('<I', glb, 12)[0]
    doc = json.loads(glb[20:20+length])
    start = 20 + length + 8
    def accessor(index):
        item = doc['accessors'][index]
        view = doc['bufferViews'][item['bufferView']]
        dtype = {5126: '<f4', 5125: '<u4', 5123: '<u2'}[item['componentType']]
        width = {'SCALAR':1, 'VEC3':3}[item['type']]
        return np.frombuffer(glb, dtype=dtype, count=item['count']*width,
            offset=start+view.get('byteOffset',0)+item.get('byteOffset',0)).reshape((-1,width))
    output = []
    for node in doc['nodes']:
        if not node.get('name','').startswith('Architecture_'): continue
        primitive = doc['meshes'][node['mesh']]['primitives'][0]
        positions = accessor(primitive['attributes']['POSITION'])
        normals = accessor(primitive['attributes']['NORMAL'])
        triangles = accessor(primitive['indices']).reshape((-1,3))
        face = np.cross(positions[triangles[:,1]]-positions[triangles[:,0]], positions[triangles[:,2]]-positions[triangles[:,0]])
        face_length = np.linalg.norm(face, axis=1)
        averaged = normals[triangles].mean(axis=1)
        agreement = np.einsum('ij,ij->i', face, averaged)
        output.append({'mesh':node['name'], 'triangles':len(triangles), 'nonfinite_vertices':int((~np.isfinite(positions)).any(axis=1).sum()),
            'near_zero_area_triangles':int((face_length<1e-8).sum()), 'normals_opposed_to_winding':int((agreement < -1e-6).sum())})
    return output

def main():
    result = {'roi_coordinates_xyxy':{}, 'measurements':{}, 'gloss':{}, 'geometry_normals':audit_mesh()}
    variants = ['baseline','ao_off','ao_half','ambient_050','ambient_060','sky_ambient','plain_white','road_only','shadow_off','warm','neutral','cool','warm_wide','final','no_gloss']
    for label,(view,box) in REGIONS.items():
        result['roi_coordinates_xyxy'][label] = list(box)
        result['measurements'][label] = {}
        x0,y0,x1,y1 = box
        for variant in variants:
            region = pixels(view+'_'+variant)[y0:y1,x0:x1]
            luma = region @ np.array([.2126,.7152,.0722])
            result['measurements'][label][variant] = {'mean_rgb_8bit':region.mean(axis=(0,1)).round(3).tolist(),
                'mean_display_luma_8bit':round(float(luma.mean()),3), 'minimum_display_luma_8bit':round(float(luma.min()),3)}
    on,off = pixels('roof_gloss_final'),pixels('roof_gloss_off')
    # Rectangular ROI lies wholly on the pavilion roof, away from trees/edges.
    delta = on[350:750,700:1400] - off[350:750,700:1400]
    result['gloss'] = {'roof_roi_xyxy':[700,350,1400,750], 'max_rgb_gain_8bit':float(delta.max()),
        'mean_rgb_gain_8bit':delta.mean(axis=(0,1)).round(3).tolist(), 'pixels_gain_over_8':int((delta.max(axis=2)>8).sum()),
        'unmodified_background_max_change_8bit':float(np.abs(on[:120]-off[:120]).max())}
    assert result['gloss']['pixels_gain_over_8'] > 100, 'Actual roof highlight was not demonstrated'
    assert result['gloss']['unmodified_background_max_change_8bit'] <= 1, 'Reflection leaked into the background'
    assert result['measurements']['gallery_road']['final']['mean_display_luma_8bit'] > 60, 'Gallery road still too dark'
    (ROOT/'docs/CLIFF_B_RENDERING_PIXEL_REPORT.json').write_text(json.dumps(result,indent=2,ensure_ascii=False),encoding='utf-8')
    for label,values in result['measurements'].items():
        print(label,{key:values[key]['mean_rgb_8bit'] for key in ['baseline','ao_off','ambient_060','road_only','shadow_off','final']})
    print('gloss',result['gloss'])
    print('architecture_normal_audit',{'meshes':len(result['geometry_normals']),'opposed':sum(x['normals_opposed_to_winding'] for x in result['geometry_normals']), 'degenerate':sum(x['near_zero_area_triangles'] for x in result['geometry_normals'])})

if __name__ == '__main__': main()
