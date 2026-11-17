class_name Hud
extends CanvasLayer
## Interface : viseur, barres de vie, garde, panneau debug façon mode training (F1).

const HISTORY_SIZE := 20
const BAR_W := 520.0

var debug_label: Label
var move_label: Label
var frame_bar: FrameBar
var combo_label: Label
var history_label: Label
var guard_label: Label
var hint_label: Label
var crosshair: ColorRect
var hp_fill: Array[ColorRect] = []
var hp_text: Array[Label] = []
var guard_fill: Array[ColorRect] = []
var burst_fill: Array[ColorRect] = []
var popup_label: Label
var popup_box: Control
var popup_kanji: Label
var popup_seal: ColorRect
var _seal_mat: ShaderMaterial
var weapon_label: Label
var pip_rects: Array[ColorRect] = []
var edge_fill: ColorRect
var charge_fill: ColorRect
var _cjk_font: SystemFont
var damage_flash: ColorRect
var dummy_label: Label
var _popup_tw: Tween
var bind_box: Control
var bind_fill_me: ColorRect
var bind_fill_them: ColorRect
var potion_label: Label

var _history: Array = []        ## [{"dir": int, "btn": String, "n": int}, ...] le plus récent en premier
var _shown_move: String = ""    ## dernier coup affiché (reste visible après la fin)
var _shown_tick: int = 0


