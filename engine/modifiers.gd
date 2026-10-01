class_name Modifiers
extends RefCounted
## Standing modifiers (backlog 129): a card's `modifiers` ({key: int}) count while it works. Static functions on the
## engine's state; GameEngine.modifier calls total.

## The modifier keys (DataLoader.MODIFIER_KEYS lists the valid ones): extra actions each turn, and more cards drawn
## each turn (109), and housing on every settled territory (110).
const ACTIONS := "actions"
const HAND_SIZE := "hand_size"
const HOUSING := "housing"


## The cards whose upkeep and modifiers apply: tableau cards that aren't idle, then the cards in ALWAYS_ON_ZONES
## (researched techs, the civilization, the government). Active events come on top (see total).
static func working_cards(e: GameEngine) -> Array[CardInstance]:
	var out: Array[CardInstance] = []
	out.assign(e.zone("tableau").cards.filter(func(c): return not e.is_idle(c.uid)))
	for z in GameEngine.ALWAYS_ON_ZONES:
		out.append_array(e.zone(z).cards)
	return out


## The hand drawn up to each turn: config hand_size plus the hand_size modifier, between 1 and hand_limit (109).
static func hand_size(e: GameEngine) -> int:
	return clampi(e.config.hand_size + total(e, HAND_SIZE), 1, e.config.hand_limit)


## key summed over the working cards and the active events; 0 when none has it.
static func total(e: GameEngine, key: String) -> int:
	var sum := 0
	for card in working_cards(e) + e.zone("active_events").cards:
		sum += card.def.modifiers.get(key, 0)
	return sum
