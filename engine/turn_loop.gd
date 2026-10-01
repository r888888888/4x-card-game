class_name TurnLoop
extends RefCounted
## The turn loop: setting up a new game, starting a turn (upkeep, feeding pop, era unlocks, drawing), ending it
## with the hand-limit discard, and game over. Static functions on the engine's state; GameEngine's public
## methods call them.


## Sets up a game with seed p_seed played as civilization civ_id ("" for none) and starts turn 1.
static func new_game(e: GameEngine, p_seed: int, civ_id: String) -> void:
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
	if e.config.starting.territory != "":
		home = Territories.make(e, e.config.starting.territory)
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
	if e.config.starting.government != "":
		e.zone("government").add(e._make_card(e.config.starting.government))

	e._log("New game — seed %d, %d cards in deck." % [p_seed, deck.size()])
	start_turn(e)
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
	if e.state.discard_left > 0:
		e.state.discard_left -= 1
		if e.state.discard_left == 0:
			finish_turn(e)  # emits changed
			return true
	e.changed.emit()
	return true


static func end_turn(e: GameEngine) -> void:
	if e.end_turn_error() != "":
		return
	Events.draw(e)
	if e.turn < e.turn_limit():
		var over: int = e.zone("hand").size() - e.config.hand_limit
		if over > 0:
			e.state.discard_left = over
			e._log("Hand limit is %d: discard %d." % [e.config.hand_limit, over])
			e.changed.emit()
			return
	finish_turn(e)


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
	start_turn(e)
	e.changed.emit()


static func start_turn(e: GameEngine) -> void:
	e.turn += 1
	e.state.actions_used = 0
	e._log("— Turn %d —" % e.turn)
	resolve_upkeep(e)
	if e.population_on():
		Population.feed(e)
	Research.check_era_unlocks(e)
	e.draw(maxi(0, e.config.hand_size - e.zone("hand").size()))


## Resolves "upkeep" on every working card: tableau cards that aren't idle, the cards in ALWAYS_ON_ZONES
## (researched techs, the civilization, the government), then active events (which may end).
static func resolve_upkeep(e: GameEngine) -> void:
	var working := e.zone("tableau").cards.filter(func(c): return not e.is_idle(c.uid))
	for z in GameEngine.ALWAYS_ON_ZONES:
		working += e.zone(z).cards
	for card in working:
		e._resolve(card, "upkeep")
	Events.resolve_upkeep(e)
