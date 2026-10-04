class_name ConfigLoader
extends RefCounted
## Parses and validates config.json against the parsed cards (split out of DataLoader, backlog 095). Collects every
## problem with file and field; unknown fields are warnings. DataLoader.load_all calls parse_config.

const SEPARATE_DECK_TYPES: Array[String] = [CardDef.TERRITORY, CardDef.TECH, CardDef.EVENT, CardDef.CIVILIZATION, CardDef.GOVERNMENT]  # never in the main deck
## Population block fields: name -> [minimum, default].
const POPULATION_FIELDS := {"start": [1, 2], "food_upkeep": [0, 1], "vp_per_pop": [0, 1]}
const CONFIG_FIELDS: Array[String] = ["resources", "turn_limit", "hand_size", "hand_limit", "deck_model", "starting", "deck", "keywords", "territory_deck", "research_deck", "era_unlocks", "population", "supply", "resource_keywords", "territory_resources", "event_deck", "civilizations", "era_names", "terrains", "unrest", "terrain_defense", "territory_value", "raid_min_size", "raid_gap"]
const SUPPLY_TYPES: Array[String] = [CardDef.ACTION, CardDef.BUILDING, CardDef.UNIT]  # the only card types the supply sells
const DECK_MODELS: Array[String] = ["fixed"]  # "deckbuilding" and "era" are planned


