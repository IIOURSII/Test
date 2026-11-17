class_name ArenaBuilder
extends RefCounted
## Construit le décor d'une map : ambiance, sol, limites, obstacles (d'après les données),
## zones/geysers, et décor propre au thème. Formes simples (placeholder) mais silhouettes lisibles.
## Renvoie un MapView qui anime ce qui bouge (geysers, lave).

## Ambiance par thème : ciel (haut, horizon), brouillard, soleil, sol (2 couleurs + motif), murs.
const THEMES := {
	"training": {"sky": [Color(0.06, 0.06, 0.12), Color(0.45, 0.22, 0.18)], "fog": Color(0.16, 0.1, 0.09), "fog_d": 0.035,
		"sun": Color(1.0, 0.7, 0.5), "sun_e": 0.55, "sun_rot": Vector2(-40, 35), "amb": 0.45,
		"floor": [Color(0.42, 0.33, 0.24), Color(0.36, 0.28, 0.2)], "pattern": "checker", "wall": Color(0.3, 0.18, 0.12)},
	"colisee": {"sky": [Color(0.25, 0.4, 0.62), Color(0.95, 0.75, 0.5)], "fog": Color(0.6, 0.48, 0.36), "fog_d": 0.012,
		"sun": Color(1.0, 0.88, 0.7), "sun_e": 1.2, "sun_rot": Vector2(-50, 30), "amb": 0.55,
		"floor": [Color(0.78, 0.66, 0.46), Color(0.72, 0.6, 0.41)], "pattern": "sand", "wall": Color(0.62, 0.55, 0.45)},
	"western": {"sky": [Color(0.3, 0.55, 0.85), Color(1.0, 0.8, 0.55)], "fog": Color(0.85, 0.65, 0.45), "fog_d": 0.015,
		"sun": Color(1.0, 0.93, 0.78), "sun_e": 1.4, "sun_rot": Vector2(-72, 20), "amb": 0.6,
		"floor": [Color(0.72, 0.55, 0.36), Color(0.66, 0.5, 0.32)], "pattern": "sand", "wall": Color(0.45, 0.3, 0.18)},
	"japon": {"sky": [Color(0.18, 0.15, 0.3), Color(0.98, 0.6, 0.5)], "fog": Color(0.55, 0.38, 0.4), "fog_d": 0.02,
		"sun": Color(1.0, 0.72, 0.6), "sun_e": 0.8, "sun_rot": Vector2(-22, 140), "amb": 0.5,
		"floor": [Color(0.66, 0.64, 0.6), Color(0.6, 0.58, 0.55)], "pattern": "gravel", "wall": Color(0.88, 0.85, 0.78)},
	"volcan": {"sky": [Color(0.06, 0.02, 0.02), Color(0.5, 0.12, 0.04)], "fog": Color(0.25, 0.07, 0.03), "fog_d": 0.04,
		"sun": Color(1.0, 0.4, 0.2), "sun_e": 0.35, "sun_rot": Vector2(-60, 10), "amb": 0.35,
		"floor": [Color(0.16, 0.12, 0.11), Color(0.12, 0.09, 0.09)], "pattern": "stone", "wall": Color(0.12, 0.08, 0.07)},
	"banque": {"sky": [Color(0.02, 0.02, 0.03), Color(0.06, 0.05, 0.04)], "fog": Color(0.08, 0.06, 0.03), "fog_d": 0.03,
		"sun": Color(1.0, 0.75, 0.4), "sun_e": 0.25, "sun_rot": Vector2(-80, 0), "amb": 0.25,
		"floor": [Color(0.24, 0.22, 0.2), Color(0.2, 0.18, 0.17)], "pattern": "tiles", "wall": Color(0.2, 0.19, 0.18)},
	"chateau": {"sky": [Color(0.04, 0.05, 0.08), Color(0.12, 0.14, 0.2)], "fog": Color(0.07, 0.08, 0.12), "fog_d": 0.025,
		"sun": Color(0.7, 0.8, 1.0), "sun_e": 0.3, "sun_rot": Vector2(-55, 60), "amb": 0.3,
		"floor": [Color(0.38, 0.37, 0.36), Color(0.32, 0.31, 0.3)], "pattern": "tiles", "wall": Color(0.33, 0.31, 0.3)},
}


