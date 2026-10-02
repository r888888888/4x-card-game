extends "res://tests/lib/test_case.gd"
## Sound settings and the audio buses (184): the [sound] section of the settings file, Settings.set_volume and
## set_interface_sounds, the bus layout, and the bus volumes following the settings and the window's focus.

const PATH := "user://test_sound_settings.cfg"


func _fresh_path() -> String:
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(PATH)
	return PATH


func _write(text: String) -> void:
	var f := FileAccess.open(_fresh_path(), FileAccess.WRITE)
	f.store_string(text)
	f.close()


func _bus(bus_name: StringName) -> int:
	return AudioServer.get_bus_index(bus_name)


func _sound_of(store: Object) -> Array:
	return [store.get("master"), store.get("game"), store.get("interface"), store.get("interface_sounds")]


# --- AC1: the [sound] section ---

func test_missing_file_means_the_sound_defaults() -> void:
	var store: Object = SettingsStore.new(_fresh_path())
	var warnings: Array[String] = store.load()
	eq(_sound_of(store), [80, 80, 70, true], "master, game, interface, interface_sounds")
	eq(warnings, [] as Array[String], "warnings")


func test_a_file_without_a_sound_section_means_the_defaults() -> void:
	_write("[ui]\nreduce_motion=true\n")
	var store: Object = SettingsStore.new(PATH)
	store.set("master", 10)
	store.set("interface_sounds", false)
	var warnings: Array[String] = store.load()
	eq(_sound_of(store), [80, 80, 70, true], "master, game, interface, interface_sounds")
	eq(warnings, [] as Array[String], "warnings")


func test_sound_settings_survive_save_and_load() -> void:
	var first: Object = SettingsStore.new(_fresh_path())
	first.set("master", 60)
	first.set("game", 30)
	first.set("interface", 0)
	first.set("interface_sounds", false)
	eq(first.save(), OK, "save")
	var file := ConfigFile.new()
	file.load(PATH)
	eq([file.get_value("sound", "master"), file.get_value("sound", "game"), file.get_value("sound", "interface"),
		file.get_value("sound", "interface_sounds")], [60, 30, 0, false], "the [sound] section")
	var second: Object = SettingsStore.new(PATH)
	var warnings: Array[String] = second.load()
	eq(_sound_of(second), [60, 30, 0, false], "loaded back")
	eq(warnings, [] as Array[String], "warnings")


# --- AC2: bad values ---

func test_an_out_of_range_volume_falls_back_with_a_warning() -> void:
	_write("[sound]\ngame=140\n")
	var store: Object = SettingsStore.new(PATH)
	var warnings: Array[String] = store.load()
	eq(store.get("game"), 80, "game")
	eq(warnings, ["settings file '%s': [sound] 'game' must be a whole number from 0 to 100, got 140; using 80" % PATH]
		as Array[String], "the warning")


func test_a_volume_that_isnt_a_whole_number_falls_back_with_a_warning() -> void:
	_write("[sound]\nmaster=50.5\ninterface=\"loud\"\n")
	var store: Object = SettingsStore.new(PATH)
	var warnings: Array[String] = store.load()
	eq([store.get("master"), store.get("interface")], [80, 70], "master, interface")
	eq(warnings, [
		"settings file '%s': [sound] 'master' must be a whole number from 0 to 100, got 50.5; using 80" % PATH,
		"settings file '%s': [sound] 'interface' must be a whole number from 0 to 100, got \"loud\"; using 70" % PATH,
	] as Array[String], "the warnings")


func test_a_non_bool_interface_sounds_falls_back_with_a_warning() -> void:
	_write("[sound]\ninterface_sounds=\"yes\"\n")
	var store: Object = SettingsStore.new(PATH)
	store.set("interface_sounds", false)
	var warnings: Array[String] = store.load()
	eq(store.get("interface_sounds"), true, "interface_sounds")
	eq(warnings, ["settings file '%s': [sound] 'interface_sounds' must be true or false, got \"yes\"; using true" % PATH]
		as Array[String], "the warning")


# --- AC3: Settings.set_volume and set_interface_sounds ---

