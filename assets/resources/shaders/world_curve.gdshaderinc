// Shared "curved world" bend.
//
// Every material that draws something more than a few metres from the camera includes this and
// sets POSITION from curve_position(). Bending in clip space rather than moving VERTEX keeps
// VERTEX, NORMAL and world-position reconstruction correct -- dissolve.gdshader depends on that.
//
// The offset scales with the square of view depth, so it is ~0.01 units at the player and only
// becomes visible far down the track. Gameplay, lanes and collision are untouched: this is
// purely a visual effect.
//
// NOTE: because the bend is derived from the *camera's* depth, a shadow pass would compute it
// from the light's depth instead and desync. The project's DirectionalLight3D has shadows
// disabled, so this is fine today. If shadows are ever enabled, rebase this on world Z.

// world_curve.x bends the world left/right, world_curve.y bends it up/down.
// Driven by TerrainController via RenderingServer.global_shader_parameter_set().
global uniform vec2 world_curve;

vec4 curve_position(vec3 vertex, mat4 modelview, mat4 projection) {
	vec4 view_pos = modelview * vec4(vertex, 1.0);
	// Clamp so geometry behind the camera doesn't bend the wrong way once squared.
	float depth = max(-view_pos.z, 0.0);
	view_pos.xy += world_curve * depth * depth;
	return projection * view_pos;
}
