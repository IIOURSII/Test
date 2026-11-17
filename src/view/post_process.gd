class_name PostProcess
extends CanvasLayer
## Filtre plein écran appliqué à la 3D (le HUD, au-dessus, reste net) :
## style rétro (F7) + effets d'impact (impact frames, aberration, zoom blur, lignes de vitesse).

var rect: ColorRect
var mat: ShaderMaterial
var retro: bool = true

var _impact: float = 0.0
var _impact_hold: float = 0.0
var _aberration: float = 0.0
var _zoom: float = 0.0
var _lines: float = 0.0
var _lines_hold: float = 0.0


func setup(gfx: Dictionary) -> void:
	layer = -1
	rect = ColorRect.new()
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mat = ShaderMaterial.new()
	mat.shader = load("res://shaders/pixel_post.gdshader")
	rect.material = mat
	add_child(rect)
	apply(gfx)


func apply(gfx: Dictionary) -> void:
	retro = bool(gfx.get("enabled", true))
	mat.set_shader_parameter("pixel_size", maxf(float(gfx.get("pixel_size", 4)), 1.0))
	mat.set_shader_parameter("color_levels", float(gfx.get("color_levels", 7)))
	mat.set_shader_parameter("dither_strength", float(gfx.get("dither", 1.0)))
	mat.set_shader_parameter("vignette", float(gfx.get("vignette", 0.6)))
	mat.set_shader_parameter("grain", float(gfx.get("grain", 0.05)))
	mat.set_shader_parameter("saturation", float(gfx.get("saturation", 0.75)))
	mat.set_shader_parameter("contrast", float(gfx.get("contrast", 1.1)))
	mat.set_shader_parameter("brightness", float(gfx.get("brightness", 1.0)))
	mat.set_shader_parameter("tint", _color(gfx.get("tint", [1, 1, 1])))
	mat.set_shader_parameter("shadow_tint", _color(gfx.get("shadow_tint", [0, 0, 0])))
	_refresh()


func toggle() -> void:
	retro = not retro
	_refresh()


func _refresh() -> void:
	mat.set_shader_parameter("retro", 1.0 if retro else 0.0)
	# La 3D est calculée en plus basse résolution en mode rétro (plus rapide, même rendu).
	var vp := get_viewport()
	if vp:
		vp.scaling_3d_scale = 0.5 if retro else 1.0


# ------------------------------------------------------------ effets d'impact

## Impact frame : l'image passe en 2 tons pendant `hold` secondes puis revient.
func impact_frame(color: Color, invert: bool, hold: float = 0.06) -> void:
	_impact = 1.0
	_impact_hold = hold
	mat.set_shader_parameter("impact_color", Vector3(color.r, color.g, color.b))
	mat.set_shader_parameter("impact_invert", 1.0 if invert else 0.0)


func punch(aberration: float, zoom: float) -> void:
	_aberration = maxf(_aberration, aberration)
	_zoom = maxf(_zoom, zoom)


func speed_lines(amount: float, hold: float, color: Color = Color.WHITE) -> void:
	_lines = maxf(_lines, amount)
	_lines_hold = maxf(_lines_hold, hold)
	mat.set_shader_parameter("lines_color", Vector3(color.r, color.g, color.b))


func _process(delta: float) -> void:
	if _impact_hold > 0.0:
		_impact_hold -= delta
	else:
		_impact = move_toward(_impact, 0.0, delta * 10.0)
	if _lines_hold > 0.0:
		_lines_hold -= delta
	else:
		_lines = move_toward(_lines, 0.0, delta * 3.0)
	_aberration = move_toward(_aberration, 0.0, delta * 3.5)
	_zoom = move_toward(_zoom, 0.0, delta * 4.0)
	mat.set_shader_parameter("impact", _impact)
	mat.set_shader_parameter("aberration", _aberration)
	mat.set_shader_parameter("zoom_blur", _zoom)
	mat.set_shader_parameter("speed_lines", _lines)


static func _color(v) -> Vector3:
	if v is Array and v.size() >= 3:
		return Vector3(float(v[0]), float(v[1]), float(v[2]))
	return Vector3.ONE
