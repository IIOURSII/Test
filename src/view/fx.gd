class_name Fx
extends Node3D
## Effets 3D. Principe : PEU d'effets, mais nets et bien formés (bandes "cel", contours encre).
## Chaque arme donne ses couleurs via son bloc "style" (data/weapons/*.json).

const SLASH_SHADER := preload("res://shaders/slash.gdshader")
const RING_SHADER := preload("res://shaders/ring.gdshader")
const STAR_SHADER := preload("res://shaders/star_spark.gdshader")

## Inclinaison de la coupe selon le geste (degrés, garde droite).
const SLASH_ROLL := {
	"diag": 35.0, "diag_rev": -35.0, "horizontal": 4.0, "iai": -6.0,
	"rising": 80.0, "down": 95.0, "down_up": 85.0, "thrust": 0.0, "flick": 60.0,
}

var _spark_mesh: BoxMesh
var _spark_mat: StandardMaterial3D
var _arc_mesh: ArrayMesh
var _quad: QuadMesh


func setup() -> void:
	_spark_mesh = BoxMesh.new()
	_spark_mesh.size = Vector3(0.01, 0.16, 0.01)
	_spark_mat = StandardMaterial3D.new()
	_spark_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_spark_mat.vertex_color_use_as_albedo = true
	_spark_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_spark_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_quad = QuadMesh.new()
	_quad.size = Vector2(1, 1)
	_arc_mesh = _build_arc(110.0, 0.22, 32)


