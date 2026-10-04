class_name Military
extends RefCounted
## Military rules (backlog 161 on): a settled territory's defence from the units stationed there, its working walls,
## its cities and its terrain; raids (162), aimed when drawn and striking at the next event phase. Static functions on the engine's state; GameEngine's public methods call them.

const NOT_A_UNIT := "That isn't a unit in your realm."


## Settled territory uid's defence by source: {units, buildings, cities, terrain, total}, or {} when uid isn't a
## settled territory. Idle units and buildings add nothing; a unit counts where it is stationed, not on its home.
static func defense_parts(e: GameEngine, uid: int) -> Dictionary:
	var territory := Territories.settled(e, uid)
	if territory == null:
		return {}
	var parts := {"units": 0, "buildings": 0, "cities": 0, "terrain": 0}
	for card in e.zone("tableau").cards:
		if card.def.type == CardDef.UNIT and card.station_uid == uid:
			parts.units += unit_strength(e, card.uid)
		elif card.def.type == CardDef.BUILDING and card.territory_uid == uid and not e.is_idle(card.uid):
			parts.buildings += card.def.defense
		elif card.def.type == CardDef.CITY and card.territory_uid == uid:
			parts.cities += card.def.defense
	var terrain: Dictionary = e.config.get("terrain_defense", {})
	for k in territory.keywords:
		parts.terrain += terrain.get(k, 0)
	parts.total = parts.units + parts.buildings + parts.cities + parts.terrain
	return parts


## Unit uid's strength (164): its printed strength plus the training of the working buildings on its station; 0 when
## it is idle or isn't a unit in the tableau.
static func unit_strength(e: GameEngine, uid: int) -> int:
	var unit := _unit(e, uid)
	if unit == null or e.is_idle(uid):
		return 0
	var strength := unit.def.strength
	for card in e.zone("tableau").cards:
		if card.def.type == CardDef.BUILDING and card.territory_uid == unit.station_uid and not e.is_idle(card.uid):
			strength += card.def.training
	return strength


## The training unit uid gets from its station (164): unit_strength less its printed strength, or 0.
static func training(e: GameEngine, uid: int) -> int:
	var strength := unit_strength(e, uid)
	return strength - _unit(e, uid).def.strength if strength > 0 else 0


## "Strength 3" for a trained unit (164), shown on its face; "" for anything else.
static func strength_tag(e: GameEngine, uid: int) -> String:
	return "Strength %d" % unit_strength(e, uid) if training(e, uid) > 0 else ""


## "Strength 3 (printed 2, +1 training)" for a trained unit (164), its details' line; "" for anything else.
static func strength_line(e: GameEngine, uid: int) -> String:
	if training(e, uid) <= 0:
		return ""
	return "Strength %d (printed %d, +%d training)" % [unit_strength(e, uid), _unit(e, uid).def.strength, training(e, uid)]


## Whether event is a raid (162).
static func is_raid(event: CardInstance) -> bool:
	return event != null and not event.def.raid.is_empty()


## The realm's size (257): config territory_value per settled territory plus the total cost of every city, building
## and unit in the tableau, idle or not.
static func realm_size(e: GameEngine) -> int:
	var size := 0
	for card in e.zone("tableau").cards:
		if card.def.type == CardDef.TERRITORY:
			size += e.config.get("territory_value", 0)
		elif card.def.type in [CardDef.CITY, CardDef.BUILDING, CardDef.UNIT]:
			for amount in card.def.cost.values():
				size += amount
	return size


## Whether a raid may be drawn now (257): the realm is at least raid_min_size, no raid is active, and raid_gap turns
## have passed since the last strike (no gap before the first).
static func raids_allowed(e: GameEngine) -> bool:
	if realm_size(e) < e.config.get("raid_min_size", 0):
		return false
	if e.zone("active_events").cards.any(is_raid):
		return false
	return e.state.last_raid_turn == 0 or e.turn >= e.state.last_raid_turn + e.config.get("raid_gap", 0)