## Returns a normalized config: {resources, keywords, turn_limit, hand_size, hand_limit, deck_model,
## starting: {resources, tableau, territory, civilization}, deck: {card_id: count}, territory_deck: {card_id: count}, research_deck: {card_id: count},
## event_deck: {card_id: count},
## population: {start, food_upkeep, vp_per_pop}, or {} when the config has no population block (rules off),
## supply: {card_id: {price, count, locked}}, {} when there is none,
## civilizations: the civilization ids a game may start as, in order ([] when there is no list),
## unrest: {anarchy, max_counters, era_unrest, allowed_tag}, {} when there is none (145),
## terrain_defense: {keyword: int}, the defence each keyword gives a territory (161), {} when there is none,
## territory_value, raid_min_size, raid_gap: raid pacing (257), each 0 when unset}.
static func parse_config(raw: Variant, resources: Array[String], cards: Dictionary, src: String, errors: Array[String], warnings: Array[String]) -> Dictionary:
	if not (raw is Dictionary):
		errors.append("%s: must be a JSON object" % src)
		return {}
	var errs: Array[String] = []
	var config := {
		"resources": resources,
		"keywords": DataLoader.parse_keywords(raw, src, errors),
		"resource_keywords": DataLoader.parse_keywords(raw, src, errors, "resource_keywords"),
		"terrains": DataLoader.parse_keywords(raw, src, errors, "terrains"),
		"turn_limit": Fields.read_int(raw, "turn_limit", errs, 1, 20),
		"hand_size": Fields.read_int(raw, "hand_size", errs, 1, 5),
		"territory_value": Fields.read_int(raw, "territory_value", errs, 0, 0),
		"raid_min_size": Fields.read_int(raw, "raid_min_size", errs, 0, 0),
		"raid_gap": Fields.read_int(raw, "raid_gap", errs, 0, 0),
		"hand_limit": 0,
		"deck_model": Fields.read_string(raw, "deck_model", errs, DECK_MODELS, "fixed"),
		"starting": {"resources": {}, "tableau": [], "territory": "", "civilization": "", "government": ""},
		"deck": {},
		"territory_deck": {},
		"research_deck": {},
		"event_deck": {},
		"era_unlocks": {},
		"era_names": {},
		"population": {},
		"famine": {},  # population.famine, normalized: {card, max_counters} (083); {} with population off
		"supply": {},
		"territory_resources": {},
		"civilizations": [] as Array[String],
	}
	for k in config.resource_keywords:
		if config.keywords.has(k):
			errs.append("resource_keywords: '%s' is also in 'keywords'" % k)
	for k in config.terrains:
		if not config.keywords.has(k):
			errs.append("terrains: '%s' is not in 'keywords'" % k)
	_check_terrains(cards, config.terrains, errs)

	config.hand_limit = Fields.read_int(raw, "hand_limit", errs, config.hand_size, maxi(7, config.hand_size))
	for id in cards:  # 109: one card's hand_size modifier alone must fit under hand_limit
		var more: int = cards[id].modifiers.get(Modifiers.HAND_SIZE, 0)
		if config.hand_size + more > config.hand_limit:
			errs.append("card '%s': modifiers.hand_size %d takes hand_size %d past hand_limit %d" % [
				id, more, config.hand_size, config.hand_limit])

	var starting: Variant = raw.get("starting", {})
	if starting is Dictionary:
		var start_res: Variant = starting.get("resources", {})
		if start_res is Dictionary:
			for r in start_res:
				var n: Variant = Fields.as_int(start_res[r])
				if not resources.has(r):
					errs.append("starting.resources: unknown resource '%s'" % r)
				elif typeof(n) != TYPE_INT or n < 0:
					errs.append("starting.resources: '%s' must be an integer >= 0" % r)
				else:
					config.starting.resources[r] = n
		else:
			errs.append("starting.resources must be an object")
		var tableau: Variant = starting.get("tableau", [])
		if tableau is Array:
			for id in tableau:
				if cards.has(id):
					config.starting.tableau.append(id)
				else:
					errs.append("starting.tableau: unknown card '%s'" % id)
		else:
			errs.append("starting.tableau must be an array of card ids")
		var territory := Fields.read_string(starting, "territory", errs, [], "")
		if territory != "":
			if not cards.has(territory):
				errs.append("starting.territory: unknown card '%s'" % territory)
			elif cards[territory].type != CardDef.TERRITORY:
				errs.append("starting.territory: '%s' is not a territory" % territory)
			else:
				config.starting.territory = territory
		config.starting.civilization = _parse_starting_card(starting, CardDef.CIVILIZATION, cards, errs)
		config.starting.government = _parse_starting_card(starting, CardDef.GOVERNMENT, cards, errs)
	else:
		errs.append("'starting' must be an object")

	var deck: Variant = raw.get("deck")
	if deck is Dictionary and not deck.is_empty():
		config.deck = _parse_counts(deck, "deck", cards, "", errs)
	else:
		errs.append("'deck' must be a non-empty object like {\"farm\": 4}")

	var territory_deck: Variant = raw.get("territory_deck", {})
	if territory_deck is Dictionary:
		config.territory_deck = _parse_counts(territory_deck, "territory_deck", cards, CardDef.TERRITORY, errs)
	else:
		errs.append("'territory_deck' must be an object like {\"hills\": 2}")

	config.civilizations = _parse_civilizations(raw.get("civilizations", []), cards, errs)
	var start_civ: String = config.starting.civilization
	if start_civ != "" and raw.has("civilizations") and not config.civilizations.has(start_civ):
		errs.append("starting.civilization: '%s' is not in 'civilizations'" % start_civ)

	var research_deck: Variant = raw.get("research_deck", {})
	if research_deck is Dictionary:
		config.research_deck = _parse_counts(research_deck, "research_deck", cards, CardDef.TECH, errs)
	else:
		errs.append("'research_deck' must be an object like {\"pottery\": 1}")

	var event_deck: Variant = raw.get("event_deck", {})
	if event_deck is Dictionary:
		config.event_deck = _parse_counts(event_deck, "event_deck", cards, CardDef.EVENT, errs)
	else:
		errs.append("'event_deck' must be an object like {\"windfall\": 1}")

	config.supply = _parse_supply(raw.get("supply", {}), cards, errs)
	_check_unlocks(config, cards, errs)
	_check_start_buildings(config, cards, errs)
	config.territory_resources = _parse_territory_resources(raw.get("territory_resources", {}), cards, config.resource_keywords, config.terrains, errs)
	config.terrain_defense = _parse_terrain_defense(raw.get("terrain_defense", {}), config.keywords + config.resource_keywords, errs)

	config.era_unlocks = _parse_era_unlocks(raw.get("era_unlocks", {}), errs, warnings, src)
	config.era_names = _parse_era_names(raw.get("era_names", {}), errs)

	if raw.has("population"):
		config.population = _parse_population(raw.population, cards, config.starting.territory, errs, warnings, src)
		_check_homes_house_start(config, cards, errs)
		config.famine = _parse_famine(raw.population.get("famine") if raw.population is Dictionary else null, cards, resources, errs)
		var famine: String = config.famine.get("card", "")
		if config.event_deck.has(famine):
			errs.append("event_deck: '%s' is the famine card (it comes from hunger, never from the deck)" % famine)
	config.unrest = _parse_unrest(raw.unrest, config, cards, errs, warnings, src) if raw.has("unrest") else {}

	for key in raw:
		if not CONFIG_FIELDS.has(key):
			warnings.append("%s: unknown field '%s'" % [src, key])
	for m in errs:
		errors.append("%s: %s" % [src, m])
	return config


