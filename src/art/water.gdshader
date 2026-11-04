shader_type spatial;
// Faceted toon water: vertex waves on a coarse grid + flat shading, a gloss
// band, and a pale rim where it meets the shore (by distance from origin of
// each island is overkill; a cheap fresnel tint does the job).
render_mode cull_disabled;

global uniform vec4 sky_ambient : source_color;

uniform vec4 shallow : source_color = vec4(0.3, 0.8, 0.95, 1.0);
uniform vec4 deep : source_color = vec4(0.12, 0.5, 0.85, 1.0);
uniform float wave = 0.25;

void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	VERTEX.y += sin(w.x * 0.35 + TIME * 1.3) * wave + cos(w.z * 0.29 + TIME * 1.1) * wave;
}

void fragment() {
	vec3 fn = normalize(cross(dFdx(VERTEX), dFdy(VERTEX)));
	NORMAL = dot(fn, NORMAL) < 0.0 ? -fn : fn;
	float f = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.0);
	vec3 col = mix(deep.rgb, shallow.rgb, f);
	ALBEDO = col;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	EMISSION = col * sky_ambient.rgb * 0.6;
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	DIFFUSE_LIGHT += (smoothstep(0.0, 0.1, ndl) * 0.7 + 0.3) * ATTENUATION * LIGHT_COLOR / PI;
	vec3 h = normalize(LIGHT + VIEW);
	SPECULAR_LIGHT += smoothstep(0.96, 0.975, dot(NORMAL, h)) * ATTENUATION * LIGHT_COLOR * 0.5;
}
