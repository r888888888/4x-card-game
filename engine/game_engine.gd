class_name GameEngine
extends RefCounted
## Game rules and player actions. Uses no scene nodes: the UI (or a headless
## script) calls the action methods and listens to the signals.
##
## Turn loop: upkeep -> draw -> play (player) -> event -> cleanup.

signal changed
signal logged(message: String)
signal game_over(final_score: int)
## Emitted by play_card, before changed. outcome: {uid, to_zone, target, paid, gained, vp, drawn, created};
## target is the uid the card was played on (-1 if none), paid and gained map resource -> amount,
## drawn and created are card uids.
signal card_played(outcome: Dictionary)

## A tech passed over this many times is removed from the game.
const MAX_PASSES := 3

const ZONES: Array[String] = ["deck", "hand", "discard", "tableau", "territory_deck", "frontier", "reveal", "research_deck", "research_reveal", "researched", "lost_techs", "future_techs"]

var card_db: Dictionary  # id -> CardDef
var config: Dictionary  # normalized by DataLoader.parse_config
var seed_value := 0
var rng: SeededRng
var zones: Dictionary = {}  # name -> Zone
var resources: Dictionary = {}  # name -> int
var turn := 0
var bonus_score := 0  # VP from effects, on top of VP printed on tableau cards
var is_over := false
var log_lines: Array[String] = []
var play_target := -1  # target uid of the card being played; -1 outside play_card
var pending_choice: Dictionary = {}  # {options: Array[int], source: CardInstance}; empty = none
var _era := 1  # the highest era of techs added to the research deck
var _eras_added: Array[int] = []  # eras add_era has already shuffled in
var _discard_left := 0  # cards still to discard before the turn can end; 0 = none pending
var _supply: Dictionary = {}  # card_id -> copies left to buy, in config order
var _next_uid := 1
var _outcome: Dictionary = {}  # the card_played outcome being built; empty outside play_card
var _quiet := false  # true while upkeep_forecast runs upkeep on a snapshot: nothing is logged


func _init(p_card_db: Dictionary, p_config: Dictionary) -> void:
	card_db = p_card_db
	config = p_config


# --- Queries ---

func zone(zone_name: String) -> Zone:
	return zones[zone_name]


func turn_limit() -> int:
	return config.turn_limit


## Printed VP on the tableau, VP from effects, and vp_per_pop for each pop (when population is on).
func score() -> int:
	var total := bonus_score
	for card in zone("tableau").cards:
		total += card.def.vp
	for card in zone("researched").cards:
		total += card.def.vp
	if population_on():
		total += total_pop() * config.population.vp_per_pop
	return total


## Whether the population rules apply (the config has a population block).
func population_on() -> bool:
	return not config.get("population", {}).is_empty()


## Pop on settled territory territory_uid (0 for anything else).
func pop(territory_uid: int) -> int:
	var territory := _settled_territory(territory_uid)
	return territory.pop if territory != null else 0


## The most pop settled territory territory_uid can hold (0 if it isn't one).
func housing(territory_uid: int) -> int:
	var territory := _settled_territory(territory_uid)
	return territory.def.housing if territory != null else 0


## Keywords of territory uid in any zone: printed, then rolled resources ([] if it isn't a territory).
func territory_keywords(uid: int) -> Array[String]:
	for z in ZONES:
		var card := zone(z).find(uid)
		if card != null:
			return card.keywords.duplicate() if card.def.type == "territory" else [] as Array[String]
	return [] as Array[String]


## Food to grow settled territory territory_uid by 1 pop: its current pop + 1.
func grow_cost(territory_uid: int) -> int:
	return pop(territory_uid) + 1


