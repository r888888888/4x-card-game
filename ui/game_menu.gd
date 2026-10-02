class_name GameMenu
extends Modal
## The menu, a sheet on the modal stack (207): the seed field, Restart, New game, Reduce motion, Day mode and sounds,
## then Close and Exit in its footer. Tab and the arrows stay inside it; Esc or a click outside closes it. The board
## decides what the buttons do through the signals.

## Restart or Enter in the seed field (seed_value: the field's seed, or -1 if it isn't a whole number).
signal start_requested(seed_value: int)
## New game: to the new game screen (099).
signal new_game_requested
## The menu closed (Close, Esc, a click outside, or the board's dismiss): give_back says whether the focus goes back,
## to card (the one that had it when the menu opened) or, for null, the Menu button.
signal closed_giving_back(card: CardView, give_back: bool)
signal exit_requested

var _seed_edit: LineEdit
var _return_to: CardView  # the card that had the focus when the menu opened
var _give_back := true  # whether closing gives the focus back (not for Restart or New game)
var _civ_label: Label  # "Playing as <civilization>", hidden when the game has none (064)
var motion_toggle: LegendKey  # Reduce motion, in its row (182)
var day_toggle: LegendKey  # Day mode, in its row under it (183)
var sound_toggle: LegendKey  # Interface sounds, under Day mode (185)


## Builds the menu on stack's host, hidden.
func _init(p_stack: ModalStack) -> void:
	super(p_stack)
	title = "Menu"
	var box := body
	box.custom_minimum_size.x = 320
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
	sound_toggle = UIKit.sound_toggle()
	UIKit.button_column(box, [restart, new_game, UIKit.setting_row("Reduce motion", motion_toggle),
		UIKit.setting_row("Day mode", day_toggle), UIKit.setting_row("Interface sounds", sound_toggle)])
	var close_button := add_footer_button(UIKit.button("Close (Esc)", close))
	var exit := add_footer_button(UIKit.button("Exit", func(): exit_requested.emit()))
	exit.tooltip_text = "Quit the game. It isn't saved."
	UIKit.focus_loop([_seed_edit, restart, new_game, motion_toggle, day_toggle, sound_toggle, close_button, exit])


## Puts seed_value in the seed field (shown the next time the menu opens).
func set_seed(seed_value: int) -> void:
	_seed_edit.text = str(seed_value)


## The game now being played: its seed, and its civilization's name ("" for none).
func set_game(seed_value: int, civ_name: String) -> void:
	set_seed(seed_value)
	_civ_label.text = "Playing as %s" % civ_name
	_civ_label.visible = civ_name != ""


## Shows the menu with the seed field focused and holding seed_value; return_to gets the focus back when it closes.
func open(seed_value: int, return_to: CardView) -> void:
	_return_to = return_to
	set_seed(seed_value)
	present()
	_seed_edit.grab_focus()
	_seed_edit.select_all()


## Closes it; give_back false: the focus goes nowhere (the board is restarting or leaving).
func dismiss(give_back: bool) -> void:
	_give_back = give_back
	close()


func closed() -> void:
	var card := _return_to
	var give_back := _give_back
	_return_to = null
	_give_back = true
	closed_giving_back.emit(card, give_back)


## Restart: the seed in the field, or a random one if it isn't a whole number.
func _restart() -> void:
	var text := _seed_edit.text.strip_edges()
	start_requested.emit(text.to_int() if text.is_valid_int() else -1)


## Matches the Reduce motion, Day mode and Interface sounds keys to the settings.
func show_settings(calm: bool, day: bool) -> void:
	UIKit.show_setting(motion_toggle, calm)
	UIKit.show_setting(day_toggle, day)
	UIKit.show_setting(sound_toggle, Settings.interface_sounds)
