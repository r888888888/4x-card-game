extends Node
## Global "Settings" singleton: the player's settings, loaded at start and saved when changed. The palette follows
## the Day mode setting (183): it switches before anything else hears changed. The audio buses follow the sound
## settings and the window's focus (184).

signal changed

## The audio buses (default_bus_layout.tres); nothing else writes their names.
const MASTER := &"Master"
const GAME := &"Game"
const INTERFACE := &"Interface"
## Each bus and the store field holding its volume in percent.
const _VOLUME_KEYS := {MASTER: "master", GAME: "game", INTERFACE: "interface"}

var store := SettingsStore.new()
var reduce_motion: bool:
	get:
		return store.reduce_motion
var interface_sounds: bool:
	get:
		return store.interface_sounds
var _in_background := false


func _ready() -> void:
	for w in store.load():
		push_warning(w)
	changed.connect(_use_palette)  # first, so every other listener reads the new colours
	changed.connect(_apply_volumes)
	_use_palette()
	_apply_volumes()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		set_in_background(true)
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		set_in_background(false)


## Turns Day mode (the Paper palette, 183) on or off, saves it, and tells the UI.
func set_day_mode(on: bool) -> void:
	store.day_mode = on
	_save()
	changed.emit()


func _use_palette() -> void:
	if Palette.day != store.day_mode:
		Palette.use(store.day_mode)


## Turns reduce motion on or off, saves it, and tells the UI.
func set_reduce_motion(on: bool) -> void:
	store.reduce_motion = on
	_save()
	changed.emit()


## Sets bus's volume to percent (clamped to 0–100), saves it and tells the UI. Returns false, changing nothing, for
## a bus that isn't MASTER, GAME or INTERFACE.
func set_volume(bus: StringName, percent: int) -> bool:
	if not _VOLUME_KEYS.has(bus):
		return false
	store.set(_VOLUME_KEYS[bus], clampi(percent, 0, 100))
	_save()
	changed.emit()
	return true


## bus's volume in percent (MASTER, GAME or INTERFACE).
func volume(bus: StringName) -> int:
	return store.get(_VOLUME_KEYS[bus])


## Turns interface sounds on or off (the Interface bus mutes; its volume is kept), saves it, and tells the UI.
func set_interface_sounds(on: bool) -> void:
	store.interface_sounds = on
	_save()
	changed.emit()


## Mutes the Game and Interface buses while the window is in the background; back in front, they follow the settings.
func set_in_background(on: bool) -> void:
	_in_background = on
	_apply_volumes()


func _apply_volumes() -> void:
	for bus: StringName in _VOLUME_KEYS:
		var index := AudioServer.get_bus_index(bus)
		if index < 0:
			continue
		var percent := volume(bus)
		AudioServer.set_bus_volume_db(index, linear_to_db(percent / 100.0))
		var off := percent == 0 or (bus != MASTER and _in_background) or (bus == INTERFACE and not interface_sounds)
		AudioServer.set_bus_mute(index, off)


## Remembers civ_id as the last chosen civilization and saves it (064).
func set_civilization(civ_id: String) -> void:
	store.civilization = civ_id
	_save()


func _save() -> void:
	var err := store.save()
	if err != OK:
		push_warning("settings file '%s': can't be saved (%s)" % [store.path, error_string(err)])