## Why settled territory territory_uid can't grow right now, or "" if it can.
func grow_error(territory_uid: int) -> String:
	if is_over:
		return "The game is over."
	if not population_on():
		return "This game has no population."
	if not pending_choice.is_empty():
		return "Choose a territory first."
	if not research_options().is_empty():
		return _research_open_error()
	if _discard_left > 0:
		return _discard_error()
	var territory := _settled_territory(territory_uid)
	if territory == null:
		return "Only a settled territory can grow."
	if territory.pop >= territory.def.housing:
		return "%s is at its housing (%d)." % [territory.def.name, territory.def.housing]
	var cost := grow_cost(territory_uid)
	var have: int = resources.get("food", 0)
	if have < cost:
		return "Growing %s needs %d food (you have %d)." % [territory.def.name, cost, have]
	return ""


## Pays grow_cost food for +1 pop on settled territory territory_uid. False (and no change) if
## grow_error says it can't.
func grow(territory_uid: int) -> bool:
	if grow_error(territory_uid) != "":
		return false
	var territory := _settled_territory(territory_uid)
	var cost := grow_cost(territory_uid)
	resources.food -= cost
	territory.pop += 1
	_log("%s grew to %d pop (%d food)." % [territory.def.name, territory.pop, cost])
	changed.emit()
	return true


## Pop summed over every settled territory.
func total_pop() -> int:
	var total := 0
	for card in zone("tableau").cards:
		if card.def.type == "territory":
			total += card.pop
	return total


## The uids of the revealed techs waiting to be bought or declined, top first; [] when none is open.
func research_options() -> Array[int]:
	var out: Array[int] = []
	for card in zone("research_reveal").cards:
		out.append(card.uid)
	return out


## The highest era of techs added to the research deck so far (1 at the start).
func era() -> int:
	return _era


## How the next upkeep changes each resource on hand, food net of what pop eats (may be negative), plus
## "starve": the pop that food shortfall would starve. {} on the last turn or after game over.
## Runs the upkeep effects on a snapshot and restores it: nothing changes, is logged or emitted.
func upkeep_forecast() -> Dictionary:
	if is_over or turn >= turn_limit():
		return {}
	var saved_resources := resources.duplicate()
	var saved_bonus := bonus_score
	var saved_pop := {}
	for card in zone("tableau").cards:
		saved_pop[card] = card.pop
	_quiet = true
	_resolve_upkeep()
	_quiet = false
	var forecast := {}
	for r in saved_resources:
		forecast[r] = resources[r] - saved_resources[r]
	var need: int = total_pop() * config.population.food_upkeep if population_on() else 0
	forecast.food = forecast.get("food", 0) - need
	forecast.starve = maxi(need - resources.get("food", 0), 0)
	resources = saved_resources
	bonus_score = saved_bonus
	for card in saved_pop:
		card.pop = saved_pop[card]
	return forecast


## The pop and wealth thresholds that add an era at the start of a turn: {era: {pop?, wealth?}}.
func era_unlocks() -> Dictionary:
	return config.get("era_unlocks", {})


## Why reveal_techs has nothing to reveal, or "" if it has (the research deck or a future era).
func reveal_techs_error() -> String:
	if zone("research_deck").is_empty() and zone("future_techs").is_empty():
		return "The research deck is empty."
	return ""


## What tech uid costs in wealth right now: its printed cost, less 1 per pass and less its prereq
## discount when the prereq is researched, but never under 1 (0 if uid isn't a tech).
func tech_cost(uid: int) -> int:
	var tech := _find_tech(uid)
	if tech == null:
		return 0
	var cost: int = tech.def.cost.get("wealth", 0) - tech.passes
	if tech.def.prereq != "" and zone("researched").cards.any(func(c): return c.def.id == tech.def.prereq):
		cost -= tech.def.prereq_discount
	return maxi(cost, 1)


## Times another tech was bought over tech uid (0 if uid isn't a tech).
func tech_passes(uid: int) -> int:
	var tech := _find_tech(uid)
	return tech.passes if tech != null else 0


