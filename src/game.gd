class_name Game
extends Node3D
## Un combat : assemble la simulation, les inputs, les visuels et l'UI de jeu.
## Créé par App (src/app.gd) avec les choix des menus (arme, classe, map, mode).
##
## Chaque tick logique (60/s, _physics_process) :
##   1. on garde une copie de l'état précédent (pour lisser l'affichage)
##   2. chaque "contrôleur" (joueur, mannequin, IA...) donne son InputFrame
##   3. la simulation avance d'un tick
## Chaque image affichée (_process, autant que l'écran le permet) :
##   on dessine l'état interpolé entre le tick précédent et le tick actuel.

signal quit_to_menu

const COMBAT_CFG := "res://data/config/combat.json"
const CONTROLS_CFG := "res://data/config/controls.json"
const GRAPHICS_CFG := "res://data/config/graphics.json"

var cfg: Dictionary
var controls: Dictionary
var world: SimWorld
var prev_states: Array[FighterState] = []
var katana: MoveSet
var weapon_path: String = "res://data/weapons/katana.json"
var map: MapData
var map_view: MapView
var params: Dictionary = {}

var collector: InputCollector      ## joueur 1 : clavier/souris
var pad: GamepadCollector          ## joueur 2 en local : manette
var ai: AiController               ## adversaire en mode Duel
var dummy: DummyController         # DEBUG (mode bac à sable)
var fp_views: Array[FirstPersonView] = []    ## une vue FPS par joueur humain
var fp_view: FirstPersonView                 ## raccourci : celle du joueur 1
var fighter_views: Array[FighterView] = []   ## les sprites des deux combattants
var debug_draw: DebugDraw          # DEBUG
var hud: Hud
var move_list: MoveList
var fx: Fx
var sfx: Sfx
var post: PostProcess
var pause_menu: PauseMenu
var options_menu: OptionsMenu
var results: ResultsScreen
var split_layer: CanvasLayer
var paused: bool = false
var show_debug: bool = true
var _pending_events: Array = []

# --- Match (modes Duel et Local) ---
const ROUNDS_TO_WIN := 2
## Couleurs des combattants : manteau / écharpe (et yeux).
const PLAYER_COLORS := [Color(0.2, 0.25, 0.5), Color(0.55, 0.1, 0.1)]
const PLAYER_ACCENTS := [Color(0.98, 0.78, 0.3), Color(0.95, 0.95, 0.9)]
var mode: String = "sandbox"       ## "sandbox" (debug), "duel_ai", "local"
var difficulty: String = "normal"
var match_state: String = "fight"  ## "intro", "fight", "ko", "between", "over"
var state_ticks: int = 0
var round_num: int = 1
var score: Array[int] = [0, 0]
var _ko_winner: int = -1
var cine_cam: Camera3D


