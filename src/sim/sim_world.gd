class_name SimWorld
extends RefCounted
## La "vérité" du jeu. Avance de 1 tick à chaque appel de step().
## Ne contient que des données : on peut la copier (snapshot) et la restaurer.

var cfg: Dictionary
var tick: int = 0
var fighters: Array[FighterState] = []


func _init(config: Dictionary) -> void:
	cfg = config


func add_fighter(pos: Vector3, yaw_radians: float) -> FighterState:
	var f := FighterState.new()
	f.id = fighters.size()
	f.pos = pos
	f.yaw = InputFrame.yaw_to_int(yaw_radians)
	f.max_hp = int(cfg["fighter"]["max_hp"])
	f.hp = f.max_hp
	fighters.append(f)
	return f


## inputs[i] = InputFrame du combattant i pour ce tick.
func step(inputs: Array) -> void:
	for i in fighters.size():
		FighterLogic.step(fighters[i], inputs[i], cfg)
	_resolve_pushboxes()
	_clamp_to_arena()
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


## Les combattants ne peuvent pas se traverser (sauf coups spéciaux, plus tard).
func _resolve_pushboxes() -> void:
	var r: float = cfg["fighter"]["radius"]
	var h: float = cfg["fighter"]["height"]
	var min_d := r * 2.0
	for i in fighters.size():
		for j in range(i + 1, fighters.size()):
			var a := fighters[i]
			var b := fighters[j]
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
