class_name GameEngine
extends EngineCore
## Game rules and player actions. Uses no scene nodes: the UI (or a headless
## script) calls the action methods and listens to the signals.
##
## Turn loop: upkeep -> draw -> play (player) -> event -> cleanup.
##
## The state, its accessors, the signals and the helpers effects call (gain, draw, create_card, …) live in the parent
## class EngineCore (engine/engine_core.gd, 125). The rules live in modules of static functions that the methods here
## call: TurnLoop, CardPlay, Population, Research, Supply and Territories, and Events. The modules may call the
## engine's _ helpers (_log, _resolve, _make_card from EngineCore; _blocked_error here).

const ZONES: Array[String] = ["deck", "hand", "discard", "tableau", "territory_deck", "frontier", "reveal", "research_deck", "researched", "future_techs", "event_deck", "future_events", "active_events", "event_discard", "civilization", "government", "governments", "removed", "trashed"]
## Zones of always-on permanents outside the tableau: every card there resolves upkeep and scores its printed VP.
const ALWAYS_ON_ZONES: Array[String] = ["researched", "civilization", "government"]
## The zones a create effect may put a new card into.
const CREATE_ZONES: Array[String] = ["tableau", "hand", "discard", "deck"]
## The kinds of decision pending() can report.
const PENDING_EXPLORE := "explore"
const PENDING_DISCARD := "discard"
const PENDING_RENEWAL := "renewal"  # Anarchy asks you to trash cards from the discard (147)
const PENDING_GOVERNMENT := "government"  # Anarchy has ended: choose a government from the government deck (154)
## A tech's state in tech_tree(): bought, learnable now, in the research deck but waiting for its prereq (140), or
## in an era not added yet.
const TECH_RESEARCHED := "researched"
const TECH_AVAILABLE := "available"
const TECH_LOCKED := "locked"
const TECH_FUTURE := "future"
## The actions still allowed while a discard is owed (see _blocked_error).
const _DISCARD_ALLOWS: Array[String] = ["discard", "supply", "research"]

## A new engine on a deep copy of this one's state (GameState.copy). Nothing is connected to its signals and
## it logs to its own copy of the log, so playing on it never touches this game.
func fork() -> GameEngine:
	var f := GameEngine.new(card_db, config)
	f.state = state.copy()
	return f


# --- Queries ---

func turn_limit() -> int:
	return config.turn_limit


## Printed VP on the tableau and in ALWAYS_ON_ZONES, VP from effects, and vp_per_pop for each pop (when population
## is on).
func score() -> int:
	var total := bonus_score
	for z in ["tableau"] + ALWAYS_ON_ZONES:
		for card in zone(z).cards:
			total += card.def.vp
	if population_on():
		total += total_pop() * config.population.vp_per_pop
	return total


## The uid of the civilization you play as, or -1 if the game has none.
func civilization() -> int:
	var civ := zone("civilization")
	return civ.cards[0].uid if not civ.is_empty() else -1


## The uid of the ruling government, or -1 if the game has none.
func government() -> int:
	var gov := zone("government")
	return gov.cards[0].uid if not gov.is_empty() else -1


## Counters on active event uid: the Famine's (083); 0 for any other event or uid. The event panel shows them in
## place of turns left.
func event_counters(uid: int) -> int:
	return Famine.counters_on(self, uid)


## The active Famine's counters (083), or 0 with no Famine.
func famine_counters() -> int:
	return Famine.counters(self)


## Whether the population rules apply (the config has a population block).
func population_on() -> bool:
	return not config.get("population", {}).is_empty()


## Whether the unrest rules are on (144): the config lists unrest as a resource.
func unrest_on() -> bool:
	return config.get("resources", []).has(UNREST)


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


## Food to grow settled territory territory_uid by 1 pop: its current pop + 1.
func grow_cost(territory_uid: int) -> int:
	return pop(territory_uid) + 1


## What relieve_famine costs: population.famine.relief ({resource: amount}), or {} when the Famine can't be relieved.
func famine_relief() -> Dictionary:
	return config.get("famine", {}).get("relief", {}).duplicate()