## Why revealed tech uid can't be bought right now, or "" if it can.
func buy_tech_error(uid: int) -> String:
	var tech := zone("research_reveal").find(uid)
	if tech == null:
		return "That tech isn't up for research."
	var cost := tech_cost(uid)
	var have: int = resources.get("wealth", 0)
	if have < cost:
		return "%s needs %d wealth (you have %d)." % [tech.def.name, cost, have]
	return ""


## The cards in the supply and how many copies of each are left: {card_id: count}, in config order.
func supply() -> Dictionary:
	return _supply.duplicate()


## Copies of card_id left in the supply (0 if it isn't sold there).
func supply_left(card_id: String) -> int:
	return _supply.get(card_id, 0)


## What a copy of card_id costs in wealth from the supply (0 if it isn't sold there).
func buy_price(card_id: String) -> int:
	return config.get("supply", {}).get(card_id, {}).get("price", 0)


## Why a copy of card_id can't be bought from the supply right now, or "" if it can.
func buy_error(card_id: String) -> String:
	var busy := _busy_error()
	if busy != "":
		return busy
	var card_name: String = card_db[card_id].name if card_db.has(card_id) else card_id
	if not _supply.has(card_id):
		return "%s isn't in the supply." % card_name
	if _supply[card_id] <= 0:
		return "No %ss left in the supply." % card_name
	var price := buy_price(card_id)
	var have: int = resources.get("wealth", 0)
	if have < price:
		return "%s costs %d wealth (you have %d)." % [card_name, price, have]
	return ""


func count_tag(tag: String, zone_name: String) -> int:
	return zone(zone_name).count_tag(tag)


## Why the card can't be played right now, or "" if it can.
func play_error(uid: int, target_uid := -1) -> String:
	var busy := _busy_error()
	if busy != "":
		return busy
	var card := zone("hand").find(uid)
	if card == null:
		return "That card is not in your hand."
	for r in card.def.cost:
		var need: int = card.def.cost[r]
		var have: int = resources.get(r, 0)
		if have < need:
			return "%s needs %d %s (you have %d)." % [card.def.name, need, r, have]
	for effect in card.def.effects:
		if effect.trigger == "play":
			var blocked := effect.play_block_error(self)
			if blocked != "":
				return blocked
	if not _needs_target(card):
		return ""
	var targets := valid_targets(uid)
	if target_uid != -1:
		if targets.has(target_uid):
			return ""
		var target := zone("tableau").find(target_uid)
		if _is_building(card) and target != null and target.def.type == "territory" and not _meets_requires(card, target):
			return _requires_error(card)
		return "That target isn't valid."
	if targets.is_empty():
		return _no_target_error(card)
	if targets.size() > 1:
		return _choose_target_error(card)
	return ""


## The uids hand card uid can be played on; [] if it needs no target. A building's targets are the
## settled territories with a free slot; a targeting effect's are the cards in its target zone.
func valid_targets(uid: int) -> Array[int]:
	var out: Array[int] = []
	var card := zone("hand").find(uid)
	if card == null or not _needs_target(card):
		return out
	if _is_building(card):
		for territory in zone("tableau").cards:
			if _has_room(territory) and _has_worker(territory) and _meets_requires(card, territory):
				out.append(territory.uid)
	else:
		for target in zone(_target_effect(card).target_zone()).cards:
			out.append(target.uid)
	return out


## Building slots on settled territory territory_uid: its own plus the `slots` of cities on it
## (0 if it isn't settled).
func total_slots(territory_uid: int) -> int:
	var territory := _settled_territory(territory_uid)
	if territory == null:
		return 0
	var total := territory.def.slots
	for card in zone("tableau").cards:
		if card.def.type == "city" and card.territory_uid == territory_uid:
			total += card.def.slots
	return total


## Building slots left on settled territory territory_uid (0 if it isn't settled). Cities don't use slots.
func free_slots(territory_uid: int) -> int:
	if _settled_territory(territory_uid) == null:
		return 0
	return total_slots(territory_uid) - _buildings_on(territory_uid).size()


