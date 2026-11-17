class_name SlashTrail
extends MeshInstance3D
## Traînée lumineuse derrière la lame pendant les frames actives.

const LIFE := 0.13

var tint: Color = Color(1.0, 0.95, 0.85)
var _im: ImmediateMesh
var _mat: StandardMaterial3D
var _pts: Array = []   ## [[base, pointe, âge], ...]


func setup() -> void:
	_im = ImmediateMesh.new()
	mesh = _im
	_mat = StandardMaterial3D.new()
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.vertex_color_use_as_albedo = true
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func add_point(base: Vector3, tip: Vector3) -> void:
	_pts.append([base, tip, 0.0])


## frozen = pendant le hitstop, la traînée reste figée (effet "arrêt sur image").
func tick(delta: float, frozen: bool) -> void:
	if not frozen:
		for p in _pts:
			p[2] += delta
		while not _pts.is_empty() and float(_pts[0][2]) > LIFE:
			_pts.pop_front()
	_im.clear_surfaces()
	if _pts.size() < 2:
		return
	_im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP, _mat)
	for p in _pts:
		var a := 1.0 - float(p[2]) / LIFE
		_im.surface_set_color(Color(tint.r, tint.g, tint.b, 0.0))
		_im.surface_add_vertex(p[0])
		_im.surface_set_color(Color(tint.r, tint.g, tint.b, a * 0.9))
		_im.surface_add_vertex(p[1])
	_im.surface_end()
