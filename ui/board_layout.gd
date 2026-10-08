class_name BoardLayout
extends RefCounted
## Builds the main screen's layout in code (176, from main.gd), so the prototype is easy to change, over the theme and
## background main sets: the board (the top bar, then the Realm with the territory view and the action buttons below it, then the hand);
## the effects layer; and main's components (drag, focus, choices, supply, the log drawer and toasts, the menu and the
## game-over overlay, the modals and the start screens), wired to main. It sets main's public fields as it goes and
## keeps the private parts main reads back.

var board: Control  # the top bar and the play area, hidden behind the start screens
var top_bar: TopBar
var play_area: VBoxContainer  # the sections, top to bottom: Realm (events, frontier, territories), Hand
var relief: ActionButton  # below the Realm while a Famine can be relieved
var renew: ActionButton  # beside it while Anarchy's renewal has cards left (385)
var menu: GameMenu
var game_over: GameOverOverlay
var news: TurnNews


## Builds main's layout. restart(seed) starts again as this game's civilization (-1: a random seed);
## close_menu(give_back) closes the menu; push_new_game_screen opens the new game screen over the current one.
func _init(main: MainScreen, restart: Callable, close_menu: Callable, push_new_game_screen: Callable) -> void:
	main.sfx = Sfx.new()  # first, so every component can play through it (186)
	main.add_child(main.sfx)
	main.key_sounds = KeySounds.new(main.sfx)  # every button main gets clicks (187)
	main.add_child(main.key_sounds)
	if Game.engine != null:  # before main hears changed, so an event sound comes first (191)
		main.add_child(EventSounds.new(Game.engine, main.sfx))
	_build_board(main)
	_build_hand(main)

	# Effects layer, above the board and below the overlays.
	main.fx = Control.new()
	main.fx.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main.fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	main.add_child(main.fx)
	main.vellum = Vellum.new(func():  # the play area and the sidebar, the window's full width (210)
		var top: float = play_area.get_global_rect().position.y
		return Rect2(0, top, main.size.x, main.size.y - top), func(point: Vector2): main.drag.click_vellum(point))
	main.add_child(main.vellum)
	main.drag = DragController.new(main)
	main.focus = CardFocus.new(main)
	main.card_actions = CardActions.new(main)
	main.choices = ChoiceOverlays.new(main)
	main.doors = main.choices.doors
	main.supply = SupplyScreen.new(main, main.open_supply)
	main.supply.closed.connect(func(): main.focus.clear())
	top_bar.add_supply_button(main.supply.button)
	main.log_drawer = LogDrawer.new()  # before the modals, which open over it and take the keys first
	main.add_child(main.log_drawer)
	main.log_drawer.unread_changed.connect(top_bar.set_log_unread)
	main.toasts = Toasts.new(main.sidebar, func(): return menu.is_open() or main.nav.depth() > 0 or main.modals.is_open() \
		or main.era_sheet.is_open() or main.knowledge.is_open())
	main.add_child(main.toasts)

	main.modals = ModalStack.new(main)
	game_over = GameOverOverlay.new(main.modals, func(): restart.call(Game.engine.seed_value), func(): restart.call(-1))
	menu = GameMenu.new(main.modals)
	menu.start_requested.connect(func(seed_value: int):
		close_menu.call(false)
		restart.call(seed_value))
	menu.new_game_requested.connect(func():
		close_menu.call(false)
		main.show_new_game_screen())
	menu.exit_requested.connect(func(): main.quit_hook.call())
	menu.settings_requested.connect(func(): main.settings_modal.open(Game.engine.seed_value))
	main.details = CardDetailsModal.new(main.modals)
	main.details.play_requested.connect(main.card_actions.on_double_clicked)  # Play acts as a double-click would (225)
	main.details.buy_requested.connect(main.supply.buy)  # a supply pile's Buy (259)
	main.knowledge = KnowledgeScreen.new(main.territory_view.nav, main.tableau.get_parent(), main.details.open_tech,
		main.modals)
	main.knowledge.click_through = main.sidebar.end_turn  # 348
	var lamps := func():  # the keys' lamps, after a see (288)
		top_bar.refresh(Game.engine, true)
		main.supply.refresh(Game.engine)
	main.supply.looked.connect(func():
		Game.engine.see_supply()
		lamps.call())
	main.knowledge.looked.connect(func():
		Game.engine.see_techs()
		lamps.call())
	news = TurnNews.new(main.modals)
	main.identity_modal = IdentityModal.new(main.modals)
	main.revolt_modal = RevoltModal.new(main.modals)
	main.move_modal = MoveModal.new(main.modals)
	main.renewal_modal = RenewalModal.new(main.modals)
	main.details.move_requested.connect(func(uid): main.move_modal.open(Game.engine, uid))
	main.identity_modal.revolt_requested.connect(func(): main.revolt_modal.open(Game.engine))
	main.identity_modal.details_requested.connect(main.details.open_card)
	main.rename_modal = RenameModal.new(main.modals)
	main.territory_view.rename_requested.connect(main.rename_modal.open)
	main.build_modal = BuildModal.new(main.modals)
	main.territory_view.build_requested.connect(main.build_modal.open)
	main.settings_modal = SettingsModal.new(main.modals)
	main.settings_modal.restart_requested.connect(func(seed_value: int):
		close_menu.call(false)
		restart.call(seed_value))
	_build_screens(main, push_new_game_screen)
	main.era_sheet = EraSheet.new()  # last: over everything, and first to take the input (211)
	main.add_child(main.era_sheet)
	if Game.engine != null:
		Game.engine.milestone.connect(main.era_sheet.note)


