class_name StartScreen
extends RefCounted
## The title screen (backlog 063, 099): the game's title and New game, Settings and Exit. It is the Navigator's
## root on launch and after leaving a game, with the board hidden behind it. The board decides what the
## buttons do through the signals.

signal new_game_requested
signal settings_requested
signal exit_requested

var overlay: Control
var new_game_button: Button
var settings_button: Button
var exit_button: Button


## Builds the screen on parent, hidden.
func _init(parent: Control) -> void:
	overlay = UIKit.overlay(parent)
	overlay.z_index = 15  # above the game-over overlay, below the card details (the menu can't be open)
	var box := overlay.get_meta("box") as VBoxContainer
	box.custom_minimum_size.x = 320
	var title := UIKit.title(ProjectSettings.get_setting("application/config/name"))
	title.add_theme_font_size_override("font_size", 40)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	new_game_button = UIKit.button("New game", func(): new_game_requested.emit())
	new_game_button.tooltip_text = "Choose a civilization and a seed, then start."
	settings_button = UIKit.button("Settings", func(): settings_requested.emit())
	exit_button = UIKit.button("Exit", func(): exit_requested.emit())
	exit_button.tooltip_text = "Quit the game."
	UIKit.button_column(box, [new_game_button, settings_button, exit_button])
	UIKit.focus_loop([new_game_button, settings_button, exit_button])


func is_open() -> bool:
	return Navigator.is_shown(overlay)

