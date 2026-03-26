shader_type spatial;
render_mode blend_add, depth_draw_opaque, cull_back, unshaded;

uniform vec4 field_color : source_color = vec4(0.2, 0.6, 1.0, 1.0);
uniform float animation_speed : hint_range(0.1, 5.0) = 1.5;
uniform float field_intensity : hint_range(0.0, 2.0) = 0.8;
uniform float edge_brightness : hint_range(0.0, 5.0) = 2.0;
uniform float noise_scale : hint_range(1.0, 20.0) = 8.0;
uniform float flicker_speed : hint_range(0.1, 10.0) = 3.0;

// Simple 2D noise function
float noise(vec2 p) {
    return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

// Fractal noise
float fractal_noise(vec2 p) {
    float value = 0.0;
    float amplitude = 0.5;

    for(int i = 0; i < 4; i++) {
        value += noise(p) * amplitude;
        p *= 2.0;
        amplitude *= 0.5;
    }

    return value;
}

void fragment() {
    vec2 uv = UV;

    // Animated noise for electric field effect
    vec2 noise_uv = uv * noise_scale + vec2(TIME * animation_speed * 0.3, TIME * animation_speed * 0.2);
    float noise_val = fractal_noise(noise_uv);

    // Create electric bolts using moving noise
    vec2 bolt_uv = uv * vec2(noise_scale * 0.5, noise_scale * 2.0);
    bolt_uv.y += TIME * animation_speed;
    float bolts = fractal_noise(bolt_uv);
    bolts = pow(bolts, 3.0) * 2.0;

    // Edge detection for fresnel-like effect
    vec3 view_dir = normalize(VIEW);
    vec3 normal = normalize(NORMAL);
    float fresnel = pow(1.0 - abs(dot(view_dir, normal)), edge_brightness);

    // Flicker effect
    float flicker = sin(TIME * flicker_speed) * 0.15 + 0.85;

    // Combine effects
    float field = (noise_val * 0.3 + bolts * 0.4 + fresnel * 0.6) * field_intensity * flicker;

    // Output
    ALBEDO = field_color.rgb;
    ALPHA = field * field_color.a;
    EMISSION = field_color.rgb * field * 1.5;
}
