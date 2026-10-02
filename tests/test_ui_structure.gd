extends "res://tests/lib/test_case.gd"
## The shape of ui/ (backlog 052): each UI component lives in its own script, and no UI script
## reads engine state that an engine query covers. Checks the source files; behavior is covered by the UI smoke test.

const MAIN_PATH := "res://ui/main.gd"
## Component script -> the class_name it declares.
const COMPONENTS := {
	"res://ui/supply_screen.gd": "SupplyScreen",
	"res://ui/choice_overlays.gd": "ChoiceOverlays",
	"res://ui/top_bar.gd": "TopBar",
	"res://ui/tableau_view.gd": "TableauView",
	"res://ui/drag_controller.gd": "DragController",
	"res://ui/card_focus.gd": "CardFocus",
	"res://ui/card_details_modal.gd": "CardDetailsModal",
	"res://ui/tech_tree_modal.gd": "TechTreeModal",
	"res://ui/event_modal.gd": "EventModal",
	"res://ui/new_game_screen.gd": "NewGameScreen",
	"res://ui/settings_screen.gd": "SettingsScreen",
	"res://ui/navigator.gd": "Navigator",
	"res://ui/palette.gd": "Palette",
	"res://ui/game_theme.gd": "GameTheme",
	"res://ui/action_button.gd": "ActionButton",  # 175: Relieve famine, Restore order and Revolt
	"res://ui/board_views.gd": "BoardViews",  # 176: syncing card views with the engine
	"res://ui/board_layout.gd": "BoardLayout",  # 176: building the board's layout
}
const CARD_VIEW_PATH := "res://ui/card_view.gd"
## CardView's parts (backlog 086): script -> the class_name it declares.
const CARD_VIEW_PARTS := {
	"res://ui/card_face.gd": "CardFace",
	"res://ui/card_motion.gd": "CardMotion",
}
## Engine state the UI must reach through a query instead: the raw GameState (state; its pending is read with pending()),
## the RNG, the log lines (the logged signal) and the config (175: hand_limit(), research_on()).
const INTERNALS := [".state.", ".rng", "log_lines", ".config."]


func source(path: String) -> String:
	return FileAccess.get_file_as_string(path)


## The .gd files directly in ui/.
func ui_scripts() -> Array[String]:
	var out: Array[String] = []
	for file in DirAccess.get_files_at("res://ui"):
		if file.ends_with(".gd"):
			out.append("res://ui/" + file)
	return out


# --- AC1: components in their own scripts (script size: test_script_size.gd, backlog 085) ---

func test_each_ui_component_has_its_own_script() -> void:
	for path in COMPONENTS:
		check(FileAccess.file_exists(path), "%s exists" % path)
		check(source(path).contains("class_name %s" % COMPONENTS[path]), "%s declares class_name %s" % [path, COMPONENTS[path]])


func test_main_uses_each_component() -> void:
	var main := source(MAIN_PATH)
	for path in COMPONENTS:
		check(main.contains(COMPONENTS[path]), "ui/main.gd uses %s" % COMPONENTS[path])


func test_card_view_content_and_motion_have_their_own_scripts() -> void:
	for path in CARD_VIEW_PARTS:
		check(FileAccess.file_exists(path), "%s exists" % path)
		check(source(path).contains("class_name %s" % CARD_VIEW_PARTS[path]), "%s declares class_name %s" % [path, CARD_VIEW_PARTS[path]])


func test_card_view_uses_its_content_and_motion() -> void:
	var view := source(CARD_VIEW_PATH)
	for path in CARD_VIEW_PARTS:
		check(view.contains(CARD_VIEW_PARTS[path]), "ui/card_view.gd uses %s" % CARD_VIEW_PARTS[path])


# --- AC2: no engine internals in ui/ ---

func test_ui_scripts_read_no_engine_internals() -> void:
	var found: Array[String] = []
	for path in ui_scripts():
		var text := source(path)
		for name in INTERNALS:
			if text.contains(name):
				found.append("%s reads %s" % [path, name])
	eq(found, [] as Array[String], "engine internals read in ui/")


# --- Backlog 092: UI text never names content ---

## The quoted string literals on a line of GDScript, without their quotes.
func string_literals(line: String) -> Array[String]:
	var out: Array[String] = []
	var re := RegEx.create_from_string("\"((?:[^\"\\\\]|\\\\.)*)\"")
	for m in re.search_all(line):
		out.append(m.get_string(1))
	return out


func test_ui_names_no_card_from_the_real_data() -> void:
	var r := DataLoader.load_all("res://data/cards.json", "res://data/config.json")
	check(r.errors.is_empty(), "real data errors: %s" % [r.errors])
	var names: Array[String] = []
	for id in r.cards:
		names.append(r.cards[id].name)
	var found: Array[String] = []
	for path in ui_scripts():
		var lines := source(path).split("\n")
		for i in lines.size():
			for text in string_literals(lines[i]):
				for name in names:
					if text == name or text.contains(name + " card"):
						found.append("%s:%d names %s" % [path, i + 1, name])
	eq(found, [] as Array[String], "card names from data/cards.json in ui/ string literals")


