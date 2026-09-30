class_name DataLoader
extends RefCounted
## Loads and validates the JSON game data. Collects every problem (not just
## the first) with file, card and field, so a bad data edit is easy to fix.
## Unknown fields are warnings, not errors.

const CARD_TYPES := CardDef.TYPES
const SEPARATE_DECK_TYPES: Array[String] = [CardDef.TERRITORY, CardDef.TECH, CardDef.EVENT, CardDef.CIVILIZATION, CardDef.GOVERNMENT]  # never in the main deck
## Fields every card type may have.
const CARD_FIELDS: Array[String] = ["id", "name", "type", "cost", "vp", "tags", "effects", "text", "requires"]
## Fields only some card types use: field -> those types, the first being the one the field is for. On any other
## type the field is ignored with a warning ("'era' only applies to techs (ignored)").
const TYPE_FIELDS := {
	"slots": [CardDef.TERRITORY, CardDef.CITY],
	"housing": [CardDef.TERRITORY, CardDef.BUILDING],
	"famine_guard": [CardDef.BUILDING],
	"keywords": [CardDef.TERRITORY],
	"prereq": [CardDef.TECH],
	"prereq_discount": [CardDef.TECH],
	"era": [CardDef.TECH],
	"discard": [CardDef.EVENT],
}
const TYPE_PLURALS := {CardDef.TERRITORY: "territories", CardDef.BUILDING: "buildings", CardDef.TECH: "techs", CardDef.EVENT: "events"}
## Card types that never sit on a territory, so their effects can't use a keyword or need a target.
const NO_TERRITORY_TYPES: Array[String] = [CardDef.TECH, CardDef.EVENT, CardDef.GOVERNMENT]
## The keys of an event's discard object (its discard conditions). Only a duration so far.
const DISCARD_CONDITIONS: Array[String] = ["turns"]
## Population block fields: name -> [minimum, default].
const POPULATION_FIELDS := {"start": [1, 2], "food_upkeep": [0, 1], "vp_per_pop": [0, 1]}
const CONFIG_FIELDS: Array[String] = ["resources", "turn_limit", "hand_size", "hand_limit", "deck_model", "starting", "deck", "keywords", "territory_deck", "research_deck", "era_unlocks", "population", "supply", "resource_keywords", "territory_resources", "event_deck", "civilizations", "era_names"]
const SUPPLY_TYPES: Array[String] = [CardDef.ACTION, CardDef.BUILDING]  # the only card types the supply sells
const DECK_MODELS: Array[String] = ["fixed"]  # "deckbuilding" and "era" are planned


## Returns {cards, config, errors, warnings}. Only use cards/config when errors is empty.
static func load_all(cards_path: String, config_path: String) -> Dictionary:
	var errors: Array[String] = []
	var warnings: Array[String] = []
	var result := {"cards": {}, "config": {}, "errors": errors, "warnings": warnings}
	var cards_raw: Variant = read_json(cards_path, errors)
	var config_raw: Variant = read_json(config_path, errors)
	if not errors.is_empty():
		return result
	var config_src := config_path.get_file()
	var resources := parse_resources(config_raw, config_src, errors)
	var keyword_errors: Array[String] = []  # reported by parse_config
	var keywords := parse_keywords(config_raw, config_src, keyword_errors)
	var resource_keywords := parse_keywords(config_raw, config_src, keyword_errors, "resource_keywords")
	result.cards = parse_cards(cards_raw, resources, cards_path.get_file(), errors, warnings, keywords, resource_keywords)
	result.config = parse_config(config_raw, resources, result.cards, config_src, errors, warnings)
	return result


static func read_json(path: String, errors: Array[String]) -> Variant:
	if not FileAccess.file_exists(path):
		errors.append("%s: file not found" % path)
		return null
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		errors.append("%s: JSON syntax error on line %d: %s" % [path.get_file(), json.get_error_line(), json.get_error_message()])
		return null
	return json.data


static func parse_resources(raw: Variant, src: String, errors: Array[String]) -> Array[String]:
	var out: Array[String] = []
	var list: Variant = raw.get("resources", [GameEngine.FOOD]) if raw is Dictionary else null
	if not (list is Array) or list.is_empty():
		errors.append("%s: 'resources' must be a non-empty array of names" % src)
		return out
	for r in list:
		if r is String:
			out.append(r)
		else:
			errors.append("%s: resource names must be strings" % src)
	return out


