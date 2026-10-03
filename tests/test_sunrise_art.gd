extends "res://tests/lib/test_case.gd"
## The title screen's art (backlog 214): SunriseArt, a banded sun over one green hill in a 600 × 675 design space,
## rising on the title screen's entrance, easing up for New game and sinking into a sunset for Exit, still once
## settled. Its colours are Palette roles. Time is driven by the art's own clock: use_manual_clock(), advance(s).
## Hooks: main.start_screen.sunrise (sun_height(): the sun centre's height above the horizon, hill_offset(): px the
## hill sits below its place); static SunriseArt.warmth(height), sun_color(w), band_alpha(i, w), hill_color(w),
## slice_scale(size), gap_rects(r).

const ART_PATH := "res://ui/sunrise_art.gd"
const REST := 220.0
const DAY_UP := 70.0
const SUNSET := 190.0


## Palette's colour called name as it reads now (by name: the art's roles are new in 214).
func role(name: String) -> Color:
	var c: Variant = load("res://ui/palette.gd").get(name)
	return c if c is Color else Color.BLACK


func art_script() -> Script:
	return load(ART_PATH) if FileAccess.file_exists(ART_PATH) else null


## Main on the title screen with the art's clock in the test's hands; null (checked) before the art exists.
func open_title() -> Node:
	var main := open_main()
	var art: Object = main.start_screen.get("sunrise")
	check(art != null, "the title screen has its sunrise art")
	if art != null:
		art.use_manual_clock()
	return main


# --- AC1: the drawing ---

func test_the_art_fills_its_rect_from_a_600_by_675_design_like_svg_slice() -> void:
	var art := art_script()
	check(art != null, "%s exists" % ART_PATH)
	if art == null:
		return
	eq(art.get("DESIGN"), Vector2(600, 675), "the design space")
	eq(art.slice_scale(Vector2(960, 1080)), 1.6, "fills: the larger of the two ratios")
	eq(art.slice_scale(Vector2(600, 675)), 1.0, "at its own size")
	eq([art.get("SUN_X"), art.get("SUN_RADIUS"), art.get("HORIZON"), art.get("HILL_WIDTH"), art.get("HILL_CROWN")],
		[300.0, 150.0, 520.0, 720.0, 150.0], "the sun, the horizon and the hill")


func test_the_suns_lower_half_has_five_gaps_each_thicker_than_the_one_above() -> void:
	var art := art_script()
	if art == null:
		check(false, "%s exists" % ART_PATH)
		return
	var gaps: Array = art.gap_rects(150.0)  # [offset below the centre, height] each, top first
	eq(gaps.size(), 5, "five gaps")
	var offsets := [0.15, 0.33, 0.51, 0.69, 0.86]
	for i in gaps.size():
		check(absf(gaps[i][0] - offsets[i] * 150.0) < 0.01, "gap %d at %.2f r" % [i, offsets[i]])
		check(absf(gaps[i][1] - (4.0 + 3.5 * i)) < 0.01, "gap %d is %.1f px" % [i, 4.0 + 3.5 * i])
	var half: Array = art.gap_rects(75.0)
	check(absf(half[4][1] - (4.0 + 14.0) / 2.0) < 0.01, "heights scale with the radius")


# --- AC2: warmth ---

func test_warmth_is_a_smoothstep_from_200_down_to_10() -> void:
	var art := art_script()
	if art == null:
		check(false, "%s exists" % ART_PATH)
		return
	eq(art.warmth(250.0), 0.0, "high: none")
	eq(art.warmth(200.0), 0.0, "200: none")
	eq(art.warmth(105.0), 0.5, "halfway")
	eq(art.warmth(10.0), 1.0, "10: full")
	eq(art.warmth(-50.0), 1.0, "below: full")
	check(art.warmth(150.0) < 0.5 and art.warmth(150.0) > 0.0, "smooth between")


func test_warmth_drives_the_sun_the_sky_bands_and_the_hill() -> void:
	var art := art_script()
	if art == null:
		check(false, "%s exists" % ART_PATH)
		return
	eq(art.sun_color(0.0), role("SUN"), "warmth 0: the plain sun")
	eq(art.hill_color(0.0), role("HILL"), "and the plain hill")
	for i in 4:
		eq(art.band_alpha(i, 0.0), 0.0, "no band %d" % i)
	eq(art.sun_color(1.0), role("SUN").lerp(role("SUN_LOW"), 0.85), "low: toward SUN_LOW by 0.85")
	eq([art.band_alpha(0, 1.0), art.band_alpha(1, 1.0), art.band_alpha(2, 1.0), art.band_alpha(3, 1.0)],
		[0.55, 0.32, 0.22, 0.12], "the bands' base alphas, horizon up")
	eq(art.band_alpha(0, 0.5), 0.275, "scaled by warmth")
	eq(art.hill_color(1.0), role("HILL").lerp(role("HILL_LOW"), 0.6).lerp(Palette.SHADOW, 0.25), "the hill deepens")


