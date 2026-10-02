class_name SettingsStore
extends RefCounted
## Player settings saved between launches (not game rules): a ConfigFile at path.
## The Settings autoload holds one for user://settings.cfg; tests point it at a temp file.

const SECTION := "ui"
const SOUND_SECTION := "sound"
## The [sound] keys' defaults (184): volumes in percent, and whether interface sounds are on.
const SOUND_DEFAULTS := {"master": 80, "game": 80, "interface": 70, "interface_sounds": true}

var path: String
var reduce_motion := false
var day_mode := false  # the Paper palette (183)
var civilization := ""  # the civilization id last chosen on the start screen (064); "" for none yet
var master: int = SOUND_DEFAULTS.master  # bus volumes in percent, 0–100 (184)
var game: int = SOUND_DEFAULTS.game
var interface: int = SOUND_DEFAULTS.interface
var interface_sounds: bool = SOUND_DEFAULTS.interface_sounds


func _init(p_path := "user://settings.cfg") -> void:
	path = p_path


## Reads the file. A missing file keeps the defaults. Returns warnings (a bad file or value falls
## back to the default and says so, naming the file and key).
func load() -> Array[String]:
	var warnings: Array[String] = []
	reduce_motion = false
	day_mode = false
	civilization = ""
	for key in SOUND_DEFAULTS:
		set(key, SOUND_DEFAULTS[key])
	if not FileAccess.file_exists(path):
		return warnings
	var file := ConfigFile.new()
	# ConfigFile logs its own engine error on bad syntax; ours below says what happens instead.
	var printing := Engine.print_error_messages
	Engine.print_error_messages = false
	var err := file.parse(FileAccess.get_file_as_string(path))
	Engine.print_error_messages = printing
	if err != OK:
		warnings.append("settings file '%s': can't be read (%s); using defaults" % [path, error_string(err)])
		return warnings
	var value: Variant = file.get_value(SECTION, "reduce_motion", false)
	if value is bool:
		reduce_motion = value
	else:
		warnings.append("settings file '%s': [%s] 'reduce_motion' must be true or false, got %s; using false"
			% [path, SECTION, var_to_str(value)])
	var day: Variant = file.get_value(SECTION, "day_mode", false)
	if day is bool:
		day_mode = day
	else:
		warnings.append("settings file '%s': [%s] 'day_mode' must be true or false, got %s; using false"
			% [path, SECTION, var_to_str(day)])
	var civ: Variant = file.get_value(SECTION, "civilization", "")
	if civ is String:
		civilization = civ
	else:
		warnings.append("settings file '%s': [%s] 'civilization' must be a civilization id, got %s; using none"
			% [path, SECTION, var_to_str(civ)])
	_load_sound(file, warnings)
	return warnings


func _load_sound(file: ConfigFile, warnings: Array[String]) -> void:
	for key in ["master", "game", "interface"]:
		var value: Variant = file.get_value(SOUND_SECTION, key, SOUND_DEFAULTS[key])
		if value is int and value >= 0 and value <= 100:
			set(key, value)
		else:
			warnings.append("settings file '%s': [%s] '%s' must be a whole number from 0 to 100, got %s; using %d"
				% [path, SOUND_SECTION, key, var_to_str(value), SOUND_DEFAULTS[key]])
	var on: Variant = file.get_value(SOUND_SECTION, "interface_sounds", true)
	if on is bool:
		interface_sounds = on
	else:
		warnings.append("settings file '%s': [%s] 'interface_sounds' must be true or false, got %s; using true"
			% [path, SOUND_SECTION, var_to_str(on)])


func save() -> Error:
	var file := ConfigFile.new()
	file.set_value(SECTION, "reduce_motion", reduce_motion)
	file.set_value(SECTION, "day_mode", day_mode)
	file.set_value(SECTION, "civilization", civilization)
	for key in SOUND_DEFAULTS:
		file.set_value(SOUND_SECTION, key, get(key))
	return file.save(path)


## The civilization to preselect from listed: the saved one if it's listed, else the first ("" if listed is empty).
## A saved civilization that's no longer listed adds a warning.
func civilization_in(listed: Array[String], warnings: Array[String]) -> String:
	if listed.has(civilization):
		return civilization
	if civilization != "":
		warnings.append("settings file '%s': civilization '%s' is no longer offered; using %s"
			% [path, civilization, "'%s'" % listed[0] if not listed.is_empty() else "none"])
	return listed[0] if not listed.is_empty() else ""