## The config's keyword list in field ("keywords" for terrain, "resource_keywords" for rolled ones;
## default empty).
static func parse_keywords(raw: Variant, src: String, errors: Array[String], field := "keywords") -> Array[String]:
	var out: Array[String] = []
	var list: Variant = raw.get(field, []) if raw is Dictionary else []
	if not (list is Array):
		errors.append("%s: '%s' must be an array of keyword ids" % [src, field])
		return out
	for k in list:
		if k is String:
			out.append(k)
		else:
			errors.append("%s: keyword ids must be strings" % src)
	return out


## Card definitions by id. keywords are terrain keywords (territories may print them); resource_keywords
## are only rolled onto territories (config territory_resources). requires and effect keyword accept both.
static func parse_cards(raw: Variant, resources: Array[String], src: String, errors: Array[String], warnings: Array[String], keywords: Array[String] = [], resource_keywords: Array[String] = []) -> Dictionary:
	var db := {}
	if not (raw is Dictionary) or not (raw.get("cards") is Array):
		errors.append("%s: expected an object with a \"cards\" array" % src)
		return db
	var ctx := {"resources": resources, "zones": GameEngine.ZONES, "keywords": keywords + resource_keywords, "resource_keywords": resource_keywords}
	var list: Array = raw.cards
	for i in list.size():
		var c: Variant = list[i]
		var where := "%s: cards[%d]" % [src, i]
		if not (c is Dictionary):
			errors.append("%s: must be an object" % where)
			continue
		if c.get("id") is String:
			where = "%s: card '%s'" % [src, c.id]
		var errs: Array[String] = []
		var warns: Array[String] = []
		var def := _parse_card(c, ctx, errs, warns)
		if def.id != "" and db.has(def.id):
			errs.append("duplicate id")
		for m in errs:
			errors.append("%s: %s" % [where, m])
		for m in warns:
			warnings.append("%s: %s" % [where, m])
		if errs.is_empty():
			db[def.id] = def

	# Second pass: cross-card references.
	for id in db:
		var prereq: String = db[id].prereq
		if prereq == id:
			errors.append("%s: card '%s': prereq: a tech can't be its own prerequisite" % [src, id])
		elif prereq != "" and not db.has(prereq):
			errors.append("%s: card '%s': prereq: unknown card '%s'" % [src, id, prereq])
		elif prereq != "" and db[prereq].type != CardDef.TECH:
			errors.append("%s: card '%s': prereq: '%s' is not a tech" % [src, id, prereq])
		for e in db[id].effects:
			for ref in e.referenced_cards():
				if not db.has(ref):
					errors.append("%s: card '%s': '%s' effect refers to unknown card '%s'" % [src, id, e.op, ref])
			var ref_errors: Array[String] = []
			e.check_references(db, ref_errors)
			for m in ref_errors:
				errors.append("%s: card '%s': '%s' effect: %s" % [src, id, e.op, m])
	return db