## Croissant de rayon 1 dans le plan XY, milieu de l'arc à l'origine. UV.x le long, UV.y en travers.
static func _build_arc(arc_deg: float, width: float, n: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half := deg_to_rad(arc_deg) * 0.5
	var pts_in: Array[Vector3] = []
	var pts_out: Array[Vector3] = []
	for i in n + 1:
		var t := float(i) / float(n)
		var a := lerpf(-half, half, t)
		var dirv := Vector3(cos(a), sin(a), 0.0)
		pts_in.append(dirv * (1.0 - width * 0.5) - Vector3(1, 0, 0))
		pts_out.append(dirv * (1.0 + width * 0.5) - Vector3(1, 0, 0))
	for i in n:
		var t0 := float(i) / float(n)
		var t1 := float(i + 1) / float(n)
		st.set_uv(Vector2(t0, 0)); st.add_vertex(pts_in[i])
		st.set_uv(Vector2(t0, 1)); st.add_vertex(pts_out[i])
		st.set_uv(Vector2(t1, 1)); st.add_vertex(pts_out[i + 1])
		st.set_uv(Vector2(t0, 0)); st.add_vertex(pts_in[i])
		st.set_uv(Vector2(t1, 1)); st.add_vertex(pts_out[i + 1])
		st.set_uv(Vector2(t1, 0)); st.add_vertex(pts_in[i + 1])
	return st.commit()


## Étincelles physiques (traits fins). kind : "blade", "pommel", "block", "parry".
func impact(pos: Vector3, dir: Vector3, power: float, kind: String, spark_col: Color = Color(1.0, 0.8, 0.5)) -> void:
	match kind:
		"blade":
			_burst(pos, dir, int(10 + 18 * power), 0.28, 6.0, 14.0 + 6.0 * power,
					[Color(1, 1, 1, 1), spark_col, Color(spark_col.r, spark_col.g * 0.4, 0.0, 0)], 45.0, 1.0)
			_burst(pos, dir, int(3 + 6 * power), 0.5, 2.0, 5.0,
					[Color(0.6, 0.0, 0.02, 1), Color(0.35, 0.0, 0.0, 0)], 30.0, 1.4)
		"block":
			_burst(pos, -dir, int(12 + 14 * power), 0.22, 5.0, 12.0,
					[Color(1, 1, 1, 1), Color(0.6, 0.8, 1.0, 1), Color(0.3, 0.5, 1.0, 0)], 65.0, 0.8)
		"parry":
			_burst(pos, -dir, 50, 0.4, 7.0, 18.0,
					[Color(1, 1, 1, 1), Color(1.0, 0.85, 0.3, 1), Color(1.0, 0.5, 0.1, 0)], 110.0, 1.1)
		_:
			_burst(pos, dir, int(8 + 8 * power), 0.3, 2.0, 5.0,
					[Color(1, 1, 0.9, 0.7), Color(0.7, 0.65, 0.55, 0)], 80.0, 1.2)
	_light(pos, spark_col if kind == "blade" else (Color(1.0, 0.85, 0.4) if kind == "parry" else Color(0.8, 0.9, 1.0)),
			0.4 + 0.6 * power if kind != "parry" else 1.6)


## Coupe en croissant, face caméra, orientée selon le geste.
func slash_mark(pos: Vector3, anim: String, guard: int, length: float,
		core: Color, edge: Color, ink: Color, life: float = 0.26) -> void:
	var roll := float(SLASH_ROLL.get(anim, 20.0)) * float(guard)
	var m := ShaderMaterial.new()
	m.shader = SLASH_SHADER
	m.set_shader_parameter("core_color", core)
	m.set_shader_parameter("edge_color", edge)
	m.set_shader_parameter("ink_color", ink)
	var mi := _spawn(_arc_mesh, m, pos)
	mi.rotate_object_local(Vector3(0, 0, 1), deg_to_rad(roll))
	if guard < 0:
		mi.rotate_object_local(Vector3(0, 1, 0), PI)   # garde gauche : arc dans l'autre sens
	mi.scale = Vector3.ONE * length * 0.5
	_animate(mi, m, life)


## Étoile d'impact (le "pop" visuel du coup).
func star(pos: Vector3, color: Color, size: float, life: float = 0.12) -> void:
	var m := ShaderMaterial.new()
	m.shader = STAR_SHADER
	m.set_shader_parameter("color", color)
	m.set_shader_parameter("seed", randf() * 10.0)
	m.set_shader_parameter("spikes", float(randi_range(3, 5)))
	var mi := _spawn(_quad, m, pos)
	mi.rotate_object_local(Vector3(0, 0, 1), randf() * TAU)
	mi.scale = Vector3.ONE * size
	_animate(mi, m, life)


## Onde de choc fine. flat = au sol, sinon face caméra.
func ring(pos: Vector3, color: Color, radius: float, flat: bool, life: float = 0.35, thickness: float = 0.05) -> void:
	var m := ShaderMaterial.new()
	m.shader = RING_SHADER
	m.set_shader_parameter("color", color)
	m.set_shader_parameter("thickness", thickness)
	var mi := _spawn(_quad, m, pos, not flat)
	if flat:
		mi.rotation = Vector3(-PI / 2.0, 0, 0)
	mi.scale = Vector3.ONE * radius * 2.0
	_animate(mi, m, life)


## Braises qui montent lentement.
func embers(pos: Vector3, amount: int, color: Color) -> void:
	_burst(pos, Vector3.UP, amount, 1.0, 0.4, 2.0,
			[Color(1, 1, 0.8, 1), color, Color(color.r, color.g * 0.4, 0.0, 0)], 90.0, 0.45, Vector3(0, 1.0, 0))


## Onde du Burst.
func burst_wave(pos: Vector3) -> void:
	_light(pos, Color(1.0, 0.8, 0.3), 2.4)
	star(pos, Color(1.0, 0.75, 0.3), 3.0, 0.2)
	ring(Vector3(pos.x, 0.05, pos.z), Color(1.0, 0.75, 0.25), 5.0, true, 0.5, 0.04)
	ring(pos, Color(1.0, 0.85, 0.4), 3.5, false, 0.4, 0.04)
	embers(pos, 24, Color(1.0, 0.7, 0.2))


# ------------------------------------------------------------ outils

func _spawn(mesh: Mesh, m: Material, pos: Vector3, face_cam: bool = true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	mi.position = pos
	if face_cam:
		_face_camera(mi)
	return mi


func _animate(mi: MeshInstance3D, m: ShaderMaterial, life: float) -> void:
	var tw := mi.create_tween()
	tw.tween_method(func(v: float) -> void: m.set_shader_parameter("progress", v), 0.0, 1.0, life)
	tw.tween_callback(mi.queue_free)


func _face_camera(n: Node3D) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var to_cam := cam.global_position - n.global_position
	if to_cam.length() < 0.01:
		return
	var up := Vector3.UP if absf(to_cam.normalized().dot(Vector3.UP)) < 0.98 else Vector3.FORWARD
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
	p.direction = (dir + Vector3(0, 0.3, 0)).normalized()
	p.spread = spread
	p.initial_velocity_min = vmin
	p.initial_velocity_max = vmax
	p.gravity = gravity
	p.damping_min = 1.0
	p.damping_max = 3.0
	p.particle_flag_align_y = true
	p.scale_amount_min = 0.6 * size
	p.scale_amount_max = 1.2 * size
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


func _light(pos: Vector3, col: Color, power: float) -> void:
	var light := OmniLight3D.new()
	light.light_color = col
	light.light_energy = 3.5 * power
	light.omni_range = 5.0
	add_child(light)
	light.position = pos
	var tw := light.create_tween()
	tw.tween_property(light, "light_energy", 0.0, 0.15)
	tw.tween_callback(light.queue_free)
