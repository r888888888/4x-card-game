class_name SettingsStore
extends RefCounted
## Player settings saved between launches (not game rules): a ConfigFile at path.
## The Settings autoload holds one for user://settings.cfg; tests point it at a temp file.

const SECTION := "ui"

var path: String
var reduce_motion := false
var civilization := ""  # the civilization id last chosen on the start screen (064); "" for none yet


func _init(p_path := "user://settings.cfg") -> void:
	path = p_path


## Reads the file. A missing file keeps the defaults. Returns warnings (a bad file or value falls
## back to the default and says so, naming the file and key).
func load() -> Array[String]:
	var warnings: Array[String] = []
	reduce_motion = false
	civilization = ""
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
	var civ: Variant = file.get_value(SECTION, "civilization", "")
	if civ is String:
		civilization = civ
	else:
		warnings.append("settings file '%s': [%s] 'civilization' must be a civilization id, got %s; using none"
			% [path, SECTION, var_to_str(civ)])
	return warnings


func save() -> Error:
	var file := ConfigFile.new()
	file.set_value(SECTION, "reduce_motion", reduce_motion)
	file.set_value(SECTION, "civilization", civilization)
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
