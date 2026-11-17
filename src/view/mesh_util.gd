class_name MeshUtil
extends RefCounted
## Petites fonctions pour fabriquer des formes simples (graphismes placeholder).


## Matériau "cel" (éclairage en 2 tons) : la DA du jeu, utilisée par tout le décor et les persos.
static func mat(color: Color, emission: float = 0.0, roughness: float = 0.8) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	m.specular_mode = BaseMaterial3D.SPECULAR_TOON
	# Liseré lumineux sur les bords éclairés en contre-jour (look Dead Cells).
	m.rim_enabled = true
	m.rim = 0.35
	m.rim_tint = 0.7
	if emission > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = emission
	return m


static func box(size: Vector3, color: Color, emission: float = 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat(color, emission)
	return mi


static func cylinder(radius: float, height: float, color: Color, emission: float = 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = height
	mi.mesh = cm
	mi.material_override = mat(color, emission)
	return mi


static func sphere(radius: float, color: Color, emission: float = 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = radius
	sm.height = radius * 2.0
	mi.mesh = sm
	mi.material_override = mat(color, emission)
	return mi


static func capsule(radius: float, height: float, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CapsuleMesh.new()
	cm.radius = radius
	cm.height = height
	mi.mesh = cm
	mi.material_override = mat(color)
	return mi


## Katana placeholder. L'origine = la poignée, la lame pointe vers +Y.
static func katana() -> Node3D:
	var root := Node3D.new()
	root.name = "Katana"
	var handle := box(Vector3(0.035, 0.26, 0.035), Color(0.12, 0.08, 0.07))
	handle.name = "Handle"
	root.add_child(handle)
	var tsuba := cylinder(0.05, 0.012, Color(0.55, 0.45, 0.2))
	tsuba.name = "Tsuba"
	tsuba.position = Vector3(0, 0.135, 0)
	root.add_child(tsuba)
	var blade := box(Vector3(0.008, 0.78, 0.032), Color(0.85, 0.87, 0.9))
	(blade.material_override as StandardMaterial3D).metallic = 0.9
	(blade.material_override as StandardMaterial3D).roughness = 0.25
	blade.name = "Blade"
	blade.position = Vector3(0, 0.53, 0)
	root.add_child(blade)
	return root


## Modèle d'arme selon son nom. Origine = la poignée (là où sont les mains), axe +Y = vers la pointe.
## Chaque modèle a un nœud "Blade" (la partie qui frappe : lueurs, aura) et des métadonnées :
##   "trail" = Vector2(début, fin) de la traînée le long de +Y ; "dual" = une arme dans chaque main.
static func weapon(model: String) -> Node3D:
	match model:
		"tanto":
			return _tanto()
		"naginata":
			return _naginata()
		"kanabo":
			return _kanabo()
	var k := katana()
	k.set_meta("trail", Vector2(0.2, 0.92))
	k.set_meta("dual", false)
	return k


static func _steel(mi: MeshInstance3D) -> MeshInstance3D:
	var m := mi.material_override as StandardMaterial3D
	m.metallic = 0.9
	m.roughness = 0.25
	return mi


static func _tanto() -> Node3D:
	var root := Node3D.new()
	root.name = "Tanto"
	root.add_child(box(Vector3(0.03, 0.13, 0.03), Color(0.1, 0.06, 0.08)))
	var guard := box(Vector3(0.06, 0.012, 0.04), Color(0.7, 0.6, 0.3))
	guard.position = Vector3(0, 0.07, 0)
	root.add_child(guard)
	var blade := _steel(box(Vector3(0.008, 0.32, 0.03), Color(0.86, 0.88, 0.92)))
	blade.name = "Blade"
	blade.position = Vector3(0, 0.235, 0)
	root.add_child(blade)
	root.set_meta("trail", Vector2(0.1, 0.4))
	root.set_meta("dual", true)
	return root


static func _naginata() -> Node3D:
	var root := Node3D.new()
	root.name = "Naginata"
	var shaft := cylinder(0.028, 1.95, Color(0.32, 0.12, 0.08))
	shaft.position = Vector3(0, 0.05, 0)
	root.add_child(shaft)
	for y in [-0.6, -0.2, 0.6]:
		var band := cylinder(0.034, 0.05, Color(0.1, 0.08, 0.06))
		band.position = Vector3(0, y, 0)
		root.add_child(band)
	var butt := cylinder(0.035, 0.08, Color(0.7, 0.6, 0.3))
	butt.position = Vector3(0, -0.92, 0)
	root.add_child(butt)
	var collar := cylinder(0.045, 0.05, Color(0.7, 0.6, 0.3))
	collar.position = Vector3(0, 1.03, 0)
	root.add_child(collar)
	var blade := _steel(box(Vector3(0.012, 0.58, 0.06), Color(0.86, 0.88, 0.92)))
	blade.name = "Blade"
	blade.position = Vector3(0.015, 1.34, 0)
	blade.rotation.z = -0.08   # légère courbure
	root.add_child(blade)
	root.set_meta("trail", Vector2(1.05, 1.62))
	root.set_meta("dual", false)
	return root


static func _kanabo() -> Node3D:
	var root := Node3D.new()
	root.name = "Kanabo"
	root.add_child(cylinder(0.035, 0.4, Color(0.18, 0.1, 0.06)))
	var club := cylinder(0.15, 1.05, Color(0.2, 0.18, 0.18))
	(club.mesh as CylinderMesh).bottom_radius = 0.075
	(club.mesh as CylinderMesh).radial_segments = 8
	club.name = "Blade"
	club.position = Vector3(0, 0.72, 0)
	root.add_child(club)
	for ring in 4:
		for k in 6:
			var a := TAU * float(k) / 6.0 + ring * 0.5
			var rad := lerpf(0.09, 0.15, float(ring) / 3.0)
			var stud := _steel(box(Vector3(0.05, 0.05, 0.05), Color(0.7, 0.68, 0.65)))
			stud.position = Vector3(cos(a) * rad, 0.4 + ring * 0.24, sin(a) * rad)
			root.add_child(stud)
	root.set_meta("trail", Vector2(0.3, 1.22))
	root.set_meta("dual", false)
	return root
