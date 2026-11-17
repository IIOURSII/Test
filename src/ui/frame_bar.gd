class_name FrameBar
extends Control
## Barre de frame data façon mode training :
## vert = startup, rouge = active, bleu = recovery, cadre blanc = tick actuel.

const H := 16.0
const COL_STARTUP := Color(0.35, 0.85, 0.35)
const COL_ACTIVE := Color(0.95, 0.2, 0.15)
const COL_RECOVERY := Color(0.3, 0.5, 0.95)
const COL_INACTIVE := Color(0.45, 0.45, 0.45)

var startup: int = 0
var active: int = 0
var recovery: int = 0
var current: int = 0
## Ticks où une hitbox existe réellement (peut différer de la phase "active").
var hit_ticks: Dictionary = {}


func set_data(m: Dictionary, tick: int) -> void:
	startup = int(m.get("startup", 0))
	active = int(m.get("active", 0))
	recovery = int(m.get("recovery", 0))
	current = tick
	hit_ticks.clear()
	for hb in m.get("hitboxes", []):
		var r: Vector2i = hb["ticks"]
		for t in range(r.x, r.y + 1):
			hit_ticks[t] = true
	custom_minimum_size = Vector2(_cell_w() * _total() + 2, H + 2)
	queue_redraw()


func clear() -> void:
	startup = 0
	active = 0
	recovery = 0
	queue_redraw()


func _total() -> int:
	return startup + active + recovery


func _cell_w() -> float:
	return clampf(560.0 / maxf(float(_total()), 1.0), 3.0, 8.0)


func _draw() -> void:
	var total := _total()
	if total <= 0:
		return
	var w := _cell_w()
	for t in range(1, total + 1):
		var col := COL_RECOVERY
		if t <= startup:
			col = COL_STARTUP
		elif t <= startup + active:
			col = COL_ACTIVE if (hit_ticks.is_empty() or hit_ticks.has(t)) else COL_INACTIVE
		elif hit_ticks.has(t):
			col = COL_ACTIVE
		draw_rect(Rect2(1 + (t - 1) * w, 1, w - 1, H), col)
	if current >= 1 and current <= total:
		draw_rect(Rect2((current - 1) * w, 0, w + 1, H + 2), Color.WHITE, false, 2.0)
