shader_type spatial;
// The one shader for every prop, character and the terrain.
//  * Faceted: normals are rebuilt per-triangle from screen derivatives, so any
//    low-segment primitive reads as chunky low-poly (no normal maps needed: the
//    facets ARE the surface detail).
//  * 2-band cel diffuse from the sun, hemispheric ambient (sky blue from above,
//    warm ground bounce from below) driven by global uniforms per world.
//  * Optional gloss band for metal / ice / crystal; vertex colours for terrain
//    (which carry baked per-face tint + ambient occlusion).
render_mode cull_back;

global uniform vec4 sky_ambient : source_color;
global uniform vec4 ground_ambient : source_color;

uniform vec4 albedo : source_color = vec4(1.0);
uniform float emission_strength = 0.0;
uniform float rim_strength = 0.12;
uniform float gloss = 0.0;
uniform bool use_vertex_color = false;
uniform bool faceted = true;

varying vec3 vcol;

void vertex() {
	vcol = use_vertex_color ? COLOR.rgb : vec3(1.0);
}

void fragment() {
	vec3 n = NORMAL;
	if (faceted) {
		vec3 fn = normalize(cross(dFdx(VERTEX), dFdy(VERTEX)));
		n = dot(fn, NORMAL) < 0.0 ? -fn : fn;
	}
	NORMAL = n;
	vec3 col = albedo.rgb * vcol;
	ALBEDO = col;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	vec3 wn = (INV_VIEW_MATRIX * vec4(n, 0.0)).xyz;
	vec3 amb = mix(ground_ambient.rgb, sky_ambient.rgb, clamp(wn.y * 0.5 + 0.5, 0.0, 1.0));
	float rim = pow(1.0 - clamp(dot(n, VIEW), 0.0, 1.0), 3.0);
	EMISSION = col * (amb + emission_strength + rim * rim_strength);
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	float band = smoothstep(0.0, 0.05, ndl) * 0.78 + smoothstep(0.45, 0.5, ndl) * 0.22;
	DIFFUSE_LIGHT += band * ATTENUATION * LIGHT_COLOR / PI;
	if (gloss > 0.0) {
		vec3 h = normalize(LIGHT + VIEW);
		float s = smoothstep(0.93, 0.95, dot(NORMAL, h)) * gloss;
		SPECULAR_LIGHT += s * ATTENUATION * LIGHT_COLOR * 0.4;
	}
}
