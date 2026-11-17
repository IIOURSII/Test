class_name MapData
extends RefCounted
## Une map, lue depuis data/maps/<id>.json.
## Tout ce qui compte pour le gameplay est ici (et donc déterministe) :
## limites, points d'apparition, obstacles (piliers, murets, plateformes),
## zones (lave, sol glissant) et geysers. Le reste du JSON ("visual") ne sert qu'au décor.
##
## Équité : chaque élément marqué "mirror" (par défaut) est automatiquement dupliqué
## en symétrie centrale (x, z) -> (-x, -z). Les deux côtés sont donc strictement identiques.

const STEP_HEIGHT := 0.35   ## on monte sans sauter sur ce qui est plus bas que ça

var id: String = ""
var name: String = ""
var subtitle: String = ""
var kanji: String = ""
var desc: String = ""
var theme: String = "training"
var debug_only: bool = false

var bounds_type: String = "rect"
var half: Vector2 = Vector2(14, 14)
var radius: float = 13.0
var spawns: Array[Vector3] = []

var boxes: Array = []     ## {"min": Vector3, "max": Vector3, "bounce": bool, "look": String}
var zones: Array = []     ## {"type", "shape", "center": Vector2, "half": Vector2, "radius", ...}
var geysers: Array = []   ## {"pos": Vector2, "radius", "period", "offset", "warn", "active", "damage", "launch"}
var visual: Dictionary = {}


static func from_json(map_id: String, d: Dictionary) -> MapData:
	var m := MapData.new()
	m.id = map_id
	m.name = str(d.get("name", map_id))
	m.subtitle = str(d.get("subtitle", ""))
	m.kanji = str(d.get("kanji", ""))
	m.desc = str(d.get("desc", ""))
	m.theme = str(d.get("theme", "training"))
	m.debug_only = bool(d.get("debug_only", false))
	var b: Dictionary = d.get("bounds", {})
	m.bounds_type = str(b.get("type", "rect"))
	m.half = Vector2(float(b.get("half_x", 14.0)), float(b.get("half_z", 14.0)))
	m.radius = float(b.get("radius", 13.0))
	var sz := float(d.get("spawn_distance", 4.0))
	m.spawns = [Vector3(0, 0, sz), Vector3(0, 0, -sz)]

	for o in d.get("obstacles", []):
		var c := _v3(o.get("pos", [0, 0, 0]))
		var s := _v3(o.get("size", [1, 1, 1]))
		var box := {"look": str(o.get("look", "box")), "bounce": bool(o.get("bounce", true))}
		for p in _mirrored(c, o):
			var bb := box.duplicate()
			# pos = centre au sol (y = bas de l'obstacle)
			bb["min"] = Vector3(p.x - s.x * 0.5, p.y, p.z - s.z * 0.5)
			bb["max"] = Vector3(p.x + s.x * 0.5, p.y + s.y, p.z + s.z * 0.5)
			m.boxes.append(bb)

	for z in d.get("zones", []):
		var c := _v3(z.get("pos", [0, 0, 0]))
		for p in _mirrored(c, z):
			m.zones.append({
				"type": str(z.get("type", "lava")),
				"shape": str(z.get("shape", "circle")),
				"center": Vector2(p.x, p.z),
				"half": Vector2(float(z.get("half_x", 1.0)), float(z.get("half_z", 1.0))),
				"radius": float(z.get("radius", 1.5)),
				"damage": int(z.get("damage", 6)),
				"interval": maxi(int(z.get("interval", 6)), 1),
				"friction": float(z.get("friction", 0.25)),
			})

	for g in d.get("geysers", []):
		var c := _v3(g.get("pos", [0, 0, 0]))
		var mirrored := _mirrored(c, g)
		for k in mirrored.size():
			var p: Vector3 = mirrored[k]
			m.geysers.append({
				"pos": Vector2(p.x, p.z),
				"radius": float(g.get("radius", 1.4)),
				"period": maxi(int(g.get("period", 420)), 30),
				"offset": int(g.get("offset", 0)),
				"warn": int(g.get("warn", 75)),
				"active": int(g.get("active", 20)),
				"damage": int(g.get("damage", 80)),
				"launch": float(g.get("launch", 9.0)),
			})
	m.visual = d.get("visual", {})
	return m


