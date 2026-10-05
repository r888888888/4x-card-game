class_name GameMenu
extends Modal
## The menu, a sheet on the modal stack (207): game actions only (206): Restart, New game and Settings, then Close and
## Exit in its footer, under a "Playing as" line. Tab and the arrows stay inside it; Esc or a click outside closes it.
## The board decides what the buttons do through the signals.

## Restart: this game's seed again (seed_value).
signal start_requested(seed_value: int)
## New game: to the new game screen (099).
signal new_game_requested
## Settings: the Settings modal over the menu (206).
signal settings_requested
## The menu closed (Close, Esc, a click outside, or the board's dismiss): give_back says whether the focus goes back,
## to card (the one that had it when the menu opened) or, for null, the Menu button.
signal closed_giving_back(card: CardView, give_back: bool)
signal exit_requested

var _seed := -1  # this game's seed, for Restart
var _restart_button: Button
var _return_to: CardView  # the card that had the focus when the menu opened
var _give_back := true  # whether closing gives the focus back (not for Restart or New game)
var _civ_label: Label  # "Playing as <civilization>", hidden when the game has none (064)


## Builds the menu on stack's host, hidden.
func _init(p_stack: ModalStack) -> void:
	super(p_stack)
	title = "Menu"
	body.custom_minimum_size.x = 320
	_civ_label = UIKit.heading("")
	_civ_label.tooltip_text = "Restart keeps this civilization. New game lets you choose again."
	_civ_label.mouse_filter = Control.MOUSE_FILTER_STOP  # so the tooltip shows
	body.add_child(_civ_label)
	_restart_button = UIKit.button("Restart", func(): start_requested.emit(_seed))
	_restart_button.tooltip_text = "Start this game again: the same seed and civilization."
	var new_game := UIKit.button("New game", func(): new_game_requested.emit())
	new_game.tooltip_text = "Leave this game and choose a civilization and seed."
	var settings := UIKit.button("Settings", func(): settings_requested.emit())
	settings.tooltip_text = "Motion, day mode, sound, and restarting with another seed."
	UIKit.button_column(body, [_restart_button, new_game, settings])
	var close_button := add_footer_button(UIKit.button("Close", close))
	var exit := add_footer_button(UIKit.button("Exit", func(): exit_requested.emit()))
	exit.tooltip_text = "Quit the game. It isn't saved."
	UIKit.focus_loop([_restart_button, new_game, settings, close_button, exit])


## The game now being played: its seed, and its civilization's name ("" for none).
func set_game(seed_value: int, civ_name: String) -> void:
	_seed = seed_value
	_civ_label.text = "Playing as %s" % civ_name
	_civ_label.visible = civ_name != ""


## Shows the menu with Restart focused; return_to gets the focus back when it closes.
func open(return_to: CardView) -> void:
	_return_to = return_to
	present()
	FocusRing.focus(_restart_button)


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
