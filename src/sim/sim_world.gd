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
	for h in hits:
		_apply_hit(h[0], h[1], h[2], h[3])


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


func _apply_hit(i: int, j: int, hb: Dictionary, capsule: Array) -> void:
	var att := fighters[i]
	var def := fighters[j]
	var m := movesets[i].get_move(att.move_id)
	var dmg := int(hb["damage"])
	var stun := int(hb["hitstun"])
	def.hp = maxi(def.hp - dmg, 0)
	def.ticks_since_hit = 0

	if stun > 0:
		if def.action == FighterState.Action.ATTACK:
			FighterLogic.end_move(def)
		def.action = FighterState.Action.HITSTUN
		def.hitstun = stun
		def.crouch = 0
		var fwd: Vector3 = Combat.attack_frame(att, def, cfg)[0]
		var kb := fwd * float(hb["knockback"])
		def.vel.x = kb.x
		def.vel.z = kb.z
		var launch := float(hb["launch"])
		if launch > 0.0:
			def.vel.y = launch
			def.on_ground = false
		def.combo_hits += 1
		def.combo_damage += dmg

	var stop := int(hb["hitstop"])
	att.hitstop = stop
	def.hitstop = stop

	# Avantage = ticks où l'adversaire est encore sonné après la fin de notre coup.
	if not m.is_empty():
		att.last_advantage = stun - (int(m["total"]) - att.move_tick)
		att.has_advantage_info = true

	# Point d'impact : sur la surface du corps, du côté de la lame.
	var hb_mid: Vector3 = ((capsule[0] as Vector3) + (capsule[1] as Vector3)) * 0.5
	var r: float = cfg["fighter"]["radius"]
	var core := Vector3(def.pos.x, clampf(hb_mid.y, def.pos.y + 0.3, def.pos.y + 1.8), def.pos.z)
	var out := Vector3(hb_mid.x - core.x, 0.0, hb_mid.z - core.z)
	var impact := core + (out.normalized() * r if out.length() > 0.01 else Vector3.ZERO)
	events.append({
		"type": "hit", "attacker": i, "defender": j,
		"damage": dmg, "hitstop": stop, "pos": impact,
		"button": m.get("button", "blade"),
		"heavy": stop >= 12,
		"dir": (Combat.attack_frame(att, def, cfg)[0] as Vector3),
	})


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
