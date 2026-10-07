class_name PopulationConfig
extends RefCounted
## Parses and validates config.json's population rules (split out of ConfigLoader, backlog 339): population with its
## famine and relief, the settlement tiers and the cards that name them, the sea slots (366), unrest, and the
## civilizations' homes. Problems go to ConfigLoader's errs (it prefixes the file) and warnings; ConfigLoader.parse_config
## calls parse, check_start_buildings and parse_sea_slots.

## Population block fields: name -> [minimum, default].
const POPULATION_FIELDS := {"start": [1, 2], "food_upkeep": [0, 1], "vp_per_pop": [0, 1]}


## Fills config's population, famine and unrest from raw (the whole config.json object), each {} when absent or
## invalid, and checks the cards that name a tier. config already holds resources, starting, civilizations and
## event_deck.
static func parse(raw: Dictionary, config: Dictionary, cards: Dictionary, errs: Array[String], warnings: Array[String], src: String) -> void:
	if raw.has("population"):
		config.population = _parse_population(raw.population, cards, config.starting.territory, errs, warnings, src)
		_check_homes_house_start(config, cards, errs)
		config.famine = _parse_famine(raw.population.get("famine") if raw.population is Dictionary else null, cards, config.resources, errs)
		var famine: String = config.famine.get("card", "")
		if config.event_deck.has(famine):
			errs.append("event_deck: '%s' is the famine card (it comes from hunger, never from the deck)" % famine)
	config.unrest = _parse_unrest(raw.unrest, config, cards, errs, warnings, src) if raw.has("unrest") else {}
	_check_tolerates(config.population.get("tiers", []), cards, errs, warnings, src)
	_check_building_tiers(config.population.get("tiers", []), cards, errs, warnings, src)


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
	out["tiers"] = _parse_tiers(raw.tiers, errs, warnings, src) if raw.has("tiers") else []
	for key in raw:
		if not POPULATION_FIELDS.has(key) and not key in ["famine", "tiers"]:
			warnings.append("%s: population: unknown field '%s'" % [src, key])
	if start_territory != "" and out.start > cards[start_territory].housing:
		errs.append("'population.start' (%d) is more than the housing of starting territory '%s' (%d)" % [out.start, start_territory, cards[start_territory].housing])
	return out


## Normalizes population.tiers (281): a non-empty array of {id, name, pop, slots}, ids unique and names non-empty,
## the first at pop 0, pop rising strictly and slots never falling.
static func _parse_tiers(raw: Variant, errs: Array[String], warnings: Array[String], src: String) -> Array:
	var out := []
	if not (raw is Array) or raw.is_empty():
		errs.append("'population.tiers' must be a non-empty array of tiers like {\"id\": \"hamlet\", \"name\": \"Hamlet\", \"pop\": 0, \"slots\": 0}")
		return out
	var ids := {}
	for i in raw.size():
		var where := "population.tiers[%d]" % i
		var t: Variant = raw[i]
		if not (t is Dictionary):
			errs.append("%s must be an object" % where)
			continue
		for field in ["id", "name"]:
			if not (t.get(field) is String) or t.get(field) == "":
				errs.append("%s.%s must be a non-empty string" % [where, field])
		if ids.has(t.get("id")):
			errs.append("%s.id '%s' is used by another tier" % [where, t.id])
		ids[t.get("id")] = true
		var tier := {"id": str(t.get("id", "")), "name": str(t.get("name", ""))}
		for field in ["pop", "slots"]:
			var n: Variant = Fields.as_int(t.get(field))
			if typeof(n) != TYPE_INT or n < 0:
				errs.append("%s.%s must be an integer >= 0" % [where, field])
				n = 0
			tier[field] = n
		if i == 0 and tier.pop != 0:
			errs.append("%s.pop must be 0 (the first tier starts at pop 0)" % where)
		if not out.is_empty() and tier.pop <= out[-1].pop:
			errs.append("%s.pop must be more than the tier before's (%d)" % [where, out[-1].pop])
		if not out.is_empty() and tier.slots < out[-1].slots:
			errs.append("%s.slots must be at least the tier before's (%d)" % [where, out[-1].slots])
		for key in t:
			if not key in ["id", "name", "pop", "slots"]:
				warnings.append("%s: %s: unknown field '%s'" % [src, where, key])
		out.append(tier)
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


## Each government's tolerates (282) must be a tier id in population.tiers; it gets that tier's name for its text. With
## tiers off it is ignored, with a warning.
static func _check_tolerates(tiers: Array, cards: Dictionary, errs: Array[String], warnings: Array[String], src: String) -> void:
	for id in cards:
		var def: CardDef = cards[id]
		if def.tolerates == "":
			continue
		if tiers.is_empty():
			warnings.append("%s: card '%s': 'tolerates' needs population.tiers (ignored)" % [src, id])
			continue
		var found := tiers.filter(func(t): return t.id == def.tolerates)
		if found.is_empty():
			errs.append("card '%s': 'tolerates' '%s' is not a tier id in population.tiers" % [id, def.tolerates])
		else:
			def.tolerates_name = found[0].name


## Each building's tier (301) names a tier in population.tiers, whose name it takes; with tiers off it is ignored.
static func _check_building_tiers(tiers: Array, cards: Dictionary, errs: Array[String], warnings: Array[String], src: String) -> void:
	for id in cards:
		var def: CardDef = cards[id]
		def.tier_name = ""
		if def.tier == "":
			continue
		if tiers.is_empty():
			warnings.append("%s: card '%s': 'tier' needs population.tiers (ignored)" % [src, id])
			continue
		var found := tiers.filter(func(t): return t.id == def.tier)
		if found.is_empty():
			errs.append("card '%s': tier: unknown tier '%s'" % [id, def.tier])
		else:
			def.tier_name = found[0].name


## Each listed (or starting) civilization's start buildings (133) must meet its home's keywords and fit its slots (the
## territory's plus the starting tableau's). The home is starting.territory for a civilization without one.
static func check_start_buildings(config: Dictionary, cards: Dictionary, errs: Array[String]) -> void:
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


## Normalizes sea_slots {keyword, tag, slots} (366): keyword a config keyword, tag a non-empty string, slots an integer
## >= 1; {} when it is absent or invalid.
static func parse_sea_slots(raw: Variant, keywords: Array[String], errs: Array[String]) -> Dictionary:
	if raw is Dictionary and raw.is_empty():
		return {}
	if not (raw is Dictionary):
		errs.append("'sea_slots' must be an object like {\"keyword\": \"coastal\", \"tag\": \"port\", \"slots\": 1}")
		return {}
	var problems: Array[String] = []
	var keyword: Variant = raw.get("keyword")
	if not (keyword is String) or not keywords.has(keyword):
		problems.append("sea_slots: 'keyword' must be one of the config keywords, not %s" % JSON.stringify(keyword))
	var tag: Variant = raw.get("tag")
	if not (tag is String) or tag == "":
		problems.append("sea_slots: 'tag' must be a non-empty string")
	var slots: Variant = Fields.as_int(raw.get("slots"))
	if typeof(slots) != TYPE_INT or slots < 1:
		problems.append("sea_slots: 'slots' must be an integer >= 1, not %s" % JSON.stringify(raw.get("slots")))
	errs.append_array(problems)
	return {} if not problems.is_empty() else {"keyword": keyword, "tag": tag, "slots": slots}
