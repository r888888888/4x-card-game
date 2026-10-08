extends "res://tests/lib/test_case.gd"
## Wood and paper surfaces (341) in the real main scene: walnut grain under the board, the Rail (lined up with the
## board's) and the Strip; paper on every Sheet (Modal) and DarkPanel (UIKit.overlay), on soft shadows; keys stay flat;
## Day mode switches all of it at once; text and hues keep their contrast on each surface's mean colour. A card's own
## paper and shadows are in test_card_faces.gd. Means come from tests/lib/surface_looks.gd.

const Looks := preload("res://tests/lib/surface_looks.gd")
## The criteria's sheet shadow (AC5): SHADOW at (0, 16), size 32, alpha 0.55 Night / 0.35 Day.
const SHEET_OFFSET := Vector2(0, 16)
const SHEET_SIZE := 32
const SHEET_ALPHA := {false: 0.55, true: 0.35}


func set_day(on: bool) -> void:
	Settings.call("set_day_mode", on)


## The strip the top bar sits on.
func strip(main: Node) -> Control:
	var node: Node = MainProbe.counter(main, GameEngine.FOOD)
	while node != null and not node is TopBar:
		node = node.get_parent()
	return node.get_parent() as Control


func panel_box(c: Control) -> StyleBox:
	return c.get_theme_stylebox("panel")


## Checks box shows the expected surface (Looks.mismatch).
func check_surface(box: StyleBox, expected: Color, what: String) -> void:
	var why := Looks.mismatch(box, expected)
	check(why == "", "%s: %s" % [what, why])


## Checks a sheet's or overlay panel's frame: border colour border, 2 px all round, the mode's soft sheet shadow.
func check_sheet_frame(box: StyleBox, border: Color, what: String) -> void:
	var frame := Looks.frame_of(box)
	check(frame != null, "%s: a frame" % what)
	if frame == null:
		return
	eq(frame.border_color, border, "%s: its rule" % what)
	eq([frame.border_width_left, frame.border_width_top, frame.border_width_right, frame.border_width_bottom], [2, 2, 2, 2],
		"%s: 2 px" % what)
	eq(Color(frame.shadow_color, 1.0), Color(Palette.SHADOW, 1.0), "%s: SHADOW" % what)
	check(is_equal_approx(frame.shadow_color.a, SHEET_ALPHA[Palette.day]),
		"%s: shadow alpha %.2f, expected %.2f" % [what, frame.shadow_color.a, SHEET_ALPHA[Palette.day]])
	eq(frame.shadow_offset, SHEET_OFFSET, "%s: straight down 16" % what)
	eq(frame.shadow_size, SHEET_SIZE, "%s: size 32" % what)
	check(frame.anti_aliasing, "%s: soft (anti-aliased)" % what)


# --- AC1: the board and the Rail ---

func test_the_board_and_the_rail_show_grain_under_the_background() -> void:
	await with_temp_settings(func():
		for day in [false, true]:
			set_day(day)
			var main: Node = await mid_game()
			var mode := "day" if day else "night"
			check_surface(MainProbe.background_box(main), Looks.grain(Palette.BACKGROUND), "%s: the board" % mode)
			var rail := panel_box(main.sidebar)
			check_surface(rail, Looks.grain(Palette.BACKGROUND), "%s: the Rail" % mode)
			var frame := Looks.frame_of(rail)
			check(frame != null, "%s: the Rail's frame" % mode)
			if frame != null:
				eq(frame.border_color, Palette.HAIRLINE, "%s: the Rail's hairline" % mode)
				eq([frame.border_width_left, frame.border_width_top, frame.border_width_right, frame.border_width_bottom],
					[1, 0, 0, 0], "%s: 1 px on its left only" % mode)
			close_main(main)
		set_day(false))


func test_the_rails_grain_lines_up_with_the_boards() -> void:
	var main: Node = await mid_game()
	var board: StyleBox = MainProbe.background_box(main)
	var rail := panel_box(main.sidebar)
	var at: Vector2 = (main.sidebar as Control).global_position
	check(at.x > 0.0 and at.y > 0.0, "precondition: the Rail isn't at the screen's origin")
	eq(Looks.texture_of(rail), Looks.texture_of(board), "the same grain")
	for p in [Vector2.ZERO, Vector2(10, 20), Vector2(37, 500), Vector2(200, 900)]:
		eq(rail.call("source_at", p), board.call("source_at", p + at),
			"the Rail at %s shows the board's grain at %s" % [p, p + at])
	close_main(main)


# --- AC2: the Strip ---

func test_the_strip_shows_grain_under_raised_and_keeps_its_rule() -> void:
	await with_temp_settings(func():
		for day in [false, true]:
			set_day(day)
			var main: Node = await mid_game()
			var mode := "day" if day else "night"
			var box := panel_box(strip(main))
			check_surface(box, Looks.grain(Palette.RAISED), "%s: the Strip" % mode)
			var frame := Looks.frame_of(box)
			check(frame != null, "%s: the Strip's frame" % mode)
			if frame != null:
				eq(frame.border_color, Palette.TEXT, "%s: a TEXT rule" % mode)
				eq([frame.border_width_left, frame.border_width_top, frame.border_width_right, frame.border_width_bottom],
					[0, 0, 0, 3], "%s: 3 px along its foot" % mode)
			close_main(main)
		set_day(false))


