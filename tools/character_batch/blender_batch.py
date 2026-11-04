"""Manifest-driven PMX audit/conversion in an independent Blender process."""
import argparse,json,sys,hashlib,re
from pathlib import Path
import bpy,addon_utils
from mathutils import Matrix

ROOT=Path(__file__).resolve().parents[2]
WORK=Path('D:/Prism Route/research/character_batch_20261104')
sys.path.insert(0,str(ROOT/'tools'))
from build_mmd_vrm_review import weight_counts,weight_totals,foot_test,transfer_weights,export_vrm,set_enum

def import_model(row):
    for module in ['bl_ext.blender_org.mmd_tools','bl_ext.blender_org.vrm']:
        if not addon_utils.check(module)[1]:addon_utils.enable(module,default_set=False,persistent=False)
        assert addon_utils.check(module)[1],module
    bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
    assert bpy.ops.mmd_tools.import_model(filepath=row['source'],scale=.08,types={'MESH','ARMATURE','MORPHS'},save_log=False,log_level='WARNING')=={'FINISHED'}
    arm=next(o for o in bpy.context.scene.objects if o.type=='ARMATURE')
    meshes=[o for o in bpy.context.scene.objects if o.type=='MESH']
    for b in arm.pose.bones:
        for c in list(b.constraints):b.constraints.remove(c)
        b.matrix_basis=Matrix.Identity(4)
    arm.animation_data_clear()
    for mesh in meshes:
        mesh.animation_data_clear()
        if mesh.data.shape_keys:
            mesh.data.shape_keys.animation_data_clear()
            for key in mesh.data.shape_keys.key_blocks:key.value=0
    return arm,meshes

def audit(row,arm,meshes):
    counts=weight_counts(meshes)
    bones=[dict(name=b.name,japanese=arm.pose.bones[b.name].mmd_bone.name_j,parent=b.parent.name if b.parent else None,
                head=list(b.head_local),tail=list(b.tail_local),weighted_vertices=counts.get(b.name,0)) for b in arm.data.bones]
    mats=[]
    for m in {s.material for o in meshes for s in o.material_slots if s.material}:
        mats.append(dict(name=m.name,alpha=m.mmd_material.alpha,texture=m.mmd_material.texture if hasattr(m.mmd_material,'texture') else ''))
    return dict(id=row['id'],label=row['label'],source_sha256=row['source_sha256'],
                vertices=sum(len(m.data.vertices) for m in meshes),bones=bones,materials=mats,
                morphs=sum(len(m.data.shape_keys.key_blocks)-1 for m in meshes if m.data.shape_keys),
                textures=[dict(path=i.filepath,exists=Path(bpy.path.abspath(i.filepath)).exists()) for i in bpy.data.images if i.source=='FILE'])

def physics_chains(row,arm):
    allowed={b.name for b in arm.data.bones if b.name.startswith(tuple(row['physics_prefixes']))}
    result=[]
    def segment(name):
        path=[name];bone=arm.data.bones[name]
        while True:
            children=[c for c in bone.children if c.name in allowed]
            if len(children)!=1:break
            bone=children[0];path.append(bone.name)
        if len(path)>=3:
            parent=arm.data.bones[path[0]].parent;anc=[]
            while parent:anc.append(parent.name);parent=parent.parent
            group='Hair' if '頭' in anc or path[0].startswith(('Hair','CF_','DM_')) else 'Clothes'
            # Keep the attachment segment rigid on long articulated garments.
            result.append(dict(group=group,attachment=path[0],nodes=path[1:] if len(path)>3 else path))
        for child in [c for c in bone.children if c.name in allowed]:segment(child.name)
    for b in arm.data.bones:
        if b.name in allowed and (not b.parent or b.parent.name not in allowed):segment(b.name)
    joints=[n for c in result for n in c['nodes']];assert len(joints)==len(set(joints))
    assert any(c['group']=='Hair' for c in result) and any(c['group']=='Clothes' for c in result)
    return result