## Pop on settled territory territory_uid not yet working a building (0 if none, or not a territory).
func free_workers(territory_uid: int) -> int:
	return maxi(pop(territory_uid) - _buildings_on(territory_uid).size(), 0)


## Whether building uid is idle: with population on, a territory's buildings beyond its pop are idle,
## the ones placed last first. Idle buildings skip upkeep but keep their printed VP.
func is_idle(uid: int) -> bool:
	var card := zone("tableau").find(uid)
	if card == null or not _is_building(card) or not population_on():
		return false
	return _buildings_on(card.territory_uid).find(card) >= pop(card.territory_uid)


func needs_target(uid: int) -> bool:
	var card := zone("hand").find(uid)
	return card != null and _needs_target(card)


## The settled territory card sits on, or null.
func territory_of(card: CardInstance) -> CardInstance:
	if card.territory_uid < 0:
		return null
	return zone("tableau").find(card.territory_uid)


# --- Actions ---

func new_game(p_seed: int) -> void:
	seed_value = p_seed
	rng = SeededRng.new(p_seed)
	zones = {}
	for z in ZONES:
		zones[z] = Zone.new(z)
	resources = {}
	for r in config.resources:
		resources[r] = 0
	for r in config.starting.resources:
		resources[r] = config.starting.resources[r]
	turn = 0
	bonus_score = 0
	is_over = false
	pending_choice = {}
	_discard_left = 0
	_era = 1
	_eras_added = []
	_supply = {}
	for id in config.get("supply", {}):
		_supply[id] = config.supply[id].count
	_next_uid = 1
	log_lines.clear()

	var deck := zone("deck")
	for id in config.deck:
		for i in config.deck[id]:
			deck.add(_make_card(id))
	rng.shuffle(deck.cards)
	var territory_deck := zone("territory_deck")
	for id in config.territory_deck:
		for i in config.territory_deck[id]:
			territory_deck.add(_make_territory(id))
	rng.shuffle(territory_deck.cards)
	var research_deck := zone("research_deck")
	for id in config.research_deck:
		for i in config.research_deck[id]:
			var tech := _make_card(id)
			zone("research_deck" if tech.def.era == 1 else "future_techs").add(tech)
	if not research_deck.is_empty():
		rng.shuffle(research_deck.cards)
	var home: CardInstance = null
	if config.starting.territory != "":
		home = _make_territory(config.starting.territory)
		if population_on():
			home.pop = config.population.start
		zone("tableau").add(home)
	for id in config.starting.tableau:
		var card := _make_card(id)
		if home != null:
			card.territory_uid = home.uid
		zone("tableau").add(card)

	_log("New game — seed %d, %d cards in deck." % [p_seed, deck.size()])
	_start_turn()
	changed.emit()


## Pays the cost, moves the card (permanents to the tableau), resolves its "play" effects on
## target_uid, then emits card_played with what happened. A card that needs a target and has only
## one valid target uses it when target_uid is -1; a card that needs none ignores target_uid.
func play_card(uid: int, target_uid := -1) -> bool:
	if play_error(uid, target_uid) != "":
		return false
	var target := -1
	if needs_target(uid):
		target = target_uid if target_uid != -1 else valid_targets(uid)[0]
	var hand := zone("hand")
	var card := hand.find(uid)
	hand.remove(card)
	var permanent := card.def.is_permanent()
	_outcome = _new_outcome(uid, "tableau" if permanent else "discard", target)
	play_target = target
	for r in card.def.cost:
		resources[r] -= card.def.cost[r]
		if card.def.cost[r] > 0:
			_outcome.paid[r] = card.def.cost[r]
	_log("Played %s." % card.def.name)
	if permanent:
		if _is_building(card):
			card.territory_uid = target
		zone("tableau").add(card)
	_resolve(card, "play")
	if not permanent:
		zone("discard").add(card)
	var outcome := _outcome
	_outcome = {}
	play_target = -1
	card_played.emit(outcome)
	changed.emit()
	return true


