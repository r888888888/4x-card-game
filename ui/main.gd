class_name MainScreen
extends Control
## Main game screen. The layout is built in code so the prototype is easy to
## change. It holds no game state: it renders Game.engine and forwards player actions.
##
## Card views stay alive between refreshes (views, keyed by uid), so they can animate from where
## they were to where the engine now says they are. Cards in motion live on fx, a layer above the
## board; at rest they sit in slot Controls inside the hand, tableau, frontier and choice containers.
## The components: TopBar, TableauView, ChoiceOverlays, SupplyScreen, GameMenu, CardDetailsModal, TechTreeModal,
## StartScreen, NewGameScreen, SettingsScreen (opened and closed through the Navigator, nav), DragController
## (dragging and targeting) and CardFocus (the keyboard focus on the cards).

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
var details: CardDetailsModal
var start_screen: StartScreen  # the title screen, shown on launch with the board hidden (063, 099)
var new_game_screen: NewGameScreen  # the civilization and seed, from the title screen and the menu's New game (099)
var settings_screen: SettingsScreen  # Reduce motion, from the title screen (099)
var nav := Navigator.new()  # the open start screens, title first (103); empty while a game is on the board
var tech_tree: TechTreeModal
var territory_view: TerritoryView  # one territory in place of the Realm, opened by a click on it (101)

var _board: Control  # the top bar and the body (play area and side panel)
var _top_bar: TopBar
var _menu: GameMenu
var _menu_return: CardView  # the card to give the focus back to when the menu closes (null: the Menu button)
var _card_before_menu_button: CardView  # the focused card when the Menu button took the focus
var _row_sections := {}  # zone -> its heading and row (Frontier, Known), hidden while the zone is empty
var _events_section: Control  # the active events' heading and row, hidden when the config has no event deck (068)
var _events_row: HBoxContainer  # the active events, in draw order
var _relieve: Button  # under the events: pays to end the Famine (084), shown while one can be relieved
var _side: SidePanel
var _collapse_all: Button  # on the Realm heading: collapses or expands every territory group (087)
var _play_area: VBoxContainer  # the sections, top to bottom: Realm, Frontier, Known, Events, Hand
var _game_over: GameOverOverlay
var _outcome := {}  # the last card_played outcome, animated by the next _refresh
var _drawn := {}  # the last event_drawn outcome, shown by the next _refresh unless the game is over (079)
var _event_modal: EventModal
var _outcome_point := Vector2.ZERO  # where the played card was when it was played


func _ready() -> void:
	_build_layout()
	if not Game.load_errors.is_empty():
		UIKit.message_overlay(self, "Game data has errors — fix data/*.json and restart", Game.load_errors).show()
		return
	Game.engine.changed.connect(_refresh)
	Game.engine.logged.connect(_side.append_log)
	Game.engine.card_played.connect(_on_card_played)
	Game.engine.event_drawn.connect(func(outcome: Dictionary): _drawn = outcome)
	get_viewport().gui_focus_changed.connect(_on_gui_focus_changed)
	show_title_screen()


## Keyboard play (CardFocus.handle_key). Only reached when no control with focus (a button or the seed field)
## used the key. Nothing here runs while the menu is open.
func _unhandled_key_input(event: InputEvent) -> void:
	if Game.engine != null and event is InputEventKey and event.pressed and not _menu.is_open() and nav.depth() == 0 \
			and focus.handle_key(event as InputEventKey):
		get_viewport().set_input_as_handled()


func _input(event: InputEvent) -> void:
	if _menu.is_open():
		if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			_close_menu()
		return
	if nav.handle_key(event):  # Esc works like Back on the new game and settings screens (099)
		get_viewport().set_input_as_handled()
		return
	if drag.handle_input(event) or (not supply.is_open() and territory_view.handle_key(event)):
		get_viewport().set_input_as_handled()


# --- Actions ---

## Starts a new game with seed_value (a random seed if negative) as civilization civ_id ("" for the config's
## starting one), dropping the old game's views.
func start_game(seed_value: int, civ_id := "") -> void:
	if seed_value < 0:
		seed_value = randi_range(1, 999999)
	nav.clear()
	_board.show()
	_side.clear_log()
	supply.close()
	_event_modal.close()  # an old game's event
	_drawn = {}
	territory_view.reset()
	_reset_views()
	tableau.reset()
	Game.new_game(seed_value, civ_id)
	_menu.set_game(seed_value, _civilization_name())