static func build(parent: Node3D, map: MapData) -> MapView:
	var th: Dictionary = THEMES.get(map.theme, THEMES["training"])
	var view := MapView.new()
	parent.add_child(view)
	view.setup(map)
	_environment(view, th)
	_floor(view, map, th)
	_bounds(view, map, th)
	for b in map.boxes:
		_obstacle(view, b, map.theme)
	for z in map.zones:
		_zone(view, z)
	for g in map.geysers:
		view.add_geyser(g)
	match map.theme:
		"training": _decor_training(view, map)
		"colisee": _decor_colisee(view, map)
		"western": _decor_western(view, map)
		"japon": _decor_japon(view, map)
		"volcan": _decor_volcan(view, map)
		"banque": _decor_banque(view, map)
		"chateau": _decor_chateau(view, map)
	return view


# ------------------------------------------------------------ base

static func _environment(parent: Node3D, th: Dictionary) -> void:
	var sky_mat := ProceduralSkyMaterial.new()
	var sky_cols: Array = th["sky"]
	sky_mat.sky_top_color = sky_cols[0]
	sky_mat.sky_horizon_color = sky_cols[1]
	sky_mat.ground_horizon_color = (sky_cols[1] as Color).darkened(0.5)
	sky_mat.ground_bottom_color = (sky_cols[0] as Color).darkened(0.6)
	var sky := Sky.new()
	sky.sky_material = sky_mat
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = float(th["amb"])
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 1.0
	env.fog_enabled = true
	env.fog_light_color = th["fog"]
	env.fog_density = float(th["fog_d"])
	env.fog_sky_affect = 0.5
	var we := WorldEnvironment.new()
	we.environment = env
	parent.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.light_color = th["sun"]
	sun.light_energy = float(th["sun_e"])
	sun.shadow_enabled = true
	var rot: Vector2 = th["sun_rot"]
	sun.rotation = Vector3(deg_to_rad(rot.x), deg_to_rad(rot.y), 0)
	parent.add_child(sun)