## Normalizes era_names {"1": "Stone Age"} to {1: "Stone Age"}: each key an era >= 1, each value a string.
static func _parse_era_names(raw: Variant, errs: Array[String]) -> Dictionary:
	var out := {}
	if not (raw is Dictionary):
		errs.append("'era_names' must be an object like {\"1\": \"Stone Age\"}")
		return out
	for key in raw:
		var era: Variant = int(key) if str(key).is_valid_int() else null
		if era == null or era < 1:
			errs.append("era_names: '%s' must be an era number >= 1" % key)
		elif not (raw[key] is String):
			errs.append("era_names: '%s' must be a name" % key)
		else:
			out[era] = raw[key]
	return out


## Normalizes era_unlocks {"2": {"pop": 8, "wealth": 15}} to {2: {pop, wealth}}: each key an era >= 2, each
## value at least one of pop and wealth, integers >= 1.
static func _parse_era_unlocks(raw: Variant, errs: Array[String], warnings: Array[String], src: String) -> Dictionary:
	var out := {}
	if not (raw is Dictionary):
		errs.append("'era_unlocks' must be an object like {\"2\": {\"pop\": 8}}")
		return out
	for key in raw:
		var era: Variant = int(key) if str(key).is_valid_int() else null
		if era == null or era < 2:
			errs.append("era_unlocks: '%s' must be an era number >= 2" % key)
			continue
		var value: Variant = raw[key]
		if not (value is Dictionary) or value.is_empty():
			errs.append("era_unlocks: era %d needs an object with 'pop' and/or 'wealth'" % era)
			continue
		var thresholds := {}
		for field in value:
			if not ["pop", GameEngine.WEALTH].has(field):
				warnings.append("%s: era_unlocks: era %d: unknown field '%s'" % [src, era, field])
				continue
			var n: Variant = Fields.as_int(value[field])
			if typeof(n) != TYPE_INT or n < 1:
				errs.append("era_unlocks: era %d: '%s' must be an integer >= 1" % [era, field])
			else:
				thresholds[field] = n
		if not thresholds.is_empty():
			out[era] = thresholds
	return out


## Normalizes the population block, filling in defaults. start must fit the starting territory's housing.
static func _parse_population(raw: Variant, cards: Dictionary, start_territory: String, errs: Array[String], warnings: Array[String], src: String) -> Dictionary:
	var out := {}
	if not (raw is Dictionary):
		errs.append("'population' must be an object")
		return out
	for field in POPULATION_FIELDS:
		var min_value: int = POPULATION_FIELDS[field][0]
		var n: Variant = Fields.as_int(raw.get(field, POPULATION_FIELDS[field][1]))
		if typeof(n) != TYPE_INT or n < min_value:
			errs.append("'population.%s' must be an integer >= %d" % [field, min_value])
			n = POPULATION_FIELDS[field][1]
		out[field] = n
	for key in raw:
		if not POPULATION_FIELDS.has(key) and key != "famine":
			warnings.append("%s: population: unknown field '%s'" % [src, key])
	if start_territory != "" and out.start > cards[start_territory].housing:
		errs.append("'population.start' (%d) is more than the housing of starting territory '%s' (%d)" % [out.start, start_territory, cards[start_territory].housing])
	return out


