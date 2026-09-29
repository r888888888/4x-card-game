class_name MainScreen
extends Control
## Main game screen. The layout is built in code so the prototype is easy to
## change. It holds no game state: it renders Game.engine and forwards player actions.
##
## Card views stay alive between refreshes (views, keyed by uid), so they can animate from where
## they were to where the engine now says they are. Cards in motion live on fx, a layer above the
## board; at rest they sit in slot Controls inside the hand, tableau, frontier and choice containers.
## The components: TopBar, TableauView, ChoiceOverlays, SupplyScreen, GameMenu, DragController (dragging and
## targeting) and CardFocus (the keyboard focus on the cards).

## Menu Exit calls this. Tests swap it so pressing Exit doesn't end the test run.
var quit_hook := func(): get_tree().quit()

var views := {}  # uid -> CardView
var fx: Control  # effects layer: flying, dragged and leaving cards, resource tokens, errors
var tableau: TableauView
var frontier: HBoxContainer  # discovered, unsettled territories
var hand: HBoxContainer
var hand_scroll: ScrollContainer
var choices: ChoiceOverlays
var supply: SupplyScreen
var drag: DragController
var focus: CardFocus

var _top_bar: TopBar
var _menu: GameMenu
var _menu_return: CardView  # the card to give the focus back to when the menu closes (null: the Menu button)
var _card_before_menu_button: CardView  # the focused card when the Menu button took the focus
var _frontier_section: Control  # the frontier's heading and row, hidden while it is empty
var _researched_section: Control  # the researched techs' heading and row, hidden while it is empty
var _researched: HBoxContainer
var _events_section: Control  # the active events' heading and row, hidden when the config has no event deck (068)
var _events_row: HBoxContainer  # the active events, in draw order
var _side: SidePanel
var _game_over: GameOverOverlay
var _outcome := {}  # the last card_played outcome, animated by the next _refresh
var _outcome_point := Vector2.ZERO  # where the played card was when it was played


func _ready() -> void:
	_build_layout()
	if not Game.load_errors.is_empty():
		UIKit.message_overlay(self, "Game data has errors — fix data/*.json and restart", Game.load_errors).show()
		return
	Game.engine.changed.connect(_refresh)
	Game.engine.logged.connect(_side.append_log)
	Game.engine.card_played.connect(_on_card_played)
	get_viewport().gui_focus_changed.connect(_on_gui_focus_changed)
	start_game(-1)


## Keyboard play (CardFocus.handle_key). Only reached when no control with focus (a button or the seed field)
## used the key. Nothing here runs while the menu is open.
func _unhandled_key_input(event: InputEvent) -> void:
	if Game.engine != null and event is InputEventKey and event.pressed and not _menu.is_open() and focus.handle_key(event as InputEventKey):
		get_viewport().set_input_as_handled()


func _input(event: InputEvent) -> void:
	if _menu.is_open():
		if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			_close_menu()
		return
	if drag.handle_input(event):
		get_viewport().set_input_as_handled()


# --- Actions ---

## Starts a new game with seed_value (a random seed if negative), dropping the old game's views.
func start_game(seed_value: int) -> void:
	if seed_value < 0:
		seed_value = randi_range(1, 999999)
	_menu.set_seed(seed_value)
	_side.clear_log()
	supply.close()
	_reset_views()
	Game.new_game(seed_value)


## Test hook (045): the number of card views in the hand row, resting or flying in.
func hand_view_count() -> int:
	return views_in(hand).size()


## Test hook (045): the game-over overlay's text, or "" while it is hidden.
func game_over_text() -> String:
	return _game_over.text()


## Test hook (068): the event panel as {visible, info, tooltip, views: [{uid, id, text}]}, views in row order.
func event_panel() -> Dictionary:
	var shown := []
	for view in views_in(_events_row):
		shown.append({"uid": view.uid, "id": Game.engine.zone("active_events").find(view.uid).def.id, "text": view.event_info_text()})
	var info := _side.event_info
	return {"visible": _events_section.visible, "info": info.text, "tooltip": info.tooltip_text, "views": shown}


## Test hook (067): the menu's buttons, in order.
func menu_buttons() -> Array[Button]:
	return _buttons_in(_menu.overlay)


## Test hook (067): the game-over overlay's buttons, in order.
func game_over_buttons() -> Array[Button]:
	return _buttons_in(_game_over.overlay)


func _buttons_in(overlay: Control) -> Array[Button]:
	var buttons: Array[Button] = []
	buttons.assign(overlay.find_children("*", "Button", true, false))
	return buttons


