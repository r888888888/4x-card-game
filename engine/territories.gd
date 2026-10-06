class_name Territories
extends RefCounted
## Territory rules (backlog 001 on): exploring and the explore choice, settling, building slots and keyword
## requirements, and grouping the tableau by territory. Static functions on the engine's state; GameEngine's
## public methods call them.


## The territory card territory_uid if it is settled (on the tableau), or null.
static func settled(e: GameEngine, territory_uid: int) -> CardInstance:
	var territory := e.zone("tableau").find(territory_uid)
	if territory == null or territory.def.type != CardDef.TERRITORY:
		return null
	return territory


## How many territories are settled (in the tableau).
static func count_settled(e: GameEngine) -> int:
	return e.zone("tableau").cards.filter(func(c): return c.def.type == CardDef.TERRITORY).size()


static func keywords_of(e: GameEngine, uid: int) -> Array[String]:
	for z in GameEngine.ZONES:
		var card := e.zone(z).find(uid)
		if card != null:
			return card.keywords.duplicate() if card.def.type == CardDef.TERRITORY else [] as Array[String]
	return [] as Array[String]


## A settled territory's building slots: its own, its cities' and its tier's (281); 0 if unsettled.
static func total_slots(e: GameEngine, territory_uid: int) -> int:
	var territory := settled(e, territory_uid)
	if territory == null:
		return 0
	var total := territory.def.slots + Population.slots_at_pop(e, territory.pop)
	for card in e.zone("tableau").cards:
		if card.def.type == CardDef.CITY and card.territory_uid == territory_uid:
			total += card.def.slots
	return total


static func free_slots(e: GameEngine, territory_uid: int) -> int:
	if settled(e, territory_uid) == null:
		return 0
	return maxi(0, total_slots(e, territory_uid) - buildings_on(e, territory_uid).size())


## The buildings in territory territory_uid's slots, in the order they were placed: not the upgrades on them (300).
static func buildings_on(e: GameEngine, territory_uid: int) -> Array[CardInstance]:
	var out: Array[CardInstance] = []
	for card in e.zone("tableau").cards:
		if card.def.uses_worker() and card.def.type == CardDef.BUILDING and card.territory_uid == territory_uid:
			out.append(card)
	return out


## The cards using workers on territory territory_uid (its buildings and the units homed there, 160), in the order
## they were placed: the first ones get its pop.
static func workers_on(e: GameEngine, territory_uid: int) -> Array[CardInstance]:
	var out: Array[CardInstance] = []
	for card in e.zone("tableau").cards:
		if card.def.uses_worker() and card.territory_uid == territory_uid:
			out.append(card)
	return out


## The units stationed on territory territory_uid (160), in the order they were recruited; [] for anything else.
static func units_at(e: GameEngine, territory_uid: int) -> Array[int]:
	var out: Array[int] = []
	for card in e.zone("tableau").cards:
		if card.def.type == CardDef.UNIT and card.station_uid == territory_uid:
			out.append(card.uid)
	return out


## Whether card is a territory with a free building slot.
static func has_room(e: GameEngine, territory: CardInstance) -> bool:
	return territory.def.type == CardDef.TERRITORY and free_slots(e, territory.uid) > 0


## Whether territory has one of the keywords building card requires (or it requires none).
static func meets_requires(card: CardInstance, territory: CardInstance) -> bool:
	if card.def.requires.is_empty():
		return true
	for k in card.def.requires:
		if territory.keywords.has(k):
			return true
	return false


static func requires_error(card: CardInstance) -> String:
	return "%s needs a territory with %s." % [card.def.name, CardDef.keyword_names(card.def.requires)]


## The settled territories building card can go on: room, a free worker and a required keyword. One pass over the
## tableau (294) counts what free_slots and free_workers would for each territory.
static func building_targets(e: GameEngine, card: CardInstance) -> Array[int]:
	var out: Array[int] = []
	var tableau := e.zone("tableau").cards
	var tiers := Population.tiers(e)
	var slots := {}  # territory uid -> city slots on it minus the buildings on it (see total_slots, free_slots)
	var workers := {}  # territory uid -> cards using its workers (see free_workers)
	for c in tableau:
		if c.def.type == CardDef.CITY:
			slots[c.territory_uid] = slots.get(c.territory_uid, 0) + c.def.slots
		elif c.def.type == CardDef.BUILDING and not c.def.is_upgrade():
			slots[c.territory_uid] = slots.get(c.territory_uid, 0) - 1
		if c.def.uses_worker():
			workers[c.territory_uid] = workers.get(c.territory_uid, 0) + 1
	var pop_on := e.population_on()
	for territory in tableau:
		if territory.def.type != CardDef.TERRITORY or not meets_requires(card, territory):
			continue
		var room: int = territory.def.slots + Population.tier_slots(tiers, territory.pop) + slots.get(territory.uid, 0)
		if room > 0 and (not pop_on or territory.pop - workers.get(territory.uid, 0) > 0):
			out.append(territory.uid)
	return out


