class_name FighterView
extends Node3D
## Représentation d'un combattant vu de l'extérieur (mannequin, IA, adversaire).

var body: MeshInstance3D
var head: MeshInstance3D
var visor: MeshInstance3D
var katana: Node3D
var _cfg: Dictionary


func setup(cfg: Dictionary, color: Color) -> void:
	_cfg = cfg
	var r: float = cfg["fighter"]["radius"]
	body = MeshUtil.capsule(r, 1.5, color)
	add_child(body)
	head = MeshUtil.sphere(0.17, color.lightened(0.25))
	add_child(head)
	# Bandeau sombre sur le visage : montre de quel côté il regarde.
	visor = MeshUtil.box(Vector3(0.26, 0.06, 0.06), Color(0.05, 0.05, 0.05))
	add_child(visor)
	katana = MeshUtil.katana()
	add_child(katana)


func update_view(prev: FighterState, cur: FighterState, alpha: float) -> void:
	var fcfg: Dictionary = _cfg["fighter"]
	position = prev.pos.lerp(cur.pos, alpha)
	rotation = Vector3(0, lerp_angle(prev.yaw_rad(), cur.yaw_rad(), alpha), 0)

	var crouch_t := lerpf(prev.crouch, cur.crouch, alpha) / float(FighterLogic.CROUCH_TICKS)
	var h := lerpf(float(fcfg["height"]), float(fcfg["crouch_height"]), crouch_t)
	var body_h := h - 0.3
	body.scale = Vector3(1, body_h / 1.5, 1)
	body.position = Vector3(0, body_h * 0.5, 0)
	head.position = Vector3(0, h - 0.17, 0)
	visor.position = Vector3(0, h - 0.15, -0.15)

	var side := float(cur.guard)
	katana.position = Vector3(0.32 * side, h * 0.55, -0.35)
	katana.rotation = Vector3(deg_to_rad(-35.0), 0.0, deg_to_rad(15.0) * side)
