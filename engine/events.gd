class_name Events
extends RefCounted
## The event deck (backlog 039): drawing one event at each turn start from turn 2 (237), active events' upkeep, and discarding an
## event once its discard condition is met. Static functions on the engine's state; GameEngine and TurnLoop
## call them.


## Deals the config's era-1 events into the event_deck zone, shuffled with the engine rng; later-era events wait in
## future_events until their era is added (074).
static func setup(e: GameEngine) -> void:
	var deck := e.zone("event_deck")
	for id in e.config.get("event_deck", {}):
		for i in e.config.event_deck[id]:
			var card := e._make_card(id)
			e.zone("event_deck" if card.def.era == 1 else "future_events").add(card)
	if not deck.is_empty():
		e.rng.shuffle(deck.cards)


## Shuffles the era-n events waiting in future_events into the event deck (Research.add_era calls it, once per era).
static func add_era(e: GameEngine, n: int) -> void:
	var waiting := e.zone("future_events").cards.filter(func(c): return c.def.era == n)
	if waiting.is_empty():
		return
	var deck := e.zone("event_deck")
	for event in waiting:
		e.zone("future_events").remove(event)
		deck.add(event)
	e.rng.shuffle(deck.cards)
	e._notice("  Era %d events added to the event deck." % n)


## The active event with card id id (the Famine, Anarchy), or null; null for "".
static func find_active(e: GameEngine, id: String) -> CardInstance:
	return e.zone("active_events").find_id(id) if id != "" else null


## Upkeeps left for active event uid (0 if uid isn't an active event).
static func turns_left(e: GameEngine, uid: int) -> int:
	var card := e.zone("active_events").find(uid)
	return card.turns_left if card != null else 0


## The turn's event (TurnLoop.start_turn calls it last, from turn 2; 237): draws the top event, makes it active for its
## discard_turns, and resolves its play effects. A raid drawn while raids aren't allowed goes to the deck's bottom and
## the next event is drawn instead (257); one that finds no target fizzles into the discard, resolving nothing (372). When the deck is empty, or holds only such raids (266), the event discard is
## shuffled in first. Does nothing when both piles are empty or only such raids are left in either.
static func draw(e: GameEngine) -> void:
	var deck := e.zone("event_deck")
	if deck.is_empty():
		_reshuffle(e, deck)
	var event := _take_allowed(e, deck)
	if event == null and _reshuffle(e, deck):
		event = _take_allowed(e, deck)
	if event == null:
		return
	event.turns_left = event.def.discard_turns
	e._log("Event: %s." % event.def.name)
	e._outcome = CardPlay.new_outcome(event.uid)
	e._outcome.id = event.def.id
	if Military.is_raid(event) and e.military.aim(event) == null:
		e.zone("event_discard").add(event)
		_emit_drawn(e, event)
		return
	e.zone("active_events").add(event)
	e._resolve(event, "play")
	if Military.is_raid(event):
		e.military.announce(event)
	_emit_drawn(e, event)


## Ends drawing event: clears the outcome being collected, opens the event's choice if it has one, and emits event_drawn.
static func _emit_drawn(e: GameEngine, event: CardInstance) -> void:
	var outcome := e._outcome
	e._outcome = {}
	EventChoices.drawn(e, event)
	e.event_drawn.emit(outcome)


## Shuffles the event discard into deck with the cards already there; false when the discard is empty.
static func _reshuffle(e: GameEngine, deck: Zone) -> bool:
	var discard := e.zone("event_discard")
	if discard.is_empty():
		return false
	for card in discard.take_all():
		deck.add(card)
	e.rng.shuffle(deck.cards)
	e._log("  Reshuffled the event discard into the event deck (%d cards)." % deck.size())
	return true


## The top card of deck, after moving each raid on top to the bottom while raids aren't allowed (257); null when every
## card is such a raid.
static func _take_allowed(e: GameEngine, deck: Zone) -> CardInstance:
	for i in deck.size():
		var top := deck.take_top()
		if not Military.is_raid(top) or e.military.raids_allowed():
			return top
		deck.add_bottom(top)
	return null


## Resolves each active event's upkeep effects, then counts down its turns and discards it at 0. The Famine is
## skipped: Famine.after_feeding resolves it, and it ends when pop is fed (083). So are raids: they last until they
## strike (Military.strike_raids, 162). Anarchy resolves but isn't counted down: its counters end it (253).
static func resolve_upkeep(e: GameEngine) -> void:
	var active := e.zone("active_events")
	for event in active.cards.duplicate():
		if Famine.is_famine(e, event) or Military.is_raid(event):
			continue
		e._resolve(event, "upkeep")
		if Anarchy.is_anarchy(e, event):
			continue
		event.turns_left -= 1
		if event.turns_left <= 0:
			active.remove(event)
			e.zone("event_discard").add(event)
			e._notice("%s ends." % event.def.name)


## outcome (card_played or event_drawn) as text: "+2 food, −1 wealth, +1 VP, drew 2 cards, created 1 card"; "" when
## it did nothing.
static func outcome_summary(outcome: Dictionary) -> String:
	var parts: PackedStringArray = []
	for r in outcome.get("gained", {}):
		parts.append("+%d %s" % [outcome.gained[r], r])
	for r in outcome.get("lost", {}):
		parts.append("−%d %s" % [outcome.lost[r], r])
	if outcome.get("vp", 0) != 0:
		parts.append("%+d VP" % outcome.vp)
	for key in ["drawn", "created"]:
		var n: int = outcome.get(key, []).size()
		if n > 0:
			parts.append("%s %d card%s" % ["drew" if key == "drawn" else "created", n, "" if n == 1 else "s"])
	return ", ".join(parts)
