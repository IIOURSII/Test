class_name DifficultySelect
extends CanvasLayer
## Choix de la difficulté de l'IA (profils dans data/ai.json).

signal done(id: String)
signal back


func setup(profiles: Dictionary) -> void:
	add_child(UiStyle.side_shade(0.55, 0.92))
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	var head := HBoxContainer.new()
	head.position = Vector2(80, 50)
	head.add_theme_constant_override("separation", 20)
	root.add_child(head)
	head.add_child(UiStyle.seal("敵", 72))
	var tt := VBoxContainer.new()
	tt.add_child(UiStyle.label("DUEL CONTRE L'IA", 44, UiStyle.PAPER))
	tt.add_child(UiStyle.label(UiStyle.spaced("CHOISIS TON ADVERSAIRE") + "   ·   2 rounds gagnants", 14, UiStyle.MUTED))
	head.add_child(tt)
	var list := VBoxContainer.new()
	list.position = Vector2(120, 200)
	list.add_theme_constant_override("separation", 10)
	root.add_child(list)
	for id in ["facile", "normal", "difficile"]:
		if not profiles.has(id):
			continue
		var pr: Dictionary = profiles[id]
		var b := UiStyle.menu_button(str(pr.get("label", id)), str(pr.get("desc", "")), false, 32)
		b.custom_minimum_size.x = 760
		var key: String = id
		b.pressed.connect(func() -> void: done.emit(key))
		list.add_child(b)
	var bb := UiStyle.menu_button("Retour", "", false, 24)
	bb.pressed.connect(func() -> void: back.emit())
	list.add_child(bb)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		back.emit()