# --- Backlog 094: the targeting choice, tech eras and open piles come from the engine ---

func test_ui_asks_the_engine_for_targeting_tech_eras_and_open_piles() -> void:
	check(source(MAIN_PATH).contains("needs_target_choice("), "main.gd asks needs_target_choice")
	var tree := source("res://ui/tech_tree_modal.gd")
	check(tree.contains("tech_eras()"), "tech_tree_modal.gd builds from tech_eras()")
	check(not tree.contains(".config") and not tree.contains("tech_tree()"), "tech_tree_modal.gd reads no config or tech_tree()")
	var supply := source("res://ui/supply_screen.gd")
	check(supply.contains("open_supply_piles()") and not supply.contains("supply_locked"),
		"supply_screen.gd shows open_supply_piles() and filters nothing itself")


# --- Backlog 175: one action-button class; hand cards picked up through the engine ---

func test_the_board_action_buttons_share_one_class() -> void:
	for path in ["res://ui/relieve_button.gd", "res://ui/restore_order_button.gd", "res://ui/revolt_button.gd"]:
		check(not FileAccess.file_exists(path), "%s is gone" % path)


func test_main_asks_the_engine_whether_a_hand_card_can_be_picked_up() -> void:
	check(source(MAIN_PATH).contains("hand_input_error()"), "main.gd asks hand_input_error")


# --- Backlog 176: main.gd split along the view-sync and layout boundaries ---

## The soft script-size limit (test_script_size.gd): past it the suite prints a WARN line.
const SOFT_LIMIT := 500


func test_main_is_under_the_soft_limit() -> void:
	var lines := source(MAIN_PATH).count("\n")  # as wc -l counts, like tests/lib/script_sizes.gd
	check(lines <= SOFT_LIMIT, "ui/main.gd: %d lines (soft limit %d)" % [lines, SOFT_LIMIT])


func test_the_ui_asks_the_engine_which_zone_holds_a_card() -> void:
	check(source("res://ui/tableau_view.gd").contains("zone_of("), "TableauView.leading_zone uses zone_of")
	check(source("res://ui/board_views.gd").contains("zone_of("), "the leave point uses zone_of")


# --- 177: tests find counters by name ---

## The counters' old prefixes, as string literals (built here so this file doesn't hold them itself).
func counter_prefixes() -> Array[String]:
	var out: Array[String] = []
	for word in ["Food", "Wealth", "Insight", "Unrest", "Score", "Pop"]:
		out.append("\"%s:\"" % word)
	return out


func test_no_test_finds_a_counter_by_its_text() -> void:
	var found: Array[String] = []
	for dir in ["res://tests", "res://tests/lib"]:
		for file in DirAccess.get_files_at(dir):
			if not file.ends_with(".gd"):
				continue
			var text := source(dir + "/" + file)
			for prefix in counter_prefixes():
				if text.contains(prefix):
					found.append("%s/%s: %s" % [dir, file, prefix])
	eq(found, [] as Array[String], "tests use counter(key) and counter_text(key), not a counter's text")


# --- 179: machined motion ---

func test_no_tween_overshoots_or_bounces() -> void:
	var found: Array[String] = []
	for path in ui_scripts():
		for trans in ["TRANS_BACK", "TRANS_ELASTIC", "TRANS_BOUNCE"]:
			if source(path).contains(trans):
				found.append("%s: %s" % [path, trans])
	eq(found, [] as Array[String], "tweens in ui/ that overshoot or bounce")


func test_the_pulses_pops_and_slides_ease_out_quartically() -> void:
	for path in ["res://ui/ui_kit.gd", "res://ui/territory_view.gd", "res://ui/card_motion.gd"]:
		check(source(path).contains(".set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)"),
			"%s eases out with TRANS_QUART" % path)


# --- 183: no colour frozen before a Day mode switch ---

## Each const declaration in path's code (a multi-line one joined up) that reads a Palette colour, as "file:line".
func palette_constants(path: String) -> Array[String]:
	var found: Array[String] = []
	var lines := source(path).split("\n")
	var i := 0
	while i < lines.size():
		if lines[i].begins_with("const "):
			var start := i
			var text := lines[i].split("#")[0]
			var depth := text.count("{") + text.count("[") + text.count("(") - text.count("}") - text.count("]") - text.count(")")
			while depth > 0 and i + 1 < lines.size():
				i += 1
				var more := lines[i].split("#")[0]
				text += more
				depth += more.count("{") + more.count("[") + more.count("(") - more.count("}") - more.count("]") - more.count(")")
			if text.contains("Palette."):
				found.append("%s:%d" % [path.get_file(), start + 1])
		i += 1
	return found


func test_no_ui_script_holds_a_palette_colour_in_a_constant() -> void:
	var found: Array[String] = []
	for path in ui_scripts():
		if path != "res://ui/palette.gd":
			found.append_array(palette_constants(path))
	eq(found, [] as Array[String], "constants that freeze a Palette colour (read Palette when drawing instead)")
