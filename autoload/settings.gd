extends Node
## Global "Settings" singleton: the player's settings, loaded at start and saved when changed.

signal changed

var store := SettingsStore.new()
var reduce_motion: bool:
	get:
		return store.reduce_motion


func _ready() -> void:
	for w in store.load():
		push_warning(w)


## Turns reduce motion on or off, saves it, and tells the UI.
func set_reduce_motion(on: bool) -> void:
	store.reduce_motion = on
	var err := store.save()
	if err != OK:
		push_warning("settings file '%s': can't be saved (%s)" % [store.path, error_string(err)])
	changed.emit()