func setup() -> void:
	crosshair = ColorRect.new()
	crosshair.color = Color(1, 1, 1, 0.8)
	crosshair.size = Vector2(4, 4)
	crosshair.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	add_child(crosshair)

	damage_flash = ColorRect.new()
	damage_flash.color = Color(0.8, 0.0, 0.0, 0.0)
	damage_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	damage_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(damage_flash)

	_make_hp_bar(0, "TOI", -BAR_W - 20.0)
	_make_hp_bar(1, "MANNEQUIN", 20.0)

	_cjk_font = SystemFont.new()
	_cjk_font.font_names = PackedStringArray(["Yu Mincho", "MS Mincho", "Noto Serif CJK JP", "Hiragino Mincho ProN",
			"Noto Sans CJK JP", "Yu Gothic", "MS Gothic", "Hiragino Sans"])
	_cjk_font.font_weight = 700

	# Popup : sceau rouge (hanko) avec le kanji, et le nom du coup en petites capitales espacées.
	popup_box = Control.new()
	popup_box.set_anchors_preset(Control.PRESET_CENTER)
	popup_box.offset_left = 90
	popup_box.offset_right = 520
	popup_box.offset_top = -230
	popup_box.offset_bottom = -90
	popup_box.pivot_offset = Vector2(65, 70)
	popup_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	popup_box.modulate.a = 0.0
	add_child(popup_box)

	popup_seal = ColorRect.new()
	_seal_mat = ShaderMaterial.new()
	_seal_mat.shader = load("res://shaders/hanko.gdshader")
	popup_seal.material = _seal_mat
	popup_seal.position = Vector2(0, 5)
	popup_seal.size = Vector2(130, 130)
	popup_box.add_child(popup_seal)

	popup_kanji = Label.new()
	popup_kanji.add_theme_font_override("font", _cjk_font)
	popup_kanji.add_theme_font_size_override("font_size", 92)
	popup_kanji.add_theme_color_override("font_color", Color(1.0, 0.95, 0.88))
	popup_kanji.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	popup_kanji.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	popup_kanji.position = Vector2(0, 5)
	popup_kanji.size = Vector2(130, 130)
	popup_box.add_child(popup_kanji)

	popup_label = _make_label(22)
	popup_label.add_theme_constant_override("outline_size", 6)
	popup_label.position = Vector2(148, 52)
	popup_label.size = Vector2(300, 40)
	popup_box.add_child(popup_label)

	# Jauge de bind : qui martèle le plus vite.
	bind_box = Control.new()
	bind_box.set_anchors_preset(Control.PRESET_CENTER)
	bind_box.offset_left = -260
	bind_box.offset_right = 260
	bind_box.offset_top = 120
	bind_box.offset_bottom = 190
	bind_box.visible = false
	add_child(bind_box)
	var bl := _make_label(26)
	bl.text = "CLIQUE !  CLIQUE !  CLIQUE !"
	bl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bl.size = Vector2(520, 34)
	bind_box.add_child(bl)
	var bbg := ColorRect.new()
	bbg.color = Color(0, 0, 0, 0.7)
	bbg.position = Vector2(0, 40)
	bbg.size = Vector2(520, 18)
	bind_box.add_child(bbg)
	bind_fill_me = ColorRect.new()
	bind_fill_me.color = Color(1.0, 0.85, 0.4)
	bind_fill_me.position = Vector2(0, 42)
	bind_fill_me.size = Vector2(260, 14)
	bind_box.add_child(bind_fill_me)
	bind_fill_them = ColorRect.new()
	bind_fill_them.color = Color(0.8, 0.15, 0.12)
	bind_fill_them.position = Vector2(260, 42)
	bind_fill_them.size = Vector2(260, 14)
	bind_box.add_child(bind_fill_them)

	potion_label = _make_label(15)
	potion_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	potion_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	potion_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	potion_label.offset_left -= 20
	potion_label.offset_right -= 20
	potion_label.offset_top -= 20
	potion_label.offset_bottom -= 20
	add_child(potion_label)

	dummy_label = _make_label(16)
	dummy_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	dummy_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dummy_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	dummy_label.offset_top = 78
	dummy_label.offset_bottom = 100
	add_child(dummy_label)

	var col := VBoxContainer.new()
	col.position = Vector2(16, 70)
	col.add_theme_constant_override("separation", 6)
	add_child(col)
	debug_label = _make_label(15)
	col.add_child(debug_label)
	move_label = _make_label(18)
	col.add_child(move_label)
	frame_bar = FrameBar.new()
	col.add_child(frame_bar)
	combo_label = _make_label(18)
	col.add_child(combo_label)

	history_label = _make_label(18)
	var mono := SystemFont.new()
	mono.font_names = PackedStringArray(["Consolas", "DejaVu Sans Mono", "Menlo", "Courier New", "monospace"])
	history_label.add_theme_font_override("font", mono)
	history_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	history_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	history_label.offset_top = 70
	history_label.offset_right = -20
	history_label.offset_left = -20
	add_child(history_label)

	guard_label = _make_label(26)
	guard_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	guard_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	guard_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	guard_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	guard_label.offset_top -= 50
	guard_label.offset_bottom -= 50
	add_child(guard_label)

	hint_label = _make_label(14)
	hint_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	hint_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	hint_label.offset_left += 16
	hint_label.offset_right += 16
	hint_label.offset_top -= 16
	hint_label.offset_bottom -= 16
	add_child(hint_label)


## Panneau de la mécanique d'arme du joueur (katana : Zanshin 残心 + Tranchant 刃).
func _make_weapon_panel(parent: Control) -> void:
	weapon_label = _make_label(18)
	weapon_label.add_theme_font_override("font", _cjk_font)
	weapon_label.position = Vector2(0, 58)
	weapon_label.text = "残心"
	parent.add_child(weapon_label)
	for k in 3:
		var p := ColorRect.new()
		p.size = Vector2(16, 16)
		p.position = Vector2(48 + k * 22, 64)
		p.rotation = PI / 4.0
		p.pivot_offset = Vector2(8, 8)
		parent.add_child(p)
		pip_rects.append(p)
	var e := _make_label(18)
	e.add_theme_font_override("font", _cjk_font)
	e.position = Vector2(140, 58)
	e.text = "刃"
	parent.add_child(e)
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.6)
	bg.position = Vector2(166, 66)
	bg.size = Vector2(160, 10)
	parent.add_child(bg)
	edge_fill = ColorRect.new()
	edge_fill.position = Vector2(1, 1)
	edge_fill.size = Vector2(158, 8)
	bg.add_child(edge_fill)
	charge_fill = ColorRect.new()
	charge_fill.color = Color(1.0, 0.95, 0.85)
	charge_fill.position = Vector2(340, 66)
	charge_fill.size = Vector2(0, 10)
	parent.add_child(charge_fill)


