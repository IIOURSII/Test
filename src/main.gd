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
var show_debug: bool = true
var _pending_events: Array = []


func _ready() -> void:
	cfg = DataLoader.load_json(COMBAT_CFG)
	controls = DataLoader.load_json(CONTROLS_CFG)
	ControlsSetup.apply(controls)
	katana = MoveSet.from_json(DataLoader.load_json(KATANA))

	ArenaBuilder.build(self, cfg)

	world = SimWorld.new(cfg)
	world.add_fighter(Vector3(0, 0, 4), 0.0, katana)   # 0 = joueur (regarde vers -Z)
	world.add_fighter(Vector3(0, 0, -1), PI, katana)   # 1 = mannequin (regarde vers le joueur)
	world.training_dummies = [1]
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
		if e["type"] == "hit":
			var power := clampf(float(e["hitstop"]) / 12.0, 0.2, 1.0)
			if e["defender"] == 1:
				dummy_view.flash()
			if e["attacker"] == 0 or e["defender"] == 0:
				fp_view.add_shake(power)
	_pending_events.clear()

	fp_view.update_view(prev_states[0], world.fighters[0], a, collector.look_yaw, collector.look_pitch, delta, world.movesets[0])
	dummy_view.update_view(prev_states[1], world.fighters[1], a, delta, world.movesets[1])
	debug_draw.redraw(world, show_debug)
	hud.update_hud(world, show_debug, collector.is_captured())
	move_list.refresh(world.movesets[0], world.fighters[0].guard, controls)


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
		katana = MoveSet.from_json(kd)
		for i in world.movesets.size():
			world.movesets[i] = katana
	move_list.refresh(katana, world.fighters[0].guard, controls, true)
	print("Données rechargées.")
