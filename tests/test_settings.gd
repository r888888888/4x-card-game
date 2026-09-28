extends "res://tests/lib/test_case.gd"
## SettingsStore: player settings saved to a ConfigFile (reduce motion).

const PATH := "user://test_settings.cfg"


func _fresh_path() -> String:
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(PATH)
	return PATH


func _write(text: String) -> void:
	var f := FileAccess.open(_fresh_path(), FileAccess.WRITE)
	f.store_string(text)
	f.close()


func test_missing_file_means_reduce_motion_off() -> void:
	var store := SettingsStore.new(_fresh_path())
	var warnings := store.load()
	eq(store.reduce_motion, false, "reduce_motion")
	eq(warnings, [] as Array[String], "warnings")


func test_reduce_motion_survives_save_and_load() -> void:
	var first := SettingsStore.new(_fresh_path())
	first.reduce_motion = true
	eq(first.save(), OK, "first save")
	var second := SettingsStore.new(PATH)
	second.load()
	eq(second.reduce_motion, true, "reduce_motion after saving true")
	second.reduce_motion = false
	eq(second.save(), OK, "second save")
	var third := SettingsStore.new(PATH)
	third.reduce_motion = true  # so the load has to overwrite it
	third.load()
	eq(third.reduce_motion, false, "reduce_motion after saving false")


func test_corrupt_file_falls_back_to_off_with_warning() -> void:
	_write("reduce_motion = [[[ this is not a config file")
	var store := SettingsStore.new(PATH)
	store.reduce_motion = true
	var warnings := store.load()
	eq(store.reduce_motion, false, "reduce_motion")
	has_msg(warnings, "settings file '%s'" % PATH)


func test_non_bool_reduce_motion_falls_back_to_off_with_warning() -> void:
	_write("[ui]\nreduce_motion=\"yes\"\n")
	var store := SettingsStore.new(PATH)
	store.reduce_motion = true
	var warnings := store.load()
	eq(store.reduce_motion, false, "reduce_motion")
	has_msg(warnings, "settings file '%s'" % PATH)
	has_msg(warnings, "'reduce_motion'")
