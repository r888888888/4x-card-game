class_name ConfigLoader
extends RefCounted
## Parses and validates config.json against the parsed cards (split out of DataLoader, backlog 095). Collects every
## problem with file and field; unknown fields are warnings. DataLoader.load_all calls parse_config;
## PopulationConfig parses the population rules (339).

const SEPARATE_DECK_TYPES: Array[String] = [CardDef.TERRITORY, CardDef.TECH, CardDef.EVENT, CardDef.CIVILIZATION, CardDef.GOVERNMENT]  # never in the main deck
const CONFIG_FIELDS: Array[String] = ["resources", "turn_limit", "hand_size", "hand_limit", "deck_model", "starting", "deck", "keywords", "territory_deck", "research_deck", "era_unlocks", "population", "supply", "build_menu", "resource_keywords", "territory_resources", "event_deck", "civilizations", "era_names", "terrains", "unrest", "terrain_defense", "territory_value", "raid_min_size", "raid_gap", "raid_hoard_step", "raid_plunder_pct", "raid_plunder_era_pct", "sea_slots"]
const SUPPLY_TYPES: Array[String] = [CardDef.ACTION, CardDef.BUILDING, CardDef.UNIT]  # the only card types the supply sells
const BUILD_TYPES: Array[String] = [CardDef.BUILDING, CardDef.UNIT]  # the card types the build menu may hold (295)
const BUILD_FIELDS: Array[String] = ["locked", "once"]
const DECK_MODELS: Array[String] = ["fixed"]  # the deck grows through the supply, the build menu and techs instead
## An upgrade (300) can't be dealt or bought: it is only built from the build menu, onto its base.
const UPGRADE_ONLY_BUILT := "'%s' is an upgrade; build it from the build menu"


## Returns a normalized config: {resources, keywords, turn_limit, hand_size, hand_limit, deck_model,
## starting: {resources, tableau, territory, civilization}, deck: {card_id: count}, territory_deck: {card_id: count}, research_deck: {card_id: count},
## event_deck: {card_id: count},
## population: {start, food_upkeep, vp_per_pop, tiers} (tiers: [{id, name, pop, slots}], [] when off; 281), or {} when the config has no population block (rules off),
## supply: {card_id: {price, count, locked}}, {} when there is none,
## build_menu: {card_id: {locked, once}}, in the order the menu lists them, {} when there is none (295),
## civilizations: the civilization ids a game may start as, in order ([] when there is no list),
## unrest: {anarchy, max_counters, era_unrest, allowed_tag}, {} when there is none (145),
## terrain_defense: {keyword: int}, the defence each keyword gives a territory (161), {} when there is none,
## sea_slots: {keyword, tag, slots}, the extra slots a territory with the keyword has for buildings with the tag (366),
## {} when there is none,
## territory_value, raid_min_size, raid_gap: raid pacing (257), each 0 when unset,
## raid_hoard_step, raid_plunder_pct: how raids grow with the food and wealth held (374), each 0 (off) when unset,
## raid_plunder_era_pct: the plunder share's extra points per era after the first (377), 0 (off) when unset}.
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
		"raid_hoard_step": Fields.read_int(raw, "raid_hoard_step", errs, 0, 0),
		"raid_plunder_pct": Fields.read_int(raw, "raid_plunder_pct", errs, 0, 0),
		"raid_plunder_era_pct": Fields.read_int(raw, "raid_plunder_era_pct", errs, 0, 0),
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
		"build_menu": {},
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
	if config.raid_plunder_pct > 100:
		errs.append("'raid_plunder_pct' must be an integer from 0 to 100, not %d" % config.raid_plunder_pct)

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
	config.build_menu = _parse_build_menu(raw.get("build_menu", {}), cards, config.supply, errs, warnings, src)
	_check_unlocks(config, cards, errs)
	PopulationConfig.check_start_buildings(config, cards, errs)
	config.territory_resources = _parse_territory_resources(raw.get("territory_resources", {}), cards, config.resource_keywords, config.terrains, errs)
	config.terrain_defense = _parse_terrain_defense(raw.get("terrain_defense", {}), config.keywords + config.resource_keywords, errs)
	config.sea_slots = PopulationConfig.parse_sea_slots(raw.get("sea_slots", {}), config.keywords, errs)

	config.era_unlocks = _parse_era_unlocks(raw.get("era_unlocks", {}), errs, warnings, src)
	config.era_names = _parse_era_names(raw.get("era_names", {}), errs)

	PopulationConfig.parse(raw, config, cards, errs, warnings, src)

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
		if cards[id].is_upgrade():
			errs.append("supply: " + UPGRADE_ONLY_BUILT % id)
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


## Normalizes the build menu {card_id: {locked, once}} (295): each card a building or unit not also in the supply,
## locked and once bools (default false); another field is a warning.
static func _parse_build_menu(raw: Variant, cards: Dictionary, supply: Dictionary, errs: Array[String],
		warnings: Array[String], src: String) -> Dictionary:
	var out := {}
	if not (raw is Dictionary):
		errs.append("'build_menu' must be an object like {\"farm\": {}}")
		return out
	for id in raw:
		var entry: Variant = raw[id]
		if not cards.has(id):
			errs.append("build_menu: unknown card '%s'" % id)
			continue
		if not BUILD_TYPES.has(cards[id].type):
			errs.append("build_menu: '%s' is %s %s" % [id, "an" if cards[id].type == CardDef.ACTION else "a", cards[id].type])
			continue
		if supply.has(id):
			errs.append("build_menu: '%s' is also in the supply" % id)
			continue
		if not (entry is Dictionary):
			errs.append("build_menu: '%s' must be an object like {\"locked\": true}" % id)
			continue
		var valid := true
		for field in entry:
			if not BUILD_FIELDS.has(field):
				warnings.append("%s: build_menu: '%s': unknown field '%s'" % [src, id, field])
		for field in BUILD_FIELDS:
			if not (entry.get(field, false) is bool):
				errs.append("build_menu: '%s': '%s' must be true or false" % [id, field])
				valid = false
		if valid:
			out[id] = {"locked": entry.get("locked", false), "once": entry.get("once", false)}
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


## Every unlock effect on a card the game uses (decks, starting tableau, supply, build menu) must name a supply pile or
## a build-menu entry (295).
static func _check_unlocks(config: Dictionary, cards: Dictionary, errs: Array[String]) -> void:
	var used := {}
	for field in ["deck", "research_deck", "event_deck", "supply", "build_menu"]:
		for id in config[field]:
			used[id] = true
	for id in config.starting.tableau:
		used[id] = true
	for id in used:
		if not cards.has(id):
			continue
		for effect in cards[id].effects:
			if effect.op == "unlock" and not config.supply.has(effect.card_id) and not config.build_menu.has(effect.card_id):
				errs.append("'%s' unlocks '%s', which has no supply pile or build-menu entry" % [id, effect.card_id])


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
		elif required == "" and cards[id].is_upgrade():
			errs.append("%s: %s" % [field, UPGRADE_ONLY_BUILT % id])
		elif typeof(n) != TYPE_INT or n < 1:
			errs.append("%s: count for '%s' must be an integer >= 1" % [field, id])
		else:
			out[id] = n
	return out
