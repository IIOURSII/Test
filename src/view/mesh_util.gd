class_name MeshUtil
extends RefCounted
## Petites fonctions pour fabriquer des formes simples (graphismes placeholder).


static func mat(color: Color, emission: float = 0.0, roughness: float = 0.8) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
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


static func cylinder(radius: float, height: float, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = height
	mi.mesh = cm
	mi.material_override = mat(color)
	return mi


static func sphere(radius: float, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = radius
	sm.height = radius * 2.0
	mi.mesh = sm
	mi.material_override = mat(color)
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
