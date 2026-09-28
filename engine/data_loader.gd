class_name DataLoader
extends RefCounted
## Loads and validates the JSON game data. Collects every problem (not just
## the first) with file, card and field, so a bad data edit is easy to fix.
## Unknown fields are warnings, not errors.

const CARD_TYPES: Array[String] = ["action", "building", "city", "territory"]
const CARD_FIELDS: Array[String] = ["id", "name", "type", "cost", "vp", "tags", "effects", "text", "slots", "keywords"]
const CONFIG_FIELDS: Array[String] = ["resources", "turn_limit", "hand_size", "deck_model", "starting", "deck", "keywords", "territory_deck"]
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
	result.cards = parse_cards(cards_raw, resources, cards_path.get_file(), errors, warnings, keywords)
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


## JSON numbers are floats; accept whole numbers as ints. Returns null otherwise.
static func as_int(v: Variant) -> Variant:
	if v is int:
		return v
	if v is float and is_finite(v) and v == floorf(v):
		return int(v)
	return null


static func parse_resources(raw: Variant, src: String, errors: Array[String]) -> Array[String]:
	var out: Array[String] = []
	var list: Variant = raw.get("resources", ["food"]) if raw is Dictionary else null
	if not (list is Array) or list.is_empty():
		errors.append("%s: 'resources' must be a non-empty array of names" % src)
		return out
	for r in list:
		if r is String:
			out.append(r)
		else:
			errors.append("%s: resource names must be strings" % src)
	return out


## The config's "keywords" list (default empty).
static func parse_keywords(raw: Variant, src: String, errors: Array[String]) -> Array[String]:
	var out: Array[String] = []
	var list: Variant = raw.get("keywords", []) if raw is Dictionary else []
	if not (list is Array):
		errors.append("%s: 'keywords' must be an array of keyword ids" % src)
		return out
	for k in list:
		if k is String:
			out.append(k)
		else:
			errors.append("%s: keyword ids must be strings" % src)
	return out


static func parse_cards(raw: Variant, resources: Array[String], src: String, errors: Array[String], warnings: Array[String], keywords: Array[String] = []) -> Dictionary:
	var db := {}
	if not (raw is Dictionary) or not (raw.get("cards") is Array):
		errors.append("%s: expected an object with a \"cards\" array" % src)
		return db
	var ctx := {"resources": resources, "zones": GameEngine.ZONES, "keywords": keywords}
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
		for e in db[id].effects:
			for ref in e.referenced_cards():
				if not db.has(ref):
					errors.append("%s: card '%s': '%s' effect refers to unknown card '%s'" % [src, id, e.op, ref])
	return db


static func _parse_card(c: Dictionary, ctx: Dictionary, errs: Array[String], warns: Array[String]) -> CardDef:
	var def := CardDef.new()
	def.id = Effect.read_string(c, "id", errs)
	def.name = Effect.read_string(c, "name", errs)
	def.type = Effect.read_string(c, "type", errs, CARD_TYPES)
	def.vp = Effect.read_int(c, "vp", errs, 0, 0)
	def.text = Effect.read_string(c, "text", errs, [], "")

	var cost: Variant = c.get("cost", {})
	if cost is Dictionary:
		for r in cost:
			var n: Variant = as_int(cost[r])
			if not ctx.resources.has(r):
				errs.append("cost: unknown resource '%s'" % r)
			elif typeof(n) != TYPE_INT or n < 0:
				errs.append("cost: '%s' must be an integer >= 0" % r)
			else:
				def.cost[r] = n
	else:
		errs.append("'cost' must be an object like {\"food\": 2}")

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
			if effect != null and e_errs.is_empty():
				def.effects.append(effect)
	else:
		errs.append("'effects' must be an array")

	if def.type == "territory":
		def.slots = Effect.read_int(c, "slots", errs, 0)
		var kws: Variant = c.get("keywords", [])
		if kws is Array:
			for k in kws:
				if not (k is String):
					errs.append("keywords must be strings")
				elif not ctx.keywords.has(k):
					errs.append("unknown keyword '%s'" % k)
				else:
					def.keywords.append(k)
		else:
			errs.append("'keywords' must be an array of keyword ids")
	else:
		for key in ["slots", "keywords"]:
			if c.has(key):
				warns.append("'%s' only applies to territories (ignored)" % key)

	for key in c:
		if not CARD_FIELDS.has(key):
			warns.append("unknown field '%s'" % key)
	return def


## Returns a normalized config: {resources, keywords, turn_limit, hand_size, deck_model,
## starting: {resources, tableau, territory}, deck: {card_id: count}, territory_deck: {card_id: count}}.
static func parse_config(raw: Variant, resources: Array[String], cards: Dictionary, src: String, errors: Array[String], warnings: Array[String]) -> Dictionary:
	if not (raw is Dictionary):
		errors.append("%s: must be a JSON object" % src)
		return {}
	var errs: Array[String] = []
	var config := {
		"resources": resources,
		"keywords": parse_keywords(raw, src, errors),
		"turn_limit": Effect.read_int(raw, "turn_limit", errs, 1, 20),
		"hand_size": Effect.read_int(raw, "hand_size", errs, 1, 5),
		"deck_model": Effect.read_string(raw, "deck_model", errs, DECK_MODELS, "fixed"),
		"starting": {"resources": {}, "tableau": [], "territory": ""},
		"deck": {},
		"territory_deck": {},
	}

	var starting: Variant = raw.get("starting", {})
	if starting is Dictionary:
		var start_res: Variant = starting.get("resources", {})
		if start_res is Dictionary:
			for r in start_res:
				var n: Variant = as_int(start_res[r])
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
		var territory := Effect.read_string(starting, "territory", errs, [], "")
		if territory != "":
			if not cards.has(territory):
				errs.append("starting.territory: unknown card '%s'" % territory)
			elif cards[territory].type != "territory":
				errs.append("starting.territory: '%s' is not a territory" % territory)
			else:
				config.starting.territory = territory
	else:
		errs.append("'starting' must be an object")

	var deck: Variant = raw.get("deck")
	if deck is Dictionary and not deck.is_empty():
		config.deck = _parse_counts(deck, "deck", cards, false, errs)
	else:
		errs.append("'deck' must be a non-empty object like {\"farm\": 4}")

	var territory_deck: Variant = raw.get("territory_deck", {})
	if territory_deck is Dictionary:
		config.territory_deck = _parse_counts(territory_deck, "territory_deck", cards, true, errs)
	else:
		errs.append("'territory_deck' must be an object like {\"hills\": 2}")

	for key in raw:
		if not CONFIG_FIELDS.has(key):
			warnings.append("%s: unknown field '%s'" % [src, key])
	for m in errs:
		errors.append("%s: %s" % [src, m])
	return config


## Normalizes a {card_id: count} deck. territories: whether the deck must hold only
## territory cards (true) or none (false).
static func _parse_counts(deck: Dictionary, field: String, cards: Dictionary, territories: bool, errs: Array[String]) -> Dictionary:
	var out := {}
	for id in deck:
		var n: Variant = as_int(deck[id])
		if not cards.has(id):
			errs.append("%s: unknown card '%s'" % [field, id])
		elif territories and cards[id].type != "territory":
			errs.append("%s: '%s' is not a territory" % [field, id])
		elif not territories and cards[id].type == "territory":
			errs.append("%s: '%s' is a territory" % [field, id])
		elif typeof(n) != TYPE_INT or n < 1:
			errs.append("%s: count for '%s' must be an integer >= 1" % [field, id])
		else:
			out[id] = n
	return out
