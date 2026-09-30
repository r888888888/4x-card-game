class_name NewGameScreen
extends RefCounted
## The new game screen (backlog 099): the civilizations to play as (064), the seed field and Start, and Back to the
## title screen. It opens from the title screen's New game and the menu's New game, with the board hidden behind it.
## The board decides what Start and Back do through the signals; selected is the civilization to use.

## Start, or Enter in the seed field (seed_value: the field's seed, or -1 if it is empty or not a whole number).
signal start_requested(seed_value: int)
## Back or Esc: to the title screen.
signal back_requested

var overlay: Control
var seed_edit: LineEdit
var start_button: Button
var back_button: Button
var selected := ""  # the id of the chosen civilization, "" if the game offers none

var _civ_row: HBoxContainer  # one display-only card per civilization, in config order
var _civ_views := {}  # civilization id -> CardView
var _on_details: Callable  # opens a card's details (the board's CardDetailsModal)


## Builds the screen on parent, hidden.
func _init(parent: Control, on_details: Callable) -> void:
	_on_details = on_details
	overlay = UIKit.overlay(parent)
	overlay.z_index = 15  # above the game-over overlay, below the card details (the menu can't be open)
	var box := overlay.get_meta("box") as VBoxContainer
	box.custom_minimum_size.x = 360
	var title := UIKit.title("New game")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var pad := MarginContainer.new()  # room above the cards for their hover lift
	pad.add_theme_constant_override("margin_top", int(Anim.HOVER_LIFT) + 8)
	box.add_child(pad)
	_civ_row = HBoxContainer.new()
	_civ_row.add_theme_constant_override("separation", UIKit.CARD_GAP)
	_civ_row.alignment = BoxContainer.ALIGNMENT_CENTER
	pad.add_child(_civ_row)
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
	start_button = UIKit.button("Start", _start)
	start_button.tooltip_text = "Start a game with the seed above, or a random one if it's empty."
	box.add_child(start_button)
	back_button = UIKit.button("Back", func(): back_requested.emit())
	box.add_child(back_button)
	UIKit.focus_loop([start_button, seed_edit, back_button])


func is_open() -> bool:
	return overlay.visible


## Shows the screen with Start focused, offering civilizations (ids in engine e's card_db) with preselect chosen.
func open(e: GameEngine, civilizations: Array[String], preselect: String) -> void:
	_show_civilizations(e, civilizations)
	_show_selected(preselect)
	overlay.show()
	start_button.grab_focus()


## The civilization cards shown, in order.
func civilization_ids() -> Array[String]:
	var out: Array[String] = []
	out.assign(_civ_views.keys())
	return out


## What a click on a civilization card does: choose it and remember the choice.
func select(civ_id: String) -> void:
	_show_selected(civ_id)
	Settings.set_civilization(civ_id)


func _show_civilizations(e: GameEngine, civilizations: Array[String]) -> void:
	if civilization_ids() == civilizations:
		return
	for slot in _civ_row.get_children():
		_civ_row.remove_child(slot)
		slot.queue_free()
	_civ_views.clear()
	for i in civilizations.size():
		var slot := Control.new()
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.custom_minimum_size = CardView.TABLEAU_SIZE
		_civ_row.add_child(slot)
		var view := CardView.new()
		view.setup(CardInstance.new(-1 - i, e.card_db[civilizations[i]]), e.card_db, false)
		view.lift_on_hover = true
		view.set_pickable(true, "Click to play as this civilization.")
		view.picked.connect(func(v: CardView): select(v.card_id))
		view.details_requested.connect(_on_details)
		view.attach(slot)
		_civ_views[civilizations[i]] = view
	_civ_row.get_parent().visible = not civilizations.is_empty()


func _show_selected(civ_id: String) -> void:
	selected = civ_id
	for id in _civ_views:
		_civ_views[id].set_highlight(id == civ_id)


func hide() -> void:
	overlay.hide()


func _start() -> void:
	var text := seed_edit.text.strip_edges()
	start_requested.emit(text.to_int() if text.is_valid_int() else -1)
