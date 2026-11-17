class_name Hud
extends CanvasLayer
## Interface : viseur, indicateur de garde, panneau debug (F1).

var debug_label: Label
var guard_label: Label
var hint_label: Label
var crosshair: ColorRect


func setup() -> void:
	crosshair = ColorRect.new()
	crosshair.color = Color(1, 1, 1, 0.8)
	crosshair.size = Vector2(4, 4)
	crosshair.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	add_child(crosshair)

	debug_label = _make_label(16)
	debug_label.position = Vector2(16, 16)
	add_child(debug_label)

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
	hint_label.text = "Échap : libérer la souris  |  F1 : debug  |  F6 : recharger les données"
	add_child(hint_label)


func _make_label(font_size: int) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_constant_override("outline_size", 6)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	return l


func update_hud(world: SimWorld, show_debug: bool, mouse_captured: bool) -> void:
	var p := world.fighters[0]
	var switching := p.action == FighterState.Action.GUARD_SWITCH
	guard_label.text = "Garde %s%s" % ["DROITE" if p.guard == FighterState.GUARD_RIGHT else "GAUCHE", "  (changement...)" if switching else ""]

	crosshair.visible = mouse_captured
	if not mouse_captured:
		hint_label.text = "Souris libérée : clique dans la fenêtre pour reprendre  |  F1 : debug  |  F6 : recharger les données"
	else:
		hint_label.text = "Échap : libérer la souris  |  F1 : debug  |  F6 : recharger les données"

	debug_label.visible = show_debug
	if not show_debug:
		return
	var hspeed := Vector2(p.vel.x, p.vel.z).length()
	debug_label.text = "\n".join(PackedStringArray([
		"=== DEBUG (F1) ===",
		"FPS affichage : %d   |   Tick logique : %d (60/s)" % [Engine.get_frames_per_second(), world.tick],
		"Position : (%.2f, %.2f, %.2f)" % [p.pos.x, p.pos.y, p.pos.z],
		"Vitesse au sol : %.2f m/s   |   vertical : %.2f" % [hspeed, p.vel.y],
		"Action : %s (tick %d)" % [p.action_name(), p.action_tick],
		"Au sol : %s   |   Accroupi : %d/%d" % ["oui" if p.on_ground else "non", p.crouch, FighterLogic.CROUCH_TICKS],
		"Dash : recharge %d ticks   |   dash aérien utilisé : %s" % [p.dash_cooldown, "oui" if p.air_dash_used else "non"],
		"Inputs : %s" % _buttons_text(p.prev_buttons),
	]))


func _buttons_text(b: int) -> String:
	var parts: PackedStringArray = []
	for action_name in InputFrame.ACTION_BITS.keys():
		if b & int(InputFrame.ACTION_BITS[action_name]):
			parts.append(action_name)
	return ", ".join(parts) if parts.size() > 0 else "-"
