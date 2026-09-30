class_name GameEngine
extends RefCounted
## Game rules and player actions. Uses no scene nodes: the UI (or a headless
## script) calls the action methods and listens to the signals.
##
## Turn loop: upkeep -> draw -> play (player) -> event -> cleanup.
##
## The state lives in a GameState (state); the public vars below read and write it. The rules live in modules
## of static functions that the methods here call: TurnLoop, CardPlay, Population, Research, Supply and
## Territories, and Events. The modules may call the engine's _ helpers (_log, _resolve, _make_card, _blocked_error).

## The two built-in resources: food pays for people (growth, upkeep, Settlers), wealth for premium buildings,
## techs and the supply. The config may list more resources; only these two have rules attached.
const FOOD := "food"
const WEALTH := "wealth"

signal changed
signal logged(message: String)
signal game_over(final_score: int)
## Emitted by play_card, before changed. outcome: {uid, to_zone, target, paid, gained, vp, drawn, created};
## target is the uid the card was played on (-1 if none), paid and gained map resource -> amount,
## drawn and created are card uids.
signal card_played(outcome: Dictionary)

## A tech passed over this many times is removed from the game.
const MAX_PASSES := 3

const ZONES: Array[String] = ["deck", "hand", "discard", "tableau", "territory_deck", "frontier", "reveal", "research_deck", "research_reveal", "researched", "lost_techs", "future_techs", "event_deck", "active_events", "event_discard", "civilization", "government", "removed", "trashed"]
## Zones of always-on permanents outside the tableau: every card there resolves upkeep and scores its printed VP.
const ALWAYS_ON_ZONES: Array[String] = ["researched", "civilization", "government"]
## The zones a create effect may put a new card into.
const CREATE_ZONES: Array[String] = ["tableau", "hand", "discard", "deck"]
## The kinds of decision pending() can report.
const PENDING_EXPLORE := "explore"
const PENDING_RESEARCH := "research"
const PENDING_DISCARD := "discard"
## A tech's state in tech_tree(): bought, still to be revealed (or revealed now), in an era not added yet, or
## removed after its third pass.
const TECH_RESEARCHED := "researched"
const TECH_AVAILABLE := "available"
const TECH_FUTURE := "future"
const TECH_LOST := "lost"
## The actions still allowed while a discard is owed (see _blocked_error).
const _DISCARD_ALLOWS: Array[String] = ["discard", "supply"]

var card_db: Dictionary  # id -> CardDef
var config: Dictionary  # normalized by DataLoader.parse_config
var state := GameState.new()
var play_target := -1  # target uid of the card being played; -1 outside play_card
var _outcome: Dictionary = {}  # the card_played outcome being built; empty outside play_card

var seed_value: int:
	get: return state.seed_value
	set(v): state.seed_value = v
var rng: SeededRng:
	get: return state.rng
	set(v): state.rng = v
var zones: Dictionary:  # name -> Zone
	get: return state.zones
	set(v): state.zones = v
var resources: Dictionary:  # name -> int
	get: return state.resources
	set(v): state.resources = v
var turn: int:
	get: return state.turn
	set(v): state.turn = v
var bonus_score: int:  # VP from effects, on top of VP printed on tableau cards
	get: return state.bonus_score
	set(v): state.bonus_score = v
var is_over: bool:
	get: return state.is_over
	set(v): state.is_over = v
var log_lines: Array[String]:
	get: return state.log_lines
	set(v): state.log_lines = v
var pending_choice: Dictionary:  # {options: Array[int], source: CardInstance}; empty = none
	get: return state.pending_choice
	set(v): state.pending_choice = v


func _init(p_card_db: Dictionary, p_config: Dictionary) -> void:
	card_db = p_card_db
	config = p_config


## A new engine on a deep copy of this one's state (GameState.copy). Nothing is connected to its signals and
## it logs to its own copy of the log, so playing on it never touches this game.
func fork() -> GameEngine:
	var f := GameEngine.new(card_db, config)
	f.state = state.copy()
	return f