func _update_weapon_panel(f: FighterState, moves: MoveSet) -> void:
	if pip_rects.is_empty():
		return
	var katana := KatanaMechanic.is_katana(moves)
	weapon_label.visible = katana
	for k in pip_rects.size():
		pip_rects[k].visible = katana
		var on := k < f.weapon_pips
		pip_rects[k].color = moves.style_color("aura", Color(1, 0.1, 0.1)) if on else Color(0.15, 0.12, 0.12, 0.8)
	var e := float(f.weapon_gauge) / 100.0
	edge_fill.size.x = 158.0 * e
	edge_fill.color = Color(0.85, 0.88, 0.95).lerp(Color(0.55, 0.05, 0.05), 1.0 - e)
	var mx := float(int(moves.mech("stance_max_ticks", 90)))
	charge_fill.size.x = 120.0 * clampf(float(f.charge_ticks) / mx, 0.0, 1.0) if f.in_stance else 0.0


func _make_label(font_size: int) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_constant_override("outline_size", 6)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	return l


func _make_hp_bar(i: int, title: String, x_offset: float) -> void:
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.6)
	bg.set_anchors_preset(Control.PRESET_CENTER_TOP)
	bg.offset_left = x_offset
	bg.offset_right = x_offset + BAR_W
	bg.offset_top = 20
	bg.offset_bottom = 42
	add_child(bg)
	var fill := ColorRect.new()
	fill.color = Color(0.85, 0.15, 0.12) if i == 0 else Color(0.85, 0.6, 0.15)
	fill.position = Vector2(2, 2)
	fill.size = Vector2(BAR_W - 4, 18)
	bg.add_child(fill)
	# Jauge de garde (bleu) et de burst (or), sous la barre de vie.
	var g := ColorRect.new()
	g.color = Color(0.35, 0.6, 1.0)
	g.position = Vector2(0, 24)
	g.size = Vector2(0, 5)
	bg.add_child(g)
	guard_fill.append(g)
	var bu := ColorRect.new()
	bu.color = Color(1.0, 0.78, 0.2)
	bu.position = Vector2(0, 31)
	bu.size = Vector2(0, 5)
	bg.add_child(bu)
	burst_fill.append(bu)
	var label := _make_label(14)
	label.position = Vector2(6, 38)
	bg.add_child(label)
	if i == 0:
		_make_weapon_panel(bg)
	hp_fill.append(fill)
	hp_text.append(label)
	label.text = title


## Appelé à chaque tick avec les inputs du joueur (historique façon mode training).
func record_input(frame: InputFrame) -> void:
	var dir := MotionParser.dir_from_buttons(frame.buttons)
	var btn := ""
	if frame.has(InputFrame.BLADE):
		btn += "L "
	if frame.has(InputFrame.POMMEL):
		btn += "P "
	if frame.has(InputFrame.DASH):
		btn += "Dash "
	if frame.has(InputFrame.JUMP):
		btn += "Saut "
	if frame.has(InputFrame.CROUCH):
		btn += "Accr "
	if frame.has(InputFrame.PARRY):
		btn += "E "
	if frame.has(InputFrame.BURST):
		btn += "Burst "
	if frame.has(InputFrame.GUARD):
		btn += "ChgGarde "
	if not _history.is_empty() and _history[0]["dir"] == dir and _history[0]["btn"] == btn:
		_history[0]["n"] = mini(int(_history[0]["n"]) + 1, 99)
		return
	_history.push_front({"dir": dir, "btn": btn, "n": 1})
	if _history.size() > HISTORY_SIZE:
		_history.pop_back()


