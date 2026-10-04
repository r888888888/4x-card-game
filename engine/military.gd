class_name Military
extends RefCounted
## Military rules (backlog 161 on): a settled territory's defence from the units stationed there, its working walls,
## its cities and its terrain; raids (162), aimed when drawn and striking at the next event phase. Static functions on the engine's state; GameEngine's public methods call them.


## Settled territory uid's defence by source: {units, buildings, cities, terrain, total}, or {} when uid isn't a
## settled territory. Idle units and buildings add nothing; a unit counts where it is stationed, not on its home.
static func defense_parts(e: GameEngine, uid: int) -> Dictionary:
	var territory := Territories.settled(e, uid)
	if territory == null:
		return {}
	var parts := {"units": 0, "buildings": 0, "cities": 0, "terrain": 0}
	for card in e.zone("tableau").cards:
		if card.def.type == CardDef.UNIT and card.station_uid == uid and not e.is_idle(card.uid):
			parts.units += card.def.strength
		elif card.def.type == CardDef.BUILDING and card.territory_uid == uid and not e.is_idle(card.uid):
			parts.buildings += card.def.defense
		elif card.def.type == CardDef.CITY and card.territory_uid == uid:
			parts.cities += card.def.defense
	var terrain: Dictionary = e.config.get("terrain_defense", {})
	for k in territory.keywords:
		parts.terrain += terrain.get(k, 0)
	parts.total = parts.units + parts.buildings + parts.cities + parts.terrain
	return parts


## Whether event is a raid (162).
static func is_raid(event: CardInstance) -> bool:
	return event != null and not event.def.raid.is_empty()


## The territory active raid uid will strike (162), or -1 when uid isn't an active raid.
static func raid_target(e: GameEngine, uid: int) -> int:
	var event := e.zone("active_events").find(uid)
	return event.territory_uid if is_raid(event) else -1


## Each active raid as {uid, target, strength, defense}, in the order drawn, with its target's current defence (162).
static func raid_forecast(e: GameEngine) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for event in e.zone("active_events").cards:
		if is_raid(event):
			out.append({"uid": event.uid, "target": event.territory_uid, "strength": event.def.raid.strength,
				"defense": e.defense(event.territory_uid)})
	return out


## Fixes raid's target as it is drawn (Events.draw): among the settled territories with any of its targets (all of
## them when none has one, or it has no targets), the lowest defence, then the most pop, then tableau order.
static func announce(e: GameEngine, raid: CardInstance) -> void:
	var settled := e.zone("tableau").cards.filter(func(c): return c.def.type == CardDef.TERRITORY)
	var aimed := settled.filter(func(c): return c.keywords.any(func(k): return raid.def.raid.targets.has(k)))
	var target: CardInstance = null
	for land in aimed if not aimed.is_empty() else settled:
		if target == null or _weaker(e, land, target):
			target = land
	raid.territory_uid = target.uid if target != null else -1
	if target != null:
		e._notice("%s will strike %s next turn: %d against your %d." % [raid.def.name, target.shown_name(),
			raid.def.raid.strength, e.defense(target.uid)], GameEngine.NOTICE_CAUTION)


## Whether raid target a beats b: less defence, or as much and more pop.
static func _weaker(e: GameEngine, a: CardInstance, b: CardInstance) -> bool:
	var da := e.defense(a.uid)
	var db := e.defense(b.uid)
	return da < db or (da == db and a.pop > b.pop)


## Every active raid strikes, in the order drawn (TurnLoop.start_turn, before the turn's event is drawn), then goes to
## the event discard.
static func strike_raids(e: GameEngine) -> void:
	var active := e.zone("active_events")
	for raid in active.cards.filter(is_raid):
		_strike(e, raid)
		active.remove(raid)
		e.zone("event_discard").add(raid)


## raid strikes its target: repelled (its repel effects) when the target's defence is at least its strength, else
## pillaged (its pillage effects, the units stationed there to the discard, pop pop lost). Emits raid_resolved.
static func _strike(e: GameEngine, raid: CardInstance) -> void:
	var target := Territories.settled(e, raid.territory_uid)
	var outcome := CardPlay.new_outcome(raid.uid)
	var units_lost: Array[int] = []
	outcome.merge({"target": raid.territory_uid, "strength": raid.def.raid.strength, "defense": e.defense(raid.territory_uid),
		"units_lost": units_lost, "pop_lost": 0})
	outcome.repelled = target != null and outcome.defense >= outcome.strength
	e._outcome = outcome
	e._resolve(raid, "repel" if outcome.repelled else "pillage")
	e._outcome = {}
	if target != null and not outcome.repelled:
		for unit in e.zone("tableau").cards.filter(func(c): return c.def.type == CardDef.UNIT and c.station_uid == target.uid):
			e.zone("tableau").remove(unit)
			e.zone("discard").add(unit)
			units_lost.append(unit.uid)
		outcome.pop_lost = mini(target.pop, raid.def.raid.pop)
		target.pop -= outcome.pop_lost
	var where := target.shown_name() if target != null else "nothing"
	if outcome.repelled:
		e._notice("%s repelled at %s." % [raid.def.name, where])
	else:
		e._notice("%s pillaged %s." % [raid.def.name, where], GameEngine.NOTICE_URGENT)
	e.raid_resolved.emit(outcome)
