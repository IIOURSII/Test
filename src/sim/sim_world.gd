class_name SimWorld
extends RefCounted
## La "vérité" du jeu. Avance de 1 tick à chaque appel de step().
## Ne contient que des données : on peut la copier (snapshot) et la restaurer.

var cfg: Dictionary
var tick: int = 0
var fighters: Array[FighterState] = []
var movesets: Array[MoveSet] = []        ## données (pas de l'état) : l'arme de chaque combattant
var training_dummies: Array[int] = []    ## combattants qui régénèrent leur vie

## Événements du dernier tick (pour les effets visuels/sonores). Ce n'est PAS de l'état.
var events: Array = []


func _init(config: Dictionary) -> void:
	cfg = config


func add_fighter(pos: Vector3, yaw_radians: float, moves: MoveSet) -> FighterState:
	var f := FighterState.new()
	f.id = fighters.size()
	f.pos = pos
	f.yaw = InputFrame.yaw_to_int(yaw_radians)
	f.max_hp = int(cfg["fighter"]["max_hp"])
	f.hp = f.max_hp
	fighters.append(f)
	movesets.append(moves)
	return f


## inputs[i] = InputFrame du combattant i pour ce tick.
func step(inputs: Array) -> void:
	events.clear()
	for i in fighters.size():
		FighterLogic.step(fighters[i], inputs[i], cfg, movesets[i])
	_emit_action_events()
	_resolve_hits()
	_resolve_pushboxes()
	_clamp_to_arena()
	_training_regen()
	tick += 1


func snapshot() -> Array[FighterState]:
	var out: Array[FighterState] = []
	for f in fighters:
		out.append(f.copy())
	return out


func restore(states: Array[FighterState], at_tick: int) -> void:
	fighters.clear()
	for f in states:
		fighters.append(f.copy())
	tick = at_tick


func opponent_of(i: int) -> FighterState:
	for j in fighters.size():
		if j != i:
			return fighters[j]
	return null


## Hitbox actives de ce tick pour le combattant i : [[capsule, hitbox_data], ...]
func active_hitboxes(i: int) -> Array:
	var out: Array = []
	var att := fighters[i]
	if att.action != FighterState.Action.ATTACK:
		return out
	var m := movesets[i].get_move(att.move_id)
	if m.is_empty():
		return out
	var frame := Combat.attack_frame(att, opponent_of(i), cfg)
	for hb in m["hitboxes"]:
		var ticks: Vector2i = hb["ticks"]
		if att.move_tick >= ticks.x and att.move_tick <= ticks.y:
			out.append([Combat.hitbox_world(att, hb, frame), hb])
	return out


## Événements "début d'action" pour les sons/effets (swing, dash, changement de garde).
func _emit_action_events() -> void:
	for i in fighters.size():
		var f := fighters[i]
		if f.hitstop > 0:
			continue
		if f.action == FighterState.Action.DASH and f.action_tick == 0:
			events.append({"type": "dash", "fighter": i})
		elif f.action == FighterState.Action.GUARD_SWITCH and f.action_tick == 0:
			events.append({"type": "guard", "fighter": i})
		elif f.action == FighterState.Action.ATTACK:
			var m := movesets[i].get_move(f.move_id)
			if m.is_empty():
				continue
			if f.move_id == "burst":
				if f.move_tick == 1:
					events.append({"type": "burst", "fighter": i, "pos": f.pos + Vector3(0, 1.1, 0)})
				continue
			var hbs: Array = m["hitboxes"]
			if hbs.is_empty():
				if f.move_tick == 1 and not (m["movement"] as Array).is_empty():
					events.append({"type": "dash", "fighter": i})
				continue
			for hb in hbs:
				var r: Vector2i = hb["ticks"]
				if f.move_tick == r.x:
					events.append({
						"type": "swing", "fighter": i, "button": m["button"],
						"heavy": int(hb["hitstop"]) >= 12,
					})


