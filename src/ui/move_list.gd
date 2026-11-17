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
	text.clear()

	var s := ""
	s += "[font_size=26][b]LISTE DES COUPS — %s[/b][/font_size]     " % moves.weapon_name.to_upper()
	s += "[color=%s][b]GARDE %s[/b][/color]" % ["#ff9a5a" if left else "#7fd0ff", "GAUCHE (flèches inversées)" if left else "DROITE"]
	s += "     [color=#888](Tab pour fermer)[/color]\n\n"
	s += "[color=#e8dcc8][b]COMMENT ÇA MARCHE[/b] — le jeu retient tes [b]3 dernières directions différentes[/b] "
	s += "(← = %s, → = %s, ↓ = %s, ↙ = %s+%s, ↘ = %s+%s ; avancer, sauter et s'accroupir ne comptent pas), " % [k_left, k_right, k_back, k_back, k_left, k_back, k_right]
	s += "sans limite de temps. Un [b]clic[/b] confirme le coup — [b]à n'importe quel moment[/b], même en plein milieu d'un autre coup ou d'un dash (il l'annule). "
	s += "La mémoire n'est [b]jamais effacée[/b] : re-cliquer relance le même coup tant que tu ne tapes pas d'autre direction. "
	s += "Le coup de base (aucune direction) n'existe qu'au tout début du combat, avant tes 3 premières directions. Regarde l'indicateur en bas de l'écran.[/color]\n\n"
	s += "[color=#e05a4a][b]LAME[/b] = clic gauche[/color]     [color=#e0c04a][b]POMMEAU[/b] = clic droit[/color]\n\n"
	if moves.mechanic_desc != "":
		s += "[color=#ff8a8a]%s[/color]\n\n" % moves.mechanic_desc
	s += "[color=#9fc8ff][b]DÉFENSE[/b] — maintenir [b]E[/b] = garde (de face seulement). Appuyer sur [b]E[/b] juste avant l'impact = [b]PARRY[/b]. "
	s += "Les overheads se bloquent DEBOUT, les coups bas ACCROUPI. La LAME bat le POMMEAU (en cas d'échange), le POMMEAU brise la GARDE, la GARDE bat la LAME. "
	s += "Lis le [b]reflet[/b] sur la lame adverse : il annonce le coup.\n"
	s += "[b]CLASH[/b] = deux lames qui se touchent : MARTÈLE le clic gauche.   [b]POTION[/b] = R.   [b]PROVOCATION[/b] = T.   [b]BURST[/b] = F quand tu encaisses un combo.[/color]\n\n"
	text.append_text(s)

	for input in MoveSet.INPUT_ORDER:
		var shown: String = MoveSet.mirror_notation(input) if left else input
		_arrows(shown)
		if input == "236":
			text.append_text("   [b][color=#e8f4ff]DASH[/color][/b] — commun à toutes les armes. Clic quelconque. Droit devant, ou dans la direction tapée juste après la manip (ex : ↓↘→ puis ↓ + clic = dash arrière).\n\n")
			continue
		var blade := moves.get_move(input + "_blade")
		var pommel := moves.get_move(input + "_pommel")
		var line := ""
		if input == "5":
			line += "   [color=#888](aucune direction en mémoire)[/color]"
		line += "\n"
		if not blade.is_empty():
			line += "    [color=#e05a4a][b]LAME[/b][/color]  [b]%s[/b] — %s  [color=#888](%s)[/color]\n" % [blade["name"], blade["desc"], _fd(blade)]
		if not pommel.is_empty():
			line += "    [color=#e0c04a][b]POMMEAU[/b][/color]  [b]%s[/b] — %s  [color=#888](%s)[/color]\n" % [pommel["name"], pommel["desc"], _fd(pommel)]
		text.append_text(line + "\n")


func _arrows(notation: String) -> void:
	for c in notation:
		text.add_image(ArrowIcons.texture(int(c), Color(1, 1, 1), 28), 28, 28)


func _fd(m: Dictionary) -> String:
	return "%d / %d / %d" % [m["startup"], m["active"], m["recovery"]]


func _key(bindings: Dictionary, action: String, fallback: String) -> String:
	var arr: Array = bindings.get(action, [])
	return str(arr[0]) if arr.size() > 0 else fallback