func test_set_volume_clamps_saves_and_says_so() -> void:
	await with_temp_settings(func():
		var told := [0]
		var on_changed := func(): told[0] += 1
		Settings.changed.connect(on_changed)
		eq(Settings.call("set_volume", Settings.get("GAME"), 140), true, "a known bus")
		eq(Settings.call("volume", Settings.get("GAME")), 100, "clamped to 100")
		eq(Settings.call("set_volume", Settings.get("MASTER"), -5), true, "a known bus")
		eq(Settings.call("volume", Settings.get("MASTER")), 0, "clamped to 0")
		eq(Settings.call("set_volume", Settings.get("INTERFACE"), 40), true, "a known bus")
		eq(Settings.call("volume", Settings.get("INTERFACE")), 40, "interface")
		Settings.changed.disconnect(on_changed)
		eq(told[0], 3, "changed once per call")
		var saved: Object = SettingsStore.new(PATH)
		saved.load()
		eq(_sound_of(saved), [0, 100, 40, true], "saved"), PATH)


func test_set_volume_on_an_unknown_bus_changes_nothing() -> void:
	await with_temp_settings(func():
		var told := [0]
		var on_changed := func(): told[0] += 1
		Settings.changed.connect(on_changed)
		eq(Settings.call("set_volume", &"Music", 50), false, "not a bus")
		Settings.changed.disconnect(on_changed)
		eq(told[0], 0, "changed not emitted")
		eq(FileAccess.file_exists(PATH), false, "nothing saved")
		eq(Settings.call("volume", Settings.get("GAME")), 80, "game untouched"), PATH)


func test_set_interface_sounds_saves_and_says_so() -> void:
	await with_temp_settings(func():
		var told := [0]
		var on_changed := func(): told[0] += 1
		Settings.changed.connect(on_changed)
		Settings.call("set_interface_sounds", false)
		Settings.changed.disconnect(on_changed)
		eq(told[0], 1, "changed once")
		eq(Settings.get("interface_sounds"), false, "read back")
		var saved: Object = SettingsStore.new(PATH)
		saved.load()
		eq(saved.get("interface_sounds"), false, "saved"), PATH)


# --- AC4: the bus layout ---

func test_game_and_interface_buses_send_to_master() -> void:
	check(_bus(&"Game") > 0, "a Game bus")
	check(_bus(&"Interface") > 0, "an Interface bus")
	eq(AudioServer.get_bus_send(_bus(&"Game")), &"Master", "Game sends to")
	eq(AudioServer.get_bus_send(_bus(&"Interface")), &"Master", "Interface sends to")
	eq([Settings.get("MASTER"), Settings.get("GAME"), Settings.get("INTERFACE")], [&"Master", &"Game", &"Interface"],
		"the bus name constants")


func test_each_bus_ends_in_a_hard_limiter() -> void:
	for pair in [[&"Master", -1.0], [&"Game", -10.0], [&"Interface", -18.0]]:
		var bus := _bus(pair[0])
		var count := AudioServer.get_bus_effect_count(bus) if bus >= 0 else 0
		check(count > 0, "%s has effects" % pair[0])
		if count == 0:
			continue
		var last := AudioServer.get_bus_effect(bus, count - 1)
		check(last is AudioEffectHardLimiter, "%s ends in a hard limiter, got %s" % [pair[0], last])
		if last is AudioEffectHardLimiter:
			check(is_equal_approx(last.ceiling_db, pair[1]), "%s ceiling %s, got %s" % [pair[0], pair[1], last.ceiling_db])


func test_the_interface_bus_filters_before_its_limiter() -> void:
	var bus := _bus(&"Interface")
	check(bus >= 0, "an Interface bus")
	if bus < 0:
		return
	var effects := []
	for i in AudioServer.get_bus_effect_count(bus):
		effects.append(AudioServer.get_bus_effect(bus, i))
	eq(effects.size(), 3, "high-pass, high-shelf, limiter")
	if effects.size() != 3:
		return
	check(effects[0] is AudioEffectHighPassFilter, "first a high-pass filter, got %s" % effects[0])
	check(effects[1] is AudioEffectHighShelfFilter, "then a high-shelf filter, got %s" % effects[1])
	if effects[0] is AudioEffectHighPassFilter:
		check(is_equal_approx(effects[0].cutoff_hz, 150.0), "high-pass at 150 Hz, got %s" % effects[0].cutoff_hz)
	if effects[1] is AudioEffectHighShelfFilter:
		check(is_equal_approx(effects[1].cutoff_hz, 6000.0), "high-shelf at 6 kHz, got %s" % effects[1].cutoff_hz)
		var shelf_db := linear_to_db(effects[1].gain)
		check(absf(shelf_db + 6.0) < 0.05, "high-shelf −6 dB, got %.2f dB" % shelf_db)


