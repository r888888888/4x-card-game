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
}
const CARD_VIEW_PATH := "res://ui/card_view.gd"
## CardView's parts (backlog 086): script -> the class_name it declares.
const CARD_VIEW_PARTS := {
	"res://ui/card_face.gd": "CardFace",
	"res://ui/card_motion.gd": "CardMotion",
}
## Engine state the UI must reach through a query instead: pending_choice and discard_left (pending()), the raw
## GameState (state), the RNG and the log lines (the logged signal).
const INTERNALS := ["pending_choice", "discard_left", ".state.", ".rng", "log_lines"]


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
