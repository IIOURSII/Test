class_name Puppet
extends Node3D
## Samouraï-lansquenet (fusion Japon / Allemagne médiévale) en volumes cel-shadés, photographié en basse résolution pour devenir un SPRITE.
## Silhouette pensée pour se lire même en très gros pixels :
##   cheveux en pointes + queue de cheval, yeux lumineux (on voit où il regarde),
##   long manteau ouvert (haori) qui flotte, écharpe à deux pans qui traînent derrière,
##   hakama séparé en deux jambes (posture, marche, dash, saut lisibles).

var hips: Node3D
var torso: Node3D
var head: Node3D
var leg_l: Node3D
var leg_r: Node3D
var coat_back: Node3D
var scarf_a: Node3D
var scarf_b: Node3D
var plume: Node3D
var katana: Node3D
var arm_r: MeshInstance3D
var arm_l: MeshInstance3D
var hand_r: MeshInstance3D
var hand_l: MeshInstance3D
var _mats: Array[StandardMaterial3D] = []
var _cols: Array[Color] = []
var _pose: Array = []
var _phase: float = 0.0
var _time: float = 0.0
var _lean: Vector2 = Vector2.ZERO
var _twist: float = 0.0


func setup(main_color: Color, accent: Color) -> void:
	var skin := Color(0.93, 0.76, 0.6)
	var hair := Color(0.07, 0.05, 0.07)
	var inner := Color(0.9, 0.86, 0.78)
	var hakama := main_color.darkened(0.55)
	var glove := Color(0.12, 0.1, 0.1)

	hips = _node(self, Vector3(0, 0.95, 0))
	# Jambes (pivot à la hanche) : hakama évasé + pied.
	leg_l = _node(hips, Vector3(-0.12, 0, 0))
	leg_r = _node(hips, Vector3(0.12, 0, 0))
	for leg in [leg_l, leg_r]:
		var h := _mesh(leg, MeshUtil.cylinder(0.1, 0.92, hakama), Vector3(0, -0.46, 0))
		(h.mesh as CylinderMesh).bottom_radius = 0.2
		_mesh(leg, MeshUtil.box(Vector3(0.11, 0.06, 0.22), glove), Vector3(0, -0.92, -0.05))

	torso = _node(hips, Vector3(0, 0.02, 0))
	_mesh(torso, MeshUtil.box(Vector3(0.34, 0.5, 0.22), inner), Vector3(0, 0.3, 0))                 # kimono
	_mesh(torso, MeshUtil.box(Vector3(0.4, 0.09, 0.26), accent.darkened(0.35)), Vector3(0, 0.06, 0))  # obi
	var steel := Color(0.6, 0.63, 0.7)
	for sx in [-1.0, 1.0]:
		_mesh(torso, MeshUtil.box(Vector3(0.14, 0.82, 0.27), main_color), Vector3(sx * 0.17, 0.2, 0))  # pans du manteau
		# Manches bouffantes et tailladées (lansquenet) : bouffant + crevés de la couleur d'accent.
		var pad := _mesh(torso, MeshUtil.sphere(0.14, main_color), Vector3(sx * 0.26, 0.53, 0))
		pad.scale = Vector3(1.2, 1.0, 1.0)
		for k in 3:
			var slash := _mesh(torso, MeshUtil.box(Vector3(0.035, 0.22, 0.03), accent), Vector3(sx * 0.27 + (k - 1) * 0.06 * sx, 0.53, -0.13))
			slash.rotation.z = 0.15 * sx
	# Cuirasse d'acier bombée (Kürass) par-dessus le kimono.
	var cuirass := _mesh(torso, MeshUtil.sphere(0.2, steel), Vector3(0, 0.34, -0.05))
	cuirass.scale = Vector3(1.0, 1.25, 0.62)
	(cuirass.material_override as StandardMaterial3D).metallic = 0.8
	(cuirass.material_override as StandardMaterial3D).roughness = 0.35
	coat_back = _node(torso, Vector3(0, 0.6, 0.13))
	_mesh(coat_back, MeshUtil.box(Vector3(0.46, 0.95, 0.05), main_color), Vector3(0, -0.47, 0))       # dos du manteau

	# Écharpe : tour de cou + deux pans qui traînent.
	_mesh(torso, MeshUtil.cylinder(0.13, 0.09, accent), Vector3(0, 0.66, 0))
	scarf_a = _node(torso, Vector3(-0.05, 0.66, 0.1))
	scarf_b = _node(torso, Vector3(0.06, 0.64, 0.1))
	for sc in [scarf_a, scarf_b]:
		_mesh(sc, MeshUtil.box(Vector3(0.08, 0.025, 0.62), accent), Vector3(0, 0, 0.31))

	head = _node(torso, Vector3(0, 0.82, 0))
	_mesh(head, MeshUtil.sphere(0.14, skin), Vector3.ZERO)
	_mesh(head, MeshUtil.sphere(0.155, hair), Vector3(0, 0.04, 0.03))
	# Pointes de cheveux (vers l'arrière et le haut) + queue de cheval.
	var spikes := [Vector3(0, 0.12, 0.05), Vector3(-0.09, 0.08, 0.08), Vector3(0.09, 0.08, 0.08), Vector3(0, 0.03, 0.13), Vector3(-0.06, 0.13, -0.04)]
	for i in spikes.size():
		var sp := _mesh(head, MeshUtil.cylinder(0.0, 0.24, hair), spikes[i])
		(sp.mesh as CylinderMesh).bottom_radius = 0.055
		sp.rotation = Vector3(deg_to_rad(55.0 + i * 6.0), 0, deg_to_rad((i - 2) * 18.0))
	var tail := _mesh(head, MeshUtil.cylinder(0.0, 0.42, hair), Vector3(0, -0.06, 0.2))
	(tail.mesh as CylinderMesh).bottom_radius = 0.05
	tail.rotation.x = deg_to_rad(160.0)
	# Béret de lansquenet incliné + grand panache de plumes (flotte comme l'écharpe).
	var beret := _mesh(head, MeshUtil.cylinder(0.21, 0.05, hakama.darkened(0.3)), Vector3(0.04, 0.13, 0.0))
	beret.rotation = Vector3(0.1, 0, -0.28)
	plume = _node(head, Vector3(-0.12, 0.17, 0.02))
	var plume_cols := [accent, Color(0.97, 0.95, 0.9), accent.lightened(0.3)]
	for k in 3:
		var fe := _mesh(plume, MeshUtil.box(Vector3(0.05, 0.02, 0.42), plume_cols[k]), Vector3(-0.03 * k, 0.02 * k, 0.2))
		fe.rotation = Vector3(0.0, -0.15 * (k - 1), 0.0)
	# Yeux lumineux (couleur de l'écharpe) : on voit tout de suite où il regarde.
	for ex in [-0.05, 0.05]:
		_mesh(head, MeshUtil.box(Vector3(0.055, 0.022, 0.02), accent.lightened(0.5), 2.5), Vector3(ex, 0.0, -0.135))

	katana = MeshUtil.katana()
	torso.add_child(katana)
	_collect(katana)
	hand_r = _loose(MeshUtil.sphere(0.055, glove))
	hand_l = _loose(MeshUtil.sphere(0.055, glove))
	arm_r = _loose(MeshUtil.box(Vector3(0.1, 0.1, 1.0), main_color))
	arm_l = _loose(MeshUtil.box(Vector3(0.1, 0.1, 1.0), main_color))


