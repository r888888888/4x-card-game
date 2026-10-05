class_name Population
extends RefCounted
## Population rules (backlog 009 on): pop on settled territories, growth from cards (262), workers and idle buildings,
## and pop eating food at upkeep. Static functions on the engine's state; GameEngine's public methods call them.


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
	territory.pop += added
	e._log("  %s: +%d pop on %s" % [source.def.name, added, territory.def.name])


static func free_workers(e: GameEngine, territory_uid: int) -> int:
	return maxi(pop(e, territory_uid) - Territories.workers_on(e, territory_uid).size(), 0)


static func is_idle(e: GameEngine, uid: int) -> bool:
	var card := e.zone("tableau").find(uid)
	if card == null or not card.def.uses_worker() or not e.population_on():
		return false
	return Territories.workers_on(e, card.territory_uid).find(card) >= pop(e, card.territory_uid)


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
		biggest.pop -= 1
		e._log("  %s: −1 pop on %s" % [source.def.name, biggest.def.name])