# --- Queries ---

func zone(zone_name: String) -> Zone:
	return zones[zone_name]


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
## {kind: PENDING_EXPLORE, options: territory uids top first, source: uid of the card that explored},
## {kind: PENDING_RESEARCH, options: revealed tech uids} or
## {kind: PENDING_DISCARD, count: cards still to discard, options: hand uids}.
func pending() -> Dictionary:
	if not pending_choice.is_empty():
		return {"kind": PENDING_EXPLORE, "options": pending_choice.options, "source": pending_choice.source.uid}
	if not zone("research_reveal").is_empty():
		return {"kind": PENDING_RESEARCH, "options": research_options()}
	if state.discard_left > 0:
		return {"kind": PENDING_DISCARD, "count": state.discard_left, "options": zone("hand").cards.map(func(c): return c.uid)}
	return {}


## The uids of the revealed techs waiting to be bought or declined, top first; [] when none is open.
func research_options() -> Array[int]:
	return Research.options(self)


## The name of the card that reveals techs, for hints: the first with a research effect in config deck order, then
## supply order; "" when there is none.
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


## Every tech in config research_deck, by era then config order: [{id, era, prereq, state (TECH_*), cost (wealth
## now; printed for a future tech), passes, gives (card ids it creates or unlocks)}].
func tech_tree() -> Array[Dictionary]:
	return Research.tree(self)


## Era n's name from config era_names ("Stone Age"), or "Era n".
func era_name(n: int) -> String:
	return config.get("era_names", {}).get(n, "Era %d" % n)


## Why reveal_techs has nothing to reveal, or "" if it has (the research deck or a future era).
func reveal_techs_error() -> String:
	return Research.reveal_error(self)


## What tech uid costs in wealth right now: its printed cost, less 1 per pass and less its prereq
## discount when the prereq is researched, but never under 1 (0 if uid isn't a tech).
func tech_cost(uid: int) -> int:
	return Research.cost(self, uid)


## Times another tech was bought over tech uid (0 if uid isn't a tech).
func tech_passes(uid: int) -> int:
	return Research.passes(self, uid)


## Why revealed tech uid can't be bought right now, or "" if it can.
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


## What is built on settled territory uid, for a collapsed group's summary: {cities, buildings, idle}, or {} when
## uid isn't a territory in the tableau.
func territory_summary(uid: int) -> Dictionary:
	return Territories.summary(self, uid)


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


## Reveals the top 2 techs (or the last one) of the research deck, adding the lowest future era first
## when it is empty. The player then calls buy_tech or decline_research. Does nothing if
## reveal_techs_error says there is nothing to reveal. source is the card that researched.
func reveal_techs(_source: CardInstance) -> void:
	Research.reveal(self)


## Pays for revealed tech uid, moves it to the researched row and resolves its play effects. The other
## revealed tech goes back into the research deck. False (and no change) if buy_tech_error says no.
func buy_tech(uid: int) -> bool:
	return Research.buy(self, uid)


## Pays buy_price wealth for a new copy of card_id from the supply and puts it on the discard.
## False (and no change) if buy_error says it can't.
func buy(card_id: String) -> bool:
	return Supply.buy(self, card_id)


## Why decline_research would refuse (no techs are revealed), or "".
func decline_research_error() -> String:
	return Research.decline_error(self)


## Puts the revealed techs back into the research deck without buying. The action stays spent.
## False (and no change) if decline_research_error says no.
func decline_research() -> bool:
	return Research.decline(self)


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


# --- Helpers called by effects ---

func gain(resource: String, amount: int, source: CardInstance) -> void:
	resources[resource] = resources.get(resource, 0) + amount
	if not _outcome.is_empty():
		_outcome.gained[resource] = _outcome.gained.get(resource, 0) + amount
	_log("  %s: +%d %s" % [source.def.name, amount, resource])


## Takes up to amount of resource (never below 0). source is the card whose effect takes it.
func lose(resource: String, amount: int, source: CardInstance) -> void:
	var lost: int = mini(amount, resources.get(resource, 0))
	resources[resource] = resources.get(resource, 0) - lost
	_log("  %s: −%d %s" % [source.def.name, lost, resource])


