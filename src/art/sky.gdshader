shader_type sky;
// Clean cartoon sky: saturated gradient, hard-edged sun disc, flat puffy
// clouds. No haze band at the horizon (that's what made the old look muddy).

uniform vec4 top_color : source_color = vec4(0.25, 0.55, 0.95, 1.0);
uniform vec4 horizon_color : source_color = vec4(0.62, 0.84, 1.0, 1.0);
uniform vec4 bottom_color : source_color = vec4(0.4, 0.62, 0.85, 1.0);
uniform vec4 cloud_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 cloud_shade : source_color = vec4(0.82, 0.88, 1.0, 1.0);
uniform float cloud_cover = 0.5;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

void sky() {
	vec3 d = EYEDIR;
	vec3 c = mix(horizon_color.rgb, top_color.rgb, smoothstep(0.0, 0.55, d.y));
	c = mix(c, bottom_color.rgb, smoothstep(0.0, -0.25, d.y));
	if (LIGHT0_ENABLED) {
		float sd = dot(d, LIGHT0_DIRECTION);
		c = mix(c, vec3(1.0, 0.97, 0.85), smoothstep(0.9975, 0.998, sd));
		c += vec3(1.0, 0.9, 0.7) * smoothstep(0.97, 1.0, sd) * 0.12;
	}
	if (d.y > 0.0) {
		vec2 p = d.xz / (d.y + 0.12) * 1.4 + vec2(TIME * 0.01, 0.0);
		float n = noise(p) * 0.6 + noise(p * 2.3) * 0.3 + noise(p * 5.1) * 0.1;
		float m = smoothstep(1.0 - cloud_cover, 1.04 - cloud_cover, n) * smoothstep(0.0, 0.12, d.y);
		float shade = smoothstep(1.0 - cloud_cover, 1.25 - cloud_cover, noise(p + vec2(0.05, 0.08)) * 0.6 + noise(p * 2.3) * 0.3);
		c = mix(c, mix(cloud_shade.rgb, cloud_color.rgb, shade), m);
	}
	COLOR = c;
}