## Détecte toutes les touches du tick, PUIS les applique (équitable si les deux frappent en même temps).
func _resolve_hits() -> void:
	var hits: Array = []
	for i in fighters.size():
		var att := fighters[i]
		if att.hitstop > 0:
			continue
		for pair in active_hitboxes(i):
			var hb: Dictionary = pair[1]
			var bit := 1 << int(hb["group"])
			if att.hit_groups & bit:
				continue
			for j in fighters.size():
				if j == i:
					continue
				var def := fighters[j]
				if FighterLogic.is_invulnerable(def, movesets[j]):
					continue
				if Combat.capsules_overlap(pair[0], Combat.hurtbox(def, cfg)):
					att.hit_groups |= bit
					hits.append([i, j, hb, pair[0]])
					break
	hits = _apply_trade_rule(hits)
	for h in hits:
		_resolve_contact(h[0], h[1], h[2], h[3])


## Échange simultané : la LAME l'emporte sur le POMMEAU (lame > pommeau > garde > lame).
func _apply_trade_rule(hits: Array) -> Array:
	var out: Array = []
	for h in hits:
		var mine := _button_of(h[0])
		var dropped := false
		for o in hits:
			if o[0] == h[1] and o[1] == h[0] and mine == "pommel" and _button_of(o[0]) == "blade":
				dropped = true
		if not dropped:
			out.append(h)
	return out


func _button_of(i: int) -> String:
	var m := movesets[i].get_move(fighters[i].move_id)
	return str(m.get("button", ""))


## Garde/parry ne protègent que si on fait face à l'attaquant.
func _faces(def: FighterState, att: FighterState) -> bool:
	var d := att.pos - def.pos
	d.y = 0.0
	if d.length() < 0.01:
		return true
	return rad_to_deg(def.forward().angle_to(d.normalized())) <= float(cfg["guard"]["angle_deg"])


func _resolve_contact(i: int, j: int, hb: Dictionary, capsule: Array) -> void:
	var att := fighters[i]
	var def := fighters[j]
	var m := movesets[i].get_move(att.move_id)
	var button := str(m.get("button", "blade"))
	var fwd: Vector3
	if hb["radial"]:
		fwd = Vector3(def.pos.x - att.pos.x, 0.0, def.pos.z - att.pos.z)
		fwd = fwd.normalized() if fwd.length() > 0.01 else att.forward()
	else:
		fwd = Combat.attack_frame(att, def, cfg)[0]
	var info := {"pos": _impact_point(def, capsule), "dir": fwd, "button": button,
			"anim": str(m.get("anim", "")), "guard": att.guard}
	var faces := _faces(def, att)

	# 1) Parry parfait : appui sur E juste avant l'impact.
	if def.can_defend() and faces and def.parry_timer > 0:
		_parry(att, def, i, j, fwd, info)
		return
	# 2) Garde.
	var guarding := def.action == FighterState.Action.BLOCK or def.action == FighterState.Action.BLOCKSTUN
	if guarding and faces:
		if button == "pommel":
			_guard_break(att, def, i, j, hb, fwd, info)
			return
		var tags: Array = m.get("tags", [])
		var wrong_height := (tags.has("overhead") and def.is_crouching()) or (tags.has("low") and not def.is_crouching())
		if not wrong_height:
			_block(att, def, i, j, hb, fwd, info)
			return
		info["wrong_height"] = "OVERHEAD" if tags.has("overhead") else "COUP BAS"
	# 3) Touché.
	_hit(att, def, i, j, hb, m, fwd, info)


func _parry(att: FighterState, def: FighterState, i: int, j: int, fwd: Vector3, info: Dictionary) -> void:
	var gd: Dictionary = cfg["guard"]
	FighterLogic.end_move(att)
	att.action = FighterState.Action.PARRIED
	att.hitstun = int(gd["parry_stun"])
	att.vel = Vector3(-fwd.x * 3.0, minf(att.vel.y, 0.0), -fwd.z * 3.0)
	att.hitstop = int(gd["parry_hitstop"])
	def.hitstop = int(gd["parry_hitstop"])
	def.parry_timer = 0
	def.parry_lockout = 0   # un parry réussi permet d'enchaîner un autre parry
	if def.action == FighterState.Action.BLOCKSTUN:
		def.action = FighterState.Action.BLOCK
		def.hitstun = 0
	info.merge({"type": "parry", "attacker": i, "defender": j, "hitstop": int(gd["parry_hitstop"])})
	events.append(info)