## params : {"weapon", "class", "map", "mode": "sandbox"/"duel_ai"/"local", "difficulty"}
func setup(post_process: PostProcess, shared_sfx: Sfx, p: Dictionary) -> void:
	params = p
	post = post_process
	sfx = shared_sfx
	mode = str(p.get("mode", "sandbox"))
	difficulty = str(p.get("difficulty", "normal"))
	show_debug = mode == "sandbox"
	cfg = DataLoader.load_json(COMBAT_CFG)
	controls = DataLoader.load_json(CONTROLS_CFG)
	ControlsSetup.apply(controls)
	weapon_path = "res://data/weapons/%s.json" % str(p.get("weapon", "katana"))
	katana = _load_weapon(weapon_path)

	var map_id := str(p.get("map", "training"))
	map = MapData.from_json(map_id, DataLoader.load_json("res://data/maps/%s.json" % map_id))
	map_view = ArenaBuilder.build(self, map)
	_new_world()

	collector = InputCollector.new()
	add_child(collector)
	collector.setup(controls, map.spawn_yaw(0))
	collector.sensitivity = float(Settings.get_value("sensitivity"))
	dummy = DummyController.new()
	if mode == "duel_ai":
		ai = AiController.new()
		var profiles := DataLoader.load_json("res://data/ai.json")
		ai.setup(profiles.get(difficulty, profiles.get("normal", {})), 12345)
		ai.reset(map.spawn_yaw(1))
	if mode == "local":
		pad = GamepadCollector.new()
		add_child(pad)
		var pads := Input.get_connected_joypads()
		pad.setup(pads[0] if pads.size() > 0 else 0, map.spawn_yaw(1))

	# Vues FPS (une par humain) et sprites des deux combattants.
	for i in 2:
		var fv := FighterView.new()
		add_child(fv)
		fv.setup(cfg, PLAYER_COLORS[i], 1 << (1 + i), PLAYER_ACCENTS[i])
		fighter_views.append(fv)
	if mode == "local":
		_setup_split()
	else:
		var v := FirstPersonView.new()
		add_child(v)
		v.setup(cfg, PLAYER_COLORS[0], PLAYER_ACCENTS[0])
		fp_views.append(v)
	for k in fp_views.size():
		fp_views[k].camera.cull_mask = 0xFFFFF & ~(1 << (1 + k))   # on ne voit pas son propre sprite
	fp_view = fp_views[0]
	_assign_viewers()

	debug_draw = DebugDraw.new()
	add_child(debug_draw)
	debug_draw.setup()

	hud = Hud.new()
	add_child(hud)
	hud.setup()
	hud.configure(_names(), mode == "local", mode == "sandbox")

	move_list = MoveList.new()
	add_child(move_list)
	move_list.setup()

	fx = Fx.new()
	add_child(fx)
	fx.setup()

	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if mode == "sandbox":
		hud.popup(map.name.to_upper(), Color(0.95, 0.9, 0.8), map.kanji)
	else:
		_start_round(true)
	if mode == "local" and not pad.is_pad_connected():
		hud.message("Aucune manette détectée pour le Joueur 2 — branche une manette (le J2 joue à la manette).")


func _names() -> Array:
	match mode:
		"duel_ai":
			return ["TOI", "IA — %s" % difficulty.to_upper()]
		"local":
			return ["JOUEUR 1", "JOUEUR 2"]
	return ["TOI", "MANNEQUIN"]


func _new_world() -> void:
	world = SimWorld.new(cfg, map)
	world.add_fighter(map.spawns[0], map.spawn_yaw(0), katana)
	world.add_fighter(map.spawns[1], map.spawn_yaw(1), katana)
	if mode == "sandbox":
		world.training_dummies.assign([0, 1])
	prev_states = world.snapshot()


## Écran partagé : deux vues côte à côte sur le même monde.
func _setup_split() -> void:
	split_layer = CanvasLayer.new()
	split_layer.layer = -3
	add_child(split_layer)
	var hb := HBoxContainer.new()
	hb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hb.add_theme_constant_override("separation", 4)
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	split_layer.add_child(hb)
	for k in 2:
		var cont := SubViewportContainer.new()
		cont.stretch = true
		cont.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cont.size_flags_vertical = Control.SIZE_EXPAND_FILL
		cont.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hb.add_child(cont)
		var vp := SubViewport.new()
		vp.world_3d = get_viewport().world_3d
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		cont.add_child(vp)
		var v := FirstPersonView.new()
		vp.add_child(v)
		v.setup(cfg, PLAYER_COLORS[k], PLAYER_ACCENTS[k])
		fp_views.append(v)


## Chaque sprite est "photographié" depuis la caméra qui le regarde.
func _assign_viewers() -> void:
	for i in 2:
		var viewer: Camera3D = null
		if cine_cam:
			viewer = cine_cam
		elif mode == "local":
			viewer = fp_views[1 - i].camera
		else:
			viewer = fp_views[0].camera
		fighter_views[i].view_camera = viewer


func _fp(i: int) -> FirstPersonView:
	return fp_views[i] if i >= 0 and i < fp_views.size() else null


