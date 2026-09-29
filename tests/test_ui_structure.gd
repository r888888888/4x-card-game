extends "res://tests/lib/test_case.gd"
## The shape of ui/ (backlog 052): main.gd stays small, each UI component lives in its own script, and no UI script
## reads engine state that an engine query covers. Checks the source files; behavior is covered by the UI smoke test.

const MAIN_PATH := "res://ui/main.gd"
const MAX_MAIN_LINES := 500
## Component script -> the class_name it declares.
const COMPONENTS := {
	"res://ui/supply_screen.gd": "SupplyScreen",
	"res://ui/choice_overlays.gd": "ChoiceOverlays",
	"res://ui/top_bar.gd": "TopBar",
	"res://ui/tableau_view.gd": "TableauView",
	"res://ui/drag_controller.gd": "DragController",
	"res://ui/card_focus.gd": "CardFocus",
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


# --- AC1: components in their own scripts, main.gd small ---

func test_main_script_is_at_most_500_lines() -> void:
	var lines := source(MAIN_PATH).split("\n").size()
	check(lines <= MAX_MAIN_LINES, "ui/main.gd has %d lines, over %d" % [lines, MAX_MAIN_LINES])


func test_each_ui_component_has_its_own_script() -> void:
	for path in COMPONENTS:
		check(FileAccess.file_exists(path), "%s exists" % path)
		check(source(path).contains("class_name %s" % COMPONENTS[path]), "%s declares class_name %s" % [path, COMPONENTS[path]])


func test_main_uses_each_component() -> void:
	var main := source(MAIN_PATH)
	for path in COMPONENTS:
		check(main.contains(COMPONENTS[path]), "ui/main.gd uses %s" % COMPONENTS[path])


# --- AC2: no engine internals in ui/ ---

func test_ui_scripts_read_no_engine_internals() -> void:
	var found: Array[String] = []
	for path in ui_scripts():
		var text := source(path)
		for name in INTERNALS:
			if text.contains(name):
				found.append("%s reads %s" % [path, name])
	eq(found, [] as Array[String], "engine internals read in ui/")
