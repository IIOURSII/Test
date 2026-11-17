class_name FirstPersonView
extends Node3D
## Caméra du joueur + bras et katana visibles à l'écran.
## Ne fait QUE lire l'état de la simulation (jamais l'inverse).

const BASE_FOV := 80.0
const DASH_FOV_BONUS := 10.0

var camera: Camera3D
var arms: Node3D
var katana: Node3D
var forearm_main: MeshInstance3D
var forearm_off: MeshInstance3D
var hand_main: MeshInstance3D
var hand_off: MeshInstance3D

var _cfg: Dictionary
var _bob_phase: float = 0.0
var _bob_amount: float = 0.0
var _shake: float = 0.0
var _shake_time: float = 0.0
var _fov_punch: float = 0.0
var _kick: Vector2 = Vector2.ZERO   ## petit à-coup de caméra à l'impact
var trail: SlashTrail
var _pose: Array = []   ## pose affichée (lissée hors attaque)
var _blade_mat: StandardMaterial3D
var _embers: CPUParticles3D
var _aura_time: float = 0.0
var _aura_color: Color = Color(1.0, 0.5, 0.15)
var _ember_color: Color = Color(0, 0, 0, 0)


func setup(cfg: Dictionary) -> void:
	_cfg = cfg
	camera = Camera3D.new()
	camera.fov = BASE_FOV
	camera.near = 0.03
	camera.current = true
	add_child(camera)

	arms = Node3D.new()
	camera.add_child(arms)

	katana = MeshUtil.katana()
	arms.add_child(katana)
	trail = SlashTrail.new()
	arms.add_child(trail)
	trail.setup()
	_setup_aura()

	var skin := Color(0.85, 0.66, 0.5)
	var sleeve := Color(0.15, 0.17, 0.25)
	hand_main = MeshUtil.sphere(0.045, skin)
	hand_off = MeshUtil.sphere(0.045, skin)
	arms.add_child(hand_main)
	arms.add_child(hand_off)
	forearm_main = MeshUtil.box(Vector3(0.075, 0.075, 1.0), sleeve)
	forearm_off = MeshUtil.box(Vector3(0.075, 0.075, 1.0), sleeve)
	arms.add_child(forearm_main)
	arms.add_child(forearm_off)


## Aura : la lame s'embrase et laisse des braises (après un parry ou un counter).
func _setup_aura() -> void:
	var blade := katana.get_node("Blade") as MeshInstance3D
	_blade_mat = blade.material_override as StandardMaterial3D
	_blade_mat.emission_enabled = true
	_blade_mat.emission_energy_multiplier = 0.0
	_embers = CPUParticles3D.new()
	_embers.local_coords = false
	_embers.amount = 40
	_embers.lifetime = 0.7
	_embers.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_embers.emission_box_extents = Vector3(0.01, 0.38, 0.01)
	_embers.gravity = Vector3(0, 1.5, 0)
	_embers.initial_velocity_min = 0.1
	_embers.initial_velocity_max = 0.6
	_embers.spread = 180.0
	_embers.scale_amount_min = 0.5
	_embers.scale_amount_max = 1.2
	var em := BoxMesh.new()
	em.size = Vector3(0.012, 0.012, 0.012)
	_embers.mesh = em
	var mm := StandardMaterial3D.new()
	mm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mm.vertex_color_use_as_albedo = true
	mm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_embers.material_override = mm
	_embers.emitting = false
	_embers.position = Vector3(0, 0.53, 0)
	katana.add_child(_embers)


## Aura temporaire (parry, counter...).
func aura(color: Color, seconds: float) -> void:
	_aura_color = color
	_aura_time = maxf(_aura_time, seconds)


func _set_ember_color(color: Color) -> void:
	if color == _ember_color:
		return
	_ember_color = color
	var g := Gradient.new()
	g.colors = PackedColorArray([Color(1, 1, 0.9, 1), color, Color(color.r, color.g * 0.3, 0.0, 0.0)])
	g.offsets = PackedFloat32Array([0.0, 0.4, 1.0])
	_embers.color_ramp = g


