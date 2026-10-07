class_name Military
extends RefCounted
## Military rules (backlog 161 on): a settled territory's defence from the units stationed there, its working walls,
## its cities and its terrain; raids (162), aimed when drawn and striking two event phases later (257), once the realm is
## large enough. The engine's military area (394): `engine.military.move(uid, t)`, the units' and raids' actions and
## queries on one object, built with its engine (so a fork has its own). It holds no state, only a weak reference back
## to its engine (no reference cycle); its actions keep their `_error` twins.

const NOT_A_UNIT := "That isn't a unit in your realm."

var _engine_ref: WeakRef  # the engine this area works on; weak, as the engine holds the area


func _init(engine: GameEngine) -> void:
	_engine_ref = weakref(engine)


## The engine this area works on.
func _engine() -> GameEngine:
	return _engine_ref.get_ref()


## Settled territory uid's defence (161): defense_parts(uid).total, or 0 for anything else.
func defense(uid: int) -> int:
	return defense_parts(uid).get("total", 0)


## Settled territory uid's defence by source: {units, buildings, cities, terrain, total}, or {} when uid isn't a
## settled territory. Idle units and buildings add nothing; a unit counts where it is stationed, not on its home.
func defense_parts(uid: int) -> Dictionary:
	var e := _engine()
	var territory := Territories.settled(e, uid)
	if territory == null:
		return {}
	var parts := {"units": 0, "buildings": 0, "cities": 0, "terrain": 0}
	for card in e.zone("tableau").cards:
		if card.def.type == CardDef.UNIT and card.station_uid == uid:
			parts.units += strength(card.uid)
		elif card.def.type == CardDef.BUILDING and card.territory_uid == uid and Fallback.works(e, card) \
				and not Sites.unfinished(e, card):
			parts.buildings += card.def.defense
		elif card.def.type == CardDef.CITY and card.territory_uid == uid:
			parts.cities += card.def.defense
	var terrain: Dictionary = e.config.get("terrain_defense", {})
	for k in territory.keywords:
		parts.terrain += terrain.get(k, 0)
	parts.total = parts.units + parts.buildings + parts.cities + parts.terrain
	return parts


## Unit uid's strength (164): its printed strength plus its training and its veteran counters (165); 0 when it is
## idle or isn't a unit in the tableau.
func strength(uid: int) -> int:
	var e := _engine()
	var unit := _unit(uid)
	if unit == null or e.is_idle(uid):
		return 0
	return unit.def.strength + training(uid) + unit.counters


## The training working unit uid gets from the working buildings on its station (164); 0 when it is idle or isn't a
## unit in the tableau.
func training(uid: int) -> int:
	var e := _engine()
	var unit := _unit(uid)
	if unit == null or e.is_idle(uid):
		return 0
	var total := 0
	for card in e.zone("tableau").cards:
		if card.def.type == CardDef.BUILDING and card.territory_uid == unit.station_uid and Fallback.works(e, card) \
				and not Sites.unfinished(e, card):
			total += card.def.training
	return total


## Unit uid's veteran counters (165): 1 per raid repelled where it stood, up to config veteran_max; 0 for anything
## but a unit in the tableau.
## Unit uid's veteran pips on its card (388): {filled: its counters, total: config veteran_max}; {filled 0, total 0}
## for anything but a unit in the tableau, or with veteran_max 0.
func veteran_pips(uid: int) -> Dictionary:
	var total: int = _engine().config.get("veteran_max", 0)
	var unit := _unit(uid)
	if unit == null or total == 0:
		return {"filled": 0, "total": 0}
	return {"filled": unit.counters, "total": total}


func veterancy(uid: int) -> int:
	var unit := _unit(uid)
	return unit.counters if unit != null else 0


## "Veteran 1 (+1 strength)" for a veteran unit (165), its details' line; "" for anything else.
func veteran_line(uid: int) -> String:
	var n := veterancy(uid)
	return "Veteran %d (+%d strength)" % [n, n] if n > 0 else ""


## "Strength 3" for a trained or veteran unit (164, 165), shown on its face; "" for anything else.
func strength_tag(uid: int) -> String:
	var total := strength(uid)
	return "Strength %d" % total if total > 0 and total != _unit(uid).def.strength else ""


## "Strength 3 (printed 2, +1 training)" for a trained unit (164), its details' line; "" for anything else.
func strength_line(uid: int) -> String:
	if training(uid) <= 0:
		return ""
	return "Strength %d (printed %d, +%d training)" % [strength(uid), _unit(uid).def.strength, training(uid)]


