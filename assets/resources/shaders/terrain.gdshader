// The ground plane.
//
// Replaces the StandardMaterial3D that terrain.tres used to be, purely so the ground can run a
// vertex stage and bend with the world -- it is the single most important surface to curve.
// render_mode blend_mul reproduces the old blend_mode = 3 (MUL); the uniform defaults mirror
// the old albedo/metallic/roughness values.
//
// Note this material is transparent and therefore does not write depth, exactly as before.
shader_type spatial;
render_mode blend_mul;

#include "res://assets/resources/shaders/world_curve.gdshaderinc"

uniform vec4 albedo_color : source_color = vec4(0.0, 1.0, 1.0, 1.0);
uniform float metallic : hint_range(0.0, 1.0) = 1.0;
uniform float specular : hint_range(0.0, 1.0) = 0.27;
uniform float roughness : hint_range(0.0, 1.0) = 0.0;

void vertex() {
	POSITION = curve_position(VERTEX, MODELVIEW_MATRIX, PROJECTION_MATRIX);
}

void fragment() {
	ALBEDO = albedo_color.rgb;
	ALPHA = albedo_color.a;
	METALLIC = metallic;
	SPECULAR = specular;
	ROUGHNESS = roughness;
}
