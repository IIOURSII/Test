class_name ControlsSetup
extends RefCounted
## Crée les actions Godot à partir de data/config/controls.json.


static func apply(controls: Dictionary) -> void:
	var bindings: Dictionary = controls.get("bindings", {})
	for action in bindings.keys():
		if InputMap.has_action(action):
			InputMap.erase_action(action)
		InputMap.add_action(action)
		for key_name in bindings[action]:
			var ev := _make_event(str(key_name))
			if ev != null:
				InputMap.action_add_event(action, ev)


static func _make_event(key_name: String) -> InputEvent:
	var mouse_buttons := {
		"MOUSE_LEFT": MOUSE_BUTTON_LEFT,
		"MOUSE_RIGHT": MOUSE_BUTTON_RIGHT,
		"MOUSE_MIDDLE": MOUSE_BUTTON_MIDDLE,
		"MOUSE_4": MOUSE_BUTTON_XBUTTON1,
		"MOUSE_5": MOUSE_BUTTON_XBUTTON2,
	}
	var upper := key_name.to_upper()
	if mouse_buttons.has(upper):
		var mb := InputEventMouseButton.new()
		mb.button_index = mouse_buttons[upper]
		return mb
	var code := OS.find_keycode_from_string(key_name)
	if code == KEY_NONE:
		push_warning("Touche inconnue dans controls.json : '%s'" % key_name)
		return null
	var k := InputEventKey.new()
	k.keycode = code
	return k