## Identité de l'arme : lueur liée au Zanshin, charge de posture, lame tachée quand elle s'émousse.
func _update_weapon_identity(cur: FighterState, moves: MoveSet, delta: float) -> void:
	_aura_time = maxf(_aura_time - delta, 0.0)
	var style_aura := moves.style_color("aura", Color(1.0, 0.3, 0.1))
	var temp := clampf(_aura_time / 0.6, 0.0, 1.0)
	var pip_glow := float(cur.weapon_pips) / 3.0 * 0.6
	var charge := 0.0
	if cur.in_stance:
		charge = clampf(float(cur.charge_ticks) / float(int(moves.mech("stance_max_ticks", 90))), 0.0, 1.0)
	var glow := maxf(temp, pip_glow) + charge * 1.5
	var col := _aura_color if _aura_time > 0.0 else style_aura
	if cur.issen:
		col = Color(1.0, 0.95, 0.9)
		glow = 3.0
	_blade_mat.emission = col
	_blade_mat.emission_energy_multiplier = glow * (2.0 + sin(Time.get_ticks_msec() * 0.02) * 0.5)
	_set_ember_color(col)
	_embers.emitting = glow > 0.35

	# Tranchant : la lame se tache de sang et perd son éclat quand elle s'émousse.
	var dull := 1.0 - float(cur.weapon_gauge) / 100.0
	_blade_mat.albedo_color = Color(0.85, 0.87, 0.9).lerp(Color(0.32, 0.04, 0.04), dull * 0.85)
	_blade_mat.metallic = lerpf(0.9, 0.35, dull)
	_blade_mat.roughness = lerpf(0.22, 0.65, dull)

	trail.tint = col.lightened(0.4) if glow > 0.35 else moves.style_color("trail", Color(1.0, 0.95, 0.85))
	if cur.in_stance:
		katana.position += Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * 0.004 * (0.3 + charge)


## Secousse + à-coup + zoom à l'impact (proportionnels à la puissance du coup).
func on_impact(power: float, as_attacker: bool) -> void:
	_shake = maxf(_shake, power * (0.7 if as_attacker else 1.3))
	_fov_punch = -7.0 * power if as_attacker else 5.0 * power
	_kick = Vector2(randf_range(-1.0, 1.0), -1.0 if as_attacker else 1.0) * 0.025 * power


func update_view(prev: FighterState, cur: FighterState, alpha: float,
		look_yaw: float, look_pitch: float, delta: float, moves: MoveSet) -> void:
	var fcfg: Dictionary = _cfg["fighter"]
	var p := prev.pos.lerp(cur.pos, alpha)
	var crouch_t := lerpf(prev.crouch, cur.crouch, alpha) / float(FighterLogic.CROUCH_TICKS)
	var eye := lerpf(float(fcfg["eye_height"]), float(fcfg["crouch_eye_height"]), crouch_t)

	position = p + Vector3(0, eye, 0)
	rotation = Vector3(0, look_yaw, 0)

	_shake_time += delta
	_shake = move_toward(_shake, 0.0, delta * 2.5)
	_kick = _kick.lerp(Vector2.ZERO, 1.0 - exp(-delta * 12.0))
	_fov_punch = lerpf(_fov_punch, 0.0, 1.0 - exp(-delta * 9.0))
	var sh := Vector2(sin(_shake_time * 71.0), cos(_shake_time * 53.0)) * _shake * 0.06

	# Le "corps" suit le geste : la caméra penche/plonge avec le coup.
	var cam_off := Vector4.ZERO  # roll, pitch, yaw (degrés), push (m)
	var attacking := cur.action == FighterState.Action.ATTACK and moves.has_move(cur.move_id)
	if attacking:
		var m := moves.get_move(cur.move_id)
		var tc := float(cur.move_tick) + (0.0 if (cur.hitstop > 0 or cur.in_stance) else alpha)
		var c := WeaponAnim.cam_curve(m, tc)
		var cp: Dictionary = WeaponAnim.CAM.get(m["anim"], {})
		var g := float(cur.guard)
		cam_off = Vector4(float(cp.get("roll", 0.0)) * g, float(cp.get("pitch", 0.0)),
				float(cp.get("yaw", 0.0)) * g, float(cp.get("push", 0.0))) * c
	camera.rotation = Vector3(
		look_pitch + sh.y + _kick.y + deg_to_rad(cam_off.y),
		sh.x + _kick.x + deg_to_rad(cam_off.z),
		deg_to_rad(cam_off.x))
	camera.position = Vector3(0, 0, -cam_off.w)

	var dashing := cur.action == FighterState.Action.DASH
	# Posture Iai : la vue se resserre pendant la charge (concentration).
	var focus := 0.0
	if cur.in_stance:
		focus = -9.0 * clampf(float(cur.charge_ticks) / float(int(moves.mech("stance_max_ticks", 90))), 0.0, 1.0) - 2.0
	var target_fov := BASE_FOV + (DASH_FOV_BONUS if dashing else 0.0) + _fov_punch + focus
	camera.fov = lerpf(camera.fov, target_fov, 1.0 - exp(-delta * 18.0))
	camera.fov = clampf(camera.fov, 60.0, 110.0)

	var hspeed := Vector2(cur.vel.x, cur.vel.z).length()
	var moving := cur.on_ground and hspeed > 0.5 and cur.action != FighterState.Action.ATTACK
	_bob_amount = lerpf(_bob_amount, 1.0 if moving else 0.0, 1.0 - exp(-delta * 10.0))
	_bob_phase += delta * hspeed * 1.6
	var bob := Vector3(cos(_bob_phase) * 0.012, absf(sin(_bob_phase)) * 0.018, 0) * _bob_amount

	var pose: Array
	if cur.action == FighterState.Action.ATTACK and moves.has_move(cur.move_id):
		# Pendant le hitstop, l'arme reste figée (pas d'interpolation).
		var t := float(cur.move_tick) + (0.0 if (cur.hitstop > 0 or cur.in_stance) else alpha)
		pose = WeaponAnim.pose_for_move(moves.get_move(cur.move_id), t, float(cur.guard))
	elif cur.action == FighterState.Action.GUARD_SWITCH or cur.action == FighterState.Action.NONE \
			or cur.action == FighterState.Action.DASH:
		pose = _smooth(_guard_pose(cur, alpha), delta, 30.0)
	else:
		pose = _smooth(WeaponAnim.state_pose(cur), delta, 35.0)
	_pose = pose
	_apply_pose(pose, bob)

	# Traînée de lame pendant les frames actives (+ un peu après).
	if attacking:
		var m2 := moves.get_move(cur.move_id)
		var s0 := int(m2["startup"])
		var e0 := s0 + int(m2["active"]) + 3
		if m2["button"] == "blade" and not (m2["hitboxes"] as Array).is_empty() \
				and cur.move_tick >= s0 and cur.move_tick <= e0 and cur.hitstop == 0:
			trail.add_point(katana.transform * Vector3(0, 0.2, 0), katana.transform * Vector3(0, 0.92, 0))
	_update_weapon_identity(cur, moves, delta)
	trail.tick(delta, cur.hitstop > 0)


