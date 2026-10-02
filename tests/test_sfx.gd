extends "res://tests/lib/test_case.gd"
## The sound player (186): Sfx's tokens and levels from the style guide's §14.1, their files under assets/sounds/, the
## streams that play them, play() and its rules (tick rate, notification spacing, voices, Level 3 precedence), and the
## contact timing (Anim.contact, Sfx.lead, Sfx.at_contact). The clock is set by hand (Sfx.set_clock).

const GUIDE := "res://docs/design/mcm-style-guide.md"


## A new Sfx in the tree, its clock at 0.
func new_sfx() -> Node:
	var sfx: Node = Sfx.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(sfx)
	sfx.set_clock(0.0)
	return sfx


func free_sfx(sfx: Node) -> void:
	sfx.get_parent().remove_child(sfx)
	sfx.free()


## The guide's §14.1 tokens by level: {1: [...], 2: [...], 3: [...]}; ui.notification as its three patterns.
func guide_tokens() -> Dictionary:
	var text := FileAccess.get_file_as_string(GUIDE)
	var section := text.substr(text.find("### 14.1 Sound tokens"))
	section = section.substr(0, section.find("\n## 15."))
	var by_level := {1: [], 2: [], 3: []}
	var level := 0
	var row := RegEx.create_from_string("^\\| `(ui\\.[a-z.]+)` \\|")
	for line in section.split("\n"):
		for n in [1, 2, 3]:
			if line.begins_with("**Level %d" % n):
				level = n
		var m := row.search(line)
		if m != null and level > 0:
			var token := m.get_string(1)
			if token == "ui.notification":
				by_level[level].append_array(["ui.notification.info", "ui.notification.caution", "ui.notification.urgent"])
			else:
				by_level[level].append(token)
	return by_level


## Sfx's constant for token: "ui.button.press" is BUTTON_PRESS, "ui.milestone" MILESTONE.
func constant_name(token: String) -> String:
	return token.trim_prefix("ui.").replace(".", "_").to_upper()


func record_of(sfx: Node, token: StringName) -> Dictionary:
	for r: Dictionary in sfx.played():
		if r.token == token:
			return r
	return {}


# --- AC1: tokens and levels ---

func test_every_guide_token_is_a_constant_with_its_level() -> void:
	var by_level := guide_tokens()
	check(by_level[1].size() >= 12 and by_level[2].size() >= 18 and by_level[3].size() >= 8,
		"read the guide's tables: %s" % [by_level])
	var constants := (Sfx as Script).get_script_constant_map()
	for level: int in by_level:
		for token: String in by_level[level]:
			eq(constants.get(constant_name(token)), StringName(token), "Sfx.%s" % constant_name(token))
			eq(Sfx.level(StringName(token)), level, "level of %s" % token)
	eq(Sfx.TOKENS.size(), by_level[1].size() + by_level[2].size() + by_level[3].size(), "Sfx.TOKENS: every token, no more")


func test_levels_and_buses() -> void:
	eq([Sfx.level(Sfx.BUTTON_PRESS), Sfx.level(Sfx.COUNTER_TICK), Sfx.level(Sfx.PANEL_OPEN), Sfx.level(Sfx.ENDTURN_COMMIT),
		Sfx.level(Sfx.MILESTONE_ERA)], [1, 1, 2, 2, 3], "levels")
	eq([Sfx.bus(Sfx.BUTTON_PRESS), Sfx.bus(Sfx.NOTIFICATION_URGENT), Sfx.bus(Sfx.MILESTONE_VICTORY)],
		[Settings.INTERFACE, Settings.INTERFACE, Settings.GAME], "buses")


# --- AC2: files and streams ---

func test_every_token_has_its_files() -> void:
	for token: StringName in Sfx.TOKENS:
		var files: Array = Sfx.files(token)
		eq(files.size(), {1: 4, 2: 2, 3: 1}[Sfx.level(token)], "%s's variants" % token)
		for path: String in files:
			var stem := String(token).replace(".", "_")
			check(path.begins_with("res://assets/sounds/%s/%s" % ["events" if Sfx.level(token) == 3 else "ui", stem]),
				"%s named for its token" % path)
			var stream: Variant = load(path) if ResourceLoader.exists(path) else null
			check(stream is AudioStreamWAV, "%s loads as an AudioStreamWAV" % path)
			if stream is AudioStreamWAV:
				eq([stream.format, stream.mix_rate, stream.stereo, stream.loop_mode],
					[AudioStreamWAV.FORMAT_16_BITS, 48000, false, AudioStreamWAV.LOOP_DISABLED],
					"%s: 16-bit, 48 kHz, mono, uncompressed, no loop" % path)
	eq(Sfx.files(Sfx.BUTTON_PRESS)[0], "res://assets/sounds/ui/ui_button_press_a.wav", "a Level 1 file")
	eq(Sfx.files(Sfx.MILESTONE_ERA), ["res://assets/sounds/events/ui_milestone_era.wav"], "a Level 3 file")