## Whether event is a raid (162).
static func is_raid(event: CardInstance) -> bool:
	return event != null and not event.def.raid.is_empty()


## The realm's size (257): config territory_value per settled territory plus the total cost of every city, building
## and unit in the tableau, idle or not.
func realm_size() -> int:
	var e := _engine()
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
func raids_allowed() -> bool:
	var e := _engine()
	if realm_size() < e.config.get("raid_min_size", 0):
		return false
	if e.zone("active_events").cards.any(is_raid):
		return false
	return e.state.last_raid_turn == 0 or e.turn >= e.state.last_raid_turn + e.config.get("raid_gap", 0)


## Event phases until active raid uid strikes (257): 2 on the turn it is drawn, then 1; 0 when uid isn't an active raid.
func raid_turns_left(uid: int) -> int:
	var e := _engine()
	var event := e.zone("active_events").find(uid)
	return event.turns_left if is_raid(event) else 0


## "in 2 turns" or "next turn" for raid's strike (257).
static func _when(raid: CardInstance) -> String:
	return "in %d turns" % raid.turns_left if raid.turns_left > 1 else "next turn"


## Active raid uid's strength (374): fixed when it was announced; 0 when uid isn't an active raid.
func raid_strength(uid: int) -> int:
	var e := _engine()
	var event := e.zone("active_events").find(uid)
	return event.raid_strength if is_raid(event) else 0


## The territory active raid uid will strike (162), or -1 when uid isn't an active raid.
func raid_target(uid: int) -> int:
	var e := _engine()
	var event := e.zone("active_events").find(uid)
	return event.territory_uid if is_raid(event) else -1


## Each active raid as {uid, target, strength, defense}, in the order drawn, with its target's current defence (162).
func raid_forecast() -> Array[Dictionary]:
	var e := _engine()
	var out: Array[Dictionary] = []
	for event in e.zone("active_events").cards:
		if is_raid(event):
			out.append({"uid": event.uid, "target": event.territory_uid, "strength": event.raid_strength,
				"defense": defense(event.territory_uid)})
	return out


## The territory raid would strike if drawn now: among the settled territories with any of its targets (all of them
## when it has no targets), the lowest defence, then the most pop, then tableau order; null when none qualifies (372).
func aim(raid: CardInstance) -> CardInstance:
	var e := _engine()
	var targets: Array = raid.def.raid.targets
	var target: CardInstance = null
	for land in e.zone("tableau").cards:
		if land.def.type != CardDef.TERRITORY or not (targets.is_empty() or land.keywords.any(func(k): return targets.has(k))):
			continue
		if target == null or _weaker(land, target):
			target = land
	return target


## Fixes raid's target (aim) and strength as it is drawn (Events.draw) and announces it. Its strength is its printed
## one plus 1 for every config raid_hoard_step food and wealth held (374; none when the step is 0).
func announce(raid: CardInstance) -> void:
	var e := _engine()
	var target := aim(raid)
	raid.territory_uid = target.uid if target != null else -1
	var step: int = e.config.get("raid_hoard_step", 0)
	var hoard: int = e.resources.get(GameEngine.FOOD, 0) + e.resources.get(GameEngine.WEALTH, 0)
	raid.raid_strength = raid.def.raid.strength + (hoard / step if step > 0 else 0)
	raid.turns_left = CardDef.RAID_WARNING
	if target != null:
		e._notice(raid_line(raid.uid), GameEngine.NOTICE_CAUTION)


## Active raid uid and its target, or {} when uid isn't an active raid aimed at a settled territory.
func _aimed(uid: int) -> Dictionary:
	var e := _engine()
	var raid := e.zone("active_events").find(uid)
	var target := Territories.settled(e, raid.territory_uid) if is_raid(raid) else null
	return {"raid": raid, "target": target} if target != null else {}


## "Raiders will strike Hills in 2 turns: 3 against your 0." (or "next turn") for active raid uid, or "".
func raid_line(uid: int) -> String:
	var a := _aimed(uid)
	if a.is_empty():
		return ""
	return "%s will strike %s %s: %d against your %d." % [a.raid.def.name, a.target.shown_name(), _when(a.raid),
		a.raid.raid_strength, defense(a.target.uid)]


