class_name Population
extends RefCounted
## Population rules (backlog 009 on): pop on settled territories, growth from cards (262), workers and idle buildings,
## settlement tiers (281), and pop eating food at upkeep. Static functions on the engine's state; GameEngine's public methods call them.


static func pop(e: GameEngine, territory_uid: int) -> int:
	var territory := Territories.settled(e, territory_uid)
	return territory.pop if territory != null else 0


## A settled territory's housing plus the housing of every building on it, working or idle (0 if unsettled).
static func housing(e: GameEngine, territory_uid: int) -> int:
	var territory := Territories.settled(e, territory_uid)
	if territory == null:
		return 0
	var total := territory.def.housing + Modifiers.total(e, Modifiers.HOUSING)
	for building in Territories.buildings_on(e, territory_uid):
		total += building.def.housing
	return maxi(1, total)


static func total_pop(e: GameEngine) -> int:
	var total := 0
	for card in e.zone("tableau").cards:
		if card.def.type == CardDef.TERRITORY:
			total += card.pop
	return total


## The settled territories with room to grow, smallest pop first (ties: tableau order): what a grow op with "each" and
## a count reaches (261). [] with population off or during a Famine.
static func smallest_with_room(e: GameEngine) -> Array[CardInstance]:
	var out: Array[CardInstance] = []
	if not e.population_on() or Famine.growth_error(e) != "":
		return out
	for card in e.zone("tableau").cards:
		if card.def.type == CardDef.TERRITORY and card.pop < housing(e, card.uid):
			out.append(card)
	var order := {}
	for i in out.size():
		order[out[i]] = i
	out.sort_custom(func(a, b): return a.pop < b.pop or (a.pop == b.pop and order[a] < order[b]))
	return out


## Where pop helps most (261): among the territories with room, one with idle buildings (more workers on it than pop)
## first, then the smallest pop (ties: tableau order); null when nothing can grow.
static func best_to_grow(e: GameEngine) -> CardInstance:
	var lands := smallest_with_room(e)
	for card in lands:
		if Territories.workers_on(e, card.uid).size() > card.pop:
			return card
	return lands[0] if not lands.is_empty() else null


static func add_pop(e: GameEngine, territory_uid: int, amount: int, source: CardInstance) -> void:
	var territory := Territories.settled(e, territory_uid)
	if territory == null or not e.population_on() or Famine.growth_error(e) != "":  # no growth during a Famine (083)
		return
	var added := mini(amount, housing(e, territory_uid) - territory.pop)
	if added <= 0:
		return
	var before := tier(e, territory_uid)
	territory.pop += added
	e._log("  %s: +%d pop on %s" % [source.def.name, added, territory.def.name])
	_notice_tier(e, territory, before)


## The config's settlement tiers (281): [{id, name, pop, slots}], lowest first; [] when tiers or population are off.
static func tiers(e: GameEngine) -> Array:
	return e.config.population.get("tiers", []) if e.population_on() else []


## The index of settled territory uid's tier: the last whose pop it has reached; -1 with tiers off or for anything
## that isn't a settled territory.
static func tier(e: GameEngine, territory_uid: int) -> int:
	var territory := Territories.settled(e, territory_uid)
	return tier_at_pop(e, territory.pop) if territory != null else -1


## The index of the tier a territory with pop n is in; -1 with tiers off.
static func tier_at_pop(e: GameEngine, n: int) -> int:
	var all := tiers(e)
	var out := -1
	for i in all.size():
		if n >= all[i].pop:
			out = i
	return out


## The building slots the tier of a territory with pop n adds (0 with tiers off).
static func slots_at_pop(e: GameEngine, n: int) -> int:
	var i := tier_at_pop(e, n)
	return tiers(e)[i].slots if i >= 0 else 0


## The name of territory uid's tier, or "" when it has none.
static func tier_name(e: GameEngine, territory_uid: int) -> String:
	var i := tier(e, territory_uid)
	return tiers(e)[i].name if i >= 0 else ""


## The pop territory uid's next tier needs; 0 at the top tier or when it has none.
static func next_tier_pop(e: GameEngine, territory_uid: int) -> int:
	var i := tier(e, territory_uid)
	var all := tiers(e)
	return all[i + 1].pop if i >= 0 and i + 1 < all.size() else 0


## A notice when territory's tier is no longer before: it grew into a higher one or shrank to a lower one.
static func _notice_tier(e: GameEngine, territory: CardInstance, before: int) -> void:
	var now := tier(e, territory.uid)
	if now == before:
		return
	var tier_text := with_article(tier_name(e, territory.uid))
	if now > before:
		e._notice("%s grows into %s." % [territory.shown_name(), tier_text])
	else:
		e._notice("%s shrinks to %s." % [territory.shown_name(), tier_text], GameEngine.NOTICE_CAUTION)


## name with "a" or "an" before it ("a Village", "an Outpost").
static func with_article(name: String) -> String:
	return ("an " if "AEIOU".contains(name.left(1).to_upper()) else "a ") + name


static func free_workers(e: GameEngine, territory_uid: int) -> int:
	return maxi(pop(e, territory_uid) - Territories.workers_on(e, territory_uid).size(), 0)


## Whether card uid is idle: a building or unit past its territory's pop (no worker), or a building past its
## territory's slots (281).
static func is_idle(e: GameEngine, uid: int) -> bool:
	var card := e.zone("tableau").find(uid)
	if card == null or not card.def.uses_worker() or not e.population_on():
		return false
	if Territories.workers_on(e, card.territory_uid).find(card) >= pop(e, card.territory_uid):
		return true
	return card.def.type == CardDef.BUILDING \
		and Territories.buildings_on(e, card.territory_uid).find(card) >= Territories.total_slots(e, card.territory_uid)


## Whether territory has a free worker for another building or unit (always, with population off).
static func has_worker(e: GameEngine, territory: CardInstance) -> bool:
	return not e.population_on() or free_workers(e, territory.uid) > 0


## Pop eats food_upkeep food each (083), then the Famine rules run on whether it was fed (Famine.after_feeding).
static func feed(e: GameEngine) -> void:
	var need: int = total_pop(e) * e.config.population.food_upkeep
	var eaten: int = mini(need, e.resources[GameEngine.FOOD])
	e.pay({GameEngine.FOOD: eaten})
	if need > 0:
		e._log("Pop eats %d food." % eaten)
	Famine.after_feeding(e, eaten == need)


## The settled territory with the most pop (ties: the first in tableau order, the one settled first), or null when no
## territory has pop. lose_pop (and so the Famine) takes pop from it.
static func most_pop(e: GameEngine) -> CardInstance:
	var biggest: CardInstance = null
	for card in e.zone("tableau").cards:
		if card.def.type == CardDef.TERRITORY and card.pop > 0 and (biggest == null or card.pop > biggest.pop):
			biggest = card
	return biggest


## Takes up to amount pop, one at a time, from the territory with the most pop. Does nothing with population off.
static func lose_pop(e: GameEngine, amount: int, source: CardInstance) -> void:
	if not e.population_on():
		return
	for i in amount:
		var biggest := most_pop(e)
		if biggest == null:
			return
		var before := tier(e, biggest.uid)
		biggest.pop -= 1
		e._log("  %s: −1 pop on %s" % [source.def.name, biggest.def.name])
		_notice_tier(e, biggest, before)
