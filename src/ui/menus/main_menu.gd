class_name MainMenu
extends CanvasLayer
## Écran titre.

signal action(id: String)


func setup() -> void:
	add_child(UiStyle.side_shade(0.55, 0.92))
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# Titre : sceau + nom (titre de travail, modifiable ici).
	var seal := UiStyle.seal("真剣", 120)
	seal.position = Vector2(90, 70)
	root.add_child(seal)
	var title := UiStyle.label("SHINKEN", 84, UiStyle.PAPER, UiStyle.serif(), 0)
	title.position = Vector2(232, 62)
	root.add_child(title)
	var sub := UiStyle.label(UiStyle.spaced("LA VOIE DU DUEL") + "     —     prototype", 16, UiStyle.MUTED)
	sub.position = Vector2(238, 160)
	root.add_child(sub)
	var line := ColorRect.new()
	line.color = UiStyle.CRIMSON
	line.position = Vector2(92, 210)
	line.size = Vector2(520, 2)
	root.add_child(line)

	var list := VBoxContainer.new()
	list.position = Vector2(120, 260)
	list.add_theme_constant_override("separation", 6)
	root.add_child(list)
	_add(list, "duel", "Duel", "contre l'IA · 2 rounds gagnants")
	_add(list, "local", "1 contre 1", "local · écran partagé · J2 à la manette")
	_add(list, "online", "Colisée", "PvP en ligne — plus tard", true)
	_add(list, "options", "Options", "")
	_add(list, "quit", "Quitter", "")

	# Catégorie DEBUG, séparée : tout ce qu'elle contient sera supprimé à la fin.
	var dbg := UiStyle.label(UiStyle.spaced("DEBUG"), 14, UiStyle.CRIMSON.lightened(0.15))
	dbg.position = Vector2(122, 660)
	root.add_child(dbg)
	var dbg_line := ColorRect.new()
	dbg_line.color = Color(UiStyle.CRIMSON, 0.5)
	dbg_line.position = Vector2(122, 684)
	dbg_line.size = Vector2(300, 1)
	root.add_child(dbg_line)
	var dlist := VBoxContainer.new()
	dlist.position = Vector2(120, 692)
	root.add_child(dlist)
	var sandbox := UiStyle.menu_button("Bac à sable", "mannequin, frame data, hitbox", false, 22)
	sandbox.pressed.connect(func() -> void: action.emit("sandbox"))
	dlist.add_child(sandbox)

	var foot := UiStyle.label("Échap : retour     ·     souris : naviguer", 13, UiStyle.MUTED)
	foot.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	foot.position += Vector2(122, -40)
	root.add_child(foot)


func _add(list: VBoxContainer, id: String, text: String, hint: String, locked: bool = false) -> void:
	var b := UiStyle.menu_button(text, hint, locked)
	b.pressed.connect(func() -> void: action.emit(id))
	list.add_child(b)
