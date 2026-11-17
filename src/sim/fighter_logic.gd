class_name FighterLogic
extends RefCounted
## Fait avancer UN combattant d'UN tick : déplacement, saut, accroupi, dash,
## changement de garde, coups, hitstun. Aucune dépendance au moteur physique.

const DT := 1.0 / 60.0
const CROUCH_TICKS := 6


static func step(f: FighterState, inp: InputFrame, cfg: Dictionary, moves: MoveSet) -> void:
	var mv: Dictionary = cfg["movement"]
	var gd: Dictionary = cfg["guard"]
	var held: int = inp.buttons
	var pressed: int = held & ~f.prev_buttons

	f.yaw = inp.yaw
	f.pitch = inp.pitch
	f.local_tick += 1

	# Le buffer continue d'enregistrer même pendant le hitstop.
	var stunned := f.action == FighterState.Action.HITSTUN or f.action == FighterState.Action.PARRIED
	if not stunned:
		MotionParser.record(f, held)
		_record_attack_press(f, pressed, cfg, moves)
	if pressed & InputFrame.PARRY:
		_try_parry_press(f, gd)
	if pressed & InputFrame.BURST:
		f.burst_buffer = 8
	if (pressed & InputFrame.GUARD) and f.action == FighterState.Action.ATTACK:
		f.cancel_buffer = 8
	f.prev_buttons = held

	if f.hitstop > 0:
		f.hitstop -= 1
		return

	_tick_timers(f, cfg)

	# --- Accroupi (au sol, en mouvement libre ou en garde) ---
	var free_state := f.action == FighterState.Action.NONE or f.action == FighterState.Action.GUARD_SWITCH \
			or f.action == FighterState.Action.BLOCK or f.action == FighterState.Action.BLOCKSTUN
	if (held & InputFrame.CROUCH) != 0 and f.on_ground and free_state:
		f.crouch = mini(f.crouch + 1, CROUCH_TICKS)
	else:
		f.crouch = maxi(f.crouch - 1, 0)

	var wish := wish_dir(f, held)

	# Mécanique du katana : annuler la recovery avec le Zanshin (touche A).
	if f.cancel_buffer > 0 and f.action == FighterState.Action.ATTACK:
		if KatanaMechanic.try_cancel(f, moves):
			f.cancel_buffer = 0
			pressed &= ~InputFrame.GUARD   # ne déclenche pas en plus un changement de garde normal

	if f.action == FighterState.Action.ATTACK:
		_step_attack(f, cfg, moves, wish, held)
	if f.action == FighterState.Action.HITSTUN:
		_step_hitstun(f, mv)
		_try_burst(f, cfg, moves)
	if f.action == FighterState.Action.PARRIED:
		_step_stun_simple(f, mv, FighterState.Action.NONE)
	if f.action == FighterState.Action.BLOCKSTUN:
		var after := FighterState.Action.BLOCK if (held & InputFrame.PARRY) else FighterState.Action.NONE
		_step_stun_simple(f, mv, after)
	if f.action == FighterState.Action.DASH:
		_step_dash(f, mv)
	elif f.action == FighterState.Action.NONE or f.action == FighterState.Action.GUARD_SWITCH \
			or f.action == FighterState.Action.BLOCK:
		if f.action == FighterState.Action.GUARD_SWITCH:
			_step_guard_switch(f, cfg)
		_update_block(f, held)
		var speed_mult := 1.0
		if f.action == FighterState.Action.BLOCK:
			speed_mult = float(gd["walk_speed"]) / maxf(float(mv["walk_speed"]), 0.01)
		_step_walk(f, mv, wish, speed_mult)
		if f.action != FighterState.Action.BLOCK:
			_try_jump(f, mv, pressed)
			_try_dash(f, mv, held, pressed, wish)
			_try_guard_switch(f, pressed)

	_try_start_attack(f, cfg, moves, wish)
	_integrate(f, mv)


static func _tick_timers(f: FighterState, cfg: Dictionary) -> void:
	var gd: Dictionary = cfg["guard"]
	var bd: Dictionary = cfg["burst"]
	if f.pending_move != "":
		f.pending_age += 1
	if f.dash_cooldown > 0:
		f.dash_cooldown -= 1
	if f.parry_timer > 0:
		f.parry_timer -= 1
	if f.parry_lockout > 0:
		f.parry_lockout -= 1
	if f.burst_buffer > 0:
		f.burst_buffer -= 1
	if f.cancel_buffer > 0:
		f.cancel_buffer -= 1
	f.ticks_since_hit += 1
	f.burst_gauge = mini(f.burst_gauge + int(bd["gauge_regen"]), int(bd["gauge_max"]))
	if f.action == FighterState.Action.BLOCK or f.action == FighterState.Action.BLOCKSTUN:
		f.guard_idle = 0
	else:
		f.guard_idle += 1
		if f.guard_idle > int(gd["guard_regen_delay"]):
			f.guard_gauge = maxi(f.guard_gauge - int(gd["guard_regen"]), 0)


# ---------------------------------------------------------------- Défense

