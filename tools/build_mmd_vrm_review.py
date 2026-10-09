"""Run in Blender background: local PMX -> VRM 1.0 workflow experiment.

The source stays outside Git. The audited Keqing and Huahuo profiles use the
standard/D leg layout; missing or already weighted destinations fail explicitly.
"""
import argparse
import hashlib
import json
import math
import sys
from pathlib import Path

import addon_utils
import bpy
from mathutils import Matrix, Quaternion

ROOT = Path(__file__).resolve().parents[1]
BUILD = ROOT / '.model_import_build'
DEST = ROOT / 'assets/characters/import_tests_local/keqing'
PROFILES = {
    'keqing': {'glob': '刻晴_by_*/刻晴/刻晴/刻晴.pmx', 'name': 'Keqing', 'editor': '观海'},
    'huahuo': {'glob': '星穹铁道—花火_by_*/*/花火3.0.pmx', 'name': 'Huahuo', 'editor': '神帝宇'},
}


def set_enum(owner, field, identifier):
    choices = [item.identifier for item in owner.bl_rna.properties[field].enum_items]
    if identifier not in choices:
        raise RuntimeError(f'{field}: {identifier} unavailable: {choices}')
    setattr(owner, field, identifier)


def weight_counts(meshes):
    counts = {}
    for mesh in meshes:
        for vertex in mesh.data.vertices:
            for group in vertex.groups:
                if group.weight > 1e-8:
                    name = mesh.vertex_groups[group.group].name
                    counts[name] = counts.get(name, 0) + 1
    return counts


def weight_totals(meshes, arm):
    deform = {b.name for b in arm.data.bones if b.use_deform}
    return [[sum(g.weight for g in v.groups
                 if mesh.vertex_groups[g.group].name in deform)
             for v in mesh.data.vertices] for mesh in meshes]


def evaluated_vertices(meshes):
    bpy.context.view_layer.update()
    depsgraph = bpy.context.evaluated_depsgraph_get()
    result = []
    for mesh in meshes:
        evaluated = mesh.evaluated_get(depsgraph)
        result.extend(evaluated.matrix_world @ v.co for v in evaluated.data.vertices)
    return result


def foot_test(meshes, arm, bone_name):
    bone = arm.pose.bones[bone_name]
    before = evaluated_vertices(meshes)
    bone.rotation_mode = 'QUATERNION'
    bone.rotation_quaternion = Quaternion((1, 0, 0), math.radians(25))
    after = evaluated_vertices(meshes)
    bone.rotation_quaternion = Quaternion()
    bpy.context.view_layer.update()
    if len(before) != len(after):
        raise RuntimeError('Foot rotation changed topology')
    distances = [(a-b).length for a, b in zip(before, after)]
    return {'bone': bone_name, 'angle_deg': 25,
            'moved_vertices_over_0_1mm': sum(d > 0.0001 for d in distances),
            'max_displacement_m': max(distances, default=0)}


def transfer_weights(meshes, source, target, merge=False):
    transferred = 0
    for mesh in meshes:
        src = mesh.vertex_groups.get(source)
        if src is None:
            continue
        dst = mesh.vertex_groups.get(target)
        nonempty = dst and any(any(g.group == dst.index and g.weight > 1e-8
                                  for g in v.groups) for v in mesh.data.vertices)
        if nonempty and not merge:
            raise RuntimeError(f'{mesh.name}: destination {target} is already weighted')
        if not merge:
            if dst:
                mesh.vertex_groups.remove(dst)
            src.name = target
            transferred += 1
        else:
            dst = dst or mesh.vertex_groups.new(name=target)
            rows = [(v.index, g.weight) for v in mesh.data.vertices
                    for g in v.groups if g.group == src.index and g.weight > 0]
            for index, weight in rows:
                dst.add([index], weight, 'ADD')
            mesh.vertex_groups.remove(src)
            transferred += len(rows)
    return transferred


def export_vrm(arm, meshes, path):
    # The add-on changes selection during export; restore it for every variant.
    bpy.ops.object.select_all(action='DESELECT')
    for obj in [arm, *meshes]:
        obj.hide_set(False)
        obj.select_set(True)
    bpy.context.view_layer.objects.active = arm
    result = bpy.ops.export_scene.vrm(filepath=str(path),
        armature_object_name=arm.name, use_addon_preferences=False,
        export_only_selections=True, export_invisibles=False,
        export_gltf_animations=False, ignore_warning=True)
    if result != {'FINISHED'} or not path.is_file():
        raise RuntimeError(f'VRM export failed: {result}, {path}')
    print('EXPORTED', str(path), path.stat().st_size, flush=True)


