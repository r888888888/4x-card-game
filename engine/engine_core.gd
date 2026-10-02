class_name EngineCore
extends RefCounted
## The state the rules modules share and the helpers effects call back into: the signals, the GameState and its
## accessors, the effect hooks (gain, lose, draw, create_card, …) and the logging internals. GameEngine extends it
## with the player-facing actions, their *_error queries and the read queries.

## The built-in resources: food pays for people (growth, upkeep, Settlers), wealth for premium buildings and the
## supply, insight for techs (139); unrest (144) is only gained and lost, never paid, and gain caps it at
## GameEngine.unrest_limit(). The config may list more resources; only these have rules attached.
const FOOD := "food"
const WEALTH := "wealth"
const INSIGHT := "insight"
const UNREST := "unrest"

signal changed
signal logged(message: String)
## Emitted after logged for a notable line the player should see even with the log closed (116): a famine arriving,
## ending, saving pop or relieved, a tech lost, a pile unlocked, an era's techs or events added, an event ending.
signal noticed(message: String)
signal game_over(final_score: int)
## Emitted by play_card, before changed. outcome: {uid, to_zone, target, paid, gained, lost, vp, drawn, created};
## target is the uid the card was played on (-1 if none), paid and gained map resource -> amount,
## drawn and created are card uids.
signal card_played(outcome: Dictionary)
## Emitted when the event phase draws an event, after its play effects, before changed (079). outcome: {uid, id,
## gained, lost, vp, drawn, created}, as card_played's plus the event's card id; lost maps resource -> what a lose
## effect actually took.
signal event_drawn(outcome: Dictionary)
## Emitted when revolt() declares a revolution (155), before changed; the sim counts them (158).
signal revolted
## Emitted when restore_order() buys order (155), before changed; the sim counts them (158).
signal order_restored

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


func _init(p_card_db: Dictionary, p_config: Dictionary) -> void:
	card_db = p_card_db
	config = p_config


# --- Queries ---

func zone(zone_name: String) -> Zone:
	return zones[zone_name]


## Whether the resources on hand cover cost ({resource: amount}) (173).
func can_pay(cost: Dictionary) -> bool:
	for r in cost:
		if resources.get(r, 0) < cost[r]:
			return false
	return true


## Takes cost ({resource: amount}) from the resources on hand (173): every price an action pays, and the food pop eats.
## Callers check can_pay first.
func pay(cost: Dictionary) -> void:
	for r in cost:
		resources[r] = resources.get(r, 0) - cost[r]


## "" when cost can be paid, else "<what> needs <cost> (you have <what you have of each>)." (173): "Restoring order
## needs 2 food, 6 wealth (you have 0 food, 1 wealth).", or "… needs 6 wealth (you have 1)." for one resource.
func price_error(what: String, cost: Dictionary) -> String:
	if can_pay(cost):
		return ""
	var have := {}
	for r in cost:
		have[r] = resources.get(r, 0)
	var have_text: String = str(have.values()[0]) if cost.size() == 1 else Fields.amounts_text(have)
	return "%s needs %s (you have %s)." % [what, Fields.amounts_text(cost), have_text]


## Sets unrest to n, never below 0, and returns the change (173): the one way unrest is added or capped. Raising it
## stops at unrest_limit(), and never lifts it when it is already past the limit (a lowered limit); lowering it is free.
func set_unrest(n: int) -> int:
	var have: int = resources.get(UNREST, 0)
	var limit := Modifiers.unrest_limit(self)
	if limit >= 0 and n > limit:
		n = maxi(limit, mini(n, have))
	n = maxi(n, 0)
	resources[UNREST] = n
	if n < have:
		_unrest_lowered()
	return n - have


# --- Helpers called by effects ---

## Adds amount of resource; unrest stops at the unrest limit (144, set_unrest). The outcome and the log report what
## was added.
func gain(resource: String, amount: int, source: CardInstance) -> void:
	if resource == UNREST:
		amount = set_unrest(resources.get(UNREST, 0) + amount)
	else:
		resources[resource] = resources.get(resource, 0) + amount
	if not _outcome.is_empty():
		_outcome.gained[resource] = _outcome.gained.get(resource, 0) + amount
	_log("  %s: +%d %s" % [source.def.name, amount, resource])


## Takes up to amount of resource (never below 0). source is the card whose effect takes it.
func lose(resource: String, amount: int, source: CardInstance) -> void:
	var lost: int = mini(amount, resources.get(resource, 0))
	resources[resource] = resources.get(resource, 0) - lost
	if resource == UNREST and lost > 0:
		_unrest_lowered()
	if not _outcome.is_empty() and lost > 0:
		_outcome.lost[resource] = _outcome.lost.get(resource, 0) + lost
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
## (the log then names no source). A government goes to the government deck instead, unless one with its id is
## already there or rules: then nothing is created and it returns null (154).
func create_card(card_id: String, zone_name: String, source: CardInstance) -> CardInstance:
	if card_db[card_id].type == CardDef.GOVERNMENT:
		var known := zone("governments").cards + zone("government").cards
		if known.any(func(c): return c.def.id == card_id):
			return null
		zone_name = "governments"
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
		_notice("%s%s can now be bought." % [prefix, card_db[card_id].name])


## Adds up to amount pop to settled territory territory_uid, stopping at its housing. Does nothing if
## population is off or territory_uid isn't a settled territory.
func add_pop(territory_uid: int, amount: int, source: CardInstance) -> void:
	Population.add_pop(self, territory_uid, amount, source)


## Shuffles the era-n techs waiting in future_techs into the research deck. Does nothing if era n was
## already added. source is the card that added it (null when the empty research deck did).
func add_era(n: int, source: CardInstance = null) -> void:
	Research.add_era(self, n, source)


## Gives amount more actions this turn (128). Does nothing while actions are unlimited.
func gain_actions(amount: int, source: CardInstance) -> void:
	if CardPlay.actions_per_turn(self) < 0:
		return
	state.actions_gained += amount
	_log("  %s: +%d action%s" % [source.def.name, amount, "" if amount == 1 else "s"])


func add_score(amount: int, source: CardInstance) -> void:
	bonus_score += amount
	if not _outcome.is_empty():
		_outcome.vp += amount
	_log("  %s: +%d VP" % [source.def.name, amount])


# --- Internals (the modules call these too) ---

## Applies card's effects for trigger. A keyword effect applies only if the card's territory has it.
func _resolve(card: CardInstance, trigger: String) -> void:
	var territory := Territories.territory_of(self, card)
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


## Logs a notable message, then emits noticed with it (116).
func _notice(message: String) -> void:
	_log(message)
	noticed.emit(message)


## Called whenever unrest drops (set_unrest, lose); GameEngine lets a ruling Anarchy shorten (155).
func _unrest_lowered() -> void:
	pass