## The kind of decision the engine is waiting for (GameEngine.PENDING_*), or "".
func pending_kind() -> String:
	return Game.engine.pending().get("kind", "")


## The views resting in (or flying to) container's slots, in slot order.
func views_in(container: Container) -> Array[CardView]:
	var out: Array[CardView] = []
	for slot in container.get_children():
		for uid in views:
			if views[uid].slot == slot:
				out.append(views[uid])
	return out


## Adds a line of BBCode to the log.
func log_note(bbcode: String) -> void:
	_side.note(bbcode)


## Plays the card (on target_uid) if it's legal; otherwise sends it back with a shake and says why.
func try_play(view: CardView, target_uid := -1) -> void:
	var error := Game.engine.play_error(view.uid, target_uid)
	if error != "":
		_refuse(view, error)
		view.reject()
		return
	Game.engine.play_card(view.uid, target_uid)


## Logs the engine's refusal and shows it over view.
func _refuse(view: CardView, error: String) -> void:
	log_note("[color=#e88]%s[/color]" % error)
	UIKit.show_error(fx, view, error, size.x)


func on_double_clicked(view: CardView) -> void:
	if drag.targeting != null:
		drag.end_targeting()
	if drag.dragging != null or pending_kind() == GameEngine.PENDING_EXPLORE:
		return
	var e := Game.engine
	if pending_kind() == GameEngine.PENDING_DISCARD:
		discard(view)
		return
	if e.needs_target(view.uid) and e.valid_targets(view.uid).size() > 1 and e.playable_error(view.uid) == "":
		drag.begin_targeting(view)
	else:
		try_play(view)


## Discards a hand card (right-click, D, or double-click while over the hand limit).
func discard(view: CardView) -> void:
	if drag.dragging == null and drag.targeting == null:
		Game.engine.discard_card(view.uid)


## A click on a lit target, a revealed tech or a revealed territory.
func on_picked(view: CardView) -> void:
	if drag.targeting != null:
		var card := drag.targeting
		drag.end_targeting()
		try_play(card, view.uid)
	elif pending_kind() == GameEngine.PENDING_RESEARCH:
		var error := Game.engine.buy_tech_error(view.uid)
		if error != "":
			_refuse(view, error)
		else:
			Game.engine.buy_tech(view.uid)
	else:
		Game.engine.choose(view.uid)


func _on_drag_requested(view: CardView, grab_offset: Vector2) -> void:
	if drag.targeting != null:
		drag.end_targeting()
	if drag.dragging == null and not Game.engine.is_over and pending_kind() != GameEngine.PENDING_EXPLORE:
		drag.begin_drag(view, grab_offset)


func open_supply() -> void:
	if not supply.can_open(Game.engine) or drag.dragging != null:
		return
	drag.end_targeting()
	focus.clear()
	supply.open(Game.engine)


# --- Menu ---

## Opens the menu over the board, with the seed field focused and holding this game's seed.
## Targeting is cancelled; the card that had the focus gets it back on close.
func open_menu() -> void:
	if drag.dragging != null:
		return
	_menu_return = focus.focused if focus.focused != null else _card_before_menu_button
	drag.end_targeting()
	focus.set_card(null)
	_menu.open(Game.engine.seed_value)


## Closes the menu. give_back: return the focus to the card that had it, else to the Menu button.
func _close_menu(give_back := true) -> void:
	_menu.hide()
	get_viewport().gui_release_focus()
	var card := _menu_return
	_menu_return = null
	if not give_back:
		return
	if is_instance_valid(card) and focus.row().has(card):
		focus.set_card(card)
	else:
		_top_bar.menu_button.grab_focus()


## Menu Restart: the seed in the field, or a random one if it isn't a whole number.
func _on_restart_requested(seed_text: String) -> void:
	var text := seed_text.strip_edges()
	_close_menu(false)
	start_game(text.to_int() if text.is_valid_int() else -1)


## A button or field took the focus: the card focus goes. Remembers the card if it was the Menu
## button (clicking it moves the focus before it is pressed).
func _on_gui_focus_changed(control: Control) -> void:
	_card_before_menu_button = focus.focused if control == _top_bar.menu_button else null
	focus.set_card(null)


# --- Rendering ---

func _on_card_played(outcome: Dictionary) -> void:
	_outcome = outcome
	var view: CardView = views.get(outcome.uid)
	_outcome_point = view.get_global_rect().get_center() if view != null else size / 2


