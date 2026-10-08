class_name TerritoryQueries
extends EngineCore
## The read queries about settled territories and their people (backlog 281, split from EngineQueries): pop and
## housing, building slots, workers and settlement tiers, idle buildings, the administration cap (319), and each
## territory's name, summary, status and tooltip, and its defence and raid warning (moved here in 166). They change
## nothing. EngineQueries extends this with the other read queries.


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


## The most settled territories the realm holds calmly (319): the ruling government's administers plus the
## administers modifier, never below 0; -1 (no cap) with no government or one that sets none.
func admin_cap() -> int:
	return Modifiers.admin_cap(self)


## The unrest the next upkeep adds for territories past admin_cap (319): the k-th one past it adds k (1, 3, 6, 10 in
## all). 0 with unrest off or no cap.
func admin_unrest() -> int:
	return Population.admin_unrest(self)


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


## Sea slots on settled territory territory_uid (366): extra slots only buildings with the config sea_slots' tag may
## fill, on a territory with its keyword; 0 for anything else.
func sea_slots(territory_uid: int) -> int:
	return Territories.sea_slots(self, territory_uid)


## Sea slots left on settled territory territory_uid (366).
func free_sea_slots(territory_uid: int) -> int:
	return Territories.free_sea_slots(self, territory_uid)


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


## Territory uid's tier and the pop the next one needs ("Village: a Town at 8 pop"), just the name at the top tier, or
## "" when it has none (346).
func tier_line(uid: int) -> String:
	return Population.tier_line(self, uid)


## The pop territory uid's next tier needs, or 0 at the top tier or with none.
func next_tier_pop(uid: int) -> int:
	return Population.next_tier_pop(self, uid)


## A longer explanation of play_error's refusal for a tooltip (347), or "" when it has none (or the play is legal).
func play_error_detail(uid: int, target_uid := -1) -> String:
	return Population.no_worker_detail(self, target_uid) if CardPlay.error(self, uid, target_uid) == Population.NO_WORKER else ""


## A longer explanation of build_error's refusal for a tooltip (347), or "" when it has none (or the build is legal).
func build_error_detail(card_id: String, territory_uid := -1) -> String:
	if BuildMenu.error(self, card_id, territory_uid) != Population.NO_WORKER:
		return ""
	return Population.no_worker_detail(self, territory_uid)


## Whether building uid is idle: with population on, a territory's buildings beyond its pop are idle, and those beyond
## its slots (281), the ones placed last first. Idle buildings skip upkeep but keep their printed VP. An upgrade takes no
## worker, so it is never idle; it falls back instead (fallen_back_reason).
func is_idle(uid: int) -> bool:
	return Population.is_idle(self, uid)


## The name of the building upgrade entry card_id builds on ("Farm", 302), or "" for anything else.
func upgrade_base_name(card_id: String) -> String:
	if not card_db.has(card_id) or not card_db[card_id].is_upgrade():
		return ""
	return card_db[card_db[card_id].upgrade_of].name


## The name of the settlement tier card card_id needs ("Village", 301, 302), or "" when it needs none or tiers are off.
func card_tier_name(card_id: String) -> String:
	return card_db[card_id].tier_name if card_db.has(card_id) else ""


## Upgrade card_id's face rules, one a line: what it adds (302, 382); "" for anything else.
func upgrade_rules_text(card_id: String) -> String:
	if not card_db.has(card_id) or not card_db[card_id].is_upgrade():
		return ""
	return "\n".join(card_db[card_id].face(card_db).rules)


## Building uid's upgrade rows for its details (387): {card_id, base, built, error} per base (uid, then its upgrades)
## and build-menu entry, locked or not, that upgrades it; [] for anything but a building in the tableau.
func upgrade_rows(uid: int) -> Array[Dictionary]:
	return Upgrades.rows(self, uid)


## Whether building uid's chain has an upgrade not yet built, whatever stops it now (410): its card's upgrade badge.
func has_unbuilt_upgrades(uid: int) -> bool:
	return upgrade_rows(uid).any(func(r): return r.built == -1)


## Building uid's upgrades and theirs, depth first in build order: its card's ribbons (302).
func upgrade_tree(uid: int) -> Array[int]:
	return Upgrades.tree(self, uid)


## The Build modal's upgrade rows for settled territory t (302): {card_id, base} for each unlocked upgrade entry and
## each building on t it builds on, by building in tableau order, then menu order.
func upgrade_options(t: int) -> Array[Dictionary]:
	return Upgrades.options(self, t)


## The building upgrade uid is built onto (300), or -1 when uid isn't an upgrade in the tableau.
func upgrade_base(uid: int) -> int:
	var card := zone("tableau").find(uid)
	return card.base_uid if card != null else -1


## The upgrades built onto building uid (300), in build order.
func upgrades_on(uid: int) -> Array[int]:
	return Upgrades.on(self, uid)


## Why card uid has fallen back and counts for nothing now: below its tier ("Needs a Village.", 301), or an upgrade
## whose base is idle ("Its Farm is idle.", 300) or has fallen back ("Its Sanctum has fallen back."); "" while it
## counts, or for a card not in the tableau.
func fallen_back_reason(uid: int) -> String:
	var card := zone("tableau").find(uid)
	return Fallback.reason(self, card) if card != null else ""


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

