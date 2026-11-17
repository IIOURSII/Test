// Post-process "rétro pixelisé" (inspiration Inscryption) :
// gros pixels, palette réduite avec tramage (dithering), étalonnage chaud/désaturé,
// vignette sombre et grain de film. Réglages dans data/config/graphics.json.
shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
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

const float BAYER[16] = float[16](
	0.0, 8.0, 2.0, 10.0,
	12.0, 4.0, 14.0, 6.0,
	3.0, 11.0, 1.0, 9.0,
	15.0, 7.0, 13.0, 5.0);

void fragment() {
	vec2 screen_size = 1.0 / SCREEN_PIXEL_SIZE;
	vec2 px = SCREEN_UV * screen_size;
	vec2 cell = floor(px / pixel_size);
	vec2 uv = (cell + 0.5) * pixel_size / screen_size;
	vec3 c = texture(screen_tex, uv).rgb;

	// Étalonnage
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(vec3(l), c, saturation);
	c = (c - 0.5) * contrast + 0.5;
	c *= tint * brightness;
	c = max(c, shadow_tint * (1.0 - l));

	// Vignette
	vec2 d = (cell + 0.5) * pixel_size / screen_size - 0.5;
	c *= clamp(1.0 - vignette * dot(d, d) * 2.2, 0.0, 1.0);

	// Grain (par gros pixel, animé)
	float n = fract(sin(dot(cell + floor(TIME * 12.0) * vec2(17.0, 31.0), vec2(12.9898, 78.233))) * 43758.5453);
	c += (n - 0.5) * grain;

	// Tramage + palette réduite
	int bx = int(mod(cell.x, 4.0));
	int by = int(mod(cell.y, 4.0));
	float b = BAYER[by * 4 + bx] / 16.0 - 0.5;
	float lv = max(color_levels - 1.0, 1.0);
	c = floor(c * lv + 0.5 + b * dither_strength) / lv;

	COLOR = vec4(clamp(c, 0.0, 1.0), 1.0);
}