## "Hills 3 vs 0" for active raid uid's board face, or "".
func raid_tag(uid: int) -> String:
	var a := _aimed(uid)
	if a.is_empty():
		return ""
	return "%s %d vs %d" % [a.target.shown_name(), a.raid.raid_strength, defense(a.target.uid)]


## Whether active raid uid's target has less defence than its strength now.
func raid_short(uid: int) -> bool:
	var a := _aimed(uid)
	return not a.is_empty() and defense(a.target.uid) < a.raid.raid_strength


## A line per active raid aimed at territory uid, "Raiders strike in 2 turns: 3 vs 0" (or "next turn"), or "" when
## none is.
func raid_warning(territory_uid: int) -> String:
	var e := _engine()
	var lines: PackedStringArray = []
	for raid in e.zone("active_events").cards:
		if is_raid(raid) and raid.territory_uid == territory_uid and Territories.settled(e, territory_uid) != null:
			lines.append("%s strike %s: %d vs %d" % [raid.def.name, _when(raid), raid.raid_strength, defense(territory_uid)])
	return "\n".join(lines)


## Whether raid target a beats b: less defence, or as much and more pop.
func _weaker(a: CardInstance, b: CardInstance) -> bool:
	var da := defense(a.uid)
	var db := defense(b.uid)
	return da < db or (da == db and a.pop > b.pop)


## Counts down each active raid, in the order drawn (TurnLoop.start_turn, before the turn's event is drawn); one at 0
## strikes, then goes to the event discard, and the turn is recorded for raid_gap (257).
func strike_raids() -> void:
	var e := _engine()
	var active := e.zone("active_events")
	for raid in active.cards.filter(is_raid):
		raid.turns_left -= 1
		if raid.turns_left > 0:
			continue
		e.state.last_raid_turn = e.turn
		_strike(raid)
		active.remove(raid)
		e.zone("event_discard").add(raid)


## raid strikes its target: repelled (its repel effects) when the target's defence is at least its strength, else
## pillaged (its pillage effects, then its plunder (374), the units stationed there lost (_leave_play), pop pop lost). Logs what happened (a raid
## modal shows it, 271, so it's no notice) and emits raid_resolved.
func _strike(raid: CardInstance) -> void:
	var e := _engine()
	var target := Territories.settled(e, raid.territory_uid)
	var outcome := CardPlay.new_outcome(raid.uid)
	var units_lost: Array[int] = []
	outcome.merge({"id": raid.def.id, "target": raid.territory_uid, "strength": raid.raid_strength,
		"defense": defense(raid.territory_uid), "units_lost": units_lost, "pop_lost": 0})
	outcome.repelled = target != null and outcome.defense >= outcome.strength
	outcome.veterans = _promote(target.uid) if outcome.repelled else [] as Array[int]
	e._outcome = outcome
	e._resolve(raid, "repel" if outcome.repelled else "pillage")
	if not outcome.repelled:
		_plunder(raid)
	e._outcome = {}
	if target != null and not outcome.repelled:
		for unit in e.zone("tableau").cards.filter(func(c): return c.def.type == CardDef.UNIT and c.station_uid == target.uid):
			_leave_play(unit)
			units_lost.append(unit.uid)
		outcome.pop_lost = mini(target.pop, raid.def.raid.pop)
		target.pop -= outcome.pop_lost
	e._log(outcome_text(outcome))
	e.raid_resolved.emit(outcome)


## Each working unit stationed on territory_uid below config veteran_max gains a veteran counter (165); returns
## their uids.
func _promote(territory_uid: int) -> Array[int]:
	var e := _engine()
	var promoted: Array[int] = []
	for unit in e.zone("tableau").cards:
		if unit.def.type == CardDef.UNIT and unit.station_uid == territory_uid and not e.is_idle(unit.uid) \
				and unit.counters < e.config.get("veteran_max", 0):
			unit.counters += 1
			promoted.append(unit.uid)
	return promoted


## The share (%) a pillage plunders in the current era (377): raid_plunder_pct plus raid_plunder_era_pct per era after
## the first, at most 100.
func plunder_pct() -> int:
	var e := _engine()
	var step: int = e.config.get("raid_plunder_era_pct", 0)
	return mini(100, e.config.get("raid_plunder_pct", 0) + step * (e.era() - 1))


