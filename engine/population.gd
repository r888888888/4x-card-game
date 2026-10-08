class_name Population
extends RefCounted
## Population rules (backlog 009 on): pop on settled territories, growth from cards (262), workers and idle buildings,
## settlement tiers (281), and pop eating food at upkeep. Static functions on the engine's state; GameEngine's public methods call them.


static func pop(e: GameEngine, territory_uid: int) -> int:
	var territory := Territories.settled(e, territory_uid)
	return territory.pop if territory != null else 0


## A settled territory's housing plus the housing of every building on it, working or idle, but not fallen back (300,
## 301) (0 if unsettled).
static func housing(e: GameEngine, territory_uid: int) -> int:
	var territory := Territories.settled(e, territory_uid)
	if territory == null:
		return 0
	var total := territory.def.housing + Modifiers.total(e, Modifiers.HOUSING)
	var fallen := Fallback.fallen_uids(e)
	for card in e.zone("tableau").cards:
		if card.def.type == CardDef.BUILDING and card.territory_uid == territory_uid and not fallen.has(card.uid):
			total += card.def.housing
	return maxi(1, total)


static func total_pop(e: GameEngine) -> int:
	var total := 0
	for card in e.zone("tableau").cards:
		if card.def.type == CardDef.TERRITORY:
			total += card.pop
	return total


## The settled territories with room to grow, smallest pop first (ties: tableau order): what a grow op with "each" and
## a count reaches (261). [] with population off or during a Famine. Counts housing as housing() does, in one pass (294).
static func smallest_with_room(e: GameEngine) -> Array[CardInstance]:
	var out: Array[CardInstance] = []
	if not e.population_on() or Famine.growth_error(e) != "":
		return out
	var tableau := e.zone("tableau").cards
	var built := {}  # territory uid -> the housing of the buildings on it (see housing)
	var fallen := Fallback.fallen_uids(e)
	for card in tableau:
		if card.def.type == CardDef.BUILDING and not fallen.has(card.uid):
			built[card.territory_uid] = built.get(card.territory_uid, 0) + card.def.housing
	var extra := Modifiers.total(e, Modifiers.HOUSING)
	for card in tableau:
		if card.def.type == CardDef.TERRITORY and card.pop < maxi(1, card.def.housing + extra + built.get(card.uid, 0)):
			out.append(card)
	var order := {}
	for i in out.size():
		order[out[i]] = i
	out.sort_custom(func(a, b): return a.pop < b.pop or (a.pop == b.pop and order[a] < order[b]))
	return out


## Where pop helps most (261): among the territories with room, one with idle buildings (more workers on it than pop)
## first, then one a pop short of its next settlement tier (283), then the smallest pop. Each step takes the smallest
## pop first (ties: tableau order); null when nothing can grow.
static func best_to_grow(e: GameEngine) -> CardInstance:
	var lands := smallest_with_room(e)
	for card in lands:
		if Territories.workers_on(e, card.uid).size() > card.pop:
			return card
	for card in lands:
		if next_tier_pop(e, card.uid) == card.pop + 1:
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
	var fallen := Fallback.fallen_on(e, territory_uid)
	territory.pop += added
	e._log("  %s: +%d pop on %s" % [source.def.name, added, territory.def.name])
	_notice_tier(e, territory, before, fallen)


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
	return tier_slots(tiers(e), n)


## The building slots tiers (as tiers() returns them) give a territory with pop n: the last tier's it has reached, 0
## for none. For a pass over many territories, with the tiers looked up once (294).
static func tier_slots(all: Array, n: int) -> int:
	var out := 0
	for t in all:
		if n >= t.pop:
			out = t.slots
	return out


## The name of territory uid's tier, or "" when it has none.
static func tier_name(e: GameEngine, territory_uid: int) -> String:
	var i := tier(e, territory_uid)
	return tiers(e)[i].name if i >= 0 else ""


## Territory uid's tier and the next one's pop ("Village: a Town at 8 pop"), just the name at the top tier (281), or ""
## when it has none.
static func tier_line(e: GameEngine, territory_uid: int) -> String:
	var i := tier(e, territory_uid)
	var all := tiers(e)
	if i < 0:
		return ""
	if i + 1 >= all.size():
		return all[i].name
	return "%s: %s at %d pop" % [all[i].name, with_article(all[i + 1].name), all[i + 1].pop]


## See GameEngine.size_unrest (282).
static func size_unrest(e: GameEngine) -> int:
	var gov := e.zone("government")
	if not e.unrest_on() or gov.is_empty() or gov.cards[0].def.tolerates == "":
		return 0
	var tolerated := tiers(e).map(func(t): return t.id).find(gov.cards[0].def.tolerates)
	if tolerated < 0:
		return 0
	var sum := 0
	for card in e.zone("tableau").cards:
		if card.def.type == CardDef.TERRITORY:
			sum += maxi(0, tier_at_pop(e, card.pop) - tolerated)
	return sum


## See GameEngine.admin_unrest (319).
static func admin_unrest(e: GameEngine) -> int:
	var cap := Modifiers.admin_cap(e)
	if not e.unrest_on() or cap < 0:
		return 0
	var over := maxi(0, Territories.count_settled(e) - cap)
	return over * (over + 1) / 2


## The pop territory uid's next tier needs; 0 at the top tier or when it has none.
static func next_tier_pop(e: GameEngine, territory_uid: int) -> int:
	var i := tier(e, territory_uid)
	var all := tiers(e)
	return all[i + 1].pop if i >= 0 and i + 1 < all.size() else 0