## A card_played or event_drawn outcome as text: "+2 food, −1 wealth, +1 VP, drew 2 cards, created 1 card"; "" when
## it did nothing.
func outcome_summary(outcome: Dictionary) -> String:
	return Events.outcome_summary(outcome)


## Why relieve_famine would refuse: game over or a pending decision, no active Famine, no relief price in the config,
## or not enough to pay it. "" if it can.
func relieve_famine_error() -> String:
	return Famine.relieve_error(self)


## Pays the config's population.famine.relief and the active Famine leaves the game at once (084). False (and no
## change) if relieve_famine_error says no.
func relieve_famine() -> bool:
	return Famine.relieve(self)


## Why settled territory territory_uid can't grow right now, or "" if it can.
func grow_error(territory_uid: int) -> String:
	return Population.grow_error(self, territory_uid)


## Pays grow_cost food for +1 pop on settled territory territory_uid. False (and no change) if
## grow_error says it can't.
func grow(territory_uid: int) -> bool:
	return Population.grow(self, territory_uid)


## Pop summed over every settled territory.
func total_pop() -> int:
	return Population.total_pop(self)


## The decision the player owes before the game can go on, or {} when none:
## {kind: PENDING_GOVERNMENT, options: the government deck's uids (154)} or
## {kind: PENDING_EXPLORE, options: territory uids top first, source: uid of the card that explored} or
## {kind: PENDING_RENEWAL, count: cards still to trash, options: discard uids but governments (147)} or
## {kind: PENDING_DISCARD, count: cards still to discard, options: hand uids}.
func pending() -> Dictionary:
	if state.choosing_government:
		return {"kind": PENDING_GOVERNMENT, "options": zone("governments").cards.map(func(c): return c.uid)}
	if not pending_choice.is_empty():
		return {"kind": PENDING_EXPLORE, "options": pending_choice.options, "source": pending_choice.source.uid}
	if state.renewal_left > 0:
		return {"kind": PENDING_RENEWAL, "count": state.renewal_left, "options": Anarchy.renewal_options(self)}
	if state.discard_left > 0:
		return {"kind": PENDING_DISCARD, "count": state.discard_left, "options": zone("hand").cards.map(func(c): return c.uid)}
	return {}


## The name of the card that makes insight, for hints: the first whose effects gain insight in config deck order,
## then supply order; "" when there is none.
func research_card_name() -> String:
	return Research.card_name(self)


## The highest era of techs added to the research deck so far (1 at the start).
func era() -> int:
	return state.era


## How the next upkeep changes each resource on hand, food net of what pop eats (may be negative), plus
## "starve": the pop that food shortfall would starve, after famine guards. {} on the last turn or after game over.
## Runs the upkeep effects on a fork: nothing here changes, is logged or emitted.
func upkeep_forecast() -> Dictionary:
	if is_over or turn >= turn_limit():
		return {}
	var f := fork()
	TurnLoop.resolve_upkeep(f)
	var forecast := {}
	for r in resources:
		forecast[r] = f.resources[r] - resources[r]
	var need: int = f.total_pop() * config.population.food_upkeep if population_on() else 0
	forecast[FOOD] = forecast.get(FOOD, 0) - need
	var pop_before := f.total_pop()
	if population_on():
		Population.feed(f)
	forecast.starve = pop_before - f.total_pop()
	return forecast


## Upkeeps left for active event uid before it is discarded (0 if uid isn't an active event).
func event_turns_left(uid: int) -> int:
	return Events.turns_left(self, uid)


## The pop and wealth thresholds that add an era at the start of a turn: {era: {pop?, wealth?}}.
func era_unlocks() -> Dictionary:
	return config.get("era_unlocks", {})


## The era_unlocks entries for eras above the current one.
func upcoming_era_unlocks() -> Dictionary:
	return Research.upcoming_era_unlocks(self)


## The tech tree by era: one {era, name, reached, unlocks, techs} per era with techs in research_deck, in era
## order. unlocks is the era's upcoming_era_unlocks entry ({} once reached); techs are its tech_tree entries.
func tech_eras() -> Array[Dictionary]:
	return Research.eras(self)