## A pillaging raid also takes plunder_pct% of the food and of the wealth left after its pillage effects, each
## rounded up (374), into the outcome's lost.
func _plunder(raid: CardInstance) -> void:
	var e := _engine()
	var pct := plunder_pct()
	for r in [GameEngine.FOOD, GameEngine.WEALTH]:
		var n := ceili(maxi(0, e.resources.get(r, 0)) * pct / 100.0)
		if n > 0:
			e.lose(r, n, raid)


## A raid_resolved outcome as its result line (271): "Raiders pillaged Hills: +1 unrest, −2 food, −1 pop, 1 unit lost." or
## "Raiders repelled at Hills: +2 wealth."; the part after the colon lists what it gave and took, and is left out when
## it did nothing.
func outcome_text(outcome: Dictionary) -> String:
	var e := _engine()
	var target := Territories.settled(e, outcome.target)
	var where := target.shown_name() if target != null else "nothing"
	var parts: PackedStringArray = []
	var summary := Events.outcome_summary(outcome)
	if summary != "":
		parts.append(summary)
	if outcome.pop_lost > 0:
		parts.append("−%d pop" % outcome.pop_lost)
	var units: int = outcome.units_lost.size()
	if units > 0:
		parts.append("%d unit%s lost" % [units, "" if units == 1 else "s"])
	var what := (": " + ", ".join(parts)) if not parts.is_empty() else ""
	var name: String = e.card_db[outcome.id].name
	if outcome.repelled:
		return "%s repelled at %s%s." % [name, where, what]
	return "%s pillaged %s%s." % [name, where, what]


## Why unit uid can't move to territory_uid now (163), or "": unit_move_block's reasons, then not a settled
## territory or its own station.
func move_error(uid: int, territory_uid: int) -> String:
	var e := _engine()
	var unit_error := _unit_move_error(uid)
	if unit_error != "":
		return unit_error
	var target := Territories.settled(e, territory_uid)
	if target == null:
		return "Units can only move to a settled territory."
	var unit := _unit(uid)
	if unit.station_uid == territory_uid:
		return "%s is already on %s." % [unit.def.name, target.shown_name()]
	return ""


## Stations unit uid on territory_uid for an action (163). False (and no change) if move_error says no.
func move(uid: int, territory_uid: int) -> bool:
	var e := _engine()
	if move_error(uid, territory_uid) != "":
		return false
	var unit := _unit(uid)
	unit.station_uid = territory_uid
	e.state.moved_units.append(uid)
	e.state.actions_used += 1
	e._log("%s marches to %s." % [unit.def.name, Territories.settled(e, territory_uid).shown_name()])
	e.changed.emit()
	return true


## The settled territories unit uid can move to now (163), in tableau order; [] when move_block says it can't.
func move_targets(uid: int) -> Array[int]:
	var out: Array[int] = []
	if move_block(uid) == "":
		out = _elsewhere(uid)
	return out


## Why unit uid can't move anywhere now (163), or "": blocked, no action left, not a unit in the tableau, moved this
## turn, or no settled territory but its station.
func move_block(uid: int) -> String:
	var unit_error := _unit_move_error(uid)
	if unit_error != "":
		return unit_error
	return "%s has nowhere else to go." % _unit(uid).def.name if _elsewhere(uid).is_empty() else ""


## "from Homeland" for a unit stationed away from its home (163), else "".
func origin(uid: int) -> String:
	var e := _engine()
	var unit := _unit(uid)
	if unit == null or unit.station_uid == unit.territory_uid:
		return ""
	return "from %s" % e.territory_name(unit.territory_uid)


## The reasons unit uid can't move whatever the target: blocked, no action left, not a unit, moved this turn; or "".
func _unit_move_error(uid: int) -> String:
	var e := _engine()
	var blocked := e._blocked_error("move_unit")
	if blocked != "":
		return blocked
	if CardPlay.actions_left(e) == 0:
		return "No actions left this turn."
	var unit := _unit(uid)
	if unit == null:
		return NOT_A_UNIT
	if e.state.moved_units.has(uid):
		return "%s has already moved this turn." % unit.def.name
	return ""


## The settled territories other than unit uid's station, in tableau order ([] when uid isn't a unit).
func _elsewhere(uid: int) -> Array[int]:
	var e := _engine()
	var out: Array[int] = []
	var unit := _unit(uid)
	if unit != null:
		for card in e.zone("tableau").cards:
			if card.def.type == CardDef.TERRITORY and card.uid != unit.station_uid:
				out.append(card.uid)
	return out


