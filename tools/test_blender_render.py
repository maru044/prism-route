import bpy
from pathlib import Path

bpy.ops.wm.read_factory_settings(use_empty=True)

# Add a simple cube
bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0, 0))

# Add camera
bpy.ops.object.camera_add(location=(2, -3, 2), rotation=(1.1, 0, 0.6))
cam = bpy.context.active_object
bpy.context.scene.camera = cam

# Add light
bpy.ops.object.light_add(type='SUN', location=(5, -5, 10))

bpy.context.scene.render.resolution_x = 800
bpy.context.scene.render.resolution_y = 600
bpy.context.scene.render.image_settings.file_format = 'PNG'
out_path = Path("C:/Users/PC/.gemini/antigravity/brain/51c58479-72e8-436c-a199-d13ab3cac199/blender_render_test.png")
bpy.context.scene.render.filepath = str(out_path)

bpy.context.scene.render.engine = 'BLENDER_WORKBENCH'
bpy.ops.render.render(write_still=True)
print("Rendered test to:", out_path)