## Texture de sol procédurale (petite, filtrée "nearest" = pixel art).
static func _floor_texture(c1: Color, c2: Color, pattern: String) -> ImageTexture:
	var img := Image.create(64, 64, false, Image.FORMAT_RGB8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1234
	for y in 64:
		for x in 64:
			var col := c1
			match pattern:
				"checker":
					col = c1 if ((x / 32) + (y / 32)) % 2 == 0 else c2
				"tiles":
					col = c1 if ((x / 32) + (y / 32)) % 2 == 0 else c2
					if x % 32 == 0 or y % 32 == 0:
						col = c1.darkened(0.45)
				"planks":
					col = c1 if (y / 8) % 2 == 0 else c2
					if y % 8 == 0 or (x + (y / 8) * 23) % 48 == 0:
						col = c1.darkened(0.5)
				"gravel":
					col = c1.lerp(c2, rng.randf())
					if rng.randf() < 0.06:
						col = c1.lightened(0.25)
				"stone":
					col = c1.lerp(c2, rng.randf())
					if rng.randf() < 0.03:
						col = Color(0.9, 0.3, 0.05)   # fissures incandescentes
				_:  # sand
					col = c1.lerp(c2, rng.randf() * 0.6 + (0.4 if (x + y * 3) % 17 < 3 else 0.0))
			img.set_pixel(x, y, col)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


static func _floor(parent: Node3D, map: MapData, th: Dictionary) -> void:
	var cols: Array = th["floor"]
	var m := StandardMaterial3D.new()
	m.albedo_texture = _floor_texture(cols[0], cols[1], th["pattern"])
	m.roughness = 0.9
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	var size := Vector2(map.half.x * 2.0, map.half.y * 2.0)
	if map.bounds_type == "circle":
		size = Vector2(map.radius * 2.0, map.radius * 2.0)
	m.uv1_scale = Vector3(size.x * 0.5, size.y * 0.5, 1.0)   # 1 case = 1 m
	var plane := PlaneMesh.new()
	plane.size = size + Vector2(8, 8)
	m.uv1_scale = Vector3((size.x + 8) * 0.5, (size.y + 8) * 0.5, 1.0)
	var fl := MeshInstance3D.new()
	fl.mesh = plane
	fl.material_override = m
	parent.add_child(fl)
	var outer := MeshInstance3D.new()
	var op := PlaneMesh.new()
	op.size = Vector2(400, 400)
	outer.mesh = op
	outer.material_override = MeshUtil.mat((cols[1] as Color).darkened(0.35))
	outer.position.y = -0.03
	parent.add_child(outer)


static func _bounds(parent: Node3D, map: MapData, th: Dictionary) -> void:
	var wall: Color = th["wall"]
	var h := 1.4
	if map.bounds_type == "circle":
		var n := 48
		var seg := TAU * (map.radius + 0.3) / float(n) + 0.05
		for k in n:
			var a := TAU * float(k) / float(n)
			var b := MeshUtil.box(Vector3(seg, h, 0.5), wall)
			b.position = Vector3(cos(a) * (map.radius + 0.25), h * 0.5, sin(a) * (map.radius + 0.25))
			b.rotation.y = -a + PI / 2.0
			parent.add_child(b)
		return
	var hx := map.half.x
	var hz := map.half.y
	for i in 4:
		var along_x := i < 2
		var sgn := 1.0 if i % 2 == 0 else -1.0
		var size := Vector3(hx * 2.0 + 1.0, h, 0.5) if along_x else Vector3(0.5, h, hz * 2.0 + 1.0)
		var w := MeshUtil.box(size, wall)
		w.position = Vector3(0, h * 0.5, sgn * (hz + 0.25)) if along_x else Vector3(sgn * (hx + 0.25), h * 0.5, 0)
		parent.add_child(w)


## Obstacles : la boîte de collision est exacte, seule l'apparence change selon "look".
static func _obstacle(parent: Node3D, b: Dictionary, theme: String) -> void:
	var mn: Vector3 = b["min"]
	var mx: Vector3 = b["max"]
	var size := mx - mn
	var c := Vector3((mn.x + mx.x) * 0.5, mn.y, (mn.z + mx.z) * 0.5)
	var root := Node3D.new()
	root.position = c
	parent.add_child(root)
	var r := minf(size.x, size.z) * 0.5
	match str(b["look"]):
		"column":
			_add(root, MeshUtil.cylinder(r * 0.82, size.y, Color(0.85, 0.8, 0.7)), Vector3(0, size.y * 0.5, 0))
			_add(root, MeshUtil.box(Vector3(size.x, 0.3, size.z), Color(0.75, 0.7, 0.6)), Vector3(0, 0.15, 0))
			_add(root, MeshUtil.box(Vector3(size.x, 0.3, size.z), Color(0.75, 0.7, 0.6)), Vector3(0, size.y - 0.15, 0))
		"well":
			_add(root, MeshUtil.cylinder(r, size.y, Color(0.5, 0.48, 0.45)), Vector3(0, size.y * 0.5, 0))
			_add(root, MeshUtil.cylinder(r * 0.75, 0.05, Color(0.1, 0.2, 0.3)), Vector3(0, size.y + 0.01, 0))
			for sd in [-1.0, 1.0]:
				_add(root, MeshUtil.box(Vector3(0.12, 1.4, 0.12), Color(0.4, 0.26, 0.15)), Vector3(sd * r * 0.9, size.y + 0.7, 0))
			_add(root, MeshUtil.box(Vector3(size.x * 1.2, 0.12, size.z * 0.9), Color(0.35, 0.2, 0.12)), Vector3(0, size.y + 1.45, 0))
		"trough":
			_add(root, MeshUtil.box(size, Color(0.42, 0.27, 0.15)), Vector3(0, size.y * 0.5, 0))
			_add(root, MeshUtil.box(Vector3(size.x * 0.8, 0.04, size.z * 0.9), Color(0.2, 0.35, 0.45)), Vector3(0, size.y + 0.01, 0))
		"barrels":
			for k in 3:
				var o := Vector3(cos(k * 2.1) * r * 0.45, 0, sin(k * 2.1) * r * 0.45)
				_add(root, MeshUtil.cylinder(r * 0.48, size.y, Color(0.45, 0.28, 0.14)), o + Vector3(0, size.y * 0.5, 0))
		"platform":
			_add(root, MeshUtil.box(size, Color(0.45, 0.3, 0.18)), Vector3(0, size.y * 0.5, 0))
			_add(root, MeshUtil.box(Vector3(size.x + 0.1, 0.06, size.z + 0.1), Color(0.25, 0.14, 0.08)), Vector3(0, size.y, 0))
			_add(root, MeshUtil.box(Vector3(size.x * 0.96, 0.02, size.z * 0.96), Color(0.62, 0.55, 0.36)), Vector3(0, size.y + 0.03, 0))
		"lantern":
			_add(root, MeshUtil.box(Vector3(size.x, 0.25, size.z), Color(0.5, 0.5, 0.48)), Vector3(0, 0.12, 0))
			_add(root, MeshUtil.cylinder(r * 0.35, size.y * 0.45, Color(0.55, 0.55, 0.52)), Vector3(0, size.y * 0.45, 0))
			_add(root, MeshUtil.box(Vector3(size.x * 0.7, 0.35, size.z * 0.7), Color(1.0, 0.75, 0.4), 1.5), Vector3(0, size.y * 0.75, 0))
			_add(root, MeshUtil.box(Vector3(size.x * 1.25, 0.15, size.z * 1.25), Color(0.45, 0.45, 0.43)), Vector3(0, size.y * 0.95, 0))
		"gold_pile":
			var gs := MeshUtil.sphere(0.5, Color(0.95, 0.75, 0.25))
			(gs.material_override as StandardMaterial3D).metallic = 0.9
			(gs.material_override as StandardMaterial3D).roughness = 0.3
			gs.scale = Vector3(size.x, size.y * 2.0, size.z)
			_add(root, gs, Vector3(0, 0, 0))
		"dwarf_pillar":
			_add(root, MeshUtil.box(size, Color(0.3, 0.29, 0.28)), Vector3(0, size.y * 0.5, 0))
			for hy in [0.6, size.y * 0.5, size.y - 0.6]:
				var band := MeshUtil.box(Vector3(size.x + 0.08, 0.25, size.z + 0.08), Color(0.9, 0.7, 0.25))
				(band.material_override as StandardMaterial3D).metallic = 0.9
				_add(root, band, Vector3(0, hy, 0))
		"castle_pillar":
			_add(root, MeshUtil.box(size, Color(0.42, 0.4, 0.38)), Vector3(0, size.y * 0.5, 0))
			_add(root, MeshUtil.box(Vector3(size.x * 1.3, 0.35, size.z * 1.3), Color(0.35, 0.33, 0.31)), Vector3(0, 0.17, 0))
			var banner := MeshUtil.box(Vector3(0.7, 1.8, 0.05), Color(0.55, 0.06, 0.08))
			var face := -signf(c.x) if absf(c.x) > 0.1 else 1.0
			banner.rotation.y = PI / 2.0
			_add(root, banner, Vector3(face * (size.x * 0.5 + 0.03), size.y * 0.6, 0))
		_:
			_add(root, MeshUtil.box(size, Color(0.5, 0.45, 0.4)), Vector3(0, size.y * 0.5, 0))


static func _zone(parent: Node3D, z: Dictionary) -> void:
	var c: Vector2 = z["center"]
	var mi: MeshInstance3D
	if z["type"] == "lava":
		mi = MeshUtil.cylinder(float(z["radius"]), 0.04, Color(1.0, 0.35, 0.05))
		var mm := mi.material_override as StandardMaterial3D
		mm.emission_enabled = true
		mm.emission = Color(1.0, 0.35, 0.05)
		mm.emission_energy_multiplier = 2.5
		mi.position = Vector3(c.x, 0.02, c.y)
		parent.add_child(mi)
		var rim := MeshUtil.cylinder(float(z["radius"]) + 0.25, 0.03, Color(0.08, 0.05, 0.05))
		rim.position = Vector3(c.x, 0.01, c.y)
		parent.add_child(rim)
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.45, 0.1)
		l.light_energy = 2.0
		l.omni_range = 5.0
		l.position = Vector3(c.x, 0.8, c.y)
		parent.add_child(l)
	elif z["type"] == "slippery":
		var h: Vector2 = z["half"]
		mi = MeshUtil.box(Vector3(h.x * 2.0, 0.03, h.y * 2.0), Color(0.95, 0.75, 0.25))
		var gm := mi.material_override as StandardMaterial3D
		gm.metallic = 0.9
		gm.roughness = 0.25
		mi.position = Vector3(c.x, 0.015, c.y)
		parent.add_child(mi)


