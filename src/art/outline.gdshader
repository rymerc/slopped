shader_type spatial;
// Inverted-hull outline used as next_pass. Pushes vertices away from the mesh
// centre (not along normals) so hard-edged boxes don't crack at the corners.
render_mode unshaded, cull_front, shadows_disabled;

uniform vec4 color : source_color = vec4(0.09, 0.06, 0.12, 1.0);
uniform float width = 0.03;

void vertex() {
	if (length(VERTEX) > 0.0001) {
		VERTEX += normalize(VERTEX) * width;
	}
}

void fragment() {
	ALBEDO = color.rgb;
}
