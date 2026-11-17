// Sceau rouge (hanko) à bords irréguliers, avec cadre intérieur et manques d'encre.
shader_type canvas_item;

uniform vec4 seal_color : source_color = vec4(0.8, 0.06, 0.08, 1.0);
uniform float seed = 0.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233)) + seed) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float d = max(abs(p.x), abs(p.y));
	float n = noise(UV * 14.0) * 0.09 + noise(UV * 45.0) * 0.05;
	if (d > 0.93 - n) {
		discard;
	}
	float frame = smoothstep(0.76, 0.78, d + n * 0.3) * (1.0 - smoothstep(0.81, 0.83, d + n * 0.3));
	float holes = step(0.86, noise(UV * 32.0 + 7.0));
	float a = 1.0 - frame * 0.85 - holes * 0.55;
	COLOR = vec4(seal_color.rgb, seal_color.a * a);
}
