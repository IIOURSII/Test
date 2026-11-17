extends Node3D
## Point d'entrée : assemble la simulation, les inputs, les visuels et l'UI.
##
## Chaque tick logique (60/s, _physics_process) :
##   1. on garde une copie de l'état précédent (pour lisser l'affichage)
##   2. chaque "contrôleur" (joueur, mannequin, IA...) donne son InputFrame
##   3. la simulation avance d'un tick
## Chaque image affichée (_process, autant que l'écran le permet) :
##   on dessine l'état interpolé entre le tick précédent et le tick actuel.

const COMBAT_CFG := "res://data/config/combat.json"
const CONTROLS_CFG := "res://data/config/controls.json"
const KATANA := "res://data/weapons/katana.json"
const GRAPHICS_CFG := "res://data/config/graphics.json"

var cfg: Dictionary
var controls: Dictionary
var world: SimWorld
var prev_states: Array[FighterState] = []
var katana: MoveSet

var collector: InputCollector
var dummy: DummyController
var fp_view: FirstPersonView
var dummy_view: FighterView
var debug_draw: DebugDraw
var hud: Hud
var move_list: MoveList
var fx: Fx
var sfx: Sfx
var post: PostProcess
var show_debug: bool = true
var _pending_events: Array = []


func _ready() -> void:
	cfg = DataLoader.load_json(COMBAT_CFG)
	controls = DataLoader.load_json(CONTROLS_CFG)
	ControlsSetup.apply(controls)
	katana = _load_weapon(KATANA)

	ArenaBuilder.build(self, cfg)

	world = SimWorld.new(cfg)
	world.add_fighter(Vector3(0, 0, 4), 0.0, katana)   # 0 = joueur (regarde vers -Z)
	world.add_fighter(Vector3(0, 0, -1), PI, katana)   # 1 = mannequin (regarde vers le joueur)
	world.training_dummies = [0, 1]
	prev_states = world.snapshot()

	collector = InputCollector.new()
	add_child(collector)
	collector.setup(controls, 0.0)
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
	sfx = Sfx.new()
	add_child(sfx)
	sfx.setup()
	post = PostProcess.new()
	add_child(post)
	post.setup(DataLoader.load_json(GRAPHICS_CFG))

	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _physics_process(_delta: float) -> void:
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
	for e in _pending_events:
		_play_event(e)
	_pending_events.clear()

	fp_view.update_view(prev_states[0], world.fighters[0], a, collector.look_yaw, collector.look_pitch, delta, world.movesets[0])
	dummy_view.update_view(prev_states[1], world.fighters[1], a, delta, world.movesets[1])
	debug_draw.redraw(world, show_debug)
	hud.update_hud(world, show_debug, collector.is_captured(), dummy.mode_name())
	move_list.refresh(world.movesets[0], world.fighters[0].guard, controls)


## Charge une arme + les coups communs (Burst).
func _load_weapon(path: String) -> MoveSet:
	var ms := MoveSet.from_json(DataLoader.load_json(path))
	ms.add_move("burst", cfg.get("burst", {}).get("move", {}))
	return ms


func _view_of(i: int) -> FighterView:
	return dummy_view if i == 1 else null


## Sons, effets visuels et messages déclenchés par la simulation.
## C'est ici que se règle le côté "aura farm" : impact frames, coupes, kanji...
func _play_event(e: Dictionary) -> void:
	var kind: String = e["type"]
	if kind in ["hit", "block", "parry", "guard_break", "guard_crush"]:
		_play_contact(kind, e)
		return
	match kind:
		"burst":
			fx.burst_wave(e["pos"])
			sfx.play("hit_heavy", 3.0, 0.0)
			sfx.play("dash", 0.0)
			post.impact_frame(Color(1.0, 0.8, 0.3), true, 0.08)
			post.speed_lines(0.8, 0.25, Color(1.0, 0.85, 0.4))
			post.punch(1.0, 1.0)
			hud.popup("BURST", Color(1.0, 0.8, 0.3), "爆")
			if e["fighter"] != 0:
				fp_view.on_impact(0.8, false)
		"swing":
			if e["button"] == "blade":
				sfx.play("swish_heavy" if e["heavy"] else "swish", -4.0)
				if e["heavy"] and e["fighter"] == 0:
					post.speed_lines(0.25, 0.05)
			else:
				sfx.play("swish_soft", -8.0)
		"dash":
			sfx.play("dash", -9.0)
			if e["fighter"] == 0:
				post.speed_lines(0.35, 0.1)
		"guard":
			sfx.play("shing", -12.0, 0.03)