## Starts again as this game's civilization (Restart, Replay, the game-over New game).
func _restart(seed_value: int) -> void:
	var civ := _civilization_card()
	start_game(seed_value, civ.def.id if civ != null else "")


## The name of the civilization this game is played as, or "".
func _civilization_name() -> String:
	var civ := _civilization_card()
	return civ.def.name if civ != null else ""


func _civilization_card() -> CardInstance:
	return Game.engine.zone("civilization").find(Game.engine.civilization())


## Leaves the current game (if any) for the title screen.
func show_title_screen() -> void:
	_leave_game()
	nav.set_root(start_screen.overlay, start_screen.new_game_button)


## Leaves the current game for the new game screen, over the title screen (the menu's New game).
func show_new_game_screen() -> void:
	show_title_screen()
	_push_new_game_screen()


## Opens the new game screen over the current screen, with the saved civilization preselected.
func _push_new_game_screen() -> void:
	var warnings: Array[String] = []
	var civs := Game.engine.civilizations()
	var preselect := Settings.store.civilization_in(civs, warnings)
	for w in warnings:
		push_warning(w)
	new_game_screen.show_civilizations(Game.engine, civs, preselect)
	nav.push(new_game_screen.overlay, new_game_screen.start_button)


## Hides the board and every screen: the board's cards and any open choice go away.
func _leave_game() -> void:
	nav.clear()
	supply.close()
	details.close()
	_event_modal.close()
	_reset_views()
	choices.refresh(null)
	_game_over.overlay.hide()
	_board.hide()



## Test hook (063): whether the board (top bar, play area, side panel) is showing.
func board_shown() -> bool:
	return _board.visible


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


## The Relieve button: shown while a Famine is active and has a relief price, disabled with the reason it can't pay.
func _refresh_relieve(e: GameEngine) -> void:
	var relief := e.famine_relief()
	_relieve.visible = e.famine_counters() > 0 and not relief.is_empty()
	_relieve.text = "Relieve famine (%s)" % CardFace.cost_text(relief)
	var error := e.relieve_famine_error()
	_relieve.disabled = error != ""
	_relieve.tooltip_text = error if error != "" else "Pay to end the famine now. A later hungry upkeep brings a new one."


## Test hook (079): the drawn-event modal on show, {uid, id, text, lasts, summary}; {} while closed.
func event_modal() -> Dictionary:
	return _event_modal.shown()


## Test hook (079): the drawn-event modal's OK button.
func event_modal_ok_button() -> Button:
	return _event_modal.ok_button


## Test hook (088): the visible civilization and government lines in the side panel, top to bottom, as {text, tooltip}.
func identity_lines() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for line in identity_buttons():
		out.append({"text": line.text, "tooltip": line.tooltip_text})
	return out


## Test hook (088): the visible civilization and government lines, to press.
func identity_buttons() -> Array[Button]:
	return _side.identity_buttons().filter(func(b: Button): return b.visible)


## Test hook (053): the play area's section headings, top to bottom, as {text, tooltip}.
func section_headings() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for section in _play_area.get_children().filter(func(c): return c != territory_view):
		var heading: Label = section.get_child(0)
		out.append({"text": heading.text, "tooltip": heading.tooltip_text})
	return out


## Test hook (067): the menu's buttons, in order.
func menu_buttons() -> Array[Button]:
	return UIKit.buttons_in(_menu.overlay)


## Test hook (067): the game-over overlay's buttons, in order.
func game_over_buttons() -> Array[Button]:
	return UIKit.buttons_in(_game_over.overlay)


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


## A single click on a board card: a Realm territory opens its view (101), anything else shows its details.
func _on_clicked(view: CardView) -> void:
	if not territory_view.is_open() and TerritoryView.is_territory(Game.engine, view.uid):
		territory_view.open(view.uid)
	else:
		details.open(view)


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
	if territory_view.is_open() and e.needs_target(view.uid):
		try_play(view, territory_view.uid)  # onto the territory on view (101)
	elif e.needs_target_choice(view.uid):
		drag.begin_targeting(view)
	else:
		try_play(view)


