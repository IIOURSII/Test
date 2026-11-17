class_name Puppet
extends Node3D
## Petit samouraï en volumes cel-shadés, rendu en basse résolution puis affiché comme un SPRITE
## (voir FighterView). Il n'est jamais vu directement : seulement à travers sa "caméra photo".
## Silhouette pensée pour la lecture : chapeau/bandeau, épaules ailées (kataginu), hakama évasé.

var body: Node3D           ## tout sauf l'arme (s'écrase quand on s'accroupit)
var katana: Node3D
var arm_r: MeshInstance3D
var arm_l: MeshInstance3D
var hand_r: MeshInstance3D
var hand_l: MeshInstance3D
var _mats: Array[StandardMaterial3D] = []
var _cols: Array[Color] = []
var _pose: Array = []
var _height: float = 1.8


func setup(main_color: Color, accent: Color) -> void:
	body = Node3D.new()
	add_child(body)
	var skin := Color(0.92, 0.74, 0.58)
	var dark := accent.darkened(0.55)
	_part(MeshUtil.cylinder(0.2, 0.85, dark), Vector3(0, 0.43, 0))      # hakama
	(_last().mesh as CylinderMesh).bottom_radius = 0.38
	for sx in [-0.12, 0.12]:
		_part(MeshUtil.box(Vector3(0.12, 0.06, 0.2), Color(0.1, 0.08, 0.07)), Vector3(sx, 0.03, -0.06))   # pieds
	_part(MeshUtil.box(Vector3(0.5, 0.5, 0.3), main_color), Vector3(0, 1.1, 0))           # kimono
	_part(MeshUtil.box(Vector3(0.53, 0.1, 0.32), accent), Vector3(0, 0.88, 0))             # obi
	_part(MeshUtil.box(Vector3(0.8, 0.1, 0.34), accent.lightened(0.1)), Vector3(0, 1.37, 0))  # épaules ailées
	_part(MeshUtil.sphere(0.17, skin), Vector3(0, 1.58, 0))                                 # tête
	_part(MeshUtil.cylinder(0.175, 0.05, Color(0.85, 0.85, 0.82)), Vector3(0, 1.64, 0))     # bandeau
	_part(MeshUtil.box(Vector3(0.09, 0.09, 0.14), Color(0.06, 0.05, 0.05)), Vector3(0, 1.76, 0.07))  # chignon
	for ex in [-0.06, 0.06]:
		_part(MeshUtil.box(Vector3(0.04, 0.03, 0.02), Color(0.05, 0.03, 0.03)), Vector3(ex, 1.59, -0.16))  # yeux
	katana = MeshUtil.katana()
	add_child(katana)
	_collect(katana)
	hand_r = _loose(MeshUtil.sphere(0.06, skin))
	hand_l = _loose(MeshUtil.sphere(0.06, skin))
	arm_r = _loose(MeshUtil.box(Vector3(0.11, 0.11, 1.0), main_color))
	arm_l = _loose(MeshUtil.box(Vector3(0.11, 0.11, 1.0), main_color))


func _part(n: MeshInstance3D, pos: Vector3) -> void:
	n.position = pos
	body.add_child(n)
	_register(n)


func _last() -> MeshInstance3D:
	return body.get_child(body.get_child_count() - 1)


func _loose(n: MeshInstance3D) -> MeshInstance3D:
	add_child(n)
	_register(n)
	return n


func _register(n: MeshInstance3D) -> void:
	var m := n.material_override as StandardMaterial3D
	if m:
		_mats.append(m)
		_cols.append(m.albedo_color)


func _collect(n: Node) -> void:
	for c in n.get_children():
		if c is MeshInstance3D:
			_register(c as MeshInstance3D)


## crouch_t 0..1, tilt (radians, recul quand on est touché), flash 0..1 (couleur de flash).
func apply(cur: FighterState, alpha: float, delta: float, moves: MoveSet, crouch_t: float,
		tilt: float, flash: float, flash_col: Color) -> void:
	var h := lerpf(1.8, 1.15, crouch_t)
	_height = h
	body.scale = Vector3(1, h / 1.8, 1)
	rotation = Vector3(tilt, 0, 0)

	var side := float(cur.guard)
	var target: Array
	if cur.action == FighterState.Action.ATTACK and moves.has_move(cur.move_id):
		var frozen := cur.hitstop > 0 or cur.in_stance
		target = WeaponAnim.pose_for_move(moves.get_move(cur.move_id), float(cur.move_tick) + (0.0 if frozen else alpha), side)
		_pose = target
	else:
		target = WeaponAnim.state_pose(cur)
		_pose = target if _pose.is_empty() else WeaponAnim.lerp_pose(_pose, target, 1.0 - exp(-delta * 30.0))
	var grip: Vector3 = _pose[0]
	var chest := Vector3(0, h - 0.32, 0)
	katana.transform = Transform3D(WeaponAnim.basis_from_dir(_pose[1]), chest + grip * 1.25)

	var ga := katana.transform * Vector3(0, -0.07, 0)
	var gb := katana.transform * Vector3(0, 0.07, 0)
	hand_r.position = gb
	hand_l.position = ga
	var sh_y := h - 0.43
	_limb(arm_r, Vector3(0.33 * side, sh_y, 0), gb)
	_limb(arm_l, Vector3(-0.3 * side, sh_y, 0), ga)

	for i in _mats.size():
		_mats[i].albedo_color = _cols[i].lerp(flash_col, clampf(flash, 0.0, 1.0) * 0.85)


func _limb(arm: MeshInstance3D, a: Vector3, b: Vector3) -> void:
	var d := b - a
	var l := d.length()
	if l < 0.01:
		return
	var bs := Basis.looking_at(d / l, Vector3.UP if absf((d / l).dot(Vector3.UP)) < 0.98 else Vector3.FORWARD)
	arm.transform = Transform3D(bs * Basis.from_scale(Vector3(1, 1, l)), (a + b) * 0.5)
