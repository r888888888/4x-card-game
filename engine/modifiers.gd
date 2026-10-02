class_name Modifiers
extends RefCounted
## Standing modifiers (backlog 129): a card's `modifiers` ({key: int}) count while it works. Static functions on the
## engine's state; GameEngine.modifier calls total.

## The modifier keys (DataLoader.MODIFIER_KEYS lists the valid ones): extra actions each turn, and more cards drawn
## each turn (109), housing on every settled territory (110), a higher (or lower) unrest limit (144), and more (or
## fewer) cards Anarchy's renewal trashes (147), and more (or less) insight from each insight gain (157).
const ACTIONS := "actions"
const HAND_SIZE := "hand_size"
const HOUSING := "housing"
const UNREST_LIMIT := "unrest_limit"
const RENEWAL := "renewal"
const INSIGHT_PER_GAIN := "insight_per_gain"


## The cards whose upkeep and modifiers apply: tableau cards that aren't idle, then the cards in ALWAYS_ON_ZONES
## (researched techs, the civilization, the government). Active events come on top (see total).
## One pass over the tableau (150): a building is idle once its territory's earlier buildings use up its pop, as
## is_idle says, without looking each one up.
static func working_cards(e: GameEngine) -> Array[CardInstance]:
	var out: Array[CardInstance] = []
	var tableau := e.zone("tableau").cards
	var pop_on := e.population_on()
	var workers := {}  # settled territory uid -> pop not yet working a building seen so far
	if pop_on:
		for c in tableau:
			if c.def.type == CardDef.TERRITORY:
				workers[c.uid] = c.pop
	for c in tableau:
		if pop_on and c.def.type == CardDef.BUILDING:
			var left: int = workers.get(c.territory_uid, 0)
			workers[c.territory_uid] = left - 1
			if left <= 0:
				continue
		out.append(c)
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


## key summed over the working cards and the active events; 0 when none has it.
static func total(e: GameEngine, key: String) -> int:
	var sum := 0
	for card in working_cards(e) + e.zone("active_events").cards:
		sum += card.def.modifiers.get(key, 0)
	return sum
