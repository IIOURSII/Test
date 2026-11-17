class_name Fx
extends Node3D
## Effets d'impact : gerbe d'étincelles, gouttes, éclair lumineux.

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


## kind : "blade" (étincelles + gouttes) ou "pommel" (poussière, choc sourd).
func impact(pos: Vector3, dir: Vector3, power: float, kind: String) -> void:
	if kind == "blade":
		_burst(pos, dir, int(16 + 34 * power), 0.32, 5.0, 12.0 + 6.0 * power,
				[Color(1, 1, 1, 1), Color(1.0, 0.75, 0.3, 1), Color(1.0, 0.3, 0.05, 0)], 60.0, 1.0)
		_burst(pos, dir, int(5 + 10 * power), 0.5, 2.0, 5.0,
				[Color(0.7, 0.02, 0.02, 1), Color(0.45, 0.0, 0.0, 0)], 35.0, 1.8)
		_flash(pos, Color(1.0, 0.85, 0.6), 0.5 + 0.5 * power)
	elif kind == "block":
		# Métal contre métal : étincelles blanc-bleu, pas de sang.
		_burst(pos, -dir, int(14 + 20 * power), 0.25, 4.0, 10.0,
				[Color(1, 1, 1, 1), Color(0.6, 0.8, 1.0, 1), Color(0.3, 0.5, 1.0, 0)], 70.0, 0.9)
		_flash(pos, Color(0.7, 0.85, 1.0), 0.35 + 0.3 * power)
	elif kind == "parry":
		# Gros feu d'artifice doré.
		_burst(pos, -dir, 70, 0.45, 6.0, 16.0,
				[Color(1, 1, 1, 1), Color(1.0, 0.85, 0.3, 1), Color(1.0, 0.5, 0.1, 0)], 110.0, 1.3)
		_flash(pos, Color(1.0, 0.85, 0.4), 1.6)
	else:
		_burst(pos, dir, int(10 + 12 * power), 0.3, 2.0, 6.0,
				[Color(1, 1, 0.9, 0.8), Color(0.7, 0.65, 0.55, 0)], 80.0, 1.4)
		_flash(pos, Color(1.0, 1.0, 0.9), 0.35 + 0.3 * power)


## Onde du Burst : grosse sphère dorée qui s'étend.
func burst_wave(pos: Vector3) -> void:
	_flash(pos, Color(1.0, 0.8, 0.3), 2.6)
	_burst(pos, Vector3.UP, 60, 0.5, 5.0, 12.0,
			[Color(1, 1, 0.8, 1), Color(1.0, 0.7, 0.2, 0)], 180.0, 1.2)


func _burst(pos: Vector3, dir: Vector3, amount: int, life: float, vmin: float, vmax: float,
		colors: Array, spread: float, size: float) -> void:
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
	p.gravity = Vector3(0, -14, 0)
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