func test_no_key_on_the_board_is_textured() -> void:
	var main: Node = await mid_game()
	var buttons := main.find_children("*", "Button", true, false)
	check(buttons.size() > 5, "precondition: the board has keys")
	for b: Button in buttons:
		for state in ["normal", "hover", "pressed", "disabled"]:
			var box := b.get_theme_stylebox(state)
			check(Looks.texture_of(box) == null, "%s's %s look has no texture" % [b.name, state])
	var key := main.sidebar.end_turn.get_theme_stylebox("normal") as StyleBoxFlat
	check(key != null and key.shadow_size == 1 and not key.anti_aliasing, "End turn keeps its hard plinth")
	var top := strip(main).find_children("*", "Button", true, false)[0] as Button
	var flat := top.get_theme_stylebox("normal") as StyleBoxFlat
	check(flat != null and flat.bg_color == Palette.CONTROL and flat.shadow_offset == GameTheme.PLINTH,
		"the Strip's keys stay CONTROL on their plinth")
	close_main(main)


# --- AC4 and AC5: modals on paper, on soft shadows ---

func test_a_modal_sheet_is_paper_on_a_soft_shadow() -> void:
	await with_temp_settings(func():
		for day in [false, true]:
			set_day(day)
			var main: Node = await mid_game()
			var mode := "day" if day else "night"
			main.identity_modal.open()
			await wait_frames()
			var box := panel_box(main.identity_modal.panel)
			check_surface(box, Looks.paper(), "%s: the sheet" % mode)
			check_sheet_frame(box, Palette.TEXT, "%s: the sheet" % mode)
			close_main(main)
		set_day(false))


func test_an_overlay_panel_is_paper_in_its_role_colour_on_a_soft_shadow() -> void:
	await with_temp_settings(func():
		for day in [false, true]:
			set_day(day)
			var main: Node = await mid_game()
			var mode := "day" if day else "night"
			for role in [&"EDGE", &"TERRITORY"]:
				var overlay := UIKit.overlay(main, role)
				var box := panel_box(overlay.get_meta("panel"))
				check_surface(box, Looks.paper(), "%s: a %s overlay" % [mode, role])
				check_sheet_frame(box, Palette.color(role), "%s: a %s overlay" % [mode, role])
			close_main(main)
		set_day(false))


# --- AC6: Day mode switches every surface at once ---

## Checks every surface on main reads the current mode: the board, the Rail, the Strip, each card view and the open
## identity modal.
func check_surfaces(main: Node, mode: String) -> void:
	check_surface(MainProbe.background_box(main), Looks.grain(Palette.BACKGROUND), "%s: the board" % mode)
	check_surface(panel_box(main.sidebar), Looks.grain(Palette.BACKGROUND), "%s: the Rail" % mode)
	check_surface(panel_box(strip(main)), Looks.grain(Palette.RAISED), "%s: the Strip" % mode)
	for uid in main.views:
		var view: CardView = main.views[uid]
		if view.board_kind == CardView.BOARD_FRONTIER:
			continue
		var box := panel_box(view)
		var paper := Looks.mismatch(box, Looks.paper())
		var dimmed := Looks.mismatch(box, Looks.dimmed_paper())
		check(paper == "" or dimmed == "", "%s: %s on paper: %s" % [mode, view.card_id, paper])
	var sheet := panel_box(main.identity_modal.panel)
	check_surface(sheet, Looks.paper(), "%s: the open modal" % mode)
	check_sheet_frame(sheet, Palette.TEXT, "%s: the open modal" % mode)


func test_day_mode_switches_every_surface_with_a_modal_open() -> void:
	await with_temp_settings(func():
		var main: Node = await mid_game()
		main.identity_modal.open()
		await wait_frames()
		var depth: int = main.modals.depth()
		var e := Game.engine
		var before := [e.turn, card_ids(e.zone("hand")), e.resources.duplicate()]
		set_day(true)
		await wait_frames()
		check(Palette.day, "precondition: Day mode")
		check_surfaces(main, "day")
		set_day(false)
		await wait_frames()
		check_surfaces(main, "night")
		eq(main.modals.depth(), depth, "the modal stays open")
		eq([e.turn, card_ids(e.zone("hand")), e.resources.duplicate()], before, "the game is untouched")
		close_main(main))


# --- AC7: contrast on each surface as drawn ---

func test_text_and_hues_keep_their_contrast_on_each_surface() -> void:
	await with_temp_settings(func():
		for day in [false, true]:
			set_day(day)
			var main: Node = await mid_game()
			main.identity_modal.open()
			await wait_frames()
			var mode := "day" if day else "night"
			var cards: Array = main.views.values().filter(func(v: CardView):
				return Looks.mismatch(panel_box(v), Looks.paper()) == "")
			check(not cards.is_empty(), "%s: a card on plain paper" % mode)
			var surfaces := {
				"board": MainProbe.background_box(main),
				"Strip": panel_box(strip(main)),
				"card": panel_box(cards[0]) if not cards.is_empty() else null,
				"Sheet": panel_box(main.identity_modal.panel),
			}
			for surface: String in surfaces:
				var tex := Looks.texture_of(surfaces[surface])
				check(tex != null, "%s: the %s is textured" % [mode, surface])
				if tex == null:
					continue
				var ground := Looks.mean(tex)
				for text in ["TEXT", "TEXT_DIM"]:
					var r := Looks.contrast(Palette.color(text), ground)
					check(r >= 4.5, "%s: %s on the %s is %.2f:1, needs 4.5" % [mode, text, surface, r])
				if surface == "card":
					for hue in ["CONTROL_BORDER", "GAIN", "WEALTH", "INSIGHT", "UNREST", "POP"]:
						var r := Looks.contrast(Palette.color(hue), ground)
						check(r >= 3.0, "%s: %s on the card is %.2f:1, needs 3" % [mode, hue, r])
			close_main(main)
		set_day(false))
