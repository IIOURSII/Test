class_name GamepadCollector
extends Node
## Manette (joueur 2 en 1 contre 1 local). Produit les mêmes InputFrame que le clavier.
##  Stick gauche : déplacement (et manips 236, 623...)   Stick droit : visée
##  RT : LAME   RB : POMMEAU   LT : garde / parry   LB : dash   A : saut   B : accroupi
##  X : changer de garde   Y : potion   R3 : burst   Croix haut : provocation   Start : pause

const DEAD := 0.18
const DIR_THRESHOLD := 0.4

var device: int = 0
var look_yaw: float = 0.0
var look_pitch: float = 0.0
var look_speed: float = 3.2   ## radians / seconde, stick à fond
var enabled: bool = true


func setup(dev: int, start_yaw: float) -> void:
	device = dev
	look_yaw = start_yaw


func is_pad_connected() -> bool:
	return Input.get_connected_joypads().has(device)


func _process(delta: float) -> void:
	if not enabled:
		return
	var rx := _curve(Input.get_joy_axis(device, JOY_AXIS_RIGHT_X))
	var ry := _curve(Input.get_joy_axis(device, JOY_AXIS_RIGHT_Y))
	look_yaw = wrapf(look_yaw - rx * look_speed * delta, -PI, PI)
	look_pitch = clampf(look_pitch - ry * look_speed * 0.7 * delta, -1.45, 1.45)


static func _curve(v: float) -> float:
	if absf(v) < DEAD:
		return 0.0
	var k := (absf(v) - DEAD) / (1.0 - DEAD)
	return signf(v) * pow(k, 1.6)


func poll() -> InputFrame:
	var b := 0
	if enabled:
		var lx := Input.get_joy_axis(device, JOY_AXIS_LEFT_X)
		var ly := Input.get_joy_axis(device, JOY_AXIS_LEFT_Y)
		var mag := Vector2(lx, ly).length()
		if mag > 0.45:
			var nx := lx / mag
			var ny := ly / mag
			if nx > DIR_THRESHOLD:
				b |= InputFrame.RIGHT
			elif nx < -DIR_THRESHOLD:
				b |= InputFrame.LEFT
			if ny < -DIR_THRESHOLD:
				b |= InputFrame.FORWARD
			elif ny > DIR_THRESHOLD:
				b |= InputFrame.BACK
		if Input.get_joy_axis(device, JOY_AXIS_TRIGGER_RIGHT) > 0.4:
			b |= InputFrame.BLADE
		if Input.get_joy_axis(device, JOY_AXIS_TRIGGER_LEFT) > 0.4:
			b |= InputFrame.PARRY
		var map := {
			JOY_BUTTON_A: InputFrame.JUMP, JOY_BUTTON_B: InputFrame.CROUCH, JOY_BUTTON_X: InputFrame.GUARD,
			JOY_BUTTON_Y: InputFrame.POTION, JOY_BUTTON_LEFT_SHOULDER: InputFrame.DASH,
			JOY_BUTTON_RIGHT_SHOULDER: InputFrame.POMMEL, JOY_BUTTON_RIGHT_STICK: InputFrame.BURST,
			JOY_BUTTON_DPAD_UP: InputFrame.TAUNT,
		}
		for btn in map.keys():
			if Input.is_joy_button_pressed(device, btn):
				b |= int(map[btn])
	return InputFrame.new(b, InputFrame.yaw_to_int(look_yaw), InputFrame.angle_to_int(look_pitch))