## population.start must fit the housing of each listed (or starting) civilization's home (111).
static func _check_homes_house_start(config: Dictionary, cards: Dictionary, errs: Array[String]) -> void:
	var civs: Array[String] = config.civilizations.duplicate()
	if config.starting.civilization != "" and not civs.has(config.starting.civilization):
		civs.append(config.starting.civilization)
	for civ in civs:
		var home: String = cards[civ].home if cards.has(civ) else ""
		if home != "" and cards.has(home) and config.population.get("start", 0) > cards[home].housing:
			errs.append("'population.start' (%d) is more than the housing of civilization '%s''s home '%s' (%d)" % [
				config.population.start, civ, home, cards[home].housing])


## Each listed (or starting) civilization's start buildings (133) must meet its home's keywords and fit its slots (the
## territory's plus the starting tableau's). The home is starting.territory for a civilization without one.
static func _check_start_buildings(config: Dictionary, cards: Dictionary, errs: Array[String]) -> void:
	var civs: Array[String] = config.civilizations.duplicate()
	if config.starting.civilization != "" and not civs.has(config.starting.civilization):
		civs.append(config.starting.civilization)
	for civ in civs:
		if not cards.has(civ):
			continue
		var home: String = cards[civ].home if cards[civ].home != "" else config.starting.territory
		if not cards.has(home):
			continue
		var slots: int = cards[home].slots
		for id in config.starting.tableau:
			if cards.has(id) and cards[id].type == CardDef.CITY:
				slots += cards[id].slots
		var built := 0
		for effect in cards[civ].effects_for("start"):
			var id: String = effect.get("card_id") if effect.op == "create" and effect.get("zone") == "tableau" else ""
			if not cards.has(id) or cards[id].type != CardDef.BUILDING:
				continue
			built += 1
			var req: Array = cards[id].requires
			if not req.is_empty() and not req.any(func(k): return cards[home].keywords.has(k)):
				errs.append("civilization '%s' starts with '%s', which needs %s; its home '%s' has none" % [
					civ, id, " or ".join(req), home])
		if built > slots:
			errs.append("civilization '%s' starts with %d buildings, more than its home '%s' has slots (%d)" % [
				civ, built, home, slots])


## Normalizes population.famine {card, max_counters, relief} (083, 084): required with population on; card is an
## event with no discard; relief (optional, {} when absent) is what relieve_famine costs. Returns {} when invalid.
static func _parse_famine(raw: Variant, cards: Dictionary, resources: Array[String], errs: Array[String]) -> Dictionary:
	if not (raw is Dictionary):
		errs.append("population.famine is required: an object like {\"card\": \"famine\", \"max_counters\": 3}")
		return {}
	var f_errs: Array[String] = []
	var card := Fields.read_string(raw, "card", f_errs)
	var max_counters := Fields.read_int(raw, "max_counters", f_errs, 1)
	var relief := _parse_relief(raw.get("relief", {}), resources, f_errs) if raw.has("relief") else {}
	for m in f_errs:
		errs.append("population.famine" + ("" if m.begins_with(".") else ": ") + m)
	if card != "" and not cards.has(card):
		errs.append("population.famine.card: unknown card '%s'" % card)
	elif card != "" and cards[card].type != CardDef.EVENT:
		errs.append("population.famine.card '%s' is not an event" % card)
	elif card != "" and cards[card].has_discard:
		errs.append("population.famine.card '%s' can't have a discard (the Famine ends when pop is fed)" % card)
	elif f_errs.is_empty():
		return {"card": card, "max_counters": max_counters, "relief": relief}
	return {}


