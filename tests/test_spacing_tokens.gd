extends "res://tests/lib/test_case.gd"
## Spacing and corner radius tokens (193): the guide's space and radius scales (docs/design/mcm-style-guide.md §6.1,
## §6.3) as constants named after its tokens, every spacing and radius on screen a step of them, and no numeric
## literal for one in ui/. The token script is loaded by path (held as Script) so this file parses before it exists.

const TOKENS_PATH := "res://ui/tokens.gd"
const SPACE_SCALE := [0, 4, 8, 12, 16, 24, 32, 48, 64, 96]
const RADIUS_SCALE := [0, 2, 4]
const RADIUS_FULL := 9999
const GLYPH_GAP := 3  # §6.7: a cost's glyph and its figure; the guide's one spacing off its scale
## Container constants that space things out, by the container class that reads them.
const SPACING := {
	"BoxContainer": ["separation"],
	"FlowContainer": ["h_separation", "v_separation"],
	"GridContainer": ["h_separation", "v_separation"],
	"MarginContainer": ["margin_left", "margin_top", "margin_right", "margin_bottom"],
}


## Opens main on a seed-1 game played to turn 3, laid out.
func mid_game() -> Node:
	var main := open_main()
	main.start_game(1)
	for i in 2:
		Game.engine.end_turn()
		if not main.event_modal().is_empty():
			main.event_modal_ok_button().pressed.emit()
	await wait_frames()
	return main


## Calls visit(main, name) on each screen to check: the board mid-game, then each modal and screen open over it, the
## start screens, a drawn event and game over. Use with await.
func each_screen(visit: Callable) -> void:
	await with_temp_settings(func():
		var main: Node = await mid_game()
		visit.call(main, "board")
		var openers := {
			"supply": func(): main.open_supply(),
			"tech tree": func(): main.tech_tree.open(),
			"card details": func(): main.details.open(main.views[first_in_hand(Game.engine)]),
			"identity": func(): main.identity_modal.open(),
			"log": func(): main.log_drawer.open(),
			"game menu": func(): main.open_menu(),
		}
		for screen: String in openers:
			openers[screen].call()
			await wait_screen_transition()
			visit.call(main, screen)
			main.modals.close_all()
			if main.log_drawer.is_open():
				main.log_drawer.close()
		close_main(main)

		main = open_main()
		await wait_screen_transition()
		visit.call(main, "start")
		main.start_screen.settings_button.pressed.emit()
		await wait_screen_transition()
		visit.call(main, "settings")
		close_main(main)
		main = open_main()
		main.show_new_game_screen()
		await wait_screen_transition()
		visit.call(main, "new game")
		close_main(main)

		main = open_main()
		main.start_game(1)
		var shown := false
		for i in 10:
			Game.engine.end_turn()
			if not main.event_modal().is_empty():
				shown = true
				break
		check(shown, "precondition: an event is drawn within 10 turns of seed 1")
		await wait_screen_transition()
		if shown:
			visit.call(main, "event")
		close_main(main)

		main = open_main()
		play_seed_1(main, func(_m): pass)
		await wait_frames()
		check(Game.engine.is_over, "precondition: game over")
		visit.call(main, "game over")
		close_main(main))


## The visible controls under root.
func visible_controls(root: Node) -> Array[Control]:
	var found: Array[Control] = []
	for c in root.find_children("*", "Control", true, false):
		if (c as Control).is_visible_in_tree():
			found.append(c)
	return found


## The flat styleboxes a control draws at rest (a panel's, or a button's or field's normal box).
func resting_boxes(c: Control) -> Array[StyleBoxFlat]:
	var boxes: Array[StyleBoxFlat] = []
	for name in ["panel", "normal"]:
		if c.has_theme_stylebox(name):
			var box := c.get_theme_stylebox(name) as StyleBoxFlat
			if box != null:
				boxes.append(box)
	return boxes


## Whether radius is full for c: as large as half its smaller side (Godot clamps a larger one to that).
func is_full(radius: int, c: Control) -> bool:
	return radius * 2 >= mini(int(c.size.x), int(c.size.y)) - 1


# --- AC1: the tokens ---

func test_the_tokens_hold_the_guides_scales() -> void:
	check(FileAccess.file_exists(TOKENS_PATH), "%s exists" % TOKENS_PATH)
	if not FileAccess.file_exists(TOKENS_PATH):
		return
	var tokens: Script = load(TOKENS_PATH)
	for i in SPACE_SCALE.size():
		eq(tokens.get("SPACE_%d" % i), SPACE_SCALE[i], "Tokens.SPACE_%d" % i)
	for i in RADIUS_SCALE.size():
		eq(tokens.get("RADIUS_%d" % i), RADIUS_SCALE[i], "Tokens.RADIUS_%d" % i)
	eq(tokens.get("RADIUS_FULL"), RADIUS_FULL, "Tokens.RADIUS_FULL (radius.full)")
	eq(tokens.get("GLYPH_GAP"), GLYPH_GAP, "Tokens.GLYPH_GAP (§6.7)")