static func _add(parent: Node3D, n: Node3D, pos: Vector3) -> Node3D:
	n.position = pos
	parent.add_child(n)
	return n


static func _light(parent: Node3D, pos: Vector3, col: Color, energy: float, rng: float) -> void:
	var l := OmniLight3D.new()
	l.light_color = col
	l.light_energy = energy
	l.omni_range = rng
	l.position = pos
	parent.add_child(l)


# ------------------------------------------------------------ décors par thème

static func _decor_training(p: Node3D, map: MapData) -> void:
	var red := Color(0.75, 0.12, 0.08)
	var at := Vector3(0, 0, -map.half.y - 4.0)
	for x in [-3.0, 3.0]:
		_add(p, MeshUtil.cylinder(0.3, 6.0, red), at + Vector3(x, 3.0, 0))
	_add(p, MeshUtil.box(Vector3(9.5, 0.45, 0.7), Color(0.08, 0.06, 0.06)), at + Vector3(0, 6.25, 0))
	_add(p, MeshUtil.box(Vector3(7.6, 0.3, 0.4), red), at + Vector3(0, 4.8, 0))
	for c in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
		var pos := Vector3(c.x * (map.half.x - 1.0), 0, c.y * (map.half.y - 1.0))
		_add(p, MeshUtil.box(Vector3(0.45, 0.5, 0.45), Color(1.0, 0.6, 0.25), 3.0), pos + Vector3(0, 1.85, 0))
		_add(p, MeshUtil.box(Vector3(0.2, 1.6, 0.2), Color(0.45, 0.45, 0.42)), pos + Vector3(0, 0.8, 0))
		_light(p, pos + Vector3(0, 1.9, 0), Color(1.0, 0.65, 0.35), 3.0, 9.0)


