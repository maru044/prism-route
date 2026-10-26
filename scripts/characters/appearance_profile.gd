extends Resource
## Explicit material-name mapping. Unknown/ambiguous surfaces keep their original.
@export var character_label := "甘雨"
@export var mesh_path := NodePath("甘雨/甘雨_arm/GeneralSkeleton/甘雨_mesh")
@export var regions: Dictionary = {}
@export_range(2, 3, 1) var tone_bands := 2
@export_range(0.01, 0.3) var edge_softness := 0.08
@export_range(0.0, 1.0) var face_softness := 0.45
@export_range(0.0, 1.5) var diffuse_gain := 0.85
@export_range(0.0, 1.0) var hair_highlight := 0.12
@export_range(0.0, 1.0) var eye_highlight := 0.12
@export var shadow_multiplier := Vector3(0.62, 0.56, 0.70)
@export var skin_shadow_multiplier := Vector3(0.82, 0.68, 0.72)
@export_group("C1 原神式 NPR")
@export var face_sdf: Texture2D
@export var body_material_mask: Texture2D
@export var sdf_enabled := true
@export_range(0.005, 0.15) var sdf_softness := 0.035
@export_range(0.0, 1.0) var ambient_weight := 0.62
@export_range(0.0, 1.5) var c1_diffuse_gain := 0.82
@export var c1_shadow_multiplier := Vector3(0.50, 0.46, 0.64)
@export var c1_skin_shadow_multiplier := Vector3(0.71, 0.48, 0.55)
@export_range(0.0, 1.0) var c1_hair_highlight := 0.22
@export var outline_enabled := true
@export_range(0.0, 2.0) var outline_pixels := 0.85
