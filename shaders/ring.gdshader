// Onde de choc : anneau qui s'étend et s'efface.
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec4 color : source_color = vec4(1.0, 0.8, 0.3, 1.0);
uniform float progress = 0.0;
uniform float thickness = 0.08;

void fragment() {
	float d = length(UV - 0.5) * 2.0;
	float r = 1.0 - pow(1.0 - progress, 3.0);
	float band = smoothstep(r - thickness, r, d) * (1.0 - smoothstep(r, r + thickness * 0.4, d));
	ALBEDO = color.rgb * 2.0;
	ALPHA = band * (1.0 - progress);
}
