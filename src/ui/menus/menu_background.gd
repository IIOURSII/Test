class_name MenuBackground
extends Node3D
## Décor des menus : une map qui tourne lentement (comme le panorama de Minecraft),
## avec deux duellistes face à face. Change de map régulièrement (ou à la demande).

const ORBIT_SPEED := 0.06      ## radians / seconde
const CYCLE_SECONDS := 22.0

var cfg: Dictionary
var camera: Camera3D
var _scene: Node3D
var _view: MapView
var _map: MapData
var _angle: float = 0.0
var _time: float = 0.0
var _cycle_t: float = 0.0
var _auto_cycle: bool = true
var _map_ids: Array = []
var _cycle_index: int = 0
var _fade: ColorRect
var _views: Array = []    ## [[FighterView, FighterState]]
var _empty_moves := MoveSet.new()


func setup(config: Dictionary, map_ids: Array, start_id: String = "") -> void:
	cfg = config
	_map_ids = map_ids
	camera = Camera3D.new()
	camera.fov = 62.0
	camera.current = true
	add_child(camera)
	var layer := CanvasLayer.new()
	layer.layer = -2
	add_child(layer)
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 0)
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_fade)
	if start_id == "" and not _map_ids.is_empty():
		_cycle_index = randi() % _map_ids.size()
		start_id = _map_ids[_cycle_index]
	show_map(start_id, false)


func set_auto_cycle(on: bool) -> void:
	_auto_cycle = on
	_cycle_t = 0.0


func show_map(map_id: String, fade: bool = true) -> void:
	if _map and _map.id == map_id:
		return
	if fade:
		var tw := create_tween()
		tw.tween_property(_fade, "color:a", 1.0, 0.18)
		tw.tween_callback(func() -> void: _build(map_id))
		tw.tween_property(_fade, "color:a", 0.0, 0.3)
	else:
		_build(map_id)


func _build(map_id: String) -> void:
	if _scene:
		_scene.queue_free()
	_scene = Node3D.new()
	add_child(_scene)
	_map = MapData.from_json(map_id, DataLoader.load_json("res://data/maps/%s.json" % map_id))
	_view = ArenaBuilder.build(_scene, _map)
	_views.clear()
	# Deux silhouettes en garde, face à face.
	for i in 2:
		var st := FighterState.new()
		st.pos = _map.spawns[i] * 0.6
		st.yaw = InputFrame.yaw_to_int(_map.spawn_yaw(i))
		st.guard = 1 if i == 0 else -1
		var fv := FighterView.new()
		_scene.add_child(fv)
		var models := ["katana", "tanto", "naginata", "kanabo"]
		fv.setup(cfg, Game.PLAYER_COLORS[i], 1, Game.PLAYER_ACCENTS[i], models[randi() % models.size()])
		fv.view_camera = camera
		_views.append([fv, st])


func _process(delta: float) -> void:
	_time += delta
	_angle += delta * ORBIT_SPEED
	if _map:
		var r := (_map.radius if _map.bounds_type == "circle" else maxf(_map.half.x, _map.half.y)) * 0.85
		r = clampf(r, 9.0, 20.0)
		camera.position = Vector3(cos(_angle) * r, 3.2 + sin(_time * 0.3) * 0.3, sin(_angle) * r)
		camera.look_at(Vector3(0, 1.2, 0), Vector3.UP)
		if _view:
			_view.update_tick(_time * 60.0)
		for v in _views:
			(v[0] as FighterView).update_view(v[1], v[1], 0.0, delta, _empty_moves)
	if _auto_cycle and _map_ids.size() > 1:
		_cycle_t += delta
		if _cycle_t > CYCLE_SECONDS:
			_cycle_t = 0.0
			_cycle_index = (_cycle_index + 1) % _map_ids.size()
			show_map(_map_ids[_cycle_index])
