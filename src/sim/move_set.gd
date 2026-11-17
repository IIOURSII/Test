class_name MoveSet
extends RefCounted
## Les coups d'une arme, lus depuis data/weapons/<arme>.json et "nettoyés"
## (entiers pour la frame data, Vector3 pour les hitbox, valeurs par défaut).

## Ordre d'affichage dans la liste des coups ("236" = dash universel).
const INPUT_ORDER := ["5", "236", "426", "624", "632", "421", "214", "436", "123", "623", "321"]

var weapon_name: String = ""
var moves: Dictionary = {}
var mechanic: Dictionary = {}    ## mécanique propre à l'arme (ex : Voie du sabre)
var mechanic_desc: String = ""
var style: Dictionary = {}       ## identité visuelle (couleurs des coupes, aura...)
var model: String = "katana"     ## modèle 3D de l'arme (katana, tanto, naginata, kanabo)
var ai_reach: float = 1.0        ## allonge relative (l'IA adapte ses distances)


static func from_json(d: Dictionary) -> MoveSet:
	var ms := MoveSet.new()
	ms.weapon_name = str(d.get("weapon", "?"))
	ms.mechanic = d.get("mechanic", {})
	ms.mechanic_desc = str(d.get("mechanic_desc", ""))
	ms.style = d.get("style", {})
	ms.model = str(d.get("model", "katana"))
	ms.ai_reach = float(d.get("ai_reach", 1.0))
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


func mechanic_type() -> String:
	return str(mechanic.get("type", ""))


func mech(key: String, default_value = 0):
	return mechanic.get(key, default_value)


func style_color(key: String, fallback: Color) -> Color:
	var v = style.get(key, null)
	if v is Array and v.size() >= 3:
		return Color(float(v[0]), float(v[1]), float(v[2]))
	return fallback


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
	out["stance"] = bool(m.get("stance", false))
	out["restore_edge"] = bool(m.get("restore_edge", false))
	out["heal_at"] = int(m.get("heal_at", -1))
	out["auto_counter"] = _range(m.get("auto_counter", null))
	out["counter_damage"] = int(m.get("counter_damage", 150))
	out["counter_stun"] = int(m.get("counter_stun", 30))
	out["counter_hitstop"] = int(m.get("counter_hitstop", 16))
	out["turn_back"] = bool(m.get("turn_back", false))
	out["counter_front"] = bool(m.get("counter_front", false))   # contre seulement les attaques de face
	out["armor"] = _range(m.get("armor", null))                   # super-armure : on encaisse sans être interrompu
	out["armor_reduction"] = float(m.get("armor_reduction", 0.6)) # part des dégâts encaissés sous armure
	out["projectile_shield"] = _range(m.get("projectile_shield", null))
	out["teleport_behind"] = int(m.get("teleport_behind", -1))    # tick où l'on réapparaît dans le dos adverse
	out["smoke"] = int(m.get("smoke", -1))                        # tick d'un nuage de fumée (bloque la vue adverse)
	out["gain_pips"] = int(m.get("gain_pips", 0))                 # points de mécanique gagnés à la fin du startup
	out["buff"] = str(m.get("buff", ""))                          # "unblockable" : le prochain coup LAME est imparable
	out["throw_weapon"] = int(m.get("throw_weapon", 0))           # ticks sans l'arme lancée (coups affaiblis)
	out["impulses"] = []
	for imp in m.get("impulses", []):                             # sauts supplémentaires : [{"at": tick, "up": v}]
		out["impulses"].append({"at": int(imp.get("at", 1)), "up": float(imp.get("up", 0.0))})
	var pj = m.get("projectile", null)
	out["projectile"] = {}
	if pj is Dictionary:
		out["projectile"] = {
			"at": int(pj.get("at", int(out["startup"]))), "speed": float(pj.get("speed", 15.0)),
			"up": float(pj.get("up", 0.0)), "gravity": float(pj.get("gravity", 0.0)),
			"radius": float(pj.get("radius", 0.2)), "life": int(pj.get("life", 60)),
			"damage": int(pj.get("damage", 30)), "hitstun": int(pj.get("hitstun", 16)),
			"hitstop": int(pj.get("hitstop", 6)), "knockback": float(pj.get("knockback", 2.0)),
			"kind": str(pj.get("kind", "rock")),
		}

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
			"grab": bool(hb.get("grab", false)),               # saisie : ni garde ni parry
			"ground_only": bool(hb.get("ground_only", false)), # onde au sol : il faut sauter
			"slow": int(hb.get("slow", 0)),                    # ralentit la cible (ticks)
			"bounce": float(hb.get("bounce", 0.0)),            # l'attaquant rebondit vers le haut s'il touche
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