func _physics_process(_delta: float) -> void:
	if paused:
		return
	_update_match()
	prev_states = world.snapshot()
	var inputs: Array = [_input_for(0), _input_for(1)]
	world.step(inputs)
	hud.record_input(inputs[0])
	_pending_events.append_array(world.events)


func _input_for(i: int) -> InputFrame:
	var frame: InputFrame
	if i == 0:
		frame = collector.poll()
	elif mode == "local":
		frame = pad.poll()
	elif mode == "duel_ai":
		frame = ai.poll(world, 1, 0)
	else:
		frame = dummy.poll(world, 1, 0)
	if match_state != "fight":
		# Intro / KO / fin : personne ne bouge, on regarde l'adversaire.
		var f := world.fighters[i]
		frame = InputFrame.new(0, f.yaw if match_state != "intro" else InputFrame.yaw_to_int(map.spawn_yaw(i)), 0)
	return frame


func _process(delta: float) -> void:
	var a := Engine.get_physics_interpolation_fraction()
	if paused:
		a = 0.0
	map_view.update_tick(float(world.tick) + a)
	for e in _pending_events:
		_play_event(e)
	_pending_events.clear()

	for k in fp_views.size():
		var look := Vector2(collector.look_yaw, collector.look_pitch)
		if k == 1 and pad:
			look = Vector2(pad.look_yaw, pad.look_pitch)
		fp_views[k].update_view(prev_states[k], world.fighters[k], a, look.x, look.y, delta, world.movesets[k])
	for i in 2:
		fighter_views[i].update_view(prev_states[i], world.fighters[i], a, delta, world.movesets[i])
	if cine_cam:
		cine_cam.position += cine_cam.global_transform.basis.x * delta * 0.35
	debug_draw.redraw(world, show_debug and mode == "sandbox")
	hud.update_hud(world, show_debug and mode == "sandbox", collector.is_captured(), dummy.mode_name())
	hud.set_rounds(score, ROUNDS_TO_WIN)
	move_list.refresh(world.movesets[0], world.fighters[0].guard, controls)


# ------------------------------------------------------------ déroulé d'un match

func _start_round(first: bool) -> void:
	if not first:
		_new_world()
	match_state = "intro"
	state_ticks = 0
	collector.look_yaw = map.spawn_yaw(0)
	collector.look_pitch = 0.0
	if pad:
		pad.look_yaw = map.spawn_yaw(1)
		pad.look_pitch = 0.0
	if ai:
		ai.reset(map.spawn_yaw(1))
	var kanji := ["一", "二", "三", "四", "五"]
	hud.popup("ROUND %d" % round_num, Color(0.95, 0.9, 0.8), kanji[mini(round_num - 1, 4)])


func _update_match() -> void:
	if mode == "sandbox":
		return
	state_ticks += 1
	match match_state:
		"intro":
			var dur := 150 if round_num == 1 else 90
			# Premier round : chacun fait le geste propre à son arme (le kata du katana).
			if round_num == 1 and state_ticks == 8:
				for f in world.fighters:
					FighterLogic.start_move(f, "taunt", world.movesets[f.id], cfg, Vector3.ZERO)
			if state_ticks >= dur:
				match_state = "fight"
				state_ticks = 0
				hud.popup("HAJIME", Color(1.0, 0.85, 0.4), "始")
				sfx.play("shing", 0.0, 0.0)
		"fight":
			var dead0 := world.fighters[0].hp <= 0
			var dead1 := world.fighters[1].hp <= 0
			if dead0 or dead1:
				_ko_winner = -1 if (dead0 and dead1) else (1 if dead0 else 0)
				match_state = "ko"
				state_ticks = 0
				Engine.time_scale = 0.3
				_start_cinematic()
				hud.popup("KETCHAKU", Color(1.0, 0.2, 0.15), "決着")
				post.impact_frame(Color(1.0, 0.15, 0.1), true, 0.15)
				sfx.play("hit_heavy", 4.0, 0.0)
		"ko":
			if state_ticks >= 55:
				Engine.time_scale = 1.0
				_stop_cinematic()
				if _ko_winner >= 0:
					score[_ko_winner] += 1
				match_state = "between"
				state_ticks = 0
				if _ko_winner >= 0 and score[_ko_winner] >= ROUNDS_TO_WIN:
					match_state = "over"
					_show_results(_ko_winner)
		"between":
			if state_ticks >= 50:
				round_num += 1
				_start_round(false)


