class_name BoardViews
extends RefCounted
## Keeps the board's card views in line with the engine (176, from main.gd). Views stay alive between syncs (views,
## keyed by uid), so they can animate from where they were to where the engine now says they are: new cards are dealt
## in from the deck or pop into place, cards that changed zone fly to their new place, and cards that left fly towards
## where they went. Cards in motion live on main's fx layer; at rest they sit in slot Controls inside the hand, the
## Realm's row (events, frontier, territories), the territory view and the choice rows.

var views := {}  # uid -> CardView
var outcome := {}  # the last card_played outcome: the next sync flies the played card to where it was played
var quiet := false  # syncing after a navigation: cards appear and go at once, with no pop or flight (105)

var _main: MainScreen
var _top_bar: TopBar


## main: the screen whose rows, layers and handlers the views use; top_bar: where cards deal from and leave to.
func _init(main: MainScreen, top_bar: TopBar) -> void:
	_main = main
	_top_bar = top_bar


## Places a view for every card the board shows and sends off the views of cards it no longer shows.
func sync(e: GameEngine) -> void:
	var m := _main
	var rows := {"reveal": m.choices.reveal}
	if m.pending_kind() == GameEngine.PENDING_RENEWAL:
		rows["discard"] = m.choices.renewal_row  # the discard pile, to trash from (147)
	rows["governments"] = m.choices.government_row  # the government deck, shown while one is to be chosen (154)
	var viewed := m.territory_view.card_uids()  # these rest in the territory view instead of the Realm
	var shown := {}
	for zone_name in ["hand"] + rows.keys() + TableauView.LEADING_ZONES.keys():
		for card in e.zone(zone_name).cards:
			shown[card.uid] = true
	for uid in TableauView.realm_uids(e) + viewed:  # a city or building shows only in its territory's view (102)
		shown[uid] = true
	for uid in views.keys():
		if not shown.has(uid):
			remove_view(uid, quiet)
	var hand_cards := e.zone("hand").cards
	var dealt := 0
	for i in hand_cards.size():
		if place(hand_cards[i], m.hand, i, 0.0 if UIKit.calm() else dealt * Anim.DEAL_STAGGER):
			dealt += 1
	var put := func(card: CardInstance, row: Container, index: int): place(card, row, index, 0.0)
	m.tableau.refresh(e, put, viewed)
	m.territory_view.refresh(e, put)
	for group in e.territory_groups():
		if views.has(group.territory):
			var t: int = group.territory
			views[t].show_settled(TerritoryView.stats(e, t), e.territory_tooltip(t))
			views[t].set_raid_warning(e.raid_warning(t))
	for zone_name in rows:
		var cards := e.zone(zone_name).cards
		if zone_name == "governments" and m.pending_kind() == GameEngine.PENDING_GOVERNMENT:  # the default first (254)
			var options: Array = e.pending().options
			cards = cards.duplicate()
			cards.sort_custom(func(a: CardInstance, b: CardInstance): return options.find(a.uid) < options.find(b.uid))
		for i in cards.size():
			var card: CardInstance = cards[cards.size() - 1 - i] if zone_name == "reveal" else cards[i]  # reveal: top of the deck first
			place(card, rows[zone_name], i, 0.0)
	for uid in viewed:  # a unit away from home says where it is from (163); a trained one, its strength (164)
		if views.has(uid) and e.unit_station(uid) != -1:
			views[uid].set_unit_origin(e.unit_origin(uid))
			views[uid].set_unit_strength(e.unit_strength_tag(uid))
	for card in e.zone("active_events").cards:
		var raid := e.raid_tag(card.uid)
		if raid != "":
			views[card.uid].set_raid_info(raid, e.raid_short(card.uid))
		else:
			views[card.uid].set_event_info(e.event_turns_left(card.uid), e.event_counters(card.uid))
	outcome = {}


