class_name CardTypeFields
extends RefCounted
## The loader's checks of the fields only some card types have (338): one function per type, called by
## DataLoader._parse_card after the fields every card has and the integer fields of DataLoader.INT_FIELDS. Problems go
## to errs, each naming the field.

## A project is built over turns on a territory, so it can't go onto a building or have one go onto it (300).
const UPGRADE_PROJECT_ERROR := "upgrade_of: a project can't take or be an upgrade"
## The keys of an event's discard object (its discard conditions). Only a duration so far.
const DISCARD_CONDITIONS: Array[String] = ["turns"]


## Reads raw card c's fields for def's type into def. ctx is DataLoader.parse_cards' (resources, keywords, …).
static func parse(c: Dictionary, def: CardDef, ctx: Dictionary, errs: Array[String]) -> void:
	match def.type:
		CardDef.TERRITORY:
			_territory(c, def, ctx, errs)
		CardDef.BUILDING:
			_building(c, def, ctx, errs)
		CardDef.UNIT:
			_unit(c, def, ctx, errs)
		CardDef.TECH:
			_tech(c, def, errs)
		CardDef.EVENT:
			_event(c, def, ctx, errs)
		CardDef.CIVILIZATION:
			_civilization(c, def, ctx, errs)
		CardDef.GOVERNMENT:
			def.tolerates = Fields.read_string(c, "tolerates", errs, [], "")
	if c.has("choices") and def.type != CardDef.EVENT:
		errs.append("choices: only an event can have choices")


## Whether raw card c is a raid: an event with a raid field (162).
static func is_raid(c: Dictionary) -> bool:
	return c.get("type") == CardDef.EVENT and c.has("raid")


static func _territory(c: Dictionary, def: CardDef, ctx: Dictionary, errs: Array[String]) -> void:
	var kws: Variant = c.get("keywords", [])
	if not (kws is Array):
		errs.append("'keywords' must be an array of keyword ids")
		return
	for k in kws:
		if not (k is String):
			errs.append("keywords must be strings")
		elif ctx.resource_keywords.has(k):
			errs.append("keywords: '%s' is a resource keyword; roll it with territory_resources instead" % k)
		elif not ctx.keywords.has(k):
			errs.append("unknown keyword '%s'" % k)
		else:
			def.keywords.append(k)


static func _building(c: Dictionary, def: CardDef, ctx: Dictionary, errs: Array[String]) -> void:
	if c.has("project"):
		if not (c.project is bool):
			errs.append("'project' must be true or false")
		else:
			def.project = c.project
	if def.project and not (def.cost.size() == 1 and def.cost.get(GameEngine.WEALTH, 0) >= 1):
		errs.append("project: its cost must be wealth only, at least 1 (like {\"wealth\": 30})")
	def.upgrade_of = Fields.read_string(c, "upgrade_of", errs, [], "")
	def.tier = Fields.read_string(c, "tier", errs, [], "")
	if def.project and def.upgrade_of != "":
		errs.append(UPGRADE_PROJECT_ERROR)
	if def.project and not def.cost_per_territory.is_empty():
		errs.append("cost_per_territory: a project's cost is paid in over turns, so it can't grow")
	def.requires = _requires(c, ctx, errs)


## A unit can move, so it has no fixed land: its requires is an error (DataLoader doesn't warn about it as well).
static func _unit(c: Dictionary, def: CardDef, ctx: Dictionary, errs: Array[String]) -> void:
	def.upgrades_to = Fields.read_string(c, "upgrades_to", errs, [], "")
	if not _requires(c, ctx, errs).is_empty():
		errs.append("a unit can't have 'requires' (it can move, so it has no fixed land)")


static func _tech(c: Dictionary, def: CardDef, errs: Array[String]) -> void:
	if not (def.cost.size() == 1 and def.cost.get(GameEngine.INSIGHT, 0) >= 1):
		errs.append("cost: a tech must cost insight only, at least 1 (like {\"insight\": 2})")
	def.prereq = Fields.read_string(c, "prereq", errs, [], "")
	if c.has("eureka"):
		def.eureka = _eureka(c.eureka, errs)