## Coup final au ralenti : caméra basse, de côté, qui glisse doucement.
func _start_cinematic() -> void:
	var a := world.fighters[0].pos
	var b := world.fighters[1].pos
	var mid := (a + b) * 0.5
	var d := (b - a)
	d.y = 0.0
	d = d.normalized() if d.length() > 0.01 else Vector3.FORWARD
	var perp := d.cross(Vector3.UP).normalized()
	cine_cam = Camera3D.new()
	cine_cam.fov = 50.0
	add_child(cine_cam)
	cine_cam.global_position = mid + perp * 3.4 + Vector3(0, 0.45, 0) - d * 0.6
	cine_cam.look_at(mid + Vector3(0, 1.25, 0), Vector3.UP)
	cine_cam.current = true
	for v in fp_views:
		v.arms_overlay.visible = false
	if split_layer:
		split_layer.visible = false
	_assign_viewers()


func _stop_cinematic() -> void:
	if cine_cam:
		cine_cam.queue_free()
		cine_cam = null
	for v in fp_views:
		v.arms_overlay.visible = true
	if split_layer:
		split_layer.visible = true
	elif not fp_views.is_empty():
		fp_views[0].camera.current = true
	_assign_viewers()


func _show_results(winner: int) -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	collector.set_process_input(false)
	results = ResultsScreen.new()
	add_child(results)
	var title := ""
	var good := true
	match mode:
		"duel_ai":
			title = "VICTOIRE" if winner == 0 else "DÉFAITE"
			good = winner == 0
		_:
			title = "JOUEUR %d L'EMPORTE" % (winner + 1)
	results.setup(title, good, score, _names())
	results.action.connect(func(id: String) -> void:
		if id == "rematch":
			results.queue_free()
			score.assign([0, 0])
			round_num = 1
			collector.set_process_input(true)
			if pad:
				pad.enabled = true
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			_start_round(false)
		else:
			quit_to_menu.emit())


## Charge une arme + les coups communs (Burst, Potion).
func _load_weapon(path: String) -> MoveSet:
	var ms := MoveSet.from_json(DataLoader.load_json(path))
	ms.add_move("burst", cfg.get("burst", {}).get("move", {}))
	ms.add_move("potion", cfg.get("potion", {}).get("move", {}))
	return ms


func _view_of(i: int) -> FighterView:
	return fighter_views[i] if i >= 0 and i < fighter_views.size() else null


