class_name MoveSet
extends RefCounted
## Les coups d'une arme, lus depuis data/weapons/<arme>.json et "nettoyés"
## (entiers pour la frame data, Vector3 pour les hitbox, valeurs par défaut).

const INPUT_ORDER := ["5", "6", "4", "2", "22", "214", "236", "66", "623", "44"]

var weapon_name: String = ""
var moves: Dictionary = {}


static func from_json(d: Dictionary) -> MoveSet:
	var ms := MoveSet.new()
	ms.weapon_name = str(d.get("weapon", "?"))
	var raw: Dictionary = d.get("moves", {})
	for id in raw.keys():
		ms.moves[id] = _normalize(str(id), raw[id])
	if not ms.moves.has("5_blade") or not ms.moves.has("5_pommel"):
		push_warning("%s : il manque 5_blade ou 5_pommel" % ms.weapon_name)
	return ms


## Ajoute un coup commun à toutes les armes (ex : le Burst, défini dans combat.json).
func add_move(id: String, raw: Dictionary) -> void:
	if not raw.is_empty():
		moves[id] = _normalize(id, raw)


func has_move(id: String) -> bool:
	return moves.has(id)


func get_move(id: String) -> Dictionary:
	return moves.get(id, {})


static func _normalize(id: String, m: Dictionary) -> Dictionary:
	var out := {}
	out["id"] = id
	out["name"] = str(m.get("name", id))
	out["input"] = str(m.get("input", "5"))
	out["button"] = str(m.get("button", "blade"))
	out["desc"] = str(m.get("desc", ""))
	out["hidden"] = bool(m.get("hidden", false))
	out["anim"] = str(m.get("anim", "none"))
	out["startup"] = int(m.get("startup", 10))
	out["active"] = int(m.get("active", 2))
	out["recovery"] = int(m.get("recovery", 10))
	out["total"] = maxi(int(out["startup"]) + int(out["active"]) + int(out["recovery"]), 1)
	out["chain_next"] = str(m.get("chain_next", ""))
	out["chain_window"] = _range(m.get("chain_window", null))
	out["free_cancel"] = _range(m.get("free_cancel", null))
	out["invuln"] = _range(m.get("invuln", null))
	out["no_pushbox"] = _range(m.get("no_pushbox", null))
	out["guard_flip_at"] = int(m.get("guard_flip_at", -1))
	out["tags"] = m.get("tags", [])

	var movement: Array = []
	for seg in m.get("movement", []):
		movement.append({
			"from": int(seg.get("from", 1)),
			"to": int(seg.get("to", seg.get("from", 1))),
			"forward": float(seg.get("forward", 0.0)),
			"side": float(seg.get("side", 0.0)),
			"up": float(seg.get("up", 0.0)),
			"has_horizontal": seg.has("forward") or seg.has("side"),
		})
	out["movement"] = movement

	var default_ticks := Vector2i(int(out["startup"]) + 1, int(out["startup"]) + int(out["active"]))
	var hitboxes: Array = []
	var i := 0
	for hb in m.get("hitboxes", []):
		var ticks := _range(hb.get("ticks", null))
		hitboxes.append({
			"ticks": ticks if ticks.x >= 0 else default_ticks,
			"a": _vec(hb.get("from", [0, 1.2, 0.5])),
			"b": _vec(hb.get("to", [0, 1.2, 1.2])),
			"radius": float(hb.get("radius", 0.15)),
			"group": int(hb.get("group", i)),
			"damage": int(hb.get("damage", m.get("damage", 0))),
			"hitstun": int(hb.get("hitstun", m.get("hitstun", 15))),
			"hitstop": int(hb.get("hitstop", m.get("hitstop", 6))),
			"knockback": float(hb.get("knockback", m.get("knockback", 1.0))),
			"launch": float(hb.get("launch", m.get("launch", 0.0))),
			"radial": bool(hb.get("radial", false)),
		})
		i += 1
	out["hitboxes"] = hitboxes
	return out


## [a, b] -> Vector2i(a, b) ; absent -> (-1, -1)
static func _range(v) -> Vector2i:
	if v is Array and v.size() >= 2:
		return Vector2i(int(v[0]), int(v[1]))
	return Vector2i(-1, -1)


static func _vec(v) -> Vector3:
	if v is Array and v.size() >= 3:
		return Vector3(float(v[0]), float(v[1]), float(v[2]))
	return Vector3.ZERO


static func in_range(r: Vector2i, t: int) -> bool:
	return r.x >= 0 and t >= r.x and t <= r.y


## Inverse une notation (236 <-> 214) : utile pour l'affichage en garde gauche.
static func mirror_notation(s: String) -> String:
	var out := ""
	for c in s:
		out += str(MotionParser.mirror_dir(int(c)))
	return out