static func _decor_colisee(p: Node3D, map: MapData) -> void:
	var stone := Color(0.7, 0.62, 0.5)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var crowd := [Color(0.6, 0.15, 0.12), Color(0.85, 0.8, 0.7), Color(0.25, 0.3, 0.5), Color(0.5, 0.4, 0.2), Color(0.3, 0.45, 0.3)]
	for tier in 4:
		var rad := map.radius + 1.6 + tier * 1.6
		var hgt := 2.2 + tier * 1.3
		var n := 40 + tier * 6
		for k in n:
			var a := TAU * float(k) / float(n)
			var seg := TAU * rad / float(n) + 0.05
			var b := MeshUtil.box(Vector3(seg, hgt, 1.6), stone.darkened(0.08 * tier))
			b.position = Vector3(cos(a) * rad, hgt * 0.5, sin(a) * rad)
			b.rotation.y = -a + PI / 2.0
			p.add_child(b)
			if rng.randf() < 0.7:
				var sp := MeshUtil.box(Vector3(0.35, 0.6, 0.35), crowd[rng.randi() % crowd.size()])
				sp.position = Vector3(cos(a) * (rad - 0.3), hgt + 0.3, sin(a) * (rad - 0.3))
				p.add_child(sp)
	for k in 8:
		var a := TAU * float(k) / 8.0
		var ban := MeshUtil.box(Vector3(1.0, 2.2, 0.06), Color(0.6, 0.08, 0.08) if k % 2 == 0 else Color(0.85, 0.65, 0.2))
		ban.position = Vector3(cos(a) * (map.radius + 0.55), 2.6, sin(a) * (map.radius + 0.55))
		ban.rotation.y = -a + PI / 2.0
		p.add_child(ban)


