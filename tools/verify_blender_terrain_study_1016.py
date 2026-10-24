"""Read back the saved study and verify its live height controls and GLB."""
from pathlib import Path
import bpy,bmesh,json,math
OUT=Path(__file__).resolve().parents[1]/'docs/concepts/blender_terrain_1016_v01'

def bounds(obj):
    bpy.context.view_layer.update();ev=obj.evaluated_get(bpy.context.evaluated_depsgraph_get());m=ev.to_mesh()
    value=[min(v.co.z for v in m.vertices),max(v.co.z for v in m.vertices)];ev.to_mesh_clear();return value

def main():
    bpy.ops.wm.open_mainfile(filepath=str(OUT/'terrain_1016_blender_study.blend'))
    assets=list(bpy.data.collections['01_重建地形_可编辑基底'].objects)
    assert len(assets)==2
    base=bpy.data.objects['基础地形_连续控制网'];feature=bpy.data.objects['独立地形_S形隆起']
    control=bpy.data.objects[base['height_control_object']]
    before={o.name:bounds(o)for o in assets}
    # A reversible test of the intended editing relationship, without saving.
    old=[v.co.z for v in control.data.vertices]
    for v in control.data.vertices:v.co.z+=1
    control.data.update();control.update_tag();bpy.context.view_layer.update()
    lifted={o.name:bounds(o)for o in assets}
    for v,z in zip(control.data.vertices,old):v.co.z=z
    control.data.update();control.update_tag();bpy.context.view_layer.update()
    restored={o.name:bounds(o)for o in assets}
    deltas={n:lifted[n][1]-before[n][1]for n in before}
    assert all(abs(d-1)<.03 for d in deltas.values()),deltas
    assert all(abs(restored[n][1]-before[n][1])<1e-5 for n in before)
    report={'saved_assets':list(before),'height_controls_linked':True,'base_lift_1m_response':deltas,
            'test_change_restored':True,'blend_not_saved_by_test':True,
            'modifiers':{o.name:[m.type for m in o.modifiers]for o in assets}}
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(OUT/'terrain_1016_blender_study.glb'))
    report['glb_objects']=[]
    for o in bpy.data.objects:
        if o.type!='MESH':continue
        assert all(math.isfinite(x)for v in o.data.vertices for x in v.co)
        bm=bmesh.new();bm.from_mesh(o.data);bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=.0001)
        bad=sum(not e.is_manifold for e in bm.edges)
        report['glb_objects'].append({'name':o.name,'vertices':len(bm.verts),'faces':len(bm.faces),'nonmanifold_edges_after_position_weld':bad})
        assert bad==0
        bm.free()
    assert len(report['glb_objects'])==2
    (OUT/'saved_asset_verification.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
    print('STUDY_VERIFIED '+json.dumps(report,ensure_ascii=False))

if __name__=='__main__':main()
