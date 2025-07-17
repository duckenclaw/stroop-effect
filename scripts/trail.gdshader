shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx, depth_draw_opaque, depth_test_disabled, blend_mix, cull_disabled, vertex_lighting;

varying vec3 world_position;
varying vec3 world_normal;
varying vec3 world_view;

uniform float crystal_opacity : hint_range(0.0, 1.0) = 0.3;
uniform float glow_strength : hint_range(0.0, 5.0) = 2.0;
uniform vec4 crystal_color : hint_color = vec4(0.4, 0.8, 1.0, 1.0);
uniform vec4 glow_color : hint_color = vec4(0.6, 0.9, 1.0, 1.0);
uniform float fresnel_power : hint_range(0.0, 5.0) = 2.0;
uniform float inner_glow : hint_range(0.0, 2.0) = 0.5;
uniform float animation_speed : hint_range(0.0, 3.0) = 1.0;

void vertex() {
	world_position = VERTEX;
	world_normal = NORMAL;
	world_view = (INV_CAMERA_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 normal = normalize(NORMAL);
	vec3 view = normalize(VIEW);
	vec3 world_view_dir = normalize(world_view);

	// Calculate fresnel effect for crystal edges
	float fresnel = dot(normal, -view);
	fresnel = pow(1.0 - fresnel, fresnel_power);

	// Animated sparkle effect
	float time = TIME * animation_speed;
	vec3 sparkle_pos = world_position * 8.0;
	float sparkle = sin(sparkle_pos.x + time) * sin(sparkle_pos.y + time * 1.3) * sin(sparkle_pos.z + time * 0.7);
	sparkle = pow(max(sparkle, 0.0), 3.0) * 0.5;

	// Create depth-based inner glow
	float depth_fade = 1.0 - smoothstep(0.0, 1.0, length(view));
	float inner_light = depth_fade * inner_glow;

	// Combine crystal color with fresnel
	vec3 base_color = crystal_color.rgb;
	vec3 edge_glow = glow_color.rgb * fresnel * glow_strength;
	vec3 final_color = base_color + edge_glow + (glow_color.rgb * inner_light);

	// Add sparkle highlights
	final_color += vec3(1.0) * sparkle * glow_strength;

	// Calculate final alpha
	float alpha = crystal_opacity + fresnel * 0.3 + sparkle * 0.2;
	alpha = clamp(alpha, 0.0, 1.0);

	// Set emission for glow effect
	EMISSION = final_color * glow_strength * 0.5;
	ALBEDO = base_color;
	ALPHA = alpha;

	// Crystal-like material properties
	METALLIC = 0.1;
	ROUGHNESS = 0.2;
	SPECULAR = 0.8;
}
