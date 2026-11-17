class_name PostProcess
extends CanvasLayer
## Filtre plein écran appliqué à la 3D (le HUD, au-dessus, reste net).

var rect: ColorRect
var mat: ShaderMaterial
var enabled: bool = true


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
	enabled = bool(gfx.get("enabled", true))
	var ps := float(gfx.get("pixel_size", 4))
	mat.set_shader_parameter("pixel_size", maxf(ps, 1.0))
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
	enabled = not enabled
	_refresh()


func _refresh() -> void:
	visible = enabled
	# La 3D est calculée en plus basse résolution quand le filtre est actif (plus rapide, même rendu).
	var vp := get_viewport()
	if vp:
		vp.scaling_3d_scale = 0.5 if enabled else 1.0


static func _color(v) -> Vector3:
	if v is Array and v.size() >= 3:
		return Vector3(float(v[0]), float(v[1]), float(v[2]))
	return Vector3.ONE
