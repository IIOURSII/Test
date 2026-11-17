class_name InkOutline
extends RefCounted
## Crée le "quad" plein écran qui dessine les contours à l'encre (un par monde 3D suffit).


static func create(thickness: float = 1.0, fade_end: float = 60.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(2, 2)
	mi.mesh = q
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/ink_outline.gdshader")
	m.set_shader_parameter("thickness", thickness)
	m.set_shader_parameter("fade_end", fade_end)
	m.set_shader_parameter("fade_start", fade_end * 0.45)
	mi.material_override = m
	mi.extra_cull_margin = 16384.0
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.custom_aabb = AABB(Vector3(-1e5, -1e5, -1e5), Vector3(2e5, 2e5, 2e5))
	return mi