## Coup de tampon : sceau rouge + kanji, et le nom en petites capitales espacées.
func popup(text: String, color: Color, kanji: String = "") -> void:
	var spaced := ""
	for c in text:
		spaced += c + " "
	popup_label.text = spaced.strip_edges()
	popup_label.add_theme_color_override("font_color", color.lightened(0.35))
	popup_kanji.text = kanji
	popup_kanji.add_theme_font_size_override("font_size", 92 if kanji.length() <= 1 else 54)
	_seal_mat.set_shader_parameter("seal_color", Color(color.r * 0.85, color.g * 0.6, color.b * 0.6, 0.95))
	_seal_mat.set_shader_parameter("seed", randf() * 100.0)
	popup_seal.visible = kanji != ""
	popup_box.modulate.a = 1.0
	popup_box.rotation = deg_to_rad(randf_range(-8.0, 8.0))
	popup_box.scale = Vector2.ONE * 1.35
	if _popup_tw:
		_popup_tw.kill()
	_popup_tw = popup_box.create_tween()
	_popup_tw.tween_property(popup_box, "scale", Vector2.ONE, 0.06)
	_popup_tw.tween_interval(0.55)
	_popup_tw.tween_property(popup_box, "modulate:a", 0.0, 0.25)


## Éclaboussure de sang à l'écran (Chiburi adverse) : gêne la vue une demi-seconde.
func blood_splash() -> void:
	var vp := get_viewport().get_visible_rect().size
	for k in 5:
		var r := ColorRect.new()
		var m := ShaderMaterial.new()
		m.shader = load("res://shaders/blood_blob.gdshader")
		m.set_shader_parameter("seed", randf() * 100.0)
		r.material = m
		var s := randf_range(180.0, 420.0)
		r.size = Vector2(s, s)
		r.position = Vector2(randf_range(vp.x * 0.15, vp.x * 0.85) - s * 0.5, randf_range(vp.y * 0.15, vp.y * 0.85) - s * 0.5)
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(r)
		var tw := r.create_tween()
		tw.tween_interval(0.45)
		tw.tween_property(r, "modulate:a", 0.0, 0.35)
		tw.tween_callback(r.queue_free)


## Voile rouge quand le joueur se fait toucher.
func hurt_flash(power: float) -> void:
	damage_flash.color.a = 0.18 + 0.2 * power
	var tw := damage_flash.create_tween()
	tw.tween_property(damage_flash, "color:a", 0.0, 0.3)


