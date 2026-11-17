class_name ArenaBuilder
extends RefCounted
## Construit l'arène placeholder : sol en damier, murs, torii, lanternes, ciel.


static func build(parent: Node3D, cfg: Dictionary) -> void:
	var half: float = cfg["arena"]["half_size"]
	_environment(parent)
	_floor(parent, half)
	_walls(parent, half)
	_torii(parent, Vector3(0, 0, -half - 4.0))
	for c in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
		_lantern(parent, Vector3(c.x * (half - 1.0), 0, c.y * (half - 1.0)))


static func _environment(parent: Node3D) -> void:
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.06, 0.06, 0.12)
	sky_mat.sky_horizon_color = Color(0.45, 0.22, 0.18)
	sky_mat.ground_horizon_color = Color(0.2, 0.12, 0.1)
	sky_mat.ground_bottom_color = Color(0.03, 0.03, 0.04)
	var sky := Sky.new()
	sky.sky_material = sky_mat

	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.45
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 1.2
	env.fog_enabled = true
	env.fog_light_color = Color(0.16, 0.1, 0.09)
	env.fog_density = 0.035
	env.fog_sky_affect = 0.6
	var we := WorldEnvironment.new()
	we.environment = env
	parent.add_child(we)

	var sun := DirectionalLight3D.new()
	sun.light_color = Color(1.0, 0.7, 0.5)
	sun.light_energy = 0.55
	sun.shadow_enabled = true
	sun.rotation = Vector3(deg_to_rad(-40.0), deg_to_rad(35.0), 0)
	parent.add_child(sun)


static func _floor(parent: Node3D, half: float) -> void:
	# Damier : aide énormément à juger les distances et les vitesses.
	var img := Image.create(64, 64, false, Image.FORMAT_RGB8)
	var c1 := Color(0.42, 0.33, 0.24)
	var c2 := Color(0.36, 0.28, 0.2)
	for y in 64:
		for x in 64:
			img.set_pixel(x, y, c1 if ((x / 32) + (y / 32)) % 2 == 0 else c2)
	img.generate_mipmaps()
	var tex := ImageTexture.create_from_image(img)

	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.roughness = 0.9
	m.uv1_scale = Vector3(half, half, 1.0)  # 1 case = 1 mètre
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS

	var plane := PlaneMesh.new()
	plane.size = Vector2(half * 2.0, half * 2.0)
	var floor_mi := MeshInstance3D.new()
	floor_mi.mesh = plane
	floor_mi.material_override = m
	parent.add_child(floor_mi)

	var outer := MeshInstance3D.new()
	var outer_plane := PlaneMesh.new()
	outer_plane.size = Vector2(300, 300)
	outer.mesh = outer_plane
	outer.material_override = MeshUtil.mat(Color(0.18, 0.2, 0.15))
	outer.position.y = -0.02
	parent.add_child(outer)


static func _walls(parent: Node3D, half: float) -> void:
	var wood := Color(0.3, 0.18, 0.12)
	var h := 1.4
	var t := 0.4
	var wall_len := half * 2.0 + t * 2.0
	for i in 4:
		var horizontal := i < 2
		var sgn := 1.0 if i % 2 == 0 else -1.0
		var size := Vector3(wall_len, h, t) if horizontal else Vector3(t, h, wall_len)
		var w := MeshUtil.box(size, wood)
		if horizontal:
			w.position = Vector3(0, h * 0.5, sgn * (half + t * 0.5))
		else:
			w.position = Vector3(sgn * (half + t * 0.5), h * 0.5, 0)
		parent.add_child(w)
		# Liseré blanc en haut du mur.
		var cap_size := Vector3(size.x + 0.05, 0.12, size.z + 0.05)
		var cap := MeshUtil.box(cap_size, Color(0.85, 0.82, 0.75))
		cap.position = w.position + Vector3(0, h * 0.5, 0)
		parent.add_child(cap)


static func _torii(parent: Node3D, at: Vector3) -> void:
	var red := Color(0.75, 0.12, 0.08)
	var black := Color(0.08, 0.06, 0.06)
	for x in [-3.0, 3.0]:
		var pillar := MeshUtil.cylinder(0.3, 6.0, red)
		pillar.position = at + Vector3(x, 3.0, 0)
		parent.add_child(pillar)
	var kasagi := MeshUtil.box(Vector3(9.5, 0.45, 0.7), black)
	kasagi.position = at + Vector3(0, 6.25, 0)
	parent.add_child(kasagi)
	var shimaki := MeshUtil.box(Vector3(8.8, 0.35, 0.6), red)
	shimaki.position = at + Vector3(0, 5.85, 0)
	parent.add_child(shimaki)
	var nuki := MeshUtil.box(Vector3(7.6, 0.3, 0.4), red)
	nuki.position = at + Vector3(0, 4.8, 0)
	parent.add_child(nuki)


static func _lantern(parent: Node3D, at: Vector3) -> void:
	var post := MeshUtil.box(Vector3(0.2, 1.6, 0.2), Color(0.45, 0.45, 0.42))
	post.position = at + Vector3(0, 0.8, 0)
	parent.add_child(post)
	var lamp := MeshUtil.box(Vector3(0.45, 0.5, 0.45), Color(1.0, 0.6, 0.25), 3.0)
	lamp.position = at + Vector3(0, 1.85, 0)
	parent.add_child(lamp)
	var roof := MeshUtil.box(Vector3(0.7, 0.12, 0.7), Color(0.3, 0.3, 0.28))
	roof.position = at + Vector3(0, 2.15, 0)
	parent.add_child(roof)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.65, 0.35)
	light.light_energy = 3.0
	light.omni_range = 9.0
	light.shadow_enabled = true
	light.position = at + Vector3(0, 1.9, 0)
	parent.add_child(light)