def build(row,arm,meshes,report):
    before=weight_totals(meshes,arm);baseline=foot_test(meshes,arm,'足首.L');transfers=[]
    for side in ['L','R']:
        for stem,target in [('足D','足'),('ひざD','ひざ'),('足首D','足首')]:
            src=f'{stem}.{side}';dst=f'{target}.{side}';assert src in arm.data.bones and dst in arm.data.bones
            delta=(arm.data.bones[src].head_local-arm.data.bones[dst].head_local).length
            assert delta<.001,(src,dst,delta)
            groups=transfer_weights(meshes,src,dst)
            transfers.append(dict(source=src,target=dst,groups=groups,pivot_delta_m=delta))
        transfers.append(dict(source=f'足先EX.{side}',target=f'足首.{side}',entries=transfer_weights(meshes,f'足先EX.{side}',f'足首.{side}',merge=True)))
    # D-bone children include weighted knee/ankle helpers on Miyabi. Preserve
    # their global rests while making them follow the animated standard bones.
    bpy.context.view_layer.objects.active=arm;bpy.ops.object.mode_set(mode='EDIT')
    helper_links=[]
    for side in ['L','R']:
        for stem,target in [('足D','足'),('ひざD','ひざ'),('足首D','足首')]:
            bone=arm.data.edit_bones[f'{stem}.{side}'];matrix=bone.matrix.copy()
            bone.parent=arm.data.edit_bones[f'{target}.{side}'];bone.use_connect=False;bone.matrix=matrix
            helper_links.append([bone.name,bone.parent.name])
    bpy.ops.object.mode_set(mode='OBJECT')
    after=weight_totals(meshes,arm)
    error=max(abs(a-b) for aa,bb in zip(before,after) for a,b in zip(aa,bb))
    assert error<1e-6 and min(v for row_values in after for v in row_values)>1e-6
    fixed=foot_test(meshes,arm,'足首.L');assert fixed['moved_vertices_over_0_1mm']>=100
    bpy.ops.object.select_all(action='DESELECT')
    for mesh in meshes:mesh.select_set(True)
    bpy.context.view_layer.objects.active=meshes[0]
    assert bpy.ops.mmd_tools.convert_materials(use_principled=True,clean_nodes=True)=={'FINISHED'}
    mats={s.material for o in meshes for s in o.material_slots if s.material}
    for material in mats:
        m=material.vrm_addon_extension.mtoon1;m.enabled=True;source=material.mmd_material
        m.pbr_metallic_roughness.base_color_factor=(*source.diffuse_color,source.alpha)
        m.emissive_factor=(0,0,0)
        toon=m.extensions.vrmc_materials_mtoon
        toon.shade_multiply_texture.index.source=m.pbr_metallic_roughness.base_color_texture.index.source
        toon.shade_color_factor=(.78,.73,.85);toon.shading_toony_factor=.75
        set_enum(m,'alpha_mode','BLEND' if source.alpha<.999 else 'MASK');m.alpha_cutoff=.35
    for image in bpy.data.images:
        if image.source=='FILE' and image.filepath:
            assert Path(bpy.path.abspath(image.filepath)).is_file(),image.filepath
            image.pack()
    bpy.context.view_layer.objects.active=arm;arm.select_set(True)
    ext=arm.data.vrm_addon_extension;set_enum(ext,'spec_version','1.0')
    bpy.ops.vrm.assign_vrm1_humanoid_human_bones_automatically(armature_object_name=arm.name)
    human=ext.vrm1.humanoid.human_bones;assert '腰' in arm.data.bones
    human.hips.node.bone_name='腰';set_enum(ext.vrm1.humanoid,'pose','autoPose')
    meta=ext.vrm1.meta;meta.vrm_name=row['label'];meta.version='2026-11-04';meta.authors.clear()
    meta.authors.add().value='miHoYo; original MMD credits retained in source archive'
    meta.copyright_information='Original PMX and source archive credits apply.'
    meta.third_party_licenses='Original archive readme and PMX comments remain authoritative; local technical conversion.'
    set_enum(meta,'commercial_usage','personalNonProfit');set_enum(meta,'modification','allowModification');set_enum(meta,'credit_notation','required');set_enum(meta,'avatar_permission','onlySeparatelyLicensedPerson')
    meta.allow_redistribution=False;meta.allow_excessively_sexual_usage=False;meta.allow_excessively_violent_usage=False
    chains=physics_chains(row,arm)
    folder=WORK/'converted'/row['id'];folder.mkdir(parents=True,exist_ok=True)
    export_vrm(arm,meshes,folder/'body.vrm')
    report.update(transfers=transfers,helper_links=helper_links,max_weight_total_error=error,foot_before=baseline,foot_after=fixed,chains=chains,
                  source_unchanged=hashlib.sha256(Path(row['source']).read_bytes()).hexdigest()==row['source_sha256'])
    assert report['source_unchanged']
    (WORK/'reports'/f'{row["id"]}_build.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf8')
    print('BATCH_BUILT',json.dumps(dict(id=row['id'],chains=len(chains),weight_error=error,foot_vertices=fixed['moved_vertices_over_0_1mm']),ensure_ascii=False),flush=True)

def main():
    global WORK
    sys.stdout.reconfigure(encoding='utf8')
    parser=argparse.ArgumentParser();parser.add_argument('--id',required=True);parser.add_argument('--mode',choices=['audit','build'],default='audit');parser.add_argument('--work-dir',type=Path,default=WORK);args=parser.parse_args(sys.argv[sys.argv.index('--')+1:]);WORK=args.work_dir
    row=next(r for r in json.loads((WORK/'batch.json').read_text(encoding='utf8'))['profiles'] if r['id']==args.id)
    arm,meshes=import_model(row);report=audit(row,arm,meshes)
    (WORK/'reports').mkdir(exist_ok=True)
    (WORK/'reports'/f'{row["id"]}_audit.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf8')
    if args.mode=='build':build(row,arm,meshes,report)
    print('BATCH_AUDIT',json.dumps(dict(id=row['id'],vertices=report['vertices'],bones=len(report['bones']),materials=len(report['materials']),morphs=report['morphs']),ensure_ascii=False),flush=True)

if __name__=='__main__':main()