## Brings the views in line with the engine: new cards are dealt in from the deck or pop into place,
## cards that changed zone fly to their new place, and cards that left fly towards where they went.
func _refresh() -> void:
	var e := Game.engine
	_top_bar.refresh(e)
	var hand_cards := e.zone("hand").cards
	var rows := {"frontier": frontier, "reveal": choices.reveal, "research_reveal": choices.research_row,
		"researched": _researched, "active_events": _events_row}
	var shown := {}
	for zone_name in ["hand", "tableau"] + rows.keys():
		for card in e.zone(zone_name).cards:
			shown[card.uid] = true
	for uid in views.keys():
		if not shown.has(uid):
			_remove_view(uid)
	var dealt := 0
	for i in hand_cards.size():
		if _place(hand_cards[i], hand, i, 0.0 if UIKit.calm() else dealt * Anim.DEAL_STAGGER):
			dealt += 1
	tableau.refresh(e, func(card: CardInstance, row: HBoxContainer, index: int): _place(card, row, index, 0.0))
	for zone_name in rows:
		var cards := e.zone(zone_name).cards
		for i in cards.size():
			var card: CardInstance = cards[cards.size() - 1 - i] if zone_name == "reveal" else cards[i]  # reveal: top of the deck first
			_place(card, rows[zone_name], i, 0.0)
	for card in e.zone("research_reveal").cards:
		views[card.uid].set_tech_info(e.tech_cost(card.uid), card.def.cost.wealth, e.tech_passes(card.uid), GameEngine.MAX_PASSES)
	for card in e.zone("active_events").cards:
		views[card.uid].set_event_info(e.event_turns_left(card.uid))
	_frontier_section.visible = not e.zone("frontier").is_empty()
	_researched_section.visible = not e.zone("researched").is_empty()
	choices.refresh(pending_kind())
	_side.refresh(e)
	_events_section.visible = _side.event_info.visible
	supply.refresh(e)
	if not _outcome.is_empty():
		_top_bar.fly_outcome(fx, _outcome, _outcome_point)
		_outcome = {}
	focus.sync()
	_game_over.refresh(e)


## Makes sure card has a view resting in (or flying to) a slot at index in container.
## Returns true if the card was newly dealt into the hand.
func _place(card: CardInstance, container: Container, index: int, delay: float) -> bool:
	var e := Game.engine
	var in_hand := container == hand
	var error := e.playable_error(card.uid) if in_hand else ""
	var compact := container == frontier or container == _researched or container == _events_row
	var view: CardView = views.get(card.uid)
	if view == null:
		view = CardView.new()
		view.setup(card, e.card_db, in_hand, error, compact)
		view.set_pickable(choices.is_choice_row(container), choices.pick_hint(container))
		view.drag_requested.connect(_on_drag_requested)
		view.double_clicked.connect(on_double_clicked)
		view.discard_requested.connect(discard)
		view.picked.connect(on_picked)
		views[card.uid] = view
		var slot := _new_slot(in_hand, container, index)
		if in_hand:
			view.deal(slot, fx, _top_bar.pile_point(0.25), delay)
		else:
			view.pop_in(slot)
		return in_hand
	if view.slot.get_parent() != container:
		if view == drag.dragging:
			drag.end_drag()
		var old_slot := view.slot
		view.setup(card, e.card_db, in_hand, error, compact)
		view.set_pickable(choices.is_choice_row(container), choices.pick_hint(container))
		view.fly_to_slot(_new_slot(in_hand, container, index), fx)
		_free_slot(old_slot)
		return false
	container.move_child(view.slot, index)
	if in_hand:
		view.set_play_error(error)
	else:
		view.set_idle(e.is_idle(card.uid))
	return false


## The card is no longer shown: it flies towards the zone it went to and fades (popping first if it
## was just played, so the player sees it resolve).
func _remove_view(uid: int) -> void:
	var view: CardView = views[uid]
	views.erase(uid)
	if view == drag.dragging:
		drag.end_drag()
	if view == drag.targeting:
		drag.end_targeting()
	var old_slot := view.slot
	var just_played: bool = not _outcome.is_empty() and _outcome.uid == uid
	var via: Variant = null
	if just_played and views.has(_outcome.target):  # fly to where it was played, e.g. the settled territory
		via = (views[_outcome.target] as CardView).get_global_rect().get_center()
	view.leave(fx, _leave_point(uid), just_played, via)
	_free_slot(old_slot)