func test_the_board_gaps_are_on_the_scale() -> void:
	eq(UIKit.SECTION_GAP, 24, "SECTION_GAP (§6.1: 22 becomes 24)")
	eq(UIKit.CARD_GAP, 12, "CARD_GAP (§6.1: 10 becomes 12)")
	eq(UIKit.HEADING_GAP, 8, "HEADING_GAP")


# --- AC2, AC3: on screen ---

func test_every_spacing_on_screen_is_on_the_scale() -> void:
	var off: Array[String] = []
	await each_screen(func(main: Node, screen: String):
		for c in visible_controls(main):
			for type: String in SPACING:
				if not c.is_class(type):
					continue
				for constant: String in SPACING[type]:
					var value := c.get_theme_constant(constant)
					if not SPACE_SCALE.has(value) and value != GLYPH_GAP:
						off.append("%s: %s %s %d" % [screen, main.get_path_to(c), constant, value]))
	eq(off, [] as Array[String], "spacings off the space scale")


func test_every_box_on_screen_has_a_radius_and_margins_on_the_scales() -> void:
	var off: Array[String] = []
	await each_screen(func(main: Node, screen: String):
		for c in visible_controls(main):
			for box in resting_boxes(c):
				var radius := box.corner_radius_top_left
				if not RADIUS_SCALE.has(radius) and not is_full(radius, c):
					off.append("%s: %s radius %d" % [screen, main.get_path_to(c), radius])
				for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
					var margin := int(box.get_content_margin(side))
					if margin >= 0 and not SPACE_SCALE.has(margin):
						off.append("%s: %s content margin %d" % [screen, main.get_path_to(c), margin]))
	eq(off, [] as Array[String], "corner radii and content margins off the scales")


# --- AC4: zones, hints and slots are cut square ---

func test_drop_zone_hint_error_and_slot_outline_are_square() -> void:
	await with_temp_settings(func():
		var main: Node = await mid_game()
		UIKit.show_error(main.fx, main.views[first_in_hand(Game.engine)], "No", 1920.0)
		var radii: Array[String] = []
		for c in main.fx.get_children():  # the drop zone, the drag hint and the error pop-up
			if c is Panel or c is PanelContainer:
				var box := (c as Control).get_theme_stylebox("panel") as StyleBoxFlat
				if box != null and box.corner_radius_top_left != 0:
					radii.append("%s %d" % [c.get_class(), box.corner_radius_top_left])
		var outline := UIKit.slot_outline()
		var slot := outline.get_theme_stylebox("panel") as StyleBoxFlat
		if slot.corner_radius_top_left != 0:
			radii.append("slot outline %d" % slot.corner_radius_top_left)
		outline.free()
		check(main.fx.get_child_count() >= 3, "precondition: the drop zone, the hint and the error are on the fx layer")
		eq(radii, [] as Array[String], "rounded zones, hints and slots")
		close_main(main))


# --- AC5: no literals ---

## Calls in ui/ that pass a spacing or radius, and the part of the line holding the value.
const CALLS := [
	"add_theme_constant_override(\"separation\"", "add_theme_constant_override(\"h_separation\"",
	"add_theme_constant_override(\"v_separation\"", "add_theme_constant_override(\"margin_",
	"set_content_margin_all(", "set_content_margin(", "content_margin_left =", "content_margin_top =",
	"content_margin_right =", "content_margin_bottom =", "set_corner_radius_all(", "set_corner_radius(",
]


## The ui/ lines (other than the tokens') that pass a numeric literal other than 0 as a spacing or radius.
func spacing_literals() -> Array[String]:
	var found: Array[String] = []
	var number := RegEx.create_from_string("(?<![\\w.])([0-9]+(\\.[0-9]+)?)(?![\\w.])")
	for file in DirAccess.get_files_at("res://ui"):
		if not file.ends_with(".gd") or "res://ui/" + file == TOKENS_PATH:
			continue
		var lines := FileAccess.get_file_as_string("res://ui/" + file).split("\n")
		for i in lines.size():
			var code := lines[i].split("#")[0]
			for call: String in CALLS:
				var at := code.find(call)
				if at < 0:
					continue
				for m in number.search_all(code.substr(at + call.length())):
					if float(m.get_string(1)) != 0.0:
						found.append("ui/%s:%d" % [file, i + 1])
						break
	return found


func test_no_ui_script_passes_a_spacing_or_radius_literal() -> void:
	eq(spacing_literals(), [] as Array[String], "spacing or radius literals (use Tokens)")
