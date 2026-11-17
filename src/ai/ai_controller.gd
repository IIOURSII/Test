class_name AiController
extends RefCounted
## IA du mode Duel. Elle ne lit QUE ce qu'un joueur verrait (positions, animations en cours),
## avec un temps de réaction, et produit des InputFrame exactement comme un joueur
## (y compris les manips : 236, 623... tapées tick par tick).

var p: Dictionary = {}
var rng := RandomNumberGenerator.new()
var _queue: Array = []        ## boutons à envoyer les prochains ticks (une attaque en cours de saisie)
var _yaw: float = 0.0
var _seen_key: String = ""
var _seen_tick: int = 0
var _decision: String = ""    ## face à l'attaque vue : "parry", "block" ou "none"
var _cooldown: int = 40
var _strafe: float = 1.0
var _strafe_t: int = 0
var _hold_block: int = 0
var _burst_decided: int = -1
var _t: int = 0
var _aim_noise: float = 0.0


func setup(profile: Dictionary, seed_value: int) -> void:
	p = profile
	rng.seed = seed_value


func reset(yaw: float) -> void:
	_queue.clear()
	_yaw = yaw
	_cooldown = 60
	_seen_key = ""
	_hold_block = 0


func _f(key: String, def: float) -> float:
	return float(p.get(key, def))


func poll(world: SimWorld, mi: int, fi: int) -> InputFrame:
	_t += 1
	var me := world.fighters[mi]
	var foe := world.fighters[fi]
	var d := foe.pos - me.pos
	d.y = 0.0
	var dist := d.length()

	# Visée : tourne vers l'adversaire à vitesse limitée, avec une petite imprécision.
	if _t % 30 == 0:
		_aim_noise = deg_to_rad(rng.randf_range(-1.0, 1.0) * _f("aim_error", 3.0))
	var want := atan2(-d.x, -d.z) + _aim_noise
	var max_turn := deg_to_rad(_f("turn_speed", 7.0))
	_yaw = wrapf(_yaw + clampf(wrapf(want - _yaw, -PI, PI), -max_turn, max_turn), -PI, PI)

	var b := 0
	if me.action == FighterState.Action.BIND:
		var per := int(_f("mash_period", 8))
		return _frame(InputFrame.BLADE if _t % per < 2 else 0)
	if _cooldown > 0:
		_cooldown -= 1

	# Burst pendant un combo subi (décidé une fois par combo).
	if me.action == FighterState.Action.HITSTUN:
		_queue.clear()
		if me.combo_hits >= 2 and _burst_decided != me.combo_hits and me.burst_gauge >= int(world.cfg["burst"]["gauge_max"]):
			_burst_decided = me.combo_hits
			if rng.randf() < _f("burst", 0.5):
				return _frame(InputFrame.BURST)
		return _frame(0)

	# Défense face à une attaque qui arrive.
	var threat := _threat(world, foe, fi, dist)
	if not threat.is_empty():
		var key := "%s:%d" % [foe.move_id, world.tick - foe.move_tick]
		if key != _seen_key:
			_seen_key = key
			_seen_tick = world.tick
			var r := rng.randf()
			if threat["button"] == "pommel":
				_decision = "dodge"
			elif r < _f("parry", 0.2):
				_decision = "parry"
			elif r < _f("parry", 0.2) + _f("block", 0.6):
				_decision = "block"
			else:
				_decision = "none"
		if world.tick - _seen_tick >= int(_f("reaction", 15)) and me.can_defend():
			_queue.clear()
			match _decision:
				"parry":
					if int(threat["ticks"]) <= 3:
						return _frame(InputFrame.PARRY)
					return _frame(0)
				"block":
					_hold_block = 12
					var crouch := InputFrame.CROUCH if (threat["tags"] as Array).has("low") else 0
					return _frame(InputFrame.PARRY | crouch)
				"dodge":
					return _frame(InputFrame.BACK)
	if _hold_block > 0 and foe.action == FighterState.Action.ATTACK:
		_hold_block -= 1
		return _frame(InputFrame.PARRY)

	# Une manip en cours de saisie ?
	if not _queue.is_empty():
		return _frame(int(_queue.pop_front()) | (InputFrame.FORWARD if dist > 2.6 else 0))

	if not me.can_defend() or me.action == FighterState.Action.BLOCKSTUN:
		return _frame(0)

	# Punir une ouverture (parry raté, recovery, potion, provocation...).
	if _is_opening(world, foe, fi) and dist < 3.2 and rng.randf() < _f("punish", 0.6) * 0.25:
		_queue_move(me, "5" if dist < 2.1 else "6", "blade", 2 if dist < 2.1 else 0)
		return _frame(int(_queue.pop_front()))
	if _is_opening(world, foe, fi) and dist >= 3.2 and dist < 6.5 and rng.randf() < _f("punish", 0.6) * 0.08:
		_queue_move(me, "236", "blade")
		return _frame(int(_queue.pop_front()))

	# Anti-dash : l'adversaire fonce dessus -> coupe montante.
	if foe.action == FighterState.Action.DASH and dist < 4.0 and foe.dash_dir.dot(-d.normalized()) > 0.6 \
			and rng.randf() < _f("special", 0.3) * 0.3:
		_queue_move(me, "623", "blade")
		return _frame(int(_queue.pop_front()))

	# Neutre : gestion de la distance + feintes de déplacement.
	_strafe_t -= 1
	if _strafe_t <= 0:
		_strafe_t = rng.randi_range(25, 70)
		_strafe = [-1.0, 0.0, 1.0][rng.randi() % 3]
	if dist > 3.0:
		b |= InputFrame.FORWARD
		if dist > 7.0 and rng.randf() < 0.02:
			_queue = [InputFrame.DASH | InputFrame.FORWARD, InputFrame.DASH | InputFrame.FORWARD]
	elif dist < 1.6:
		b |= InputFrame.BACK
	if _strafe > 0.5:
		b |= InputFrame.RIGHT
	elif _strafe < -0.5:
		b |= InputFrame.LEFT

	if _cooldown <= 0 and dist < 7.0 and rng.randf() < _f("aggression", 0.035):
		_choose_attack(me, foe, dist)
		var cd: Array = p.get("cooldown", [30, 60])
		_cooldown = rng.randi_range(int(cd[0]), int(cd[1]))
		if not _queue.is_empty():
			return _frame(int(_queue.pop_front()))
	return _frame(b)


