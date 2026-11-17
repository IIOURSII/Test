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


func update_view(prev: FighterState, cur: FighterState, alpha: float,
		look_yaw: float, look_pitch: float, delta: float) -> void:
	var fcfg: Dictionary = _cfg["fighter"]
	var p := prev.pos.lerp(cur.pos, alpha)
	var crouch_t := lerpf(prev.crouch, cur.crouch, alpha) / float(FighterLogic.CROUCH_TICKS)
	var eye := lerpf(float(fcfg["eye_height"]), float(fcfg["crouch_eye_height"]), crouch_t)

	position = p + Vector3(0, eye, 0)
	rotation = Vector3(0, look_yaw, 0)
	camera.rotation = Vector3(look_pitch, 0, 0)

	# Petit "kick" de FOV pendant le dash : sensation de vitesse.
	var target_fov := BASE_FOV + (DASH_FOV_BONUS if cur.action == FighterState.Action.DASH else 0.0)
	camera.fov = lerpf(camera.fov, target_fov, 1.0 - exp(-delta * 18.0))

	# Balancement des bras quand on marche.
	var hspeed := Vector2(cur.vel.x, cur.vel.z).length()
	var moving := cur.on_ground and hspeed > 0.5
	_bob_amount = lerpf(_bob_amount, 1.0 if moving else 0.0, 1.0 - exp(-delta * 10.0))
	_bob_phase += delta * hspeed * 1.6
	var bob := Vector3(cos(_bob_phase) * 0.012, absf(sin(_bob_phase)) * 0.018, 0) * _bob_amount

	_pose_weapon(_guard_side(cur, alpha), bob)


## -1..1 : de quel côté est tenue l'arme (animé pendant le changement de garde).
func _guard_side(cur: FighterState, alpha: float) -> float:
	if cur.action != FighterState.Action.GUARD_SWITCH:
		return float(cur.guard)
	var total := float(int(_cfg["guard_switch_ticks"]))
	var half := int(_cfg["guard_switch_ticks"]) / 2
	var start_side := float(cur.guard) if cur.action_tick < half else float(-cur.guard)
	var t := clampf((cur.action_tick + alpha) / total, 0.0, 1.0)
	return lerpf(start_side, -start_side, smoothstep(0.0, 1.0, t))


func _pose_weapon(side: float, bob: Vector3) -> void:
	var s := side
	# Pendant la transition, l'arme passe devant le visage (plus haute, plus centrée).
	var mid := 1.0 - absf(side)
	katana.position = Vector3(0.30 * s, -0.36 + 0.12 * mid, -0.55 - 0.1 * mid) + bob
	katana.rotation = Vector3(deg_to_rad(-38.0), 0.0, deg_to_rad(22.0) * s)

	var grip_a := katana.transform * Vector3(0, -0.07, 0)
	var grip_b := katana.transform * Vector3(0, 0.07, 0)
	hand_main.position = grip_b
	hand_off.position = grip_a
	_place_forearm(forearm_main, grip_b, Vector3(0.42 * s, -0.75, -0.05))
	_place_forearm(forearm_off, grip_a, Vector3(-0.05 * s, -0.8, 0.05))


func _place_forearm(arm: MeshInstance3D, hand: Vector3, elbow: Vector3) -> void:
	var dir := elbow - hand
	var length := dir.length()
	var b := Basis.looking_at(dir.normalized(), Vector3.UP)
	b = b * Basis.from_scale(Vector3(1, 1, length))
	arm.transform = Transform3D(b, (hand + elbow) * 0.5)
