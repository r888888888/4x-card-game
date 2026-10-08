class_name TurnLoop
extends RefCounted
## The turn loop: setting up a new game, starting a turn (upkeep, feeding pop, era unlocks, drawing), ending it
## with the hand-limit discard, and game over. Static functions on the engine's state; GameEngine's public
## methods call them.


## The zones whose cards every turn forecast reads: the board and the always-on zones (336; forecast_zones adds the
## zones effects count).
const FORECAST_ZONES: Array[String] = ["tableau", "researched", "civilization", "government", "active_events"]


## Sets up a game with seed p_seed played as civilization civ_id ("" for none) and starts turn 1.
static func new_game(e: GameEngine, p_seed: int, civ_id: String) -> void:
	e._setting_up = true  # whatever eras or cities the setup adds, they are no milestones (191)
	e.state = GameState.new()
	e.seed_value = p_seed
	e.rng = SeededRng.new(p_seed)
	for z in GameEngine.ZONES:
		e.zones[z] = Zone.new(z)
	for r in e.config.resources:
		e.resources[r] = 0
	for r in e.config.starting.resources:
		e.resources[r] = e.config.starting.resources[r]
	for id in e.config.get("supply", {}):
		e.state.supply[id] = e.config.supply[id].count
		if e.config.supply[id].locked:
			e.state.locked_supply[id] = true
	for id in e.config.get("build_menu", {}):
		if e.config.build_menu[id].locked:
			e.state.locked_builds[id] = true

	var deck := e.zone("deck")
	for id in e.config.deck:
		for i in e.config.deck[id]:
			deck.add(e._make_card(id))
	e.rng.shuffle(deck.cards)
	var territory_deck := e.zone("territory_deck")
	for id in e.config.territory_deck:
		for i in e.config.territory_deck[id]:
			territory_deck.add(Territories.make(e, id))
	e.rng.shuffle(territory_deck.cards)
	var research_deck := e.zone("research_deck")
	for id in e.config.research_deck:
		for i in e.config.research_deck[id]:
			var tech := e._make_card(id)
			e.zone("research_deck" if tech.def.era == 1 else "future_techs").add(tech)
	if not research_deck.is_empty():
		e.rng.shuffle(research_deck.cards)
	Events.setup(e)
	var home: CardInstance = null
	var home_id: String = e.config.starting.territory
	if civ_id != "" and e.card_db[civ_id].home != "":
		home_id = e.card_db[civ_id].home
	if home_id != "":
		home = Territories.make_home(e, home_id)
		if e.population_on():
			home.pop = e.config.population.start
		e.zone("tableau").add(home)
	for id in e.config.starting.tableau:
		var card := e._make_card(id)
		if home != null:
			card.territory_uid = home.uid
		e.zone("tableau").add(card)
	if civ_id != "":
		var civilization := e._make_card(civ_id)
		e.zone("civilization").add(civilization)
		e._resolve(civilization, "start")
		if home != null:
			Territories.name_settled(e, home)
		for card in e.zone("tableau").cards:  # a start create into the tableau builds on the home (133)
			if card.def.type == CardDef.BUILDING and card.territory_uid == -1 and home != null:
				card.territory_uid = home.uid
	if e.config.starting.government != "":
		e.zone("government").add(e._make_card(e.config.starting.government))

	e._log("New game — seed %d, %d cards in deck." % [p_seed, deck.size()])
	start_turn(e)
	e._setting_up = false
	e.changed.emit()


## Why hand card uid can't be discarded now, or "".
static func discard_error(e: GameEngine, uid: int) -> String:
	var blocked := e._blocked_error("discard")
	if blocked != "":
		return blocked
	if e.zone("hand").find(uid) == null:
		return "That card is not in your hand."
	return ""


static func discard_card(e: GameEngine, uid: int) -> bool:
	if discard_error(e, uid) != "":
		return false
	var card := e.zone("hand").find(uid)
	e.zone("hand").remove(card)
	e.zone("discard").add(card)
	e._log("Discarded %s." % card.def.name)
	if e.state.pending.get("kind", "") == GameEngine.PENDING_DISCARD:
		e.state.pending.count -= 1
		if e.state.pending.count == 0:
			e.state.pending = {}
			finish_turn(e)  # emits changed
			return true
	e.changed.emit()
	return true


