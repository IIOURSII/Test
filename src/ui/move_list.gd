class_name MoveList
extends CanvasLayer
## Liste des coups consultable en jeu (Tab). S'adapte à la garde : en garde
## gauche, les inputs affichés sont inversés (ce que tu dois VRAIMENT taper).

var panel: PanelContainer
var text: RichTextLabel
var _last_guard: int = 0


func setup() -> void:
	layer = 10
	panel = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.08, 0.92)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(24)
	panel.add_theme_stylebox_override("panel", style)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 140
	panel.offset_right = -140
	panel.offset_top = 50
	panel.offset_bottom = -50
	add_child(panel)
	text = RichTextLabel.new()
	text.bbcode_enabled = true
	text.scroll_active = true
	text.add_theme_font_size_override("normal_font_size", 17)
	text.add_theme_font_size_override("bold_font_size", 18)
	panel.add_child(text)
	visible = false


func toggle() -> void:
	visible = not visible


func refresh(moves: MoveSet, guard: int, controls: Dictionary, force: bool = false) -> void:
	if not visible:
		return
	if guard == _last_guard and not force:
		return
	_last_guard = guard
	var left := guard == FighterState.GUARD_LEFT
	var b: Dictionary = controls.get("bindings", {})
	var k_left := _key(b, "left", "Q")
	var k_right := _key(b, "right", "D")
	var k_back := _key(b, "back", "S")

	var s := ""
	s += "[font_size=26][b]LISTE DES COUPS — %s[/b][/font_size]     " % moves.weapon_name.to_upper()
	s += "[color=%s][b]GARDE %s[/b][/color]" % ["#ff9a5a" if left else "#7fd0ff", "GAUCHE (inputs inversés)" if left else "DROITE"]
	s += "     [color=#888](Tab pour fermer)[/color]\n\n"
	s += "[color=#bbb]Notation : [b]4[/b] = %s   [b]6[/b] = %s   [b]2[/b] = %s   [b]1[/b] = %s+%s   [b]3[/b] = %s+%s   [b]5[/b] = sans direction. " % [k_left, k_right, k_back, k_back, k_left, k_back, k_right]
	s += "Avancer, sauter et s'accroupir ne comptent pas.\n"
	s += "Exemple : [b]236[/b] = %s, puis %s+%s, puis %s, puis clic.   [b]66[/b] = %s deux fois puis clic.[/color]\n\n" % [k_back, k_back, k_right, k_right, k_right]
	s += "[color=#e05a4a][b]LAME[/b] = clic gauche[/color]     [color=#e0c04a][b]POMMEAU[/b] = clic droit[/color]\n\n"

	for input in MoveSet.INPUT_ORDER:
		var shown: String = MoveSet.mirror_notation(input) if left else input
		var blade := moves.get_move(input + "_blade")
		var pommel := moves.get_move(input + "_pommel")
		s += "[font_size=22][b][color=#ffffff]%s[/color][/b][/font_size]\n" % shown
		if not blade.is_empty():
			s += "    [color=#e05a4a][b]LAME[/b][/color]  [b]%s[/b] — %s  [color=#888](%s)[/color]\n" % [blade["name"], blade["desc"], _fd(blade)]
		if not pommel.is_empty():
			s += "    [color=#e0c04a][b]POMMEAU[/b][/color]  [b]%s[/b] — %s  [color=#888](%s)[/color]\n" % [pommel["name"], pommel["desc"], _fd(pommel)]
		s += "\n"
	text.text = s


func _fd(m: Dictionary) -> String:
	return "%d / %d / %d" % [m["startup"], m["active"], m["recovery"]]


func _key(bindings: Dictionary, action: String, fallback: String) -> String:
	var arr: Array = bindings.get(action, [])
	return str(arr[0]) if arr.size() > 0 else fallback