static func _decor_western(p: Node3D, map: MapData) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var woods := [Color(0.5, 0.32, 0.18), Color(0.6, 0.45, 0.3), Color(0.42, 0.3, 0.22), Color(0.65, 0.55, 0.4)]
	for side in [-1.0, 1.0]:
		var z := -map.half.y
		while z < map.half.y:
			var w := rng.randf_range(4.0, 6.5)
			var h := rng.randf_range(4.0, 7.0)
			var col: Color = woods[rng.randi() % woods.size()]
			var x: float = side * (map.half.x + 2.2)
			_add(p, MeshUtil.box(Vector3(3.5, h, w - 0.3), col), Vector3(x, h * 0.5, z + w * 0.5))
			_add(p, MeshUtil.box(Vector3(0.2, h + 1.0, w - 0.3), col.darkened(0.15)), Vector3(x - side * 1.8, (h + 1.0) * 0.5, z + w * 0.5))
			for wy in [1.5, 3.3]:
				if wy < h - 0.5:
					_add(p, MeshUtil.box(Vector3(0.05, 0.9, 1.0), Color(0.08, 0.06, 0.05)), Vector3(x - side * 1.92, wy, z + w * 0.5))
			_add(p, MeshUtil.box(Vector3(1.4, 0.1, w - 0.3), col.darkened(0.3)), Vector3(x - side * 2.4, 2.6, z + w * 0.5))
			z += w
	# Enseigne du saloon et mesas au loin.
	_add(p, MeshUtil.box(Vector3(0.1, 0.9, 4.0), Color(0.25, 0.12, 0.06)), Vector3(map.half.x + 0.3, 5.5, 0))
	for k in 6:
		var a := TAU * float(k) / 6.0 + 0.3
		var s := rng.randf_range(10, 22)
		_add(p, MeshUtil.box(Vector3(s, s * 0.6, s), Color(0.7, 0.4, 0.25)), Vector3(cos(a) * 70, s * 0.3, sin(a) * 70))


