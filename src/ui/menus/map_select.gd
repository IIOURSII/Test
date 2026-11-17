class_name MapSelect
extends CanvasLayer
## Choix de la map : la liste à gauche, le décor de la map survolée tourne en fond.

signal done(map_id: String)
signal back
signal preview(map_id: String)

var _maps: Array = []    ## [MapData]
var _current: String = ""
var _seal_holder: Control
var _name: Label
var _sub: Label
var _desc: Label
var _rows: Dictionary = {}


func setup(maps: Array, current: String) -> void:
	_maps = maps
	add_child(UiStyle.side_shade(0.48, 0.9))
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	var head := HBoxContainer.new()
	head.position = Vector2(80, 50)
	head.add_theme_constant_override("separation", 20)
	root.add_child(head)
	head.add_child(UiStyle.shield("地", 72, Color(0.12,0.2,0.12), Color(0.78,0.6,0.18)))
	var tt := VBoxContainer.new()
	tt.add_child(UiStyle.label("Choisis le terrain", 56, UiStyle.PAPER, UiStyle.gothic()))
	tt.add_child(UiStyle.label(UiStyle.spaced("TOUTES LES MAPS SONT SYMÉTRIQUES"), 14, UiStyle.MUTED))
	head.add_child(tt)

	var list := VBoxContainer.new()
	list.position = Vector2(110, 170)
	list.add_theme_constant_override("separation", 2)
	root.add_child(list)
	for m in maps:
		var md: MapData = m
		var b := UiStyle.menu_button(md.name, (md.subtitle + ("   ·   debug" if md.debug_only else "")), false, 26)
		b.mouse_entered.connect(func() -> void: _select(md.id))
		b.pressed.connect(func() -> void: done.emit(md.id))
		list.add_child(b)
		_rows[md.id] = b

	# Fiche de la map (à droite).
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiStyle.box_style(Color(0.04, 0.035, 0.04, 0.82), Color(1, 1, 1, 0.1), 1))
	panel.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	panel.offset_left = -620
	panel.offset_right = -70
	panel.offset_top = -40
	panel.offset_bottom = 300
	root.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 16)
	v.add_child(top)
	_seal_holder = Control.new()
	_seal_holder.custom_minimum_size = Vector2(90, 90)
	top.add_child(_seal_holder)
	var names := VBoxContainer.new()
	_name = UiStyle.label("", 40, UiStyle.PAPER, UiStyle.gothic())
	_sub = UiStyle.label("", 13, UiStyle.GOLD)
	names.add_child(_name)
	names.add_child(_sub)
	top.add_child(names)
	var part := UiStyle.label(UiStyle.spaced("PARTICULARITÉS"), 13, UiStyle.CRIMSON.lightened(0.2))
	v.add_child(part)
	_desc = UiStyle.label("", 17, UiStyle.PAPER.darkened(0.1))
	_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc.custom_minimum_size = Vector2(500, 120)
	v.add_child(_desc)

	var nav := HBoxContainer.new()
	nav.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	nav.position += Vector2(-560, -90)
	nav.add_theme_constant_override("separation", 30)
	root.add_child(nav)
	var bb := UiStyle.menu_button("Retour", "", false, 24)
	bb.custom_minimum_size.x = 200
	bb.pressed.connect(func() -> void: back.emit())
	nav.add_child(bb)
	var go := UiStyle.menu_button("Combattre", "", false, 24)
	go.custom_minimum_size.x = 260
	go.pressed.connect(func() -> void: done.emit(_current))
	nav.add_child(go)
	_select(current if _rows.has(current) else (maps[0] as MapData).id)


func _select(id: String) -> void:
	if id == _current:
		return
	_current = id
	for m in _maps:
		var md: MapData = m
		if md.id != id:
			continue
		for c in _seal_holder.get_children():
			c.queue_free()
		_seal_holder.add_child(UiStyle.seal(md.kanji, 90))
		_name.text = md.name
		_sub.text = UiStyle.spaced(md.subtitle.to_upper()) + ("   ·   DEBUG" if md.debug_only else "")
		_desc.text = md.desc
	preview.emit(id)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		back.emit()
