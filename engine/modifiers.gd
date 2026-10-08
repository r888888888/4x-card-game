class_name Modifiers
extends RefCounted
## Standing modifiers (backlog 129): a card's `modifiers` ({key: int}) count while it works. Static functions on the
## engine's state; GameEngine.modifier calls total.

## The modifier keys (DataLoader.MODIFIER_KEYS lists the valid ones): extra actions each turn, and more cards drawn
## each turn (109), housing on every settled territory (110), a higher (or lower) unrest limit (144), and more (or
## fewer) cards Anarchy's renewal trashes (147), more (or less) insight from each insight gain (157), and more (or
## fewer) territories the government administers (319).
const ACTIONS := "actions"
const HAND_SIZE := "hand_size"
const HOUSING := "housing"
const UNREST_LIMIT := "unrest_limit"
const RENEWAL := "renewal"
const INSIGHT_PER_GAIN := "insight_per_gain"
const ADMINISTERS := "administers"


## The cards whose upkeep and modifiers apply: tableau cards that aren't idle, then the cards in ALWAYS_ON_ZONES
## (researched techs, the civilization, the government). Active events come on top (see total).
## One pass over the tableau (150): a building or unit is idle once its territory's earlier ones use up its pop, or a
## building once they use up its slots (281), as is_idle says, without looking each one up. A card below its tier
## falls back (301), and an upgrade works with its base (300), which comes before it in the tableau.
static func working_cards(e: GameEngine) -> Array[CardInstance]:
	var out: Array[CardInstance] = []
	var tableau := e.zone("tableau").cards
	var pop_on := e.population_on()
	var workers := {}  # settled territory uid -> pop not yet working a building seen so far
	var slots := {}  # settled territory uid -> slots not yet taken by a building seen so far
	var sea := {}  # settled territory uid -> sea slots not yet taken (366; see Territories.slot_use)
	var tier_of := {}  # settled territory uid -> the index of its tier (301)
	if pop_on:
		var tiers := Population.tiers(e)
		for c in tableau:
			if c.def.type == CardDef.TERRITORY:
				workers[c.uid] = c.pop
				tier_of[c.uid] = Population.tier_at_pop(e, c.pop)
				slots[c.uid] = c.def.slots + Population.tier_slots(tiers, c.pop)
				sea[c.uid] = Territories.sea_slots_of(e, c)
		for c in tableau:
			if c.def.type == CardDef.CITY and slots.has(c.territory_uid):
				slots[c.territory_uid] += c.def.slots
	var kept := {}  # uid -> true for the tableau cards kept so far
	for c in tableau:
		if c.base_uid >= 0 and not kept.has(c.base_uid):
			continue
		if pop_on and c.def.uses_worker():
			var left: int = workers.get(c.territory_uid, 0)
			workers[c.territory_uid] = left - 1
			var room: int = 1
			if c.def.type == CardDef.BUILDING and sea.get(c.territory_uid, 0) > 0 and Territories.takes_sea_slot(e, c.def):
				sea[c.territory_uid] -= 1
			elif c.def.type == CardDef.BUILDING:
				room = slots.get(c.territory_uid, 0)
				slots[c.territory_uid] = room - 1
			if left <= 0 or room <= 0:
				continue
		if c.def.tier != "" and tier_of.get(c.territory_uid, -1) < Fallback.need(e, c.def):
			continue  # fallen back below its tier, keeping its worker and slot (301)
		if c.def.project and Sites.unfinished(e, c):  # takes its worker and slot, but works once completed (286)
			continue
		out.append(c)
		kept[c.uid] = true
	for z in GameEngine.ALWAYS_ON_ZONES:
		out.append_array(e.zone(z).cards)
	return out


## The hand drawn up to each turn: config hand_size plus the hand_size modifier, between 1 and hand_limit (109).
static func hand_size(e: GameEngine) -> int:
	return clampi(e.config.hand_size + total(e, HAND_SIZE), 1, e.config.hand_limit)


## The most unrest the realm holds (144): the ruling government's unrest_limit plus the unrest_limit modifier, never
## below 0; -1 (no limit) while unrest is off, with no government, or with one that sets none.
static func unrest_limit(e: GameEngine) -> int:
	var gov := e.zone("government")
	if not e.unrest_on() or gov.is_empty() or gov.cards[0].def.unrest_limit == 0:
		return -1
	return maxi(0, gov.cards[0].def.unrest_limit + total(e, UNREST_LIMIT))


## The most settled territories the realm holds calmly (319): the ruling government's administers plus the
## administers modifier, never below 0; -1 (no cap) with no government or one that sets none.
static func admin_cap(e: GameEngine) -> int:
	var gov := e.zone("government")
	if gov.is_empty() or gov.cards[0].def.administers == 0:
		return -1
	return maxi(0, gov.cards[0].def.administers + total(e, ADMINISTERS))


## key summed over the working cards and the active events; 0 when none has it. The idle pass (working_cards) runs only
## when a tableau card has key (294): otherwise only ALWAYS_ON_ZONES and the active events can.
static func total(e: GameEngine, key: String) -> int:
	var sum := 0
	for card in e.zone("tableau").cards:
		if card.def.modifiers.has(key):
			for c in working_cards(e) + e.zone("active_events").cards:
				sum += c.def.modifiers.get(key, 0)
			return sum
	for z in GameEngine.ALWAYS_ON_ZONES:
		for c in e.zone(z).cards:
			sum += c.def.modifiers.get(key, 0)
	for c in e.zone("active_events").cards:
		sum += c.def.modifiers.get(key, 0)
	return sum
