shader_type spatial;
// Cheap 2-band cel shading + rim light. One shader for every prop/character:
// colour comes from a uniform, so no textures are needed at all.
render_mode cull_back, specular_disabled;

uniform vec4 albedo : source_color = vec4(1.0);
uniform float emission_strength = 0.0;
uniform float rim_strength = 0.25;

void fragment() {
	ALBEDO = albedo.rgb;
	ROUGHNESS = 1.0;
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	EMISSION = albedo.rgb * (emission_strength + rim * rim_strength);
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	// Hard terminator + a small highlight band; shadowed side is lit by ambient only.
	float band = smoothstep(0.0, 0.06, ndl) * 0.85 + smoothstep(0.55, 0.6, ndl) * 0.15;
	DIFFUSE_LIGHT += band * ATTENUATION * LIGHT_COLOR / PI;
}