static func _decor_japon(p: Node3D, map: MapData) -> void:
	var plaster := Color(0.9, 0.88, 0.82)
	var dark := Color(0.15, 0.1, 0.08)
	for i in 4:
		var along_x := i < 2
		var sgn := 1.0 if i % 2 == 0 else -1.0
		var wall_len := (map.half.x if along_x else map.half.y) * 2.0 + 4.0
		var size := Vector3(wall_len, 2.6, 0.5) if along_x else Vector3(0.5, 2.6, wall_len)
		var pos := Vector3(0, 1.3, sgn * (map.half.y + 1.5)) if along_x else Vector3(sgn * (map.half.x + 1.5), 1.3, 0)
		_add(p, MeshUtil.box(size, plaster), pos)
		_add(p, MeshUtil.box(size + Vector3(0.6, -2.3, 0.6), dark), pos + Vector3(0, 1.45, 0))
	var red := Color(0.78, 0.12, 0.08)
	var at := Vector3(0, 0, -map.half.y - 6.0)
	for x in [-3.0, 3.0]:
		_add(p, MeshUtil.cylinder(0.3, 6.5, red), at + Vector3(x, 3.25, 0))
	_add(p, MeshUtil.box(Vector3(10.0, 0.45, 0.7), dark), at + Vector3(0, 6.7, 0))
	_add(p, MeshUtil.box(Vector3(8.0, 0.3, 0.4), red), at + Vector3(0, 5.3, 0))
	for c in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
		var base := Vector3(c.x * (map.half.x + 4.0), 0, c.y * (map.half.y + 4.0))
		_add(p, MeshUtil.cylinder(0.25, 3.0, Color(0.3, 0.2, 0.15)), base + Vector3(0, 1.5, 0))
		for k in 4:
			var blossom := MeshUtil.sphere(1.3, Color(0.98, 0.7, 0.8))
			_add(p, blossom, base + Vector3(cos(k * 1.7) * 0.9, 3.4 + (k % 2) * 0.6, sin(k * 1.7) * 0.9))
	_light(p, Vector3(0, 3.0, 0), Color(1.0, 0.75, 0.5), 1.0, 10.0)


static func _decor_volcan(p: Node3D, map: MapData) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var lava := MeshUtil.box(Vector3(300, 0.1, 300), Color(1.0, 0.3, 0.05), 1.8)
	lava.position = Vector3(0, -0.6, 0)
	p.add_child(lava)
	for k in 36:
		var a := TAU * float(k) / 36.0
		var s := rng.randf_range(1.5, 3.5)
		var rh := rng.randf_range(1.5, 5.0)
		var rock := MeshUtil.box(Vector3(s, rh, s), Color(0.12, 0.08, 0.07))
		rock.position = Vector3(cos(a) * (map.radius + 1.6), rh * 0.5 - 0.3, sin(a) * (map.radius + 1.6))
		rock.rotation = Vector3(rng.randf_range(-0.2, 0.2), rng.randf(), rng.randf_range(-0.2, 0.2))
		p.add_child(rock)
	for k in 4:
		var a := TAU * float(k) / 4.0 + 0.4
		_add(p, MeshUtil.box(Vector3(14, 30, 14), Color(0.1, 0.06, 0.05)), Vector3(cos(a) * 45, 12, sin(a) * 45))
	_light(p, Vector3(0, 4, 0), Color(1.0, 0.4, 0.15), 1.5, 25.0)
	var ash := CPUParticles3D.new()
	ash.amount = 120
	ash.lifetime = 6.0
	ash.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	ash.emission_box_extents = Vector3(map.radius, 0.5, map.radius)
	ash.gravity = Vector3(0.3, 0.6, 0)
	ash.initial_velocity_max = 0.5
	var em := BoxMesh.new()
	em.size = Vector3(0.05, 0.05, 0.05)
	ash.mesh = em
	ash.material_override = MeshUtil.mat(Color(1.0, 0.5, 0.15), 3.0)
	ash.position = Vector3(0, 0.3, 0)
	p.add_child(ash)