## Normalizes the unrest block (145) {anarchy, max_counters, era_unrest (default 0), allowed_tag (default
## ""), renewal (147, only when given; 0 when absent), drain_pct (156, only when given: 0 to 100)}: only with unrest in
## resources; anarchy is an event (253) with no discard, never in event_deck. Returns {} when invalid.
static func _parse_unrest(raw: Variant, config: Dictionary, cards: Dictionary, errs: Array[String], warnings: Array[String], src: String) -> Dictionary:
	if not config.resources.has(GameEngine.UNREST):
		errs.append("unrest: needs '%s' in resources" % GameEngine.UNREST)
		return {}
	if not (raw is Dictionary):
		errs.append("unrest: must be an object like {\"anarchy\": \"anarchy\", \"max_counters\": 4}")
		return {}
	var u_errs: Array[String] = []
	var out := {}
	var id: Variant = raw.get("anarchy")
	if not raw.has("anarchy"):
		u_errs.append("unrest.anarchy: missing (an event id)")
	elif not (id is String and cards.has(id)):
		u_errs.append("unrest.anarchy: unknown card '%s'" % [id])
	elif cards[id].type != CardDef.EVENT:
		u_errs.append("unrest.anarchy '%s' is not an event" % id)
	elif cards[id].has_discard:
		u_errs.append("unrest.anarchy '%s' can't have a discard (Anarchy ends when its counters run out)" % id)
	elif config.event_deck.has(id):
		u_errs.append("unrest.anarchy '%s' can't be in event_deck (unrest brings it)" % id)
	else:
		out.anarchy = id
	for key in [["max_counters", 1, null], ["era_unrest", 0, 0]]:
		var n: Variant = Fields.as_int(raw.get(key[0], key[2]))
		if typeof(n) != TYPE_INT or n < key[1]:
			u_errs.append("unrest.%s: must be an integer >= %d" % [key[0], key[1]])
		else:
			out[key[0]] = n
	var tag: Variant = raw.get("allowed_tag", "")
	if tag is String:
		out.allowed_tag = tag
	else:
		u_errs.append("unrest.allowed_tag: must be a string (a tag)")
	if raw.has("renewal"):
		var renewal: Variant = Fields.as_int(raw.renewal)
		if typeof(renewal) != TYPE_INT or renewal < 0:
			u_errs.append("unrest.renewal: must be an integer >= 0")
		else:
			out.renewal = renewal
	if raw.has("drain_pct"):
		var pct: Variant = Fields.as_int(raw.drain_pct)
		if typeof(pct) != TYPE_INT or pct < 0 or pct > 100:
			u_errs.append("unrest.drain_pct: must be an integer from 0 to 100")
		else:
			out.drain_pct = pct
	for key in raw:
		if not ["anarchy", "max_counters", "era_unrest", "allowed_tag", "renewal", "drain_pct"].has(key):
			warnings.append("%s: unrest: unknown field '%s'" % [src, key])
	errs.append_array(u_errs)
	return out if u_errs.is_empty() else {}


## population.famine.relief as {resource: amount}: a non-empty object of known resources, amounts integers >= 1.
## Problems go to errs, each starting ".relief" (the caller prefixes "population.famine").
static func _parse_relief(raw: Variant, resources: Array[String], errs: Array[String]) -> Dictionary:
	if not (raw is Dictionary) or raw.is_empty():
		errs.append(".relief must be an object like {\"wealth\": 5}")
		return {}
	var out := {}
	for r in raw:
		var n: Variant = Fields.as_int(raw[r])
		if not resources.has(r):
			errs.append(".relief: unknown resource '%s'" % r)
		elif Fields.unpayable(r) != "":
			errs.append(".relief: " + Fields.unpayable(r))
		elif typeof(n) != TYPE_INT or n < 1:
			errs.append(".relief: '%s' must be an integer >= 1" % r)
		else:
			out[r] = n
	return out


