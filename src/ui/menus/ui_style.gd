class_name UiStyle
extends RefCounted
## Identité visuelle des écrans — FUSION JAPON / ALLEMAGNE MÉDIÉVALE :
## écriture gothique (Grenze Gotisch, licence OFL) + kanji, blasons, encre, papier, rouge sceau, or.

const INK := Color(0.045, 0.035, 0.04)
const PAPER := Color(0.95, 0.91, 0.83)
const CRIMSON := Color(0.8, 0.09, 0.1)
const GOLD := Color(0.93, 0.76, 0.36)
const MUTED := Color(0.55, 0.51, 0.47)

static var _cjk: SystemFont
static var _serif: SystemFont
static var _hanko: Shader
static var _gothic: Font


static func cjk() -> Font:
	if _cjk == null:
		_cjk = SystemFont.new()
		_cjk.font_names = PackedStringArray(["Yu Mincho", "MS Mincho", "Noto Serif CJK JP", "Hiragino Mincho ProN",
				"Noto Sans CJK JP", "Yu Gothic", "MS Gothic", "Hiragino Sans"])
		_cjk.font_weight = 700
	return _cjk


static func serif() -> Font:
	if _serif == null:
		_serif = SystemFont.new()
		_serif.font_names = PackedStringArray(["Georgia", "Palatino Linotype", "Book Antiqua", "Times New Roman",
				"Noto Serif", "DejaVu Serif", "serif"])
		_serif.font_weight = 600
	return _serif


## Écriture gothique (Fraktur) pour les titres et menus.
static func gothic() -> Font:
	if _gothic == null:
		var base = load("res://assets/fonts/GrenzeGotisch.ttf")
		if base is Font:
			var fv := FontVariation.new()
			fv.base_font = base
			fv.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 640}
			_gothic = fv
		else:
			_gothic = serif()
	return _gothic


## Blason allemand portant un kanji.
static func shield(kanji: String, size: float, a: Color = Color(0.08, 0.07, 0.08), b: Color = Color(0.72, 0.1, 0.1)) -> Control:
	return ShieldEmblem.new().setup(kanji, size, a, b)


## "DUEL" -> "D U E L"
static func spaced(text: String) -> String:
	var out := ""
	for c in text:
		out += c + " "
	return out.strip_edges()


static func label(text: String, size: int, color: Color = PAPER, font: Font = null, outline: int = 0) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font if font else serif())
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if outline > 0:
		l.add_theme_constant_override("outline_size", outline)
		l.add_theme_color_override("font_outline_color", INK)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## Sceau rouge avec un kanji (même rendu que les popups en jeu).
static func seal(kanji: String, size: float, color: Color = CRIMSON) -> Control:
	if _hanko == null:
		_hanko = load("res://shaders/hanko.gdshader")
	var root := Control.new()
	root.custom_minimum_size = Vector2(size, size)
	root.size = Vector2(size, size)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var r := ColorRect.new()
	var m := ShaderMaterial.new()
	m.shader = _hanko
	m.set_shader_parameter("seal_color", color)
	m.set_shader_parameter("seed", float(kanji.hash() % 97))
	r.material = m
	r.size = Vector2(size, size)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(r)
	var k := label(kanji, int(size * (0.68 if kanji.length() <= 1 else 0.4)), PAPER, cjk())
	k.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	k.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	k.size = Vector2(size, size)
	root.add_child(k)
	return root


static func box_style(bg: Color, border: Color = Color(0, 0, 0, 0), width: int = 0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(width)
	s.set_content_margin_all(14)
	return s


## Bouton de menu : écriture gothique, losange rouge au survol, version "verrouillée".
static func menu_button(text: String, hint: String = "", locked: bool = false, font_size: int = 30) -> Button:
	var b := Button.new()
	b.text = text
	b.flat = true
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font", gothic())
	b.add_theme_font_size_override("font_size", int(font_size * 1.15))
	b.add_theme_color_override("font_color", MUTED if locked else PAPER)
	b.add_theme_color_override("font_hover_color", MUTED if locked else Color(1.0, 0.82, 0.75))
	b.add_theme_color_override("font_pressed_color", CRIMSON)
	b.add_theme_color_override("font_disabled_color", MUTED.darkened(0.2))
	b.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	b.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	b.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	b.add_theme_stylebox_override("disabled", StyleBoxEmpty.new())
	b.custom_minimum_size = Vector2(420, font_size + 22)
	b.disabled = locked
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var marker := ColorRect.new()
	marker.color = CRIMSON
	marker.size = Vector2(10, 10)
	marker.rotation = PI / 4.0
	marker.position = Vector2(-26, (font_size + 22) * 0.5 - 7)
	marker.visible = false
	marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(marker)
	if hint != "":
		var h := label(spaced(hint.to_upper()), 13, CRIMSON.lightened(0.2) if locked else MUTED)
		h.position = Vector2(4, font_size + 12)
		b.add_child(h)
		b.custom_minimum_size.y += 14
	b.mouse_entered.connect(func() -> void:
		marker.visible = not b.disabled
		if not b.disabled:
			var tw := b.create_tween()
			tw.tween_property(b, "position:x", 12.0, 0.08))
	b.mouse_exited.connect(func() -> void:
		marker.visible = false
		var tw := b.create_tween()
		tw.tween_property(b, "position:x", 0.0, 0.1))
	return b


## Dégradé sombre (pour faire ressortir le texte devant le décor qui tourne).
static func side_shade(width_ratio: float = 0.55, alpha: float = 0.9) -> TextureRect:
	var g := Gradient.new()
	g.colors = PackedColorArray([Color(INK, alpha), Color(INK, alpha * 0.6), Color(INK, 0.0)])
	g.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(1, 0)
	gt.width = 256
	gt.height = 4
	var tr := TextureRect.new()
	tr.texture = gt
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	tr.anchor_right = width_ratio
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tr


static func full_shade(alpha: float) -> ColorRect:
	var r := ColorRect.new()
	r.color = Color(INK, alpha)
	r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r
