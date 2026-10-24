import bpy,json
from pathlib import Path
from mathutils import geometry
out=Path(__file__).resolve().parents[1]/'docs/concepts/blender_terrain_1016_v01'
out.mkdir(parents=True,exist_ok=True)
r={'version':bpy.app.version_string,'cdt_doc':geometry.delaunay_2d_cdt.__doc__}
try:
 p=bpy.context.preferences.addons['cycles'].preferences
 p.refresh_devices()
 r['cycles_devices']=[{'name':d.name,'type':d.type}for d in p.devices]
except Exception as e:r['cycles_probe_error']=str(e)
(out/'blender_probe.json').write_text(json.dumps(r,indent=2))
print(json.dumps(r))