## Discards a hand card (right-click, D, or double-click while over the hand limit).
func discard(view: CardView) -> void:
	if drag.dragging != null or drag.targeting != null:
		return
	var error := Game.engine.discard_error(view.uid)
	if error != "":
		_refuse(view, error)
		view.reject()
		return
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
		var error := Game.engine.choose_error(view.uid)
		if error != "":
			_refuse(view, error)
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
	territory_view.close_if_stale(e)
	_top_bar.refresh(e)
	var hand_cards := e.zone("hand").cards
	var rows := {"reveal": choices.reveal, "research_reveal": choices.research_row, "active_events": _events_row}
	for zone_name in _row_sections:
		rows[zone_name] = _row_sections[zone_name].get_meta("row")
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
	var viewed := territory_view.card_uids()  # these rest in the territory view instead
	tableau.refresh(e, func(card: CardInstance, row: Container, index: int):
		if not viewed.has(card.uid):
			_place(card, row, index, 0.0))
	territory_view.refresh(e, func(card: CardInstance, row: Container, index: int): _place(card, row, index, 0.0))
	_refresh_collapse_all()
	for zone_name in rows:
		var cards := e.zone(zone_name).cards
		for i in cards.size():
			var card: CardInstance = cards[cards.size() - 1 - i] if zone_name == "reveal" else cards[i]  # reveal: top of the deck first
			_place(card, rows[zone_name], i, 0.0)
	for card in e.zone("research_reveal").cards:
		views[card.uid].set_tech_info(e.tech_cost(card.uid), card.def.cost.wealth, e.tech_passes(card.uid), GameEngine.MAX_PASSES)
	for card in e.zone("active_events").cards:
		views[card.uid].set_event_info(e.event_turns_left(card.uid), e.event_counters(card.uid))
	for zone_name in _row_sections:
		_row_sections[zone_name].visible = not e.zone(zone_name).is_empty()
	choices.refresh(e)
	_side.refresh(e)
	_events_section.visible = _side.event_info.visible  # both only with an event deck
	_refresh_relieve(e)
	supply.refresh(e)
	if not _outcome.is_empty():
		_top_bar.fly_outcome(fx, _outcome, _outcome_point)
		_outcome = {}
	focus.sync()
	_game_over.refresh(e)
	if not _drawn.is_empty():
		if not e.is_over:
			_event_modal.open(_drawn)
		_drawn = {}


## The Collapse all button: shown with a territory group, and says Expand all once every group is collapsed.
func _refresh_collapse_all() -> void:
	_collapse_all.visible = Game.engine.territory_groups().any(func(g): return tableau.has_toggle(g.territory))
	_collapse_all.text = "Expand all" if tableau.all_collapsed() else "Collapse all"


## Makes sure card has a view resting in (or flying to) a slot at index in container.
## Returns true if the card was newly dealt into the hand.
func _place(card: CardInstance, container: Container, index: int, delay: float) -> bool:
	var e := Game.engine
	var in_hand := container == hand
	var error := e.playable_error(card.uid) if in_hand else ""
	var compact := container == _events_row or _row_sections.values().any(func(s): return s.get_meta("row") == container)
	var banner := tableau.is_banner(container)  # a settled territory, drawn as its group's title bar (087)
	var view: CardView = views.get(card.uid)
	if view == null:
		view = CardView.new()
		view.setup(card, e.card_db, in_hand, error, compact, banner)
		view.set_pickable(choices.is_choice_row(container), choices.pick_hint(container))
		view.drag_requested.connect(_on_drag_requested)
		view.double_clicked.connect(on_double_clicked)
		view.discard_requested.connect(discard)
		view.picked.connect(on_picked)
		view.details_requested.connect(_on_clicked)
		views[card.uid] = view
		var slot := _new_slot(view, container, index)
		if in_hand:
			view.deal(slot, fx, _top_bar.pile_point(0.25), delay)
		else:
			view.pop_in(slot)
		return in_hand
	if view.slot.get_parent() != container:
		if view == drag.dragging:
			drag.end_drag()
		var old_slot := view.slot
		view.setup(card, e.card_db, in_hand, error, compact, banner)
		view.set_pickable(choices.is_choice_row(container), choices.pick_hint(container))
		view.fly_to_slot(_new_slot(view, container, index), fx)
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
	var trashed := Game.engine.zone("trashed").find(uid) != null
	view.leave(fx, _leave_point(uid, view), just_played or trashed, via)
	_free_slot(old_slot)


## Where a card that left the board flies: the deck or discard counter, the event counts, for a territory
## put back in the territory deck the edge of the choice panel, or up off the table for a trashed card.
func _leave_point(uid: int, view: CardView) -> Vector2:
	var e := Game.engine
	if e.zone("trashed").find(uid) != null:
		return view.get_global_rect().get_center() - Vector2(0, view.size.y)
	if e.zone("territory_deck").find(uid) != null:
		return choices.explore_exit_point()
	if e.zone("deck").find(uid) != null:
		return _top_bar.pile_point(0.25)
	if e.zone("government").find(uid) != null:
		return _side.identity_point("government")
	if e.zone("event_discard").find(uid) != null:
		return _side.event_info.get_global_rect().get_center()
	return _top_bar.pile_point(0.75)