func test_level_1_plays_through_a_randomizer() -> void:
	var stream: Variant = Sfx.stream(Sfx.BUTTON_PRESS)
	check(stream is AudioStreamRandomizer, "a randomizer: %s" % stream)
	if stream is AudioStreamRandomizer:
		eq(stream.playback_mode, AudioStreamRandomizer.PLAYBACK_RANDOM_NO_REPEATS, "no immediate repeat")
		check(is_equal_approx(stream.random_pitch, 1.015), "±25 cents: %s" % stream.random_pitch)
		check(is_equal_approx(stream.random_volume_offset_db, 1.0), "±1 dB: %s" % stream.random_volume_offset_db)
		eq(stream.streams_count, 4, "its four variants")
		eq(stream.get_stream(0).resource_path, Sfx.files(Sfx.BUTTON_PRESS)[0], "variant a")


func test_levels_2_and_3_play_their_files_unpitched() -> void:
	var two: Variant = Sfx.stream(Sfx.PANEL_OPEN)
	check(two is AudioStreamRandomizer, "Level 2: its two files: %s" % two)
	if two is AudioStreamRandomizer:
		eq(two.streams_count, 2, "two variants")
		check(is_equal_approx(two.random_pitch, 1.0), "no pitch change: %s" % two.random_pitch)
		check(is_equal_approx(two.random_volume_offset_db, 0.0), "no volume jitter: %s" % two.random_volume_offset_db)
	var three: Variant = Sfx.stream(Sfx.MILESTONE_ERA)
	check(three is AudioStreamWAV and three.resource_path == Sfx.files(Sfx.MILESTONE_ERA)[0], "Level 3: its file")


# --- AC3: play() ---

func test_play_records_the_token_its_bus_and_when() -> void:
	var sfx := new_sfx()
	sfx.set_clock(10.0)
	eq(sfx.clock(), 10.0, "the clock")
	eq(sfx.play(Sfx.BUTTON_PRESS, 0.05), true, "plays")
	eq(sfx.play(Sfx.MILESTONE_CITY, 5.0), true, "plays")  # after the press: not over it (191's giving way)
	var press := record_of(sfx, Sfx.BUTTON_PRESS)
	eq([press.get("bus"), snappedf(press.get("at", 0.0), 0.0001)], [Settings.INTERFACE, 10.05], "the press")
	var city := record_of(sfx, Sfx.MILESTONE_CITY)
	eq([city.get("bus"), city.get("at")], [Settings.GAME, 15.0], "the city")
	free_sfx(sfx)


func test_an_unknown_token_plays_nothing_and_says_so() -> void:
	var sfx := new_sfx()
	expect_error("ui.no.such.sound")
	eq(sfx.play(&"ui.no.such.sound"), false, "refused")
	eq(sfx.played(), [], "nothing recorded")
	free_sfx(sfx)


# --- AC4: rate rules ---

func test_a_tick_within_35_ms_of_the_last_is_dropped() -> void:
	var sfx := new_sfx()
	eq(sfx.play(Sfx.COUNTER_TICK), true, "the first tick")
	eq(sfx.play(Sfx.COUNTER_TICK, 0.02), false, "20 ms later: dropped")
	eq(sfx.play(Sfx.COUNTER_TICK, 0.04), true, "40 ms later: plays")
	eq(sfx.played().size(), 2, "two ticks recorded")
	free_sfx(sfx)


func test_a_notification_waits_400_ms_after_the_last() -> void:
	var sfx := new_sfx()
	eq(sfx.play(Sfx.NOTIFICATION_INFO), true, "the first")
	eq(sfx.play(Sfx.NOTIFICATION_CAUTION, 0.1), true, "the second still plays")
	eq(sfx.play(Sfx.NOTIFICATION_URGENT), true, "the third still plays")
	var ats: Array = sfx.played().map(func(r): return snappedf(r.at, 0.0001))
	eq(ats, [0.0, 0.4, 0.8], "each 0.4 s after the one before")
	free_sfx(sfx)


