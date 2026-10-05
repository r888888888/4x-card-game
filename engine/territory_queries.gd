class_name TerritoryQueries
extends EngineCore
## The read queries about settled territories and their people (backlog 281, split from EngineQueries): pop and
## housing, building slots, workers and settlement tiers, idle buildings, and each territory's name, summary, status
## and tooltip. They change nothing. EngineQueries extends this with the other read queries.


## Pop on settled territory territory_uid (0 for anything else).
func pop(territory_uid: int) -> int:
	return Population.pop(self, territory_uid)


## The most pop settled territory territory_uid can hold (0 if it isn't one).
func housing(territory_uid: int) -> int:
	return Population.housing(self, territory_uid)


## Keywords of territory uid in any zone: printed, then rolled resources ([] if it isn't a territory).
func territory_keywords(uid: int) -> Array[String]:
	return Territories.keywords_of(self, uid)


## How many settled territories (in the tableau) have any of keywords, printed or rolled; each counts once.
func count_territories_with(keywords: Array[String]) -> int:
	return zone("tableau").cards.filter(func(c: CardInstance):
		return c.def.type == CardDef.TERRITORY and keywords.any(func(k): return c.keywords.has(k))).size()


## Pop summed over every settled territory.
func total_pop() -> int:
	return Population.total_pop(self)


## Building slots on settled territory territory_uid: its own plus the `slots` of cities on it
## (0 if it isn't settled).
func total_slots(territory_uid: int) -> int:
	return Territories.total_slots(self, territory_uid)


## Building slots left on settled territory territory_uid (0 if it isn't settled). Cities don't use slots.
func free_slots(territory_uid: int) -> int:
	return Territories.free_slots(self, territory_uid)


## Pop on settled territory territory_uid not yet working a building (0 if none, or not a territory).
func free_workers(territory_uid: int) -> int:
	return Population.free_workers(self, territory_uid)


## Settled territory uid's settlement tier (281): its index in config population.tiers, or -1 with tiers off or for
## anything else.
func tier(uid: int) -> int:
	return Population.tier(self, uid)


## The name of territory uid's tier ("Village"), or "" when it has none.
func tier_name(uid: int) -> String:
	return Population.tier_name(self, uid)


## The pop territory uid's next tier needs, or 0 at the top tier or with none.
func next_tier_pop(uid: int) -> int:
	return Population.next_tier_pop(self, uid)


## Whether building uid is idle: with population on, a territory's buildings beyond its pop are idle, and those beyond
## its slots (281), the ones placed last first. Idle buildings skip upkeep but keep their printed VP.
func is_idle(uid: int) -> bool:
	return Population.is_idle(self, uid)


## The name territory uid goes by (248): its city name once settled, else its card's name; "" when uid isn't a territory.
func territory_name(uid: int) -> String:
	return Territories.territory_name(self, uid)


## The settled territory card sits on, or null.
func territory_of(card: CardInstance) -> CardInstance:
	return Territories.territory_of(self, card)


## The tableau in territory groups: [{territory: uid, cards: [uids]}]. Each settled territory is first in its group,
## followed by the cards on it (a unit on its station, 163) in tableau order; groups come in order of first
## appearance, and cards on no territory come last in a group with territory -1.
func territory_groups() -> Array[Dictionary]:
	return Territories.groups(self)


## What is built on settled territory uid: {cities, buildings, idle}, or {} when uid isn't a territory in the
## tableau (the UI asks it whether a card is a settled territory, 101).
func territory_summary(uid: int) -> Dictionary:
	return Territories.summary(self, uid)


## Settled territory uid's {free_slots, total_slots, pop, housing, free_workers} (123), or {} for anything else.
func territory_status(uid: int) -> Dictionary:
	return Territories.status(self, uid)


## Settled territory uid's tooltip (123): its slots, pop and free workers spelled out, then its keywords; "" if not one.
func territory_tooltip(uid: int) -> String:
	return Territories.tooltip(self, uid)