## Every tech in config research_deck, by era then config order: [{id, era, prereq, state (TECH_*), cost (insight
## now; printed for a future tech), gives (card ids it creates or unlocks), uid (-1 for a future tech), eureka (whether
## its eureka is met, 141)}].
func tech_tree() -> Array[Dictionary]:
	return Research.tree(self)


## Era n's name from config era_names ("Stone Age"), or "Era n".
func era_name(n: int) -> String:
	return config.get("era_names", {}).get(n, "Era %d" % n)


## What tech uid costs in insight right now: its printed cost less civilization discounts, its eureka when met (141)
## and 1 per era added past its own (diffusion, 142), never under 1 (0 if uid isn't a tech).
func tech_cost(uid: int) -> int:
	return Research.cost(self, uid)


## Why tech uid can't be learned right now, or "" if it can: the game is over or a choice is pending, it isn't in the
## research deck, its prereq isn't researched, or the insight is short.
func buy_tech_error(uid: int) -> String:
	return Research.buy_error(self, uid)


## The cards in the supply and how many copies of each are left: {card_id: count}, in config order.
func supply() -> Dictionary:
	return state.supply.duplicate()


## Copies of card_id left in the supply (0 if it isn't sold there).
func supply_left(card_id: String) -> int:
	return state.supply.get(card_id, 0)


## The supply's card ids whose piles aren't locked (sold-out ones included), in config order: what the supply shows.
func open_supply_piles() -> Array[String]:
	return Supply.open_piles(self)


## Whether card_id's supply pile is still locked (a tech's unlock effect opens it). supply() lists locked piles too.
func supply_locked(card_id: String) -> bool:
	return state.locked_supply.has(card_id)


## What a copy of card_id costs in wealth from the supply (0 if it isn't sold there).
func buy_price(card_id: String) -> int:
	return Supply.price(self, card_id)


## Why a copy of card_id can't be bought from the supply right now, or "" if it can.
func buy_error(card_id: String) -> String:
	return Supply.buy_error(self, card_id)


func count_tag(tag: String, zone_name: String) -> int:
	return zone(zone_name).count_tag(tag)


## How many cards can be played from hand each turn: the ruling government's actions (127), or -1 for no limit.
func actions_per_turn() -> int:
	return CardPlay.actions_per_turn(self)


## The most unrest the realm holds (144): the government's unrest_limit plus the unrest_limit modifier, never below 0;
## -1 (no limit) while unrest is off or no government sets one.
func unrest_limit() -> int:
	return Modifiers.unrest_limit(self)


## The ruling Anarchy card's uid (145), or -1.
func anarchy() -> int:
	var card := Anarchy.active(self)
	return card.uid if card != null else -1


## Why revolt would refuse (148): game over or a pending decision, Anarchy already ruling, or no active event that
## lets you revolt. "" if it can.
func revolt_error() -> String:
	return Anarchy.revolt_error(self)


## Starts Anarchy now, by choice, with renewal owed at once (148). False (and no change) if revolt_error says no.
func revolt() -> bool:
	return Anarchy.revolt(self)


## Why renew(uid) would refuse (147): renewal isn't pending, or uid isn't a discard card other than a government. ""
## if it can.
func renew_error(uid: int) -> String:
	return Anarchy.renew_error(self, uid)


## Trashes discard card uid for Anarchy's renewal: it leaves the game and unrest drops by 1 (147). False (and no
## change) if renew_error says no.
func renew(uid: int) -> bool:
	return Anarchy.renew(self, uid)


## What restore_order pays (146): config unrest.relief ({resource: amount}), or {} when order can't be bought.
func order_relief() -> Dictionary:
	return Anarchy.relief(self)


## Why restore_order would refuse: game over or a pending decision, no Anarchy, no relief in the config, or not
## enough to pay it. "" if it can.
func restore_order_error() -> String:
	return Anarchy.restore_error(self)


## Pays the config's unrest.relief and Anarchy ends: a government is to be chosen (146, 154). False (and no change) if
## restore_order_error says no.
func restore_order() -> bool:
	return Anarchy.restore(self)