## Transition douce vers une pose (évite les sauts quand on lève/baisse la garde).
func _smooth(target: Array, delta: float, speed: float) -> Array:
	if _pose.is_empty():
		return target
	return WeaponAnim.lerp_pose(_pose, target, 1.0 - exp(-delta * speed))


## Pose de garde, animée pendant le changement de garde.
func _guard_pose(cur: FighterState, alpha: float) -> Array:
	var side := float(cur.guard)
	if cur.action == FighterState.Action.GUARD_SWITCH:
		var total := float(int(_cfg["guard_switch_ticks"]))
		var half := int(_cfg["guard_switch_ticks"]) / 2
		var start_side := float(cur.guard) if cur.action_tick < half else float(-cur.guard)
		var t := clampf((cur.action_tick + alpha) / total, 0.0, 1.0)
		side = lerpf(start_side, -start_side, smoothstep(0.0, 1.0, t))
	var rest: Array = WeaponAnim.POSES["rest"]
	var grip: Vector3 = rest[0]
	var dir: Vector3 = rest[1]
	var mid := 1.0 - absf(side)  # pendant la transition, l'arme passe devant le visage
	grip = Vector3(grip.x * side, grip.y + 0.12 * mid, grip.z - 0.1 * mid)
	dir = Vector3(dir.x * side, dir.y, dir.z).normalized()
	return [grip, dir]


func _apply_pose(pose: Array, bob: Vector3) -> void:
	var grip: Vector3 = pose[0]
	var dir: Vector3 = pose[1]
	katana.transform = Transform3D(WeaponAnim.basis_from_dir(dir), grip + bob)

	var side := 1.0 if grip.x >= 0.0 else -1.0
	var grip_a := katana.transform * Vector3(0, -0.07, 0)
	var grip_b := katana.transform * Vector3(0, 0.07, 0)
	hand_main.position = grip_b
	hand_off.position = grip_a
	_place_forearm(forearm_main, grip_b, Vector3(0.42 * side, -0.75, -0.05))
	_place_forearm(forearm_off, grip_a, Vector3(-0.05 * side, -0.8, 0.05))


func _place_forearm(arm: MeshInstance3D, hand: Vector3, elbow: Vector3) -> void:
	var dir := elbow - hand
	var length := dir.length()
	if length < 0.01:
		return
	var b := Basis.looking_at(dir / length, Vector3.UP)
	b = b * Basis.from_scale(Vector3(1, 1, length))
	arm.transform = Transform3D(b, (hand + elbow) * 0.5)
