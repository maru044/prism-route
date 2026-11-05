import bpy

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath='D:/Prism Route/assets/model/sci-fi_chairs_demo/scene.gltf')

g = bpy.data.objects.get('Demo_005_5_17')
print('=== Demo_005_5_17 Hierarchy ===')
def pr(o, indent=0):
    print('  '*indent + o.name + ' (' + o.type + ')')
    for c in o.children:
        pr(c, indent+1)
if g:
    pr(g)
else:
    print('Demo_005_5_17 not found! Objects:')
    for o in bpy.data.objects:
        if 'Demo' in o.name:
            print(' ', o.name)
