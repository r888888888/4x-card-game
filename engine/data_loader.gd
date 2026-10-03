class_name DataLoader
extends RefCounted
## Loads and validates the JSON game data. Collects every problem (not just
## the first) with file, card and field, so a bad data edit is easy to fix.
## Unknown fields are warnings, not errors.

const CARD_TYPES := CardDef.TYPES
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
	"eureka": [CardDef.TECH],
	"era": [CardDef.TECH, CardDef.EVENT],
	"discard": [CardDef.EVENT],
	"flavor": [CardDef.CIVILIZATION, CardDef.GOVERNMENT, CardDef.TECH, CardDef.EVENT],
	"home": [CardDef.CIVILIZATION],
	"quote": [CardDef.CIVILIZATION, CardDef.GOVERNMENT, CardDef.TECH],
	"actions": [CardDef.GOVERNMENT],
	"unrest_limit": [CardDef.GOVERNMENT],
	"discounts": [CardDef.CIVILIZATION],
	"modifiers": [CardDef.BUILDING, CardDef.CITY, CardDef.TECH, CardDef.CIVILIZATION, CardDef.GOVERNMENT, CardDef.EVENT],
}
## The keys a card's modifiers object may use (129); Modifiers.total sums each over the working cards.
const MODIFIER_KEYS: Array[String] = [Modifiers.ACTIONS, Modifiers.HAND_SIZE, Modifiers.HOUSING, Modifiers.UNREST_LIMIT, Modifiers.RENEWAL, Modifiers.INSIGHT_PER_GAIN]
const TYPE_PLURALS := {CardDef.TERRITORY: "territories", CardDef.BUILDING: "buildings", CardDef.TECH: "techs", CardDef.EVENT: "events", CardDef.CIVILIZATION: "civilizations", CardDef.GOVERNMENT: "governments"}
## Card types that never sit on a territory, so their effects can't use a keyword or need a target.
const NO_TERRITORY_TYPES: Array[String] = [CardDef.TECH, CardDef.EVENT, CardDef.GOVERNMENT]
## The keys of an event's discard object (its discard conditions). Only a duration so far.
const DISCARD_CONDITIONS: Array[String] = ["turns"]


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
	var keyword_errors: Array[String] = []  # reported by ConfigLoader.parse_config
	var keywords := parse_keywords(config_raw, config_src, keyword_errors)
	var resource_keywords := parse_keywords(config_raw, config_src, keyword_errors, "resource_keywords")
	result.cards = parse_cards(cards_raw, resources, cards_path.get_file(), errors, warnings, keywords, resource_keywords)
	result.config = ConfigLoader.parse_config(config_raw, resources, result.cards, config_src, errors, warnings)
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
		var eureka_card: String = db[id].eureka.get("card", "")
		if eureka_card != "" and not db.has(eureka_card):
			errors.append("%s: card '%s': eureka: unknown card '%s'" % [src, id, eureka_card])
		var home: String = db[id].home
		if home != "" and not db.has(home):
			errors.append("%s: card '%s': home: unknown card '%s'" % [src, id, home])
		elif home != "" and db[home].type != CardDef.TERRITORY:
			errors.append("%s: card '%s': home: '%s' is not a territory" % [src, id, home])
		for j in db[id].effects.size():
			var start_building := _start_building_problem(db[id].effects[j], db)
			if start_building != "":
				errors.append("%s: card '%s': effects[%d]: %s" % [src, id, j, start_building])
		for e in db[id].effects:
			for ref in e.referenced_cards():
				if not db.has(ref):
					errors.append("%s: card '%s': '%s' effect refers to unknown card '%s'" % [src, id, e.op, ref])
			var ref_errors: Array[String] = []
			e.check_references(db, ref_errors)
			for m in ref_errors:
				errors.append("%s: card '%s': '%s' effect: %s" % [src, id, e.op, m])
	errors.append_array(_prereq_cycles(db, src))
	return db


