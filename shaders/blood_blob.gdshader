// Tache de sang à l'écran (Chiburi) : forme organique + petites gouttes.
shader_type canvas_item;

uniform vec4 blob_color : source_color = vec4(0.45, 0.0, 0.02, 0.9);
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
	float r = length(p);
	float a = atan(p.y, p.x);
	float edge = 0.55 + noise(vec2(a * 2.0, seed)) * 0.35 + noise(UV * 10.0) * 0.12;
	float drops = step(0.93, noise(UV * 22.0 + seed)) * step(r, 0.98);
	float m = max(step(r, edge), drops);
	if (m < 0.5) {
		discard;
	}
	COLOR = vec4(blob_color.rgb * (0.8 + 0.4 * noise(UV * 30.0)), blob_color.a);
}
