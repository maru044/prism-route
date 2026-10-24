"""Generate the approved tree backlight shaders while preserving source shaders."""
from pathlib import Path
import hashlib
import json

ROOT=Path(__file__).resolve().parents[1]
SHADERS=ROOT/'assets/vegetation/shaders'


def main():
    hashes={}
    for stem in ('vegetation_wind','tree_hlod'):
        path=SHADERS/(stem+'.gdshader')
        original=path.read_text(encoding='utf-8')
        prefix,body=original.split('void light() {',1)
        uniforms='''// Approved tree backlight. Grass continues to use the source shader.
uniform float foliage_backlight_fill : hint_range(0.0, 0.5) = 0.06;
uniform float foliage_shadow_relief : hint_range(0.0, 0.5) = 0.0;

'''
        prefix=prefix.replace('uniform float light_wrap',uniforms+'uniform float light_wrap',1)
        # Keep non-directional lights and all vertex/fragment operations intact.
        body=body.replace('ATTENUATION','foliage_attenuation')
        body='''
	float foliage_attenuation = LIGHT_IS_DIRECTIONAL
		? mix(ATTENUATION, 1.0, foliage_shadow_relief) : ATTENUATION;
'''+body
        insertion='''
	// Neutral diffuse fill follows directional-light colour and energy. It is
	// strongest on the back-facing side, fades on the lit side, and is not emission.
	if (LIGHT_IS_DIRECTIONAL) {
		float ndotl_fill = dot(NORMAL, LIGHT);
		float back_weight = (1.0 - smoothstep(0.05, 0.75, ndotl_fill))
			* mix(0.25, 1.0, smoothstep(-1.0, 0.20, ndotl_fill));
		DIFFUSE_LIGHT += LIGHT_COLOR * foliage_attenuation
			* foliage_backlight_fill * back_weight;
	}
'''
        closing=body.rfind('}')
        body=body[:closing]+insertion+body[closing:]
        (SHADERS/(stem+'_soft_backlight.gdshader')).write_text(prefix+'void light() {'+body,encoding='utf-8')
        hashes[path.name]=hashlib.sha256(path.read_bytes()).hexdigest()
    output=ROOT/'.vegetation_art_build/backlight_1024'
    output.mkdir(parents=True,exist_ok=True)
    (output/'baseline_shader_hashes.json').write_text(json.dumps(hashes,indent=2)+'\n',encoding='utf-8')


if __name__=='__main__':main()
