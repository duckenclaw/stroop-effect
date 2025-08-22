shader_type spatial;
render_mode cull_disabled; // View both sides

uniform vec3 sphere_position;
uniform float sphere_radius = 1.0;
uniform float burn_threshold = 0.1;

uniform sampler2D noise_texture;
uniform float noise_strength = 0.1;
uniform float noise_scale = 1.0;

uniform vec3 neon_base_color: source_color = vec3(0.2, 0.5, 1.0);
uniform vec3 albedo_color: source_color;

uniform float inner_face_neon_intensity = 0.86;

vec3 calculate_neon_effect(float value, vec3 base_color) {
    float ramp = clamp(value, 0.0, 1.0);
    vec3 neon_color = vec3(0.0);

    // Layer 1: Intense core
    ramp = ramp * ramp;
    neon_color += pow(base_color, vec3(4.0)) * ramp;

    // Layer 2: Mid intensity
    ramp = ramp * ramp;
    neon_color += base_color * ramp;

    // Layer 3: Bright center
    ramp = ramp * ramp;
    neon_color += vec3(1.0) * ramp;

    return neon_color;
}


void fragment(){
	vec3 world_pos = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float dist = distance(world_pos, sphere_position);

	// Adding Noise for Irregular Edges
	vec2 noise_uv = (world_pos.xy + world_pos.yz + world_pos.xz) * noise_scale;
	float noise = texture(noise_texture, noise_uv).r * 2.0 - 1.0;

	// Applying the Dissolve Effect
	float noisy_radius = sphere_radius + noise * noise_strength;
	float sphere_dist = dist - noisy_radius;

	if (sphere_dist < 0.0) {
	    discard;
	}

	ALBEDO = albedo_color;
	METALLIC = 0.0;
	ROUGHNESS = 1.0;
	EMISSION = vec3(0.0);

	if (sphere_dist < burn_threshold) {
	    float burn_factor = sphere_dist / burn_threshold;

	    float burn_noise = texture(noise_texture, noise_uv * 2.0).r * 0.5;
	    burn_factor = mix(burn_factor, burn_factor * (1.0 + burn_noise), 0.5);

	    // Calculate and apply neon effect
	    vec3 neon = calculate_neon_effect(1.0 - burn_factor, neon_base_color);
	    EMISSION = neon * 2.0;
	}

	// Additional neon effect for back faces
	if (!FRONT_FACING) {
	    vec3 back_face_neon = calculate_neon_effect(inner_face_neon_intensity, neon_base_color);
	    EMISSION += back_face_neon * 1.5;
	}
}