# --- AC5: bus volumes follow the settings ---

func test_bus_volumes_follow_the_settings() -> void:
	await with_temp_settings(func():
		Settings.call("set_volume", Settings.get("GAME"), 50)
		Settings.call("set_volume", Settings.get("INTERFACE"), 100)
		Settings.call("set_volume", Settings.get("MASTER"), 80)
		check(absf(AudioServer.get_bus_volume_db(_bus(&"Game")) - (-6.02)) <= 0.01,
			"Game at 50%%: −6.02 dB, got %.3f" % AudioServer.get_bus_volume_db(_bus(&"Game")))
		check(absf(AudioServer.get_bus_volume_db(_bus(&"Interface"))) <= 0.01, "Interface at 100%: 0 dB")
		check(absf(AudioServer.get_bus_volume_db(_bus(&"Master")) - linear_to_db(0.8)) <= 0.01, "Master at 80%")
		eq([AudioServer.is_bus_mute(_bus(&"Master")), AudioServer.is_bus_mute(_bus(&"Game")),
			AudioServer.is_bus_mute(_bus(&"Interface"))], [false, false, false], "none muted"), PATH)


func test_a_changed_store_is_applied_to_the_buses() -> void:
	await with_temp_settings(func():
		Settings.store.set("game", 50)
		Settings.changed.emit()
		check(absf(AudioServer.get_bus_volume_db(_bus(&"Game")) - (-6.02)) <= 0.01,
			"Game at 50%% after changed, got %.3f" % AudioServer.get_bus_volume_db(_bus(&"Game"))), PATH)


func test_a_bus_at_zero_is_muted() -> void:
	await with_temp_settings(func():
		Settings.call("set_volume", Settings.get("GAME"), 0)
		eq(AudioServer.is_bus_mute(_bus(&"Game")), true, "Game muted at 0%")
		Settings.call("set_volume", Settings.get("GAME"), 10)
		eq(AudioServer.is_bus_mute(_bus(&"Game")), false, "Game unmuted at 10%"), PATH)


func test_interface_sounds_off_mutes_only_the_interface_bus() -> void:
	await with_temp_settings(func():
		Settings.call("set_volume", Settings.get("INTERFACE"), 50)
		Settings.call("set_interface_sounds", false)
		eq(AudioServer.is_bus_mute(_bus(&"Interface")), true, "Interface muted")
		eq(AudioServer.is_bus_mute(_bus(&"Game")), false, "Game not muted")
		eq(Settings.call("volume", Settings.get("INTERFACE")), 50, "the saved volume kept")
		Settings.call("set_interface_sounds", true)
		eq(AudioServer.is_bus_mute(_bus(&"Interface")), false, "Interface unmuted")
		check(absf(AudioServer.get_bus_volume_db(_bus(&"Interface")) - (-6.02)) <= 0.01, "back at its saved 50%"), PATH)


# --- AC6: in the background ---

func test_in_the_background_game_and_interface_are_muted() -> void:
	await with_temp_settings(func():
		Settings.call("set_in_background", true)
		var muted := [AudioServer.is_bus_mute(_bus(&"Game")), AudioServer.is_bus_mute(_bus(&"Interface"))]
		Settings.call("set_in_background", false)
		eq(muted, [true, true], "Game and Interface muted in the background")
		eq([AudioServer.is_bus_mute(_bus(&"Game")), AudioServer.is_bus_mute(_bus(&"Interface"))], [false, false],
			"restored in the foreground"), PATH)


func test_back_in_the_foreground_interface_stays_off_when_its_sounds_are_off() -> void:
	await with_temp_settings(func():
		Settings.call("set_interface_sounds", false)
		Settings.call("set_in_background", true)
		Settings.call("set_in_background", false)
		eq(AudioServer.is_bus_mute(_bus(&"Interface")), true, "Interface still muted")
		eq(AudioServer.is_bus_mute(_bus(&"Game")), false, "Game back"), PATH)


func test_losing_and_regaining_focus_goes_to_and_from_the_background() -> void:
	await with_temp_settings(func():
		Settings.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
		var muted := AudioServer.is_bus_mute(_bus(&"Game"))
		Settings.notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
		eq(muted, true, "Game muted when the window lost focus")
		eq(AudioServer.is_bus_mute(_bus(&"Game")), false, "Game back when it regained focus"), PATH)
