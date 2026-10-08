class_name Fallback
extends RefCounted
## Whether a built card works (300, 301): an idle building or unit (no worker or slot) skips its upkeep and modifiers
## but keeps its housing and printed VP; a card that has fallen back counts for nothing at all. A building or upgrade
## falls back while its territory is below its tier (301), and an upgrade while its base is idle or fallen back (300).
## Derived from pop every time, never stored: a fallen-back card works again by itself when the cause goes. Static
## functions on the engine's state; GameEngine's public methods call them.


## The index in population.tiers of the tier def needs, or -1 when it needs none (or tiers are off).
static func need(e: GameEngine, def: CardDef) -> int:
	if def.tier == "":
		return -1
	var all := Population.tiers(e)
	for i in all.size():
		if all[i].id == def.tier:
			return i
	return -1


## Whether settled territory territory_uid is too small for def's tier.
static func below_tier(e: GameEngine, def: CardDef, territory_uid: int) -> bool:
	var needs := need(e, def)  # first: most cards need no tier, and the territory's tier costs a search (408)
	return needs >= 0 and Population.tier(e, territory_uid) < needs


## Why def can't go on territory_uid for its tier: "Forum needs a Town (Homeland is a Village)."; "" when it can.
static func tier_error(e: GameEngine, def: CardDef, territory_uid: int) -> String:
	var territory := Territories.settled(e, territory_uid)
	if territory == null or not below_tier(e, def, territory_uid):
		return ""
	return "%s needs %s (%s is %s)." % [def.name, Population.with_article(def.tier_name), territory.shown_name(),
		Population.with_article(Population.tier_name(e, territory_uid))]


## "Forum needs a Town.": def has nowhere big enough.
static func short_tier_error(def: CardDef) -> String:
	return "%s needs %s." % [def.name, Population.with_article(def.tier_name)]


## Why card counts for nothing now, or "": its nearest base that is idle ("Its Farm is idle.") or fallen back below its
## tier ("Its Sanctum has fallen back."), else its own tier ("Needs a Village.").
static func reason(e: GameEngine, card: CardInstance) -> String:
	var at := card
	while at.base_uid >= 0:
		var base := e.zone("tableau").find(at.base_uid)
		if base == null:
			break
		if base.def.uses_worker() and Population.is_idle(e, base.uid):
			return "Its %s is idle." % base.def.name
		if below_tier(e, base.def, base.territory_uid):
			return "Its %s has fallen back." % base.def.name
		at = base
	if below_tier(e, card.def, card.territory_uid):
		return "Needs %s." % Population.with_article(card.def.tier_name)
	return ""


## Whether card has fallen back: it counts for nothing, its housing and printed VP included.
static func fallen_back(e: GameEngine, card: CardInstance) -> bool:
	return reason(e, card) != ""


## The tableau cards that have fallen back (reason non-empty), worked out in one pass (408): uid -> true. Each
## territory's tier and the idle cards (Population.idle_uids) are read once, not per card.
static func fallen_uids(e: GameEngine) -> Dictionary:
	var out := {}
	if not e.population_on():
		return out
	var idle := Population.idle_uids(e)
	var tier_of := {}  # settled territory uid -> the index of its tier
	var by_uid := {}
	for c in e.zone("tableau").cards:
		by_uid[c.uid] = c
		if c.def.type == CardDef.TERRITORY:
			tier_of[c.uid] = Population.tier_at_pop(e, c.pop)
	var seen := {}  # uid -> whether it has fallen back, for the cards worked out so far
	for c in e.zone("tableau").cards:
		if _fallen(e, c, by_uid, idle, tier_of, seen):
			out[c.uid] = true
	return out


## Whether card has fallen back, as reason says: below its own tier, or its base idle or fallen back. seen memoizes.
static func _fallen(e: GameEngine, card: CardInstance, by_uid: Dictionary, idle: Dictionary, tier_of: Dictionary,
		seen: Dictionary) -> bool:
	if seen.has(card.uid):
		return seen[card.uid]
	var needs := need(e, card.def)
	var fallen: bool = needs >= 0 and tier_of.get(card.territory_uid, -1) < needs
	var base: CardInstance = by_uid.get(card.base_uid)
	if not fallen and base != null:
		fallen = idle.has(base.uid) or _fallen(e, base, by_uid, idle, tier_of, seen)
	seen[card.uid] = fallen
	return fallen


## Whether card works: neither idle nor fallen back.
static func works(e: GameEngine, card: CardInstance) -> bool:
	return not Population.is_idle(e, card.uid) and not fallen_back(e, card)


## The uids of the cards on settled territory territory_uid that have fallen back, in tableau order.
static func fallen_on(e: GameEngine, territory_uid: int) -> Array[int]:
	var out: Array[int] = []
	var fallen := fallen_uids(e)
	for card in e.zone("tableau").cards:
		if card.territory_uid == territory_uid and card.def.type == CardDef.BUILDING and fallen.has(card.uid):
			out.append(card.uid)
	return out


## "Sanctum", "Sanctum and Bell", "Sanctum, Bell and Forum": the names of the tableau cards uids.
static func names(e: GameEngine, uids: Array) -> String:
	var all: PackedStringArray = []
	for uid in uids:
		all.append(e.zone("tableau").find(uid).def.name)
	if all.size() <= 1:
		return "".join(all)
	return ", ".join(all.slice(0, -1)) + " and " + all[-1]
