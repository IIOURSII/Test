class_name PauseMenu
extends CanvasLayer
## Menu pause (Échap en jeu).

signal action(id: String)


func setup() -> void:
	layer = 15
	add_child(UiStyle.side_shade(0.5, 0.92))
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	var head := HBoxContainer.new()
	head.position = Vector2(80, 80)
	head.add_theme_constant_override("separation", 20)
	root.add_child(head)
	head.add_child(UiStyle.seal("休", 72))
	head.add_child(UiStyle.label("PAUSE", 44, UiStyle.PAPER))
	var list := VBoxContainer.new()
	list.position = Vector2(120, 220)
	list.add_theme_constant_override("separation", 6)
	root.add_child(list)
	for e in [["resume", "Reprendre", ""], ["options", "Options", ""], ["menu", "Menu principal", "quitter le combat"]]:
		var b := UiStyle.menu_button(e[1], e[2])
		var id: String = e[0]
		b.pressed.connect(func() -> void: action.emit(id))
		list.add_child(b)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		action.emit("resume")