## Resolves the pending choice: keeps territory uid in the frontier and puts the other revealed
## territories at the bottom of the territory deck. False (and no change) if uid isn't an option.
func choose(uid: int) -> bool:
	if pending_choice.is_empty() or not pending_choice.options.has(uid):
		return false
	var reveal := zone("reveal")
	var kept := reveal.find(uid)
	reveal.remove(kept)
	zone("frontier").add(kept)
	for card in reveal.take_all():
		zone("territory_deck").add_bottom(card)
	_log("  %s: kept %s." % [pending_choice.source.def.name, kept.def.name])
	pending_choice = {}
	changed.emit()
	return true


## Reveals the top 2 techs (or the last one) of the research deck, adding the lowest future era first
## when it is empty. The player then calls buy_tech or decline_research. Does nothing if
## reveal_techs_error says there is nothing to reveal. source is the card that researched.
func reveal_techs(_source: CardInstance) -> void:
	if reveal_techs_error() != "":
		return
	var deck := zone("research_deck")
	if deck.is_empty():
		add_era(_lowest_future_era())
	for i in 2:
		if deck.is_empty():
			break
		zone("research_reveal").add(deck.take_top())
	_log("  Researching: %s." % ", ".join(PackedStringArray(zone("research_reveal").cards.map(func(c): return c.def.name))))


## Pays for revealed tech uid, moves it to the researched row and resolves its play effects. The other
## revealed tech goes back into the research deck. False (and no change) if buy_tech_error says no.
func buy_tech(uid: int) -> bool:
	if buy_tech_error(uid) != "":
		return false
	var tech := zone("research_reveal").find(uid)
	var cost := tech_cost(uid)
	zone("research_reveal").remove(tech)
	resources.wealth -= cost
	zone("researched").add(tech)
	_log("Researched %s (%d wealth)." % [tech.def.name, cost])
	_resolve(tech, "play")
	_return_revealed_techs(true)
	changed.emit()
	return true


## Pays buy_price wealth for a new copy of card_id from the supply and puts it on the discard.
## False (and no change) if buy_error says it can't.
func buy(card_id: String) -> bool:
	if buy_error(card_id) != "":
		return false
	var price := buy_price(card_id)
	resources.wealth -= price
	_supply[card_id] -= 1
	var card := _make_card(card_id)
	zone("discard").add(card)
	_log("Bought %s (%d wealth)." % [card.def.name, price])
	changed.emit()
	return true


## Puts the revealed techs back into the research deck without buying. The action stays spent.
## False (and no change) if nothing is revealed.
func decline_research() -> bool:
	if zone("research_reveal").is_empty():
		return false
	_log("Declined to research.")
	_return_revealed_techs(false)
	changed.emit()
	return true


## Cards that must still be discarded before the turn can end (0 when none is pending).
func discard_needed() -> int:
	return _discard_left


## Discards one card from the hand for free, any time in the turn. If an end-of-turn discard is
## pending this counts toward it, and the turn ends once the hand is down to the limit. False (and no
## change) if the game is over, a choice is pending, or the card isn't in hand.
func discard_card(uid: int) -> bool:
	if is_over or not pending_choice.is_empty() or not research_options().is_empty():
		return false
	var card := zone("hand").find(uid)
	if card == null:
		return false
	zone("hand").remove(card)
	zone("discard").add(card)
	_log("Discarded %s." % card.def.name)
	if _discard_left > 0:
		_discard_left -= 1
		if _discard_left == 0:
			_finish_turn()
	changed.emit()
	return true


## Ends the turn. Over the hand limit, waits for discard_card calls instead (not on the last turn).
func end_turn() -> void:
	if is_over or not pending_choice.is_empty() or not research_options().is_empty() or _discard_left > 0:
		return
	_event_phase()
	if turn < turn_limit():
		var over: int = zone("hand").size() - config.hand_limit
		if over > 0:
			_discard_left = over
			_log("Hand limit is %d: discard %d." % [config.hand_limit, over])
			changed.emit()
			return
	_finish_turn()


