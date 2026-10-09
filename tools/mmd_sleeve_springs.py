"""Audited sleeve-only VRMC_springBone setup for the two local PMX profiles."""
import uuid

import bpy


def configure_sleeves(arm, profile):
    springs = arm.data.vrm_addon_extension.spring_bone1
    springs.springs.clear()
    springs.colliders.clear()
    springs.collider_groups.clear()
    reparented = []
    if profile == 'huahuo':
        # MMD cuff panels use a shoulder helper. Follow the animated arm instead.
        bpy.context.view_layer.objects.active = arm
        bpy.ops.object.mode_set(mode='EDIT')
        for bone in arm.data.edit_bones:
            if bone.name.startswith(('yxx__', 'zxx_')) and bone.parent.name.startswith('肩C.'):
                parent = '腕.R' if bone.name.startswith('yxx__') else '腕.L'
                reparented.append({'bone': bone.name, 'from': bone.parent.name, 'to': parent})
                bone.parent = arm.data.edit_bones[parent]
        bpy.ops.object.mode_set(mode='OBJECT')
    group = springs.collider_groups.add()
    group.uuid = uuid.uuid4().hex
    group.vrm_name = 'Sleeve body'
    for name, radius in [('腰', .105), ('上半身', .09), ('上半身2', .10),
                         ('腕.L', .038), ('腕.R', .038),
                         ('ひじ.L', .03), ('ひじ.R', .03),
                         ('足.L', .055), ('足.R', .055)]:
        bone = arm.data.bones[name]
        collider = springs.colliders.add()
        collider.uuid = uuid.uuid4().hex
        collider.node.bone_name = name
        collider.shape_type = 'Capsule'
        collider.reset_bpy_object(bpy.context, arm)
        collider.shape.capsule.offset = (0, 0, 0)
        collider.shape.capsule.tail = bone.matrix_local.inverted() @ bone.tail_local
        collider.shape.capsule.radius = radius
        group.colliders.add().collider_uuid = collider.uuid
    root_names = ['袖_0_1.L', '袖_0_1.R'] if profile == 'keqing' else ['yx__1', 'zx_0_1']
    report_chains = []
    for root_name in root_names:
        chain = []
        bone = arm.data.bones[root_name]
        while True:
            chain.append(bone.name)
            children = [c for c in bone.children if not c.name.startswith(('_dummy_', '_shadow_'))]
            if not children: break
            if len(children) != 1: raise RuntimeError(f'Branched sleeve chain: {bone.name}')
            bone = children[0]
        # Keep the attachment segment rigid so shoulder/cuff geometry cannot
        # collapse when the free fabric changes direction under gravity.
        chain = chain[1:]
        spring = springs.springs.add()
        spring.vrm_name = 'Sleeves ' + root_name
        spring.center.bone_name = '腰'
        spring.collider_groups.add().collider_group_uuid = group.uuid
        for i, name in enumerate(chain):
            joint = spring.joints.add()
            joint.node.bone_name = name
            joint.stiffness = .65 if i == 0 else .25
            joint.gravity_power = .4
            joint.gravity_dir = (0, 0, -1)
            joint.drag_force = .65
            joint.hit_radius = .014
        report_chains.append({'attachment': root_name, 'root': chain[0], 'joints': chain})
    return {'chains': report_chains, 'colliders': len(springs.colliders),
            'reparented_cuff_roots': reparented,
            'limitations': ['Bone-chain approximation, not cloth self-collision',
                            'Hair and skirt are still outside this sleeve-only setup']}
