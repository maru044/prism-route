"""Blender: verify unchanged base geometry, deterministic replay and held-out rays.

Requires the explicit pre-repair checkpoint made by canopy_gap_repair.py.
Does not save/replace any Blender or runtime model files.
"""
import sys
from pathlib import Path
import json
import bpy
import numpy as np

sys.path.insert(0,str(Path(__file__).resolve().parent))
import canopy_gap_repair as gap


def snapshot(objects):
    return {o.name:{
        'vertices':np.array([tuple(v.co) for v in o.data.vertices]),
        'faces':[tuple(p.vertices) for p in o.data.polygons],
        'uv':np.array([tuple(v.uv) for v in o.data.uv_layers.active.data]),
        'normals':np.array([tuple(n.vector) for n in o.data.corner_normals]),
        'colors':np.array([tuple(c.color) for c in o.data.color_attributes.active_color.data]),
        'transform':np.array(o.matrix_world),
    } for o in objects}


def main():
    recipes={};results={}
    # Halfway between selection views, at different elevations.
    views=[(22.5+a,e) for e in (0,35) for a in range(0,360,45)]
    for key,stem in gap.STEMS.items():
        bpy.ops.wm.open_mainfile(filepath=str(gap.OUT/'before'/(stem+'.blend')),load_ui=False)
        objects=gap.foliage_objects();base=snapshot(objects)
        signature=gap.geometry_signature(objects)
        before,_,masks=gap.audit(gap.AlphaTree(objects),views,128,key+'_heldout_before')
        gap.save_masks(masks,gap.OUT/(key+'_heldout_before_masks.png'))
        after_training=json.loads((gap.OUT/(key+'_after.json')).read_text())
        recipes[key]={k:after_training[k] for k in ('added_logical_cards','patch_locations')}
        recipes[key]['base_geometry_sha256']=signature
        _,cards=gap.repair(objects,recipes[key]['patch_locations'],key,limit=32)
        replay=snapshot(objects)
        bpy.ops.wm.open_mainfile(filepath=str(gap.ROOT/'assets/vegetation/source'/(stem+'.blend')),load_ui=False)
        objects=gap.foliage_objects();current=snapshot(objects)
        assert set(current)==set(base) and len(objects)==30
        max_normal_error=0.
        for name,old in base.items():
            new=current[name]
            for field in ('vertices','uv','colors'):
                assert np.allclose(new[field][:len(old[field])],old[field],atol=1e-6), (name,field)
                assert np.allclose(new[field],replay[name][field],atol=1e-6), ('replay',name,field)
            assert new['faces'][:len(old['faces'])]==old['faces']
            assert np.allclose(new['transform'],old['transform'],atol=1e-6)
            max_normal_error=max(max_normal_error,float(np.max(np.abs(new['normals'][:len(old['normals'])]-old['normals']))))
        assert max_normal_error<.001
        old_tree_bounds=np.array([np.min(np.concatenate([v['vertices']@v['transform'][:3,:3].T+v['transform'][:3,3] for v in base.values()]),axis=0),np.max(np.concatenate([v['vertices']@v['transform'][:3,:3].T+v['transform'][:3,3] for v in base.values()]),axis=0)])
        tree=gap.AlphaTree(objects)
        assert np.allclose(tree.bounds,old_tree_bounds,atol=1e-5)
        after,_,masks=gap.audit(tree,views,128,key+'_heldout_after')
        gap.save_masks(masks,gap.OUT/(key+'_heldout_after_masks.png'))
        assert before['capped_rays']==after['capped_rays']==0
        assert after['total_macro_hole_area_m2']<before['total_macro_hole_area_m2']
        results[key]={'before':before,'after':after,'base_geometry_unchanged':True,
            'replay_matches_saved_mesh':True,'bounds_unchanged':True,'max_original_corner_normal_error':max_normal_error,
            'added_logical_cards':cards,'relative_area_reduction':1-after['total_macro_hole_area_m2']/before['total_macro_hole_area_m2']}
        print('CANOPY_HELDOUT_PASS',key,results[key]['relative_area_reduction'],flush=True)
    assert json.loads(gap.RECIPE.read_text(encoding='utf-8'))==recipes, 'Saved repair recipe differs from the reviewed mesh'
    (gap.OUT/'validation.json').write_text(json.dumps(results,indent=2)+'\n',encoding='utf-8')


if __name__=='__main__':main()
