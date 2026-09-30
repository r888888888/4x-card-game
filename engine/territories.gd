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


static func keywords_of(e: GameEngine, uid: int) -> Array[String]:
	for z in GameEngine.ZONES:
		var card := e.zone(z).find(uid)
		if card != null:
			return card.keywords.duplicate() if card.def.type == CardDef.TERRITORY else [] as Array[String]
	return [] as Array[String]


static func total_slots(e: GameEngine, territory_uid: int) -> int:
	var territory := settled(e, territory_uid)
	if territory == null:
		return 0
	var total := territory.def.slots
	for card in e.zone("tableau").cards:
		if card.def.type == CardDef.CITY and card.territory_uid == territory_uid:
			total += card.def.slots
	return total


static func free_slots(e: GameEngine, territory_uid: int) -> int:
	if settled(e, territory_uid) == null:
		return 0
	return total_slots(e, territory_uid) - buildings_on(e, territory_uid).size()


## The buildings on territory territory_uid, in the order they were placed.
static func buildings_on(e: GameEngine, territory_uid: int) -> Array[CardInstance]:
	var out: Array[CardInstance] = []
	for card in e.zone("tableau").cards:
		if card.def.type == CardDef.BUILDING and card.territory_uid == territory_uid:
			out.append(card)
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


## The settled territories building card can go on: room, a free worker and a required keyword.
static func building_targets(e: GameEngine, card: CardInstance) -> Array[int]:
	var out: Array[int] = []
	for territory in e.zone("tableau").cards:
		if has_room(e, territory) and Population.has_worker(e, territory) and meets_requires(card, territory):
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


static func groups(e: GameEngine) -> Array[Dictionary]:
	var members := {}  # territory uid or -1 -> Array[int]
	for card in e.zone("tableau").cards:
		var key := -1
		if card.def.type == CardDef.TERRITORY:
			key = card.uid
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
		e.pending_choice = {"options": options, "source": source}
		e._log("  %s: choose a territory to keep." % source.def.name)


## Why territory uid can't be chosen now, or "".
static func choose_error(e: GameEngine, uid: int) -> String:
	if e.pending_choice.is_empty():
		return "There is no territory to choose."
	if not e.pending_choice.options.has(uid):
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
	e._log("  %s: kept %s." % [e.pending_choice.source.def.name, kept.def.name])
	e.pending_choice = {}
	e.changed.emit()
	return true


static func settle(e: GameEngine, territory_uid: int, city_id: String, source: CardInstance) -> void:
	var territory := e.zone("frontier").find(territory_uid)
	e.zone("frontier").remove(territory)
	e.zone("tableau").add(territory)
	if e.population_on():
		territory.pop = 1
	var city := e.create_card(city_id, "tableau", source)
	city.territory_uid = territory.uid
	e._log("  %s: settled %s." % [source.def.name, territory.def.name])


## A new territory card_id with resource keywords rolled from its territory_resources table, if any.
static func make(e: GameEngine, card_id: String) -> CardInstance:
	var card := e._make_card(card_id)
	var table: Array = e.config.get("territory_resources", {}).get(card_id, [])
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