func update_hud(world: SimWorld, show_debug: bool, mouse_captured: bool, dummy_mode: String = "") -> void:
	var p := world.fighters[0]
	var moves := world.movesets[0]
	var switching := p.action == FighterState.Action.GUARD_SWITCH
	guard_label.text = "Garde %s%s" % ["DROITE" if p.guard == FighterState.GUARD_RIGHT else "GAUCHE", "  (changement...)" if switching else ""]

	for i in mini(world.fighters.size(), hp_fill.size()):
		var f := world.fighters[i]
		var ratio := float(f.hp) / float(maxi(f.max_hp, 1))
		hp_fill[i].size.x = (BAR_W - 4) * ratio
		hp_text[i].text = "%s   %d / %d" % ["TOI" if i == 0 else "MANNEQUIN", f.hp, f.max_hp]
		var gmax := float(world.cfg["guard"]["guard_max"])
		var bmax := float(world.cfg["burst"]["gauge_max"])
		guard_fill[i].size.x = BAR_W * clampf(float(f.guard_gauge) / gmax, 0.0, 1.0)
		burst_fill[i].size.x = BAR_W * clampf(float(f.burst_gauge) / bmax, 0.0, 1.0)
		burst_fill[i].color = Color(1.0, 0.85, 0.3) if f.burst_gauge >= int(bmax) else Color(0.6, 0.45, 0.15)
	dummy_label.text = "Mannequin : %s   (F2 pour changer)" % dummy_mode
	_update_weapon_panel(p, moves)
	potion_label.text = "Potion (R) : %d     Provocation : T" % p.potions_left
	var d0 := world.fighters[1]
	bind_box.visible = p.action == FighterState.Action.BIND
	if bind_box.visible:
		var lead := float(int(world.cfg["clash"]["bind_lead"]))
		var k := clampf(0.5 + float(p.bind_presses - d0.bind_presses) / (2.0 * lead), 0.0, 1.0)
		bind_fill_me.size.x = 520.0 * k
		bind_fill_them.position.x = 520.0 * k
		bind_fill_them.size.x = 520.0 * (1.0 - k)

	crosshair.visible = mouse_captured
	if mouse_captured:
		hint_label.text = "Tab : liste des coups  |  F1 : debug  |  F2 : mannequin  |  F6 : recharger  |  F7 : filtre  |  Échap : pause"
	else:
		hint_label.text = "Souris libérée : clique dans la fenêtre pour reprendre"

	debug_label.visible = show_debug
	move_label.visible = show_debug
	frame_bar.visible = show_debug
	combo_label.visible = show_debug
	history_label.visible = show_debug
	if not show_debug:
		return

	var hspeed := Vector2(p.vel.x, p.vel.z).length()
	debug_label.text = "\n".join(PackedStringArray([
		"=== DEBUG (F1) ===   FPS : %d   |   tick : %d" % [Engine.get_frames_per_second(), world.tick],
		"Vitesse : %.1f m/s   |   état : %s   |   %s" % [hspeed, p.action_name(), "au sol" if p.on_ground else "en l'air"],
		"Garde (E) : %s   |   fenêtre de parry : %d   |   anti-spam : %d   |   jauge de garde : %d   |   burst (F) : %d" % [
			"OUI" if (p.action == FighterState.Action.BLOCK or p.action == FighterState.Action.BLOCKSTUN) else "non",
			p.parry_timer, p.parry_lockout, p.guard_gauge, p.burst_gauge],
		"Buffer : %s" % (("%s %s (%d ticks)" % [p.pending_input, "LAME" if p.pending_button == "blade" else "POMMEAU", p.pending_age]) if p.pending_move != "" else "-"),
	]))

	# Coup en cours (ou le dernier, qui reste affiché pour qu'on puisse le lire).
	if p.action == FighterState.Action.ATTACK:
		_shown_move = p.move_id
		_shown_tick = p.move_tick
	var m := moves.get_move(_shown_move)
	if m.is_empty():
		move_label.text = "Coup : -"
		frame_bar.clear()
	else:
		var btn := "LAME" if m["button"] == "blade" else "POMMEAU"
		var input: String = m["input"]
		var phys: String = MoveSet.mirror_notation(input) if p.guard == FighterState.GUARD_LEFT else input
		var phase := _phase(m, _shown_tick)
		move_label.text = "Coup : %s %s — %s   [%s]   tick %d/%d   (startup %d / active %d / recovery %d)" % [
			phys, btn, m["name"], phase, _shown_tick, m["total"], m["startup"], m["active"], m["recovery"]]
		frame_bar.set_data(m, _shown_tick if p.action == FighterState.Action.ATTACK else 0)

	var d := world.fighters[1]
	var combo_hits := d.combo_hits if d.combo_hits > 0 else d.last_combo_hits
	var combo_dmg := d.combo_damage if d.combo_hits > 0 else d.last_combo_damage
	var adv := ("%+d" % p.last_advantage) if p.has_advantage_info else "-"
	combo_label.text = "Combo : %d coup(s), %d dégâts   |   Avantage (%s) : %s ticks" % [
		combo_hits, combo_dmg, "sur garde" if p.last_adv_on_block else "touché", adv]

	var lines: PackedStringArray = ["INPUTS (numpad)"]
	for e in _history:
		lines.append("%2d  %d  %s" % [e["n"], e["dir"], e["btn"]])
	history_label.text = "\n".join(lines)


func _phase(m: Dictionary, t: int) -> String:
	if t <= int(m["startup"]):
		return "STARTUP"
	if t <= int(m["startup"]) + int(m["active"]):
		return "ACTIVE"
	return "RECOVERY"
