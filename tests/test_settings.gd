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


# --- Backlog 064 AC5: the last chosen civilization ---

func test_missing_file_means_no_civilization() -> void:
	var store: Object = SettingsStore.new(_fresh_path())
	store.load()
	eq(store.get("civilization"), "", "civilization")


func test_civilization_survives_save_and_load() -> void:
	var first: Object = SettingsStore.new(_fresh_path())
	first.set("civilization", "nomads")
	first.reduce_motion = true
	eq(first.save(), OK, "save")
	var second: Object = SettingsStore.new(PATH)
	var warnings: Array[String] = second.load()
	eq(second.get("civilization"), "nomads", "civilization after loading")
	eq(second.reduce_motion, true, "reduce_motion kept alongside")
	eq(warnings, [] as Array[String], "warnings")


func test_non_string_civilization_falls_back_to_none_with_warning() -> void:
	_write("[ui]\ncivilization=3\n")
	var store: Object = SettingsStore.new(PATH)
	store.set("civilization", "tribe")
	var warnings: Array[String] = store.load()
	eq(store.get("civilization"), "", "civilization")
	has_msg(warnings, "settings file '%s'" % PATH)
	has_msg(warnings, "'civilization'")


func test_civilization_in_keeps_a_listed_choice() -> void:
	var store: Object = SettingsStore.new(_fresh_path())
	store.set("civilization", "nomads")
	var warnings: Array[String] = []
	eq(store.civilization_in(["tribe", "nomads"] as Array[String], warnings), "nomads", "chosen")
	eq(warnings, [] as Array[String], "warnings")


func test_civilization_in_falls_back_to_the_first_with_warning() -> void:
	var store: Object = SettingsStore.new(_fresh_path())
	store.set("civilization", "vikings")
	var warnings: Array[String] = []
	eq(store.civilization_in(["tribe", "nomads"] as Array[String], warnings), "tribe", "first listed")
	has_msg(warnings, "'vikings'")


func test_civilization_in_with_nothing_saved_picks_the_first_quietly() -> void:
	var store: Object = SettingsStore.new(_fresh_path())
	var warnings: Array[String] = []
	eq(store.civilization_in(["tribe", "nomads"] as Array[String], warnings), "tribe", "first listed")
	eq(warnings, [] as Array[String], "no warning when nothing was saved")
	eq(store.civilization_in([] as Array[String], warnings), "", "no list: none")


func test_settings_set_civilization_saves_it() -> void:
	var original: SettingsStore = Settings.store
	Settings.store = SettingsStore.new(_fresh_path())
	Settings.call("set_civilization", "nomads")
	var saved: Object = SettingsStore.new(PATH)
	saved.load()
	eq(saved.get("civilization"), "nomads", "saved")
	Settings.store = original
