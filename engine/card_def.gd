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
var keywords: Array[String] = []  # territories: keyword ids from config
var text: String = ""  # optional override; otherwise generated from effects


func is_permanent() -> bool:
	return type != "action"


func has_tag(tag: String) -> bool:
	return tags.has(tag)


func effects_for(trigger: String) -> Array[Effect]:
	var out: Array[Effect] = []
	for e in effects:
		if e.trigger == trigger:
			out.append(e)
	return out


## Card text for display. Generated from effects so it always matches the data.
func rules_text(card_db: Dictionary) -> String:
	if text != "":
		return text
	var parts: PackedStringArray = []
	for e in effects:
		var line := e.describe(card_db)
		if e.trigger == "upkeep":
			line = "Each upkeep: " + line
		parts.append(line)
	return "\n".join(parts)