## A slot for view at index in container, already the size view rests at, so the row doesn't change height
## when a flying card lands (075).
func _new_slot(view: CardView, container: Container, index: int) -> Control:
	var slot := Control.new()
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.custom_minimum_size = view.slot_size()
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
	_board = margin

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

	_play_area = VBoxContainer.new()
	_play_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_play_area.add_theme_constant_override("separation", UIKit.SECTION_GAP)
	body.add_child(_play_area)

	var realm_section := UIKit.section(_play_area, "Realm")
	realm_section.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tableau = TableauView.new()
	tableau.collapse_changed.connect(_refresh)
	realm_section.add_child(tableau)
	# Collapse all / Expand all (087), at the right end of the Realm heading so it takes no extra row.
	_collapse_all = UIKit.button("Collapse all", func(): tableau.set_all_collapsed(not tableau.all_collapsed()))
	_collapse_all.tooltip_text = "Show each territory as its territory card and a summary of what's built on it."
	_collapse_all.add_theme_font_size_override("font_size", 17)
	_collapse_all.anchor_left = 1.0  # pinned to the heading's right end, growing left
	_collapse_all.anchor_right = 1.0
	_collapse_all.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_collapse_all.grow_vertical = Control.GROW_DIRECTION_BOTH
	_collapse_all.anchor_top = 0.5
	_collapse_all.anchor_bottom = 0.5
	realm_section.get_child(0).add_child(_collapse_all)
	territory_view = TerritoryView.new(self, realm_section)
	territory_view.navigated.connect(_refresh)
	_row_sections.frontier = UIKit.card_row_section(_play_area, "Frontier",
		"Territories discovered, not yet settled. Play a city card on one to settle it.")
	frontier = _row_sections.frontier.get_meta("row")
	_row_sections.researched = UIKit.card_row_section(_play_area, "Known")
	_events_section = UIKit.card_row_section(_play_area, "Events")
	_events_row = _events_section.get_meta("row")
	_relieve = UIKit.button("", func(): Game.engine.relieve_famine())
	_relieve.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_events_section.add_child(_relieve)

	var hand_section := UIKit.section(_play_area, "Hand — drag a card into the realm, double-click it, or ←/→ then Enter. Right-click or D discards.")
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

	_side = SidePanel.new(func(): tech_tree.open(), func(card_id: String): details.open_def(card_id))
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

	_game_over = GameOverOverlay.new(self, func(): _restart(Game.engine.seed_value), func(): _restart(-1))

	_menu = GameMenu.new(self)
	_menu.start_requested.connect(func(seed_value: int):
		_close_menu(false)
		_restart(seed_value))
	_menu.new_game_requested.connect(func():
		_close_menu(false)
		show_new_game_screen())
	_menu.close_requested.connect(_close_menu)
	_menu.exit_requested.connect(func(): quit_hook.call())
	tech_tree = TechTreeModal.new(self)  # before details, which opens over it and takes the keys first
	_event_modal = EventModal.new(self)  # before details, so a details modal opened from it takes the keys first
	details = CardDetailsModal.new(self)
	start_screen = StartScreen.new(self)
	start_screen.new_game_requested.connect(_push_new_game_screen)
	start_screen.settings_requested.connect(func(): nav.push(settings_screen.overlay, settings_screen.back_button))
	start_screen.exit_requested.connect(func(): quit_hook.call())
	new_game_screen = NewGameScreen.new(self, details.open)
	new_game_screen.start_requested.connect(func(seed_value: int): start_game(seed_value, new_game_screen.selected))
	new_game_screen.back_requested.connect(nav.back)
	settings_screen = SettingsScreen.new(self)
	settings_screen.back_requested.connect(nav.back)
	_apply_motion_setting()
	Settings.changed.connect(_apply_motion_setting)


## Matches the menu's and settings screen's toggles and the looping drop-zone pulse to the reduce motion setting.
func _apply_motion_setting() -> void:
	_menu.show_motion_setting(UIKit.calm())
	UIKit.show_motion(settings_screen.motion_toggle, UIKit.calm())
	drag.apply_motion(UIKit.calm())
