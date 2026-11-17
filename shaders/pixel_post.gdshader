// Post-process plein écran :
// 1) style "rétro pixelisé" (gros pixels, palette tramée, vignette, grain) - activable avec F7
// 2) effets d'impact façon anime : impact frames bicolores, aberration chromatique,
//    zoom blur, lignes de vitesse. Pilotés par src/view/post_process.gd.
shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform float retro = 1.0;
uniform float pixel_size = 4.0;
uniform float color_levels = 7.0;
uniform float dither_strength = 1.0;
uniform float vignette = 0.6;
uniform float grain = 0.05;
uniform float saturation = 0.75;
uniform float contrast = 1.12;
uniform float brightness = 1.0;
uniform vec3 tint = vec3(1.0, 0.92, 0.82);
uniform vec3 shadow_tint = vec3(0.05, 0.04, 0.07);
uniform vec3 split_shadow = vec3(0.5);
uniform vec3 split_highlight = vec3(0.5);
uniform float split_amount = 0.0;
uniform float use_palette = 0.0;
uniform sampler2D palette_tex : filter_nearest;
uniform int palette_size = 0;

uniform float impact = 0.0;
uniform vec3 impact_color = vec3(1.0);
uniform float impact_invert = 0.0;
uniform float aberration = 0.0;
uniform float zoom_blur = 0.0;
uniform float speed_lines = 0.0;
uniform vec3 lines_color = vec3(1.0);

const float BAYER[16] = float[16](
	0.0, 8.0, 2.0, 10.0,
	12.0, 4.0, 14.0, 6.0,
	3.0, 11.0, 1.0, 9.0,
	15.0, 7.0, 13.0, 5.0);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 screen_size = 1.0 / SCREEN_PIXEL_SIZE;
	float ps = retro > 0.5 ? max(pixel_size, 1.0) : 1.0;
	vec2 px = SCREEN_UV * screen_size;
	vec2 cell = floor(px / ps);
	vec2 uv = (cell + 0.5) * ps / screen_size;

	// Zoom blur + aberration chromatique (vers le centre de l'écran).
	vec2 dir = uv - vec2(0.5);
	vec3 c = vec3(0.0);
	const int N = 6;
	for (int i = 0; i <= N; i++) {
		float k = 1.0 - zoom_blur * 0.035 * float(i);
		vec2 suv = vec2(0.5) + dir * k;
		vec2 ab = dir * aberration * 0.025;
		c.r += texture(screen_tex, suv + ab).r;
		c.g += texture(screen_tex, suv).g;
		c.b += texture(screen_tex, suv - ab).b;
	}
	c /= float(N + 1);

	// Étalonnage
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(vec3(l), c, saturation);
	c = (c - 0.5) * contrast + 0.5;
	c *= tint * brightness;
	c = max(c, shadow_tint * (1.0 - l));
	// Virage partiel : ombres froides, lumières chaudes (le clair-obscur de Dead Cells).
	c += (split_shadow - 0.5) * (1.0 - l) * split_amount + (split_highlight - 0.5) * l * split_amount;

	// Lignes de vitesse radiales (style manga).
	if (speed_lines > 0.001) {
		vec2 d = uv - vec2(0.5);
		d.x *= screen_size.x / screen_size.y;
		float ang = atan(d.y, d.x);
		float bin = floor((ang + 3.14159) / 6.28318 * 140.0);
		float rnd = hash(vec2(bin, floor(TIME * 24.0)));
		float r = length(d);
		float start = 0.18 + rnd * 0.3;
		float line_mask = step(0.62, rnd) * smoothstep(start, start + 0.15, r);
		c = mix(c, lines_color, line_mask * speed_lines);
	}

	// Impact frame : image réduite à 2 tons (silhouettes), éventuellement inversée.
	float L = dot(c, vec3(0.299, 0.587, 0.114));
	float t = step(0.3, L);
	t = mix(t, 1.0 - t, impact_invert);
	vec3 ic = mix(vec3(0.02), impact_color, t);
	c = mix(c, ic, impact);

	// Vignette
	vec2 vd = uv - 0.5;
	c *= clamp(1.0 - vignette * dot(vd, vd) * 2.2 * (1.0 - impact), 0.0, 1.0);

	if (retro > 0.5) {
		float n = hash(cell + floor(TIME * 12.0) * vec2(17.0, 31.0));
		c += (n - 0.5) * grain;
		int bx = int(mod(cell.x, 4.0));
		int by = int(mod(cell.y, 4.0));
		float bay = BAYER[by * 4 + bx] / 16.0;
		if (use_palette > 0.5 && palette_size > 1) {
			// Palette fixe : on prend les 2 couleurs les plus proches et on trame entre elles.
			c = clamp(c, 0.0, 1.0);
			float d1 = 1e9;
			float d2 = 1e9;
			vec3 p1 = c;
			vec3 p2 = c;
			for (int i = 0; i < 64; i++) {
				if (i >= palette_size) { break; }
				vec3 pc = texelFetch(palette_tex, ivec2(i, 0), 0).rgb;
				vec3 df = c - pc;
				float d = dot(df * df, vec3(0.30, 0.59, 0.11));
				if (d < d1) { d2 = d1; p2 = p1; d1 = d; p1 = pc; }
				else if (d < d2) { d2 = d; p2 = pc; }
			}
			float s1 = sqrt(d1);
			float s2 = sqrt(d2);
			float t = s1 / (s1 + s2 + 1e-5);
			c = (bay < t * dither_strength) ? p2 : p1;
		} else {
			float lv = max(color_levels - 1.0, 1.0);
			c = floor(c * lv + 0.5 + (bay - 0.5) * dither_strength) / lv;
		}
	}

	COLOR = vec4(clamp(c, 0.0, 1.0), 1.0);
}
