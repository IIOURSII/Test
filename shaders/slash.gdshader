// Marque de coupe façon anime : un trait lumineux qui se dessine puis s'amincit.
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec4 core_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 edge_color : source_color = vec4(1.0, 0.25, 0.1, 1.0);
uniform float progress = 0.0;   // 0 -> 1 sur la durée de vie

void fragment() {
	float along = UV.x;
	float head = clamp(progress * 5.0, 0.0, 1.0);        // le trait se dessine très vite
	float tail = clamp((progress - 0.35) * 1.6, 0.0, 1.0); // puis s'efface par l'arrière
	if (along > head || along < tail) {
		discard;
	}
	float taper = sin(along * 3.14159);
	float across = abs(UV.y - 0.5) * 2.0;
	float width = taper * (1.0 - progress * 0.7);
	float core = 1.0 - smoothstep(width * 0.18, width * 0.28 + 0.001, across);
	float glow = 1.0 - smoothstep(width * 0.3, width + 0.001, across);
	ALBEDO = core_color.rgb * core * 2.5 + edge_color.rgb * glow * 1.6;
	ALPHA = clamp(core + glow * 0.7, 0.0, 1.0);
}