func test_six_interface_voices_refuse_a_level_1_and_a_level_2_steals_the_oldest() -> void:
	var sfx := new_sfx()
	for token in [Sfx.BUTTON_PRESS, Sfx.BUTTON_RELEASE, Sfx.SELECTION, Sfx.CARD_LIFT, Sfx.CARD_PLACE, Sfx.FLAP]:
		eq(sfx.play(token), true, "%s plays" % token)
	eq(sfx.play(Sfx.TOGGLE_ON), false, "a seventh Level 1 is refused")
	eq(sfx.play(Sfx.PANEL_OPEN), true, "a Level 2 plays")
	var playing: Array = sfx.playing(Settings.INTERFACE)
	check(not playing.has(Sfx.BUTTON_PRESS), "the oldest Level 1 stopped: %s" % [playing])
	check(playing.has(Sfx.PANEL_OPEN) and playing.has(Sfx.BUTTON_RELEASE), "the rest play on: %s" % [playing])
	eq(playing.size(), 6, "six voices")
	free_sfx(sfx)


# --- AC5: Level 3 precedence ---

func test_while_a_level_3_plays_system_sounds_are_dropped_and_input_is_quieter() -> void:
	var sfx := new_sfx()
	eq(sfx.play(Sfx.MILESTONE_ERA, 0.5), true, "the era plays from 0.5 s")
	eq(sfx.play(Sfx.COUNTER_TICK), true, "a tick before it starts plays")
	eq(sfx.play(Sfx.COUNTER_TICK, 0.6), false, "a system tick during it is dropped")
	eq(sfx.play(Sfx.NOTIFICATION_INFO, 0.6), false, "a system notification during it is dropped")
	eq(sfx.play(Sfx.BUTTON_PRESS, 0.6, true), true, "a press during it plays")
	eq(record_of(sfx, Sfx.BUTTON_PRESS).get("db"), -6.0, "6 dB quieter")
	var era_end: float = 0.5 + Sfx.length(Sfx.MILESTONE_ERA)
	sfx.set_clock(era_end + 0.01)
	eq(sfx.play(Sfx.SELECTION), true, "after it ends, system sounds play")
	eq(record_of(sfx, Sfx.SELECTION).get("db"), 0.0, "at their own level")
	free_sfx(sfx)


# --- AC6: contact timing ---

func test_contact_is_when_a_motion_reaches_90_percent() -> void:
	for c in [[0.07, Anim.SNAP, 0.038], [0.12, Anim.MACHINED, 0.065], [0.26, Anim.LATCH, 0.164], [0.2, Anim.RELEASE, 0.187]]:
		var got: float = Anim.contact(c[0], c[1])
		check(absf(got - c[2]) <= 0.002, "contact(%s, %s) %.4f, want %s" % [c[0], c[1], got, c[2]])


func test_two_stage_sounds_lead_their_contact() -> void:
	eq([Sfx.lead(Sfx.BUTTON_PRESS), Sfx.lead(Sfx.ENDTURN_PRESS), Sfx.lead(Sfx.BUTTON_RELEASE), Sfx.lead(Sfx.TOGGLE_OFF),
		Sfx.lead(Sfx.TOGGLE_ON), Sfx.lead(Sfx.SELECTION)], [0.014, 0.014, 0.018, 0.018, 0.0, 0.0], "leads")


func test_at_contact_plays_at_the_contact_less_the_lead() -> void:
	await with_reduce_motion(false, func():
		var sfx := new_sfx()
		eq(sfx.at_contact(Sfx.BUTTON_PRESS, 0.07, Anim.SNAP), true, "plays")
		eq(sfx.at_contact(Sfx.SELECTION, 0.12, Anim.MACHINED), true, "plays")
		eq(sfx.at_contact(Sfx.TOGGLE_OFF, 0.01, Anim.SNAP), true, "plays")
		var ats: Array = sfx.played().map(func(r): return snappedf(r.at, 0.001))
		eq(ats, [0.024, 0.065, 0.0], "contact − lead, never below 0")
		free_sfx(sfx))


func test_at_contact_with_reduce_motion_plays_at_once() -> void:
	await with_reduce_motion(true, func():
		var sfx := new_sfx()
		sfx.at_contact(Sfx.BUTTON_RELEASE, 0.12, Anim.MACHINED)
		eq(sfx.played().map(func(r): return r.at), [0.0], "at the change")
		free_sfx(sfx))