func _guard_break(att: FighterState, def: FighterState, i: int, j: int, hb: Dictionary, fwd: Vector3, info: Dictionary) -> void:
	var gd: Dictionary = cfg["guard"]
	_reset_combo_if_fresh(def)
	def.action = FighterState.Action.HITSTUN
	def.hitstun = int(hb["hitstun"]) + int(gd["break_bonus_stun"])
	def.crouch = 0
	def.vel.x = fwd.x * float(hb["knockback"])
	def.vel.z = fwd.z * float(hb["knockback"])
	def.combo_hits += 1
	def.ticks_since_hit = 0
	var stop := int(hb["hitstop"]) + 3
	att.hitstop = stop
	def.hitstop = stop
	_record_advantage(att, def.hitstun, false)
	info.merge({"type": "guard_break", "attacker": i, "defender": j, "hitstop": stop})
	events.append(info)


func _block(att: FighterState, def: FighterState, i: int, j: int, hb: Dictionary, fwd: Vector3, info: Dictionary) -> void:
	var gd: Dictionary = cfg["guard"]
	var stun := maxi(int(gd["min_blockstun"]), roundi(float(hb["hitstun"]) * float(gd["blockstun_ratio"])))
	def.action = FighterState.Action.BLOCKSTUN
	def.hitstun = stun
	var push := float(hb["knockback"]) * 0.6 + float(gd["pushback"])
	def.vel.x = fwd.x * push
	def.vel.z = fwd.z * push
	def.guard_gauge += int(gd["guard_per_block"]) + roundi(float(hb["damage"]) * float(gd["guard_per_damage"]))
	var stop := maxi(int(hb["hitstop"]) - 2, 4)
	if def.guard_gauge >= int(gd["guard_max"]):
		# Garde brisée : on a trop bloqué.
		def.guard_gauge = 0
		_reset_combo_if_fresh(def)
		def.action = FighterState.Action.HITSTUN
		def.hitstun = int(gd["crush_stun"])
		stop += 6
		_record_advantage(att, def.hitstun, false)
		info.merge({"type": "guard_crush", "attacker": i, "defender": j, "hitstop": stop})
	else:
		_record_advantage(att, stun, true)
		info.merge({"type": "block", "attacker": i, "defender": j, "hitstop": stop})
	att.hitstop = stop
	def.hitstop = stop
	events.append(info)


func _hit(att: FighterState, def: FighterState, i: int, j: int, hb: Dictionary, m: Dictionary, fwd: Vector3, info: Dictionary) -> void:
	var cc: Dictionary = cfg["counter"]
	var co: Dictionary = cfg["combo"]
	# Counter-hit : on le touche pendant le startup de son coup. Punish : pendant sa recovery.
	var counter := false
	var punish := def.action == FighterState.Action.PARRIED
	if def.action == FighterState.Action.ATTACK:
		var dm := movesets[j].get_move(def.move_id)
		if not dm.is_empty():
			counter = def.move_tick <= int(dm["startup"])
			punish = def.move_tick > int(dm["startup"]) + int(dm["active"])

	_reset_combo_if_fresh(def)
	var n := def.combo_hits
	var dmg_mult := maxf(float(co["min_damage"]), 1.0 - float(co["damage_decay"]) * n)
	var stun_mult := maxf(float(co["min_hitstun"]), 1.0 - float(co["hitstun_decay"]) * n)
	if counter:
		dmg_mult *= float(cc["damage_mult"])
	var dmg := roundi(float(hb["damage"]) * dmg_mult)
	var stun := int(hb["hitstun"])
	if stun > 0:
		stun = maxi(1, roundi(float(stun) * stun_mult) + (int(cc["hitstun_bonus"]) if counter else 0))
	var stop := int(hb["hitstop"]) + (int(cc["hitstop_bonus"]) if counter else 0)

	def.hp = maxi(def.hp - dmg, 0)
	def.ticks_since_hit = 0
	def.burst_gauge = mini(def.burst_gauge + roundi(dmg * float(cfg["burst"]["gauge_per_damage"])), int(cfg["burst"]["gauge_max"]))

	if stun > 0:
		if def.action == FighterState.Action.ATTACK:
			FighterLogic.end_move(def)
		def.action = FighterState.Action.HITSTUN
		def.hitstun = stun
		def.crouch = 0
		var kb := fwd * float(hb["knockback"])
		def.vel.x = kb.x
		def.vel.z = kb.z
		var launch := float(hb["launch"])
		if launch > 0.0:
			def.vel.y = launch
			def.on_ground = false
		def.combo_hits += 1
		def.combo_damage += dmg

	att.hitstop = stop
	def.hitstop = stop
	if not m.is_empty():
		_record_advantage(att, stun, false)

	info.merge({
		"type": "hit", "attacker": i, "defender": j,
		"damage": dmg, "hitstop": stop, "heavy": stop >= 12,
		"counter": counter, "punish": punish, "combo": def.combo_hits,
	})
	events.append(info)