# --- Helpers called by effects ---

func gain(resource: String, amount: int, source: CardInstance) -> void:
	resources[resource] = resources.get(resource, 0) + amount
	if not _outcome.is_empty():
		_outcome.gained[resource] = _outcome.gained.get(resource, 0) + amount
	_log("  %s: +%d %s" % [source.def.name, amount, resource])


## Draws up to n cards, reshuffling the discard pile into the deck when it runs out.
func draw(n: int) -> int:
	var deck := zone("deck")
	var drawn := 0
	for i in n:
		if deck.is_empty():
			var discard := zone("discard")
			if discard.is_empty():
				break
			for card in discard.take_all():
				deck.add(card)
			rng.shuffle(deck.cards)
			_log("  Reshuffled discard pile into deck (%d cards)." % deck.size())
		var card := deck.take_top()
		zone("hand").add(card)
		if not _outcome.is_empty():
			_outcome.drawn.append(card.uid)
		drawn += 1
	return drawn


func create_card(card_id: String, zone_name: String, source: CardInstance) -> CardInstance:
	var card := _make_card(card_id)
	zone(zone_name).add(card)
	if not _outcome.is_empty():
		_outcome.created.append(card.uid)
	_log("  %s: created %s." % [source.def.name, card.def.name])
	return card


## Reveals up to n territories. Several start a choice (see choose); a single one goes
## straight to the frontier.
func explore(n: int, source: CardInstance) -> void:
	var territory_deck := zone("territory_deck")
	var reveal := zone("reveal")
	for i in n:
		if territory_deck.is_empty():
			break
		reveal.add(territory_deck.take_top())
	if reveal.is_empty():
		_log("  %s: no territories left to explore." % source.def.name)
	elif reveal.size() == 1:
		var card := reveal.take_top()
		zone("frontier").add(card)
		_log("  %s: discovered %s." % [source.def.name, card.def.name])
	else:
		var options: Array[int] = []
		for card in reveal.cards:
			options.append(card.uid)
		options.reverse()  # top first
		pending_choice = {"options": options, "source": source}
		_log("  %s: choose a territory to keep." % source.def.name)


## Moves frontier territory territory_uid to the tableau and founds a new city_id on it. With population
## on, the territory starts with 1 pop.
func settle(territory_uid: int, city_id: String, source: CardInstance) -> void:
	var territory := zone("frontier").find(territory_uid)
	zone("frontier").remove(territory)
	zone("tableau").add(territory)
	if population_on():
		territory.pop = 1
	var city := create_card(city_id, "tableau", source)
	city.territory_uid = territory.uid
	_log("  %s: settled %s." % [source.def.name, territory.def.name])


## Adds up to amount pop to settled territory territory_uid, stopping at its housing. Does nothing if
## population is off or territory_uid isn't a settled territory.
func add_pop(territory_uid: int, amount: int, source: CardInstance) -> void:
	var territory := _settled_territory(territory_uid)
	if territory == null or not population_on():
		return
	var added := mini(amount, territory.def.housing - territory.pop)
	if added <= 0:
		return
	territory.pop += added
	_log("  %s: +%d pop on %s" % [source.def.name, added, territory.def.name])


## Shuffles the era-n techs waiting in future_techs into the research deck. Does nothing if era n was
## already added. source is the card that added it (null when the empty research deck did).
func add_era(n: int, source: CardInstance = null) -> void:
	if _eras_added.has(n):
		return
	_eras_added.append(n)
	_era = maxi(_era, n)
	var deck := zone("research_deck")
	for tech in zone("future_techs").cards.filter(func(c): return c.def.era == n):
		zone("future_techs").remove(tech)
		deck.add(tech)
	rng.shuffle(deck.cards)
	_log("  %sEra %d techs added to the research deck." % [source.def.name + ": " if source != null else "", n])


