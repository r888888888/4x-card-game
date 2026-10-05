class_name EngineQueries
extends TerritoryQueries
## The read queries the UI, the sim and the tests ask (backlog 249): state, derived values and the error queries that
## gate several actions at once. They change nothing. The territory queries come from TerritoryQueries, which this
## extends (281). GameEngine extends this with fork, the player actions and their
## *_error queries. The constants (zones, pending kinds, tech states) stay on GameEngine, so these name them through it.


func turn_limit() -> int:
	return config.turn_limit


## Printed VP on the tableau and in ALWAYS_ON_ZONES, VP from effects, and vp_per_pop for each pop (when population
## is on).
func score() -> int:
	var total := bonus_score
	for z in ["tableau"] + GameEngine.ALWAYS_ON_ZONES:
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


## Counters on active event uid: the Famine's (083) or Anarchy's left (253); 0 for any other event or uid. The event panel shows them in
## place of turns left.
func event_counters(uid: int) -> int:
	var anarchy := Anarchy.active(self)
	return Anarchy.counters_left(self) if anarchy != null and anarchy.uid == uid else Famine.counters_on(self, uid)


## The active Famine's counters (083), or 0 with no Famine.
func famine_counters() -> int:
	return Famine.counters(self)


## Whether the population rules apply (the config has a population block).
func population_on() -> bool:
	return not config.get("population", {}).is_empty()


## Whether the unrest rules are on (144): the config lists unrest as a resource.
func unrest_on() -> bool:
	return config.get("resources", []).has(UNREST)


## What relieve_famine costs: population.famine.relief ({resource: amount}), or {} when the Famine can't be relieved.
func famine_relief() -> Dictionary:
	return config.get("famine", {}).get("relief", {}).duplicate()


## A card_played or event_drawn outcome as text: "+2 food, −1 wealth, +1 VP, drew 2 cards, created 1 card"; "" when
## it did nothing.
func outcome_summary(outcome: Dictionary) -> String:
	return Events.outcome_summary(outcome)


## The decision the player owes before the game can go on, or {} when none: {kind: PENDING_GOVERNMENT, options: the
## government deck's uids (154)}, {kind: PENDING_EXPLORE, options: territory uids top first, source: uid of the card
## that explored}, {kind: PENDING_RENEWAL, count: cards still to trash, options: discard uids but governments (147)},
## {kind: PENDING_DISCARD, count: cards still to discard, options: hand uids} or {kind: PENDING_EVENT_CHOICE, uid: the
## choice event's, options: its option indices (269)}.
func pending() -> Dictionary:
	var p := state.pending.duplicate(true)
	match p.get("kind", ""):
		GameEngine.PENDING_GOVERNMENT:
			p.erase("ends_turn")
			p.options = Anarchy.government_options(self)
		GameEngine.PENDING_RENEWAL:
			p.options = Anarchy.renewal_options(self)
		GameEngine.PENDING_DISCARD:
			p.options = zone("hand").cards.map(func(c): return c.uid)
	return p


## The name of the card that makes insight, for hints: the first whose effects gain insight in config deck order,
## then supply order; "" when there is none.
func research_card_name() -> String:
	return Research.card_name(self)


## The highest era of techs added to the research deck so far (1 at the start).
func era() -> int:
	return state.era


## How the next upkeep changes each resource on hand, food net of what pop eats (may be negative), plus
## "starve": the pop that food shortfall would starve, after famine guards. When Anarchy will rule next turn it
## includes the drain on the stores after upkeep and feeding (156). {} on the last turn or after game over.
## Runs the upkeep effects on a fork: nothing here changes, is logged or emitted.
func upkeep_forecast() -> Dictionary:
	if is_over or turn >= turn_limit():
		return {}
	var f := _as_engine().fork()
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
	if Anarchy.rules_next_turn(self):
		var stores := {}
		for r in [FOOD, WEALTH]:
			stores[r] = resources.get(r, 0) + forecast.get(r, 0)
		var lost := Anarchy.drain_of(self, stores)
		for r in lost:
			forecast[r] -= lost[r]
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


## What a copy of supply pile card_id would cost to play, after the civilization's type and tag discounts (232);
## {} if card_id has no pile.
func supply_play_cost(card_id: String) -> Dictionary:
	return Discounts.cost(self, card_db[card_id]) if state.supply.has(card_id) and card_db.has(card_id) else {}


func count_tag(tag: String, zone_name: String) -> int:
	return zone(zone_name).count_tag(tag)


## How many cards can be played from hand each turn: the ruling government's actions (127), or -1 for no limit.
func actions_per_turn() -> int:
	return CardPlay.actions_per_turn(self)


## The most unrest the realm holds (144): the government's unrest_limit plus the unrest_limit modifier, never below 0;
## -1 (no limit) while unrest is off or no government sets one.
func unrest_limit() -> int:
	return Modifiers.unrest_limit(self)


## The unrest the next upkeep adds for big territories (282): +1 per tier each settled territory is above the ruling
## government's tolerated tier. 0 with unrest or tiers off, no government, or one that tolerates any size.
func size_unrest() -> int:
	return Population.size_unrest(self)


## The id of the government Anarchy plays as (the config's unrest.anarchy), or "" without unrest (205: the
## revolution's confirmation shows its flavor).
func anarchy_id() -> String:
	return config.get("unrest", {}).get("anarchy", "")


## The ruling Anarchy card's uid (145), or -1.
func anarchy() -> int:
	var card := Anarchy.active(self)
	return card.uid if card != null else -1


