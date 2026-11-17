class_name WeaponSelect
extends CanvasLayer
## Choix de l'arme et de la classe secondaire (les verrouillées sont des aperçus du futur).

signal done(weapon_id: String, class_id: String)
signal back

var _roster: Dictionary
var _weapon: String = "katana"
var _class: String = "aucune"
var _weapon_cards: Dictionary = {}
var _class_cards: Dictionary = {}
var _info: Label


func setup(roster: Dictionary, weapon_id: String, class_id: String) -> void:
	_roster = roster
	_weapon = weapon_id
	_class = class_id
	add_child(UiStyle.full_shade(0.62))
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	var head := HBoxContainer.new()
	head.position = Vector2(80, 50)
	head.add_theme_constant_override("separation", 20)
	root.add_child(head)
	head.add_child(UiStyle.seal("武", 72))
	var tt := VBoxContainer.new()
	tt.add_child(UiStyle.label("CHOISIS TA LAME", 44, UiStyle.PAPER))
	tt.add_child(UiStyle.label(UiStyle.spaced("ARME") + "   ·   " + UiStyle.spaced("CLASSE SECONDAIRE"), 14, UiStyle.MUTED))
	head.add_child(tt)

	var cards := HBoxContainer.new()
	cards.position = Vector2(80, 160)
	cards.add_theme_constant_override("separation", 22)
	root.add_child(cards)
	for w in roster.get("weapons", []):
		var c := _weapon_card(w)
		cards.add_child(c)
		_weapon_cards[w["id"]] = c

	var ct := UiStyle.label(UiStyle.spaced("CLASSE SECONDAIRE"), 18, UiStyle.GOLD)
	ct.position = Vector2(82, 590)
	root.add_child(ct)
	var cdesc := UiStyle.label("Modifie l'arme sans changer son gameplay de base, mais change ta façon de l'utiliser.", 14, UiStyle.MUTED)
	cdesc.position = Vector2(82, 616)
	root.add_child(cdesc)
	var crow := HBoxContainer.new()
	crow.position = Vector2(80, 648)
	crow.add_theme_constant_override("separation", 14)
	root.add_child(crow)
	for c in roster.get("classes", []):
		var cc := _class_card(c)
		crow.add_child(cc)
		_class_cards[c["id"]] = cc

	_info = UiStyle.label("", 15, UiStyle.PAPER)
	_info.position = Vector2(82, 770)
	_info.size = Vector2(1100, 40)
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(_info)

	var nav := HBoxContainer.new()
	nav.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	nav.position += Vector2(-560, -90)
	nav.add_theme_constant_override("separation", 30)
	root.add_child(nav)
	var bb := UiStyle.menu_button("Retour", "", false, 24)
	bb.custom_minimum_size.x = 200
	bb.pressed.connect(func() -> void: back.emit())
	nav.add_child(bb)
	var go := UiStyle.menu_button("Continuer", "choix de la map", false, 24)
	go.custom_minimum_size.x = 260
	go.pressed.connect(func() -> void: done.emit(_weapon, _class))
	nav.add_child(go)
	_refresh()


func _weapon_card(w: Dictionary) -> Control:
	var locked := not bool(w.get("available", false))
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(300, 400)
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	card.add_child(v)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 14)
	v.add_child(top)
	top.add_child(UiStyle.seal(str(w["kanji"]), 80, UiStyle.CRIMSON if not locked else UiStyle.MUTED.darkened(0.3)))
	var names := VBoxContainer.new()
	names.add_child(UiStyle.label(str(w["name"]), 28, UiStyle.PAPER if not locked else UiStyle.MUTED))
	names.add_child(UiStyle.label(UiStyle.spaced(str(w["archetype"]).to_upper()), 12, UiStyle.GOLD if not locked else UiStyle.MUTED))
	top.add_child(names)
	var d := UiStyle.label(str(w["desc"]), 14, UiStyle.PAPER.darkened(0.15))
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.custom_minimum_size = Vector2(260, 60)
	v.add_child(d)
	var stats: Dictionary = w.get("stats", {})
	for k in stats.keys():
		var row := HBoxContainer.new()
		var lk := UiStyle.label(UiStyle.spaced(str(k).to_upper()), 11, UiStyle.MUTED)
		lk.custom_minimum_size = Vector2(130, 0)
		row.add_child(lk)
		for i in 5:
			var pip := ColorRect.new()
			pip.custom_minimum_size = Vector2(18, 8)
			pip.color = (UiStyle.CRIMSON if not locked else UiStyle.MUTED) if i < int(stats[k]) else Color(1, 1, 1, 0.08)
			row.add_child(pip)
		row.add_theme_constant_override("separation", 4)
		v.add_child(row)
	var mech := UiStyle.label(("MÉCANIQUE — " + str(w["mechanic"])) if not locked else UiStyle.spaced("BIENTÔT"), 14,
			UiStyle.GOLD if not locked else UiStyle.CRIMSON.lightened(0.2))
	v.add_child(mech)
	card.set_meta("locked", locked)
	if not locked:
		card.gui_input.connect(func(ev: InputEvent) -> void:
			if ev is InputEventMouseButton and ev.is_pressed():
				_weapon = str(w["id"])
				_refresh())
	card.mouse_entered.connect(func() -> void: _info.text = str(w["desc"]) if not locked else "%s — en préparation (phase 2)." % w["name"])
	return card


func _class_card(c: Dictionary) -> Control:
	var locked := not bool(c.get("available", false))
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(220, 100)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	card.add_child(h)
	h.add_child(UiStyle.seal(str(c["kanji"]), 56, UiStyle.CRIMSON if not locked else UiStyle.MUTED.darkened(0.3)))
	var v := VBoxContainer.new()
	v.add_child(UiStyle.label(str(c["name"]), 22, UiStyle.PAPER if not locked else UiStyle.MUTED))
	v.add_child(UiStyle.label(UiStyle.spaced("CONCEPT") if locked else UiStyle.spaced("DISPONIBLE"), 11,
			UiStyle.CRIMSON.lightened(0.2) if locked else UiStyle.GOLD))
	h.add_child(v)
	if not locked:
		card.gui_input.connect(func(ev: InputEvent) -> void:
			if ev is InputEventMouseButton and ev.is_pressed():
				_class = str(c["id"])
				_refresh())
	card.mouse_entered.connect(func() -> void: _info.text = str(c["desc"]))
	return card


func _refresh() -> void:
	for id in _weapon_cards.keys():
		var card: PanelContainer = _weapon_cards[id]
		var sel: bool = id == _weapon
		var locked: bool = card.get_meta("locked", false)
		card.add_theme_stylebox_override("panel", UiStyle.box_style(
				Color(0.08, 0.05, 0.05, 0.9) if sel else Color(0.04, 0.035, 0.04, 0.78 if not locked else 0.55),
				UiStyle.CRIMSON if sel else Color(1, 1, 1, 0.08), 3 if sel else 1))
	for id in _class_cards.keys():
		var card: PanelContainer = _class_cards[id]
		var sel: bool = id == _class
		card.add_theme_stylebox_override("panel", UiStyle.box_style(
				Color(0.08, 0.05, 0.05, 0.9) if sel else Color(0.04, 0.035, 0.04, 0.6),
				UiStyle.GOLD if sel else Color(1, 1, 1, 0.08), 2 if sel else 1))


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		back.emit()