## Sons, effets visuels et messages déclenchés par la simulation.
## Règle de mise en scène (pour que ça reste classe et pas "cheap") :
##   - coup normal  : étoile + coupe + quelques étincelles, rien d'autre ;
##   - gros coup    : coupe plus grande + zoom ;
##   - moments forts (counter, parry, contre Iai, guard break, burst, Issen) :
##     impact frame TRÈS courte (2-3 images), sceau kanji, lignes de vitesse.
func _play_event(e: Dictionary) -> void:
	var kind: String = e["type"]
	if kind in ["hit", "block", "parry", "guard_break", "guard_crush", "iai_counter"]:
		_play_contact(kind, e)
		return
	var fi: int = e.get("fighter", -1)
	var ms: MoveSet = world.movesets[fi] if fi >= 0 else katana
	match kind:
		"burst":
			fx.burst_wave(e["pos"])
			sfx.play("hit_heavy", 3.0, 0.0)
			sfx.play("dash", 0.0)
			post.impact_frame(Color(1.0, 0.8, 0.3), true, 0.05)
			post.speed_lines(0.6, 0.15, Color(1.0, 0.85, 0.4))
			post.punch(0.8, 0.8)
			hud.popup("BURST", Color(1.0, 0.75, 0.25), "爆")
			for k in fp_views.size():
				if k != fi:
					fp_views[k].on_impact(0.8, false)
		"swing":
			if e["button"] == "blade":
				sfx.play("swish_heavy" if e["heavy"] else "swish", -4.0)
			else:
				sfx.play("swish_soft", -8.0)
		# --- Lecture et annulations ---
		"tell":
			# Reflet sur la lame adverse juste avant le coup : à toi de le lire.
			if fi != 0 or mode == "local":
				fx.star(e["pos"], Color(1.0, 1.0, 0.95) if e["button"] == "blade" else Color(1.0, 0.85, 0.5), 0.45, 0.14)
				sfx.play("chin", -16.0, 0.05)
		"cancel_dash", "cancel_attack":
			if fi >= 0 and fi < fighter_views.size():
				fighter_views[fi].ghost(Color(0.7, 0.95, 1.0, 0.7), 0.35)
			sfx.play("shing", -11.0, 0.08)
			sfx.play("dash", -8.0)
			if _fp(fi):
				post.speed_lines(0.3, 0.06, Color(0.8, 0.95, 1.0))
				post.punch(0.25, 0.15)
		"dash":
			sfx.play("dash", -9.0)
			if fi == 0:
				post.speed_lines(0.2, 0.06)
		"guard":
			sfx.play("shing", -12.0, 0.03)
		# --- Voie du sabre ---
		"stance":
			sfx.play("click", -2.0, 0.02)
		"iai_draw":
			sfx.play("swish_heavy", -1.0)
		"issen":
			sfx.play("parry", 0.0, 0.0)
			sfx.play("swish_heavy", 2.0, 0.0)
			post.impact_frame(Color(0.95, 0.95, 0.95), true, 0.12)
			post.speed_lines(0.9, 0.3)
			post.punch(1.0, 1.2)
			hud.popup("ISSEN", ms.style_color("kanji_color", Color(0.9, 0.1, 0.1)), "一閃")
		"zanshin_gain":
			sfx.play("chin", -6.0, 0.02)
		"zanshin_cancel":
			sfx.play("shing", -2.0, 0.02)
			sfx.play("click", -4.0)
			fx.star(e["pos"], ms.style_color("aura", Color(1, 0.1, 0.1)), 0.9, 0.1)
			if _fp(fi):
				post.speed_lines(0.35, 0.06, ms.style_color("aura", Color(1, 0.1, 0.1)))
				_fp(fi).aura(ms.style_color("aura", Color(1, 0.1, 0.1)), 0.5)
		# --- Clash / bind ---
		"clash":
			fx.impact(e["pos"], e["dir"], 1.0, "parry")
			fx.star(e["pos"], Color.WHITE, 2.2, 0.2)
			fx.ring(e["pos"], Color(1.0, 0.95, 0.85), 2.5, false, 0.35, 0.04)
			sfx.play("parry", 4.0, 0.0)
			sfx.play("clang", 0.0)
			post.impact_frame(Color(0.95, 0.95, 0.95), true, 0.06)
			post.speed_lines(0.9, 0.6)
			post.punch(1.0, 0.6)
			hud.popup("CLASH", Color(1.0, 0.95, 0.85), "鍔")
			for v in fp_views:
				v.on_impact(1.0, true)
			# La vue se tourne face à l'adversaire.
			collector.look_yaw = world.fighters[0].yaw_rad()
			collector.look_pitch = 0.0
			if pad:
				pad.look_yaw = world.fighters[1].yaw_rad()
				pad.look_pitch = 0.0
		"bind_end":
			var w: int = e["winner"]
			fx.impact(e["pos"], e["dir"], 1.0, "block")
			fx.star(e["pos"], Color(1.0, 0.85, 0.4), 1.6, 0.15)
			sfx.play("hit_heavy", 0.0)
			sfx.play("clang", -2.0)
			post.punch(0.8, 0.5)
			if mode == "local" and w >= 0:
				hud.popup("BIND — %s" % _names()[w], Color(1.0, 0.85, 0.35), "勝")
				_fp(w).aura(Color(1.0, 0.7, 0.15), 1.5)
			elif w == 0:
				hud.popup("BIND GAGNÉ", Color(1.0, 0.85, 0.35), "勝")
				fp_view.aura(Color(1.0, 0.7, 0.15), 1.5)
			elif w == 1:
				hud.popup("BIND PERDU", Color(0.7, 0.7, 0.75), "負")
				hud.hurt_flash(0.5)
			else:
				hud.popup("ÉGALITÉ", Color(0.85, 0.85, 0.85), "互")
		# --- Map ---
		"wall_bounce":
			fx.impact(e["pos"], e["dir"], 0.7, "block")
			fx.star(e["pos"], Color(1.0, 0.9, 0.7), 0.7, 0.1)
			sfx.play("clang", -1.0)
			if _fp(fi):
				hud.popup("REBOND", Color(0.8, 0.8, 0.85), "壁")
				_fp(fi).on_impact(0.6, false)
		"burn":
			fx.embers(e["pos"], 6, Color(1.0, 0.45, 0.1))
			sfx.play("thock", -14.0, 0.2)
			if fi == 0:
				hud.hurt_flash(0.15)
		"geyser_hit":
			fx.embers(e["pos"], 30, Color(1.0, 0.5, 0.1))
			fx.ring(e["pos"], Color(1.0, 0.45, 0.1), 2.0, false, 0.35)
			sfx.play("hit_heavy", -2.0)
			if _fp(fi):
				hud.hurt_flash(0.8)
				_fp(fi).on_impact(0.9, false)
			hud.popup("GEYSER", Color(1.0, 0.5, 0.15), "噴")
		# --- Objets ---
		"potion":
			sfx.play("swish_soft", -6.0)
		"potion_heal":
			fx.embers(e["pos"], 20, Color(0.5, 1.0, 0.6))
			sfx.play("chin", -2.0, 0.0)
			if fi == 0:
				hud.popup("SOIN", Color(0.55, 1.0, 0.65), "癒")
		"taunt":
			sfx.play("ring", -8.0, 0.0)
			hud.popup("PROVOCATION", Color(0.95, 0.9, 0.8), "挑")
		"chiburi":
			sfx.play("swish_soft", -2.0)
			sfx.play("ring", -10.0, 0.02)
			if _fp(fi):
				_fp(fi).aura(Color(1.0, 1.0, 1.0), 0.35)


