class_name ArrowIcons
extends RefCounted
## Flèches dessinées en pixel art (pas besoin de police) pour la notation des coups.
## Directions numpad : 1 ↙  2 ↓  3 ↘  4 ←  6 →  (5 = point, "aucune direction").

const ANGLES := {2: 180.0, 4: -90.0, 6: 90.0, 1: -135.0, 3: 135.0, 8: 0.0, 7: -45.0, 9: 45.0}

static var _cache: Dictionary = {}


static func texture(dir: int, color: Color = Color(0.95, 0.91, 0.83), size: int = 24) -> ImageTexture:
	var key := "%d_%s_%d" % [dir, color.to_html(), size]
	if _cache.has(key):
		return _cache[key]
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var ink := Color(0.04, 0.03, 0.035)
	for y in size:
		for x in size:
			var p := Vector2((x + 0.5) / size * 2.0 - 1.0, (y + 0.5) / size * 2.0 - 1.0)
			if _inside(dir, p):
				img.set_pixel(x, y, color)
			elif _near(dir, p, 2.4 / size):
				img.set_pixel(x, y, ink)   # contour encre
	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex


static func _inside(dir: int, p: Vector2) -> bool:
	if dir == 5:
		return p.length() < 0.28
	var a := deg_to_rad(float(ANGLES.get(dir, 0.0)))
	var q := p.rotated(-a)   # repère où la flèche pointe vers le haut (y négatif)
	var shaft := absf(q.x) < 0.17 and q.y > -0.15 and q.y < 0.78
	var head := q.y >= -0.86 and q.y <= -0.06 and absf(q.x) <= (q.y + 0.86) * 0.82
	return shaft or head


static func _near(dir: int, p: Vector2, r: float) -> bool:
	for o in [Vector2(r, 0), Vector2(-r, 0), Vector2(0, r), Vector2(0, -r)]:
		if _inside(dir, p + o):
			return true
	return false


## Une rangée de flèches pour une notation ("236" -> ↓↘→) : à mettre dans un HBoxContainer.
static func row(notation: String, color: Color = Color(0.95, 0.91, 0.83), size: int = 24) -> HBoxContainer:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 2)
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for c in notation:
		var tr := TextureRect.new()
		tr.texture = texture(int(c), color, size)
		tr.custom_minimum_size = Vector2(size, size)
		tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hb.add_child(tr)
	return hb
