class_name Settings
extends RefCounted
## Réglages du joueur, sauvegardés dans user://settings.json (filtre, sensibilité, volume, derniers choix).

const PATH := "user://settings.json"
const DEFAULTS := {
	"filter": "estampe",
	"sensitivity": 0.0025,
	"volume": 0.8,
	"weapon": "katana",
	"class": "aucune",
	"map": "colisee",
}

static var data: Dictionary = {}


static func load_settings() -> void:
	data = DEFAULTS.duplicate()
	if FileAccess.file_exists(PATH):
		var f := FileAccess.open(PATH, FileAccess.READ)
		if f:
			var parsed = JSON.parse_string(f.get_as_text())
			if parsed is Dictionary:
				data.merge(parsed, true)
	apply_audio()


static func save() -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data, "  "))


static func get_value(key: String):
	return data.get(key, DEFAULTS.get(key))


static func set_value(key: String, value) -> void:
	data[key] = value
	save()


static func apply_audio() -> void:
	var v := clampf(float(get_value("volume")), 0.0, 1.0)
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(v, 0.0001)))