## The settled territories a unit can be recruited on (160): any with a free worker; a unit takes no slot.
static func unit_targets(e: GameEngine) -> Array[int]:
	var out: Array[int] = []
	for territory in e.zone("tableau").cards:
		if territory.def.type == CardDef.TERRITORY and Population.has_worker(e, territory):
			out.append(territory.uid)
	return out


## Why building card has no territory to go on.
static func no_building_target_error(e: GameEngine, card: CardInstance) -> String:
	var slot_found := false
	for territory in e.zone("tableau").cards:
		if territory.def.type == CardDef.TERRITORY and meets_requires(card, territory):
			if has_room(e, territory):
				return "No territory with a free worker."
			slot_found = true
	return "No territory with a free slot." if slot_found else requires_error(card)


static func territory_of(e: GameEngine, card: CardInstance) -> CardInstance:
	if card.territory_uid < 0:
		return null
	return e.zone("tableau").find(card.territory_uid)


## What is built on settled territory uid: {cities, buildings, idle}, or {} when uid isn't a territory in the tableau.
static func summary(e: GameEngine, uid: int) -> Dictionary:
	var territory := e.zone("tableau").find(uid)
	if territory == null or territory.def.type != CardDef.TERRITORY:
		return {}
	var cities := 0
	for card in e.zone("tableau").cards:
		if card.def.type == CardDef.CITY and card.territory_uid == uid:
			cities += 1
	var buildings := buildings_on(e, uid)
	return {"cities": cities, "buildings": buildings.size(), "idle": buildings.filter(func(b): return e.is_idle(b.uid)).size()}


static func status(e: GameEngine, uid: int) -> Dictionary:
	if summary(e, uid).is_empty():
		return {}
	var out := {"free_slots": e.free_slots(uid), "total_slots": e.total_slots(uid), "pop": e.pop(uid),
		"housing": e.housing(uid), "free_workers": e.free_workers(uid)}
	if Population.tier(e, uid) >= 0:  # with tiers on (281)
		out["tier_name"] = Population.tier_name(e, uid)
		out["next_tier_pop"] = Population.next_tier_pop(e, uid)
	return out


static func tooltip(e: GameEngine, uid: int) -> String:
	var s := status(e, uid)
	if s.is_empty():
		return ""
	var lines: PackedStringArray = ["Building slots: %d free of %d" % [s.free_slots, s.total_slots]]
	if e.population_on():
		lines.append("Pop %d, housing %d" % [s.pop, s.housing])
		if s.has("tier_name"):
			lines.append(_tier_line(e, uid))
		lines.append("Free workers: %d (each building or unit needs one)" % s.free_workers)
	var d := Military.defense_parts(e, uid)
	lines.append("Defence %d: units %d, walls %d, cities %d, terrain %d" % [d.total, d.units, d.buildings, d.cities,
		d.terrain])
	var keywords: Array[String] = e.zone("tableau").find(uid).keywords
	if not keywords.is_empty():
		lines.append("Keywords: " + ", ".join(PackedStringArray(keywords.map(func(k): return k.capitalize()))))
	var raids := Military.raid_warning(e, uid)
	if raids != "":
		lines.append(raids)
	return "\n".join(lines)


## Territory uid's tier and the next one's pop ("Village: a Town at 8 pop"), or just the name at the top tier (281).
static func _tier_line(e: GameEngine, uid: int) -> String:
	var i := Population.tier(e, uid)
	var all := Population.tiers(e)
	if i + 1 >= all.size():
		return all[i].name
	return "%s: %s at %d pop" % [all[i].name, Population.with_article(all[i + 1].name), all[i + 1].pop]


static func groups(e: GameEngine) -> Array[Dictionary]:
	var members := {}  # territory uid or -1 -> Array[int]
	for card in e.zone("tableau").cards:
		var key := -1
		if card.def.type == CardDef.TERRITORY:
			key = card.uid
		elif card.def.type == CardDef.UNIT and settled(e, card.station_uid) != null:  # where it stands (163)
			key = card.station_uid
		elif territory_of(e, card) != null:
			key = card.territory_uid
		if not members.has(key):
			members[key] = [] as Array[int]
		if card.def.type == CardDef.TERRITORY:
			members[key].push_front(card.uid)
		else:
			members[key].append(card.uid)
	var out: Array[Dictionary] = []
	for key in members:
		if key != -1:
			out.append({"territory": key, "cards": members[key]})
	if members.has(-1):
		out.append({"territory": -1, "cards": members[-1]})
	return out


static func explore(e: GameEngine, n: int, source: CardInstance) -> void:
	var territory_deck := e.zone("territory_deck")
	var reveal := e.zone("reveal")
	for i in n:
		if territory_deck.is_empty():
			break
		reveal.add(territory_deck.take_top())
	if reveal.is_empty():
		e._log("  %s: no territories left to explore." % source.def.name)
	elif reveal.size() == 1:
		var card := reveal.take_top()
		e.zone("frontier").add(card)
		e._log("  %s: discovered %s." % [source.def.name, card.def.name])
	else:
		var options: Array[int] = []
		for card in reveal.cards:
			options.append(card.uid)
		options.reverse()  # top first
		e.state.pending = {"kind": GameEngine.PENDING_EXPLORE, "options": options, "source": source.uid}
		e._log("  %s: choose a territory to keep." % source.def.name)


