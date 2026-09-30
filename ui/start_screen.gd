class_name StartScreen
extends RefCounted
## The start screen (backlog 063): the game's title, New game with an optional seed, and the Reduce motion toggle.
## It is shown on launch and from the menu's New game, with the board hidden behind it. The board decides what New
## game does through start_requested.

## New game, or Enter in the seed field (seed_value: the field's seed, or -1 if it is empty or not a whole number).
signal start_requested(seed_value: int)

var overlay: Control
var seed_edit: LineEdit
var new_game_button: Button
var motion_toggle: Button


## Builds the screen on parent, hidden.
func _init(parent: Control) -> void:
	overlay = UIKit.overlay(parent)
	overlay.z_index = 30  # above the menu and every other overlay
	var box := overlay.get_meta("box") as VBoxContainer
	box.custom_minimum_size.x = 360
	var title := UIKit.title(ProjectSettings.get_setting("application/config/name"))
	title.add_theme_font_size_override("font_size", 40)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	new_game_button = UIKit.button("New game", _start)
	new_game_button.tooltip_text = "Start a game with the seed below, or a random one if it's empty."
	box.add_child(new_game_button)
	var seed_row := HBoxContainer.new()
	seed_row.add_theme_constant_override("separation", 10)
	box.add_child(seed_row)
	var seed_label := Label.new()
	seed_label.text = "Seed"
	seed_row.add_child(seed_label)
	seed_edit = LineEdit.new()
	seed_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	seed_edit.placeholder_text = "random"
	seed_edit.tooltip_text = "The same seed deals the same game. Leave it empty for a random one."
	seed_edit.text_submitted.connect(func(_text: String): _start())
	seed_row.add_child(seed_edit)
	motion_toggle = UIKit.motion_toggle()
	box.add_child(motion_toggle)
	UIKit.focus_loop([new_game_button, seed_edit, motion_toggle])


func is_open() -> bool:
	return overlay.visible


## Shows the screen with New game focused.
func open() -> void:
	overlay.show()
	new_game_button.grab_focus()


func hide() -> void:
	overlay.hide()


func _start() -> void:
	var text := seed_edit.text.strip_edges()
	start_requested.emit(text.to_int() if text.is_valid_int() else -1)