## Event phases until active raid uid strikes (257): 2 on the turn it is drawn, then 1; 0 when uid isn't an active raid.
static func raid_turns_left(e: GameEngine, uid: int) -> int:
	var event := e.zone("active_events").find(uid)
	return event.turns_left if is_raid(event) else 0


## "in 2 turns" or "next turn" for raid's strike (257).
static func _when(raid: CardInstance) -> String:
	return "in %d turns" % raid.turns_left if raid.turns_left > 1 else "next turn"


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
	raid.turns_left = CardDef.RAID_WARNING
	if target != null:
		e._notice(raid_line(e, raid.uid), GameEngine.NOTICE_CAUTION)


## Active raid uid and its target, or {} when uid isn't an active raid aimed at a settled territory.
static func _aimed(e: GameEngine, uid: int) -> Dictionary:
	var raid := e.zone("active_events").find(uid)
	var target := Territories.settled(e, raid.territory_uid) if is_raid(raid) else null
	return {"raid": raid, "target": target} if target != null else {}


## "Raiders will strike Hills in 2 turns: 3 against your 0." (or "next turn") for active raid uid, or "".
static func raid_line(e: GameEngine, uid: int) -> String:
	var a := _aimed(e, uid)
	if a.is_empty():
		return ""
	return "%s will strike %s %s: %d against your %d." % [a.raid.def.name, a.target.shown_name(), _when(a.raid),
		a.raid.def.raid.strength, e.defense(a.target.uid)]


## "Hills 3 vs 0" for active raid uid's board face, or "".
static func raid_tag(e: GameEngine, uid: int) -> String:
	var a := _aimed(e, uid)
	if a.is_empty():
		return ""
	return "%s %d vs %d" % [a.target.shown_name(), a.raid.def.raid.strength, e.defense(a.target.uid)]


## Whether active raid uid's target has less defence than its strength now.
static func raid_short(e: GameEngine, uid: int) -> bool:
	var a := _aimed(e, uid)
	return not a.is_empty() and e.defense(a.target.uid) < a.raid.def.raid.strength


## A line per active raid aimed at territory uid, "Raiders strike in 2 turns: 3 vs 0" (or "next turn"), or "" when
## none is.
static func raid_warning(e: GameEngine, territory_uid: int) -> String:
	var lines: PackedStringArray = []
	for raid in e.zone("active_events").cards:
		if is_raid(raid) and raid.territory_uid == territory_uid and Territories.settled(e, territory_uid) != null:
			lines.append("%s strike %s: %d vs %d" % [raid.def.name, _when(raid), raid.def.raid.strength, e.defense(territory_uid)])
	return "\n".join(lines)


## Whether raid target a beats b: less defence, or as much and more pop.
static func _weaker(e: GameEngine, a: CardInstance, b: CardInstance) -> bool:
	var da := e.defense(a.uid)
	var db := e.defense(b.uid)
	return da < db or (da == db and a.pop > b.pop)


## Counts down each active raid, in the order drawn (TurnLoop.start_turn, before the turn's event is drawn); one at 0
## strikes, then goes to the event discard, and the turn is recorded for raid_gap (257).
static func strike_raids(e: GameEngine) -> void:
	var active := e.zone("active_events")
	for raid in active.cards.filter(is_raid):
		raid.turns_left -= 1
		if raid.turns_left > 0:
			continue
		e.state.last_raid_turn = e.turn
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
	var parts: PackedStringArray = []
	var summary := Events.outcome_summary(outcome)
	if summary != "":
		parts.append(summary)
	if outcome.pop_lost > 0:
		parts.append("−%d pop" % outcome.pop_lost)
	if not units_lost.is_empty():
		parts.append("%d unit%s lost" % [units_lost.size(), "" if units_lost.size() == 1 else "s"])
	var what := (": " + ", ".join(parts)) if not parts.is_empty() else ""
	if outcome.repelled:
		e._notice("%s repelled at %s%s." % [raid.def.name, where, what])
	else:
		e._notice("%s pillaged %s%s." % [raid.def.name, where, what], GameEngine.NOTICE_URGENT)
	e.raid_resolved.emit(outcome)


