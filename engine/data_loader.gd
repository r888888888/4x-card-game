class_name DataLoader
extends RefCounted
## Loads and validates the JSON game data. Collects every problem (not just
## the first) with file, card and field, so a bad data edit is easy to fix.
## Unknown fields are warnings, not errors.

const CARD_TYPES := CardDef.TYPES
## Fields every card type may have.
const CARD_FIELDS: Array[String] = ["id", "name", "type", "cost", "cost_per_territory", "vp", "tags", "effects", "text"]
## Fields only some card types use: field -> those types, the first being the one the field is for. On any other
## type the field is ignored with a warning ("'era' only applies to techs (ignored)").
const TYPE_FIELDS := {
	"slots": [CardDef.TERRITORY, CardDef.CITY],
	"housing": [CardDef.TERRITORY, CardDef.BUILDING],
	"famine_guard": [CardDef.BUILDING],
	"strength": [CardDef.UNIT],
	"upgrades_to": [CardDef.UNIT],
	"defense": [CardDef.BUILDING, CardDef.CITY],
	"training": [CardDef.BUILDING],
	"upkeep": [CardDef.BUILDING],
	"keywords": [CardDef.TERRITORY],
	"prereq": [CardDef.TECH],
	"eureka": [CardDef.TECH],
	"era": [CardDef.TECH, CardDef.EVENT],
	"discard": [CardDef.EVENT],
	"raid": [CardDef.EVENT],
	"choices": [CardDef.EVENT],
	"flavor": [CardDef.CIVILIZATION, CardDef.GOVERNMENT, CardDef.TECH, CardDef.EVENT, CardDef.ACTION, CardDef.BUILDING],
	"home": [CardDef.CIVILIZATION],
	"city_names": [CardDef.CIVILIZATION],
	"quote": [CardDef.CIVILIZATION, CardDef.GOVERNMENT, CardDef.TECH, CardDef.EVENT, CardDef.BUILDING],
	"actions": [CardDef.GOVERNMENT],
	"unrest_limit": [CardDef.GOVERNMENT],
	"tolerates": [CardDef.GOVERNMENT],
	"administers": [CardDef.GOVERNMENT],
	"project": [CardDef.BUILDING],
	"upgrade_of": [CardDef.BUILDING],
	"tier": [CardDef.BUILDING],
	"discounts": [CardDef.CIVILIZATION],
	"modifiers": [CardDef.BUILDING, CardDef.CITY, CardDef.TECH, CardDef.CIVILIZATION, CardDef.GOVERNMENT, CardDef.EVENT],
	"requires": [CardDef.BUILDING],
}
## An INT_FIELDS default: the field must be given.
const REQUIRED := "required"
## An INT_FIELDS default: the card's slots + 2 (a territory's housing).
const SLOTS_PLUS_2 := "slots + 2"
## The integer fields of TYPE_FIELDS (338): the least value each takes, and its default when left out (an int, REQUIRED
## or SLOTS_PLUS_2; by type when it differs). Each is read into the CardDef var of the same name.
const INT_FIELDS := {
	"slots": {"min": 0, "default": {CardDef.TERRITORY: REQUIRED, CardDef.CITY: 0}},
	"housing": {"min": 1, "default": {CardDef.TERRITORY: SLOTS_PLUS_2, CardDef.BUILDING: 0}},
	"famine_guard": {"min": 1, "default": 0},
	"strength": {"min": 1, "default": REQUIRED},
	"defense": {"min": 1, "default": 0},
	"training": {"min": 1, "default": 0},
	"upkeep": {"min": 0, "default": -1},  # -1: the config's building_upkeep, which parse_config fills in (405)
	"era": {"min": 1, "default": 1},
	"actions": {"min": 1, "default": 0},
	"unrest_limit": {"min": 1, "default": 0},
	"administers": {"min": 1, "default": 0},
}
## The keys a card's modifiers object may use (129); Modifiers.total sums each over the working cards.
const MODIFIER_KEYS: Array[String] = [Modifiers.ACTIONS, Modifiers.HAND_SIZE, Modifiers.HOUSING, Modifiers.UNREST_LIMIT, Modifiers.RENEWAL, Modifiers.INSIGHT_PER_GAIN,
	Modifiers.ADMINISTERS]
const TYPE_PLURALS := {CardDef.TERRITORY: "territories", CardDef.BUILDING: "buildings", CardDef.TECH: "techs", CardDef.EVENT: "events", CardDef.CIVILIZATION: "civilizations", CardDef.GOVERNMENT: "governments", CardDef.UNIT: "units"}
## Card types that never sit on a territory, so their effects can't use a keyword or need a target.
const NO_TERRITORY_TYPES: Array[String] = [CardDef.TECH, CardDef.EVENT, CardDef.GOVERNMENT]


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
		var upgrade: String = db[id].upgrades_to
		if upgrade != "" and not db.has(upgrade):
			errors.append("%s: card '%s': upgrades_to: unknown card '%s'" % [src, id, upgrade])
		elif upgrade != "" and db[upgrade].type != CardDef.UNIT:
			errors.append("%s: card '%s': upgrades_to: '%s' is not a unit" % [src, id, upgrade])
		var base_problem := _upgrade_base_problem(db[id].upgrade_of, db)
		if base_problem != "":
			errors.append("%s: card '%s': %s" % [src, id, base_problem])
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
	errors.append_array(_upgrade_cycles(db, src))
	return db