## The board (221, the transitions mock's desk): the top bar on a full-bleed Strip, then the Realm (the row, the
## territory view and the action buttons) and the hand, inset SPACE_4, beside the sidebar's open rail.
func _build_board(main: MainScreen) -> void:
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", Tokens.SPACE_0)
	main.add_child(root)
	board = root

	var strip := PanelContainer.new()
	strip.theme_type_variation = &"Strip"
	root.add_child(strip)
	top_bar = TopBar.new(main.open_menu, func(): main.knowledge.toggle(), func(): main.log_drawer.toggle())
	strip.add_child(top_bar)

	var below := HBoxContainer.new()  # the play area, then the sidebar at the right edge (202)
	below.size_flags_vertical = Control.SIZE_EXPAND_FILL
	below.add_theme_constant_override("separation", Tokens.SPACE_0)
	root.add_child(below)
	var inset := MarginContainer.new()  # the play area's margins, level with the rail's padding (221)
	inset.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "right", "top", "bottom"]:
		inset.add_theme_constant_override("margin_" + side, Tokens.SPACE_4)
	below.add_child(inset)
	play_area = VBoxContainer.new()  # the width left of the sidebar below the top bar (115, 202)
	play_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	play_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	play_area.add_theme_constant_override("separation", UIKit.SECTION_GAP)
	inset.add_child(play_area)
	main.sidebar = Sidebar.new(func(): main.identity_modal.open())
	below.add_child(main.sidebar)
	top_bar.menu_button.focus_next = top_bar.menu_button.get_path_to(main.sidebar.name_button)  # the strip, then the rail
	main.sidebar.name_button.focus_previous = main.sidebar.name_button.get_path_to(top_bar.menu_button)

	var realm_section := UIKit.section(play_area, "Realm")
	realm_section.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main.tableau = TableauView.new()
	realm_section.add_child(main.tableau)
	main.territory_view = TerritoryView.new(main, realm_section)
	var relief_row := HBoxContainer.new()  # Relieve famine and Renew (385), each when it applies
	realm_section.add_child(relief_row)
	relief = ActionButton.relieve_famine(relief_row)
	renew = ActionButton.renew(relief_row, func(e: GameEngine): main.renewal_modal.open(e))


## The hand section: its "In Hand" heading (the how-to in its tooltip) with the actions count right-aligned on its line
## (127, 204), and the hand's row in a sideways scroll.
func _build_hand(main: MainScreen) -> void:
	var hand_section := UIKit.section(play_area, "In Hand")
	var heading := hand_section.get_child(0) as Label
	heading.tooltip_text = "Drag a card into the realm, double-click it, or ←/→ then Enter. Right-click or D discards."
	heading.mouse_filter = Control.MOUSE_FILTER_PASS  # so the tooltip shows
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var hand_heading := HBoxContainer.new()
	heading.reparent(hand_heading)
	main.actions_label = UIKit.stat(hand_heading)
	main.actions_label.theme_type_variation = &"BarStat"
	main.actions_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	main.actions_label.mouse_filter = Control.MOUSE_FILTER_PASS
	main.actions_label.tooltip_text = "Actions left this turn"
	hand_section.add_child(hand_heading)
	hand_section.move_child(hand_heading, 0)
	main.hand_scroll = SmoothScroll.new()
	main.hand_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main.hand_scroll.custom_minimum_size.y = CardView.HAND_SIZE.y + Anim.LIFT_ROOM + 20
	main.hand_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	hand_section.add_child(main.hand_scroll)
	var hand_pad := MarginContainer.new()
	hand_pad.add_theme_constant_override("margin_left", int(Anim.HAND_SIDE_ROOM))
	hand_pad.add_theme_constant_override("margin_right", int(Anim.HAND_SIDE_ROOM))
	main.hand_scroll.add_child(hand_pad)
	main.hand = HBoxContainer.new()
	main.hand.add_theme_constant_override("separation", Tokens.SPACE_3)
	hand_pad.add_child(main.hand)


## The title, new game and settings screens, on main's animated navigator.
func _build_screens(main: MainScreen, push_new_game_screen: Callable) -> void:
	main.start_screen = StartScreen.new(main)
	main.start_screen.new_game_requested.connect(push_new_game_screen)
	main.start_screen.settings_requested.connect(func():
		main.settings_modal.open())
	main.start_screen.exit_requested.connect(func(): main.quit_hook.call())
	main.nav.animated = true
	main.new_game_screen = NewGameScreen.new(main, main.nav)
	main.new_game_screen.start_requested.connect(func(seed_value: int):
		main.start_game(seed_value, main.new_game_screen.selected))