## The counters on the ruling Anarchy card (145): 0 the turn it falls, +1 each turn after; 0 without Anarchy.
func anarchy_counters() -> int:
	var card := Anarchy.active(self)
	return card.counters if card != null else 0


## Why choose_government(uid) would refuse (154): no choice is owed, or uid isn't in the government deck. "" if it can.
func choose_government_error(uid: int) -> String:
	return Anarchy.choose_government_error(self, uid)


## Government uid leaves the government deck and rules, its play effects resolving (its cost unpaid), and unrest
## drops to at most half its limit (154). Uses no action. False (and no change) if choose_government_error says no.
func choose_government(uid: int) -> bool:
	return Anarchy.choose_government(self, uid)


## Whether unrest has reached a limit (144); false with no limit.
func at_unrest_limit() -> bool:
	var limit := unrest_limit()
	return limit >= 0 and resources.get(UNREST, 0) >= limit


## The hand drawn up to each turn: config hand_size plus the hand_size modifier, between 1 and hand_limit (109).
func hand_size() -> int:
	return Modifiers.hand_size(self)


## key ("actions", …) summed over the `modifiers` of the working tableau cards, ALWAYS_ON_ZONES and active events (129).
func modifier(key: String) -> int:
	return Modifiers.total(self, key)


## Actions left this turn (playing a card from hand uses 1; nothing else does), or -1 for no limit.
func actions_left() -> int:
	return CardPlay.actions_left(self)


## What hand card uid costs to play now: its cost less the civilization's discounts (108), never below 0 per
## resource; {} if uid isn't in the hand, or there's no hand yet (before new_game, 136).
func play_cost(uid: int) -> Dictionary:
	if not zones.has("hand"):
		return {}
	var card := zone("hand").find(uid)
	return Discounts.cost(self, card.def) if card != null else {}


## Why hand card uid can't be played on any target right now, or "" if it can. Unlike play_error, a card
## with several valid targets isn't blocked by the choice between them: it is checked on the first.
func playable_error(uid: int) -> String:
	var targets := valid_targets(uid)
	return play_error(uid, targets[0] if needs_target(uid) and not targets.is_empty() else -1)


## Why the card can't be played right now, or "" if it can.
func play_error(uid: int, target_uid := -1) -> String:
	return CardPlay.error(self, uid, target_uid)


## The uids hand card uid can be played on; [] if it needs no target. A building's targets are the
## settled territories with a free slot; a targeting effect's are the cards in its target zone.
func valid_targets(uid: int) -> Array[int]:
	return CardPlay.targets_of(self, uid)


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


## Whether building uid is idle: with population on, a territory's buildings beyond its pop are idle,
## the ones placed last first. Idle buildings skip upkeep but keep their printed VP.
func is_idle(uid: int) -> bool:
	return Population.is_idle(self, uid)


## Whether playing hand card uid needs the player to pick a target: it is playable and has several valid targets.
func needs_target_choice(uid: int) -> bool:
	return CardPlay.needs_target_choice(self, uid)


func needs_target(uid: int) -> bool:
	var card := zone("hand").find(uid)
	return card != null and CardPlay.needs_target(card)


## A card definition's details for the details modal: {name, type, cost, vp, rules, state, terms}, with no state;
## {} for an unknown id. terms are [{term, text}], unique, in first-use order.
func def_details(card_id: String) -> Dictionary:
	return CardDetails.of_def(self, card_id)


## Like def_details for card uid in any zone, with its live state (pop, slots, idle, price now); {} if not found.
func card_details(uid: int) -> Dictionary:
	return CardDetails.of_card(self, uid)


## The settled territory card sits on, or null.
func territory_of(card: CardInstance) -> CardInstance:
	return Territories.territory_of(self, card)


## The tableau in territory groups: [{territory: uid, cards: [uids]}]. Each settled territory is first in
## its group, followed by the cards on it in tableau order; groups come in order of first appearance, and
## cards on no territory come last in a group with territory -1.
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


## Cards that must still be discarded before the turn can end (0 when none is pending).
func discard_needed() -> int:
	return state.discard_left


