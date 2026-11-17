class_name FighterLogic
extends RefCounted
## Fait avancer UN combattant d'UN tick : déplacement, saut, accroupi, dash,
## changement de garde. Aucune dépendance au moteur physique de Godot.

const DT := 1.0 / 60.0
const CROUCH_TICKS := 6


static func step(f: FighterState, inp: InputFrame, cfg: Dictionary) -> void:
	var mv: Dictionary = cfg["movement"]
	var held: int = inp.buttons
	var pressed: int = held & ~f.prev_buttons

	f.yaw = inp.yaw
	f.pitch = inp.pitch
	if f.dash_cooldown > 0:
		f.dash_cooldown -= 1

	# --- Accroupi (seulement au sol) ---
	var want_crouch := (held & InputFrame.CROUCH) != 0 and f.on_ground and f.action != FighterState.Action.DASH
	if want_crouch:
		f.crouch = mini(f.crouch + 1, CROUCH_TICKS)
	else:
		f.crouch = maxi(f.crouch - 1, 0)

	var wish := wish_dir(f, held)

	# --- Actions en cours ---
	if f.action == FighterState.Action.DASH:
		_step_dash(f, mv)
	else:
		if f.action == FighterState.Action.GUARD_SWITCH:
			_step_guard_switch(f, cfg)
		_step_walk(f, mv, wish)
		_try_jump(f, mv, pressed)
		_try_dash(f, mv, held, pressed, wish)
		_try_guard_switch(f, pressed)

	_integrate(f, mv)
	f.prev_buttons = held


## Direction de déplacement voulue (monde, à plat, normalisée).
static func wish_dir(f: FighterState, held: int) -> Vector3:
	var x := 0.0
	var z := 0.0
	if held & InputFrame.RIGHT:
		x += 1.0
	if held & InputFrame.LEFT:
		x -= 1.0
	if held & InputFrame.FORWARD:
		z += 1.0
	if held & InputFrame.BACK:
		z -= 1.0
	var d := f.forward() * z + f.right() * x
	if d.length_squared() > 0.0:
		d = d.normalized()
	return d


static func _step_walk(f: FighterState, mv: Dictionary, wish: Vector3) -> void:
	var crouched := f.crouch > CROUCH_TICKS / 2
	var speed: float = mv["crouch_speed"] if crouched else mv["walk_speed"]
	var hv := Vector3(f.vel.x, 0.0, f.vel.z)
	if f.on_ground:
		hv = hv.move_toward(wish * speed, float(mv["ground_accel"]) * DT)
	elif wish != Vector3.ZERO:
		# En l'air : on peut corriger sa trajectoire, sans freiner si on ne touche à rien.
		hv = hv.move_toward(wish * speed, float(mv["air_accel"]) * DT)
	f.vel.x = hv.x
	f.vel.z = hv.z


static func _try_jump(f: FighterState, mv: Dictionary, pressed: int) -> void:
	if (pressed & InputFrame.JUMP) and f.on_ground:
		f.vel.y = float(mv["jump_velocity"])
		f.on_ground = false


## Dash = Shift + direction. Se déclenche quand on appuie sur Shift en tenant
## une direction, OU quand on appuie sur une direction en tenant Shift.
static func _try_dash(f: FighterState, mv: Dictionary, held: int, pressed: int, wish: Vector3) -> void:
	if f.action != FighterState.Action.NONE or f.dash_cooldown > 0:
		return
	if not (held & InputFrame.DASH) or wish == Vector3.ZERO:
		return
	var trigger := (pressed & InputFrame.DASH) != 0 or (pressed & InputFrame.DIR_MASK) != 0
	if not trigger:
		return
	if not f.on_ground:
		if not mv.get("allow_air_dash", true) or f.air_dash_used:
			return
		f.air_dash_used = true
	f.action = FighterState.Action.DASH
	f.action_tick = 0
	f.dash_dir = wish
	f.vel = wish * float(mv["dash_speed"])


static func _step_dash(f: FighterState, mv: Dictionary) -> void:
	f.action_tick += 1
	var total := int(mv["dash_ticks"])
	var slow := int(mv["dash_slowdown_ticks"])
	var speed: float = mv["dash_speed"]
	var end_speed: float = speed * float(mv["dash_end_speed_ratio"])
	var t := f.action_tick
	var s := speed
	if t > total - slow:
		var k := float(t - (total - slow)) / float(maxi(slow, 1))
		s = lerpf(speed, end_speed, k)
	f.vel = f.dash_dir * s  # vel.y = 0 : le dash aérien "suspend" la gravité
	if t >= total:
		f.action = FighterState.Action.NONE
		f.action_tick = 0
		f.dash_cooldown = int(mv["dash_cooldown_ticks"])


static func _try_guard_switch(f: FighterState, pressed: int) -> void:
	if (pressed & InputFrame.GUARD) and f.action == FighterState.Action.NONE:
		f.action = FighterState.Action.GUARD_SWITCH
		f.action_tick = 0


## L'arme change de main à mi-animation.
static func _step_guard_switch(f: FighterState, cfg: Dictionary) -> void:
	var total := int(cfg["guard_switch_ticks"])
	f.action_tick += 1
	if f.action_tick == total / 2:
		f.guard = -f.guard
	if f.action_tick >= total:
		f.action = FighterState.Action.NONE
		f.action_tick = 0


static func _integrate(f: FighterState, mv: Dictionary) -> void:
	if not f.on_ground and f.action != FighterState.Action.DASH:
		f.vel.y -= float(mv["gravity"]) * DT
	f.pos += f.vel * DT
	if f.pos.y <= 0.0:
		f.pos.y = 0.0
		if f.vel.y < 0.0:
			f.vel.y = 0.0
		f.on_ground = true
		f.air_dash_used = false
	else:
		f.on_ground = false
