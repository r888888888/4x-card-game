extends RefCounted
## What UI tests read off the main screen (392): controls and readings inside main's components, each a static
## function taking main first (`MainProbe.event_modal(main)`), so main.gd grows with the game and not with the tests.
## It reads only public members of main and its components. A UI test that needs to reach one more control inside a
## component of main adds a function here, never a method on main (test_ui_structure checks main has none).


## Whether the board (top bar and play area) is showing (063).
static func board_shown(main: MainScreen) -> bool:
	return main.board.visible


## The number of card views in the hand row, resting or flying in (045).
static func hand_view_count(main: MainScreen) -> int:
	return main.views_in(main.hand).size()


## The game-over overlay's text, or "" while it is hidden (045).
static func game_over_text(main: MainScreen) -> String:
	return main.game_over.text()


## The active events' views as {visible, tooltip, views: [{uid, id, text}]}, views in row order (068; 137: they lead
## the Realm's row); visible while any shows; tooltip is the explanation every event card's tooltip ends with.
static func event_panel(main: MainScreen) -> Dictionary:
	var shown := []
	for view in main.views_in(main.tableau.row):
		var event := Game.engine.zone("active_events").find(view.uid)
		if event != null:
			shown.append({"uid": view.uid, "id": event.def.id, "text": view.event_info_text()})
	return {"visible": not shown.is_empty(), "tooltip": TableauView.LEADING_ZONES.active_events, "views": shown}


## The Relieve button below the Realm, visible or not (137).
static func relieve_button(main: MainScreen) -> Button:
	return main.relief.button


## The Restore order button beside Relieve, visible or not (146). Revolt is in the civilization modal (205).
static func restore_order_button(main: MainScreen) -> Button:
	return main.restore.button


## The drawn-event modal on show, {uid, id, text, lasts, summary}; {} while closed (079).
static func event_modal(main: MainScreen) -> Dictionary:
	return main.news.event_modal.shown()


## The drawn-event modal's OK button (079).
static func event_modal_ok_button(main: MainScreen) -> Button:
	return main.news.event_modal.ok_button


## A choice event's option buttons in the event modal, in order (269).
static func event_option_buttons(main: MainScreen) -> Array[Button]:
	return main.news.event_modal.option_buttons


## The raid modal on show, {uid, id, repelled, result, title, context, art}; {} while closed (271).
static func raid_modal(main: MainScreen) -> Dictionary:
	return main.news.raid_modal.shown()


## The raid modal's verdict headline (389).
static func raid_modal_verdict(main: MainScreen) -> Label:
	return main.news.raid_modal.verdict


## The raid modal's OK button (271).
static func raid_modal_ok_button(main: MainScreen) -> Button:
	return main.news.raid_modal.ok_button


## The play area's section headings, top to bottom, as {text, tooltip} (053).
static func section_headings(main: MainScreen) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for section in main.play_area.get_children().filter(func(c): return c != main.territory_view and c != main.knowledge):
		var heading: Label = section.find_children("*", "Label", true, false)[0]  # the hand's shares a row (127)
		out.append({"text": heading.text, "tooltip": heading.tooltip_text})
	return out


## The menu's buttons, in order (067).
static func menu_buttons(main: MainScreen) -> Array[Button]:
	return UIKit.buttons_in(main.menu)


## The locked tip, a disabled key's reason shown at once (187).
static func locked_tip(main: MainScreen) -> Control:
	return main.key_sounds.tip()


## The game-over overlay's buttons, in order (067).
static func game_over_buttons(main: MainScreen) -> Array[Button]:
	return UIKit.buttons_in(main.game_over)


## The top bar's counter for key (TopBar.counter, 177).
static func counter(main: MainScreen, key: String) -> Control:
	return main.top_bar.counter(key)


## The top bar's forecast for key, apart from its figure (TopBar.forecast_text, 201).
static func forecast_text(main: MainScreen, key: String) -> String:
	return main.top_bar.forecast_text(key)


## The top bar's reading for key (TopBar.counter_text, 177): the figure and its words, not the forecast (201).
static func counter_text(main: MainScreen, key: String) -> String:
	return main.top_bar.counter_text(key)


## The build ceremonies playing on the fx layer (357).
static func build_ceremonies(main: MainScreen) -> Array[BuildCeremony]:
	var out: Array[BuildCeremony] = []
	out.assign(main.fx.get_children().filter(func(n): return n is BuildCeremony and not n.is_queued_for_deletion()))
	return out


## The board's background, its grain under BACKGROUND (183, 341).
static func background_box(main: MainScreen) -> StyleBox:
	return (main.get_node("Background") as Control).get_theme_stylebox("panel")
