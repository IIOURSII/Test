class_name OptionsMenu
extends CanvasLayer
## Options : style du filtre, sensibilité de la souris, volume. Sauvegardées automatiquement.

signal closed

var post: PostProcess
var _filter_label: Label
var _filter_desc: Label
var _sens_label: Label
var _vol_label: Label


func setup(post_process: PostProcess) -> void:
	post = post_process
	layer = 20
	add_child(UiStyle.full_shade(0.75))
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	var head := HBoxContainer.new()
	head.position = Vector2(80, 50)
	head.add_theme_constant_override("separation", 20)
	root.add_child(head)
	head.add_child(UiStyle.shield("設", 72, Color(0.1,0.12,0.2), Color(0.85,0.82,0.75)))
	head.add_child(UiStyle.label("Optionen · Options", 56, UiStyle.PAPER, UiStyle.gothic()))

	var v := VBoxContainer.new()
	v.position = Vector2(110, 180)
	v.add_theme_constant_override("separation", 26)
	root.add_child(v)

	# Filtre
	v.add_child(UiStyle.label(UiStyle.spaced("STYLE DE L'IMAGE"), 14, UiStyle.GOLD))
	var fr := HBoxContainer.new()
	fr.add_theme_constant_override("separation", 18)
	var prev_b := _small_button("‹")
	var next_b := _small_button("›")
	_filter_label = UiStyle.label("", 30, UiStyle.PAPER)
	_filter_label.custom_minimum_size = Vector2(260, 0)
	_filter_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fr.add_child(prev_b)
	fr.add_child(_filter_label)
	fr.add_child(next_b)
	v.add_child(fr)
	_filter_desc = UiStyle.label("", 15, UiStyle.MUTED)
	v.add_child(_filter_desc)
	prev_b.pressed.connect(func() -> void: _cycle_filter(-1))
	next_b.pressed.connect(func() -> void: _cycle_filter(1))

	# Sensibilité
	_sens_label = UiStyle.label("", 14, UiStyle.GOLD)
	v.add_child(_sens_label)
	var sens := HSlider.new()
	sens.min_value = 0.0005
	sens.max_value = 0.008
	sens.step = 0.0001
	sens.value = float(Settings.get_value("sensitivity"))
	sens.custom_minimum_size = Vector2(500, 24)
	sens.value_changed.connect(func(val: float) -> void:
		Settings.set_value("sensitivity", val)
		_update_labels())
	v.add_child(sens)

	# Volume
	_vol_label = UiStyle.label("", 14, UiStyle.GOLD)
	v.add_child(_vol_label)
	var vol := HSlider.new()
	vol.min_value = 0.0
	vol.max_value = 1.0
	vol.step = 0.01
	vol.value = float(Settings.get_value("volume"))
	vol.custom_minimum_size = Vector2(500, 24)
	vol.value_changed.connect(func(val: float) -> void:
		Settings.set_value("volume", val)
		Settings.apply_audio()
		_update_labels())
	v.add_child(vol)

	var bb := UiStyle.menu_button("Retour", "", false, 26)
	bb.pressed.connect(func() -> void: closed.emit())
	v.add_child(bb)
	_update_labels()


func _small_button(t: String) -> Button:
	var b := Button.new()
	b.text = t
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 40)
	b.add_theme_color_override("font_color", UiStyle.CRIMSON)
	b.add_theme_color_override("font_hover_color", UiStyle.PAPER)
	return b


func _cycle_filter(dir: int) -> void:
	var names := post.preset_names()
	if names.is_empty():
		return
	var i := names.find(post.current_preset)
	i = posmod(i + dir, names.size())
	var pname: String = names[i]
	post.apply(post._gfx, pname)
	Settings.set_value("filter", pname)
	_update_labels()


func _update_labels() -> void:
	_filter_label.text = post.preset_label(post.current_preset).to_upper()
	_filter_desc.text = post.preset_desc(post.current_preset)
	_sens_label.text = UiStyle.spaced("SENSIBILITÉ SOURIS") + "    %.4f" % float(Settings.get_value("sensitivity"))
	_vol_label.text = UiStyle.spaced("VOLUME") + "    %d %%" % roundi(float(Settings.get_value("volume")) * 100.0)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		closed.emit()