func _play_contact(kind: String, e: Dictionary) -> void:
	var power := clampf(float(e["hitstop"]) / 15.0, 0.25, 1.0)
	var att: int = e["attacker"]
	var def: int = e["defender"]
	var ms := world.movesets[att]
	var dv := _view_of(def)
	var pos: Vector3 = e["pos"]
	var anim: String = e.get("anim", "")
	var g: int = e.get("guard", 1)
	var feet := Vector3(pos.x, 0.04, pos.z)
	var core := ms.style_color("slash_core", Color.WHITE)
	var edge := ms.style_color("slash_edge", Color(1.0, 0.3, 0.1))
	var ink := ms.style_color("slash_ink", Color(0.02, 0.0, 0.0))
	var spark := ms.style_color("spark", Color(1.0, 0.8, 0.5))
	var kanji_col := ms.style_color("kanji_color", Color(0.85, 0.1, 0.1))
	var metal: bool = ms.style.get("metal_ring", false)
	match kind:
		"hit":
			var blade: bool = e["button"] == "blade"
			var counter: bool = e["counter"]
			var heavy: bool = e["heavy"]
			var issen: bool = e.get("issen", false)
			fx.impact(pos, e["dir"], power, "blade" if blade else "pommel", spark)
			fx.star(pos, spark if blade else Color(1, 1, 0.9), 0.5 + 0.6 * power)
			if blade:
				var length := 1.4 + 1.4 * power + (0.8 if counter else 0.0) + (4.0 if issen else 0.0)
				fx.slash_mark(pos, "horizontal" if issen else anim, g, length,
						core, Color(1.0, 0.05, 0.05) if counter else edge, ink)
				sfx.play("hit_heavy" if (heavy or counter) else "hit", 1.0 if counter else (-1.0 if heavy else -3.0))
				if metal:
					sfx.play("ring", -14.0, 0.05)
			else:
				sfx.play("thock", 0.0 if counter else -1.0)
			if issen:
				post.impact_frame(Color(1.0, 0.1, 0.08), true, 0.08)
				post.punch(1.2, 1.2)
				fx.ring(feet, kanji_col, 4.0, true, 0.5, 0.03)
			elif counter:
				post.impact_frame(Color(1.0, 0.12, 0.08), true, 0.035)
				post.speed_lines(0.5, 0.08, Color(1.0, 0.25, 0.2))
				post.punch(0.9, 0.7)
				hud.popup("COUNTER", Color(1.0, 0.2, 0.15), "斬")
				if _fp(att):
					_fp(att).aura(Color(1.0, 0.15, 0.05), 2.0)
			elif heavy:
				post.punch(0.45, 0.45)
			else:
				post.punch(0.12, 0.05)
			if dv:
				dv.flash(power, Color(1.0, 0.3, 0.2) if counter else Color.WHITE)
			if e.has("wrong_height"):
				hud.popup(str(e["wrong_height"]), Color(1.0, 0.6, 0.2), "崩")
			elif e["punish"] and not counter:
				hud.popup("PUNISH", Color(0.95, 0.5, 0.85), "罰")
			if def == 0:
				hud.hurt_flash(power)
				if e.get("splash", false):
					hud.blood_splash()
		"block":
			fx.impact(pos, e["dir"], power, "block")
			fx.star(pos, Color(0.6, 0.8, 1.0), 0.35 + 0.3 * power, 0.08)
			sfx.play("clang", -3.0)
			sfx.play("thock", -10.0)
			post.punch(0.15, 0.05)
			if dv:
				dv.flash(0.3, Color(0.5, 0.7, 1.0), false)
		"parry":
			fx.impact(pos, e["dir"], 1.0, "parry")
			fx.star(pos, Color(1.0, 0.85, 0.35), 1.8, 0.16)
			fx.ring(pos, Color(1.0, 0.85, 0.35), 2.2, false, 0.3, 0.04)
			sfx.play("parry", 3.0, 0.02)
			sfx.play("hit", -6.0)
			post.impact_frame(Color(1.0, 0.82, 0.35), true, 0.05)
			post.speed_lines(0.6, 0.12, Color(1.0, 0.9, 0.5))
			post.punch(0.8, 0.6)
			hud.popup("PARRY", Color(1.0, 0.8, 0.3), "弾")
			if dv:
				dv.flash(1.0, Color(1.0, 0.85, 0.3), false)
			if _fp(def):
				_fp(def).aura(Color(1.0, 0.7, 0.15), 2.5)
			power = 1.0
		"iai_counter":
			# Contre depuis la posture : dégaine éclair horizontale.
			fx.impact(pos, e["dir"], 1.0, "blade", spark)
			fx.star(pos, Color.WHITE, 1.4, 0.14)
			fx.slash_mark(pos, "iai", g, 4.0, core, edge, ink, 0.3)
			sfx.play("hit_heavy", 2.0)
			sfx.play("ring", -6.0, 0.02)
			post.impact_frame(Color(0.95, 0.95, 0.95), true, 0.05)
			post.speed_lines(0.6, 0.1)
			post.punch(1.0, 0.8)
			if e.get("style", "iai") == "back":
				hud.popup("NŌTŌ", kanji_col, "背")
			else:
				hud.popup("IAI", kanji_col, "返")
			power = 1.0
		"guard_break", "guard_crush":
			fx.impact(pos, e["dir"], 1.0, "pommel")
			fx.star(pos, Color(0.55, 0.75, 1.0), 1.3, 0.14)
			fx.ring(feet, Color(0.45, 0.7, 1.0), 2.5, true, 0.35, 0.04)
			sfx.play("thock", 2.0)
			sfx.play("hit_heavy", -4.0)
			post.impact_frame(Color(0.5, 0.75, 1.0), true, 0.035)
			post.punch(0.7, 0.5)
			if kind == "guard_break":
				hud.popup("GUARD BREAK", Color(0.55, 0.75, 1.0), "破")
			else:
				hud.popup("GUARD CRUSH", Color(0.55, 0.75, 1.0), "崩")
			if dv:
				dv.flash(1.0, Color(0.5, 0.75, 1.0))
			if def == 0:
				hud.hurt_flash(0.6)
	for k in fp_views.size():
		if att == k or def == k:
			fp_views[k].on_impact(power, att == k)


