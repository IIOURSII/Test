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


## Petite secousse de caméra (proportionnelle au coup). Version simple, améliorée à l'étape 5.
func add_shake(amount: float) -> void:
	_shake = maxf(_shake, amount)


func update_view(prev: FighterState, cur: FighterState, alpha: float,
		look_yaw: float, look_pitch: float, delta: float, moves: MoveSet) -> void:
	var fcfg: Dictionary = _cfg["fighter"]
	var p := prev.pos.lerp(cur.pos, alpha)
	var crouch_t := lerpf(prev.crouch, cur.crouch, alpha) / float(FighterLogic.CROUCH_TICKS)
	var eye := lerpf(float(fcfg["eye_height"]), float(fcfg["crouch_eye_height"]), crouch_t)

	position = p + Vector3(0, eye, 0)
	rotation = Vector3(0, look_yaw, 0)

	_shake_time += delta
	_shake = move_toward(_shake, 0.0, delta * 3.0)
	var sh := Vector2(sin(_shake_time * 71.0), cos(_shake_time * 53.0)) * _shake * 0.05
	camera.rotation = Vector3(look_pitch + sh.y, sh.x, 0)

	var dashing := cur.action == FighterState.Action.DASH
	var target_fov := BASE_FOV + (DASH_FOV_BONUS if dashing else 0.0)
	camera.fov = lerpf(camera.fov, target_fov, 1.0 - exp(-delta * 18.0))

	var hspeed := Vector2(cur.vel.x, cur.vel.z).length()
	var moving := cur.on_ground and hspeed > 0.5 and cur.action != FighterState.Action.ATTACK
	_bob_amount = lerpf(_bob_amount, 1.0 if moving else 0.0, 1.0 - exp(-delta * 10.0))
	_bob_phase += delta * hspeed * 1.6
	var bob := Vector3(cos(_bob_phase) * 0.012, absf(sin(_bob_phase)) * 0.018, 0) * _bob_amount

	var pose: Array
	if cur.action == FighterState.Action.ATTACK and moves.has_move(cur.move_id):
		# Pendant le hitstop, l'arme reste figée (pas d'interpolation).
		var t := float(cur.move_tick) + (0.0 if cur.hitstop > 0 else alpha)
		pose = WeaponAnim.pose_for_move(moves.get_move(cur.move_id), t, float(cur.guard))
	else:
		pose = _guard_pose(cur, alpha)
	_apply_pose(pose, bob)


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