## Un nouveau combo commence si l'adversaire n'était pas déjà sonné.
func _reset_combo_if_fresh(def: FighterState) -> void:
	if def.action != FighterState.Action.HITSTUN:
		def.combo_hits = 0
		def.combo_damage = 0


## Avantage = ticks où l'adversaire est encore bloqué après la fin de notre coup.
func _record_advantage(att: FighterState, stun: int, on_block: bool) -> void:
	var m := movesets[att.id].get_move(att.move_id)
	if m.is_empty():
		return
	att.last_advantage = stun - (int(m["total"]) - att.move_tick)
	att.has_advantage_info = true
	att.last_adv_on_block = on_block


## Point d'impact : sur la surface du corps, du côté de la lame.
func _impact_point(def: FighterState, capsule: Array) -> Vector3:
	var hb_mid: Vector3 = ((capsule[0] as Vector3) + (capsule[1] as Vector3)) * 0.5
	var r: float = cfg["fighter"]["radius"]
	var core := Vector3(def.pos.x, clampf(hb_mid.y, def.pos.y + 0.3, def.pos.y + 1.8), def.pos.z)
	var out := Vector3(hb_mid.x - core.x, 0.0, hb_mid.z - core.z)
	return core + (out.normalized() * r if out.length() > 0.01 else Vector3.ZERO)


## Les combattants ne peuvent pas se traverser (sauf certains coups).
func _resolve_pushboxes() -> void:
	var r: float = cfg["fighter"]["radius"]
	var h: float = cfg["fighter"]["height"]
	var min_d := r * 2.0
	for i in fighters.size():
		for j in range(i + 1, fighters.size()):
			var a := fighters[i]
			var b := fighters[j]
			if FighterLogic.ignores_pushbox(a, movesets[i]) or FighterLogic.ignores_pushbox(b, movesets[j]):
				continue
			if absf(a.pos.y - b.pos.y) >= h:
				continue
			var d := Vector2(b.pos.x - a.pos.x, b.pos.z - a.pos.z)
			var dist := d.length()
			if dist >= min_d:
				continue
			var n := d / dist if dist > 0.0001 else Vector2(1.0, 0.0)
			var push := (min_d - dist) * 0.5
			a.pos.x -= n.x * push
			a.pos.z -= n.y * push
			b.pos.x += n.x * push
			b.pos.z += n.y * push


func _clamp_to_arena() -> void:
	var lim: float = float(cfg["arena"]["half_size"]) - float(cfg["fighter"]["radius"])
	for f in fighters:
		f.pos.x = clampf(f.pos.x, -lim, lim)
		f.pos.z = clampf(f.pos.z, -lim, lim)


func _training_regen() -> void:
	var delay := int(cfg.get("training", {}).get("dummy_regen_ticks", 120))
	for i in training_dummies:
		var f := fighters[i]
		if f.ticks_since_hit > delay and f.action != FighterState.Action.HITSTUN:
			f.hp = f.max_hp
			f.burst_gauge = int(cfg["burst"]["gauge_max"])