func _unhandled_input(event: InputEvent) -> void:
	if paused:
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_open_pause()
	elif event is InputEventJoypadButton and event.is_pressed() and (event as InputEventJoypadButton).button_index == JOY_BUTTON_START:
		_open_pause()
	elif event.is_action_pressed("debug") and mode == "sandbox":
		show_debug = not show_debug
	elif event.is_action_pressed("move_list"):
		move_list.toggle()
		move_list.refresh(world.movesets[0], world.fighters[0].guard, controls, true)
	elif event.is_action_pressed("reload_data"):
		_reload_data()
	elif event.is_action_pressed("toggle_filter"):
		post.toggle()
	elif event.is_action_pressed("dummy_mode") and mode == "sandbox":
		dummy.cycle()


## F6 : relit les fichiers JSON sans relancer le jeu.
func _reload_data() -> void:
	var new_cfg := DataLoader.load_json(COMBAT_CFG)
	if new_cfg.is_empty():
		push_warning("combat.json invalide : réglages précédents conservés.")
	else:
		cfg = new_cfg
		world.cfg = cfg
		for v in fp_views:
			v._cfg = cfg
		for v in fighter_views:
			v._cfg = cfg
	var new_controls := DataLoader.load_json(CONTROLS_CFG)
	if not new_controls.is_empty():
		controls = new_controls
		ControlsSetup.apply(controls)
		collector.setup(controls, collector.look_yaw)
		collector.sensitivity = float(Settings.get_value("sensitivity"))
	var kd := DataLoader.load_json(weapon_path)
	if kd.is_empty():
		push_warning("Fichier d'arme invalide : coups précédents conservés.")
	else:
		katana = _load_weapon(weapon_path)
		for i in world.movesets.size():
			world.movesets[i] = katana
	var gfx := DataLoader.load_json(GRAPHICS_CFG)
	if not gfx.is_empty():
		post.apply(gfx, post.current_preset)
	move_list.refresh(katana, world.fighters[0].guard, controls, true)
	print("Données rechargées.")


# ------------------------------------------------------------ pause

func _open_pause() -> void:
	paused = true
	collector.set_process_input(false)   # sinon un clic dans le menu recapturerait la souris
	Engine.time_scale = 1.0 if match_state != "ko" else 0.3
	if pad:
		pad.enabled = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	pause_menu = PauseMenu.new()
	add_child(pause_menu)
	pause_menu.setup()
	pause_menu.action.connect(_on_pause_action)


func _on_pause_action(id: String) -> void:
	match id:
		"resume":
			pause_menu.queue_free()
			paused = false
			collector.set_process_input(true)
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		"options":
			options_menu = OptionsMenu.new()
			add_child(options_menu)
			options_menu.setup(post)
			options_menu.closed.connect(func() -> void:
				options_menu.queue_free()
				collector.sensitivity = float(Settings.get_value("sensitivity")))
		"menu":
			Engine.time_scale = 1.0
			quit_to_menu.emit()