## Why unit uid can't move to territory_uid now (163), or "": unit_move_block's reasons, then not a settled
## territory or its own station.
static func move_error(e: GameEngine, uid: int, territory_uid: int) -> String:
	var unit_error := _unit_move_error(e, uid)
	if unit_error != "":
		return unit_error
	var target := Territories.settled(e, territory_uid)
	if target == null:
		return "Units can only move to a settled territory."
	var unit := _unit(e, uid)
	if unit.station_uid == territory_uid:
		return "%s is already on %s." % [unit.def.name, target.shown_name()]
	return ""


## The settled territories unit uid can move to now (163), in tableau order; [] when move_block says it can't.
static func move_targets(e: GameEngine, uid: int) -> Array[int]:
	var out: Array[int] = []
	if move_block(e, uid) == "":
		out = _elsewhere(e, uid)
	return out


## Why unit uid can't move anywhere now (163), or "": blocked, no action left, not a unit in the tableau, moved this
## turn, or no settled territory but its station.
static func move_block(e: GameEngine, uid: int) -> String:
	var unit_error := _unit_move_error(e, uid)
	if unit_error != "":
		return unit_error
	return "%s has nowhere else to go." % _unit(e, uid).def.name if _elsewhere(e, uid).is_empty() else ""


## "from Homeland" for a unit stationed away from its home (163), else "".
static func unit_origin(e: GameEngine, uid: int) -> String:
	var unit := _unit(e, uid)
	if unit == null or unit.station_uid == unit.territory_uid:
		return ""
	return "from %s" % e.territory_name(unit.territory_uid)


## The reasons unit uid can't move whatever the target: blocked, no action left, not a unit, moved this turn; or "".
static func _unit_move_error(e: GameEngine, uid: int) -> String:
	var blocked := e._blocked_error("move_unit")
	if blocked != "":
		return blocked
	if CardPlay.actions_left(e) == 0:
		return "No actions left this turn."
	var unit := _unit(e, uid)
	if unit == null:
		return NOT_A_UNIT
	if e.state.moved_units.has(uid):
		return "%s has already moved this turn." % unit.def.name
	return ""


## The settled territories other than unit uid's station, in tableau order ([] when uid isn't a unit).
static func _elsewhere(e: GameEngine, uid: int) -> Array[int]:
	var out: Array[int] = []
	var unit := _unit(e, uid)
	if unit != null:
		for card in e.zone("tableau").cards:
			if card.def.type == CardDef.TERRITORY and card.uid != unit.station_uid:
				out.append(card.uid)
	return out


## Stations unit uid on territory_uid for an action (163). False (and no change) if move_error says no.
static func move(e: GameEngine, uid: int, territory_uid: int) -> bool:
	if move_error(e, uid, territory_uid) != "":
		return false
	var unit := _unit(e, uid)
	unit.station_uid = territory_uid
	e.state.moved_units.append(uid)
	e.state.actions_used += 1
	e._log("%s marches to %s." % [unit.def.name, Territories.settled(e, territory_uid).shown_name()])
	e.changed.emit()
	return true


## Why unit uid can't be disbanded now (163), or "": blocked, or not a unit in the tableau.
static func disband_error(e: GameEngine, uid: int) -> String:
	var blocked := e._blocked_error("disband")
	if blocked != "":
		return blocked
	return NOT_A_UNIT if _unit(e, uid) == null else ""


## Unit uid goes from the tableau to the discard (163), freeing its worker on its home. False (and no change) if
## disband_error says no.
static func disband(e: GameEngine, uid: int) -> bool:
	if disband_error(e, uid) != "":
		return false
	var unit := _unit(e, uid)
	e.zone("tableau").remove(unit)
	e.zone("discard").add(unit)
	e._log("%s disbanded." % unit.def.name)
	e.changed.emit()
	return true


## Unit uid in the tableau, or null.
static func _unit(e: GameEngine, uid: int) -> CardInstance:
	var card := e.zone("tableau").find(uid)
	return card if card != null and card.def.type == CardDef.UNIT else null
