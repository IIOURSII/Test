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

var collector: InputCollector
var dummy: DummyController          # DEBUG (mode bac à sable)
var fp_view: FirstPersonView
var dummy_view: FighterView
var debug_draw: DebugDraw           # DEBUG
var hud: Hud
var move_list: MoveList
var fx: Fx
var sfx: Sfx
var post: PostProcess
var pause_menu: PauseMenu
var options_menu: OptionsMenu
var paused: bool = false
var show_debug: bool = true
var _pending_events: Array = []


## params : {"weapon": "katana", "class": "aucune", "map": "colisee", "mode": "sandbox"}
func setup(post_process: PostProcess, shared_sfx: Sfx, p: Dictionary) -> void:
	params = p
	post = post_process
	sfx = shared_sfx
	cfg = DataLoader.load_json(COMBAT_CFG)
	controls = DataLoader.load_json(CONTROLS_CFG)
	ControlsSetup.apply(controls)
	weapon_path = "res://data/weapons/%s.json" % str(p.get("weapon", "katana"))
	katana = _load_weapon(weapon_path)

	var map_id := str(p.get("map", "training"))
	map = MapData.from_json(map_id, DataLoader.load_json("res://data/maps/%s.json" % map_id))
	map_view = ArenaBuilder.build(self, map)

	world = SimWorld.new(cfg, map)
	world.add_fighter(map.spawns[0], map.spawn_yaw(0), katana)   # 0 = joueur
	world.add_fighter(map.spawns[1], map.spawn_yaw(1), katana)   # 1 = mannequin (DEBUG)
	world.training_dummies = [0, 1]
	prev_states = world.snapshot()

	collector = InputCollector.new()
	add_child(collector)
	collector.setup(controls, map.spawn_yaw(0))
	collector.sensitivity = float(Settings.get_value("sensitivity"))
	dummy = DummyController.new()

	fp_view = FirstPersonView.new()
	add_child(fp_view)
	fp_view.setup(cfg)

	dummy_view = FighterView.new()
	add_child(dummy_view)
	dummy_view.setup(cfg, Color(0.7, 0.55, 0.35))

	debug_draw = DebugDraw.new()
	add_child(debug_draw)
	debug_draw.setup()

	hud = Hud.new()
	add_child(hud)
	hud.setup()

	move_list = MoveList.new()
	add_child(move_list)
	move_list.setup()

	fx = Fx.new()
	add_child(fx)
	fx.setup()

	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	hud.popup(map.name.to_upper(), Color(0.95, 0.9, 0.8), map.kanji)


func _physics_process(_delta: float) -> void:
	if paused:
		return
	prev_states = world.snapshot()
	var player_input := collector.poll()
	var inputs: Array = [
		player_input,
		dummy.poll(world, 1, 0),
	]
	world.step(inputs)
	hud.record_input(player_input)
	_pending_events.append_array(world.events)


func _process(delta: float) -> void:
	var a := Engine.get_physics_interpolation_fraction()
	if paused:
		a = 0.0
	map_view.update_tick(float(world.tick) + a)
	for e in _pending_events:
		_play_event(e)
	_pending_events.clear()

	fp_view.update_view(prev_states[0], world.fighters[0], a, collector.look_yaw, collector.look_pitch, delta, world.movesets[0])
	dummy_view.update_view(prev_states[1], world.fighters[1], a, delta, world.movesets[1])
	debug_draw.redraw(world, show_debug)
	hud.update_hud(world, show_debug, collector.is_captured(), dummy.mode_name())
	move_list.refresh(world.movesets[0], world.fighters[0].guard, controls)


## Charge une arme + les coups communs (Burst, Potion).
func _load_weapon(path: String) -> MoveSet:
	var ms := MoveSet.from_json(DataLoader.load_json(path))
	ms.add_move("burst", cfg.get("burst", {}).get("move", {}))
	ms.add_move("potion", cfg.get("potion", {}).get("move", {}))
	return ms


func _view_of(i: int) -> FighterView:
	return dummy_view if i == 1 else null


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
			if fi != 0:
				fp_view.on_impact(0.8, false)
		"swing":
			if e["button"] == "blade":
				sfx.play("swish_heavy" if e["heavy"] else "swish", -4.0)
			else:
				sfx.play("swish_soft", -8.0)
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
			if fi == 0:
				post.speed_lines(0.35, 0.06, ms.style_color("aura", Color(1, 0.1, 0.1)))
				fp_view.aura(ms.style_color("aura", Color(1, 0.1, 0.1)), 0.5)
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
			fp_view.on_impact(1.0, true)
			# La vue se tourne face à l'adversaire.
			collector.look_yaw = world.fighters[0].yaw_rad()
			collector.look_pitch = 0.0
		"bind_end":
			var w: int = e["winner"]
			fx.impact(e["pos"], e["dir"], 1.0, "block")
			fx.star(e["pos"], Color(1.0, 0.85, 0.4), 1.6, 0.15)
			sfx.play("hit_heavy", 0.0)
			sfx.play("clang", -2.0)
			post.punch(0.8, 0.5)
			if w == 0:
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
			if fi == 0:
				hud.popup("REBOND", Color(0.8, 0.8, 0.85), "壁")
				fp_view.on_impact(0.6, false)
		"burn":
			fx.embers(e["pos"], 6, Color(1.0, 0.45, 0.1))
			sfx.play("thock", -14.0, 0.2)
			if fi == 0:
				hud.hurt_flash(0.15)
		"geyser_hit":
			fx.embers(e["pos"], 30, Color(1.0, 0.5, 0.1))
			fx.ring(e["pos"], Color(1.0, 0.45, 0.1), 2.0, false, 0.35)
			sfx.play("hit_heavy", -2.0)
			if fi == 0:
				hud.hurt_flash(0.8)
				fp_view.on_impact(0.9, false)
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
			if fi == 0:
				fp_view.aura(Color(1.0, 1.0, 1.0), 0.35)


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
				if att == 0:
					fp_view.aura(Color(1.0, 0.15, 0.05), 2.0)
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
			if def == 0:
				fp_view.aura(Color(1.0, 0.7, 0.15), 2.5)
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
	if att == 0 or def == 0:
		fp_view.on_impact(power, att == 0)


func _unhandled_input(event: InputEvent) -> void:
	if paused:
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_open_pause()
	elif event.is_action_pressed("debug"):
		show_debug = not show_debug
	elif event.is_action_pressed("move_list"):
		move_list.toggle()
		move_list.refresh(world.movesets[0], world.fighters[0].guard, controls, true)
	elif event.is_action_pressed("reload_data"):
		_reload_data()
	elif event.is_action_pressed("toggle_filter"):
		post.toggle()
	elif event.is_action_pressed("dummy_mode"):
		dummy.cycle()


## F6 : relit les fichiers JSON sans relancer le jeu.
func _reload_data() -> void:
	var new_cfg := DataLoader.load_json(COMBAT_CFG)
	if new_cfg.is_empty():
		push_warning("combat.json invalide : réglages précédents conservés.")
	else:
		cfg = new_cfg
		world.cfg = cfg
		fp_view._cfg = cfg
		dummy_view._cfg = cfg
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
			quit_to_menu.emit()
