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
func _play_event(e: Dictionary) -> void:
	var kind: String = e["type"]
	if kind in ["hit", "block", "parry", "guard_break", "guard_crush"]:
		var power := clampf(float(e["hitstop"]) / 15.0, 0.25, 1.0)
		var att: int = e["attacker"]
		var def: int = e["defender"]
		var dv := _view_of(def)
		var player_involved := att == 0 or def == 0
		match kind:
			"hit":
				var blade: bool = e["button"] == "blade"
				fx.impact(e["pos"], e["dir"], power, "blade" if blade else "pommel")
				if e["counter"]:
					sfx.play("hit_heavy", 2.0)
				elif blade:
					sfx.play("hit_heavy" if e["heavy"] else "hit", 0.0 if e["heavy"] else -2.0)
				else:
					sfx.play("thock", -1.0)
				if dv:
					dv.flash(power, Color(1.0, 0.3, 0.2) if e["counter"] else Color.WHITE)
				if e.has("wrong_height"):
					hud.popup("%s !" % e["wrong_height"], Color(1.0, 0.6, 0.2))
				elif e["counter"]:
					hud.popup("COUNTER", Color(1.0, 0.25, 0.2))
				elif e["punish"]:
					hud.popup("PUNISH", Color(1.0, 0.55, 0.9))
				if def == 0:
					hud.hurt_flash(power)
			"block":
				fx.impact(e["pos"], e["dir"], power, "block")
				sfx.play("clang", -3.0)
				sfx.play("thock", -10.0)
				if dv:
					dv.flash(0.3, Color(0.5, 0.7, 1.0), false)
			"parry":
				fx.impact(e["pos"], e["dir"], 1.0, "parry")
				sfx.play("parry", 3.0, 0.02)
				sfx.play("hit", -6.0)
				hud.popup("PARRY !", Color(1.0, 0.85, 0.3))
				if dv:
					dv.flash(1.0, Color(1.0, 0.85, 0.3), false)
				power = 1.0
			"guard_break", "guard_crush":
				fx.impact(e["pos"], e["dir"], 1.0, "pommel")
				sfx.play("thock", 2.0)
				sfx.play("hit_heavy", -4.0)
				hud.popup("GUARD BREAK" if kind == "guard_break" else "GUARD CRUSH", Color(0.5, 0.75, 1.0))
				if dv:
					dv.flash(1.0, Color(0.5, 0.75, 1.0))
				if def == 0:
					hud.hurt_flash(0.6)
		if player_involved:
			fp_view.on_impact(power, att == 0)
		return
	match kind:
		"burst":
			fx.burst_wave(e["pos"])
			sfx.play("hit_heavy", 3.0, 0.0)
			sfx.play("dash", 0.0)
			hud.popup("BURST", Color(1.0, 0.8, 0.3))
			if e["fighter"] != 0:
				fp_view.on_impact(0.8, false)
		"swing":
			if e["button"] == "blade":
				sfx.play("swish_heavy" if e["heavy"] else "swish", -4.0)
			else:
				sfx.play("swish_soft", -8.0)
		"dash":
			sfx.play("dash", -9.0)
		"guard":
			sfx.play("shing", -12.0, 0.03)


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
