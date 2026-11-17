// Contour à l'encre sur toute l'image 3D (silhouettes + arêtes), à partir de la profondeur
// et des normales. C'est ce qui donne le look "dessin imprimé" à toute la scène.
// Nécessite le moteur de rendu Forward+ (réglage par défaut du projet).
shader_type spatial;
render_mode unshaded, depth_draw_never, depth_test_disabled, cull_disabled, blend_mix, fog_disabled, shadows_disabled;

uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
uniform sampler2D normal_tex : hint_normal_roughness_texture, filter_nearest;
uniform vec4 ink_color : source_color = vec4(0.05, 0.03, 0.045, 1.0);
uniform float thickness = 1.0;
uniform float depth_threshold = 0.06;
uniform float normal_threshold = 0.55;
uniform float fade_start = 25.0;
uniform float fade_end = 60.0;

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

float lin_depth(vec2 uv, mat4 inv_proj) {
	float d = texture(depth_tex, uv).r;
	vec4 v = inv_proj * vec4(uv * 2.0 - 1.0, d, 1.0);
	return min(-v.z / max(abs(v.w), 1e-6), 10000.0);
}

vec3 nrm(vec2 uv) {
	return normalize(texture(normal_tex, uv).xyz * 2.0 - 1.0);
}

void fragment() {
	vec2 px = thickness / VIEWPORT_SIZE;
	float c = lin_depth(SCREEN_UV, INV_PROJECTION_MATRIX);
	float dl = lin_depth(SCREEN_UV - vec2(px.x, 0.0), INV_PROJECTION_MATRIX);
	float dr = lin_depth(SCREEN_UV + vec2(px.x, 0.0), INV_PROJECTION_MATRIX);
	float du = lin_depth(SCREEN_UV - vec2(0.0, px.y), INV_PROJECTION_MATRIX);
	float dd = lin_depth(SCREEN_UV + vec2(0.0, px.y), INV_PROJECTION_MATRIX);
	// Seulement les voisins PLUS LOIN : le trait se pose sur le bord de l'objet proche.
	float diff = max(max(dl - c, dr - c), max(du - c, dd - c));
	float depth_edge = step(depth_threshold * c + 0.02, diff);

	vec3 n = nrm(SCREEN_UV);
	float nd = max(max(1.0 - dot(n, nrm(SCREEN_UV - vec2(px.x, 0.0))), 1.0 - dot(n, nrm(SCREEN_UV + vec2(px.x, 0.0)))),
			max(1.0 - dot(n, nrm(SCREEN_UV - vec2(0.0, px.y))), 1.0 - dot(n, nrm(SCREEN_UV + vec2(0.0, px.y)))));
	float normal_edge = step(normal_threshold, nd);

	float e = max(depth_edge, normal_edge);
	if (c > 9000.0) {
		e = 0.0;   // ciel
	}
	e *= 1.0 - smoothstep(fade_start, fade_end, c);
	ALBEDO = ink_color.rgb;
	ALPHA = e * ink_color.a;
}