## Makes sure card has a view resting in (or flying to) a slot at index in container.
## Returns true if the card was newly dealt into the hand.
func place(card: CardInstance, container: Container, index: int, delay: float) -> bool:
	var e := Game.engine
	var m := _main
	var in_hand := container == m.hand
	var error := e.playable_error(card.uid) if in_hand else ""
	var leading := TableauView.leading_zone(e, card.uid) if container == m.tableau.row else ""
	var kind := TableauView.board_kind(leading) if container == m.tableau.row else ""  # 138: a fixed-height board face
	var view: CardView = views.get(card.uid)
	if view == null:
		view = CardView.new()
		view.setup(card, e.card_db, in_hand, error, kind)
		view.set_pickable(m.choices.is_choice_row(container), m.choices.pick_hint(container))
		if leading != "":
			view.set_hint(TableauView.LEADING_ZONES[leading])
		view.drag_requested.connect(m.on_drag_requested)
		view.double_clicked.connect(m.on_double_clicked)
		view.discard_requested.connect(m.discard)
		view.picked.connect(m.on_picked)
		view.details_requested.connect(m.on_clicked)
		views[card.uid] = view
		var slot := new_slot(view, container, index)
		if in_hand:
			view.deal(slot, m.fx, _top_bar.pile_point(), delay)
		elif quiet:
			view.attach(slot)
		else:
			view.pop_in(slot)
		return in_hand
	if view.slot.get_parent() != container:
		if view == m.drag.dragging:
			m.drag.end_drag()
		var old_slot := view.slot
		if old_slot.get_parent() == m.hand and not in_hand:  # played: it pats down where it lands (188)
			view.place_on_land()
		view.setup(card, e.card_db, in_hand, error, kind)
		view.set_pickable(m.choices.is_choice_row(container), m.choices.pick_hint(container))
		if leading != "":
			view.set_hint(TableauView.LEADING_ZONES[leading])
		view.fly_to_slot(new_slot(view, container, index), m.fx)
		free_slot(old_slot)
		return false
	container.move_child(view.slot, index)
	if not in_hand and (view.board_kind != kind or view.shown_name != card.shown_name()):  # settled, renamed
		view.setup(card, e.card_db, in_hand, error, kind)
		view.slot.custom_minimum_size = view.slot_size()
	if in_hand:
		view.set_play_error(error)
		view.set_shortfall(e.play_shortfall(card.uid))
	elif leading != "":
		view.set_hint(TableauView.LEADING_ZONES[leading])
	else:
		view.set_idle(e.is_idle(card.uid))
	return false


## The card is no longer shown: it flies towards the zone it went to and fades (popping first if it
## was just played, so the player sees it resolve).
func remove_view(uid: int, at_once := false) -> void:
	var drag := _main.drag
	var view: CardView = views[uid]
	views.erase(uid)
	if view == drag.dragging:
		drag.end_drag()
	if view == drag.targeting:
		drag.end_targeting()
	var old_slot := view.slot
	if at_once:
		free_slot(old_slot)
		view.queue_free()
		return
	var just_played: bool = not outcome.is_empty() and outcome.uid == uid
	var via: Variant = null
	if just_played and views.has(outcome.target):  # fly to where it was played, e.g. the settled territory
		via = (views[outcome.target] as CardView).get_global_rect().get_center()
	var trashed := Game.engine.zone_of(uid) == "trashed"
	var point := leave_point(uid, view)
	var arrival := UIKit.pulse.bind(_top_bar.log_button) if point == _top_bar.pile_point() else Callable()
	if just_played and Game.engine.zone_of(uid) == "tableau":  # a building or city goes onto its territory's card: a pat (188)
		if UIKit.calm():  # it fades where it is, with no arrival
			_main.sfx.play(Sfx.CARD_PLACE)
		else:
			arrival = func(): _main.sfx.play(Sfx.CARD_PLACE)
	view.leave(_main.fx, point, just_played or trashed, via, arrival)  # the Log button pulses as a card reaches the piles (121)
	free_slot(old_slot)


## Where a card that left the board flies: the Log button for the deck or discard (121) and for an ended event, for a
## territory put back in the territory deck the edge of the choice panel, or up off the table for a trashed card.
func leave_point(uid: int, view: CardView) -> Vector2:
	var e := Game.engine
	match e.zone_of(uid):
		"tableau":
			var territory_uid := e.zone("tableau").find(uid).territory_uid
			if views.has(territory_uid):  # a city or building goes onto its territory's card (102)
				return views[territory_uid].get_global_rect().get_center()
		"trashed":
			return view.get_global_rect().get_center() - Vector2(0, view.size.y)
		"territory_deck":
			return _main.choices.explore_exit_point()
		"government":
			return _main.sidebar.government_point()
	return _top_bar.pile_point()


## A slot for view at index in container, already the size view rests at, so the row doesn't change height
## when a flying card lands (075).
func new_slot(view: CardView, container: Container, index: int) -> Control:
	var slot := Control.new()
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.custom_minimum_size = view.slot_size()
	container.add_child(slot)
	container.move_child(slot, index)
	return slot


## Removes a slot now (so the container relayouts this frame) and frees it.
func free_slot(slot: Control) -> void:
	if is_instance_valid(slot):
		slot.get_parent().remove_child(slot)
		slot.queue_free()


## Drops every view without animating (new game or restart), and whatever is on the effects layer but a dragged card.
func reset() -> void:
	var drag := _main.drag
	if drag.dragging != null:
		drag.end_drag()
	drag.end_targeting()
	for uid in views:
		var view: CardView = views[uid]
		free_slot(view.slot)
		view.queue_free()
	views.clear()
	_main.focus.focused = null
	outcome = {}
	for child in _main.fx.get_children():
		if not drag.owns(child):
			child.queue_free()