## With terrains set (130), every territory card prints exactly one of them.
static func _check_terrains(cards: Dictionary, terrains: Array[String], errs: Array[String]) -> void:
	if terrains.is_empty():
		return
	for id in cards:
		var def: CardDef = cards[id]
		if def.type != CardDef.TERRITORY:
			continue
		var own: Array[String] = def.keywords.filter(func(k): return terrains.has(k))
		if own.size() != 1:
			var found := "none" if own.is_empty() else ", ".join(PackedStringArray(own.map(func(k): return "'%s'" % k)))
			errs.append("card '%s': keywords: needs exactly one terrain (one of %s), found %s" % [id, ", ".join(terrains), found])


## Normalizes territory_resources {key: [{keywords, weight}]}: each key a territory or a terrain (130), each table a
## non-empty array of options whose keywords are resource keywords and whose weight is an integer >= 1.
static func _parse_territory_resources(raw: Variant, cards: Dictionary, resource_keywords: Array[String], terrains: Array[String], errs: Array[String]) -> Dictionary:
	var out := {}
	if not (raw is Dictionary):
		errs.append("'territory_resources' must be an object like {\"hills\": [{\"keywords\": [\"gold\"], \"weight\": 1}]}")
		return out
	for id in raw:
		if cards.has(id) and terrains.has(id):
			errs.append("territory_resources: '%s' is both a territory and a terrain" % id)
			continue
		if not cards.has(id) and not terrains.has(id):
			errs.append("territory_resources: unknown card '%s'" % id)
			continue
		if cards.has(id) and cards[id].type != CardDef.TERRITORY:
			errs.append("territory_resources: '%s' is not a territory" % id)
			continue
		var table: Variant = raw[id]
		if not (table is Array) or table.is_empty():
			errs.append("territory_resources: '%s' must be a non-empty array of options like {\"keywords\": [\"gold\"], \"weight\": 1}" % id)
			continue
		var options: Array = []
		for i in table.size():
			var option := _parse_resource_option(table[i], "territory_resources: '%s'[%d]" % [id, i], resource_keywords, errs)
			if not option.is_empty():
				options.append(option)
		if options.size() == table.size():
			out[id] = options
	return out


## One territory_resources option as {keywords, weight}, or {} (with errors) if it's invalid.
static func _parse_resource_option(raw: Variant, where: String, resource_keywords: Array[String], errs: Array[String]) -> Dictionary:
	if not (raw is Dictionary):
		errs.append("%s must be an object like {\"keywords\": [\"gold\"], \"weight\": 1}" % where)
		return {}
	var valid := true
	var keywords: Array[String] = []
	var list: Variant = raw.get("keywords")
	if list is Array:
		for k in list:
			if k is String and resource_keywords.has(k):
				keywords.append(k)
			else:
				errs.append("%s: '%s' is not a resource keyword" % [where, k])
				valid = false
	else:
		errs.append("%s: 'keywords' must be an array of resource keywords" % where)
		valid = false
	var weight: Variant = Fields.as_int(raw.get("weight"))
	if typeof(weight) != TYPE_INT or weight < 1:
		errs.append("%s: 'weight' must be an integer >= 1" % where)
		valid = false
	return {"keywords": keywords, "weight": weight} if valid else {}


## Normalizes the supply {card_id: {price, count, locked}}: each card an action or building, price and count
## integers >= 1, locked a bool (default false; a locked pile opens with the unlock op).
static func _parse_supply(raw: Variant, cards: Dictionary, errs: Array[String]) -> Dictionary:
	var out := {}
	if not (raw is Dictionary):
		errs.append("'supply' must be an object like {\"scout\": {\"price\": 2, \"count\": 1}}")
		return out
	for id in raw:
		var entry: Variant = raw[id]
		if not cards.has(id):
			errs.append("supply: unknown card '%s'" % id)
			continue
		if not SUPPLY_TYPES.has(cards[id].type):
			errs.append("supply: '%s' is a %s" % [id, cards[id].type])
			continue
		if not (entry is Dictionary):
			errs.append("supply: '%s' must be an object like {\"price\": 2, \"count\": 1}" % id)
			continue
		var valid := true
		for field in ["price", "count"]:
			var n: Variant = Fields.as_int(entry.get(field))
			if typeof(n) != TYPE_INT or n < 1:
				errs.append("supply: '%s': '%s' must be an integer >= 1" % [id, field])
				valid = false
		var locked: Variant = entry.get("locked", false)
		if not (locked is bool):
			errs.append("supply: '%s': 'locked' must be true or false" % id)
			valid = false
		if valid:
			out[id] = {"price": Fields.as_int(entry.price), "count": Fields.as_int(entry.count), "locked": locked}
	return out