## What restore_order pays (155): c × (c + 1) wealth for c counters left ({resource: amount}), {} without Anarchy.
func order_relief() -> Dictionary:
	return Anarchy.relief(self)


## The counters left on the ruling Anarchy (155): one comes off at the end of each of its turns, and calming lowers
## them for good; never below 1 while it rules, 0 without Anarchy.
func anarchy_counters() -> int:
	return Anarchy.counters_left(self)


## The counters a revolution declared now would bring (155): ⌈max_counters × unrest ÷ unrest_limit()⌉, between 1 and
## max_counters; 0 when revolt_error says no.
func revolt_forecast() -> int:
	return Anarchy.revolt_forecast(self)


## Whether unrest has reached a limit (144); false with no limit.
func at_unrest_limit() -> bool:
	var limit := unrest_limit()
	return limit >= 0 and resources.get(UNREST, 0) >= limit


## Whether the next upkeep brings unrest to a limit, so the next turn falls into Anarchy unless it is calmed first
## (228); false with no limit. The era's unrest isn't counted.
func anarchy_ahead() -> bool:
	var limit := unrest_limit()
	return limit >= 0 and resources.get(UNREST, 0) + upkeep_forecast().get(UNREST, 0) >= limit


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


## The resources of hand card uid's play_cost the player is short of, in the cost's order (180); [] if uid isn't in
## the hand.
func play_shortfall(uid: int) -> Array[String]:
	return shortfall(play_cost(uid))


## Why hand card uid can't be played on any target right now, or "" if it can. Unlike play_error, a card
## with several valid targets isn't blocked by the choice between them: it is checked on the first.
func playable_error(uid: int) -> String:
	var targets := valid_targets(uid)
	return CardPlay.error(self, uid, targets[0] if needs_target(uid) and not targets.is_empty() else -1)


## The uids hand card uid can be played on; [] if it needs no target. A building's targets are the
## settled territories with a free slot; a targeting effect's are the cards in its target zone.
func valid_targets(uid: int) -> Array[int]:
	return CardPlay.targets_of(self, uid)


## Where unit uid in the tableau is stationed (160): a territory uid, or -1 when uid isn't a unit in the tableau.
func unit_station(uid: int) -> int:
	var card := zone("tableau").find(uid)
	return card.station_uid if card != null and card.def.type == CardDef.UNIT else -1


## "from Homeland" for unit uid stationed away from its home (163), else "".
func unit_origin(uid: int) -> String:
	return Military.unit_origin(self, uid)


## Settled territory uid's defence (161): defense_parts(uid).total, or 0 for anything else.
func defense(uid: int) -> int:
	return Military.defense_parts(self, uid).get("total", 0)


## Settled territory uid's defence by source (161): {units, buildings, cities, terrain, total}, or {} for anything else.
func defense_parts(uid: int) -> Dictionary:
	return Military.defense_parts(self, uid)


## The territory active raid uid will strike (162), or -1 when uid isn't an active raid.
func raid_target(uid: int) -> int:
	return Military.raid_target(self, uid)


## Each announced raid as {uid, target, strength, defense}, in the order drawn, with its target's current defence
## (162); [] with no raid active.
func raid_forecast() -> Array[Dictionary]:
	return Military.raid_forecast(self)


## A raid_resolved outcome as its result line (271), "Raiders pillaged Hills: −2 food, −1 pop."; the raid modal shows it.
func raid_outcome_text(outcome: Dictionary) -> String:
	return Military.outcome_text(self, outcome)


## Active raid uid's announcement, "Raiders will strike Hills in 2 turns: 3 against your 0.", with the target's current
## defence (162); "" for anything else.
func raid_line(uid: int) -> String:
	return Military.raid_line(self, uid)


## Active raid uid's board tag, "Hills 3 vs 0" (162); "" for anything else.
func raid_tag(uid: int) -> String:
	return Military.raid_tag(self, uid)


## Whether active raid uid's target is short of its strength now (162); false for anything else.
func raid_short(uid: int) -> bool:
	return Military.raid_short(self, uid)


## The mark on settled territory uid while raids are aimed at it, "Raiders strike in 2 turns: 3 vs 0" (one line each,
## 162); "" when none is.
func raid_warning(territory_uid: int) -> String:
	return Military.raid_warning(self, territory_uid)


## The units stationed on territory uid (160), in the order they were recruited; [] for anything else.
func units_at(uid: int) -> Array[int]:
	return Territories.units_at(self, uid)


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


## The name of the zone holding card uid, or "" when none does (176).
func zone_of(uid: int) -> String:
	for z in GameEngine.ZONES:
		if zones[z].find(uid) != null:
			return z
	return ""


## The most cards the hand may hold at the end of a turn (config hand_limit).
func hand_limit() -> int:
	return config.hand_limit


## Whether the game has techs to learn (the config has a research deck).
func research_on() -> bool:
	return not config.research_deck.is_empty()


## Why hand cards can't be picked up (dragged or double-clicked) now, or "" (175): the game is over, or a decision
## other than a hand-limit discard is owed.
func hand_input_error() -> String:
	return _as_engine()._blocked_error("discard")


## Cards that must still be discarded before the turn can end (0 when none is pending).
func discard_needed() -> int:
	return state.pending.get("count", 0) if state.pending.get("kind", "") == GameEngine.PENDING_DISCARD else 0


## Why the supply screen can't open now, or "". A discard owed doesn't block it: you can browse, and
## buy_error says why each card can't be bought.
func supply_error() -> String:
	return _as_engine()._blocked_error("supply")


## This engine as the GameEngine it is: the action guards (_blocked_error) and fork live there (249).
func _as_engine() -> GameEngine:
	return self
