class_name SidePanel
extends VBoxContainer
## The right-hand column: the log, the Supply button, the Knowledge button (the tech tree), the event pile line, and
## End turn (which says how many cards to discard while the hand is over its limit).

var event_info: Label  # event deck and event discard counts
var _log: RichTextLabel
var _knowledge: Button  # opens the tech tree (059); research itself is a card (034)
var _end_turn_button: Button


## on_knowledge: the Knowledge button's action (open the tech tree).
func _init(on_knowledge: Callable) -> void:
	add_theme_constant_override("separation", UIKit.HEADING_GAP)
	add_child(UIKit.heading("Log"))
	custom_minimum_size.x = 360
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	var log_panel := PanelContainer.new()
	log_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	log_panel.add_theme_stylebox_override("panel", UIKit.panel_style(UIKit.PANEL_COLOR, Color(1, 1, 1, 0.08), 12))
	add_child(log_panel)
	_log = RichTextLabel.new()
	_log.bbcode_enabled = true
	_log.scroll_following = true
	_log.selection_enabled = true
	_log.add_theme_font_size_override("normal_font_size", 19)
	_log.add_theme_font_size_override("bold_font_size", 20)
	_log.add_theme_color_override("default_color", Color("dde3ea"))
	log_panel.add_child(_log)
	_knowledge = UIKit.button("Knowledge (T)", on_knowledge)
	_knowledge.tooltip_text = "The tech tree: every tech by era, what it costs now and what it gives.\nPlay an Insight card to reveal 2 techs."
	add_child(_knowledge)
	event_info = UIKit.heading("")
	event_info.mouse_filter = Control.MOUSE_FILTER_STOP  # so its tooltip shows
	event_info.tooltip_text = "One event is drawn at the end of each turn. It stays active until its turns run out."
	event_info.hide()
	add_child(event_info)
	_end_turn_button = UIKit.button("End turn  (E)", func(): Game.engine.end_turn())
	_end_turn_button.custom_minimum_size.y = 60
	_end_turn_button.add_theme_font_size_override("font_size", 24)
	_end_turn_button.theme_type_variation = "AccentButton"
	add_child(_end_turn_button)


## Puts the Supply button under the log.
func add_supply_button(button: Button) -> void:
	add_child(button)
	move_child(button, 2)  # after the heading and the log


func clear_log() -> void:
	_log.clear()


## Adds a line of BBCode to the log.
func note(bbcode: String) -> void:
	_log.append_text(bbcode + "\n")


## Adds an engine log message: turn headers bold, game over gold.
func append_log(message: String) -> void:
	message = Icons.bbcode(message, 19)  # the log's font size
	if message.begins_with("—"):
		_log.append_text("\n[b]%s[/b]\n" % message)
	elif message.begins_with("Game over"):
		_log.append_text("[b][color=#e8c547]%s[/color][/b]\n" % message)
	else:
		_log.append_text(message + "\n")


## The research and event lines and the End turn button, from engine e.
func refresh(e: GameEngine) -> void:
	_knowledge.text = "Knowledge (T) · %s" % e.era_name(e.era())
	_knowledge.visible = e.config.research_deck.size() > 0
	event_info.visible = not e.config.get("event_deck", {}).is_empty()
	event_info.text = "Events: deck %d · discard %d" % [e.zone("event_deck").size(), e.zone("event_discard").size()]
	var pending := e.pending()
	_end_turn_button.disabled = e.end_turn_error() != ""
	if pending.get("kind", "") == GameEngine.PENDING_DISCARD:
		_end_turn_button.text = "Discard %d (hand limit %d)" % [pending.count, e.config.hand_limit]
	else:
		_end_turn_button.text = "End turn  (E)"