## A notice when territory's tier is no longer before: it grew into a higher one or shrank to a lower one. It names
## the cards there that fell back or work again since, when fallen listed the ones fallen back before (301).
static func _notice_tier(e: GameEngine, territory: CardInstance, before: int, fallen: Array[int]) -> void:
	var now := tier(e, territory.uid)
	if now == before:
		return
	var tier_text := with_article(tier_name(e, territory.uid))
	var fallen_now := Fallback.fallen_on(e, territory.uid)
	if now > before:
		var back := fallen.filter(func(uid): return not fallen_now.has(uid))
		var works := _cards_line(e, back, "works again", "work again")
		e._notice("%s grows into %s.%s" % [territory.shown_name(), tier_text, works])
	else:
		var fell := fallen_now.filter(func(uid): return not fallen.has(uid))
		var falls := _cards_line(e, fell, "falls back", "fall back")
		e._notice("%s shrinks to %s.%s" % [territory.shown_name(), tier_text, falls], GameEngine.NOTICE_CAUTION)


## " Sanctum falls back." / " Sanctum and Bell fall back." for the tableau cards uids (301); "" for none.
static func _cards_line(e: GameEngine, uids: Array, one: String, many: String) -> String:
	if uids.is_empty():
		return ""
	return " %s %s." % [Fallback.names(e, uids), one if uids.size() == 1 else many]


## name with "a" or "an" before it ("a Village", "an Outpost").
static func with_article(name: String) -> String:
	return ("an " if "AEIOU".contains(name.left(1).to_upper()) else "a ") + name


static func free_workers(e: GameEngine, territory_uid: int) -> int:
	return maxi(pop(e, territory_uid) - Territories.workers_on(e, territory_uid).size(), 0)


## Whether the card in play uses a worker on its territory (415): a building or unit (CardDef.uses_worker), unless an
## upgrade that frees its worker is built on it.
static func uses_worker(e: GameEngine, card: CardInstance) -> bool:
	return card.def.uses_worker() and not freed_uids(e).has(card.uid)


## The tableau buildings with an upgrade that frees their worker built on them (415): uid -> true.
static func freed_uids(e: GameEngine) -> Dictionary:
	var out := {}
	for c in e.zone("tableau").cards:
		if c.def.frees_worker and c.base_uid >= 0:
			out[c.base_uid] = true
	return out


## Whether card uid is idle: a building or unit past its territory's pop (no worker), or a building past its
## territory's slots (281). An upgrade takes no worker, so it never is (it falls back instead, see Fallback).
static func is_idle(e: GameEngine, uid: int) -> bool:
	var card := e.zone("tableau").find(uid)
	if card == null or not card.def.uses_worker() or not e.population_on():
		return false
	if uses_worker(e, card) and Territories.workers_on(e, card.territory_uid).find(card) >= pop(e, card.territory_uid):
		return true
	return card.def.type == CardDef.BUILDING and Territories.slot_use(e, card.territory_uid).unslotted.has(card)


## The tableau cards is_idle says are idle, in one pass (408): uid -> true. Each territory's pop goes to its
## worker-using cards in tableau order (not a building whose worker is freed, 415), and its slots (sea slots first for a building that takes one, 366) to its
## buildings; a card past either is idle. {} with population off.
static func idle_uids(e: GameEngine) -> Dictionary:
	var out := {}
	if not e.population_on():
		return out
	var tableau := e.zone("tableau").cards
	var tiers := tiers(e)
	var workers := {}  # settled territory uid -> pop not yet given to a card seen so far
	var slots := {}  # settled territory uid -> slots not yet taken by a building seen so far
	var sea := {}  # settled territory uid -> sea slots not yet taken
	for c in tableau:
		if c.def.type == CardDef.TERRITORY:
			workers[c.uid] = c.pop
			slots[c.uid] = c.def.slots + tier_slots(tiers, c.pop)
			sea[c.uid] = Territories.sea_slots_of(e, c)
	for c in tableau:
		if c.def.type == CardDef.CITY and slots.has(c.territory_uid):
			slots[c.territory_uid] += c.def.slots
	var freed := freed_uids(e)
	for c in tableau:
		if not c.def.uses_worker():
			continue
		var left := 1  # a building whose worker is freed (415) takes none, but still takes its slot
		if not freed.has(c.uid):
			left = workers.get(c.territory_uid, 0)
			workers[c.territory_uid] = left - 1
		var room := 1
		if c.def.type == CardDef.BUILDING and sea.get(c.territory_uid, 0) > 0 and Territories.takes_sea_slot(e, c.def):
			sea[c.territory_uid] -= 1
		elif c.def.type == CardDef.BUILDING:
			room = slots.get(c.territory_uid, 0)
			slots[c.territory_uid] = room - 1
		if left <= 0 or room <= 0:
			out[c.uid] = true
	return out


## The refusal of a building or unit for want of a free worker (347); no_worker_detail explains it.
const NO_WORKER := "No free worker."


## Why NO_WORKER (347): what a worker is, then that settled territory territory_uid's pop is all at work or that it
## has none, or with -1 that every territory's pop is at work.
static func no_worker_detail(e: GameEngine, territory_uid: int) -> String:
	var why := "Each building and unit needs a worker: one pop on its territory."
	var territory := Territories.settled(e, territory_uid)
	if territory == null:
		return why + " Every territory's pop is at work."
	if territory.pop == 0:
		return why + " %s has no pop yet." % territory.shown_name()
	return why + " %s's pop is all at work." % territory.shown_name()


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
		var fallen := Fallback.fallen_on(e, biggest.uid)
		biggest.pop -= 1
		e._log("  %s: −1 pop on %s" % [source.def.name, biggest.def.name])
		_notice_tier(e, biggest, before, fallen)
