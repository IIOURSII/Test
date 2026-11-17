class_name Fx
extends Node3D
## Effets 3D : gerbes d'étincelles, gouttes, braises, éclairs, marques de coupe, ondes de choc.

const SLASH_SHADER := preload("res://shaders/slash.gdshader")
const RING_SHADER := preload("res://shaders/ring.gdshader")

## Inclinaison de la marque de coupe selon le geste (degrés, garde droite).
const SLASH_ROLL := {
	"diag": 35.0, "diag_rev": -35.0, "horizontal": 4.0, "iai": -6.0,
	"rising": 80.0, "down": 95.0, "down_up": 85.0, "thrust": 0.0, "flick": 60.0,
}

var _spark_mesh: BoxMesh
var _spark_mat: StandardMaterial3D
var _flash_mesh: SphereMesh


func setup() -> void:
	_spark_mesh = BoxMesh.new()
	_spark_mesh.size = Vector3(0.012, 0.14, 0.012)
	_spark_mat = StandardMaterial3D.new()
	_spark_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_spark_mat.vertex_color_use_as_albedo = true
	_spark_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_spark_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_flash_mesh = SphereMesh.new()
	_flash_mesh.radius = 0.5
	_flash_mesh.height = 1.0


## kind : "blade", "pommel", "block", "parry".
func impact(pos: Vector3, dir: Vector3, power: float, kind: String) -> void:
	if kind == "blade":
		_burst(pos, dir, int(20 + 40 * power), 0.32, 5.0, 13.0 + 7.0 * power,
				[Color(1, 1, 1, 1), Color(1.0, 0.75, 0.3, 1), Color(1.0, 0.3, 0.05, 0)], 60.0, 1.0)
		_burst(pos, dir, int(6 + 12 * power), 0.55, 2.0, 5.5,
				[Color(0.75, 0.02, 0.02, 1), Color(0.45, 0.0, 0.0, 0)], 35.0, 1.8)
		embers(pos, int(8 + 14 * power), Color(1.0, 0.45, 0.1))
		_flash(pos, Color(1.0, 0.85, 0.6), 0.5 + 0.5 * power)
	elif kind == "block":
		_burst(pos, -dir, int(16 + 22 * power), 0.25, 4.0, 11.0,
				[Color(1, 1, 1, 1), Color(0.6, 0.8, 1.0, 1), Color(0.3, 0.5, 1.0, 0)], 70.0, 0.9)
		_flash(pos, Color(0.7, 0.85, 1.0), 0.35 + 0.3 * power)
	elif kind == "parry":
		_burst(pos, -dir, 90, 0.5, 6.0, 18.0,
				[Color(1, 1, 1, 1), Color(1.0, 0.85, 0.3, 1), Color(1.0, 0.5, 0.1, 0)], 120.0, 1.3)
		embers(pos, 30, Color(1.0, 0.75, 0.25))
		_flash(pos, Color(1.0, 0.85, 0.4), 1.8)
	else:
		_burst(pos, dir, int(12 + 14 * power), 0.3, 2.0, 6.0,
				[Color(1, 1, 0.9, 0.8), Color(0.7, 0.65, 0.55, 0)], 80.0, 1.4)
		_flash(pos, Color(1.0, 1.0, 0.9), 0.35 + 0.3 * power)


## Marque de coupe géante qui traverse la cible, face caméra, orientée selon le geste.
func slash_mark(pos: Vector3, anim: String, guard: int, length: float, edge: Color, life: float = 0.32) -> void:
	var roll := float(SLASH_ROLL.get(anim, 20.0)) * float(guard)
	if anim == "thrust":
		_slash_quad(pos, roll + 90.0, length * 0.45, edge, life)   # estoc = étoile en croix
	_slash_quad(pos, roll, length, edge, life)


func _slash_quad(pos: Vector3, roll_deg: float, length: float, edge: Color, life: float) -> void:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(length, length * 0.16)
	mi.mesh = q
	var m := ShaderMaterial.new()
	m.shader = SLASH_SHADER
	m.set_shader_parameter("edge_color", edge)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	mi.position = pos
	_face_camera(mi)
	mi.rotate_object_local(Vector3(0, 0, 1), deg_to_rad(roll_deg))
	var tw := mi.create_tween()
	tw.tween_method(func(v: float) -> void: m.set_shader_parameter("progress", v), 0.0, 1.0, life)
	tw.tween_callback(mi.queue_free)


