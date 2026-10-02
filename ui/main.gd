class_name MainScreen
extends Control
## Main game screen. It holds no game state: it renders Game.engine and forwards player actions.
##
## BoardLayout builds the layout in code; BoardViews keeps the card views (views, keyed by uid) in line with the engine
## (176). Cards in motion live on fx, a layer above the board.
## The components: TopBar, TableauView, ChoiceOverlays, SupplyScreen, GameMenu, the modals (CardDetailsModal,
## TechTreeModal, EventModal, IdentityModal, stacked on a ModalStack, modals), StartScreen, NewGameScreen, SettingsScreen (opened and closed through the Navigator, nav), DragController
## (dragging and targeting) and CardFocus (the keyboard focus on the cards).

## Menu Exit calls this. Tests swap it so pressing Exit doesn't end the test run.
var quit_hook := func(): get_tree().quit()

var views: Dictionary:  # uid -> CardView, kept by BoardViews
	get: return _views.views
var fx: Control  # effects layer: flying, dragged and leaving cards, errors
var tableau: TableauView
var hand: HBoxContainer
var hand_scroll: ScrollContainer
var actions_label: Label  # "Actions: 1 / 2" beside the hand's heading; hidden when actions are unlimited (127)
var choices: ChoiceOverlays
var supply: SupplyScreen
var drag: DragController
var focus: CardFocus
var modals: ModalStack  # the open modals, bottom to top (153)
var details: CardDetailsModal
var start_screen: StartScreen  # the title screen, shown on launch with the board hidden (063, 099)
var new_game_screen: NewGameScreen  # the civilization and seed, from the title screen and the menu's New game (099)
var settings_screen: SettingsScreen  # Reduce motion, from the title screen (099)
var nav := Navigator.new()  # the open start screens, title first (103); empty while a game is on the board
var tech_tree: TechTreeModal
var territory_view: TerritoryView  # one territory in place of the Realm, opened by a click on it (101)
var log_drawer: LogDrawer  # the game log, opened by L or the top bar's Log button (115)
var toasts: Toasts  # notices and the targeting hint under the top bar (116)
var identity_modal: IdentityModal  # the civilization and government, from the top bar's button (119)

var _views: BoardViews  # syncs the card views with the engine (176)
var _board: Control  # the top bar and the play area
var _top_bar: TopBar
var _menu: GameMenu
var _menu_return: CardView  # the card to give the focus back to when the menu closes (null: the Menu button)
var _card_before_menu_button: CardView  # the focused card when the Menu button took the focus
var _relief: ActionButton  # below the Realm while a Famine can be relieved
var _restore: ActionButton  # beside it while Anarchy rules and order can be bought (146)
var _revolt: ActionButton  # beside them whenever you may revolt (148, 155)
var _play_area: VBoxContainer  # the sections, top to bottom: Realm (events, frontier, territories), Hand
var _game_over: GameOverOverlay
var _drawn := {}  # the last event_drawn outcome, shown by the next _refresh unless the game is over (079)
var _event_modal: EventModal
var _palette_day := false  # the palette main's theme was built in (183)


func _ready() -> void:
	_build_layout()
	if not Game.load_errors.is_empty():
		UIKit.message_overlay(self, "Game data has errors — fix data/*.json and restart", Game.load_errors).show()
		return
	Game.engine.changed.connect(_refresh)
	Game.engine.logged.connect(log_drawer.append_log)
	Game.engine.noticed.connect(toasts.notice)
	Game.engine.card_played.connect(_on_card_played)
	Game.engine.event_drawn.connect(func(outcome: Dictionary): _drawn = outcome)
	get_viewport().gui_focus_changed.connect(_on_gui_focus_changed)
	if LaunchOptions.starts_game(Game.launch):  # --civ / --seed on the command line (135)
		start_game(Game.launch.seed, Game.launch.civ)
	else:
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
	log_drawer.clear()
	log_drawer.close()
	supply.close()
	modals.close_all()  # an old game's event, details or tree
	_drawn = {}
	territory_view.reset()
	_views.reset()
	_top_bar.reset_counters()  # a new game's counters show no tags (126, 181)
	Game.new_game(seed_value, civ_id)
	log_drawer.mark_read()  # the new game's own lines
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
	nav.set_root(start_screen.overlay, start_screen.new_game_button, "Main menu")


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
	nav.push(new_game_screen.overlay, new_game_screen.start_button, "New game")


