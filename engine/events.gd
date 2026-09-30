class_name Events
extends RefCounted
## The event deck (backlog 039): drawing one event each event phase, active events' upkeep, and discarding an
## event once its discard condition is met. Static functions on the engine's state; GameEngine and TurnLoop
## call them.


## Deals the config's event_deck into the event_deck zone, shuffled with the engine rng.
static func setup(e: GameEngine) -> void:
	var deck := e.zone("event_deck")
	for id in e.config.get("event_deck", {}):
		for i in e.config.event_deck[id]:
			deck.add(e._make_card(id))
	if not deck.is_empty():
		e.rng.shuffle(deck.cards)


## Upkeeps left for active event uid (0 if uid isn't an active event).
static func turns_left(e: GameEngine, uid: int) -> int:
	var card := e.zone("active_events").find(uid)
	return card.turns_left if card != null else 0


## The event phase: draws the top event (shuffling the event discard back in when the deck is empty), makes it
## active for its discard_turns, and resolves its play effects. Does nothing when both piles are empty.
static func draw(e: GameEngine) -> void:
	var deck := e.zone("event_deck")
	if deck.is_empty():
		var discard := e.zone("event_discard")
		if discard.is_empty():
			return
		for card in discard.take_all():
			deck.add(card)
		e.rng.shuffle(deck.cards)
		e._log("  Reshuffled the event discard into the event deck (%d cards)." % deck.size())
	var event := deck.take_top()
	event.turns_left = event.def.discard_turns
	e.zone("active_events").add(event)
	e._log("Event: %s." % event.def.name)
	e._resolve(event, "play")


## Resolves each active event's upkeep effects, then counts down its turns and discards it at 0. The Famine is
## skipped: Population.feed resolves it, and it ends when pop is fed (083).
static func resolve_upkeep(e: GameEngine) -> void:
	var active := e.zone("active_events")
	var famine := Population.famine(e)
	for event in active.cards.duplicate():
		if event == famine:
			continue
		e._resolve(event, "upkeep")
		event.turns_left -= 1
		if event.turns_left <= 0:
			active.remove(event)
			e.zone("event_discard").add(event)
			e._log("%s ends." % event.def.name)
