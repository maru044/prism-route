shader_type spatial;
// Compatibility wrapper: use the installed, unmodified MIT MToon light code
// with the source StandardMaterial3D alpha-depth-prepass/cull behavior.
render_mode depth_prepass_alpha, cull_disabled;
#define ALPHA_BLEND
#include "res://addons/mtoon/mtoon_common.gdshaderinc"
