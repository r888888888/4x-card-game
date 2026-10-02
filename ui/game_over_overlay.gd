class_name GameOverOverlay
extends Modal
## The game-over sheet (207: a Modal on the stack): the final score and seed, New game and Replay this seed (primary).
## It can't be dismissed: only its buttons, or a new game, end it. Opening, it replaces any sheet still open.

var _label: Label
var _replay_button: Button


## Builds the sheet on stack's host, hidden. on_replay and on_new_game are the buttons' actions.
func _init(p_stack: ModalStack, on_replay: Callable, on_new_game: Callable) -> void:
	super(p_stack)
	title = "Game over"
	dismissable = false
	_label = UIKit.title("")
	_label.theme_type_variation = &"Body"
	body.add_child(_label)
	add_footer_button(UIKit.button("New game", on_new_game))
	_replay_button = add_footer_button(UIKit.button("Replay this seed", on_replay), true)


## The sheet's text, or "" while it is closed.
func text() -> String:
	return _label.text if is_open() else ""


## Opens the sheet once engine e's game is over, with Replay focused so Enter replays from the keyboard.
func refresh(e: GameEngine) -> void:
	if not e.is_over:
		close()
		return
	_label.text = "Final score: %d\nSeed: %d" % [e.score(), e.seed_value]
	var civ := e.zone("civilization").find(e.civilization())
	if civ != null:
		_label.text += "\nPlayed as %s" % civ.def.name
	if not is_open():
		stack.close_all()  # the game is over: it replaces any sheet still open (the last turn's event)
		present()
		_replay_button.grab_focus()
		var sfx := Sfx.find(self)
		if sfx != null:
			sfx.play(Sfx.MILESTONE_VICTORY)  # the closing ceremony (191)
