class_name NewGameScreen
extends RefCounted
## The new game screen (backlog 099; a list and a detail pane since 212): its header with Back to the title screen
## (104), the civilizations down the left as list rows (064), the selected one's story and rules on the right, and the
## seed field and Start at the pane's foot. It opens from the title screen's New game and the menu's New game, with
## the board hidden behind it. A click or the arrows select a row; nothing opens over it. The board decides what Start
## does through start_requested; selected is the civilization to use. The list is a SelectList (217), and the sheet
## holds still: the detail is as tall as the tallest civilization's, with the seed and Start under a footer rule.

## Start, or Enter in the seed field (seed_value: the field's seed, or -1 if it is empty or not a whole number).
signal start_requested(seed_value: int)

const LIST_WIDTH := Tokens.SPACE_9 * 3  # the civilizations' column
const PANE_WIDTH := 560  # the detail pane's text; long flavour wraps inside it

var overlay: Control
var header: ScreenHeader
var seed_edit: LineEdit
var start_button: Button
var back_button: Button  # the header's
var selected := ""  # the id of the chosen civilization, "" if the game offers none
var civilization_list: SelectList  # one row per civilization, in config order (217)
var detail_pane: VBoxContainer  # the selected civilization, then the seed field and Start
var detail_body: RichTextLabel

var _detail_title: Label
var _engine: GameEngine


## Builds the screen on parent, hidden, for the board's navigator nav.
func _init(parent: Control, nav: Navigator) -> void:
	overlay = UIKit.overlay(parent)
	overlay.z_index = 15  # above the game-over sheet, below the card details (the menu can't be open)
	var box := overlay.get_meta("box") as VBoxContainer
	header = ScreenHeader.new(nav)
	box.add_child(header)
	back_button = header.back_button
	var split := HBoxContainer.new()
	split.add_theme_constant_override("separation", Tokens.SPACE_6)
	box.add_child(split)
	civilization_list = UIKit.select_list()
	civilization_list.custom_minimum_size.x = LIST_WIDTH
	civilization_list.chosen.connect(select)
	split.add_child(civilization_list)
	detail_pane = VBoxContainer.new()
	detail_pane.add_theme_constant_override("separation", Tokens.SPACE_4)
	split.add_child(detail_pane)
	_detail_title = UIKit.title("")
	detail_pane.add_child(_detail_title)
	detail_body = RichTextLabel.new()
	detail_body.bbcode_enabled = true
	detail_body.fit_content = true
	detail_body.custom_minimum_size.x = PANE_WIDTH
	detail_body.theme_type_variation = &"RichBody"
	detail_pane.add_child(detail_body)
	var rule := ColorRect.new()
	rule.name = "FooterRule"
	rule.custom_minimum_size.y = 1  # a hairline (guide border.hair)
	UIKit.painted(rule, func(): rule.color = Palette.HAIRLINE)
	detail_pane.add_child(rule)
	var seed_row := HBoxContainer.new()
	seed_row.add_theme_constant_override("separation", Tokens.SPACE_3)
	detail_pane.add_child(seed_row)
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
	start_button.tooltip_text = "Start a game as the selected civilization, with the seed beside it (random if empty)."
	start_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	detail_pane.add_child(start_button)


func is_open() -> bool:
	return Navigator.is_shown(overlay)


## Offers civilizations (ids in engine e's card_db) with preselect chosen. The board's Navigator shows the screen.
func show_civilizations(e: GameEngine, civilizations: Array[String], preselect: String) -> void:
	_engine = e
	_fill_civilizations(e, civilizations)
	_show_selected(preselect)


## The control that takes the focus when the screen opens: the selected row, or Start with no civilizations.
func first_focus() -> Control:
	var row := civilization_list.row(selected)
	return row if row != null else start_button


## The civilizations listed, in order.
func civilization_ids() -> Array[String]:
	return civilization_list.ids()


## Test hooks (212): civ_id's row (or null), and the detail pane's title and text without markup.
func civilization_row(civ_id: String) -> Button:
	return civilization_list.row(civ_id)


func detail_title() -> String:
	return _detail_title.text


func detail_text() -> String:
	return detail_body.get_parsed_text()


## Choose civ_id and remember the choice. A click on its row, or the arrows onto it, do this.
func select(civ_id: String) -> void:
	_show_selected(civ_id)
	Settings.set_civilization(civ_id)


func _fill_civilizations(e: GameEngine, civilizations: Array[String]) -> void:
	civilization_list.visible = not civilizations.is_empty()
	if civilization_ids() == civilizations:
		return
	civilization_list.clear()
	for id in civilizations:
		civilization_list.add_row(id, e.card_db[id].name).tooltip_text = "Play as %s." % e.card_db[id].name
	var loop: Array[Control] = []
	for id in civilizations:
		loop.append(civilization_list.row(id))
	loop.append_array([seed_edit, start_button, back_button])
	UIKit.focus_loop(loop)
	_fit_tallest(e, civilizations)


## Holds the detail at the height of the tallest civilization's text (217), so the sheet never resizes or moves.
func _fit_tallest(e: GameEngine, civilizations: Array[String]) -> void:
	detail_body.custom_minimum_size.y = 0
	detail_body.size.x = PANE_WIDTH
	var tallest := 0
	for id in civilizations:
		detail_body.text = _detail_bbcode(e, id)
		tallest = maxi(tallest, detail_body.get_content_height())
	detail_body.custom_minimum_size.y = tallest


func _show_selected(civ_id: String) -> void:
	selected = civ_id
	civilization_list.select(civ_id)
	if civ_id == "" or _engine == null:
		_detail_title.text = ""
		detail_body.text = "This game offers no civilizations: you play without one."
		return
	_detail_title.text = _engine.card_db[civ_id].name
	detail_body.text = _detail_bbcode(_engine, civ_id)


## civ_id's story, rules and home, as the detail pane shows them.
static func _detail_bbcode(e: GameEngine, civ_id: String) -> String:
	var def: CardDef = e.card_db[civ_id]
	var text := CardDetailsModal.body_bbcode(e.def_details(civ_id))
	if def.home != "":
		var home: CardDef = e.card_db[def.home]
		var keywords := home.keywords.map(func(k): return k.capitalize())
		text += "\n\n[b]Home[/b]\n%s: %s" % [home.name, " · ".join(PackedStringArray(keywords))]
	return text


func _start() -> void:
	var text := seed_edit.text.strip_edges()
	start_requested.emit(text.to_int() if text.is_valid_int() else -1)
