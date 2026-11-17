class_name InputFrame
extends RefCounted
## Les inputs d'UN combattant pendant UN tick.
## C'est la seule chose que la simulation reçoit de l'extérieur : joueur, IA et
## (plus tard) adversaire en ligne produisent tous ce même format.

const FORWARD := 1 << 0
const BACK := 1 << 1
const LEFT := 1 << 2
const RIGHT := 1 << 3
const JUMP := 1 << 4
const CROUCH := 1 << 5
const DASH := 1 << 6
const BLADE := 1 << 7
const POMMEL := 1 << 8
const PARRY := 1 << 9
const GUARD := 1 << 10
const POTION := 1 << 11
const TAUNT := 1 << 12
const BURST := 1 << 13

const DIR_MASK := FORWARD | BACK | LEFT | RIGHT

## Nom d'action (controls.json) -> bit.
const ACTION_BITS := {
	"forward": FORWARD,
	"back": BACK,
	"left": LEFT,
	"right": RIGHT,
	"jump": JUMP,
	"crouch": CROUCH,
	"dash": DASH,
	"blade": BLADE,
	"pommel": POMMEL,
	"parry": PARRY,
	"guard_switch": GUARD,
	"potion": POTION,
	"taunt": TAUNT,
	"burst": BURST,
}

## Les angles sont stockés en entiers (1/10000 de radian) pour rester
## identiques d'une machine à l'autre (utile pour le rollback en ligne).
const ANGLE_SCALE := 10000.0
const FULL_TURN := 62832

var buttons: int = 0
var yaw: int = 0
var pitch: int = 0


func _init(b: int = 0, y: int = 0, p: int = 0) -> void:
	buttons = b
	yaw = y
	pitch = p


func has(bit: int) -> bool:
	return (buttons & bit) != 0


static func yaw_to_int(radians: float) -> int:
	return posmod(roundi(radians * ANGLE_SCALE), FULL_TURN)


static func angle_to_int(radians: float) -> int:
	return roundi(radians * ANGLE_SCALE)


static func int_to_angle(value: int) -> float:
	return float(value) / ANGLE_SCALE
