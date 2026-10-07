class_name MainScreen
extends Control
## Main game screen. It holds no game state: it renders Game.engine and forwards player actions.
##
## BoardLayout builds the layout in code; BoardViews keeps the card views (views, keyed by uid) in line with the engine
## (176). Cards in motion live on fx, a layer above the board.
## The components: TopBar, Sidebar, TableauView, ChoiceOverlays, SupplyScreen, the modals (GameMenu, CardDetailsModal,
## TurnNews's EventModal and RaidModal, IdentityModal, SettingsModal, GameOverOverlay, stacked on a ModalStack, modals),
## StartScreen and NewGameScreen (opened and closed through the Navigator, nav), DragController (dragging and
## targeting) and CardFocus (the keyboard focus on the cards).

## Menu Exit calls this. Tests swap it so pressing Exit doesn't end the test run.
var quit_hook := func(): get_tree().quit()

var views: Dictionary:  # uid -> CardView, kept by BoardViews
	get: return _views.views
var fx: Control  # effects layer: flying, dragged and leaving cards, errors
var tableau: TableauView
var hand: HBoxContainer
var hand_scroll: SmoothScroll
var actions_label: Label  # "1 / 2" right on the hand's heading line (204); hidden when actions are unlimited (127)
var choices: ChoiceOverlays
var supply: SupplyScreen
var drag: DragController
var focus: CardFocus
var card_actions: CardActions  # what the player does with a card view: play, click, discard, pick, drag (316)
var modals: ModalStack  # the open modals, bottom to top (153)
var sfx: Sfx  # every sound the UI makes (186)
var key_sounds: KeySounds  # every button's click (187)
var details: CardDetailsModal
var start_screen: StartScreen  # the title screen, shown on launch with the board hidden (063, 099)
var new_game_screen: NewGameScreen  # the civilization and seed, from the title screen and the menu's New game (099)
var revolt_modal: RevoltModal  # the revolution's confirmation, over the civilization modal (205)
var move_modal: MoveModal  # where a unit marches, from its details' Move… (163)
var renewal_modal: RenewalModal  # Anarchy's renewal, open while it is owed (255)
var rename_modal: RenameModal  # names a territory, from the territory view's Rename… (248)
var build_modal: BuildModal  # builds and recruits on a territory, from its view's Build… or a free slot (297)
var settings_modal: SettingsModal  # the settings, from the menu and the title screen (206)
var nav := Navigator.new()  # the open start screens, title first (103); empty while a game is on the board
var knowledge: KnowledgeScreen  # the techs by era, a screen over the Realm (208)
var territory_view: TerritoryView  # one territory in place of the Realm, opened by a click on it (101)
var log_drawer: LogDrawer  # the game log, opened by L or the top bar's Log button (115)
var toasts: Toasts  # notices and the targeting hint, as flags out of the rail (116, 250)
var identity_modal: IdentityModal  # the civilization and government, from the sidebar (119, 202)
var sidebar: Sidebar  # the right rail: the civilization and government (202)
var vellum: Vellum  # over the play area while a card waits for one of several targets (210)
var era_sheet: EraSheet  # the era ceremony, over everything (211)
var doors: CabinetDoors  # shut over the board while the government choice comes and goes (209)
var board: Control  # the top bar and the play area
var top_bar: TopBar  # the turn plate, the resource counters and the bar's keys (177, 201)
var menu: GameMenu  # the game menu, from the Menu key or Esc (067)
var relief: ActionButton  # below the Realm while a Famine can be relieved
var restore: ActionButton  # beside it while Anarchy rules and order can be bought (146)
var play_area: VBoxContainer  # the sections, top to bottom: Realm (events, frontier, territories), Hand
var game_over: GameOverOverlay  # the end of the game's sheet (045)
var news: TurnNews  # the turn start's event and raid, shown by the next _refresh (079, 271)

var _views: BoardViews  # syncs the card views with the engine (176)
var _card_before_menu_button: CardView  # the focused card when the Menu button took the focus
var _palette_day := false  # the palette main's theme was built in (183)


func _ready() -> void:
	_build_layout()
	add_child(FocusRing.new())  # last: it sees each key and click before the modals (230)
	if not Game.load_errors.is_empty():
		UIKit.message_overlay(self, "Game data has errors — fix data/*.json and restart", Game.load_errors).show()
		return
	Game.engine.changed.connect(_refresh)
	Game.engine.logged.connect(log_drawer.append_log)
	Game.engine.noticed.connect(toasts.notice)
	Game.engine.card_played.connect(_on_card_played)
	Game.engine.built.connect(_views.note_built)  # the build ceremony (357)
	news.listen(Game.engine, toasts.notice)
	get_viewport().gui_focus_changed.connect(_on_gui_focus_changed)
	if LaunchOptions.starts_game(Game.launch):  # --civ / --seed on the command line (135)
		start_game(Game.launch.seed, Game.launch.civ)
	else:
		show_title_screen()


## Keyboard play (CardFocus.handle_key). Only reached when no control with focus (a button or the seed field)
## used the key. Nothing here runs while a modal (the menu among them) is open.
func _unhandled_key_input(event: InputEvent) -> void:
	if Game.engine != null and event is InputEventKey and event.pressed and not modals.is_open() and nav.depth() == 0 \
			and focus.handle_key(event as InputEventKey):
		get_viewport().set_input_as_handled()