static func _parse_card(c: Dictionary, ctx: Dictionary, errs: Array[String], warns: Array[String]) -> CardDef:
	var def := CardDef.new()
	def.id = Fields.read_string(c, "id", errs)
	def.name = Fields.read_string(c, "name", errs)
	def.type = Fields.read_string(c, "type", errs, CARD_TYPES)
	def.vp = Fields.read_int(c, "vp", errs, 0, 0)
	def.text = Fields.read_string(c, "text", errs, [], "")

	var cost: Variant = c.get("cost", {})
	if cost is Dictionary:
		for r in cost:
			var n: Variant = Fields.as_int(cost[r])
			if not ctx.resources.has(r):
				errs.append("cost: unknown resource '%s'" % r)
			elif typeof(n) != TYPE_INT or n < 0:
				errs.append("cost: '%s' must be an integer >= 0" % r)
			else:
				def.cost[r] = n
	else:
		errs.append("'cost' must be an object like {\"food\": 2}")

	if def.type == CardDef.TECH and not (def.cost.size() == 1 and def.cost.get(GameEngine.WEALTH, 0) >= 1):
		errs.append("cost: a tech must cost wealth only, at least 1 (like {\"wealth\": 2})")
	if def.type == CardDef.EVENT and not def.cost.is_empty():
		errs.append("cost: an event can't have a cost")
	if def.type == CardDef.EVENT and def.vp != 0:
		errs.append("vp: an event can't score VP")

	var tags: Variant = c.get("tags", [])
	if tags is Array:
		for t in tags:
			if t is String:
				def.tags.append(t)
			else:
				errs.append("tags must be strings")
	else:
		errs.append("'tags' must be an array of strings")

	var effects: Variant = c.get("effects", [])
	if effects is Array:
		for j in effects.size():
			var e_errs: Array[String] = []
			var e_warns: Array[String] = []
			var effect := EffectRegistry.create(effects[j], ctx, e_errs, e_warns)
			for m in e_errs:
				errs.append("effects[%d]: %s" % [j, m])
			for m in e_warns:
				warns.append("effects[%d]: %s" % [j, m])
			if effect != null and e_errs.is_empty() and effect.trigger == "start":
				var start_problem := _start_effect_problem(effect, def.type)
				if start_problem != "":
					errs.append("effects[%d]: %s" % [j, start_problem])
					continue
			if effect != null and e_errs.is_empty() and NO_TERRITORY_TYPES.has(def.type):
				var problem := _no_territory_effect_problem(effect, def.type)
				if problem != "":
					errs.append("effects[%d]: %s" % [j, problem])
					continue
			if effect != null and e_errs.is_empty():
				def.effects.append(effect)
	else:
		errs.append("'effects' must be an array")

	if def.type == CardDef.TERRITORY:
		def.slots = Fields.read_int(c, "slots", errs, 0)
		def.housing = Fields.read_int(c, "housing", errs, 1, def.slots + 2)
		var kws: Variant = c.get("keywords", [])
		if kws is Array:
			for k in kws:
				if not (k is String):
					errs.append("keywords must be strings")
				elif ctx.resource_keywords.has(k):
					errs.append("keywords: '%s' is a resource keyword; roll it with territory_resources instead" % k)
				elif not ctx.keywords.has(k):
					errs.append("unknown keyword '%s'" % k)
				else:
					def.keywords.append(k)
		else:
			errs.append("'keywords' must be an array of keyword ids")
	elif def.type == CardDef.CITY:
		def.slots = Fields.read_int(c, "slots", errs, 0, 0)
	elif def.type == CardDef.BUILDING:
		def.housing = Fields.read_int(c, "housing", errs, 1, 0)
		def.famine_guard = Fields.read_int(c, "famine_guard", errs, 1, 0)
	for key in TYPE_FIELDS:
		var types: Array = TYPE_FIELDS[key]
		if c.has(key) and not types.has(def.type):
			warns.append("'%s' only applies to %s (ignored)" % [key, TYPE_PLURALS[types[0]]])

	if def.type == CardDef.EVENT:
		def.discard_turns = _parse_discard(c.get("discard", {}), errs)

	if def.type == CardDef.TECH:
		if c.has("era"):
			var era: Variant = Fields.as_int(c.era)
			if typeof(era) != TYPE_INT or era < 1:
				errs.append("era: must be an integer >= 1")
			else:
				def.era = era
		def.prereq = Fields.read_string(c, "prereq", errs, [], "")
		if c.has("prereq_discount"):
			var discount: Variant = Fields.as_int(c.prereq_discount)
			if def.prereq == "":
				warns.append("'prereq_discount' needs 'prereq' (ignored)")
			elif typeof(discount) != TYPE_INT or discount < 1:
				errs.append("prereq_discount: must be an integer >= 1")
			else:
				def.prereq_discount = discount

	var requires: Variant = c.get("requires", [])
	if requires is Array:
		for k in requires:
			if not (k is String):
				errs.append("requires must be keyword ids")
			elif not ctx.keywords.has(k):
				errs.append("unknown keyword '%s' in 'requires'" % k)
			else:
				def.requires.append(k)
	else:
		errs.append("'requires' must be an array of keyword ids")

	for key in c:
		if not CARD_FIELDS.has(key) and not TYPE_FIELDS.has(key):
			warns.append("unknown field '%s'" % key)
	return def


## Why start effect can't be on a card of type, or "" if it can: only civilizations start, and nobody can pick a
## target or answer a choice before the first turn.
static func _start_effect_problem(effect: Effect, type: String) -> String:
	if type != CardDef.CIVILIZATION:
		return "trigger 'start' only works on civilizations"
	if effect.target_zone() != "" or effect.opens_choice():
		return "'%s' can't trigger on start (it needs a target or a choice)" % effect.op
	return ""