## Why an upgrade's base can't be base (300), or "": it is unknown, not a building, or a project.
static func _upgrade_base_problem(base: String, db: Dictionary) -> String:
	if base == "":
		return ""
	if not db.has(base):
		return "upgrade_of: unknown card '%s'" % base
	var type: String = db[base].type
	if type != CardDef.BUILDING:
		return "upgrade_of: '%s' is %s %s" % [base, "an" if type == CardDef.ACTION else "a", type]
	if db[base].project:
		return CardTypeFields.UPGRADE_PROJECT_ERROR
	return ""


## One error per cycle of buildings each the upgrade of the next (300), itself included, on the cycle's first building
## in card order: "cards.json: card 'a': upgrade_of: cycle a → b → a".
static func _upgrade_cycles(db: Dictionary, src: String) -> Array[String]:
	var out: Array[String] = []
	var in_cycle := {}
	for id in db:
		if in_cycle.has(id):
			continue
		var path: Array[String] = [id]
		var next: String = db[id].upgrade_of
		while next != "" and db.has(next) and not path.has(next):
			path.append(next)
			next = db[next].upgrade_of
		if next == id:
			for b in path:
				in_cycle[b] = true
			out.append("%s: card '%s': upgrade_of: cycle %s" % [src, id, " → ".join(path + [id] as Array[String])])
	return out


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


## A card's cost_per_territory (320): {resource: int >= 1} over resources, never unrest.
static func _parse_cost_per_territory(raw: Variant, resources: Array, errs: Array[String]) -> Dictionary:
	var out := {}
	if not (raw is Dictionary):
		errs.append("'cost_per_territory' must be an object like {\"food\": 1}")
		return out
	for r in raw:
		var n: Variant = Fields.as_int(raw[r])
		if not resources.has(r):
			errs.append("cost_per_territory: unknown resource '%s'" % r)
		elif Fields.unpayable(r) != "":
			errs.append("cost_per_territory: " + Fields.unpayable(r))
		elif typeof(n) != TYPE_INT or n < 1:
			errs.append("cost_per_territory: '%s' must be an integer >= 1" % r)
		else:
			out[r] = n
	return out


static func _parse_card(c: Dictionary, ctx: Dictionary, errs: Array[String], warns: Array[String]) -> CardDef:
	var def := CardDef.new()
	def.id = Fields.read_string(c, "id", errs)
	def.name = Fields.read_string(c, "name", errs)
	def.type = Fields.read_string(c, "type", errs, CARD_TYPES)
	def.vp = Fields.read_int(c, "vp", errs, 0, 0)
	def.text = Fields.read_string(c, "text", errs, [], "")
	def.cost = _parse_cost(c.get("cost", {}), ctx.resources, errs)
	if c.has("cost_per_territory"):
		def.cost_per_territory = _parse_cost_per_territory(c.cost_per_territory, ctx.resources, errs)
	def.tags = _parse_tags(c.get("tags", []), errs)
	_parse_effects(c, def, ctx, errs, warns)
	_read_int_fields(c, def, errs)
	if c.has("modifiers") and TYPE_FIELDS.modifiers.has(def.type):
		def.modifiers = _parse_modifiers(c.modifiers, errs)
	_parse_flavor(c, def, errs)
	CardTypeFields.parse(c, def, ctx, errs)
	_warn_other_fields(c, def.type, warns)
	return def


## Reads each INT_FIELDS field that def's type takes into def.
static func _read_int_fields(c: Dictionary, def: CardDef, errs: Array[String]) -> void:
	for field: String in INT_FIELDS:
		if not TYPE_FIELDS[field].has(def.type):
			continue
		var default_value: Variant = INT_FIELDS[field].default
		if default_value is Dictionary:
			default_value = default_value[def.type]
		if default_value is String:
			default_value = def.slots + 2 if default_value == SLOTS_PLUS_2 else null
		def.set(field, Fields.read_int(c, field, errs, INT_FIELDS[field].min, default_value))