## One error per cycle of techs that need each other (174), on the cycle's first tech in card order:
## "cards.json: card 'a': prereq: cycle a → b → a". A tech that is its own prereq has its own error.
static func _prereq_cycles(db: Dictionary, src: String) -> Array[String]:
	var out: Array[String] = []
	var in_cycle := {}
	for id in db:
		if in_cycle.has(id):
			continue
		var path: Array[String] = [id]
		var next: String = db[id].prereq
		while next != "" and db.has(next) and not path.has(next):
			path.append(next)
			next = db[next].prereq
		if next == id and path.size() > 1:
			for t in path:
				in_cycle[t] = true
			out.append("%s: card '%s': prereq: cycle %s" % [src, id, " → ".join(path + [id] as Array[String])])
	return out


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
			elif Fields.unpayable(r) != "":
				errs.append("cost: " + Fields.unpayable(r))
			elif typeof(n) != TYPE_INT or n < 0:
				errs.append("cost: '%s' must be an integer >= 0" % r)
			else:
				def.cost[r] = n
	else:
		errs.append("'cost' must be an object like {\"food\": 2}")

	if def.type == CardDef.TECH and not (def.cost.size() == 1 and def.cost.get(GameEngine.INSIGHT, 0) >= 1):
		errs.append("cost: a tech must cost insight only, at least 1 (like {\"insight\": 2})")
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
	elif def.type == CardDef.GOVERNMENT:
		def.actions = Fields.read_int(c, "actions", errs, 1, 0)
		def.unrest_limit = Fields.read_int(c, "unrest_limit", errs, 1, 0)
	for key in TYPE_FIELDS:
		var types: Array = TYPE_FIELDS[key]
		if c.has(key) and not types.has(def.type):
			warns.append("'%s' only applies to %s (ignored)" % [key, TYPE_PLURALS[types[0]]])

	if c.has("modifiers") and TYPE_FIELDS.modifiers.has(def.type):
		def.modifiers = _parse_modifiers(c.modifiers, errs)
	_parse_flavor(c, def, errs)
	if def.type == CardDef.CIVILIZATION:
		def.home = Fields.read_string(c, "home", errs, [], "")
		if c.has("discounts"):
			def.discounts = _parse_discounts(c.discounts, ctx.resources, errs)
	if def.type == CardDef.EVENT:
		def.discard_turns = _parse_discard(c.get("discard", {}), errs)
		def.has_discard = c.has("discard")

	if def.type in [CardDef.TECH, CardDef.EVENT] and c.has("era"):
		var era: Variant = Fields.as_int(c.era)
		if typeof(era) != TYPE_INT or era < 1:
			errs.append("era: must be an integer >= 1")
		else:
			def.era = era
	if def.type == CardDef.TECH:
		def.prereq = Fields.read_string(c, "prereq", errs, [], "")
		if c.has("eureka"):
			def.eureka = _parse_eureka(c.eureka, errs)

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


## Why effect, a start create into the tableau, can't place its card (only a building goes on the home, 133), or "".
static func _start_building_problem(effect: Effect, db: Dictionary) -> String:
	if effect.op != "create" or effect.trigger != "start" or effect.get("zone") != "tableau":
		return ""
	var card_id: String = effect.get("card_id")
	if db.has(card_id) and db[card_id].type != CardDef.BUILDING:
		return "a start 'create' into the tableau must name a building (got '%s')" % card_id
	return ""


## Why start effect can't be on a card of type, or "" if it can: only civilizations start, and nobody can pick a
## target or answer a choice before the first turn.
static func _start_effect_problem(effect: Effect, type: String) -> String:
	if type != CardDef.CIVILIZATION:
		return "trigger 'start' only works on civilizations"
	if effect.target_zone() != "" or effect.opens_choice():
		return "'%s' can't trigger on start (it needs a target or a choice)" % effect.op
	if effect.needs_a_turn():
		return "'%s' can't trigger on start (it only lasts the turn it's played)" % effect.op
	return ""


## Why effect can't be on a card of type (a tech or an event, which has no territory to aim at), or "" if it can.
static func _no_territory_effect_problem(effect: Effect, type: String) -> String:
	var article := "an" if type == CardDef.EVENT else "a"
	if effect.keyword != "":
		return "%s %s effect can't use 'keyword' (%s %s has no territory)" % [article, type, article, type]
	if effect.target_zone() != "":
		return "%s %s effect can't need a target" % [article, type]
	if type == CardDef.EVENT and effect.needs_a_turn():
		return "an event effect can't use '%s' (an event resolves after your plays)" % effect.op
	if effect.needs_own_territory():
		return "%s %s effect can't act on its own territory (%s %s has none; use 'each')" % [article, type, article, type]
	return ""


