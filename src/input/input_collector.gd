class_name InputCollector
extends Node
## Lit le clavier/souris du joueur local et produit un InputFrame par tick.

const GAME_ACTIONS := [
	"forward", "back", "left", "right", "jump", "crouch", "dash",
	"blade", "pommel", "parry", "guard_switch", "potion", "taunt", "burst",
]
const MAX_PITCH := 1.45

var sensitivity: float = 0.0025
var invert_y: bool = false
## Regard "en direct" (mis à jour à chaque mouvement de souris, pour une
## caméra réactive même entre deux ticks).
var look_yaw: float = 0.0
var look_pitch: float = 0.0

## Appuis arrivés depuis le dernier tick (pour ne jamais rater un clic très court).
var _latched: int = 0


func setup(controls: Dictionary, start_yaw: float) -> void:
	sensitivity = float(controls.get("mouse_sensitivity", 0.0025))
	invert_y = bool(controls.get("invert_y", false))
	look_yaw = start_yaw


func is_captured() -> bool:
	return Input.mouse_mode == Input.MOUSE_MODE_CAPTURED


func _input(event: InputEvent) -> void:
	if not is_captured():
		# Un clic dans la fenêtre recapture la souris.
		if event is InputEventMouseButton and event.is_pressed():
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseMotion:
		var m := event as InputEventMouseMotion
		look_yaw = wrapf(look_yaw - m.relative.x * sensitivity, -PI, PI)
		var dy := m.relative.y * sensitivity
		look_pitch = clampf(look_pitch + (dy if invert_y else -dy), -MAX_PITCH, MAX_PITCH)
		return
	for action_name in GAME_ACTIONS:
		if event.is_action_pressed(action_name):
			_latched |= InputFrame.ACTION_BITS[action_name]


func poll() -> InputFrame:
	var b := 0
	if is_captured():
		b = _latched
		for action_name in GAME_ACTIONS:
			if Input.is_action_pressed(action_name):
				b |= InputFrame.ACTION_BITS[action_name]
	_latched = 0
	return InputFrame.new(b, InputFrame.yaw_to_int(look_yaw), InputFrame.angle_to_int(look_pitch))
