class_name FighterView
extends Node3D
## Représentation d'un combattant vu de l'extérieur (mannequin, IA, adversaire).

var body: MeshInstance3D
var head: MeshInstance3D
var visor: MeshInstance3D
var katana: Node3D
var _body_mat: StandardMaterial3D
var _head_mat: StandardMaterial3D
var _cfg: Dictionary
var _flash: float = 0.0
var _recoil: float = 0.0
var _pose: Array = []
var _flash_color: Color = Color.WHITE


func setup(cfg: Dictionary, color: Color) -> void:
	_cfg = cfg
	var r: float = cfg["fighter"]["radius"]
	body = MeshUtil.capsule(r, 1.5, color)
	_body_mat = body.material_override as StandardMaterial3D
	add_child(body)
	head = MeshUtil.sphere(0.17, color.lightened(0.25))
	_head_mat = head.material_override as StandardMaterial3D
	add_child(head)
	# Bandeau sombre sur le visage : montre de quel côté il regarde.
	visor = MeshUtil.box(Vector3(0.26, 0.06, 0.06), Color(0.05, 0.05, 0.05))
	add_child(visor)
	katana = MeshUtil.katana()
	add_child(katana)
	for m in [_body_mat, _head_mat]:
		m.emission_enabled = true
		m.emission = Color.WHITE
		m.emission_energy_multiplier = 0.0


## Flash blanc quand il est touché.
func flash(power: float = 1.0, color: Color = Color.WHITE, recoil: bool = true) -> void:
	_flash = 1.0
	_flash_color = color
	_body_mat.emission = color
	_head_mat.emission = color
	if recoil:
		_recoil = maxf(_recoil, 0.6 + 0.6 * power)


func update_view(prev: FighterState, cur: FighterState, alpha: float, delta: float, moves: MoveSet) -> void:
	var fcfg: Dictionary = _cfg["fighter"]
	var frozen := cur.hitstop > 0
	position = cur.pos if frozen else prev.pos.lerp(cur.pos, alpha)
	var yaw := lerp_angle(prev.yaw_rad(), cur.yaw_rad(), alpha)

	# Recule le buste quand il est sonné, tremble pendant le hitstop.
	_recoil = move_toward(_recoil, 0.0, delta * 3.0)
	var tilt := (0.12 if cur.action == FighterState.Action.HITSTUN else 0.0) + 0.3 * _recoil
	var tremble := Vector3.ZERO
	if frozen and cur.action == FighterState.Action.HITSTUN:
		tremble = Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)) * 0.05
	position += tremble
	rotation = Vector3(tilt, yaw, 0)

	var crouch_t := lerpf(prev.crouch, cur.crouch, alpha) / float(FighterLogic.CROUCH_TICKS)
	var h := lerpf(float(fcfg["height"]), float(fcfg["crouch_height"]), crouch_t)
	var body_h := h - 0.3
	body.scale = Vector3(1, body_h / 1.5, 1)
	body.position = Vector3(0, body_h * 0.5, 0)
	head.position = Vector3(0, h - 0.17, 0)
	visor.position = Vector3(0, h - 0.15, -0.15)

	# Même animation que la vue FPS, placée devant le torse.
	var side := float(cur.guard)
	var pose: Array
	if cur.action == FighterState.Action.ATTACK and moves.has_move(cur.move_id):
		var t := float(cur.move_tick) + (0.0 if (frozen or cur.in_stance) else alpha)
		pose = WeaponAnim.pose_for_move(moves.get_move(cur.move_id), t, side)
	else:
		var target := WeaponAnim.state_pose(cur)
		pose = target if _pose.is_empty() else WeaponAnim.lerp_pose(_pose, target, 1.0 - exp(-delta * 30.0))
	_pose = pose
	var grip: Vector3 = pose[0]
	katana.transform = Transform3D(WeaponAnim.basis_from_dir(pose[1]), Vector3(0, h - 0.25, 0) + grip * 1.2)

	_flash = move_toward(_flash, 0.0, delta * 8.0)
	_body_mat.emission_energy_multiplier = _flash * 2.0
	_head_mat.emission_energy_multiplier = _flash * 2.0
