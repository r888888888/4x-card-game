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


## Plays one scripted game: resolve any pending choice with its first option, buy the cheapest
## revealed tech it can afford (or decline), otherwise play the first hand card that can be played
## (on its first valid target; a Research card reveals techs), otherwise discard the hand (dead cards
## never cycle otherwise, backlog 024) and end the turn.
func play_scripted_game(e: GameEngine) -> void:
	var steps := 0
	while not e.is_over and steps < 2000:
		steps += 1
		if not e.pending_choice.is_empty():
			e.choose(e.pending_choice.options[0])
			continue
		if not e.research_options().is_empty():
			buy_cheapest_tech(e)
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


## Buys the cheapest revealed tech the engine allows, or declines when none is affordable.
func buy_cheapest_tech(e: GameEngine) -> void:
	var best := -1
	for uid in e.research_options():
		if e.buy_tech_error(uid) == "" and (best == -1 or e.tech_cost(uid) < e.tech_cost(best)):
			best = uid
	if best == -1:
		e.decline_research()
	else:
		e.buy_tech(best)


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
	var counts: Dictionary = r.config.deck.duplicate()
	for id in r.config.get("supply", {}):  # backlog 032: some copies moved to the supply
		counts[id] = counts.get(id, 0) + r.config.supply[id].count
	var growth := 0
	for id in counts:
		for effect in r.cards[id].effects:
			if effect.op == "grow":
				growth += counts[id]
				break
	check(growth >= 4, "at least 4 growth cards in the deck and supply (got %d)" % growth)


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


# --- Tech content (backlog 028) ---

## The cards moved out of the starting deck, each now unlocked by a tech.
const UNLOCKED := ["pasture", "harbor", "monument", "pyramids", "forge"]


func techs_in_research_deck(r: Dictionary) -> Array[CardDef]:
	var out: Array[CardDef] = []
	for id in r.config.get("research_deck", {}):
		out.append(r.cards[id])
	return out


## Card ids a tech's create effects put into play.
func created_by(tech: CardDef) -> Array[String]:
	var out: Array[String] = []
	for effect in tech.effects:
		if effect.op == "create":
			out.append(effect.card_id)
	return out


func test_real_data_loads_without_warnings() -> void:
	var r := load_real()
	eq(r.warnings, [] as Array[String], "real data warnings")


func test_research_deck_has_6_techs_in_each_of_eras_1_and_2() -> void:
	var r := load_real()
	var per_era := {1: 0, 2: 0}
	var adds_era_2 := false
	for tech in techs_in_research_deck(r):
		per_era[tech.era] = per_era.get(tech.era, 0) + 1
		for effect in tech.effects:
			if tech.era == 1 and effect.op == "add_era" and effect.era == 2:
				adds_era_2 = true
	check(per_era[1] >= 6, "era-1 techs: %d (need >= 6)" % per_era[1])
	check(per_era[2] >= 6, "era-2 techs: %d (need >= 6)" % per_era[2])
	check(adds_era_2, "an era-1 tech adds era 2")


func test_every_tech_prereq_is_in_the_research_deck() -> void:
	var r := load_real()
	var techs := techs_in_research_deck(r)
	check(not techs.is_empty(), "the research deck has techs")
	for tech in techs:
		if tech.prereq != "":
			check(r.config.research_deck.has(tech.prereq), "%s: prereq %s is not in research_deck" % [tech.id, tech.prereq])


func test_techs_only_create_cards_that_are_not_techs() -> void:
	var r := load_real()
	var created := 0
	for tech in techs_in_research_deck(r):
		for id in created_by(tech):
			created += 1
			check(r.cards[id].type != "tech", "%s creates tech %s" % [tech.id, id])
	check(created > 0, "some tech creates a card")


func test_a_tech_unlocks_the_library() -> void:
	var r := load_real()
	check(r.cards.has("library"), "a Library card exists")
	check(not r.config.deck.has("library"), "the Library is not in the main deck")
	var unlocked := false
	for tech in techs_in_research_deck(r):
		if created_by(tech).has("library"):
			unlocked = true
	check(unlocked, "a tech in research_deck creates a Library")
	if r.cards.has("library"):
		check(created_by(r.cards.library).has("research"), "the Library creates a Research card")


func test_every_card_moved_out_of_the_deck_is_unlocked_by_a_tech() -> void:
	var r := load_real()
	var unlocks := {}
	for tech in techs_in_research_deck(r):
		for id in created_by(tech):
			unlocks[id] = tech.id
	for id in UNLOCKED:
		check(not r.config.deck.has(id), "%s is no longer in the main deck" % id)
		check(unlocks.has(id), "a tech in research_deck creates %s" % id)


func test_scripted_games_buy_techs_and_never_go_negative() -> void:
	var bought_in := 0
	for s in range(1, 4):
		var e := real_engine(s)
		var state := {"min": e.resources.get("wealth", 0)}
		var on_changed := func(): state.min = mini(state.min, e.resources.get("wealth", 0))
		e.changed.connect(on_changed)
		play_scripted_game(e)
		e.changed.disconnect(on_changed)  # on_changed holds e: break the cycle so e is freed
		check(state.min >= 0, "seed %d: wealth went down to %d" % [s, state.min])
		if not e.zone("researched").is_empty():
			bought_in += 1
	check(bought_in >= 1, "a tech was bought in %d of 3 seeds (need >= 1)" % bought_in)


# --- Era unlock thresholds (backlog 029) ---

func test_real_config_sets_an_era_2_threshold() -> void:
	var r := load_real()
	var unlocks: Dictionary = r.config.get("era_unlocks", {})
	check(unlocks.has(2), "era_unlocks has era 2: %s" % [unlocks])
	if unlocks.has(2):
		check(unlocks[2].has("pop") or unlocks[2].has("wealth"), "era 2 has a pop or wealth threshold")


func test_capital_adds_4_building_slots() -> void:
	var r := load_real()
	eq(r.cards.capital.slots, 4, "Capital slots")


# --- Supply (backlog 032) ---

func test_real_research_card_starts_in_the_deck_and_is_sold() -> void:
	var r := load_real()
	check(r.cards.has("research"), "a research card exists")
	if not r.cards.has("research"):
		return
	var card: CardDef = r.cards.research
	eq([card.name, card.type, card.cost, card.vp], ["Research", "action", {}, 0], "name, type, cost, vp")
	eq(card.effects.map(func(e): return e.op), ["research"], "effects")
	eq(r.config.deck.get("research", 0), 1, "one Research card in the deck")
	var total := 0
	for id in r.config.deck:
		total += r.config.deck[id]
	eq(total, 23, "starting deck size")
	var supply: Dictionary = r.config.get("supply", {})
	eq(supply.get("research", {}), {"price": 3, "count": 2}, "supply entry")


func test_real_supply_sells_scouts() -> void:
	var r := load_real()
	check(r.config.get("supply", {}).has("scout"), "data/config.json supply has scout")


func test_every_supply_card_also_starts_in_the_deck() -> void:
	var r := load_real()
	var supply: Dictionary = r.config.get("supply", {})
	check(not supply.is_empty(), "the real config has a supply")
	for id in supply:
		check(r.config.deck.get(id, 0) >= 1, "%s is in the supply and still starts in the deck" % id)
