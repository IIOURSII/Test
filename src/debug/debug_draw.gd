class_name DebugDraw
extends MeshInstance3D
## Affiche les hurtbox (vert) et hitbox actives (rouge) en fil de fer, à travers les murs.

const SEGMENTS := 16

var _im: ImmediateMesh
var _mat: StandardMaterial3D


func setup() -> void:
	_im = ImmediateMesh.new()
	mesh = _im
	_mat = StandardMaterial3D.new()
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.vertex_color_use_as_albedo = true
	_mat.no_depth_test = true
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func redraw(world: SimWorld, enabled: bool) -> void:
	_im.clear_surfaces()
	visible = enabled
	if not enabled:
		return
	_im.surface_begin(Mesh.PRIMITIVE_LINES, _mat)
	for i in world.fighters.size():
		var f := world.fighters[i]
		var invuln := FighterLogic.is_invulnerable(f, world.movesets[i])
		var col := Color(0.6, 0.6, 1.0, 0.9) if invuln else Color(0.2, 1.0, 0.3, 0.8)
		_capsule(Combat.hurtbox(f, world.cfg), col)
		for pair in world.active_hitboxes(i):
			_capsule(pair[0], Color(1.0, 0.15, 0.1, 1.0))
	_im.surface_end()


func _capsule(c: Array, col: Color) -> void:
	var a: Vector3 = c[0]
	var b: Vector3 = c[1]
	var r: float = c[2]
	var axis := b - a
	var ax := axis.normalized() if axis.length() > 0.001 else Vector3.UP
	var u := ax.cross(Vector3.RIGHT if absf(ax.dot(Vector3.RIGHT)) < 0.9 else Vector3.FORWARD).normalized()
	var v := ax.cross(u).normalized()
	for center in [a, b, a - ax * r * 0.7, b + ax * r * 0.7]:
		var rr := r if (center == a or center == b) else r * 0.7
		for k in SEGMENTS:
			var t0 := TAU * k / SEGMENTS
			var t1 := TAU * (k + 1) / SEGMENTS
			_line(center + (u * cos(t0) + v * sin(t0)) * rr, center + (u * cos(t1) + v * sin(t1)) * rr, col)
	for k in 4:
		var t := TAU * k / 4.0
		var off := (u * cos(t) + v * sin(t)) * r
		_line(a + off, b + off, col)


func _line(p: Vector3, q: Vector3, col: Color) -> void:
	_im.surface_set_color(col)
	_im.surface_add_vertex(p)
	_im.surface_set_color(col)
	_im.surface_add_vertex(q)