## Why territory uid can't be chosen now, or "".
static func choose_error(e: GameEngine, uid: int) -> String:
	var owed := e._owed_error(GameEngine.PENDING_EXPLORE, "There is no territory to choose.")
	if owed != "":
		return owed
	if not e.state.pending.options.has(uid):
		return "That territory isn't an option."
	return ""


static func choose(e: GameEngine, uid: int) -> bool:
	if choose_error(e, uid) != "":
		return false
	var reveal := e.zone("reveal")
	var kept := reveal.find(uid)
	reveal.remove(kept)
	e.zone("frontier").add(kept)
	for card in reveal.take_all():
		e.zone("territory_deck").add_bottom(card)
	e._log("  %s: kept %s." % [_card_name(e, e.state.pending.source), kept.def.name])
	e.state.pending = {}
	e.changed.emit()
	return true


## The name of card uid, wherever it is ("" if it is nowhere).
static func _card_name(e: GameEngine, uid: int) -> String:
	for z in GameEngine.ZONES:
		var card := e.zone(z).find(uid)
		if card != null:
			return card.def.name
	return ""


static func settle(e: GameEngine, territory_uid: int, city_id: String, source: CardInstance) -> void:
	var territory := e.zone("frontier").find(territory_uid)
	e.zone("frontier").remove(territory)
	e.zone("tableau").add(territory)
	if e.population_on():
		territory.pop = 1
	var city := e.create_card(city_id, "tableau", source)
	city.territory_uid = territory.uid
	name_settled(e, territory)
	e._log("  %s: settled %s." % [source.def.name, territory.def.name])
	e._milestone(GameEngine.MILESTONE_CITY)


## The territory_resources table territory def rolls from: its own, else its terrain's (130); [] if neither.
static func resource_table(config: Dictionary, def: CardDef) -> Array:
	var tables: Dictionary = config.get("territory_resources", {})
	if tables.has(def.id):
		return tables[def.id]
	for k in def.keywords:
		if config.get("terrains", []).has(k):
			return tables.get(k, [])
	return []


## The starting territory card_id, rolled from a copy of the rng so whichever territory a civilization starts on
## leaves the game rng where it was (111).
static func make_home(e: GameEngine, card_id: String) -> CardInstance:
	var game_rng := e.rng
	e.rng = game_rng.copy()
	var card := make(e, card_id)
	e.rng = game_rng
	return card


## A new territory card_id with resource keywords rolled from its resource_table, if any.
static func make(e: GameEngine, card_id: String) -> CardInstance:
	var card := e._make_card(card_id)
	var table := resource_table(e.config, card.def)
	if table.is_empty():
		return card
	var total := 0
	for option in table:
		total += option.weight
	var roll := e.rng.randi_range(1, total)
	for option in table:
		roll -= option.weight
		if roll <= 0:
			card.keywords.append_array(option.keywords)
			break
	return card


## Gives newly settled territory the civilization's next city name (248), then the list again with numerals (II,
## III, …). Without a civilization or its city_names the territory keeps its card's name.
static func name_settled(e: GameEngine, territory: CardInstance) -> void:
	var civ := e.zone("civilization")
	var names: Array[String] = civ.cards[0].def.city_names if not civ.is_empty() else ([] as Array[String])
	if names.is_empty():
		return
	var n := e.state.names_given
	e.state.names_given += 1
	var cycle := floori(n / float(names.size())) + 1
	territory.city_name = names[n % names.size()] + ("" if cycle == 1 else " " + _numeral(cycle))


static func _numeral(n: int) -> String:
	var out := ""
	for step in [[1000, "M"], [900, "CM"], [500, "D"], [400, "CD"], [100, "C"], [90, "XC"], [50, "L"], [40, "XL"],
			[10, "X"], [9, "IX"], [5, "V"], [4, "IV"], [1, "I"]]:
		while n >= step[0]:
			out += step[1]
			n -= step[0]
	return out


## The name territory uid goes by: its city name once settled and named, else its card's name; "" for no territory.
static func territory_name(e: GameEngine, uid: int) -> String:
	for z in GameEngine.ZONES:
		var card := e.zone(z).find(uid)
		if card != null and card.def.type == CardDef.TERRITORY:
			return card.shown_name()
	return ""


static func rename_error(e: GameEngine, uid: int, name: String) -> String:
	var blocked := e._blocked_error("rename_territory")
	if blocked != "":
		return blocked
	if settled(e, uid) == null:
		return "Only a settled territory can be renamed."
	var trimmed := name.strip_edges()
	if trimmed == "":
		return "Enter a name."
	if trimmed.length() > GameEngine.MAX_TERRITORY_NAME:
		return "A name can be at most %d characters." % GameEngine.MAX_TERRITORY_NAME
	return ""


static func rename(e: GameEngine, uid: int, name: String) -> bool:
	if rename_error(e, uid, name) != "":
		return false
	settled(e, uid).city_name = name.strip_edges()
	e.changed.emit()
	return true
