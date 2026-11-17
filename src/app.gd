class_name App
extends Node
## Point d'entrée : gère les écrans (titre, choix d'arme, choix de map, options) et lance les combats.
## Le filtre d'image (PostProcess) et les sons (Sfx) sont créés une seule fois et partagés.

const GRAPHICS_CFG := "res://data/config/graphics.json"
const MAP_ORDER := ["colisee", "western", "japon", "volcan", "banque", "chateau", "training"]

var cfg: Dictionary
var roster: Dictionary
var post: PostProcess
var sfx: Sfx
var background: MenuBackground
var screen: CanvasLayer
var game: Game
var maps: Array = []        ## [MapData]
var _choice := {}


func _ready() -> void:
	Settings.load_settings()
	cfg = DataLoader.load_json("res://data/config/combat.json")
	roster = DataLoader.load_json("res://data/roster.json")
	ControlsSetup.apply(DataLoader.load_json("res://data/config/controls.json"))
	for id in MAP_ORDER:
		var d := DataLoader.load_json("res://data/maps/%s.json" % id)
		if not d.is_empty():
			maps.append(MapData.from_json(id, d))

	post = PostProcess.new()
	add_child(post)
	post.setup(DataLoader.load_json(GRAPHICS_CFG), str(Settings.get_value("filter")))
	sfx = Sfx.new()
	add_child(sfx)
	sfx.setup()
	_choice = {"weapon": Settings.get_value("weapon"), "class": Settings.get_value("class"), "map": Settings.get_value("map")}
	show_main_menu()


# ------------------------------------------------------------ écrans

func _ensure_background() -> void:
	if background == null:
		background = MenuBackground.new()
		add_child(background)
		var ids: Array = []
		for m in maps:
			if not (m as MapData).debug_only:
				ids.append((m as MapData).id)
		background.setup(cfg, ids)


func _set_screen(s: CanvasLayer) -> void:
	if screen:
		screen.queue_free()
	screen = s
	add_child(s)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func show_main_menu() -> void:
	_ensure_background()
	background.set_auto_cycle(true)
	var m := MainMenu.new()
	_set_screen(m)
	m.setup()
	m.action.connect(_on_main_action)


func _on_main_action(id: String) -> void:
	sfx.play("click", -6.0)
	match id:
		"sandbox", "local":
			_choice["mode"] = id
			_show_weapon_select()
		"duel":
			_choice["mode"] = "duel_ai"
			var ds := DifficultySelect.new()
			_set_screen(ds)
			ds.setup(DataLoader.load_json("res://data/ai.json"))
			ds.back.connect(show_main_menu)
			ds.done.connect(func(d: String) -> void:
				sfx.play("click", -6.0)
				_choice["difficulty"] = d
				_show_weapon_select())
		"options":
			var o := OptionsMenu.new()
			add_child(o)
			o.setup(post)
			o.closed.connect(func() -> void: o.queue_free())
		"quit":
			get_tree().quit()


func _show_weapon_select() -> void:
	var w := WeaponSelect.new()
	_set_screen(w)
	w.setup(roster, str(_choice["weapon"]), str(_choice["class"]))
	w.back.connect(show_main_menu)
	w.done.connect(func(wid: String, cid: String) -> void:
		sfx.play("click", -6.0)
		_choice["weapon"] = wid
		_choice["class"] = cid
		Settings.set_value("weapon", wid)
		Settings.set_value("class", cid)
		_show_map_select())


func _show_map_select() -> void:
	background.set_auto_cycle(false)
	var ms := MapSelect.new()
	_set_screen(ms)
	ms.preview.connect(func(id: String) -> void: background.show_map(id))
	ms.setup(maps, str(_choice["map"]))
	ms.back.connect(_show_weapon_select)
	ms.done.connect(func(id: String) -> void:
		sfx.play("shing", -4.0)
		_choice["map"] = id
		Settings.set_value("map", id)
		start_game())


func start_game() -> void:
	if screen:
		screen.queue_free()
		screen = null
	if background:
		background.queue_free()
		background = null
	game = Game.new()
	add_child(game)
	game.setup(post, sfx, {"weapon": _choice["weapon"], "class": _choice["class"], "map": _choice["map"],
			"mode": _choice.get("mode", "sandbox"), "difficulty": _choice.get("difficulty", "normal")})
	game.quit_to_menu.connect(_end_game)


func _end_game() -> void:
	Engine.time_scale = 1.0
	if game:
		game.queue_free()
		game = null
	show_main_menu()

