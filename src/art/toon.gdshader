shader_type spatial;
// The one shader for every prop, character, building and the terrain.
//  * Faceted: normals are rebuilt per-triangle from screen derivatives, so any
//    low-poly mesh reads as chunky hand-cut facets (no normal maps needed).
//  * 2-band cel diffuse from the sun, hemispheric ambient (sky tint from above,
//    warm ground bounce from below) driven by global uniforms per world.
//  * Vertex colours: rgb is linear albedo (with baked AO already multiplied in),
//    alpha is an emission mask. That lets a whole building, neon and all, be a
//    single mesh with a single material: one draw call.
//  * A faint world-space grain + height gradient keeps big flat faces painterly
//    instead of looking like untextured primitives.
render_mode cull_back;

global uniform vec4 sky_ambient : source_color;
global uniform vec4 ground_ambient : source_color;
global uniform sampler2D paint_grain : hint_default_white, repeat_enable, filter_linear_mipmap;

uniform vec4 albedo : source_color = vec4(1.0);
uniform float emission_strength = 0.0;
uniform float rim_strength = 0.12;
uniform float gloss = 0.0;
uniform float grain = 0.0;
uniform bool use_vertex_color = false;
uniform bool faceted = true;

const float GLOW_RANGE = 6.0;

varying vec4 vcol;
varying vec3 wpos;

void vertex() {
	vcol = use_vertex_color ? COLOR : vec4(1.0, 1.0, 1.0, 0.0);
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 n = NORMAL;
	if (faceted) {
		vec3 fn = normalize(cross(dFdx(VERTEX), dFdy(VERTEX)));
		n = dot(fn, NORMAL) < 0.0 ? -fn : fn;
	}
	NORMAL = n;
	vec3 wn = (INV_VIEW_MATRIX * vec4(n, 0.0)).xyz;
	vec3 col = albedo.rgb * vcol.rgb;
	if (grain > 0.0) {
		// sample along the two axes the face actually spans (cheap "triplanar")
		vec3 an = abs(wn);
		vec2 uv = an.y > 0.7 ? wpos.xz : (an.x > an.z ? wpos.zy : wpos.xy);
		float g = texture(paint_grain, uv * 0.11).r * 0.6 + texture(paint_grain, uv * 0.47).r * 0.4;
		col *= 1.0 + (g - 0.5) * grain;
	}
	ALBEDO = col;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	vec3 amb = mix(ground_ambient.rgb, sky_ambient.rgb, clamp(wn.y * 0.5 + 0.5, 0.0, 1.0));
	float rim = pow(1.0 - clamp(dot(n, VIEW), 0.0, 1.0), 3.0);
	EMISSION = col * (amb + emission_strength + vcol.a * GLOW_RANGE + rim * rim_strength);
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
