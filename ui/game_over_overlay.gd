class_name GameOverOverlay
extends RefCounted
## The game-over overlay: the final score and seed, Replay this seed and New game.

var overlay: Control
var _label: Label
var _replay_button: Button


## Builds the overlay on parent, hidden. on_replay and on_new_game are the buttons' actions.
func _init(parent: Control, on_replay: Callable, on_new_game: Callable) -> void:
	overlay = UIKit.overlay(parent)
	var box := overlay.get_meta("box") as VBoxContainer
	_label = UIKit.title("")
	_label.theme_type_variation = &"Display"
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_label)
	_replay_button = UIKit.button("Replay this seed", on_replay)
	UIKit.button_column(box, [_replay_button, UIKit.button("New game", on_new_game)])


## The overlay's text, or "" while it is hidden.
func text() -> String:
	return _label.text if overlay.visible else ""


## Shows the overlay once engine e's game is over, with Replay focused so Enter replays from the keyboard.
func refresh(e: GameEngine) -> void:
	if e.is_over and not overlay.visible:
		_replay_button.grab_focus()
		var sfx := Sfx.find(overlay)
		if sfx != null:
			sfx.play(Sfx.MILESTONE_VICTORY)  # the closing ceremony (191)
	overlay.visible = e.is_over
	if e.is_over:
		_label.text = "Game over\n\nFinal score: %d\nSeed: %d" % [e.score(), e.seed_value]
		var civ := e.zone("civilization").find(e.civilization())
		if civ != null:
			_label.text += "\nPlayed as %s" % civ.def.name
