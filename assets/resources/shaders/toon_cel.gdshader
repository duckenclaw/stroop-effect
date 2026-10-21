// Anime-style cel shader: hard light bands, halftone dots at the shadow edge,
// stepped specular and a fresnel rim. Port of the NG_ToonCel node group from Blender.
//
// One shader, any color: set base_color per material (or per color in ColorUtil).
// Pair it with outline.gdshader for ink lines (outline material -> next_pass -> this).
shader_type spatial;

group_uniforms Color;
uniform vec4 base_color : source_color = vec4(0.85, 0.2, 0.2, 1.0);
// Optional pattern; leave empty for flat color. It multiplies base_color.
uniform sampler2D albedo_texture : source_color, hint_default_white, filter_linear_mipmap;
// Shadows are base_color * shadow_color * shadow_brightness, so they stay colored, not grey.
uniform vec4 shadow_color : source_color = vec4(0.42, 0.33, 0.66, 1.0);
uniform float shadow_brightness : hint_range(0.0, 1.0) = 0.35;

group_uniforms Bands;
// Where the light/shadow edge sits (N·L × attenuation). Lower = more of the object lit.
uniform float shadow_threshold : hint_range(-1.0, 1.0) = 0.15;
uniform float band_softness : hint_range(0.0, 0.2) = 0.02;

group_uniforms Halftone;
// Comic dots that fade light into the shadow side. Strength 0 turns them off.
uniform float halftone_strength : hint_range(0.0, 1.0) = 1.0;
uniform float halftone_dot_size : hint_range(2.0, 32.0) = 7.0;   // pixels per dot cell
uniform float halftone_range : hint_range(0.0, 1.0) = 0.35;      // how far dots reach into shadow
uniform float halftone_angle : hint_range(0.0, 3.1416) = 0.785;

group_uniforms Highlight;
uniform float highlight_strength : hint_range(0.0, 2.0) = 0.35;
uniform float highlight_size : hint_range(0.0, 1.0) = 0.93;

group_uniforms Rim;
uniform vec4 rim_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float rim_strength : hint_range(0.0, 2.0) = 0.25;
uniform float rim_width : hint_range(0.0, 1.0) = 0.3;

group_uniforms;

void fragment() {
	vec3 col = base_color.rgb * texture(albedo_texture, UV).rgb;
	ALBEDO = col;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;

	// Colored shadow floor: what the unlit side looks like with no light at all.
	vec3 shade = col * shadow_color.rgb * shadow_brightness;

	// Rim: a hard band around the silhouette, independent of lights.
	float facing = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float rim = smoothstep(1.0 - rim_width, 1.0 - rim_width + 0.02, facing);

	EMISSION = shade + rim_color.rgb * rim * rim_strength * col;
}

// 1 inside a screen-space halftone dot whose radius grows with `amount` (0..1).
float halftone(vec2 frag, float amount) {
	float s = sin(halftone_angle), c = cos(halftone_angle);
	vec2 p = mat2(vec2(c, -s), vec2(s, c)) * frag / halftone_dot_size;
	float d = length(fract(p) - 0.5);
	return step(d, amount * 0.72);
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	float l = ndl * ATTENUATION;   // includes shadows and omni/spot falloff

	// Hard cel band.
	float lit = smoothstep(shadow_threshold - band_softness, shadow_threshold + band_softness, l);

	// Halftone: dots of light that shrink as you move deeper into shadow.
	float t = smoothstep(shadow_threshold - halftone_range, shadow_threshold, l);
	float dots = halftone(FRAGCOORD.xy, t) * halftone_strength * step(0.001, ATTENUATION);
	lit = max(lit, dots * (1.0 - lit));

	DIFFUSE_LIGHT += lit * LIGHT_COLOR / PI;

	// Stepped specular highlight.
	vec3 h = normalize(VIEW + LIGHT);
	float spec = step(highlight_size, dot(NORMAL, h)) * step(0.5, lit);
	SPECULAR_LIGHT += spec * highlight_strength * LIGHT_COLOR / PI;
}
