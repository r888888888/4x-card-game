class_name CardDef
extends RefCounted
## Immutable card definition, parsed from data/cards.json by DataLoader.

var id: String = ""
var name: String = ""
var type: String = ""  # "action" (one-shot) or "building"/"city" (stays in the tableau)
var cost: Dictionary = {}  # resource -> int
var vp: int = 0
var tags: Array[String] = []
var effects: Array[Effect] = []
var slots: int = 0  # territories: building slots
var housing: int = 0  # territories: most pop the territory can hold
var keywords: Array[String] = []  # territories: keyword ids from config
var requires: Array[String] = []  # buildings: the territory needs any of these keywords
var era := 1  # techs: the era whose research deck holds this tech (see the add_era op)
var prereq: String = ""  # techs: id of the tech that makes this one cheaper when researched
var prereq_discount := 2  # techs: wealth off when prereq is researched
var text: String = ""  # optional override; otherwise generated from effects


func is_permanent() -> bool:
	return type != "action"


## Whether one of the card's effects adds an era of techs (such a tech can't be lost).
func adds_era() -> bool:
	return effects.any(func(e): return e.op == "add_era")


func has_tag(tag: String) -> bool:
	return tags.has(tag)


func effects_for(trigger: String) -> Array[Effect]:
	var out: Array[Effect] = []
	for e in effects:
		if e.trigger == trigger:
			out.append(e)
	return out


## Short card text for the card face. Generated from effects so it always matches the data:
## "⟳" marks upkeep, and a keyword bonus joins the line it adds to ("⟳ +1 food (+1 Flood Plain)").
func rules_text(card_db: Dictionary) -> String:
	if text != "":
		return text
	var parts: PackedStringArray = []
	if not requires.is_empty():
		parts.append("Needs " + "/".join(PackedStringArray(requires.map(func(k): return k.capitalize()))))
	var prev: Effect = null
	for e in effects:
		if prev != null and e.can_merge_with(prev):
			parts[-1] += " (%s %s)" % [e.bonus_text(), e.keyword.capitalize()]
		else:
			var line := e.describe(card_db)
			if e.trigger == "upkeep":
				line = "⟳ " + line
			if e.keyword != "":
				line = "%s: %s" % [e.keyword.capitalize(), line]
			parts.append(line)
		prev = e
	if prereq != "":
		parts.append("-%d wealth with %s" % [prereq_discount, card_db[prereq].name])
	return "\n".join(parts)


## Full card text for the hover tooltip: one line per effect, spelled out. For a territory, its
## slots, housing and keywords.
func rules_tooltip(card_db: Dictionary) -> String:
	if text != "":
		return text
	var parts: PackedStringArray = []
	if type == "territory":
		parts.append("%d building slot%s, holds up to %d pop" % [slots, "" if slots == 1 else "s", housing])
		if not keywords.is_empty():
			parts.append("Keywords: " + ", ".join(PackedStringArray(keywords.map(func(k): return k.capitalize()))))
		return "\n".join(parts)
	if not requires.is_empty():
		parts.append("Requires " + keyword_names(requires))
	for e in effects:
		var line := e.describe_long(card_db)
		if e.trigger == "upkeep":
			line = "Each upkeep: " + line
		if e.keyword != "":
			line += " (on %s)" % e.keyword.capitalize()
		parts.append(line)
	if type == "city" and slots > 0:
		parts.append("+%d building slots on its territory" % slots)
	if prereq != "":
		parts.append("Costs %d less wealth if you have %s." % [prereq_discount, card_db[prereq].name])
	return "\n".join(parts)


## Keyword ids for display, joined by " or " ("fresh_water" -> "Fresh Water").
static func keyword_names(ids: Array[String]) -> String:
	var names: PackedStringArray = []
	for k in ids:
		names.append(k.capitalize())
	return " or ".join(names)
