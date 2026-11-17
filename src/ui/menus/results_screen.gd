class_name ResultsScreen
extends CanvasLayer
## Fin de match : victoire / défaite, score, revanche.

signal action(id: String)


func setup(title: String, good: bool, score: Array, names: Array) -> void:
	layer = 18
	add_child(UiStyle.full_shade(0.7))
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_CENTER)
	v.offset_left = -360
	v.offset_right = 360
	v.offset_top = -230
	v.offset_bottom = 230
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 18)
	root.add_child(v)
	var seal_row := CenterContainer.new()
	seal_row.add_child(UiStyle.seal("勝" if good else "負", 130, UiStyle.CRIMSON if good else UiStyle.MUTED.darkened(0.2)))
	v.add_child(seal_row)
	var t := UiStyle.label(title, 64, UiStyle.PAPER)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var sc := UiStyle.label("%s   %d  —  %d   %s" % [names[0], score[0], score[1], names[1]], 22, UiStyle.GOLD)
	sc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sc)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 40)
	v.add_child(row)
	for e in [["rematch", "Revanche"], ["menu", "Menu principal"]]:
		var b := UiStyle.menu_button(e[1], "", false, 26)
		b.custom_minimum_size.x = 280
		var id: String = e[0]
		b.pressed.connect(func() -> void: action.emit(id))
		row.add_child(b)