func _frame(buttons: int) -> InputFrame:
	return InputFrame.new(buttons, InputFrame.yaw_to_int(_yaw), 0)


## L'attaque adverse va-t-elle nous toucher ? Renvoie {} sinon, ou {"ticks", "button", "tags"}.
func _threat(world: SimWorld, foe: FighterState, fi: int, dist: float) -> Dictionary:
	if foe.action != FighterState.Action.ATTACK:
		return {}
	var m := world.movesets[fi].get_move(foe.move_id)
	if m.is_empty() or (m["hitboxes"] as Array).is_empty():
		return {}
	var first := 9999
	var reach := 0.0
	for hb in m["hitboxes"]:
		var tk: Vector2i = hb["ticks"]
		if tk.y >= foe.move_tick:
			first = mini(first, tk.x)
		reach = maxf(reach, maxf((hb["a"] as Vector3).z, (hb["b"] as Vector3).z) + float(hb["radius"]))
	if first == 9999:
		return {}
	var travel := 0.0
	for seg in m["movement"]:
		travel += maxf(float(seg["forward"]), 0.0) * float(int(seg["to"]) - int(seg["from"]) + 1) / 60.0
	if dist > reach + travel + 1.0:
		return {}
	return {"ticks": first - foe.move_tick, "button": m["button"], "tags": m.get("tags", [])}


func _is_opening(world: SimWorld, foe: FighterState, fi: int) -> bool:
	if foe.action == FighterState.Action.PARRIED:
		return true
	if foe.action != FighterState.Action.ATTACK:
		return false
	if foe.move_id == "potion" or foe.move_id == "taunt":
		return true
	var m := world.movesets[fi].get_move(foe.move_id)
	return not m.is_empty() and foe.move_tick > int(m["startup"]) + int(m["active"]) + 2


func _choose_attack(me: FighterState, foe: FighterState, dist: float) -> void:
	var r := rng.randf()
	var special := rng.randf() < _f("special", 0.3)
	var guarding := foe.action == FighterState.Action.BLOCK or foe.action == FighterState.Action.BLOCKSTUN
	if guarding:
		if foe.is_crouching() and dist < 3.0:
			_queue_move(me, "41236", "blade")      # overhead contre la garde basse
		elif dist < 2.0:
			_queue_move(me, "5", "pommel")         # le pommeau brise la garde
		return
	if dist < 2.0:
		if special and r < 0.5:
			_queue_move(me, "214", "blade")
		elif r < 0.6:
			_queue_move(me, "5", "blade", 2)       # Kesa-giri x3
		elif r < 0.75:
			_queue_move(me, "4", "blade")
		else:
			_queue_move(me, "5", "pommel")
	elif dist < 3.0:
		if special and r < 0.4:
			_queue_move(me, "41236", "blade")
		elif r < 0.7:
			_queue_move(me, "6", "blade")
		else:
			_queue_move(me, "236", "pommel")
	elif special:
		_queue_move(me, "236", "blade")


## Prépare la saisie d'un coup : directions tick par tick puis clic (+ enchaînements).
func _queue_move(me: FighterState, notation: String, button: String, chain: int = 0) -> void:
	_queue.clear()
	var btn := InputFrame.BLADE if button == "blade" else InputFrame.POMMEL
	var dirs: Array[int] = []
	for c in notation:
		var dgt := int(c)
		dirs.append(MotionParser.mirror_dir(dgt) if me.guard == FighterState.GUARD_LEFT else dgt)
	_queue.append(0)
	_queue.append(0)
	if notation.length() == 1:
		var hb := _dir_bits(dirs[0])
		_queue.append(hb)
		_queue.append(hb | btn)
		_queue.append(hb | btn)
	else:
		for dg in dirs:
			_queue.append(_dir_bits(dg))
			_queue.append(_dir_bits(dg))
		var last := _dir_bits(dirs[dirs.size() - 1])
		_queue.append(last | btn)
		_queue.append(last | btn)
	for k in chain:
		for i in 9:
			_queue.append(0)
		_queue.append(btn)
		_queue.append(btn)


static func _dir_bits(dgt: int) -> int:
	match dgt:
		1: return InputFrame.BACK | InputFrame.LEFT
		2: return InputFrame.BACK
		3: return InputFrame.BACK | InputFrame.RIGHT
		4: return InputFrame.LEFT
		6: return InputFrame.RIGHT
	return 0