func _play_contact(kind: String, e: Dictionary) -> void:
	var power := clampf(float(e["hitstop"]) / 15.0, 0.25, 1.0)
	var att: int = e["attacker"]
	var def: int = e["defender"]
	var dv := _view_of(def)
	var pos: Vector3 = e["pos"]
	var anim: String = e.get("anim", "")
	var g: int = e.get("guard", 1)
	var feet := Vector3(pos.x, 0.04, pos.z)
	match kind:
		"hit":
			var blade: bool = e["button"] == "blade"
			var counter: bool = e["counter"]
			var heavy: bool = e["heavy"]
			fx.impact(pos, e["dir"], power, "blade" if blade else "pommel")
			if blade:
				var edge := Color(1.0, 0.1, 0.05) if counter else (Color(1.0, 0.45, 0.15) if heavy else Color(0.9, 0.85, 1.0))
				fx.slash_mark(pos, anim, g, 1.6 + 1.6 * power + (1.0 if counter else 0.0), edge)
			if counter:
				sfx.play("hit_heavy", 2.0)
				post.impact_frame(Color(1.0, 0.12, 0.08), true, 0.09)
				post.speed_lines(0.9, 0.2, Color(1.0, 0.2, 0.15))
				post.punch(1.2, 1.0)
				fx.ring(pos, Color(1.0, 0.2, 0.1), 2.2, false, 0.35)
				fx.ring(feet, Color(1.0, 0.3, 0.1), 3.0, true, 0.45)
				hud.popup("COUNTER", Color(1.0, 0.25, 0.2), "斬")
				if att == 0:
					fp_view.aura(Color(1.0, 0.15, 0.05), 3.0)
			elif heavy:
				sfx.play("hit_heavy" if blade else "thock", 0.0)
				post.impact_frame(Color(1.0, 0.95, 0.85), false, 0.05)
				post.speed_lines(0.5, 0.1)
				post.punch(0.7, 0.6)
				fx.ring(feet, Color(1.0, 0.7, 0.4), 2.2, true, 0.4)
			else:
				sfx.play("hit" if blade else "thock", -2.0 if blade else -1.0)
				post.punch(0.35 * power, 0.15)
			if dv:
				dv.flash(power, Color(1.0, 0.3, 0.2) if counter else Color.WHITE)
			if e.has("wrong_height"):
				hud.popup("%s !" % e["wrong_height"], Color(1.0, 0.6, 0.2), "崩")
			elif e["punish"] and not counter:
				hud.popup("PUNISH", Color(1.0, 0.55, 0.9), "罰")
			if def == 0:
				hud.hurt_flash(power)
		"block":
			fx.impact(pos, e["dir"], power, "block")
			fx.slash_mark(pos, "thrust", g, 0.9 + 0.6 * power, Color(0.4, 0.65, 1.0), 0.18)
			sfx.play("clang", -3.0)
			sfx.play("thock", -10.0)
			post.punch(0.25, 0.1)
			if dv:
				dv.flash(0.3, Color(0.5, 0.7, 1.0), false)
		"parry":
			fx.impact(pos, e["dir"], 1.0, "parry")
			fx.ring(pos, Color(1.0, 0.85, 0.35), 3.0, false, 0.45, 0.05)
			fx.ring(feet, Color(1.0, 0.75, 0.3), 3.5, true, 0.5)
			fx.slash_mark(pos, "thrust", 1, 3.2, Color(1.0, 0.75, 0.2), 0.3)
			sfx.play("parry", 3.0, 0.02)
			sfx.play("hit", -6.0)
			post.impact_frame(Color(1.0, 0.82, 0.35), true, 0.1)
			post.speed_lines(0.85, 0.25, Color(1.0, 0.9, 0.5))
			post.punch(1.0, 0.8)
			hud.popup("PARRY", Color(1.0, 0.85, 0.3), "弾")
			if dv:
				dv.flash(1.0, Color(1.0, 0.85, 0.3), false)
			if def == 0:
				fp_view.aura(Color(1.0, 0.7, 0.15), 3.5)
			power = 1.0
		"guard_break", "guard_crush":
			fx.impact(pos, e["dir"], 1.0, "pommel")
			fx.ring(pos, Color(0.45, 0.7, 1.0), 2.5, false, 0.4)
			fx.ring(feet, Color(0.45, 0.7, 1.0), 3.0, true, 0.45)
			sfx.play("thock", 2.0)
			sfx.play("hit_heavy", -4.0)
			post.impact_frame(Color(0.5, 0.75, 1.0), true, 0.08)
			post.speed_lines(0.6, 0.15, Color(0.6, 0.8, 1.0))
			post.punch(0.9, 0.7)
			if kind == "guard_break":
				hud.popup("GUARD BREAK", Color(0.5, 0.75, 1.0), "破")
			else:
				hud.popup("GUARD CRUSH", Color(0.5, 0.75, 1.0), "崩")
			if dv:
				dv.flash(1.0, Color(0.5, 0.75, 1.0))
			if def == 0:
				hud.hurt_flash(0.6)
	if att == 0 or def == 0:
		fp_view.on_impact(power, att == 0)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
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
	var kd := DataLoader.load_json(KATANA)
	if kd.is_empty():
		push_warning("katana.json invalide : coups précédents conservés.")
	else:
		katana = _load_weapon(KATANA)
		for i in world.movesets.size():
			world.movesets[i] = katana
	var gfx := DataLoader.load_json(GRAPHICS_CFG)
	if not gfx.is_empty():
		post.apply(gfx)
	move_list.refresh(katana, world.fighters[0].guard, controls, true)
	print("Données rechargées.")
