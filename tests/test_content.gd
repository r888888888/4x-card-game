extends "res://tests/lib/test_case.gd"
## The real game data (data/*.json): territory content coverage and a scripted smoke test (backlog 006).
## These are the only tests besides test_real_data_loads that read the real data. They check shape and
## that games run, not balance numbers.


func load_real() -> Dictionary:
	var r := DataLoader.load_all("res://data/cards.json", "res://data/config.json")
	check(r.errors.is_empty(), "real data errors: %s" % [r.errors])
	return r


func real_engine(seed_value: int) -> GameEngine:
	var r := load_real()
	var e := GameEngine.new(r.cards, r.config)
	e.new_game(seed_value)
	return e


## Plays one scripted game: resolve any pending choice with its first option, otherwise play the
## first hand card that can be played (on its first valid target), otherwise discard the hand
## (dead cards never cycle otherwise, backlog 024) and end the turn.
func play_scripted_game(e: GameEngine) -> void:
	var steps := 0
	while not e.is_over and steps < 2000:
		steps += 1
		if not e.pending_choice.is_empty():
			e.choose(e.pending_choice.options[0])
			continue
		var played := false
		for card in e.zone("hand").cards.duplicate():
			var targets := e.valid_targets(card.uid)
			var target: int = targets[0] if e.needs_target(card.uid) and not targets.is_empty() else -1
			if e.play_error(card.uid, target) == "":
				played = e.play_card(card.uid, target)
				break
		if not played:
			for card in e.zone("hand").cards.duplicate():
				e.discard_card(card.uid)
			e.end_turn()
	check(e.is_over, "game finished within 2000 steps")


func count_id(zone: Zone, id: String) -> int:
	var n := 0
	for c in zone.cards:
		if c.def.id == id:
			n += 1
	return n


# --- AC2: coverage ---

func test_territory_deck_has_at_least_10_territories() -> void:
	var config: Dictionary = load_real().config
	var total := 0
	for id in config.territory_deck:
		total += config.territory_deck[id]
	check(total >= 10, "territory deck has %d territories (need >= 10)" % total)


func test_territory_deck_covers_at_least_5_keywords() -> void:
	var r := load_real()
	var covered := {}
	for id in r.config.territory_deck:
		for k in r.cards[id].keywords:
			covered[k] = true
	check(covered.size() >= 5, "territory deck covers %d keywords (need >= 5): %s" % [covered.size(), covered.keys()])


func test_every_keyword_is_on_a_territory_and_a_card() -> void:
	var r := load_real()
	var on_territory := {}
	var on_card := {}
	for id in r.cards:
		var def: CardDef = r.cards[id]
		if def.type == "territory":
			if r.config.territory_deck.has(id) or r.config.starting.territory == id:
				for k in def.keywords:
					on_territory[k] = true
			continue
		for k in def.requires:
			on_card[k] = true
		for e in def.effects:
			if e.keyword != "":
				on_card[e.keyword] = true
	var missing_territory: Array[String] = []
	var missing_card: Array[String] = []
	for k in r.config.keywords:
		if not on_territory.has(k):
			missing_territory.append(k)
		if not on_card.has(k):
			missing_card.append(k)
	eq(missing_territory, [] as Array[String], "keywords on no territory in play")
	eq(missing_card, [] as Array[String], "keywords used by no card")


# --- AC3: scripted smoke test ---

func test_scripted_games_run_and_found_cities() -> void:
	var founded := 0
	for s in range(1, 21):
		var e := real_engine(s)
		play_scripted_game(e)
		if count_id(e.zone("tableau"), "city") >= 1:
			founded += 1
	check(founded >= 11, "a City beyond the Capital was founded in %d of 20 seeds (need most: >= 11)" % founded)


func test_real_config_turns_population_on() -> void:
	var r := load_real()
	check(not r.config.get("population", {}).is_empty(), "data/config.json has a population block (backlog 009)")


func test_real_deck_has_growth_cards() -> void:
	var r := load_real()
	var growth := 0
	for id in r.config.deck:
		for effect in r.cards[id].effects:
			if effect.op == "grow":
				growth += r.config.deck[id]
				break
	check(growth >= 4, "at least 4 growth cards in the deck (got %d)" % growth)


# --- Wealth content (backlog 022) ---

## Whether any effect on def produces wealth (gain or gain_per_tag with resource "wealth").
func makes_wealth(def: CardDef) -> bool:
	for effect in def.effects:
		if effect.get("resource") == "wealth":
			return true
	return false


func test_real_deck_has_wealth_costs_and_capital_makes_wealth() -> void:
	var r := load_real()
	var costs_wealth := 0
	for id in r.config.deck:
		if r.cards[id].cost.get("wealth", 0) > 0:
			costs_wealth += 1
	check(costs_wealth >= 1, "at least 1 deck card costs wealth (got %d)" % costs_wealth)
	var capital_upkeep_wealth := false
	for effect in r.cards.capital.effects:
		if effect.get("resource") == "wealth" and effect.trigger == "upkeep":
			capital_upkeep_wealth = true
	check(capital_upkeep_wealth, "Capital produces wealth at upkeep")


func test_every_wealth_cost_has_a_wealth_source() -> void:
	var r := load_real()
	var sources: Array[String] = []
	for id in r.config.deck.keys() + r.config.starting.tableau:
		if makes_wealth(r.cards[id]):
			sources.append(id)
	for id in r.config.deck:
		if r.cards[id].cost.get("wealth", 0) > 0:
			check(not sources.is_empty(), "%s costs wealth but nothing in the deck or starting tableau makes it" % id)
	check(true, "ran")  # the deck may have no wealth costs; the test above covers that


func test_scripted_games_spend_wealth_and_never_go_negative() -> void:
	var spent_in := 0
	for s in range(1, 4):
		var e := real_engine(s)
		var state := {"spent": false, "min": e.resources.get("wealth", 0)}
		var on_played := func(o): if o.paid.get("wealth", 0) > 0: state.spent = true
		var on_changed := func(): state.min = mini(state.min, e.resources.get("wealth", 0))
		e.card_played.connect(on_played)
		e.changed.connect(on_changed)
		play_scripted_game(e)
		e.changed.disconnect(on_changed)  # on_changed holds e: break the cycle so e is freed
		e.card_played.disconnect(on_played)
		check(state.min >= 0, "seed %d: wealth went down to %d" % [s, state.min])
		if state.spent:
			spent_in += 1
	check(spent_in >= 1, "a card costing wealth was played in %d of 3 seeds (need >= 1)" % spent_in)
