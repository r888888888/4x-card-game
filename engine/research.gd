class_name Research
extends RefCounted
## Tech rules (backlog 025 on): revealing, buying and declining techs, passes and discounts, eras and their
## unlock thresholds. Static functions on the engine's state; GameEngine's public methods call them.


static func options(e: GameEngine) -> Array[int]:
	var out: Array[int] = []
	for card in e.zone("research_reveal").cards:
		out.append(card.uid)
	return out


static func upcoming_era_unlocks(e: GameEngine) -> Dictionary:
	var out := {}
	for n in e.era_unlocks():
		if n > e.era():
			out[n] = e.era_unlocks()[n]
	return out


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
