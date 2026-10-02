class_name GameMenu
extends RefCounted
## The menu modal, above everything else: the seed field, Restart, New game, Reduce motion, Close and Exit.
## Tab and the arrows stay inside it; a click on the dimmed area closes it. The board decides what the buttons
## do through the signals.

## Restart or Enter in the seed field (seed_value: the field's seed, or -1 if it isn't a whole number).
signal start_requested(seed_value: int)
## New game: to the new game screen (099).
signal new_game_requested
## Close, Esc, or a click on the dimmed area.
signal close_requested
signal exit_requested

var overlay: Control
var _seed_edit: LineEdit
var _civ_label: Label  # "Playing as <civilization>", hidden when the game has none (064)
var motion_toggle: LegendKey  # Reduce motion, in its row (182)
var day_toggle: LegendKey  # Day mode, in its row under it (183)


## Builds the menu on parent, hidden.
func _init(parent: Control) -> void:
	overlay = UIKit.overlay(parent)
	overlay.z_index = 20  # above the explore choice and game-over overlays
	overlay.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed:
			overlay.accept_event()
			close_requested.emit())
	var box := overlay.get_meta("box") as VBoxContainer
	box.custom_minimum_size.x = 320
	box.add_child(UIKit.title("Menu"))
	var seed_row := HBoxContainer.new()
	seed_row.add_theme_constant_override("separation", Tokens.SPACE_3)
	box.add_child(seed_row)
	var seed_label := Label.new()
	seed_label.text = "Seed"
	seed_row.add_child(seed_label)
	_seed_edit = LineEdit.new()
	_seed_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_seed_edit.tooltip_text = "Restart replays this seed (same shuffle)."
	_seed_edit.text_submitted.connect(func(_text: String): _restart())
	seed_row.add_child(_seed_edit)
	_civ_label = UIKit.heading("")
	_civ_label.tooltip_text = "Restart keeps this civilization. New game lets you choose again."
	_civ_label.mouse_filter = Control.MOUSE_FILTER_STOP  # so the tooltip shows
	box.add_child(_civ_label)
	var restart := UIKit.button("Restart", _restart)
	restart.tooltip_text = "Start again with the seed above."
	var new_game := UIKit.button("New game", func(): new_game_requested.emit())
	new_game.tooltip_text = "Leave this game and choose a civilization and seed."
	motion_toggle = UIKit.motion_toggle()
	day_toggle = UIKit.day_toggle()
	var close := UIKit.button("Close (Esc)", func(): close_requested.emit())
	var exit := UIKit.button("Exit", func(): exit_requested.emit())
	exit.tooltip_text = "Quit the game. It isn't saved."
	UIKit.button_column(box, [restart, new_game, UIKit.setting_row("Reduce motion", motion_toggle),
		UIKit.setting_row("Day mode", day_toggle), HSeparator.new(), close, exit])
	UIKit.focus_loop([_seed_edit, restart, new_game, motion_toggle, day_toggle, close, exit])


func is_open() -> bool:
	return overlay.visible


## Puts seed_value in the seed field (shown the next time the menu opens).
func set_seed(seed_value: int) -> void:
	_seed_edit.text = str(seed_value)


## The game now being played: its seed, and its civilization's name ("" for none).
func set_game(seed_value: int, civ_name: String) -> void:
	set_seed(seed_value)
	_civ_label.text = "Playing as %s" % civ_name
	_civ_label.visible = civ_name != ""


## Shows the menu with the seed field focused and holding seed_value.
func open(seed_value: int) -> void:
	set_seed(seed_value)
	overlay.show()
	_seed_edit.grab_focus()
	_seed_edit.select_all()


func hide() -> void:
	overlay.hide()


## Restart: the seed in the field, or a random one if it isn't a whole number.
func _restart() -> void:
	var text := _seed_edit.text.strip_edges()
	start_requested.emit(text.to_int() if text.is_valid_int() else -1)


## Matches the Reduce motion and Day mode keys to the settings.
func show_settings(calm: bool, day: bool) -> void:
	UIKit.show_setting(motion_toggle, calm)
	UIKit.show_setting(day_toggle, day)