func _node(parent: Node3D, pos: Vector3) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	parent.add_child(n)
	return n


func _mesh(parent: Node3D, n: MeshInstance3D, pos: Vector3) -> MeshInstance3D:
	n.position = pos
	parent.add_child(n)
	_register(n)
	return n


func _loose(n: MeshInstance3D) -> MeshInstance3D:
	torso.add_child(n)
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


## local_vel = vitesse dans le repère du combattant (x = droite, -z = devant).
func apply(cur: FighterState, alpha: float, delta: float, moves: MoveSet, crouch_t: float,
		tilt: float, flash: float, flash_col: Color, local_vel: Vector3) -> void:
	_time += delta
	var speed := Vector2(local_vel.x, local_vel.z).length()
	var side := float(cur.guard)
	var dashing := cur.action == FighterState.Action.DASH
	var airborne := not cur.on_ground

	# Hanches : accroupi, respiration, rebond de marche.
	_phase += delta * speed * 2.6
	var bob := sin(_time * 2.2) * 0.012 + absf(sin(_phase)) * 0.03 * clampf(speed / 3.0, 0.0, 1.0)
	hips.position.y = lerpf(0.95, 0.62, crouch_t) + bob

	# Inclinaison dans le mouvement (devant/côté) + recul quand touché.
	var lean_target := Vector2(clampf(-local_vel.z * 0.045, -0.3, 0.45), clampf(-local_vel.x * 0.04, -0.3, 0.3))
	if dashing:
		lean_target *= 1.6
	if cur.action == FighterState.Action.BIND:
		lean_target.x = 0.35
	_lean = _lean.lerp(lean_target, 1.0 - exp(-delta * 10.0))
	hips.rotation = Vector3(-_lean.x + tilt, 0, _lean.y)

	# Jambes : posture (pied avant selon la garde), marche, dash, saut.
	var stance := 0.22
	var la := -stance * side
	var lb := stance * side
	if speed > 0.4 and not dashing and not airborne:
		var sw := sin(_phase) * 0.55 * clampf(speed / 3.0, 0.3, 1.0)
		la = sw
		lb = -sw
	if dashing:
		la = -0.7
		lb = 0.6
	if airborne:
		la = -0.6
		lb = -0.2
	la -= crouch_t * 0.6
	lb += crouch_t * 0.3
	leg_l.rotation = Vector3(la, 0, -0.06 - crouch_t * 0.15)
	leg_r.rotation = Vector3(lb, 0, 0.06 + crouch_t * 0.15)

	# Arme (mêmes poses que la vue FPS, placées devant le torse).
	var target: Array
	if cur.action == FighterState.Action.ATTACK and moves.has_move(cur.move_id):
		var frozen := cur.hitstop > 0 or cur.in_stance
		target = WeaponAnim.pose_for_move(moves.get_move(cur.move_id), float(cur.move_tick) + (0.0 if frozen else alpha), side)
		_pose = target
	else:
		target = WeaponAnim.state_pose(cur)
		_pose = target if _pose.is_empty() else WeaponAnim.lerp_pose(_pose, target, 1.0 - exp(-delta * 30.0))
	var grip: Vector3 = _pose[0]
	# Le buste suit le geste (torsion), pour des coups plus vivants.
	_twist = lerpf(_twist, clampf(grip.x * 1.1, -0.7, 0.7), 1.0 - exp(-delta * 14.0))
	torso.rotation = Vector3(0, -_twist, 0)
	var chest := Vector3(0, 0.5, 0)
	katana.transform = Transform3D(WeaponAnim.basis_from_dir(_pose[1]), chest + grip * 1.2)
	var ga := katana.transform * Vector3(0, -0.07, 0)
	var gb := katana.transform * Vector3(0, 0.07, 0)
	hand_r.position = gb
	hand_l.position = ga
	_limb(arm_r, Vector3(0.25 * side, 0.55, 0), gb)
	_limb(arm_l, Vector3(-0.25 * side, 0.55, 0), ga)

	# Tissus : le dos du manteau et l'écharpe traînent derrière le mouvement.
	var drag := clampf(speed / 6.0, 0.0, 1.5) + (0.6 if dashing else 0.0) + (0.4 if airborne else 0.0)
	var flutter := sin(_time * 9.0) * 0.12 * (0.3 + drag)
	# (rotation négative = le bas part vers l'arrière ; écharpe : 1.2 = pend, ~0.2 = flotte à l'horizontale)
	coat_back.rotation.x = -(deg_to_rad(8.0) + drag * 0.7 + flutter * 0.5)
	scarf_a.rotation = Vector3(1.2 - drag * 0.9 + flutter, 0.15 + local_vel.x * 0.05, 0)
	scarf_b.rotation = Vector3(1.3 - drag * 0.85 - flutter, -0.15 + local_vel.x * 0.05, 0)
	head.rotation.x = _lean.x * 0.5
	plume.rotation = Vector3(-0.7 + drag * 0.5 + flutter * 0.8, 0.0, 0.3)

	for i in _mats.size():
		_mats[i].albedo_color = _cols[i].lerp(flash_col, clampf(flash, 0.0, 1.0) * 0.85)


func _limb(arm: MeshInstance3D, a: Vector3, b: Vector3) -> void:
	var d := b - a
	var l := d.length()
	if l < 0.01:
		return
	var up := Vector3.UP if absf((d / l).dot(Vector3.UP)) < 0.98 else Vector3.FORWARD
	arm.transform = Transform3D(Basis.looking_at(d / l, up) * Basis.from_scale(Vector3(1, 1, l)), (a + b) * 0.5)