## Appui sur E : ouvre la fenêtre de parry (sauf si on vient d'en rater un : anti-spam).
static func _try_parry_press(f: FighterState, gd: Dictionary) -> void:
	if f.parry_lockout > 0 or not f.can_defend():
		return
	f.parry_timer = int(gd["parry_window"]) + 1
	f.parry_lockout = int(gd["parry_lockout"])


## Maintenir E = garde.
static func _update_block(f: FighterState, held: int) -> void:
	var holding := (held & InputFrame.PARRY) != 0
	if f.action == FighterState.Action.NONE and holding:
		f.action = FighterState.Action.BLOCK
		f.action_tick = 0
	elif f.action == FighterState.Action.BLOCK and not holding:
		f.action = FighterState.Action.NONE
		f.action_tick = 0


static func _step_stun_simple(f: FighterState, mv: Dictionary, after: int) -> void:
	if f.hitstun > 0:
		f.hitstun -= 1
	if f.on_ground:
		var hv := Vector3(f.vel.x, 0.0, f.vel.z).move_toward(Vector3.ZERO, float(mv["ground_accel"]) * 0.6 * DT)
		f.vel.x = hv.x
		f.vel.z = hv.z
	if f.hitstun <= 0:
		f.action = after
		f.action_tick = 0


## Burst : seulement pendant qu'on encaisse, jauge pleine.
static func _try_burst(f: FighterState, cfg: Dictionary, moves: MoveSet) -> void:
	if f.action != FighterState.Action.HITSTUN or f.burst_buffer <= 0:
		return
	if f.burst_gauge < int(cfg["burst"]["gauge_max"]) or not moves.has_move("burst"):
		return
	f.burst_gauge = 0
	f.burst_buffer = 0
	f.hitstun = 0
	f.last_combo_hits = f.combo_hits
	f.last_combo_damage = f.combo_damage
	f.combo_hits = 0
	f.combo_damage = 0
	f.vel = Vector3(0, minf(f.vel.y, 0.0), 0)
	start_move(f, "burst", moves, cfg, Vector3.ZERO)


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


# ---------------------------------------------------------------- Coups

## Au moment du clic, on lit la manip et on retient le coup demandé.
static func _record_attack_press(f: FighterState, pressed: int, cfg: Dictionary, moves: MoveSet) -> void:
	var button := ""
	if pressed & InputFrame.BLADE:
		button = "blade"
	elif pressed & InputFrame.POMMEL:
		button = "pommel"
	if button == "":
		return
	var window := int(cfg["input"]["motion_window_ticks"])
	var notation := MotionParser.resolve(f, window)
	var id := notation + "_" + button
	if not moves.has_move(id):
		notation = "5"
		id = "5_" + button
	f.pending_move = id
	f.pending_input = notation
	f.pending_button = button
	f.pending_age = 0


static func _try_start_attack(f: FighterState, cfg: Dictionary, moves: MoveSet, wish: Vector3) -> void:
	if f.pending_move == "":
		return
	if f.pending_age > int(cfg["input"]["button_buffer_ticks"]):
		_clear_pending(f)
		return
	var next_id := f.pending_move
	var allowed := f.action == FighterState.Action.NONE or f.action == FighterState.Action.BLOCK
	if f.action == FighterState.Action.ATTACK:
		var cur := moves.get_move(f.move_id)
		if not cur.is_empty():
			# Enchaînement (ex : Kesa-giri x3) : re-cliquer le même bouton sans direction.
			if cur["chain_next"] != "" and f.pending_input == "5" and f.pending_button == cur["button"] \
					and MoveSet.in_range(cur["chain_window"], f.move_tick) and moves.has_move(cur["chain_next"]):
				next_id = cur["chain_next"]
				allowed = true
			# Coups annulables dans n'importe quoi (ex : la feinte).
			elif MoveSet.in_range(cur["free_cancel"], f.move_tick):
				allowed = true
	if not allowed:
		return
	_clear_pending(f)
	start_move(f, next_id, moves, cfg, wish)


static func start_move(f: FighterState, id: String, moves: MoveSet, cfg: Dictionary, wish: Vector3) -> void:
	var m := moves.get_move(id)
	if m.is_empty():
		return
	f.action = FighterState.Action.ATTACK
	f.action_tick = 0
	f.move_id = id
	f.move_tick = 1
	f.hit_groups = 0
	f.crouch = 0
	f.charge_ticks = 0
	f.in_stance = false
	f.issen = false
	# On garde une partie de son élan : pas de "frein à main" en lançant un coup.
	var carry := float(cfg["attack"]["momentum_carry"])
	f.vel.x *= carry
	f.vel.z *= carry
	_apply_move_tick(f, m, cfg, wish)


static func _clear_pending(f: FighterState) -> void:
	f.pending_move = ""
	f.pending_input = ""
	f.pending_button = ""
	f.pending_age = 0