static func _decor_banque(p: Node3D, map: MapData) -> void:
	var stone := Color(0.22, 0.21, 0.2)
	for i in 4:
		var along_x := i < 2
		var sgn := 1.0 if i % 2 == 0 else -1.0
		var wall_len := (map.half.x if along_x else map.half.y) * 2.0 + 2.0
		var size := Vector3(wall_len, 14.0, 1.0) if along_x else Vector3(1.0, 14.0, wall_len)
		var pos := Vector3(0, 7.0, sgn * (map.half.y + 1.0)) if along_x else Vector3(sgn * (map.half.x + 1.0), 7.0, 0)
		_add(p, MeshUtil.box(size, stone), pos)
	# Plafond, portes de coffre rondes (une de chaque côté = symétrique), torches.
	_add(p, MeshUtil.box(Vector3(map.half.x * 2 + 2, 0.5, map.half.y * 2 + 2), stone.darkened(0.3)), Vector3(0, 14, 0))
	for s in [-1.0, 1.0]:
		var door := MeshUtil.cylinder(3.0, 0.4, Color(0.8, 0.62, 0.25))
		(door.material_override as StandardMaterial3D).metallic = 0.85
		door.rotation.x = PI / 2.0
		_add(p, door, Vector3(0, 3.5, s * (map.half.y + 0.4)))
	for k in 8:
		var a := TAU * float(k) / 8.0
		var pos := Vector3(cos(a) * (map.half.x + 0.3), 2.8, sin(a) * (map.half.y + 0.3))
		pos.x = clampf(pos.x, -map.half.x - 0.3, map.half.x + 0.3)
		_add(p, MeshUtil.box(Vector3(0.25, 0.4, 0.25), Color(1.0, 0.6, 0.2), 3.0), pos)
		_light(p, pos, Color(1.0, 0.6, 0.25), 2.5, 9.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	for k in 30:
		var gold := MeshUtil.sphere(0.5, Color(0.95, 0.75, 0.25))
		(gold.material_override as StandardMaterial3D).metallic = 0.9
		var s := rng.randf_range(1.0, 3.0)
		gold.scale = Vector3(s, s * 0.5, s)
		var side := 1.0 if k % 2 == 0 else -1.0
		_add(p, gold, Vector3(side * (map.half.x - rng.randf_range(0.3, 1.0)), 0, rng.randf_range(-map.half.y, map.half.y)))


static func _decor_chateau(p: Node3D, map: MapData) -> void:
	var stone := Color(0.32, 0.31, 0.3)
	for i in 4:
		var along_x := i < 2
		var sgn := 1.0 if i % 2 == 0 else -1.0
		var wall_len := (map.half.x if along_x else map.half.y) * 2.0 + 2.0
		var size := Vector3(wall_len, 10.0, 1.0) if along_x else Vector3(1.0, 10.0, wall_len)
		var pos := Vector3(0, 5.0, sgn * (map.half.y + 1.0)) if along_x else Vector3(sgn * (map.half.x + 1.0), 5.0, 0)
		_add(p, MeshUtil.box(size, stone), pos)
	# Tapis (visuel seulement), trônes aux deux bouts (symétrie), vitraux, lustres.
	_add(p, MeshUtil.box(Vector3(2.4, 0.02, map.half.y * 2.0), Color(0.5, 0.05, 0.07)), Vector3(0, 0.01, 0))
	for s in [-1.0, 1.0]:
		_add(p, MeshUtil.box(Vector3(1.6, 2.6, 0.8), Color(0.7, 0.55, 0.2)), Vector3(0, 1.3, s * (map.half.y + 0.2)))
		for k in 3:
			var z := -8.0 + k * 8.0
			_add(p, MeshUtil.box(Vector3(0.1, 3.0, 1.2), Color(0.35, 0.5, 0.9), 1.5), Vector3(s * (map.half.x + 0.45), 5.0, z))
	for z in [-9.0, 0.0, 9.0]:
		var ring := MeshUtil.cylinder(1.2, 0.15, Color(0.25, 0.2, 0.15))
		_add(p, ring, Vector3(0, 6.5, z))
		for k in 6:
			var a := TAU * float(k) / 6.0
			_add(p, MeshUtil.box(Vector3(0.1, 0.25, 0.1), Color(1.0, 0.8, 0.5), 3.0), Vector3(cos(a) * 1.1, 6.75, z + sin(a) * 1.1))
		_light(p, Vector3(0, 6.2, z), Color(1.0, 0.75, 0.45), 2.5, 12.0)
