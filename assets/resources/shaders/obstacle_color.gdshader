// The visible coloured body of obstacles, collectibles and ramps.
//
// This replaces what used to be a plain StandardMaterial3D. It exists only so the surface can
// run a vertex stage and pick up the world curve -- StandardMaterial3D has no vertex stage, so
// without this the coloured body would stay flat while the outline pass around it bent away.
//
// Used as the next_pass target of the outline materials, and directly by player_material.tres.
// The uniforms mirror the StandardMaterial3D properties these materials previously set.
shader_type spatial;

#include "res://assets/resources/shaders/world_curve.gdshaderinc"

// hint_default_white so materials that only want a flat albedo_color can leave the texture
// unbound (the plain collectibles do) and still render at full brightness.
uniform sampler2D albedo_texture : source_color, hint_default_white, filter_linear_mipmap, repeat_enable;
uniform vec4 albedo_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float metallic : hint_range(0.0, 1.0) = 0.0;
uniform float specular : hint_range(0.0, 1.0) = 0.5;
uniform float roughness : hint_range(0.0, 1.0) = 1.0;

void vertex() {
	POSITION = curve_position(VERTEX, MODELVIEW_MATRIX, PROJECTION_MATRIX);
}

void fragment() {
	vec4 tex = texture(albedo_texture, UV);
	ALBEDO = albedo_color.rgb * tex.rgb;
	METALLIC = metallic;
	SPECULAR = specular;
	ROUGHNESS = roughness;
}
