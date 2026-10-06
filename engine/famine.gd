class_name Famine
extends RefCounted
## The Famine (backlog 083): a hungry upkeep brings it with a counter, each later hungry upkeep adds one (up to
## max_counters), its upkeep effects resolve once per counter unless a famine guard saves that death, it blocks
## growth, and a fed upkeep ends it. Static functions on the engine's state (backlog 096); Population.feed calls
## after_feeding.


## The active Famine, or null.
static func active(e: GameEngine) -> CardInstance:
	return Events.find_active(e, e.config.get("famine", {}).get("card", ""))


## Whether event is the active Famine (Events.resolve_upkeep leaves it to after_feeding).
static func is_famine(e: GameEngine, event: CardInstance) -> bool:
	return event != null and event == active(e)


## The active Famine's counters (0 when there is none).
static func counters(e: GameEngine) -> int:
	var famine := active(e)
	return famine.counters if famine != null else 0


## Counters on active event uid: the Famine's, 0 for any other event or uid.
static func counters_on(e: GameEngine, uid: int) -> int:
	var famine := active(e)
	return famine.counters if famine != null and famine.uid == uid else 0


## Why pop can't grow because of a Famine, or "".
static func growth_error(e: GameEngine) -> String:
	return "Famine: pop can't grow." if active(e) != null else ""


## Why relieve can't end the Famine now, or "" (084).
static func relieve_error(e: GameEngine) -> String:
	var blocked := e._blocked_error("relieve_famine")
	if blocked != "":
		return blocked
	if active(e) == null:
		return "There is no famine."
	var relief: Dictionary = e.config.famine.get("relief", {})
	if relief.is_empty():
		return "The famine can't be relieved."
	return e.price_error("Relieving the famine", relief)


## Pays population.famine.relief and the Famine leaves the game (084). False (and no change) if relieve_error says no.
static func relieve(e: GameEngine) -> bool:
	if relieve_error(e) != "":
		return false
	var relief: Dictionary = e.config.famine.relief
	e.pay(relief)
	e.zone("active_events").remove(active(e))
	e._notice("Relieved the famine (%s)." % Fields.amounts_text(relief))
	e.changed.emit()
	return true


## After pop has eaten: fed ends an active Famine. Short brings one (or adds a counter, up to max_counters) and
## resolves it once per counter; a guard on the territory the death would come from saves it instead.
static func after_feeding(e: GameEngine, fed: bool) -> void:
	var famine := active(e)
	if fed:
		if famine != null:
			e.zone("active_events").remove(famine)
			e._notice("Famine ends.")
		return
	if famine == null:
		famine = e._make_card(e.config.famine.card)
		e.zone("active_events").add(famine)
		e._notice("Famine! Pop went hungry.", GameEngine.NOTICE_URGENT)
	famine.counters = mini(famine.counters + 1, e.config.famine.max_counters)
	var guards := guards_by_territory(e)
	for i in famine.counters:
		var hit := Population.most_pop(e)
		if hit != null and guards.get(hit.uid, 0) > 0:
			guards[hit.uid] -= 1
			e._notice("%s: 1 pop saved from famine." % hit.def.name, GameEngine.NOTICE_CAUTION)
			continue
		e._resolve(famine, "upkeep")


## The famine guard of the working buildings on each territory: {territory uid: deaths it can save this upkeep}.
static func guards_by_territory(e: GameEngine) -> Dictionary:
	var guards := {}
	for card in e.zone("tableau").cards:
		if card.def.famine_guard > 0 and Fallback.works(e, card):
			guards[card.territory_uid] = guards.get(card.territory_uid, 0) + card.def.famine_guard
	return guards