## Hides the board and every screen: the board's cards and any open choice go away.
func _leave_game() -> void:
	nav.clear()
	supply.close()
	modals.close_all()
	_views.reset()
	choices.refresh(null)
	_game_over.overlay.hide()
	_board.hide()


## Test hook (063): whether the board (top bar and play area) is showing.
func board_shown() -> bool:
	return _board.visible


## Test hook (045): the number of card views in the hand row, resting or flying in.
func hand_view_count() -> int:
	return views_in(hand).size()


## Test hook (045): the game-over overlay's text, or "" while it is hidden.
func game_over_text() -> String:
	return _game_over.text()


## Test hook (068): the active events' views as {visible, tooltip, views: [{uid, id, text}]}, views in row order (137:
## they lead the Realm's row); visible while any shows; tooltip is the explanation every event card's tooltip ends with.
func event_panel() -> Dictionary:
	var shown := []
	for view in views_in(tableau.row):
		var event := Game.engine.zone("active_events").find(view.uid)
		if event != null:
			shown.append({"uid": view.uid, "id": event.def.id, "text": view.event_info_text()})
	return {"visible": not shown.is_empty(), "tooltip": TableauView.LEADING_ZONES.active_events, "views": shown}


## Test hook (137): the Relieve button below the Realm (visible or not).
func relieve_button() -> Button:
	return _relief.button


## Test hooks (146, 148): the Restore order and Revolt buttons beside Relieve (visible or not).
func restore_order_button() -> Button:
	return _restore.button


func revolt_button() -> Button:
	return _revolt.button


## Test hook (079): the drawn-event modal on show, {uid, id, text, lasts, summary}; {} while closed.
func event_modal() -> Dictionary:
	return _event_modal.shown()


## Test hook (079): the drawn-event modal's OK button.
func event_modal_ok_button() -> Button:
	return _event_modal.ok_button


## Test hook (119): the top bar's civilization and government button (visible or not).
func identity_button() -> Button:
	return _top_bar.identity_button()


## Test hook (053): the play area's section headings, top to bottom, as {text, tooltip}.
func section_headings() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for section in _play_area.get_children().filter(func(c): return c != territory_view):
		var heading: Label = section.find_children("*", "Label", true, false)[0]  # the hand's shares a row (127)
		out.append({"text": heading.text, "tooltip": heading.tooltip_text})
	return out


## Test hook (067): the menu's buttons, in order.
func menu_buttons() -> Array[Button]:
	return UIKit.buttons_in(_menu.overlay)


## Test hooks (182, 183): the menu's Reduce motion and Day mode keys.
func menu_motion_toggle() -> LegendKey:
	return _menu.motion_toggle


func menu_day_toggle() -> LegendKey:
	return _menu.day_toggle


## Test hook (067): the game-over overlay's buttons, in order.
func game_over_buttons() -> Array[Button]:
	return UIKit.buttons_in(_game_over.overlay)


## The top bar's counter for key (TopBar.counter, 177).
func counter(key: String) -> Control:
	return _top_bar.counter(key)


## The top bar's reading for key (TopBar.counter_text, 177).
func counter_text(key: String) -> String:
	return _top_bar.counter_text(key)


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
	log_drawer.note(bbcode)


## Plays the card (on target_uid) if it's legal; otherwise sends it back with a shake and says why.
func try_play(view: CardView, target_uid := -1) -> void:
	var error := Game.engine.play_error(view.uid, target_uid)
	if error != "":
		_refuse(view, error)
		view.reject()
		return
	Game.engine.play_card(view.uid, target_uid)


