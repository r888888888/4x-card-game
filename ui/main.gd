extends Control
## Main game screen. The layout is built in code so the prototype is easy to
## change. It holds no game state: it renders Game.engine and forwards clicks.

var _turn_label: Label
var _food_label: Label
var _score_label: Label
var _piles_label: Label
var _seed_edit: LineEdit
var _tableau: HFlowContainer
var _hand: HBoxContainer
var _log: RichTextLabel
var _end_turn_button: Button
var _game_over_overlay: Control
var _game_over_label: Label


func _ready() -> void:
	_build_layout()
	if not Game.load_errors.is_empty():
		_show_load_errors(Game.load_errors)
		return
	Game.engine.changed.connect(_refresh)
	Game.engine.logged.connect(_append_log)
	_start_game(-1)


func _unhandled_key_input(event: InputEvent) -> void:
	# Enter/Space ends the turn (unless a text field has focus).
	if event.is_action_pressed("ui_accept") and Game.engine != null and not Game.engine.is_over:
		Game.engine.end_turn()


# --- Actions ---

func _start_game(seed_value: int) -> void:
	if seed_value < 0:
		seed_value = randi_range(1, 999999)
	_seed_edit.text = str(seed_value)
	_log.clear()
	Game.new_game(seed_value)


func _on_restart_pressed() -> void:
	var text := _seed_edit.text.strip_edges()
	_start_game(text.to_int() if text.is_valid_int() else -1)


func _on_card_clicked(uid: int) -> void:
	var error := Game.engine.play_error(uid)
	if error != "":
		_log.append_text("[color=#e88]%s[/color]\n" % error)
		return
	Game.engine.play_card(uid)


# --- Rendering ---

func _refresh() -> void:
	var e := Game.engine
	_turn_label.text = "Turn %d / %d" % [e.turn, e.turn_limit()]
	_food_label.text = "Food: %d" % e.resources.get("food", 0)
	_score_label.text = "Score: %d" % e.score()
	_piles_label.text = "Deck %d  ·  Discard %d" % [e.zone("deck").size(), e.zone("discard").size()]

	_clear(_tableau)
	for card in e.zone("tableau").cards:
		var view := CardView.new()
		view.setup(card, e.card_db, false)
		_tableau.add_child(view)

	_clear(_hand)
	for card in e.zone("hand").cards:
		var view := CardView.new()
		view.setup(card, e.card_db, true, e.play_error(card.uid))
		view.clicked.connect(_on_card_clicked)
		_hand.add_child(view)

	_end_turn_button.disabled = e.is_over
	_game_over_overlay.visible = e.is_over
	if e.is_over:
		_game_over_label.text = "Game over\n\nFinal score: %d\nSeed: %d" % [e.score(), e.seed_value]


func _append_log(message: String) -> void:
	if message.begins_with("—"):
		_log.append_text("\n[b]%s[/b]\n" % message)
	elif message.begins_with("Game over"):
		_log.append_text("[b][color=#e8c547]%s[/color][/b]\n" % message)
	else:
		_log.append_text(message + "\n")


func _show_load_errors(errors: Array[String]) -> void:
	var overlay := _overlay()
	var box := overlay.get_meta("box") as VBoxContainer
	box.add_child(_heading("Game data has errors — fix data/*.json and restart"))
	var text := RichTextLabel.new()
	text.custom_minimum_size = Vector2(800, 400)
	text.text = "\n".join(PackedStringArray(errors))
	box.add_child(text)
	overlay.visible = true


# --- Layout ---

func _build_layout() -> void:
	# Default text size for everything without an explicit override (log, buttons, inputs).
	theme = Theme.new()
	theme.default_font_size = 20

	var bg := ColorRect.new()
	bg.color = Color("1d2126")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 18)
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	margin.add_child(root)

	# Top bar: stats + seed controls.
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 36)
	root.add_child(bar)
	_turn_label = _stat(bar)
	_food_label = _stat(bar, Color("ffd966"))
	_score_label = _stat(bar, Color("ffd966"))
	_piles_label = _stat(bar, Color("c3cad3"))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(spacer)
	var seed_label := Label.new()
	seed_label.text = "Seed"
	bar.add_child(seed_label)
	_seed_edit = LineEdit.new()
	_seed_edit.custom_minimum_size.x = 130
	_seed_edit.tooltip_text = "Restart replays this seed (same shuffle)."
	bar.add_child(_seed_edit)
	bar.add_child(_button("Restart", _on_restart_pressed))
	bar.add_child(_button("New game", func(): _start_game(-1)))

	# Body: play area on the left, log + end turn on the right.
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 14)
	root.add_child(body)

	var play_area := VBoxContainer.new()
	play_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(play_area)
	play_area.add_child(_heading("Tableau"))
	var tableau_scroll := ScrollContainer.new()
	tableau_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tableau_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	play_area.add_child(tableau_scroll)
	_tableau = HFlowContainer.new()
	_tableau.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tableau.add_theme_constant_override("h_separation", 10)
	_tableau.add_theme_constant_override("v_separation", 10)
	tableau_scroll.add_child(_tableau)
	play_area.add_child(_heading("Hand — click a card to play it"))
	var hand_scroll := ScrollContainer.new()
	hand_scroll.custom_minimum_size.y = CardView.HAND_SIZE.y + 20
	hand_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	play_area.add_child(hand_scroll)
	_hand = HBoxContainer.new()
	_hand.add_theme_constant_override("separation", 12)
	hand_scroll.add_child(_hand)

	var side_col := VBoxContainer.new()
	side_col.custom_minimum_size.x = 400
	body.add_child(side_col)
	side_col.add_child(_heading("Log"))
	_log = RichTextLabel.new()
	_log.bbcode_enabled = true
	_log.scroll_following = true
	_log.selection_enabled = true
	_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_log.add_theme_font_size_override("normal_font_size", 19)
	_log.add_theme_font_size_override("bold_font_size", 20)
	_log.add_theme_color_override("default_color", Color("dde3ea"))
	side_col.add_child(_log)
	_end_turn_button = _button("End turn  (Enter)", func(): Game.engine.end_turn())
	_end_turn_button.custom_minimum_size.y = 60
	_end_turn_button.add_theme_font_size_override("font_size", 24)
	side_col.add_child(_end_turn_button)

	# Game-over overlay.
	_game_over_overlay = _overlay()
	var box := _game_over_overlay.get_meta("box") as VBoxContainer
	_game_over_label = _heading("")
	_game_over_label.add_theme_font_size_override("font_size", 32)
	_game_over_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_game_over_label)
	box.add_child(_button("Replay this seed", _on_restart_pressed))
	box.add_child(_button("New game", func(): _start_game(-1)))


## Full-screen dimmer with a centered panel. The panel's VBox is stored as meta "box".
func _overlay() -> Control:
	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.65)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.visible = false
	add_child(overlay)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	var panel := PanelContainer.new()
	center.add_child(panel)
	var pad := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, 24)
	panel.add_child(pad)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	pad.add_child(box)
	overlay.set_meta("box", box)
	return overlay


func _stat(parent: Control, color := Color.WHITE) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", 26)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label


func _heading(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 19)
	label.add_theme_color_override("font_color", Color("b4bcc6"))
	return label


func _button(text: String, on_pressed: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE  # so Enter always means "end turn"
	button.pressed.connect(on_pressed)
	return button


func _clear(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()