func add_score(amount: int, source: CardInstance) -> void:
	bonus_score += amount
	if not _outcome.is_empty():
		_outcome.vp += amount
	_log("  %s: +%d VP" % [source.def.name, amount])


# --- Internals ---

func _finish_turn() -> void:
	if turn >= turn_limit():
		is_over = true
		var discard := zone("discard")
		for card in zone("hand").take_all():
			discard.add(card)
		var final_score := score()
		_log("Game over after %d turns. Final score: %d." % [turn, final_score])
		changed.emit()
		game_over.emit(final_score)
		return
	_start_turn()
	changed.emit()


## The lowest era among the techs waiting in future_techs.
func _lowest_future_era() -> int:
	var lowest: int = zone("future_techs").cards[0].def.era
	for tech in zone("future_techs").cards:
		lowest = mini(lowest, tech.def.era)
	return lowest


## Why no action can be taken right now (game over, an explore choice, open research, a discard owed),
## or "" if actions are allowed.
func _busy_error() -> String:
	if is_over:
		return "The game is over."
	if not pending_choice.is_empty():
		return "Choose a territory first."
	if not research_options().is_empty():
		return _research_open_error()
	if _discard_left > 0:
		return _discard_error()
	return ""


func _research_open_error() -> String:
	return "Buy a tech or decline first."


## The tech uid in the research deck, the revealed techs or the researched row, or null.
func _find_tech(uid: int) -> CardInstance:
	for name in ["research_reveal", "research_deck", "researched", "lost_techs"]:
		var tech := zone(name).find(uid)
		if tech != null:
			return tech
	return null


## Shuffles every revealed tech back into the research deck. With passed, each was passed over by a
## purchase: it gets a pass, and a third pass loses it for good.
func _return_revealed_techs(passed: bool) -> void:
	var deck := zone("research_deck")
	for card in zone("research_reveal").take_all():
		if passed:
			card.passes += 1
		if card.def.adds_era():
			card.passes = mini(card.passes, MAX_PASSES - 1)
		if card.passes >= MAX_PASSES:
			zone("lost_techs").add(card)
			_log("  %s was passed over too often and is lost." % card.def.name)
		else:
			deck.add(card)
	rng.shuffle(deck.cards)


func _discard_error() -> String:
	return "Discard down to %d cards first." % config.hand_limit


func _start_turn() -> void:
	turn += 1
	_log("— Turn %d —" % turn)
	_resolve_upkeep()
	if population_on():
		_feed_pop()
	_check_era_unlocks()
	draw(maxi(0, config.hand_size - zone("hand").size()))


## Resolves "upkeep" on every working card: tableau cards that aren't idle, and researched techs.
func _resolve_upkeep() -> void:
	var working := zone("tableau").cards.filter(func(c): return not is_idle(c.uid)) + zone("researched").cards
	for card in working:
		_resolve(card, "upkeep")


## Adds each era whose pop or wealth threshold is met (add_era ignores an era added before).
func _check_era_unlocks() -> void:
	var eras := era_unlocks().keys()
	eras.sort()
	for n in eras:
		var need: Dictionary = era_unlocks()[n]
		if total_pop() >= need.get("pop", INF) or resources.get("wealth", 0) >= need.get("wealth", INF):
			add_era(n)


## Pop eats food_upkeep food each. Each food that can't be paid starves 1 pop from the territory with
## the most pop (ties: the one settled first).
func _feed_pop() -> void:
	var need: int = total_pop() * config.population.food_upkeep
	if need == 0:
		return
	var eaten: int = mini(need, resources.food)
	resources.food -= eaten
	_log("Pop eats %d food." % eaten)
	for i in need - eaten:
		var biggest: CardInstance = null
		for card in zone("tableau").cards:
			if card.def.type == "territory" and card.pop > 0 and (biggest == null or card.pop > biggest.pop):
				biggest = card
		if biggest == null:
			break
		biggest.pop -= 1
		_log("%s: 1 pop starved." % biggest.def.name)


