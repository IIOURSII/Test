class_name FighterState
extends RefCounted
## Tout l'état d'un combattant dans la simulation.
## Rien de visuel ici : seulement des données qu'on peut copier/restaurer
## (indispensable pour le rollback netcode plus tard).

enum Action { NONE, DASH, GUARD_SWITCH }

const GUARD_RIGHT := 1
const GUARD_LEFT := -1

var id: int = 0
var pos: Vector3 = Vector3.ZERO
var vel: Vector3 = Vector3.ZERO
var yaw: int = 0     ## en 1/10000 rad
var pitch: int = 0   ## en 1/10000 rad
var on_ground: bool = true
var crouch: int = 0  ## 0 = debout ... CROUCH_TICKS = accroupi
var guard: int = GUARD_RIGHT

var action: int = Action.NONE
var action_tick: int = 0
var dash_dir: Vector3 = Vector3.ZERO
var dash_cooldown: int = 0
var air_dash_used: bool = false

var hp: int = 1000
var max_hp: int = 1000

var prev_buttons: int = 0


func copy() -> FighterState:
	var c: FighterState = get_script().new()
	c.id = id
	c.pos = pos
	c.vel = vel
	c.yaw = yaw
	c.pitch = pitch
	c.on_ground = on_ground
	c.crouch = crouch
	c.guard = guard
	c.action = action
	c.action_tick = action_tick
	c.dash_dir = dash_dir
	c.dash_cooldown = dash_cooldown
	c.air_dash_used = air_dash_used
	c.hp = hp
	c.max_hp = max_hp
	c.prev_buttons = prev_buttons
	return c


func yaw_rad() -> float:
	return InputFrame.int_to_angle(yaw)


## Direction "devant" (à plat). En Godot, devant = -Z.
func forward() -> Vector3:
	var a := yaw_rad()
	return Vector3(-sin(a), 0.0, -cos(a))


## Direction "droite" (à plat).
func right() -> Vector3:
	var a := yaw_rad()
	return Vector3(cos(a), 0.0, -sin(a))


func action_name() -> String:
	return Action.keys()[action]
