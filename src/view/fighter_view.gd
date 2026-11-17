class_name FighterView
extends Node3D
## Un combattant vu de l'extérieur, en SPRITE 2D qui "tourne" en fausse 3D (8 directions),
## comme les sprites de Pokémon/Doom dans un monde 3D.
## Technique : un petit Puppet cel-shadé est photographié en basse résolution depuis l'angle
## d'où on le regarde (arrondi à 45°), puis affiché sur un panneau toujours face à la caméra.
## Toutes les animations (coups, garde, sonné...) marchent donc automatiquement.

const VP := 72               ## résolution du sprite (pixels) : bas = gros pixels
const SPRITE_H := 2.7        ## hauteur couverte par le sprite (mètres)
const DIRECTIONS := 8

var view_camera: Camera3D    ## la caméra qui regarde ce sprite (null = caméra active)
var sprite: Sprite3D
var puppet: Puppet
var _vp: SubViewport
var _cam: Camera3D
var _shadow: MeshInstance3D
var _cfg: Dictionary
var _flash: float = 0.0
var _flash_color: Color = Color.WHITE
var _recoil: float = 0.0
var _turn: float = 0.0
var _ghost_t: float = 0.0
var _layer_bit: int = 1


## layer_bit : couche de rendu du sprite (pour qu'un joueur ne voie pas son propre sprite).
func setup(cfg: Dictionary, color: Color, layer_bit: int = 1, accent: Color = Color(0, 0, 0, 0), model: String = "katana") -> void:
	_cfg = cfg
	_layer_bit = layer_bit
	if accent.a == 0.0:
		accent = color.lightened(0.35) if color.get_luminance() < 0.35 else color.darkened(0.45)
	_vp = SubViewport.new()
	_vp.size = Vector2i(VP, VP)
	_vp.transparent_bg = true
	_vp.own_world_3d = true
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_vp)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.38, 0.36, 0.48)
	env.ambient_light_energy = 1.0
	var we := WorldEnvironment.new()
	we.environment = env
	_vp.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-50), deg_to_rad(30), 0)
	sun.light_energy = 1.15
	sun.light_color = Color(1.0, 0.88, 0.75)
	_vp.add_child(sun)
	var rim := DirectionalLight3D.new()
	rim.rotation = Vector3(deg_to_rad(-15), deg_to_rad(200), 0)
	rim.light_color = Color(0.35, 0.8, 1.0)
	rim.light_energy = 1.4
	_vp.add_child(rim)
	puppet = Puppet.new()
	_vp.add_child(puppet)
	puppet.setup(color, accent, model)
	_cam = Camera3D.new()
	_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	_cam.keep_aspect = Camera3D.KEEP_HEIGHT
	_cam.size = SPRITE_H
	_cam.far = 30.0
	_cam.current = true
	_vp.add_child(_cam)
	_vp.add_child(InkOutline.create(1.0, 100.0))

	sprite = Sprite3D.new()
	sprite.texture = _vp.get_texture()
	sprite.pixel_size = SPRITE_H / float(VP)
	sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.shaded = false
	sprite.double_sided = true
	sprite.position.y = SPRITE_H * 0.5 - 0.15
	sprite.layers = layer_bit
	add_child(sprite)

	# Ombre ronde sous les pieds (ancre le sprite au sol).
	_shadow = MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.45
	cm.bottom_radius = 0.45
	cm.height = 0.01
	_shadow.mesh = cm
	var sm := StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.albedo_color = Color(0, 0, 0, 0.4)
	_shadow.material_override = sm
	_shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_shadow)


## Flash quand il est touché.
func flash(power: float = 1.0, color: Color = Color.WHITE, recoil: bool = true) -> void:
	_flash = 1.0
	_flash_color = color
	if recoil:
		_recoil = maxf(_recoil, 0.6 + 0.6 * power)


## Image rémanente : une copie figée du sprite qui s'efface sur place.
func ghost(tint: Color, life: float = 0.28) -> void:
	var img := _vp.get_texture().get_image()
	if img == null or get_parent() == null:
		return
	var g := Sprite3D.new()
	g.texture = ImageTexture.create_from_image(img)
	g.pixel_size = sprite.pixel_size
	g.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	g.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	g.shaded = false
	g.double_sided = true
	g.modulate = tint
	g.layers = _layer_bit
	get_parent().add_child(g)
	g.global_position = sprite.global_position
	var tw := g.create_tween()
	tw.tween_property(g, "modulate:a", 0.0, life)
	tw.tween_callback(g.queue_free)


func update_view(prev: FighterState, cur: FighterState, alpha: float, delta: float, moves: MoveSet) -> void:
	var fcfg: Dictionary = _cfg["fighter"]
	var frozen := cur.hitstop > 0
	position = cur.pos if frozen else prev.pos.lerp(cur.pos, alpha)
	if frozen and cur.action == FighterState.Action.HITSTUN:
		position += Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)) * 0.05
	_shadow.global_position = Vector3(position.x, cur.floor_y + 0.02, position.z)
	var air := clampf((position.y - cur.floor_y) / 2.0, 0.0, 1.0)
	_shadow.scale = Vector3.ONE * (1.0 - air * 0.5)

	var turn_target := 0.0
	if cur.action == FighterState.Action.ATTACK and moves.has_move(cur.move_id) and moves.get_move(cur.move_id)["turn_back"]:
		turn_target = PI
	_turn = lerp_angle(_turn, turn_target, 1.0 - exp(-delta * 9.0))
	var yaw := lerp_angle(prev.yaw_rad(), cur.yaw_rad(), alpha) + _turn

	_recoil = move_toward(_recoil, 0.0, delta * 3.0)
	_flash = move_toward(_flash, 0.0, delta * 8.0)
	var tilt := (0.12 if cur.action == FighterState.Action.HITSTUN else 0.0) + 0.3 * _recoil
	var crouch_t := lerpf(prev.crouch, cur.crouch, alpha) / float(FighterLogic.CROUCH_TICKS)
	var local_vel := Basis(Vector3.UP, yaw).inverse() * cur.vel
	puppet.apply(cur, alpha, delta, moves, crouch_t, tilt, _flash, _flash_color, local_vel)

	# Images rémanentes pendant les dashs (style anime).
	if cur.action == FighterState.Action.DASH:
		_ghost_t += delta
		if _ghost_t > 0.045:
			_ghost_t = 0.0
			ghost(Color(0.75, 0.85, 1.0, 0.45))
	else:
		_ghost_t = 1.0

	# Angle de vue arrondi à 45° : c'est ce qui donne l'effet "sprite qui tourne".
	var cam := view_camera if view_camera else get_viewport().get_camera_3d()
	var snapped := 0.0
	if cam:
		var to_cam := cam.global_position - global_position
		var local := Basis(Vector3.UP, yaw).inverse() * to_cam
		var step := TAU / float(DIRECTIONS)
		snapped = roundf(atan2(local.x, local.z) / step) * step
	var cy := SPRITE_H * 0.5 - 0.15
	_cam.position = Vector3(sin(snapped) * 8.0, cy, cos(snapped) * 8.0)
	_cam.look_at(Vector3(0, cy, 0), Vector3.UP)