static func _event(c: Dictionary, def: CardDef, ctx: Dictionary, errs: Array[String]) -> void:
	if not def.cost.is_empty():
		errs.append("cost: an event can't have a cost")
	if def.vp != 0:
		errs.append("vp: an event can't score VP")
	def.discard_turns = _discard(c.get("discard", {}), errs)
	def.has_discard = c.has("discard")
	if c.has("raid"):
		def.raid = _raid(c.raid, ctx.keywords, errs)
		if def.has_discard:
			errs.append("raid: a raid can't have 'discard' (it lasts until it strikes)")
	if c.has("choices"):
		if is_raid(c):
			errs.append("choices: a raid can't have choices")
		else:
			def.choices = EventChoices.parse(c.choices, ctx, errs)


static func _civilization(c: Dictionary, def: CardDef, ctx: Dictionary, errs: Array[String]) -> void:
	def.home = Fields.read_string(c, "home", errs, [], "")
	def.city_names = _city_names(c.get("city_names", []), errs)
	if c.has("discounts"):
		def.discounts = _discounts(c.discounts, ctx.resources, errs)


## A building's (or unit's) requires: known keyword ids.
static func _requires(c: Dictionary, ctx: Dictionary, errs: Array[String]) -> Array[String]:
	var out: Array[String] = []
	var requires: Variant = c.get("requires", [])
	if not (requires is Array):
		errs.append("'requires' must be an array of keyword ids")
		return out
	for k in requires:
		if not (k is String):
			errs.append("requires must be keyword ids")
		elif not ctx.keywords.has(k):
			errs.append("unknown keyword '%s' in 'requires'" % k)
		else:
			out.append(k)
	return out


## An event's raid (162): {strength (int >= 1), targets (config keywords, [] for any), pop (int >= 0, default 1)}.
## Problems go to errs, prefixed "raid: ".
static func _raid(raw: Variant, keywords: Array, errs: Array[String]) -> Dictionary:
	if not (raw is Dictionary):
		errs.append("raid: must be an object like {\"strength\": 2}")
		return {}
	var problems: Array[String] = []
	var targets: Array[String] = []
	var raw_targets: Variant = raw.get("targets", [])
	if raw_targets is Array:
		for k in raw_targets:
			if not (k is String and keywords.has(k)):
				problems.append("unknown keyword '%s' in 'targets'" % [k])
			else:
				targets.append(k)
	else:
		problems.append("'targets' must be an array of keyword ids")
	var raid := {"strength": Fields.read_int(raw, "strength", problems, 1),
		"targets": targets, "pop": Fields.read_int(raw, "pop", problems, 0, 1)}
	for m in problems:
		errs.append("raid: " + m)
	return raid


## A civilization's discounts (108): a list of entries, each with exactly one filter (Discounts.FILTERS: a card type, a
## tag, or supply: true) and one or more amounts of known resources, ints >= 1.
static func _discounts(raw: Variant, resources: Array[String], errs: Array[String]) -> Array[Dictionary]:
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


## A tech's eureka object (141), {"card" | "tag": String, "count": int >= 1, "off": int >= 1}, as given; {} after an
## error. Whether a card id is known is checked in the cross-card pass.
static func _eureka(raw: Variant, errs: Array[String]) -> Dictionary:
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
static func _discard(raw: Variant, errs: Array[String]) -> int:
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


## A civilization's city_names (248): a list of distinct, non-empty strings.
static func _city_names(raw: Variant, errs: Array[String]) -> Array[String]:
	var out: Array[String] = []
	if not (raw is Array):
		errs.append("'city_names' must be an array of names")
		return out
	for name in raw:
		if not (name is String) or (name as String).strip_edges() == "":
			errs.append("'city_names' must be non-empty strings (got %s)" % [name])
		elif out.has(name):
			errs.append("'city_names' lists '%s' twice" % name)
		else:
			out.append(name)
	return out