## Why the turn can't end right now, or "" if it can.
func end_turn_error() -> String:
	return _blocked_error("end_turn")


## Why the supply screen can't open now, or "". A discard owed doesn't block it: you can browse, and
## buy_error says why each card can't be bought.
func supply_error() -> String:
	return _blocked_error("supply")


# --- Actions ---

## Starts a new game with seed p_seed as civilization civ_id ("" for the config's starting.civilization, if any).
## Refuses and changes nothing when new_game_error(civ_id) isn't "".
func new_game(p_seed: int, civ_id := "") -> void:
	if new_game_error(civ_id) != "":
		return
	TurnLoop.new_game(self, p_seed, civ_id if civ_id != "" else config.starting.get("civilization", ""))


## Why new_game can't start as civilization civ_id, or "" if it can (a listed civilization, or "" for the
## config's starting one).
func new_game_error(civ_id: String) -> String:
	if civ_id != "" and not civilizations().has(civ_id):
		return "Unknown civilization '%s'." % civ_id
	return ""


## The civilizations a game may start as (config civilizations), in order.
func civilizations() -> Array[String]:
	return config.get("civilizations", [] as Array[String]).duplicate()


## Pays the cost, moves the card (permanents to the tableau), resolves its "play" effects on
## target_uid, then emits card_played with what happened. A card that needs a target and has only
## one valid target uses it when target_uid is -1; a card that needs none ignores target_uid.
func play_card(uid: int, target_uid := -1) -> bool:
	return CardPlay.play(self, uid, target_uid)


## Why choose(uid) would refuse: no explore choice is open, or uid isn't one of its options. "" if it can.
func choose_error(uid: int) -> String:
	return Territories.choose_error(self, uid)


## Resolves the pending choice: keeps territory uid in the frontier and puts the other revealed
## territories at the bottom of the territory deck. False (and no change) if choose_error says no.
func choose(uid: int) -> bool:
	return Territories.choose(self, uid)


## Learns tech uid from the research deck (140): pays its tech_cost in insight, moves it to the researched row and
## resolves its play effects; no card or action. Once the research deck is empty the lowest waiting era's techs
## arrive. False (and no change) if buy_tech_error says no.
func buy_tech(uid: int) -> bool:
	return Research.buy(self, uid)


## Pays buy_price wealth for a new copy of card_id from the supply and puts it on the discard.
## False (and no change) if buy_error says it can't.
func buy(card_id: String) -> bool:
	return Supply.buy(self, card_id)


## Why discard_card(uid) would refuse: the game is over, a choice is pending, or uid isn't in the hand. "" if it
## can, including while an end-of-turn discard is owed.
func discard_error(uid: int) -> String:
	return TurnLoop.discard_error(self, uid)


## Discards one card from the hand for free, any time in the turn. If an end-of-turn discard is
## pending this counts toward it, and the turn ends once the hand is down to the limit. False (and no
## change) if discard_error says no.
func discard_card(uid: int) -> bool:
	return TurnLoop.discard_card(self, uid)


## Ends the turn. Over the hand limit, waits for discard_card calls instead (not on the last turn).
## Does nothing if end_turn_error says no.
func end_turn() -> void:
	TurnLoop.end_turn(self)


# --- Internals (the modules call these too) ---

## Why action ("play", "grow", "buy", "end_turn", "supply", "discard", "research") is blocked by the game being over
## or by a pending() decision, or "". Only discarding, browsing the supply and learning techs go on while a discard is
## owed.
func _blocked_error(action: String) -> String:
	if is_over:
		return "The game is over."
	match pending().get("kind", ""):
		PENDING_GOVERNMENT:
			return "Choose a government first."
		PENDING_EXPLORE:
			return "Choose a territory first."
		PENDING_RENEWAL:
			return "Anarchy: trash %d card%s from your discard first." % [state.renewal_left, "" if state.renewal_left == 1 else "s"]
		PENDING_DISCARD:
			return "" if _DISCARD_ALLOWS.has(action) else "Discard down to %d cards first." % config.hand_limit
	return ""

