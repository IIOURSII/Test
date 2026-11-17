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

var cfg: Dictionary
var controls: Dictionary
var world: SimWorld
var prev_states: Array[FighterState] = []

var collector: InputCollector
var dummy: DummyController
var fp_view: FirstPersonView
var dummy_view: FighterView
var hud: Hud
var show_debug: bool = true


func _ready() -> void:
	cfg = DataLoader.load_json(COMBAT_CFG)
	controls = DataLoader.load_json(CONTROLS_CFG)
	ControlsSetup.apply(controls)

	ArenaBuilder.build(self, cfg)

	world = SimWorld.new(cfg)
	world.add_fighter(Vector3(0, 0, 4), 0.0)   # 0 = joueur (regarde vers -Z)
	world.add_fighter(Vector3(0, 0, -4), PI)   # 1 = mannequin (regarde vers le joueur)
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

	hud = Hud.new()
	add_child(hud)
	hud.setup()

	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _physics_process(_delta: float) -> void:
	prev_states = world.snapshot()
	var inputs: Array = [
		collector.poll(),
		dummy.poll(world, 1, 0),
	]
	world.step(inputs)


func _process(delta: float) -> void:
	var a := Engine.get_physics_interpolation_fraction()
	fp_view.update_view(prev_states[0], world.fighters[0], a, collector.look_yaw, collector.look_pitch, delta)
	dummy_view.update_view(prev_states[1], world.fighters[1], a)
	hud.update_hud(world, show_debug, collector.is_captured())


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event.is_action_pressed("debug"):
		show_debug = not show_debug
	elif event.is_action_pressed("reload_data"):
		_reload_data()


## F6 : relit les fichiers JSON sans relancer le jeu.
func _reload_data() -> void:
	var new_cfg := DataLoader.load_json(COMBAT_CFG)
	if new_cfg.is_empty():
		push_warning("combat.json invalide : réglages précédents conservés.")
		return
	cfg = new_cfg
	world.cfg = cfg
	fp_view._cfg = cfg
	dummy_view._cfg = cfg
	controls = DataLoader.load_json(CONTROLS_CFG)
	if not controls.is_empty():
		ControlsSetup.apply(controls)
		collector.setup(controls, collector.look_yaw)
	print("Données rechargées.")