## A civilization's discounts (108): a list of entries, each with exactly one filter (Discounts.FILTERS: a card type, a
## tag, or supply: true) and one or more amounts of known resources, ints >= 1.
static func _parse_discounts(raw: Variant, resources: Array[String], errs: Array[String]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not (raw is Array):
		errs.append("'discounts' must be a list like [{\"type\": \"tech\", \"wealth\": 1}]")
		return out
	for i in raw.size():
		var where := "discounts[%d]" % i
		var entry: Variant = raw[i]
		if not (entry is Dictionary):
			errs.append("%s: must be an object like {\"type\": \"tech\", \"wealth\": 1}" % where)
			continue
		var filters: Array = Discounts.FILTERS.filter(func(f): return entry.has(f))
		if filters.size() != 1:
			errs.append("%s: needs exactly one filter: %s" % [where, ", ".join(Discounts.FILTERS)])
			continue
		var d := {"filter": filters[0], "value": entry[filters[0]], "amounts": {}}
		if d.filter == "type" and not CardDef.TYPES.has(d.value):
			errs.append("%s: unknown card type '%s'" % [where, d.value])
		elif d.filter == "tag" and not (d.value is String and d.value != ""):
			errs.append("%s: 'tag' must be a non-empty string" % where)
		elif d.filter == "supply" and not (d.value is bool and d.value):
			errs.append("%s: 'supply' must be true" % where)
		for key in entry:
			if key == d.filter:
				continue
			var n: Variant = Fields.as_int(entry[key])
			if not resources.has(key):
				errs.append("%s: unknown resource '%s'" % [where, key])
			elif Fields.unpayable(key) != "":
				errs.append("%s: %s" % [where, Fields.unpayable(key)])
			elif typeof(n) != TYPE_INT or n < 1:
				errs.append("%s: '%s' must be an integer >= 1" % [where, key])
			else:
				d.amounts[key] = n
		if d.amounts.is_empty():
			if entry.size() == 1:  # only the filter; a bad amount was reported above
				errs.append("%s: needs an amount of a resource, like \"wealth\": 1" % where)
		else:
			out.append(d)
	return out


## A card's modifiers as {key: int}: an object whose keys are MODIFIER_KEYS and whose values are non-zero ints (129).
static func _parse_modifiers(raw: Variant, errs: Array[String]) -> Dictionary:
	var out := {}
	if not (raw is Dictionary):
		errs.append("'modifiers' must be an object like {\"actions\": 1}")
		return out
	for key in raw:
		var n: Variant = Fields.as_int(raw[key])
		if not MODIFIER_KEYS.has(key):
			errs.append("modifiers.%s: unknown modifier (known: %s)" % [key, ", ".join(MODIFIER_KEYS)])
		elif typeof(n) != TYPE_INT or n == 0:
			errs.append("modifiers.%s: must be a non-zero integer" % key)
		else:
			out[key] = n
	return out


## Reads a card's optional flavor line and quote {text, by} into def, each only on the types TYPE_FIELDS gives it
## (civilizations and governments, 205; techs and, without a quote, events, 215).
static func _parse_flavor(c: Dictionary, def: CardDef, errs: Array[String]) -> void:
	if c.has("flavor") and TYPE_FIELDS.flavor.has(def.type):
		if c.flavor is String and c.flavor != "":
			def.flavor = c.flavor
		else:
			errs.append("'flavor' must be a non-empty string")
	if c.has("quote") and TYPE_FIELDS.quote.has(def.type):
		var q: Variant = c.quote
		var text: Variant = q.get("text") if q is Dictionary else null
		var by: Variant = q.get("by") if q is Dictionary else null
		if text is String and text != "" and by is String and by != "":
			def.quote_text = text
			def.quote_by = by
		else:
			errs.append("'quote' must be {\"text\": …, \"by\": …} with non-empty strings")


## A tech's eureka object (141), {"card" | "tag": String, "count": int >= 1, "off": int >= 1}, as given; {} after an
## error. Whether a card id is known is checked in the cross-card pass.
static func _parse_eureka(raw: Variant, errs: Array[String]) -> Dictionary:
	var example := "like {\"card\": \"farm\", \"count\": 2, \"off\": 2}"
	if not (raw is Dictionary):
		errs.append("eureka: must be an object %s" % example)
		return {}
	var own: Array[String] = []
	if raw.has("card") == raw.has("tag"):
		own.append("needs exactly one of 'card' and 'tag'")
	var key := "card" if raw.has("card") else "tag"
	var out := {key: Fields.read_string(raw, key, own, [], "")}
	out.count = Fields.read_int(raw, "count", own, 1)
	out.off = Fields.read_int(raw, "off", own, 1)
	for m in own:
		errs.append("eureka: %s (%s)" % [m, example])
	return out if own.is_empty() else {}


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


## Parses config.json against cards: see ConfigLoader.parse_config, which does the work.
static func parse_config(raw: Variant, resources: Array[String], cards: Dictionary, src: String, errors: Array[String], warnings: Array[String]) -> Dictionary:
	return ConfigLoader.parse_config(raw, resources, cards, src, errors, warnings)
