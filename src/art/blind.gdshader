shader_type canvas_item;
// Giant's vision: each blinded eye darkens that half of the screen.
// Both eyes gone = tunnel vision.

uniform float left_blind = 0.0;
uniform float right_blind = 0.0;

void fragment() {
	float l = left_blind * smoothstep(0.62, 0.38, UV.x);
	float r = right_blind * smoothstep(0.38, 0.62, UV.x);
	float a = max(l, r);
	float d = distance(UV, vec2(0.5));
	a = mix(a, smoothstep(0.06, 0.28, d) * 0.97, left_blind * right_blind);
	COLOR = vec4(0.06, 0.0, 0.03, a);
}