## Takes up to amount pop, one at a time, from the territory with the most pop (see Population.lose_pop).
func lose_pop(amount: int, source: CardInstance) -> void:
	Population.lose_pop(self, amount, source)


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


## Adds a new copy of card_id to zone_name. source is the card whose effect made it, or null
## (the log then names no source).
func create_card(card_id: String, zone_name: String, source: CardInstance) -> CardInstance:
	var card := _make_card(card_id)
	zone(zone_name).add(card)
	if not _outcome.is_empty():
		_outcome.created.append(card.uid)
	if source == null:
		_log("  Created %s." % card.def.name)
	else:
		_log("  %s: created %s." % [source.def.name, card.def.name])
	return card


## Reveals up to n territories. Several start a choice (see choose); a single one goes
## straight to the frontier.
func explore(n: int, source: CardInstance) -> void:
	Territories.explore(self, n, source)


## Moves frontier territory territory_uid to the tableau and founds a new city_id on it. With population
## on, the territory starts with 1 pop.
func settle(territory_uid: int, city_id: String, source: CardInstance) -> void:
	Territories.settle(self, territory_uid, city_id, source)


## Moves hand card uid to the trashed zone, out of the game for good.
func trash(uid: int, source: CardInstance) -> void:
	var card := zone("hand").find(uid)
	zone("hand").remove(card)
	zone("trashed").add(card)
	if not _outcome.is_empty():
		_outcome.trashed = uid
	_log("  %s: removed %s from the game." % [source.def.name, card.def.name])


## Opens card_id's supply pile for buying; nothing happens if it is already open. source is the card whose effect
## opened it, or null (the log then names no source).
func unlock_supply(card_id: String, source: CardInstance) -> void:
	if state.locked_supply.erase(card_id):
		var prefix := "  %s: " % source.def.name if source != null else "  "
		_log("%s%s can now be bought." % [prefix, card_db[card_id].name])


## Adds up to amount pop to settled territory territory_uid, stopping at its housing. Does nothing if
## population is off or territory_uid isn't a settled territory.
func add_pop(territory_uid: int, amount: int, source: CardInstance) -> void:
	Population.add_pop(self, territory_uid, amount, source)


## Shuffles the era-n techs waiting in future_techs into the research deck. Does nothing if era n was
## already added. source is the card that added it (null when the empty research deck did).
func add_era(n: int, source: CardInstance = null) -> void:
	Research.add_era(self, n, source)


func add_score(amount: int, source: CardInstance) -> void:
	bonus_score += amount
	if not _outcome.is_empty():
		_outcome.vp += amount
	_log("  %s: +%d VP" % [source.def.name, amount])


# --- Internals (the modules call these too) ---

## Why action ("play", "grow", "buy", "end_turn", "supply", "discard") is blocked by the game being over
## or by a pending() decision, or "". Only discarding and browsing the supply go on while a discard is owed.
func _blocked_error(action: String) -> String:
	if is_over:
		return "The game is over."
	match pending().get("kind", ""):
		PENDING_EXPLORE:
			return "Choose a territory first."
		PENDING_RESEARCH:
			return "Buy a tech or decline first."
		PENDING_DISCARD:
			return "" if _DISCARD_ALLOWS.has(action) else "Discard down to %d cards first." % config.hand_limit
	return ""


## Applies card's effects for trigger. A keyword effect applies only if the card's territory has it.
func _resolve(card: CardInstance, trigger: String) -> void:
	var territory := territory_of(card)
	for e in card.def.effects_for(trigger):
		if e.keyword == "" or (territory != null and territory.keywords.has(e.keyword)):
			e.apply(self, card)


func _make_card(card_id: String) -> CardInstance:
	var card := CardInstance.new(state.next_uid, card_db[card_id])
	state.next_uid += 1
	return card


func _log(message: String) -> void:
	log_lines.append(message)
	logged.emit(message)
