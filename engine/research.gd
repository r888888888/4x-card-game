class_name Research
extends RefCounted
## Tech rules (backlog 025 on; an open tree since 140): learning any tech in the research deck whose prereq is
## researched with insight, discounts, eras and their unlock thresholds. Static functions on the engine's state;
## GameEngine's public methods call them.

## The zones tech_tree looks in, in order, and the state a tech there is in (TECH_LOCKED is worked out on top).
const _TREE_ZONES := {
	"researched": GameEngine.TECH_RESEARCHED, "research_deck": GameEngine.TECH_AVAILABLE,
	"future_techs": GameEngine.TECH_FUTURE,
}


## The name of the first card whose effects gain insight, in config deck order then supply order; "" if none.
static func card_name(e: GameEngine) -> String:
	for id in e.config.deck.keys() + e.config.get("supply", {}).keys():
		var def: CardDef = e.card_db[id]
		if def.effects.any(func(effect): return effect.op == "gain" and effect.get("resource") == GameEngine.INSIGHT):
			return def.name
	return ""


static func upcoming_era_unlocks(e: GameEngine) -> Dictionary:
	var out := {}
	for n in e.era_unlocks():
		if n > e.era():
			out[n] = e.era_unlocks()[n]
	return out


## See GameEngine.tech_tree.
## One entry per era with techs in research_deck, in era order: {era, name, reached, unlocks, techs}. unlocks is
## the era's upcoming_era_unlocks entry ({} once reached, or when only a tech adds it); techs its tree() entries.
static func eras(e: GameEngine) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var upcoming := upcoming_era_unlocks(e)
	for tech in tree(e):
		if out.is_empty() or out[-1].era != tech.era:
			out.append({"era": tech.era, "name": e.era_name(tech.era), "reached": tech.era <= e.era(),
				"unlocks": upcoming.get(tech.era, {}), "techs": []})
		out[-1].techs.append(tech)
	return out


static func tree(e: GameEngine) -> Array[Dictionary]:
	var ids: Array = e.config.get("research_deck", {}).keys()
	var order := {}
	for i in ids.size():
		order[ids[i]] = i
	ids.sort_custom(func(a, b): return [e.card_db[a].era, order[a]] < [e.card_db[b].era, order[b]])
	var out: Array[Dictionary] = []
	for id in ids:
		out.append(_tree_entry(e, e.card_db[id]))
	return out


static func _tree_entry(e: GameEngine, def: CardDef) -> Dictionary:
	var state := GameEngine.TECH_FUTURE
	var tech: CardInstance = null
	for zone_name in _TREE_ZONES:
		var i := e.zone(zone_name).cards.find_custom(func(c): return c.def.id == def.id)
		if i != -1:
			tech = e.zone(zone_name).cards[i]
			state = _TREE_ZONES[zone_name]
			break
	if state == GameEngine.TECH_AVAILABLE and not prereq_met(e, def):
		state = GameEngine.TECH_LOCKED
	var gives: Array[String] = []
	for effect in def.effects:
		if effect.op in ["create", "unlock"] and not gives.has(effect.card_id):
			gives.append(effect.card_id)
	var future := tech == null or state == GameEngine.TECH_FUTURE
	return {
		"id": def.id, "era": def.era, "prereq": def.prereq, "state": state,
		"cost": def.cost.get(GameEngine.INSIGHT, 0) if future else cost(e, tech.uid),
		"gives": gives, "uid": -1 if future else tech.uid, "eureka": eureka_met(e, def),
	}


## The tech uid in the research deck or the researched row, or null.
static func find(e: GameEngine, uid: int) -> CardInstance:
	for name in ["research_deck", "researched"]:
		var tech := e.zone(name).find(uid)
		if tech != null:
			return tech
	return null


static func cost(e: GameEngine, uid: int) -> int:
	var tech := find(e, uid)
	if tech == null:
		return 0
	var insight: int = tech.def.cost.get(GameEngine.INSIGHT, 0)
	insight -= Discounts.off(e, tech.def, false).get(GameEngine.INSIGHT, 0)
	if eureka_met(e, tech.def):
		insight -= tech.def.eureka.off
	return maxi(insight, 1)


## Whether def has a eureka (141) and the tableau holds its count of matching cards (by id, or by tag), idle or not.
static func eureka_met(e: GameEngine, def: CardDef) -> bool:
	if def.eureka.is_empty():
		return false
	var matches := e.zone("tableau").cards.filter(func(c): return c.def.id == def.eureka.card if def.eureka.has("card") \
		else c.def.tags.has(def.eureka.tag))
	return matches.size() >= def.eureka.count


## Whether def has no prereq or its prereq is researched.
static func prereq_met(e: GameEngine, def: CardDef) -> bool:
	return def.prereq == "" or e.zone("researched").cards.any(func(c): return c.def.id == def.prereq)


static func buy_error(e: GameEngine, uid: int) -> String:
	var busy := e._blocked_error("research")
	if busy != "":
		return busy
	var tech := e.zone("research_deck").find(uid)
	if tech == null:
		return "That tech isn't on offer."
	if not prereq_met(e, tech.def):
		return "%s needs %s first." % [tech.def.name, e.card_db[tech.def.prereq].name]
	var price := cost(e, uid)
	var have: int = e.resources.get(GameEngine.INSIGHT, 0)
	if have < price:
		return "%s needs %d insight (you have %d)." % [tech.def.name, price, have]
	return ""


static func buy(e: GameEngine, uid: int) -> bool:
	if buy_error(e, uid) != "":
		return false
	var tech := e.zone("research_deck").find(uid)
	var price := cost(e, uid)
	e.zone("research_deck").remove(tech)
	e.resources[GameEngine.INSIGHT] -= price
	e.zone("researched").add(tech)
	e._log("Learned %s (%d insight)." % [tech.def.name, price])
	e._resolve(tech, "play")
	if e.zone("research_deck").is_empty() and not e.zone("future_techs").is_empty():
		add_era(e, _lowest_future_era(e))
	e.changed.emit()
	return true


static func add_era(e: GameEngine, n: int, source: CardInstance = null) -> void:
	if e.state.eras_added.has(n):
		return
	e.state.eras_added.append(n)
	e.state.era = maxi(e.state.era, n)
	var deck := e.zone("research_deck")
	for tech in e.zone("future_techs").cards.filter(func(c): return c.def.era == n):
		e.zone("future_techs").remove(tech)
		deck.add(tech)
	e.rng.shuffle(deck.cards)
	e._notice("  %sEra %d techs added to the tech deck." % [source.def.name + ": " if source != null else "", n])
	Events.add_era(e, n)


## Adds each era whose pop or wealth threshold is met (add_era ignores an era added before).
static func check_era_unlocks(e: GameEngine) -> void:
	var eras := e.era_unlocks().keys()
	eras.sort()
	for n in eras:
		var need: Dictionary = e.era_unlocks()[n]
		if e.total_pop() >= need.get("pop", INF) or e.resources.get(GameEngine.WEALTH, 0) >= need.get(GameEngine.WEALTH, INF):
			add_era(e, n)


## The lowest era among the techs waiting in future_techs.
static func _lowest_future_era(e: GameEngine) -> int:
	var lowest: int = e.zone("future_techs").cards[0].def.era
	for tech in e.zone("future_techs").cards:
		lowest = mini(lowest, tech.def.era)
	return lowest