## Onde de choc. flat = au sol, sinon face caméra.
func ring(pos: Vector3, color: Color, radius: float, flat: bool, life: float = 0.4, thickness: float = 0.08) -> void:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(radius * 2.0, radius * 2.0)
	mi.mesh = q
	var m := ShaderMaterial.new()
	m.shader = RING_SHADER
	m.set_shader_parameter("color", color)
	m.set_shader_parameter("thickness", thickness)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	mi.position = pos
	if flat:
		mi.rotation = Vector3(-PI / 2.0, 0, 0)
	else:
		_face_camera(mi)
	var tw := mi.create_tween()
	tw.tween_method(func(v: float) -> void: m.set_shader_parameter("progress", v), 0.0, 1.0, life)
	tw.tween_callback(mi.queue_free)


## Braises qui montent lentement.
func embers(pos: Vector3, amount: int, color: Color) -> void:
	_burst(pos, Vector3.UP, amount, 1.1, 0.5, 2.5,
			[Color(1, 1, 0.8, 1), color, Color(color.r, color.g * 0.4, 0.0, 0)], 90.0, 0.5, Vector3(0, 1.2, 0))


## Onde du Burst.
func burst_wave(pos: Vector3) -> void:
	_flash(pos, Color(1.0, 0.8, 0.3), 2.6)
	_burst(pos, Vector3.UP, 70, 0.5, 5.0, 13.0,
			[Color(1, 1, 0.8, 1), Color(1.0, 0.7, 0.2, 0)], 180.0, 1.2)
	ring(Vector3(pos.x, 0.05, pos.z), Color(1.0, 0.75, 0.25), 5.0, true, 0.5, 0.06)
	ring(pos, Color(1.0, 0.85, 0.4), 4.0, false, 0.45)
	embers(pos, 40, Color(1.0, 0.7, 0.2))


func _face_camera(n: Node3D) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var to_cam := cam.global_position - n.global_position
	if to_cam.length() < 0.01:
		return
	var up := Vector3.UP if absf(to_cam.normalized().dot(Vector3.UP)) < 0.98 else Vector3.FORWARD
	# Le quad regarde dans le sens +Z : on oriente -Z à l'opposé de la caméra.
	n.look_at(n.global_position - to_cam, up)


func _burst(pos: Vector3, dir: Vector3, amount: int, life: float, vmin: float, vmax: float,
		colors: Array, spread: float, size: float, gravity: Vector3 = Vector3(0, -14, 0)) -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = maxi(amount, 1)
	p.lifetime = life
	p.mesh = _spark_mesh
	p.material_override = _spark_mat
	p.direction = (dir + Vector3(0, 0.35, 0)).normalized()
	p.spread = spread
	p.initial_velocity_min = vmin
	p.initial_velocity_max = vmax
	p.gravity = gravity
	p.damping_min = 0.5
	p.damping_max = 2.0
	p.particle_flag_align_y = true
	p.scale_amount_min = 0.5 * size
	p.scale_amount_max = 1.3 * size
	var g := Gradient.new()
	g.colors = PackedColorArray(colors)
	var offs := PackedFloat32Array()
	for k in colors.size():
		offs.append(float(k) / float(maxi(colors.size() - 1, 1)))
	g.offsets = offs
	p.color_ramp = g
	add_child(p)
	p.position = pos
	p.emitting = true
	get_tree().create_timer(life + 0.5).timeout.connect(p.queue_free)


func _flash(pos: Vector3, col: Color, power: float) -> void:
	var light := OmniLight3D.new()
	light.light_color = col
	light.light_energy = 4.0 * power
	light.omni_range = 5.0
	add_child(light)
	light.position = pos
	var tw := light.create_tween()
	tw.tween_property(light, "light_energy", 0.0, 0.18)
	tw.tween_callback(light.queue_free)

	var ball := MeshInstance3D.new()
	ball.mesh = _flash_mesh
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = Color(col.r, col.g, col.b, 0.9)
	ball.material_override = m
	ball.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ball)
	ball.position = pos
	ball.scale = Vector3.ONE * 0.1
	var tw2 := ball.create_tween()
	tw2.set_parallel(true)
	tw2.tween_property(ball, "scale", Vector3.ONE * (0.45 * power + 0.2), 0.09)
	tw2.tween_property(m, "albedo_color:a", 0.0, 0.12)
	tw2.chain().tween_callback(ball.queue_free)
