class_name ShieldEmblem
extends Control
## Blason (écu allemand) portant un kanji : la DA "fusion Japon / Allemagne médiévale".
## L'écu est parti en deux couleurs (champ héraldique), bordé d'or, le kanji au centre comme un mon.

var field_a: Color = Color(0.08, 0.07, 0.08)
var field_b: Color = Color(0.78, 0.6, 0.18)
var border: Color = Color(0.93, 0.76, 0.36)
var kanji: String = ""
var _label: Label


func setup(k: String, size_px: float, a: Color = Color(0.08, 0.07, 0.08), b: Color = Color(0.72, 0.1, 0.1)) -> ShieldEmblem:
	kanji = k
	field_a = a
	field_b = b
	custom_minimum_size = Vector2(size_px, size_px * 1.15)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label = UiStyle.label(k, int(size_px * (0.5 if k.length() <= 1 else 0.3)), Color(0.98, 0.94, 0.85), UiStyle.cjk(), 8)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.size = Vector2(size_px, size_px)
	_label.position = Vector2(0, size_px * 0.04)
	add_child(_label)
	queue_redraw()
	return self


func _shape(w: float, h: float, inset: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	pts.append(Vector2(inset, inset))
	pts.append(Vector2(w - inset, inset))
	pts.append(Vector2(w - inset, h * 0.55))
	for i in 9:
		var t := float(i) / 8.0
		var x := lerpf(w - inset, w * 0.5, t)
		var y := h * 0.55 + (h - inset - h * 0.55) * sin(t * PI * 0.5)
		pts.append(Vector2(x, y))
	for i in range(1, 9):
		var t := float(i) / 8.0
		var x := lerpf(w * 0.5, inset, t)
		var y := h - inset - (h - inset - h * 0.55) * (1.0 - cos(t * PI * 0.5))
		pts.append(Vector2(x, y))
	pts.append(Vector2(inset, h * 0.55))
	return pts


func _draw() -> void:
	var w := size.x
	var h := size.y
	draw_colored_polygon(_shape(w, h, 0.0), Color(0.03, 0.02, 0.03))
	var inner := _shape(w, h, 4.0)
	draw_colored_polygon(inner, field_a)
	# Parti : la moitié droite de l'écu dans la seconde couleur.
	var right := PackedVector2Array()
	for p in inner:
		right.append(Vector2(maxf(p.x, w * 0.5), p.y))
	draw_colored_polygon(right, field_b)
	var outline := _shape(w, h, 3.0)
	outline.append(outline[0])
	draw_polyline(outline, border, 2.5)
	draw_line(Vector2(w * 0.5, 4), Vector2(w * 0.5, h - 4), Color(border, 0.6), 1.5)