# --- AC3: the entrance, then stillness ---

func test_the_sun_rises_and_the_hill_comes_up_then_nothing_moves() -> void:
	await with_reduce_motion(false, func():
		var main := open_title()
		var art: Object = main.start_screen.get("sunrise")
		if art != null:
			eq(art.sun_height(), -170.0, "the sun starts 170 below the horizon")
			eq(art.hill_offset(), 120.0, "the hill 120 px down")
			art.advance(0.15)
			eq(art.hill_offset(), 120.0, "the hill waits 0.15 s")
			art.advance(0.9)
			eq(art.hill_offset(), 0.0, "and is up 0.9 s later")
			check(art.sun_height() < REST, "the sun still rising at 1.05 s: %s" % art.sun_height())
			art.advance(1.6)
			eq(art.sun_height(), REST, "220 above by 2.6 s")
			check(not (art as Node).is_processing(), "settled: no processing")
		close_main(main))


# --- AC4: the keys ---

func test_new_game_brings_on_the_day_and_exit_a_sunset_and_leaving_rests() -> void:
	await with_reduce_motion(false, func():
		var main := open_title()
		var art: Object = main.start_screen.get("sunrise")
		if art != null:
			art.advance(3.0)
			var keys: Object = main.start_screen
			keys.new_game_button.mouse_entered.emit()
			check((art as Node).is_processing(), "moving")
			var highest := -INF
			for i in 40:
				art.advance(0.05)
				highest = maxf(highest, art.sun_height())
			check(absf(art.sun_height() - (REST + DAY_UP)) < 0.5, "up 70: %s" % art.sun_height())
			check(highest <= REST + DAY_UP + 0.01, "no overshoot: %s" % highest)
			keys.new_game_button.mouse_exited.emit()
			keys.exit_button.focus_entered.emit()
			art.advance(3.0)
			check(absf(art.sun_height() - (REST - SUNSET)) < 0.5, "Exit: sunk 190: %s" % art.sun_height())
			check(art.warmth(art.sun_height()) > 0.9, "into the low-sun warmth")
			keys.exit_button.focus_exited.emit()
			art.advance(3.0)
			check(absf(art.sun_height() - REST) < 0.5, "back to rest: %s" % art.sun_height())
			check(not (art as Node).is_processing(), "and still")
		close_main(main))


# --- AC5: Reduce motion ---

func test_with_reduce_motion_the_art_rests_and_jumps() -> void:
	await with_reduce_motion(true, func():
		var main := open_title()
		var art: Object = main.start_screen.get("sunrise")
		if art != null:
			eq(art.sun_height(), REST, "at rest from the start")
			eq(art.hill_offset(), 0.0, "the hill in place")
			check(not (art as Node).is_processing(), "nothing runs")
			main.start_screen.new_game_button.focus_entered.emit()
			eq(art.sun_height(), REST + DAY_UP, "New game: at once")
			check(not (art as Node).is_processing(), "still nothing runs")
		close_main(main))


# --- AC6: colours ---

func test_the_arts_colours_are_palette_roles_in_night_and_day() -> void:
	var want := {
		"SUN": ["d9a441", "d9a441"], "SUN_LOW": [Palette.NIGHT["ACCENT"].to_html(false), Palette.DAY["ACCENT"].to_html(false)],
		"SKY_LOW": ["e07a63", "c9705c"], "SKY_HIGH": ["d9a441", "d9a441"],
		"HILL": [Palette.NIGHT["TERRITORY"].to_html(false), Palette.DAY["TERRITORY"].to_html(false)],
		"HILL_LOW": [Palette.NIGHT["TECH"].to_html(false), Palette.DAY["TECH"].to_html(false)],
	}
	for role: String in want:
		check(Palette.NIGHT.has(role) and Palette.DAY.has(role), "%s in both palettes" % role)
		if Palette.NIGHT.has(role) and Palette.DAY.has(role):
			eq([Palette.NIGHT[role].to_html(false), Palette.DAY[role].to_html(false)], want[role], role)


func test_day_mode_redraws_the_art() -> void:
	await with_temp_settings(func():
		var main := open_title()
		var art: Object = main.start_screen.get("sunrise")
		if art != null:
			check((art as Node).is_in_group(UIKit.PAINTED), "repainted when the palette switches")
		close_main(main))