static func _v3(v) -> Vector3:
	if v is Array and v.size() >= 3:
		return Vector3(float(v[0]), float(v[1]), float(v[2]))
	return Vector3.ZERO


## Renvoie la position + sa copie symétrique (sauf si l'élément est au centre ou "mirror": false).
static func _mirrored(c: Vector3, entry: Dictionary) -> Array:
	var out: Array = [c]
	if bool(entry.get("mirror", true)) and Vector2(c.x, c.z).length() > 0.01:
		out.append(Vector3(-c.x, c.y, -c.z))
	return out


func spawn_yaw(i: int) -> float:
	var p := spawns[i]
	return atan2(p.x, p.z)   # regarde vers le centre


## Hauteur du sol sous ce point (plateformes).
func floor_at(pos: Vector3) -> float:
	var best := 0.0
	for b in boxes:
		var mn: Vector3 = b["min"]
		var mx: Vector3 = b["max"]
		if pos.x >= mn.x and pos.x <= mx.x and pos.z >= mn.z and pos.z <= mx.z:
			if mx.y <= pos.y + STEP_HEIGHT and mx.y > best:
				best = mx.y
	return best


func friction_at(pos: Vector3) -> float:
	var f := 1.0
	for z in zones:
		if z["type"] == "slippery" and pos.y < 0.1 and zone_contains(z, pos):
			f = minf(f, float(z["friction"]))
	return f


func zone_contains(z: Dictionary, pos: Vector3) -> bool:
	var c: Vector2 = z["center"]
	var d := Vector2(pos.x, pos.z) - c
	if z["shape"] == "rect":
		var h: Vector2 = z["half"]
		return absf(d.x) <= h.x and absf(d.y) <= h.y
	return d.length() <= float(z["radius"])


## 0 = calme, 1 = grondement (avertissement), 2 = éruption.
func geyser_state(g: Dictionary, tick: int) -> int:
	var period := int(g["period"])
	var phase := posmod(tick + int(g["offset"]), period)
	if phase >= period - int(g["active"]):
		return 2
	if phase >= period - int(g["active"]) - int(g["warn"]):
		return 1
	return 0


func geyser_erupts_now(g: Dictionary, tick: int) -> bool:
	var period := int(g["period"])
	return posmod(tick + int(g["offset"]), period) == period - int(g["active"])


## Ramène un point dans les limites de la map.
func clamp_pos(pos: Vector3, r: float) -> Vector3:
	if bounds_type == "circle":
		var v := Vector2(pos.x, pos.z)
		var lim := radius - r
		if v.length() > lim:
			v = v.normalized() * lim
		return Vector3(v.x, pos.y, v.y)
	return Vector3(clampf(pos.x, -half.x + r, half.x - r), pos.y, clampf(pos.z, -half.y + r, half.y - r))


## La capsule (hitbox) touche-t-elle un obstacle "bounce" ? Renvoie le point de contact ou null.
func capsule_hits_obstacle(cap: Array):
	var a: Vector3 = cap[0]
	var b: Vector3 = cap[1]
	var r: float = cap[2]
	for box in boxes:
		if not box["bounce"]:
			continue
		var mn: Vector3 = box["min"]
		var mx: Vector3 = box["max"]
		for k in 7:
			var p := a.lerp(b, float(k) / 6.0)
			var q := Vector3(clampf(p.x, mn.x, mx.x), clampf(p.y, mn.y, mx.y), clampf(p.z, mn.z, mx.z))
			if p.distance_to(q) <= r:
				return q
	return null
