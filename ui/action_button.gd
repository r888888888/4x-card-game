class_name ActionButton
extends RefCounted
## A button below the Realm for one engine action (175; before it, one script each: 084, 146, 148): shown while
## shown(e) is true, labelled text(e), and disabled with error(e) as its tooltip, else showing tooltip. Pressing it
## calls action(e). relieve_famine, restore_order and revolt build the board's three.

var button: Button
var _text: Callable  # (e: GameEngine) -> String
var _shown: Callable  # (e: GameEngine) -> bool
var _error: Callable  # (e: GameEngine) -> String
var _tooltip: String


func _init(parent: Control, text: Callable, shown: Callable, error: Callable, action: Callable, tooltip: String) -> void:
	_text = text
	_shown = shown
	_error = error
	_tooltip = tooltip
	button = UIKit.button("", func(): action.call(Game.engine))
	button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	parent.add_child(button)


## Relieve famine (084): while a Famine can be relieved, disabled with the reason it can't pay.
static func relieve_famine(parent: Control) -> ActionButton:
	return ActionButton.new(parent,
		func(e: GameEngine): return "Relieve famine (%s)" % CardFace.cost_text(e.famine_relief()),
		func(e: GameEngine): return e.famine_counters() > 0 and not e.famine_relief().is_empty(),
		func(e: GameEngine): return e.relieve_famine_error(),
		func(e: GameEngine): e.relieve_famine(),
		"Pay to end the famine now. A later hungry upkeep brings a new one.")


## Restore order (146): while Anarchy rules and order can be bought, disabled with the reason it can't pay.
static func restore_order(parent: Control) -> ActionButton:
	return ActionButton.new(parent,
		func(e: GameEngine): return "Restore order (%s)" % CardFace.cost_text(e.order_relief()),
		func(e: GameEngine): return e.anarchy() != -1 and not e.order_relief().is_empty(),
		func(e: GameEngine): return e.restore_order_error(),
		func(e: GameEngine): e.restore_order(),
		"Pay to end the Anarchy now, then choose a government.")


## Revolt (148): while a revolutionary event lets you start Anarchy now.
static func revolt(parent: Control) -> ActionButton:
	return ActionButton.new(parent,
		func(_e: GameEngine): return "Revolt",
		func(e: GameEngine): return e.revolt_error() == "",
		func(e: GameEngine): return e.revolt_error(),
		func(e: GameEngine): e.revolt(),
		"Start Anarchy now: your government falls into your deck, and you trash cards from your discard. Play a government the people accept to end it.")


func refresh(e: GameEngine) -> void:
	button.visible = _shown.call(e)
	button.text = _text.call(e)
	var error: String = _error.call(e)
	button.disabled = error != ""
	button.tooltip_text = error if error != "" else _tooltip
