class_name SettingsStore
extends RefCounted
## Player settings saved between launches (not game rules): a ConfigFile at path.
## The Settings autoload holds one for user://settings.cfg; tests point it at a temp file.

var path: String
var reduce_motion := false


func _init(p_path := "user://settings.cfg") -> void:
	path = p_path


## Reads the file. A missing file keeps the defaults. Returns warnings (a bad file or value falls
## back to the default and says so, naming the file and key).
func load() -> Array[String]:
	return []  # TODO 016


func save() -> Error:
	return OK  # TODO 016