func _event_phase() -> void:
	pass  # Threat design deferred: the event/barbarian deck will resolve here.


## Applies card's effects for trigger. A keyword effect applies only if the card's territory has it.
func _resolve(card: CardInstance, trigger: String) -> void:
	var territory := territory_of(card)
	for e in card.def.effects_for(trigger):
		if e.keyword == "" or (territory != null and territory.keywords.has(e.keyword)):
			e.apply(self, card)


func _new_outcome(uid: int, to_zone: String, target: int) -> Dictionary:
	var drawn: Array[int] = []
	var created: Array[int] = []
	return {"uid": uid, "to_zone": to_zone, "target": target, "paid": {}, "gained": {}, "vp": 0, "drawn": drawn, "created": created}


func _is_building(card: CardInstance) -> bool:
	return card.def.type == "building"


## Buildings target a territory; other cards need a target if a "play" effect does.
func _needs_target(card: CardInstance) -> bool:
	return _is_building(card) or _target_effect(card) != null


func _no_target_error(card: CardInstance) -> String:
	if _is_building(card):
		var slot_found := false
		for territory in zone("tableau").cards:
			if territory.def.type == "territory" and _meets_requires(card, territory):
				if _has_room(territory):
					return "No territory with a free worker."
				slot_found = true
		return "No territory with a free slot." if slot_found else _requires_error(card)
	return _target_effect(card).no_target_error()


## Whether card is a territory with a free building slot.
func _has_room(territory: CardInstance) -> bool:
	return territory.def.type == "territory" and free_slots(territory.uid) > 0


## Whether territory has a free worker for another building (always, with population off).
func _has_worker(territory: CardInstance) -> bool:
	return not population_on() or free_workers(territory.uid) > 0


## The buildings on territory territory_uid, in the order they were placed.
func _buildings_on(territory_uid: int) -> Array[CardInstance]:
	var out: Array[CardInstance] = []
	for card in zone("tableau").cards:
		if _is_building(card) and card.territory_uid == territory_uid:
			out.append(card)
	return out


## Whether territory has one of the keywords building card requires (or it requires none).
func _meets_requires(card: CardInstance, territory: CardInstance) -> bool:
	if card.def.requires.is_empty():
		return true
	for k in card.def.requires:
		if territory.keywords.has(k):
			return true
	return false


func _requires_error(card: CardInstance) -> String:
	return "%s needs a territory with %s." % [card.def.name, CardDef.keyword_names(card.def.requires)]


func _choose_target_error(card: CardInstance) -> String:
	if _is_building(card):
		return "Choose a territory for %s." % card.def.name
	return _target_effect(card).choose_target_error()


## The card's first "play" effect that needs a target, or null.
func _target_effect(card: CardInstance) -> Effect:
	for e in card.def.effects_for("play"):
		if e.target_zone() != "":
			return e
	return null


## The territory card territory_uid if it is settled (on the tableau), or null.
func _settled_territory(territory_uid: int) -> CardInstance:
	var territory := zone("tableau").find(territory_uid)
	if territory == null or territory.def.type != "territory":
		return null
	return territory


## A new territory card_id with resource keywords rolled from its territory_resources table, if any.
func _make_territory(card_id: String) -> CardInstance:
	var card := _make_card(card_id)
	var table: Array = config.get("territory_resources", {}).get(card_id, [])
	if table.is_empty():
		return card
	var total := 0
	for option in table:
		total += option.weight
	var roll := rng.randi_range(1, total)
	for option in table:
		roll -= option.weight
		if roll <= 0:
			card.keywords.append_array(option.keywords)
			break
	return card


func _make_card(card_id: String) -> CardInstance:
	var card := CardInstance.new(_next_uid, card_db[card_id])
	_next_uid += 1
	return card


func _log(message: String) -> void:
	if _quiet:
		return
	log_lines.append(message)
	logged.emit(message)