## Warns about each field of raw card c that type doesn't take, or that no card takes. A unit's requires is an error
## of its own (CardTypeFields), not a warning.
static func _warn_other_fields(c: Dictionary, type: String, warns: Array[String]) -> void:
	for key in TYPE_FIELDS:
		var types: Array = TYPE_FIELDS[key]
		if c.has(key) and not types.has(type) and not (key == "requires" and type == CardDef.UNIT):
			warns.append("'%s' only applies to %s (ignored)" % [key, TYPE_PLURALS[types[0]]])
	for key in c:
		if not CARD_FIELDS.has(key) and not TYPE_FIELDS.has(key):
			warns.append("unknown field '%s'" % key)


## A card's cost: {resource: int >= 0} over resources, never unrest.
static func _parse_cost(raw: Variant, resources: Array, errs: Array[String]) -> Dictionary:
	var out := {}
	if not (raw is Dictionary):
		errs.append("'cost' must be an object like {\"food\": 2}")
		return out
	for r in raw:
		var n: Variant = Fields.as_int(raw[r])
		if not resources.has(r):
			errs.append("cost: unknown resource '%s'" % r)
		elif Fields.unpayable(r) != "":
			errs.append("cost: " + Fields.unpayable(r))
		elif typeof(n) != TYPE_INT or n < 0:
			errs.append("cost: '%s' must be an integer >= 0" % r)
		else:
			out[r] = n
	return out


## A card's tags: strings.
static func _parse_tags(raw: Variant, errs: Array[String]) -> Array[String]:
	var out: Array[String] = []
	if not (raw is Array):
		errs.append("'tags' must be an array of strings")
		return out
	for t in raw:
		if t is String:
			out.append(t)
		else:
			errs.append("tags must be strings")
	return out


## Reads raw card c's effects into def, refusing each that its trigger or def's type doesn't allow.
static func _parse_effects(c: Dictionary, def: CardDef, ctx: Dictionary, errs: Array[String], warns: Array[String]) -> void:
	var effects: Variant = c.get("effects", [])
	if not (effects is Array):
		errs.append("'effects' must be an array")
		return
	for j in effects.size():
		var e_errs: Array[String] = []
		var e_warns: Array[String] = []
		var effect := EffectRegistry.create(effects[j], ctx, e_errs, e_warns)
		for m in e_errs:
			errs.append("effects[%d]: %s" % [j, m])
		for m in e_warns:
			warns.append("effects[%d]: %s" % [j, m])
		if effect == null or not e_errs.is_empty():
			continue
		var problem := _effect_problem(effect, c, def.type)
		if problem != "":
			errs.append("effects[%d]: %s" % [j, problem])
		else:
			def.effects.append(effect)


## Why effect can't be on raw card c of type, or "": a raid trigger off a raid, a start trigger, or an effect a card
## with no territory (or a unit) can't have.
static func _effect_problem(effect: Effect, c: Dictionary, type: String) -> String:
	if Effect.RAID_TRIGGERS.has(effect.trigger) and not CardTypeFields.is_raid(c):
		return "trigger '%s' only works on a raid (an event with 'raid')" % effect.trigger
	if effect.trigger == "start" and _start_effect_problem(effect, type) != "":
		return _start_effect_problem(effect, type)
	if NO_TERRITORY_TYPES.has(type):
		return no_territory_effect_problem(effect, type)
	if type == CardDef.UNIT:
		return _unit_effect_problem(effect)
	return ""


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
static func no_territory_effect_problem(effect: Effect, type: String) -> String:
	var article := "an" if type == CardDef.EVENT else "a"
	if effect.keyword != "":
		return "%s %s effect can't use 'keyword' (%s %s has no territory)" % [article, type, article, type]
	if effect.target_zone() != "":
		return "%s %s effect can't need a target" % [article, type]
	if type == CardDef.EVENT and effect.needs_a_turn():
		return "an event effect can't use '%s' (an event resolves after your plays)" % effect.op
	if type == CardDef.EVENT and effect.opens_choice():
		return "an event effect can't use '%s' (it opens a choice)" % effect.op
	if effect.needs_own_territory():
		return "%s %s effect can't act on its own territory (%s %s has none; use 'each')" % [article, type, article, type]
	return ""


## Why effect can't be on a unit, or "" if it can (160): a unit can move off its home, so it has no fixed land for a
## keyword or a "here" to act on.
static func _unit_effect_problem(effect: Effect) -> String:
	if effect.keyword != "":
		return "a unit effect can't use 'keyword' (a unit can move, so it has no fixed land)"
	if effect.needs_own_territory():
		return "a unit effect can't act on its own territory (a unit can move; use 'each')"
	return ""


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
## (civilizations and governments, 205; techs and events, 215; an event's quote, 253: Anarchy's; an action's flavor, 351;
## a building's, 352, and its quote, 396: the wonders').
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


## Parses config.json against cards: see ConfigLoader.parse_config, which does the work.
static func parse_config(raw: Variant, resources: Array[String], cards: Dictionary, src: String, errors: Array[String], warnings: Array[String]) -> Dictionary:
	return ConfigLoader.parse_config(raw, resources, cards, src, errors, warnings)