static func end_turn(e: GameEngine) -> void:
	if e.end_turn_error() != "":
		return
	if e.turn < e.turn_limit():
		var over: int = e.zone("hand").size() - e.config.hand_limit
		if over > 0:
			e.state.pending = {"kind": GameEngine.PENDING_DISCARD, "count": over}
			e._log("Hand limit is %d: discard %d." % [e.config.hand_limit, over])
			e.changed.emit()
			return
	finish_turn(e)


## Ends the turn after any hand-limit discard: game over on the last turn; else a counter comes off a ruling Anarchy
## (155), which may owe the government choice first; else the next turn starts.
static func finish_turn(e: GameEngine) -> void:
	if e.turn >= e.turn_limit():
		e.is_over = true
		var discard := e.zone("discard")
		for card in e.zone("hand").take_all():
			discard.add(card)
		var final_score := e.score()
		e._log("Game over after %d turns. Final score: %d." % [e.turn, final_score])
		e.changed.emit()
		e.game_over.emit(final_score)
		return
	if Anarchy.end_of_turn(e):
		e.changed.emit()
		return
	start_turn(e)
	e.changed.emit()


static func start_turn(e: GameEngine) -> void:
	_begin(e)
	_settle_in(e)
	e.draw(maxi(0, e.hand_size() - e.zone("hand").size()))
	Anarchy.start_renewal(e)
	if e.turn >= 2:  # the turn's event, last, so it is active all turn (237); raids drawn earlier strike first (162)
		e.military.strike_raids()
		Events.draw(e)


## What starting the next turn would change (309), played on a fork so nothing here changes: {score, pop, starve (the
## pop feeding starves), resource: change} after upkeep, feeding, era unlocks, Anarchy's fall and the raids
## that strike; not the draw, the renewal or the new event. {} on the last turn or after game over.
static func forecast(e: GameEngine) -> Dictionary:
	if e.is_over or e.turn >= e.turn_limit():
		return {}
	var f := e.fork()
	_begin(f)
	var starve := _settle_in(f)
	if f.turn >= 2:
		f.military.strike_raids()
	var out := {"score": f.score() - e.score(), "pop": f.total_pop() - e.total_pop(), "starve": starve}
	for r in e.resources:
		out[r] = f.resources.get(r, 0) - e.resources[r]
	return out


## The zones a turn forecast of e reads (336): FORECAST_ZONES plus every zone an effect in the card db counts
## (Effect.reads_zones), in that order.
static func forecast_zones(e: GameEngine) -> Array[String]:
	var out: Array[String] = FORECAST_ZONES.duplicate()
	for id in e.card_db:
		for effect: Effect in e.card_db[id].effects:
			for z in effect.reads_zones():
				if not out.has(z):
					out.append(z)
	return out


## A new turn's number, its counts reset and its log line.
static func _begin(e: GameEngine) -> void:
	e.turn += 1
	e.state.actions_used = 0
	e.state.actions_gained = 0
	e.state.moved_units.clear()
	Sites.start_turn(e)
	e._log("— Turn %d —" % e.turn)


## The start-of-turn steps before the draw (shared by start_turn and forecast): upkeep, feeding, era unlocks and
## Anarchy's fall. Returns the pop feeding starved.
static func _settle_in(e: GameEngine) -> int:
	Anarchy.before_upkeep(e)
	resolve_upkeep(e)
	var starved := 0
	if e.population_on():
		var pop := e.total_pop()
		Population.feed(e)
		starved = pop - e.total_pop()
	Research.check_era_unlocks(e)
	Anarchy.start_of_turn(e)
	return starved


## Adds size unrest (282) and admin unrest (319), then resolves "upkeep" on every working card: tableau cards that aren't idle, the cards in ALWAYS_ON_ZONES
## (researched techs, the civilization, the government), then active events (which may end).
static func resolve_upkeep(e: GameEngine) -> void:
	var crowded := e.size_unrest()  # first, before any upkeep takes pop (282)
	if crowded > 0:
		e._log("Crowded territories: +%d unrest." % e.set_unrest(e.resources.get(GameEngine.UNREST, 0) + crowded))
	var overextended := e.admin_unrest()  # read with size unrest, before any upkeep (319)
	if overextended > 0:
		e._log("Overextended realm: +%d unrest." % e.set_unrest(e.resources.get(GameEngine.UNREST, 0) + overextended))
	for card in Modifiers.working_cards(e):
		e._resolve(card, "upkeep")
	Events.resolve_upkeep(e)