func _input(event: InputEvent) -> void:
	if doors.moving() and event is InputEventKey:  # nothing gets through the cabinet doors (209)
		get_viewport().set_input_as_handled()
		return
	if menu.is_open():  # a sheet on the stack: it takes its own keys (207)
		return
	if nav.handle_key(event):  # Esc works like Back on the new game and settings screens (099)
		get_viewport().set_input_as_handled()
		return
	if drag.handle_input(event) or (not supply.is_open() and (knowledge.handle_key(event) or territory_view.handle_key(event))):
		get_viewport().set_input_as_handled()
	elif not supply.is_open() and modals.top() == null and drag.targeting == null and territory_view.handle_click(event):
		get_viewport().set_input_as_handled()


# --- Actions ---

## Starts a new game with seed_value (a random seed if negative) as civilization civ_id ("" for the config's
## starting one), dropping the old game's views.
func start_game(seed_value: int, civ_id := "") -> void:
	if seed_value < 0:
		seed_value = randi_range(1, 999999)
	nav.clear()
	board.show()
	log_drawer.clear()
	log_drawer.close()
	toasts.clear()  # an old game's flags, urgent ones included (250)
	supply.close()
	modals.close_all()  # an old game's event, details or tree
	news.clear()
	territory_view.reset()
	_views.reset()
	choices.refresh(null)  # an old game's choice goes at once, without doors (209)
	era_sheet.reset()
	top_bar.reset_counters()  # a new game's counters show their values at once (126)
	Game.new_game(seed_value, civ_id)
	log_drawer.mark_read()  # the new game's own lines
	menu.set_game(seed_value, _civilization_name())


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
	start_screen.opened()  # the art rises (214)


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
	nav.push(new_game_screen.overlay, new_game_screen.first_focus(), "New game")


## Hides the board and every screen: the board's cards and any open choice go away.
func _leave_game() -> void:
	nav.clear()
	supply.close()
	modals.close_all()
	_views.reset()
	choices.refresh(null)
	board.hide()


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
	var card := focus.focused if focus.focused != null else _card_before_menu_button
	drag.end_targeting()
	focus.set_card(null)
	menu.open(card)


## Closes the menu. give_back: return the focus to the card that had it, else to the Menu button.
func _close_menu(give_back := true) -> void:
	menu.dismiss(give_back)


## The menu closed (207): the focus goes back to card if it is still in the row, else to the Menu button.
func _on_menu_closed(card: CardView, give_back: bool) -> void:
	get_viewport().gui_release_focus()
	if not give_back:
		return
	if is_instance_valid(card) and focus.row().has(card):
		focus.set_card(card)
	else:
		FocusRing.focus(top_bar.menu_button)


## A button or field took the focus: the card focus goes. Remembers the card if it was the Menu
## button (clicking it moves the focus before it is pressed).
func _on_gui_focus_changed(control: Control) -> void:
	_card_before_menu_button = focus.focused if control == top_bar.menu_button else null
	focus.set_card(null)


# --- Rendering ---

func _on_card_played(outcome: Dictionary) -> void:
	_views.outcome = outcome


## Brings the screen in line with the engine: the top bar, the card views (BoardViews.sync), the overlays and buttons.
func _refresh() -> void:
	var e := Game.engine
	territory_view.close_if_stale(e)
	top_bar.refresh(e, supply.is_open())
	actions_label.visible = e.actions_per_turn() >= 0
	UIKit.set_stat(actions_label, "%d / %d" % [e.actions_left(), e.actions_per_turn()])
	_views.sync(e)
	choices.refresh(e)
	renewal_modal.refresh(e)
	log_drawer.refresh(e)
	relief.refresh(e)
	restore.refresh(e)
	sidebar.refresh(e)
	identity_modal.refresh(e)
	knowledge.refresh(e)
	supply.refresh(e)
	focus.sync()
	game_over.refresh(e)
	era_sheet.refresh(e)
	if not era_sheet.is_open():  # the event and the raid wait for the era ceremony (211)
		news.show(e)


# --- Layout ---

## The theme and background, then the board and components (BoardLayout) and the view syncing (BoardViews, 176).
func _build_layout() -> void:
	theme = GameTheme.build()
	_palette_day = Palette.day  # built in the palette as it is now: a Day mode saved before launch isn't a switch (195)
	var bg := Panel.new()
	bg.name = "Background"
	UIKit.painted(bg, func(): bg.add_theme_stylebox_override("panel", Surfaces.board()))  # walnut grain (341)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var layout := BoardLayout.new(self, _restart, _close_menu, _push_new_game_screen)
	board = layout.board
	top_bar = layout.top_bar
	play_area = layout.play_area
	relief = layout.relief
	restore = layout.restore
	menu = layout.menu
	menu.closed_giving_back.connect(_on_menu_closed)
	era_sheet.closed.connect(func(): if board.visible: _refresh())
	game_over = layout.game_over
	news = layout.news
	_views = BoardViews.new(self, top_bar)
	territory_view.navigated.connect(func():  # the view carries its cards as it grows or shrinks (105)
		_views.quiet = true
		_refresh()
		_views.quiet = false)
	_apply_settings()
	Settings.changed.connect(_apply_settings)


## Matches the menu's and settings screen's keys and the looping drop-zone pulse to the settings; when Day mode
## changed, rebuilds the theme and repaints everything open in the new palette, the game untouched (183).
func _apply_settings() -> void:
	settings_modal.show_settings()
	drag.apply_motion(UIKit.calm())
	if _palette_day == Palette.day:
		return
	_palette_day = Palette.day
	theme = GameTheme.build()
	UIKit.repaint(get_tree())
	get_tree().call_group(CardView.GROUP, "restyle")
	if board.visible:
		_refresh()

