class_name Research
extends RefCounted
## Tech rules (backlog 025 on): revealing, buying and declining techs, passes and discounts, eras and their
## unlock thresholds. Static functions on the engine's state; GameEngine's public methods call them.

## The zones tech_tree looks in, in order, and the state a tech there is in.
const _TREE_ZONES := {
	"researched": GameEngine.TECH_RESEARCHED, "research_reveal": GameEngine.TECH_AVAILABLE,
	"research_deck": GameEngine.TECH_AVAILABLE, "future_techs": GameEngine.TECH_FUTURE, "lost_techs": GameEngine.TECH_LOST,
}


static func options(e: GameEngine) -> Array[int]:
	var out: Array[int] = []
	for card in e.zone("research_reveal").cards:
		out.append(card.uid)
	return out


## The name of the first card with a research effect, in config deck order then supply order; "" if none.
static func card_name(e: GameEngine) -> String:
	for id in e.config.deck.keys() + e.config.get("supply", {}).keys():
		var def: CardDef = e.card_db[id]
		if def.effects.any(func(effect): return effect.op == "research"):
			return def.name
	return ""


static func upcoming_era_unlocks(e: GameEngine) -> Dictionary:
	var out := {}
	for n in e.era_unlocks():
		if n > e.era():
			out[n] = e.era_unlocks()[n]
	return out


## See GameEngine.tech_tree.
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
	var gives: Array[String] = []
	for effect in def.effects:
		if effect.op in ["create", "unlock"] and not gives.has(effect.card_id):
			gives.append(effect.card_id)
	var future := tech == null or state == GameEngine.TECH_FUTURE
	return {
		"id": def.id, "era": def.era, "prereq": def.prereq, "state": state,
		"cost": def.cost.get(GameEngine.WEALTH, 0) if future else cost(e, tech.uid),
		"passes": 0 if tech == null else tech.passes, "gives": gives,
	}


static func reveal_error(e: GameEngine) -> String:
	if e.zone("research_deck").is_empty() and e.zone("future_techs").is_empty():
		return "The tech deck is empty."
	return ""


## The tech uid in the research deck, the revealed techs, the researched row or the lost techs, or null.
static func find(e: GameEngine, uid: int) -> CardInstance:
	for name in ["research_reveal", "research_deck", "researched", "lost_techs"]:
		var tech := e.zone(name).find(uid)
		if tech != null:
			return tech
	return null


static func cost(e: GameEngine, uid: int) -> int:
	var tech := find(e, uid)
	if tech == null:
		return 0
	var wealth: int = tech.def.cost.get(GameEngine.WEALTH, 0) - tech.passes
	if tech.def.prereq != "" and e.zone("researched").cards.any(func(c): return c.def.id == tech.def.prereq):
		wealth -= tech.def.prereq_discount
	return maxi(wealth, 1)


static func passes(e: GameEngine, uid: int) -> int:
	var tech := find(e, uid)
	return tech.passes if tech != null else 0


static func buy_error(e: GameEngine, uid: int) -> String:
	var tech := e.zone("research_reveal").find(uid)
	if tech == null:
		return "That tech isn't on offer."
	var price := cost(e, uid)
	var have: int = e.resources.get(GameEngine.WEALTH, 0)
	if have < price:
		return "%s needs %d wealth (you have %d)." % [tech.def.name, price, have]
	return ""


static func reveal(e: GameEngine) -> void:
	if reveal_error(e) != "":
		return
	var deck := e.zone("research_deck")
	if deck.is_empty():
		add_era(e, _lowest_future_era(e))
	for i in 2:
		if deck.is_empty():
			break
		e.zone("research_reveal").add(deck.take_top())
	e._log("  Researching: %s." % ", ".join(PackedStringArray(e.zone("research_reveal").cards.map(func(c): return c.def.name))))


static func buy(e: GameEngine, uid: int) -> bool:
	if buy_error(e, uid) != "":
		return false
	var tech := e.zone("research_reveal").find(uid)
	var price := cost(e, uid)
	e.zone("research_reveal").remove(tech)
	e.resources.wealth -= price
	e.zone("researched").add(tech)
	e._log("Learned %s (%d wealth)." % [tech.def.name, price])
	e._resolve(tech, "play")
	_return_revealed(e, true)
	e.changed.emit()
	return true


static func decline(e: GameEngine) -> bool:
	if e.zone("research_reveal").is_empty():
		return false
	e._log("Declined the techs.")
	_return_revealed(e, false)
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
	e._log("  %sEra %d techs added to the tech deck." % [source.def.name + ": " if source != null else "", n])


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


## Shuffles every revealed tech back into the research deck. With passed, each was passed over by a
## purchase: it gets a pass, and a third pass loses it for good.
static func _return_revealed(e: GameEngine, passed: bool) -> void:
	var deck := e.zone("research_deck")
	for card in e.zone("research_reveal").take_all():
		if passed:
			card.passes += 1
		if card.def.adds_era():
			card.passes = mini(card.passes, GameEngine.MAX_PASSES - 1)
		if card.passes >= GameEngine.MAX_PASSES:
			e.zone("lost_techs").add(card)
			e._log("  %s was passed over too often and is lost." % card.def.name)
		else:
			deck.add(card)
	e.rng.shuffle(deck.cards)