## Why unit uid can't be disbanded now (163), or "": blocked, or not a unit in the tableau.
func disband_error(uid: int) -> String:
	var e := _engine()
	var blocked := e._blocked_error("disband")
	if blocked != "":
		return blocked
	return NOT_A_UNIT if _unit(uid) == null else ""


## Unit uid leaves play (to the discard, 163; gone if it came from the build menu, 296), freeing its worker on its home. False (and no change) if
## disband_error says no.
func disband(uid: int) -> bool:
	var e := _engine()
	if disband_error(uid) != "":
		return false
	var unit := _unit(uid)
	_leave_play(unit)
	e._log("%s disbanded." % unit.def.name)
	e.changed.emit()
	return true


## What upgrading unit uid costs (166): its upgrade's printed cost less its own per resource, the positive part; {} when
## uid isn't a unit in the tableau with upgrades_to.
func upgrade_cost(uid: int) -> Dictionary:
	var e := _engine()
	var unit := _unit(uid)
	if unit == null or unit.def.upgrades_to == "":
		return {}
	var price := {}
	var new_cost: Dictionary = e.card_db[unit.def.upgrades_to].cost
	for r in new_cost:
		var n: int = new_cost[r] - unit.def.cost.get(r, 0)
		if n > 0:
			price[r] = n
	return price


## "Upgrade to Pikes for 2 food, 1 wealth (no action)." for a unit in the tableau with upgrades_to (166), its Upgrade
## button's tooltip; "" for anything else.
func upgrade_line(uid: int) -> String:
	var e := _engine()
	var unit := _unit(uid)
	if unit == null or unit.def.upgrades_to == "":
		return ""
	var price := upgrade_cost(uid)
	var paid := Fields.amounts_text(price) if not price.is_empty() else "nothing"
	return "Upgrade to %s for %s (no action)." % [e.card_db[unit.def.upgrades_to].name, paid]


## Why unit uid can't be upgraded now (166), or "": blocked, not a unit, no upgrades_to, its upgrade's build-menu
## entry locked or missing, Anarchy (Anarchy.play_error on the new card, as building it), or short of upgrade_cost.
func upgrade_error(uid: int) -> String:
	var e := _engine()
	var blocked := e._blocked_error("upgrade_unit")
	if blocked != "":
		return blocked
	var unit := _unit(uid)
	if unit == null:
		return NOT_A_UNIT
	var to := unit.def.upgrades_to
	if to == "":
		return "%s can't be upgraded." % unit.def.name
	if not BuildMenu.entries(e).has(to):
		return "%s isn't unlocked yet." % e.card_db[to].name
	var anarchy := Anarchy.play_error(e, CardInstance.new(-1, e.card_db[to]))
	if anarchy != "":
		return anarchy
	return e.price_error("Upgrading %s" % unit.def.name, CardPlay.short_of(e, upgrade_cost(uid)))


## Replaces unit uid with a new copy of its upgrades_to unit in its tableau place, keeping its home, station and
## veteran counters; the old one goes to removed (166). False (and no change) if upgrade_error says no.
func upgrade(uid: int) -> bool:
	var e := _engine()
	if upgrade_error(uid) != "":
		return false
	var old := _unit(uid)
	e.pay(upgrade_cost(uid))
	var tableau := e.zone("tableau")
	var card := e._make_card(old.def.upgrades_to)
	card.territory_uid = old.territory_uid
	card.station_uid = old.station_uid
	card.counters = old.counters
	tableau.cards[tableau.cards.find(old)] = card
	old.counters = 0
	e.zone("removed").add(old)
	e._log("%s upgraded to %s." % [old.def.name, card.def.name])
	e.changed.emit()
	return true


## Unit leaves the tableau (disbanded or lost to a pillage), losing its veteran counters (165): a unit recruited from the build menu is gone, to be
## recruited again (296); one with no build-menu entry (dealt from a deck) goes to the discard (163).
func _leave_play(unit: CardInstance) -> void:
	var e := _engine()
	var to_discard := e.disbands_to_discard(unit.uid)
	unit.counters = 0
	e.zone("tableau").remove(unit)
	if to_discard:
		e.zone("discard").add(unit)


## Unit uid in the tableau, or null.
func _unit(uid: int) -> CardInstance:
	var e := _engine()
	var card := e.zone("tableau").find(uid)
	return card if card != null and card.def.type == CardDef.UNIT else null
