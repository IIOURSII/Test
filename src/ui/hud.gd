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
var popup_brush: Panel
var _brush_style: StyleBoxFlat
var damage_flash: ColorRect
var dummy_label: Label
var _popup_tw: Tween

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

	# Popup "aura" : trait de pinceau + kanji géant + sous-titre.
	popup_box = Control.new()
	popup_box.set_anchors_preset(Control.PRESET_CENTER)
	popup_box.offset_left = -330
	popup_box.offset_right = 330
	popup_box.offset_top = -300
	popup_box.offset_bottom = -60
	popup_box.pivot_offset = Vector2(330, 120)
	popup_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	popup_box.modulate.a = 0.0
	add_child(popup_box)

	popup_brush = Panel.new()
	_brush_style = StyleBoxFlat.new()
	_brush_style.bg_color = Color(0.05, 0.02, 0.02, 0.85)
	_brush_style.skew = Vector2(0.35, 0.0)
	_brush_style.set_corner_radius_all(40)
	popup_brush.add_theme_stylebox_override("panel", _brush_style)
	popup_brush.position = Vector2(30, 95)
	popup_brush.size = Vector2(600, 70)
	popup_brush.pivot_offset = Vector2(300, 35)
	popup_box.add_child(popup_brush)

	popup_kanji = Label.new()
	var brush_font := SystemFont.new()
	brush_font.font_names = PackedStringArray(["Yu Mincho", "MS Mincho", "Noto Serif CJK JP", "Hiragino Mincho ProN",
			"Noto Sans CJK JP", "Yu Gothic", "MS Gothic", "Hiragino Sans"])
	brush_font.font_weight = 800
	popup_kanji.add_theme_font_override("font", brush_font)
	popup_kanji.add_theme_font_size_override("font_size", 150)
	popup_kanji.add_theme_constant_override("outline_size", 18)
	popup_kanji.add_theme_color_override("font_outline_color", Color(0.02, 0.0, 0.0))
	popup_kanji.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	popup_kanji.position = Vector2(0, -20)
	popup_kanji.size = Vector2(660, 190)
	popup_box.add_child(popup_kanji)

	popup_label = _make_label(34)
	popup_label.add_theme_constant_override("outline_size", 10)
	popup_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	popup_label.position = Vector2(0, 108)
	popup_label.size = Vector2(660, 50)
	popup_box.add_child(popup_label)

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


## Gros kanji au pinceau + sous-titre : 斬 COUNTER, 弾 PARRY, 破 GUARD BREAK...
func popup(text: String, color: Color, kanji: String = "") -> void:
	popup_label.text = text
	popup_label.add_theme_color_override("font_color", color)
	popup_kanji.text = kanji
	popup_kanji.add_theme_color_override("font_color", color.lightened(0.15))
	_brush_style.bg_color = Color(color.r * 0.25, color.g * 0.08, color.b * 0.08, 0.85)
	popup_box.modulate.a = 1.0
	popup_box.rotation = deg_to_rad(randf_range(-7.0, 7.0))
	popup_box.scale = Vector2.ONE * 1.9
	popup_brush.scale = Vector2(0.0, 1.0)
	if _popup_tw:
		_popup_tw.kill()
	_popup_tw = popup_box.create_tween()
	_popup_tw.set_parallel(true)
	_popup_tw.tween_property(popup_box, "scale", Vector2.ONE, 0.09).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_popup_tw.tween_property(popup_brush, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	_popup_tw.chain().tween_interval(0.5)
	_popup_tw.chain().tween_property(popup_box, "modulate:a", 0.0, 0.3)


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

	crosshair.visible = mouse_captured
	if mouse_captured:
		hint_label.text = "Tab : liste des coups  |  F1 : debug  |  F6 : recharger les données  |  F7 : filtre rétro  |  Échap : libérer la souris"
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
