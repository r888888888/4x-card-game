class_name Population
extends RefCounted
## Population rules (backlog 009 on): pop on settled territories, buying growth, workers and idle buildings,
## and pop eating food at upkeep. Static functions on the engine's state; GameEngine's public methods call them.


static func pop(e: GameEngine, territory_uid: int) -> int:
	var territory := Territories.settled(e, territory_uid)
	return territory.pop if territory != null else 0


## A settled territory's housing plus the housing of every building on it, working or idle (0 if unsettled).
static func housing(e: GameEngine, territory_uid: int) -> int:
	var territory := Territories.settled(e, territory_uid)
	if territory == null:
		return 0
	var total := territory.def.housing
	for building in Territories.buildings_on(e, territory_uid):
		total += building.def.housing
	return total


static func total_pop(e: GameEngine) -> int:
	var total := 0
	for card in e.zone("tableau").cards:
		if card.def.type == CardDef.TERRITORY:
			total += card.pop
	return total


static func grow_error(e: GameEngine, territory_uid: int) -> String:
	if e.is_over:
		return "The game is over."
	if not e.population_on():
		return "This game has no population."
	var blocked := e._blocked_error("grow")
	if blocked != "":
		return blocked
	var territory := Territories.settled(e, territory_uid)
	if territory == null:
		return "Only a settled territory can grow."
	var cap := housing(e, territory_uid)
	if territory.pop >= cap:
		return "%s is at its housing (%d)." % [territory.def.name, cap]
	var cost := e.grow_cost(territory_uid)
	var have: int = e.resources.get(GameEngine.FOOD, 0)
	if have < cost:
		return "Growing %s needs %d food (you have %d)." % [territory.def.name, cost, have]
	return ""


static func grow(e: GameEngine, territory_uid: int) -> bool:
	if grow_error(e, territory_uid) != "":
		return false
	var territory := Territories.settled(e, territory_uid)
	var cost := e.grow_cost(territory_uid)
	e.resources.food -= cost
	territory.pop += 1
	e._log("%s grew to %d pop (%d food)." % [territory.def.name, territory.pop, cost])
	e.changed.emit()
	return true


static func add_pop(e: GameEngine, territory_uid: int, amount: int, source: CardInstance) -> void:
	var territory := Territories.settled(e, territory_uid)
	if territory == null or not e.population_on():
		return
	var added := mini(amount, housing(e, territory_uid) - territory.pop)
	if added <= 0:
		return
	territory.pop += added
	e._log("  %s: +%d pop on %s" % [source.def.name, added, territory.def.name])


static func free_workers(e: GameEngine, territory_uid: int) -> int:
	return maxi(pop(e, territory_uid) - Territories.buildings_on(e, territory_uid).size(), 0)


static func is_idle(e: GameEngine, uid: int) -> bool:
	var card := e.zone("tableau").find(uid)
	if card == null or card.def.type != CardDef.BUILDING or not e.population_on():
		return false
	return Territories.buildings_on(e, card.territory_uid).find(card) >= pop(e, card.territory_uid)


## Whether territory has a free worker for another building (always, with population off).
static func has_worker(e: GameEngine, territory: CardInstance) -> bool:
	return not e.population_on() or free_workers(e, territory.uid) > 0


## Pop eats food_upkeep food each. Each food that can't be paid starves 1 pop from the territory with
## the most pop (ties: the one settled first), unless a famine guard on that territory saves it.
static func feed(e: GameEngine) -> void:
	var need: int = total_pop(e) * e.config.population.food_upkeep
	if need == 0:
		return
	var eaten: int = mini(need, e.resources.food)
	e.resources.food -= eaten
	e._log("Pop eats %d food." % eaten)
	var guards := famine_guards(e)
	for i in need - eaten:
		var biggest: CardInstance = null
		for card in e.zone("tableau").cards:
			if card.def.type == CardDef.TERRITORY and card.pop > 0 and (biggest == null or card.pop > biggest.pop):
				biggest = card
		if biggest == null:
			break
		if guards.get(biggest.uid, 0) > 0:
			guards[biggest.uid] -= 1
			e._log("%s: 1 pop saved from famine." % biggest.def.name)
			continue
		biggest.pop -= 1
		e._log("%s: 1 pop starved." % biggest.def.name)


## The famine guard of the working buildings on each territory: {territory uid: pop it can save this upkeep}.
static func famine_guards(e: GameEngine) -> Dictionary:
	var guards := {}
	for card in e.zone("tableau").cards:
		if card.def.famine_guard > 0 and not is_idle(e, card.uid):
			guards[card.territory_uid] = guards.get(card.territory_uid, 0) + card.def.famine_guard
	return guards