## Why effect can't be on a card of type (a tech or an event, which has no territory to aim at), or "" if it can.
static func _no_territory_effect_problem(effect: Effect, type: String) -> String:
	var article := "an" if type == CardDef.EVENT else "a"
	if effect.keyword != "":
		return "%s %s effect can't use 'keyword' (%s %s has no territory)" % [article, type, article, type]
	if effect.target_zone() != "":
		return "%s %s effect can't need a target" % [article, type]
	if effect.needs_own_territory():
		return "%s %s effect can't act on its own territory (%s %s has none; use 'each')" % [article, type, article, type]
	return ""


## An event's discard object {"turns": n} as its number of turns (default 1). Unknown conditions are errors.
static func _parse_discard(raw: Variant, errs: Array[String]) -> int:
	if not (raw is Dictionary):
		errs.append("discard: must be an object like {\"turns\": 1}")
		return 1
	for key in raw:
		if not DISCARD_CONDITIONS.has(key):
			errs.append("discard: unknown condition '%s' (known: %s)" % [key, ", ".join(PackedStringArray(DISCARD_CONDITIONS))])
	var turns: Variant = Fields.as_int(raw.get("turns", 1))
	if typeof(turns) != TYPE_INT or turns < 1:
		errs.append("discard: 'turns' must be an integer >= 1")
		return 1
	return turns


## Returns a normalized config: {resources, keywords, turn_limit, hand_size, hand_limit, deck_model,
## starting: {resources, tableau, territory, civilization}, deck: {card_id: count}, territory_deck: {card_id: count}, research_deck: {card_id: count},
## event_deck: {card_id: count},
## population: {start, food_upkeep, vp_per_pop}, or {} when the config has no population block (rules off),
## supply: {card_id: {price, count, locked}}, {} when there is none,
## civilizations: the civilization ids a game may start as, in order ([] when there is no list)}.
static func parse_config(raw: Variant, resources: Array[String], cards: Dictionary, src: String, errors: Array[String], warnings: Array[String]) -> Dictionary:
	if not (raw is Dictionary):
		errors.append("%s: must be a JSON object" % src)
		return {}
	var errs: Array[String] = []
	var config := {
		"resources": resources,
		"keywords": parse_keywords(raw, src, errors),
		"resource_keywords": parse_keywords(raw, src, errors, "resource_keywords"),
		"turn_limit": Fields.read_int(raw, "turn_limit", errs, 1, 20),
		"hand_size": Fields.read_int(raw, "hand_size", errs, 1, 5),
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
		"supply": {},
		"territory_resources": {},
		"civilizations": [] as Array[String],
	}
	for k in config.resource_keywords:
		if config.keywords.has(k):
			errs.append("resource_keywords: '%s' is also in 'keywords'" % k)

	config.hand_limit = Fields.read_int(raw, "hand_limit", errs, config.hand_size, maxi(7, config.hand_size))

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
	config.territory_resources = _parse_territory_resources(raw.get("territory_resources", {}), cards, config.resource_keywords, errs)

	config.era_unlocks = _parse_era_unlocks(raw.get("era_unlocks", {}), errs, warnings, src)
	config.era_names = _parse_era_names(raw.get("era_names", {}), errs)

	if raw.has("population"):
		config.population = _parse_population(raw.population, cards, config.starting.territory, errs, warnings, src)

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
		if not POPULATION_FIELDS.has(key):
			warnings.append("%s: population: unknown field '%s'" % [src, key])
	if start_territory != "" and out.start > cards[start_territory].housing:
		errs.append("'population.start' (%d) is more than the housing of starting territory '%s' (%d)" % [out.start, start_territory, cards[start_territory].housing])
	return out


## Normalizes territory_resources {territory_id: [{keywords, weight}]}: each key a territory, each table a
## non-empty array of options whose keywords are resource keywords and whose weight is an integer >= 1.
static func _parse_territory_resources(raw: Variant, cards: Dictionary, resource_keywords: Array[String], errs: Array[String]) -> Dictionary:
	var out := {}
	if not (raw is Dictionary):
		errs.append("'territory_resources' must be an object like {\"hills\": [{\"keywords\": [\"gold\"], \"weight\": 1}]}")
		return out
	for id in raw:
		if not cards.has(id):
			errs.append("territory_resources: unknown card '%s'" % id)
			continue
		if cards[id].type != CardDef.TERRITORY:
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
