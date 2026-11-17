class_name DataLoader
extends RefCounted
## Lit les fichiers JSON de données (config, coups des armes).


static func load_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Impossible d'ouvrir %s" % path)
		return {}
	var json := JSON.new()
	var err := json.parse(file.get_as_text())
	if err != OK:
		push_error("Erreur JSON dans %s, ligne %d : %s" % [path, json.get_error_line(), json.get_error_message()])
		return {}
	if typeof(json.data) != TYPE_DICTIONARY:
		push_error("%s doit contenir un objet JSON { ... }" % path)
		return {}
	return json.data
