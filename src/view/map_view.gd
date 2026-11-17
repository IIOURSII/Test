class_name MapView
extends Node3D
## Racine du décor d'une map + animation de ce qui bouge (geysers, lueur de la lave).
## Lit seulement le tick de la simulation : l'affichage annonce exactement ce que la simulation fera.

var map: MapData
var _geysers: Array = []   ## [{"data", "crater_mat", "column", "light", "smoke"}]


func setup(m: MapData) -> void:
	map = m


func add_geyser(g: Dictionary) -> void:
	var gp: Vector2 = g["pos"]
	var r := float(g["radius"])
	var crater := MeshUtil.cylinder(r, 0.05, Color(0.08, 0.05, 0.04))
	crater.position = Vector3(gp.x, 0.03, gp.y)
	add_child(crater)
	var cm := crater.material_override as StandardMaterial3D
	cm.emission_enabled = true
	cm.emission = Color(1.0, 0.35, 0.05)
	var col := MeshUtil.cylinder(r * 0.8, 1.0, Color(1.0, 0.55, 0.15), 3.5)
	col.position = Vector3(gp.x, 0.0, gp.y)
	col.visible = false
	add_child(col)
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.45, 0.1)
	l.omni_range = 7.0
	l.position = Vector3(gp.x, 1.0, gp.y)
	add_child(l)
	_geysers.append({"data": g, "crater_mat": cm, "column": col, "light": l})


## tick = tick de simulation (avec fraction pour l'animation).
func update_tick(tick: float) -> void:
	var t := int(tick)
	for e in _geysers:
		var g: Dictionary = e["data"]
		var st := map.geyser_state(g, t)
		var cm: StandardMaterial3D = e["crater_mat"]
		var col: MeshInstance3D = e["column"]
		var l: OmniLight3D = e["light"]
		match st:
			0:
				cm.emission_energy_multiplier = 0.2
				col.visible = false
				l.light_energy = 0.2
			1:
				# Grondement : la lueur pulse de plus en plus vite.
				var pulse := 0.5 + 0.5 * sin(tick * 0.6)
				cm.emission_energy_multiplier = 1.0 + 2.5 * pulse
				col.visible = false
				l.light_energy = 1.0 + 2.0 * pulse
			2:
				cm.emission_energy_multiplier = 4.0
				col.visible = true
				var h := 6.0 + sin(tick * 1.3) * 0.6
				col.scale = Vector3(1, h, 1)
				col.position.y = h * 0.5
				l.light_energy = 6.0