## Normalizes terrain_defense {keyword: int >= 1} (161): each key a config keyword or resource keyword.
static func _parse_terrain_defense(raw: Variant, keywords: Array[String], errs: Array[String]) -> Dictionary:
	var out := {}
	if not (raw is Dictionary):
		errs.append("'terrain_defense' must be an object like {\"mountain\": 1}")
		return out
	for k in raw:
		var n: Variant = Fields.as_int(raw[k])
		if not keywords.has(k):
			errs.append("terrain_defense: unknown keyword '%s'" % k)
		elif typeof(n) != TYPE_INT or n < 1:
			errs.append("terrain_defense: '%s' must be an integer >= 1" % k)
		else:
			out[k] = n
	return out


## Every unlock effect on a card the game uses (decks, starting tableau, supply) must name a supply pile.
static func _check_unlocks(config: Dictionary, cards: Dictionary, errs: Array[String]) -> void:
	var used := {}
	for field in ["deck", "research_deck", "event_deck", "supply"]:
		for id in config[field]:
			used[id] = true
	for id in config.starting.tableau:
		used[id] = true
	for id in used:
		if not cards.has(id):
			continue
		for effect in cards[id].effects:
			if effect.op == "unlock" and not config.supply.has(effect.card_id):
				errs.append("'%s' unlocks '%s', which has no supply pile" % [id, effect.card_id])


## The config's civilizations list: civilization ids, each once.
static func _parse_civilizations(raw: Variant, cards: Dictionary, errs: Array[String]) -> Array[String]:
	var out: Array[String] = []
	if not (raw is Array):
		errs.append("'civilizations' must be an array of civilization ids")
		return out
	for id in raw:
		if not (id is String) or not cards.has(id):
			errs.append("civilizations: unknown card '%s'" % [id])
		elif cards[id].type != CardDef.CIVILIZATION:
			errs.append("civilizations: '%s' is not a civilization" % id)
		elif out.has(id):
			errs.append("civilizations: '%s' is listed twice" % id)
		else:
			out.append(id)
	return out


## The card id in starting[type] (the field is named after the card type it must hold), or "" when it's absent or
## invalid.
static func _parse_starting_card(starting: Dictionary, type: String, cards: Dictionary, errs: Array[String]) -> String:
	var id: Variant = starting.get(type, "")
	if not (id is String):
		errs.append("starting.%s must be a card id" % type)
	elif id != "":
		if not cards.has(id):
			errs.append("starting.%s: unknown card '%s'" % [type, id])
		elif cards[id].type != type:
			errs.append("starting.%s: '%s' is not a %s" % [type, id, type])
		else:
			return id
	return ""


## Normalizes a {card_id: count} deck. required: the card type the deck must hold ("territory", "tech" or
## "event"), or "" for the main deck, which holds none of those.
static func _parse_counts(deck: Dictionary, field: String, cards: Dictionary, required: String, errs: Array[String]) -> Dictionary:
	var out := {}
	for id in deck:
		var n: Variant = Fields.as_int(deck[id])
		if not cards.has(id):
			errs.append("%s: unknown card '%s'" % [field, id])
		elif required != "" and cards[id].type != required:
			errs.append("%s: '%s' is not a %s" % [field, id, required])
		elif required == "" and SEPARATE_DECK_TYPES.has(cards[id].type):
			errs.append("%s: '%s' is a %s" % [field, id, cards[id].type])
		elif typeof(n) != TYPE_INT or n < 1:
			errs.append("%s: count for '%s' must be an integer >= 1" % [field, id])
		else:
			out[id] = n
	return out