## Where a card that left the board flies: the deck or discard counter, the event counts, or for a territory
## put back in the territory deck, the edge of the choice panel.
func _leave_point(uid: int) -> Vector2:
	var e := Game.engine
	if e.zone("territory_deck").find(uid) != null:
		return choices.explore_exit_point()
	if e.zone("deck").find(uid) != null:
		return _top_bar.pile_point(0.25)
	if e.zone("event_discard").find(uid) != null:
		return _side.event_info.get_global_rect().get_center()
	return _top_bar.pile_point(0.75)


func _new_slot(in_hand: bool, container: Container, index: int) -> Control:
	var slot := Control.new()
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.custom_minimum_size = CardView.HAND_SIZE + Vector2(0, Anim.LIFT_ROOM) if in_hand else CardView.TABLEAU_SIZE
	container.add_child(slot)
	container.move_child(slot, index)
	return slot


## Removes a slot now (so the container relayouts this frame) and frees it.
func _free_slot(slot: Control) -> void:
	if is_instance_valid(slot):
		slot.get_parent().remove_child(slot)
		slot.queue_free()


## Drops every view without animating (new game or restart).
func _reset_views() -> void:
	if drag.dragging != null:
		drag.end_drag()
	drag.end_targeting()
	for uid in views:
		var view: CardView = views[uid]
		_free_slot(view.slot)
		view.queue_free()
	views.clear()
	focus.focused = null
	_outcome = {}
	for child in fx.get_children():
		if not drag.owns(child):
			child.queue_free()


# --- Layout ---

func _build_layout() -> void:
	# Default text size for everything without an explicit override (log, buttons, inputs).
	theme = Theme.new()
	theme.default_font_size = 20
	UIKit.style_controls(theme)

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
	_top_bar = TopBar.new(open_menu)
	root.add_child(_top_bar)

	# Body: play area on the left, log + end turn on the right.
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 14)
	root.add_child(body)

	var play_area := VBoxContainer.new()
	play_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	play_area.add_theme_constant_override("separation", UIKit.SECTION_GAP)
	body.add_child(play_area)

	_frontier_section = UIKit.card_row_section(play_area, "Frontier — discovered, not yet settled")
	frontier = _frontier_section.get_meta("row")
	var tableau_section := UIKit.section(play_area, "Tableau")
	tableau_section.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tableau = TableauView.new()
	tableau_section.add_child(tableau)
	_researched_section = UIKit.card_row_section(play_area, "Researched")
	_researched = _researched_section.get_meta("row")
	_events_section = UIKit.card_row_section(play_area, "Events")
	_events_row = _events_section.get_meta("row")

	var hand_section := UIKit.section(play_area, "Hand — drag a card into the tableau, double-click it, or ←/→ then Enter. Right-click or D discards.")
	hand_scroll = ScrollContainer.new()
	hand_scroll.custom_minimum_size.y = CardView.HAND_SIZE.y + Anim.LIFT_ROOM + 20
	hand_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	hand_section.add_child(hand_scroll)
	var hand_pad := MarginContainer.new()
	hand_pad.add_theme_constant_override("margin_left", int(Anim.HAND_SIDE_ROOM))
	hand_pad.add_theme_constant_override("margin_right", int(Anim.HAND_SIDE_ROOM))
	hand_scroll.add_child(hand_pad)
	hand = HBoxContainer.new()
	hand.add_theme_constant_override("separation", 12)
	hand_pad.add_child(hand)

	_side = SidePanel.new()
	body.add_child(_side)

	# Effects layer, above the board and below the overlays.
	fx = Control.new()
	fx.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fx)
	drag = DragController.new(self)
	focus = CardFocus.new(self)
	choices = ChoiceOverlays.new(self)
	supply = SupplyScreen.new(self, open_supply)
	supply.refused.connect(func(message: String): log_note("[color=#e88]%s[/color]" % message))
	supply.closed.connect(func(): focus.clear())
	_side.add_supply_button(supply.button)

	_game_over = GameOverOverlay.new(self, func(): start_game(Game.engine.seed_value), func(): start_game(-1))

	_menu = GameMenu.new(self)
	_menu.restart_requested.connect(_on_restart_requested)
	_menu.new_game_requested.connect(func():
		_close_menu(false)
		start_game(-1))
	_menu.close_requested.connect(_close_menu)
	_menu.exit_requested.connect(func(): quit_hook.call())
	_apply_motion_setting()
	Settings.changed.connect(_apply_motion_setting)


## Matches the menu's toggle and the looping drop-zone pulse to the reduce motion setting.
func _apply_motion_setting() -> void:
	_menu.show_motion_setting(UIKit.calm())
	drag.apply_motion(UIKit.calm())
