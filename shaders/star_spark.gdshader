// Étincelle d'impact "étoile" façon anime : pointes irrégulières, cœur blanc, bords nets.
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec4 color : source_color = vec4(1.0, 0.8, 0.5, 1.0);
uniform float progress = 0.0;
uniform float seed = 0.0;
uniform float spikes = 4.0;

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float a = atan(p.y, p.x);
	float s1 = pow(abs(sin(a * spikes + seed)), 10.0);
	float s2 = pow(abs(sin(a * (spikes + 1.0) + seed * 2.3)), 14.0) * 0.6;
	float grow = 0.35 + 0.65 * min(progress * 5.0, 1.0);
	float radius = mix(0.12, 1.0, max(s1, s2)) * grow * (1.0 - progress * 0.3);
	if (r > radius) {
		discard;
	}
	float core = step(r, 0.18 * (1.0 - progress));
	ALBEDO = mix(color.rgb * 1.6, vec3(2.5), core);
	ALPHA = 1.0 - progress;
}