def main():
    sys.stdout.reconfigure(encoding='utf-8')
    parser = argparse.ArgumentParser()
    parser.add_argument('--source', type=Path)
    parser.add_argument('--profile', choices=PROFILES, default='keqing')
    args = parser.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
    profile = PROFILES[args.profile]
    source = args.source or next(Path('D:/模型/20261008').glob(profile['glob']))
    BUILD = ROOT / '.model_import_build' / (args.profile if args.profile != 'keqing' else '')
    DEST = ROOT / 'assets/characters/import_tests_local' / args.profile
    BUILD.mkdir(parents=True, exist_ok=True)
    DEST.mkdir(parents=True, exist_ok=True)
    source_hash = hashlib.sha256(source.read_bytes()).hexdigest()
    for module in ['bl_ext.blender_org.mmd_tools', 'bl_ext.blender_org.vrm']:
        if not addon_utils.check(module)[1]:
            addon_utils.enable(module, default_set=False, persistent=False)
        if not addon_utils.check(module)[1]:
            raise RuntimeError(f'Unable to enable {module}')
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete(use_global=False)
    result = bpy.ops.mmd_tools.import_model(filepath=str(source), scale=0.08,
        types={'MESH', 'ARMATURE', 'MORPHS'}, save_log=False, log_level='WARNING')
    if result != {'FINISHED'}:
        raise RuntimeError(f'PMX import failed: {result}')
    arm = next(o for o in bpy.context.scene.objects if o.type == 'ARMATURE')
    meshes = [o for o in bpy.context.scene.objects if o.type == 'MESH']
    before_counts = weight_counts(meshes)
    before_totals = weight_totals(meshes, arm)
    # Imported MMD append transforms/IK are authoring controls, not VRM runtime.
    removed_constraints = []
    for bone in arm.pose.bones:
        removed_constraints.extend({'bone': bone.name, 'type': c.type, 'name': c.name}
                                   for c in bone.constraints)
        for constraint in list(bone.constraints):
            bone.constraints.remove(constraint)
        bone.matrix_basis = Matrix.Identity(4)
    arm.animation_data_clear()
    for mesh in meshes:
        mesh.select_set(True)
        mesh.animation_data_clear()
        if mesh.data.shape_keys:
            mesh.data.shape_keys.animation_data_clear()
            for key in mesh.data.shape_keys.key_blocks:
                key.value = 0
    bpy.context.view_layer.objects.active = meshes[0]
    result = bpy.ops.mmd_tools.convert_materials(use_principled=True, clean_nodes=True)
    if result != {'FINISHED'}:
        raise RuntimeError('MMD material conversion failed')
    materials = {slot.material for mesh in meshes for slot in mesh.material_slots if slot.material}
    for material in materials:
        # The conversion operator only builds nodes; the exporter additionally
        # requires enabled=True. Its MMD path also initializes textured RGB to
        # zero, so explicitly retain the PMX diffuse tint rather than black.
        gltf = material.vrm_addon_extension.mtoon1
        gltf.enabled = True
        if not gltf.enabled:
            raise RuntimeError(f'MToon activation failed: {material.name}')
        original = material.mmd_material
        gltf.pbr_metallic_roughness.base_color_factor = (*original.diffuse_color, original.alpha)
        gltf.emissive_factor = (0, 0, 0)
        mtoon = gltf.extensions.vrmc_materials_mtoon
        mtoon.shade_multiply_texture.index.source = gltf.pbr_metallic_roughness.base_color_texture.index.source
        mtoon.shade_color_factor = (0.72, 0.73, 0.80)
        mtoon.shading_toony_factor = 0.75
        # PMX texture alpha includes hair/eyelash cutouts, even when the material
        # alpha is 1. Keep those holes instead of rendering opaque rectangles.
        if gltf.pbr_metallic_roughness.base_color_texture.index.source and original.alpha >= 1:
            set_enum(gltf, 'alpha_mode', 'MASK')
            gltf.alpha_cutoff = 0.35
    for image in bpy.data.images:
        if image.source == 'FILE' and image.filepath:
            if not Path(bpy.path.abspath(image.filepath)).is_file():
                raise RuntimeError(f'Missing texture: {image.filepath}')
            image.pack()
    bpy.context.view_layer.objects.active = arm
    arm.select_set(True)
    ext = arm.data.vrm_addon_extension
    set_enum(ext, 'spec_version', '1.0')
    bpy.ops.vrm.assign_vrm1_humanoid_human_bones_automatically(armature_object_name=arm.name)
    human = ext.vrm1.humanoid.human_bones
    # Use the audited pelvic fork rather than the lower MMD center pivot.
    if '腰' not in arm.data.bones:
        raise RuntimeError('Profile mismatch: missing pelvic fork 腰')
    human.hips.node.bone_name = '腰'
    set_enum(ext.vrm1.humanoid, 'pose', 'autoPose')
    meta = ext.vrm1.meta
    meta.vrm_name = profile['name'] + ' - local neutral conversion test'
    meta.version = '2026-10-08' if args.profile == 'keqing' else '2026-10-09'
    meta.authors.clear()
    for author in ['miHoYo', profile['editor']]:
        meta.authors.add().value = author
    meta.copyright_information = f"Source model: miHoYo; MMD conversion: {profile['editor']}. Original model terms remain authoritative."
    meta.third_party_licenses = 'Original readme prohibits redistribution, commercial use and use in 18+ works. Local neutral technical test only.'
    set_enum(meta, 'commercial_usage', 'personalNonProfit')
    set_enum(meta, 'modification', 'allowModification')
    set_enum(meta, 'credit_notation', 'required')
    set_enum(meta, 'avatar_permission', 'onlySeparatelyLicensedPerson')
    meta.allow_redistribution = False
    meta.allow_excessively_sexual_usage = False
    meta.allow_excessively_violent_usage = False
    bpy.ops.object.select_all(action='DESELECT')
    for obj in [arm, *meshes]:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = arm
    baseline_test = foot_test(meshes, arm, '足首.L')
    export_vrm(arm, meshes, DEST/f'{args.profile}_before.vrm')
    bpy.ops.wm.save_as_mainfile(filepath=str(BUILD/f'{args.profile}_before.blend'))
    transfers = []
    for side in ['L', 'R']:
        for source_stem, target_stem in [('足D', '足'), ('ひざD', 'ひざ'), ('足首D', '足首')]:
            src, dst = f'{source_stem}.{side}', f'{target_stem}.{side}'
            if src not in arm.data.bones or dst not in arm.data.bones:
                raise RuntimeError(f'Profile mismatch: missing {src} or {dst}')
            delta = (arm.data.bones[src].head_local-arm.data.bones[dst].head_local).length
            if delta > 0.001:
                raise RuntimeError(f'Profile mismatch: {src}/{dst} pivots differ by {delta}m')
            transfers.append({'source': src, 'target': dst, 'operation': 'rename_empty_destination',
                              'mesh_groups': transfer_weights(meshes, src, dst), 'pivot_delta_m': delta})
        src, dst = f'足先EX.{side}', f'足首.{side}'
        transfers.append({'source': src, 'target': dst, 'operation': 'add_weights',
                          'vertex_entries': transfer_weights(meshes, src, dst, merge=True)})
    after_counts = weight_counts(meshes)
    after_totals = weight_totals(meshes, arm)
    weight_error = max(abs(a-b) for aa,bb in zip(before_totals,after_totals) for a,b in zip(aa,bb))
    if weight_error > 1e-6 or any(t < 1e-6 for row in after_totals for t in row):
        raise RuntimeError(f'Weights lost: max total error {weight_error}')
    fixed_test = foot_test(meshes, arm, '足首.L')
    if baseline_test['moved_vertices_over_0_1mm'] != 0 or fixed_test['moved_vertices_over_0_1mm'] < 100:
        raise RuntimeError(f'Foot deformation test failed: {baseline_test}, {fixed_test}')
    sys.path.insert(0, str(ROOT / 'tools'))
    from mmd_sleeve_springs import configure_sleeves
    sleeve_report = configure_sleeves(arm, args.profile)
    export_vrm(arm, meshes, DEST/f'{args.profile}_fixed.vrm')
    bpy.ops.wm.save_as_mainfile(filepath=str(BUILD/f'{args.profile}_fixed.blend'))
    report = {'profile': args.profile, 'blender': bpy.app.version_string,
        'source_unchanged': hashlib.sha256(source.read_bytes()).hexdigest() == source_hash,
        'vertices': sum(len(mesh.data.vertices) for mesh in meshes), 'bones': len(arm.data.bones),
        'materials': len(materials), 'transfers': transfers,
        'leg_weight_counts_before': {k:v for k,v in before_counts.items() if any(s in k for s in ['足','ひざ','つま先'])},
        'leg_weight_counts_after': {k:v for k,v in after_counts.items() if any(s in k for s in ['足','ひざ','つま先'])},
        'max_weight_total_error': weight_error, 'removed_constraints': removed_constraints,
        'foot_rotation_before': baseline_test, 'foot_rotation_after': fixed_test,
        'humanoid': {str(name):bone.node.bone_name for name,bone in human.human_bone_name_to_human_bone().items() if bone.node.bone_name},
        'sleeves': sleeve_report,
        'limitations': ['Hair/skirt springs are not configured', 'Facial morphs retained but VRM expressions not assigned',
                       'MMD toon/sphere shading is not reproduced pixel-for-pixel', 'Audited model profile; other models require an audit'],
        }
    (BUILD/'conversion_report.json').write_text(json.dumps(report, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
    print('CONVERSION_SUMMARY', json.dumps({k:report[k] for k in ['vertices','bones','materials','max_weight_total_error','foot_rotation_before','foot_rotation_after']}, ensure_ascii=False), flush=True)


if __name__ == '__main__':
    main()
