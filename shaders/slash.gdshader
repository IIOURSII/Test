// Coupe en croissant, rendu "cel" : cœur blanc, liseré de couleur, contour encre.
// Bandes nettes (pas de dégradé mou) = lecture claire et look anime, même pixelisé.
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec4 core_color : source_color = vec4(1.0);
uniform vec4 edge_color : source_color = vec4(0.85, 0.06, 0.12, 1.0);
uniform vec4 ink_color : source_color = vec4(0.03, 0.0, 0.02, 1.0);
uniform float progress = 0.0;

void fragment() {
	float along = UV.x;
	float head = clamp(progress * 7.0, 0.0, 1.0);          // se dessine en ~1/7 de la durée
	float tail = clamp((progress - 0.25) * 1.4, 0.0, 1.0); // puis s'efface par l'arrière
	if (along > head || along < tail) {
		discard;
	}
	float span = max(head - tail, 0.001);
	float local = clamp((along - tail) / span, 0.0, 1.0);
	float taper = pow(sin(local * 3.14159), 0.6);        // pointes effilées
	float w = taper * (1.0 - progress * 0.45);
	float across = abs(UV.y - 0.5) * 2.0;
	if (across > w) {
		discard;
	}
	float x = across / max(w, 0.001);
	vec3 col = core_color.rgb * 2.2;
	if (x > 0.38) { col = edge_color.rgb * 1.3; }
	if (x > 0.78) { col = ink_color.rgb; }
	ALBEDO = col;
	ALPHA = 1.0 - smoothstep(0.7, 1.0, progress);
}