## A single click on a board card: a Realm territory opens its view (101), anything else shows its details.
func on_clicked(view: CardView) -> void:
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
	var e := Game.engine
	if drag.dragging != null or e.hand_input_error() != "":
		return
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


## A click on a lit target, or on a card in a choice row: a revealed territory, a card to renew (147) or a government
## (154). A choice goes through its error query, so a pick on a view left over from an earlier choice is refused.
func on_picked(view: CardView) -> void:
	if drag.targeting != null:
		var card := drag.targeting
		drag.end_targeting()
		try_play(card, view.uid)
		return
	var e := Game.engine
	var error: Callable = e.choose_error
	var action: Callable = e.choose
	match e.zone_of(view.uid):
		"governments":
			error = e.choose_government_error
			action = e.choose_government
		"discard":
			error = e.renew_error
			action = e.renew
	var refused: String = error.call(view.uid)
	if refused != "":
		_refuse(view, refused)
	else:
		action.call(view.uid)


## A hand card asks to be dragged: it is, unless a drag is on or hand cards can't be picked up now (175).
func on_drag_requested(view: CardView, grab_offset: Vector2) -> void:
	if drag.targeting != null:
		drag.end_targeting()
	if drag.dragging == null and Game.engine.hand_input_error() == "":
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
	_views.outcome = outcome


## Brings the screen in line with the engine: the top bar, the card views (BoardViews.sync), the overlays and buttons.
func _refresh() -> void:
	var e := Game.engine
	territory_view.close_if_stale(e)
	_top_bar.refresh(e, supply.is_open())
	actions_label.visible = e.actions_per_turn() >= 0
	UIKit.set_stat(actions_label, "Actions: %d / %d" % [e.actions_left(), e.actions_per_turn()])
	_views.sync(e)
	choices.refresh(e)
	log_drawer.refresh(e)
	_relief.refresh(e)
	_restore.refresh(e)
	_revolt.refresh(e)
	identity_modal.refresh(e)
	supply.refresh(e)
	focus.sync()
	_game_over.refresh(e)
	if not _drawn.is_empty():
		if not e.is_over:
			_event_modal.open(_drawn)
		_drawn = {}


# --- Layout ---

## The theme and background, then the board and components (BoardLayout) and the view syncing (BoardViews, 176).
func _build_layout() -> void:
	theme = GameTheme.build()
	_palette_day = Palette.day  # built in the palette as it is now: a Day mode saved before launch isn't a switch (195)
	var bg := ColorRect.new()
	bg.name = "Background"
	UIKit.painted(bg, func(): bg.color = Palette.BACKGROUND)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var layout := BoardLayout.new(self, _restart, _close_menu, _push_new_game_screen)
	_board = layout.board
	_top_bar = layout.top_bar
	_play_area = layout.play_area
	_relief = layout.relief
	_restore = layout.restore
	_revolt = layout.revolt
	_menu = layout.menu
	_game_over = layout.game_over
	_event_modal = layout.event_modal
	_views = BoardViews.new(self, _top_bar)
	territory_view.navigated.connect(func():  # the view carries its cards as it grows or shrinks (105)
		_views.quiet = true
		_refresh()
		_views.quiet = false)
	_apply_settings()
	Settings.changed.connect(_apply_settings)


## Matches the menu's and settings screen's keys and the looping drop-zone pulse to the settings; when Day mode
## changed, rebuilds the theme and repaints everything open in the new palette, the game untouched (183).
func _apply_settings() -> void:
	_menu.show_settings(UIKit.calm(), Palette.day)
	UIKit.show_setting(settings_screen.motion_toggle, UIKit.calm())
	UIKit.show_setting(settings_screen.day_toggle, Palette.day)
	drag.apply_motion(UIKit.calm())
	if _palette_day == Palette.day:
		return
	_palette_day = Palette.day
	theme = GameTheme.build()
	UIKit.repaint(get_tree())
	get_tree().call_group(CardView.GROUP, "restyle")
	if board_shown():
		_refresh()


## Test hook (183): the board's background colour.
func background_color() -> Color:
	return (get_node("Background") as ColorRect).color