static func _step_attack(f: FighterState, cfg: Dictionary, moves: MoveSet, wish: Vector3, held: int) -> void:
	var m := moves.get_move(f.move_id)
	if m.is_empty():
		end_move(f)
		return
	var hold_bit := InputFrame.BLADE if m["button"] == "blade" else InputFrame.POMMEL

	# Posture (ex : Iai) : tant qu'on maintient le bouton, le coup reste figé en fin de startup.
	if f.in_stance:
		var max_t := int(moves.mech("stance_max_ticks", 90))
		if (held & hold_bit) and f.charge_ticks < max_t:
			f.charge_ticks += 1
			var hv := Vector3(f.vel.x, 0.0, f.vel.z).move_toward(Vector3.ZERO, float(cfg["movement"]["ground_accel"]) * DT)
			f.vel.x = hv.x
			f.vel.z = hv.z
			return
		f.in_stance = false
		KatanaMechanic.on_stance_release(f, moves)

	f.move_tick += 1
	if f.move_tick > int(m["total"]):
		end_move(f)
		return
	if m["stance"] and f.move_tick == int(m["startup"]) and (held & hold_bit):
		f.in_stance = true
		f.pending_fx = "stance"
	if m["restore_edge"] and f.move_tick == int(m["startup"]) + int(m["active"]):
		f.weapon_gauge = 100
		f.pending_fx = "chiburi"
	_apply_move_tick(f, m, cfg, wish)
	# Issen : ruée éclair pendant les frames actives.
	if f.issen and f.move_tick > int(m["startup"]) - 2 and f.move_tick <= int(m["startup"]) + int(m["active"]):
		var v := f.forward() * float(moves.mech("issen_speed", 24.0))
		f.vel.x = v.x
		f.vel.z = v.z


static func end_move(f: FighterState) -> void:
	f.action = FighterState.Action.NONE
	f.move_id = ""
	f.move_tick = 0
	f.hit_groups = 0
	f.in_stance = false
	f.issen = false
	f.charge_ticks = 0


## Déplacement pendant un coup :
## - pendant un "segment" (pas en avant, dash...), on accélère vers sa vitesse (pas de téléportation) ;
## - sinon l'élan s'amortit en douceur, et on garde un peu de contrôle hors des frames actives.
static func _apply_move_tick(f: FighterState, m: Dictionary, cfg: Dictionary, wish: Vector3) -> void:
	var ac: Dictionary = cfg["attack"]
	var t := f.move_tick
	var has_seg := false
	var target := Vector3.ZERO
	for seg in m["movement"]:
		if t < int(seg["from"]) or t > int(seg["to"]):
			continue
		if seg["has_horizontal"]:
			target = f.forward() * float(seg["forward"]) + f.right() * (float(seg["side"]) * f.guard)
			has_seg = true
		if float(seg["up"]) != 0.0 and t == int(seg["from"]):
			f.vel.y = float(seg["up"])
			f.on_ground = false

	var hv := Vector3(f.vel.x, 0.0, f.vel.z)
	if has_seg:
		hv = hv.move_toward(target, float(ac["segment_accel"]) * DT)
	elif f.on_ground:
		hv *= exp(-float(ac["damping"]) * DT)
		var startup := int(m["startup"])
		var in_active := t > startup and t <= startup + int(m["active"])
		var steer := Vector3.ZERO
		if not in_active:
			steer = wish * float(cfg["movement"]["walk_speed"]) * float(ac["steer_ratio"])
		hv = hv.move_toward(steer, float(ac["friction"]) * DT)
	f.vel.x = hv.x
	f.vel.z = hv.z

	if int(m["guard_flip_at"]) == t:
		f.guard = -f.guard


static func is_invulnerable(f: FighterState, moves: MoveSet) -> bool:
	if f.action != FighterState.Action.ATTACK:
		return false
	var m := moves.get_move(f.move_id)
	return not m.is_empty() and MoveSet.in_range(m["invuln"], f.move_tick)


static func ignores_pushbox(f: FighterState, moves: MoveSet) -> bool:
	if f.action != FighterState.Action.ATTACK:
		return false
	if f.issen:
		return true
	var m := moves.get_move(f.move_id)
	return not m.is_empty() and MoveSet.in_range(m["no_pushbox"], f.move_tick)


# ---------------------------------------------------------------- Hitstun

static func _step_hitstun(f: FighterState, mv: Dictionary) -> void:
	if f.hitstun > 0:
		f.hitstun -= 1
	if f.on_ground:
		var hv := Vector3(f.vel.x, 0.0, f.vel.z).move_toward(Vector3.ZERO, float(mv["ground_accel"]) * 0.5 * DT)
		f.vel.x = hv.x
		f.vel.z = hv.z
	# En l'air (après un launcher), on reste sonné jusqu'à l'atterrissage.
	if f.hitstun <= 0 and f.on_ground:
		f.action = FighterState.Action.NONE
		f.last_combo_hits = f.combo_hits
		f.last_combo_damage = f.combo_damage
		f.combo_hits = 0
		f.combo_damage = 0


# ---------------------------------------------------------------- Déplacement

static func _step_walk(f: FighterState, mv: Dictionary, wish: Vector3, speed_mult: float = 1.0) -> void:
	var crouched := f.crouch > CROUCH_TICKS / 2
	var speed: float = (mv["crouch_speed"] if crouched else mv["walk_speed"]) * speed_mult
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
