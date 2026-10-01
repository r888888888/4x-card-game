class_name CardDetails
extends RefCounted
## A card's full details for the details modal (backlog 056): its rules, its live state and an explanation of every
## mechanic it uses. Static functions on the engine's state; GameEngine.def_details / card_details call them.


## Details of card definition card_id with no live state, or {} if there is no such card.
static func of_def(e: GameEngine, card_id: String) -> Dictionary:
	if not e.card_db.has(card_id):
		return {}
	var def: CardDef = e.card_db[card_id]
	return _details(e, def, def.keywords, [])


## Details of card uid in any zone, with its live state, or {} if there is no such card (or no game yet).
static func of_card(e: GameEngine, uid: int) -> Dictionary:
	for zone_name in GameEngine.ZONES:
		if not e.zones.has(zone_name):  # before new_game (the new game screen) there are no zones
			continue
		var card := e.zone(zone_name).find(uid)
		if card != null:
			return _details(e, card.def, card.keywords, _state(e, card, zone_name))
	return {}


static func _details(e: GameEngine, def: CardDef, keywords: Array[String], state: Array[String]) -> Dictionary:
	var rules: Array[String] = []
	var text := def.territory_text(keywords) if def.type == CardDef.TERRITORY else def.rules_tooltip(e.card_db)
	if text != "":
		rules.assign(text.split("\n"))
	return {
		"name": def.name, "type": def.type.capitalize(), "cost": _cost_text(def.cost), "vp": def.vp,
		"rules": rules, "state": state, "terms": _terms(e, def, keywords),
		"flavor": def.flavor, "quote": {"text": def.quote_text, "by": def.quote_by} if def.quote_text != "" else {},
	}


static func _cost_text(cost: Dictionary) -> String:
	var parts: PackedStringArray = []
	for r in cost:
		parts.append("%d %s" % [cost[r], r])
	return ", ".join(parts)


static func _state(e: GameEngine, card: CardInstance, zone_name: String) -> Array[String]:
	var out: Array[String] = []
	if zone_name == "tableau" and card.def.type == CardDef.TERRITORY:
		var total := e.total_slots(card.uid)
		if e.population_on():
			out.append("Pop %d / housing %d" % [e.pop(card.uid), e.housing(card.uid)])
		out.append("Slots %d / %d used" % [total - e.free_slots(card.uid), total])
		if e.population_on():
			out.append("Free workers %d" % e.free_workers(card.uid))
	var territory := e.territory_of(card) if zone_name == "tableau" else null
	if territory != null and territory != card:
		out.append("On %s" % territory.def.name)
	if zone_name == "tableau" and card.def.type == CardDef.BUILDING and e.is_idle(card.uid):
		out.append("Idle: no free worker (skips upkeep)")
	if card.def.type == CardDef.TECH and zone_name == "research_deck":
		out.append(_tech_cost_text(e, card))
	return out


## "Costs 2 insight now (printed 3, −1 civilization)"
static func _tech_cost_text(e: GameEngine, tech: CardInstance) -> String:
	var parts: PackedStringArray = ["printed %d" % tech.def.cost.get(GameEngine.INSIGHT, 0)]
	var civ: int = Discounts.off(e, tech.def, false).get(GameEngine.INSIGHT, 0)
	if civ > 0:
		parts.append("−%d civilization" % civ)
	if Research.eureka_met(e, tech.def):
		parts.append("−%d eureka" % tech.def.eureka.off)
	if Research.diffusion(e, tech.def) > 0:
		parts.append("−%d older era" % Research.diffusion(e, tech.def))
	return "Costs %d insight now (%s)" % [e.tech_cost(tech.uid), ", ".join(parts)]


## Unique terms, in order of first use: the rules, then the card type's mechanics. Leaves out Glossary.BASIC.
static func _terms(e: GameEngine, def: CardDef, keywords: Array[String]) -> Array[Dictionary]:
	var names: Array[String] = []
	if def.type == CardDef.TERRITORY:
		names.append_array(["Slots", "Housing", "Pop"])
		names.append_array(keywords)
	if not def.requires.is_empty():
		names.append("Requires")
		names.append_array(def.requires)
	for effect in def.effects:
		names.append_array(effect.terms())
		if effect.keyword != "":
			names.append(effect.keyword)
	if def.type == CardDef.BUILDING:
		if def.housing > 0:
			names.append("Housing")
		if def.famine_guard > 0:
			names.append("Famine guard")
		names.append_array(["Slots", "Workers"])
	if def.type == CardDef.TECH:
		if def.prereq != "":
			names.append("Prerequisite")
	var out: Array[Dictionary] = []
	var seen := {}
	for n in names:
		var term := n.capitalize()
		if seen.has(term) or Glossary.BASIC.has(term):
			continue
		seen[term] = true
		var text := Glossary.text(term)
		out.append({"term": term, "text": text if text != "" else _keyword_text(e, n)})
	return out


## "A territory keyword. Needed by: Well. Bonus on it: Paddy." from the card data.
static func _keyword_text(e: GameEngine, keyword: String) -> String:
	var needed: PackedStringArray = []
	var bonus: PackedStringArray = []
	for id in e.card_db:
		var def: CardDef = e.card_db[id]
		if def.requires.has(keyword):
			needed.append(def.name)
		if def.effects.any(func(effect): return effect.keyword == keyword):
			bonus.append(def.name)
	var resource: bool = e.config.get("resource_keywords", []).has(keyword)
	var terrains: Array = e.config.get("terrains", [])
	var text := "A territory keyword."
	if resource:
		text = "A resource some territories have."
	elif terrains.has(keyword):
		text = "A terrain."
	elif not terrains.is_empty():
		text = "A territory feature."
	if not needed.is_empty():
		text += " Needed by: %s." % ", ".join(needed)
	if not bonus.is_empty():
		text += " Bonus on it: %s." % ", ".join(bonus)
	return text
