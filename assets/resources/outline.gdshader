shader_type spatial;
render_mode cull_front; // flip culling so we see the "expanded backfaces"

#include "res://assets/resources/shaders/world_curve.gdshaderinc"

uniform vec4 outline_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float outline_thickness : hint_range(0.0, 0.1) = 0.03;

void vertex() {
    // Push vertices outward along normals
    VERTEX += NORMAL * outline_thickness;
    // Bend AFTER the outline offset, so this pass and the coloured next_pass agree on where
    // the geometry ends up and the silhouette stays glued to the body.
    POSITION = curve_position(VERTEX, MODELVIEW_MATRIX, PROJECTION_MATRIX);
}

void fragment() {
    ALBEDO = outline_color.rgb;
    ALPHA = outline_color.a;
}

