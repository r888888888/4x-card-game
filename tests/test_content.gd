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


# --- AC3: scripted smoke test (the bot is sim/bot.gd, backlog 042) ---

## Plays seeds 1-20 with the scripted bot and checks every game ends, wealth never goes below 0, and that
## new territories, wealth costs and techs all come up in some seeds.
func test_scripted_sweep_over_20_seeds() -> void:
	var founded := 0
	var spent_in := 0
	var bought_in := 0
	for s in range(1, 21):
		var e := real_engine(s)
		var state := {"spent": false, "min": e.resources.get("wealth", 0)}
		var on_played := func(o): if o.paid.get("wealth", 0) > 0: state.spent = true
		var on_changed := func(): state.min = mini(state.min, e.resources.get("wealth", 0))
		e.card_played.connect(on_played)
		e.changed.connect(on_changed)
		ScriptedBot.play(e)
		e.changed.disconnect(on_changed)  # on_changed holds e: break the cycle so e is freed
		e.card_played.disconnect(on_played)
		check(e.is_over, "seed %d: game finished within 2000 steps" % s)
		check(e.zone("active_events").size() + e.zone("event_discard").size() > 0, "seed %d: an event was drawn" % s)
		check(state.min >= 0, "seed %d: wealth went down to %d" % [s, state.min])
		if e.zone("tableau").cards.filter(func(c): return c.def.type == CardDef.TERRITORY).size() >= 2:
			founded += 1
		if state.spent:
			spent_in += 1
		if not e.zone("researched").is_empty():
			bought_in += 1
	# 9, not 11, since 038: home housing 5 lets pop eat the food the bot would save for a Settler.
	check(founded >= 9, "a territory beyond the start was settled in %d of 20 seeds (need >= 9)" % founded)
	check(spent_in >= 1, "a card costing wealth was played in %d of 20 seeds (need >= 1)" % spent_in)
	check(bought_in >= 1, "a tech was bought in %d of 20 seeds (need >= 1)" % bought_in)


func test_real_deck_has_growth_cards() -> void:
	var r := load_real()
	var counts: Dictionary = r.config.deck.duplicate()
	for id in r.config.get("supply", {}):  # backlog 032: some copies moved to the supply
		counts[id] = counts.get(id, 0) + r.config.supply[id].count
	for id in r.config.get("event_deck", {}):  # backlog 069: Harvest Festival became an event
		counts[id] = counts.get(id, 0) + r.config.event_deck[id]
	var growth := 0
	for id in counts:
		var def: CardDef = r.cards[id]
		# backlog 060: a famine guard (the Granary) keeps pop, so it counts as a growth card
		if def.famine_guard > 0 or def.effects.any(func(effect): return effect.op == "grow"):
			growth += counts[id]
	check(growth >= 4, "at least 4 growth or famine guard cards in the deck, supply and event deck (got %d)" % growth)


# --- Starter events (backlog 069) ---

## The ops a real event may use: they only give (see 072 for harmful ops).
const EVENT_OPS: Array[String] = ["gain", "gain_per_tag", "score", "grow"]


func test_every_real_event_is_in_the_event_deck() -> void:
	var r := load_real()
	check(not r.config.get("event_deck", {}).is_empty(), "the real event deck is not empty")
	var unused: Array[String] = []
	for id in r.cards:
		if id == r.config.famine.get("card", ""):  # 083: the Famine comes from hunger, never from the deck
			continue
		if r.cards[id].type == CardDef.EVENT and not r.config.get("event_deck", {}).has(id):
			unused.append(id)
	eq(unused, [] as Array[String], "events not in event_deck")


func test_real_events_are_neutral_or_beneficial() -> void:
	var r := load_real()
	var blank := 0
	var active := 0
	var bad_ops: Array[String] = []
	for id in r.config.get("event_deck", {}):
		var def: CardDef = r.cards[id]
		if def.effects.is_empty():
			blank += 1
		else:
			active += 1
		for effect in def.effects:
			if not EVENT_OPS.has(effect.op):
				bad_ops.append("%s: %s" % [id, effect.op])
	eq(bad_ops, [] as Array[String], "event effects that aren't gain, gain_per_tag, score or grow")
	check(blank >= 1, "at least one blank event (got %d)" % blank)
	check(active >= 1, "at least one event with an effect (got %d)" % active)


# --- Wealth content (backlog 022) ---

## Whether any effect on def produces wealth (gain or gain_per_tag with resource "wealth").
func makes_wealth(def: CardDef) -> bool:
	for effect in def.effects:
		if effect.get("resource") == "wealth":
			return true
	return false


func test_real_deck_has_wealth_costs_and_the_starting_tableau_makes_wealth() -> void:
	var r := load_real()
	var costs_wealth := 0
	for id in r.config.deck:
		if r.cards[id].cost.get("wealth", 0) > 0:
			costs_wealth += 1
	check(costs_wealth >= 1, "at least 1 deck card costs wealth (got %d)" % costs_wealth)
	var upkeep_wealth := false
	for id in r.config.starting.tableau:
		for effect in r.cards[id].effects:
			if effect.get("resource") == GameEngine.WEALTH and effect.trigger == "upkeep":
				upkeep_wealth = true
	check(upkeep_wealth, "a starting tableau card %s produces wealth at upkeep" % [r.config.starting.tableau])


func test_every_wealth_cost_has_a_wealth_source() -> void:
	var r := load_real()
	var sources: Array[String] = []
	for id in r.config.deck.keys() + r.config.starting.tableau:
		if makes_wealth(r.cards[id]):
			sources.append(id)
	var unfunded_card_ids: Array[String] = []
	if sources.is_empty():
		for id in r.config.deck:
			if r.cards[id].cost.get("wealth", 0) > 0:
				unfunded_card_ids.append(id)
	eq(unfunded_card_ids, [] as Array[String], "cards that cost wealth with nothing in the deck or starting tableau making it")


# --- Building costs (backlog 076) ---

## Whether any effect on def produces food (gain or gain_per_tag with resource food).
func makes_food(def: CardDef) -> bool:
	for effect in def.effects:
		if effect.get("resource") == GameEngine.FOOD:
			return true
	return false


func real_buildings(r: Dictionary) -> Array[CardDef]:
	var out: Array[CardDef] = []
	for id in r.cards:
		if r.cards[id].type == CardDef.BUILDING:
			out.append(r.cards[id])
	return out


func test_every_building_costs_wealth() -> void:
	var r := load_real()
	var no_wealth: Array[String] = []
	for def in real_buildings(r):
		if def.cost.get(GameEngine.WEALTH, 0) < 1:
			no_wealth.append(def.id)
	eq(no_wealth, [] as Array[String], "buildings that cost no wealth")


func test_only_food_buildings_cost_food_and_at_most_1() -> void:
	var r := load_real()
	var too_much_food: Array[String] = []
	for def in real_buildings(r):
		var limit := 1 if makes_food(def) else 0
		if def.cost.get(GameEngine.FOOD, 0) > limit:
			too_much_food.append(def.id)
	eq(too_much_food, [] as Array[String], "buildings costing more food than allowed (0, or 1 if they make food)")


func test_starting_resources_afford_a_starting_deck_building() -> void:
	var r := load_real()
	var start: Dictionary = r.config.starting.get("resources", {})
	check(start.get(GameEngine.WEALTH, 0) >= 1, "start with at least 1 wealth (got %d)" % start.get(GameEngine.WEALTH, 0))
	var affordable: Array[String] = []
	for id in r.config.deck:
		var def: CardDef = r.cards[id]
		if def.type != CardDef.BUILDING:
			continue
		var ok := true
		for res in def.cost:
			if def.cost[res] > start.get(res, 0):
				ok = false
		if ok:
			affordable.append(id)
	check(not affordable.is_empty(), "starting resources %s pay for no building in the starting deck" % [start])


# --- Tech content (backlog 028) ---

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


func test_real_config_lists_at_least_3_different_civilizations() -> void:
	var r := load_real()
	var civs: Array = r.config.get("civilizations", [])
	check(civs.size() >= 3, "at least 3 civilizations (got %s)" % [civs])
	var seen := {}  # effect text -> civilization id
	for id in civs:
		var def: CardDef = r.cards[id]
		check(not def.effects.is_empty(), "%s has an effect" % id)
		var text := def.rules_tooltip(r.cards)
		check(not seen.has(text), "%s has the same effects as %s" % [id, seen.get(text, "")])
		seen[text] = id


func test_real_data_loads_without_warnings() -> void:
	var r := load_real()
	eq(r.warnings, [] as Array[String], "real data warnings")


func test_every_tech_prereq_is_in_the_research_deck() -> void:
	var r := load_real()
	var techs := techs_in_research_deck(r)
	check(not techs.is_empty(), "the research deck has techs")
	for tech in techs:
		if tech.prereq != "":
			check(r.config.research_deck.has(tech.prereq), "%s: prereq %s is not in research_deck" % [tech.id, tech.prereq])


## Techs in research_deck per era: {era: count}.
func techs_per_era(r: Dictionary) -> Dictionary:
	var out := {}
	for tech in techs_in_research_deck(r):
		out[tech.era] = out.get(tech.era, 0) + 1
	return out


func test_every_researchable_era_has_2_techs_and_is_added() -> void:
	var r := load_real()
	var per_era := techs_per_era(r)
	check(per_era.has(1), "era 1 has techs in research_deck")
	var added := {}  # era -> true, when a lower-era tech in research_deck or era_unlocks adds it
	for tech in techs_in_research_deck(r):
		for effect in tech.effects:
			if effect.op == "add_era" and tech.era < effect.era:
				added[effect.era] = true
	for era in r.config.era_unlocks:
		added[era] = true
	for era in per_era:
		check(per_era[era] >= 2, "era %d has %d tech(s) in research_deck (a reveal shows 2)" % [era, per_era[era]])
		if era > 1:
			check(added.has(era), "era %d is added by a lower-era tech's add_era or by era_unlocks" % era)


func test_every_added_era_has_techs_in_the_research_deck() -> void:
	var r := load_real()
	var per_era := techs_per_era(r)
	for id in r.cards:
		for effect in r.cards[id].effects:
			if effect.op == "add_era":
				check(per_era.has(effect.era), "%s adds era %d, which has no techs in research_deck" % [id, effect.era])
	for era in r.config.era_unlocks:
		check(per_era.has(era), "era_unlocks names era %d, which has no techs in research_deck" % era)


func test_techs_only_create_cards_that_are_not_techs() -> void:
	var r := load_real()
	var created := 0
	for tech in techs_in_research_deck(r):
		for id in created_by(tech):
			created += 1
			check(r.cards[id].type != "tech", "%s creates tech %s" % [tech.id, id])
	check(created > 0, "some tech creates a card")


func test_every_card_a_tech_gives_is_a_locked_pile_it_unlocks() -> void:
	var r := load_real()
	var checked := 0
	for tech in techs_in_research_deck(r):
		var unlocks: Array[String] = []
		for effect in tech.effects:
			if effect.op == "unlock":
				unlocks.append(effect.card_id)
		for id in created_by(tech):
			checked += 1
			var pile: Dictionary = r.config.supply.get(id, {})
			if r.cards[id].has_tag("wonder") or r.cards[id].type == CardDef.GOVERNMENT:
				check(pile.is_empty(), "%s (from %s) has no supply pile" % [id, tech.id])
				continue
			check(pile.get("locked", false), "%s (from %s) is a locked supply pile" % [id, tech.id])
			check(unlocks.has(id), "%s unlocks %s" % [tech.id, id])
	check(checked > 0, "some tech gives a card")


## Backlog 065: the game starts with a government, and every other government comes from a researchable tech.
func test_starting_government_and_every_other_government_comes_from_a_tech() -> void:
	var r := load_real()
	var start: String = r.config.starting.government
	check(start != "", "config has a starting.government")
	var given := {}
	for tech in techs_in_research_deck(r):
		for id in created_by(tech):
			given[id] = true
	var others := 0
	for id in r.cards:
		if r.cards[id].type == CardDef.GOVERNMENT and id != start:
			others += 1
			check(given.has(id), "a tech in research_deck creates government %s" % id)
	check(others >= 2, "at least 2 governments besides the starting one (got %d)" % others)


# --- Supply (backlog 032) ---

## Replaces test_every_supply_card_also_starts_in_the_deck (057): a locked pile is reached through a tech instead.
## Since 082 an unlocked pile needs no deck copy: some cards are only for sale.
func test_every_locked_supply_pile_is_unlocked_by_a_tech() -> void:
	var r := load_real()
	var supply: Dictionary = r.config.get("supply", {})
	check(not supply.is_empty(), "the real config has a supply")
	var unlocked_by_tech := {}
	for id in r.config.research_deck:
		for effect in r.cards[id].effects:
			if effect.op == "unlock":
				unlocked_by_tech[effect.card_id] = true
	for id in supply:
		if supply[id].get("locked", false):
			check(unlocked_by_tech.has(id), "locked pile %s is unlocked by a tech in research_deck" % id)


# --- Rolled resources (036, 037) ---

func test_every_resource_keyword_is_rolled_and_used() -> void:
	var r := load_real()
	var rolled := {}
	for id in r.config.territory_resources:
		if not r.config.territory_deck.has(id):
			continue
		for option in r.config.territory_resources[id]:
			for k in option.keywords:
				rolled[k] = true
	var used := {}
	for id in r.cards:
		var def: CardDef = r.cards[id]
		for k in def.requires:
			used[k] = true
		for e in def.effects:
			if e.keyword != "":
				used[e.keyword] = true
	var not_rolled: Array[String] = []
	var not_used: Array[String] = []
	for k in r.config.resource_keywords:
		if not rolled.has(k):
			not_rolled.append(k)
		if not used.has(k):
			not_used.append(k)
	eq(not_rolled, [] as Array[String], "resource keywords no territory in the deck rolls")
	eq(not_used, [] as Array[String], "resource keywords no card uses")


# --- Territories and what they take (054, 080, backlog 092) ---

## The keywords territories in play can have: printed on the starting territory or one in territory_deck, or
## rolled by territory_resources for one in territory_deck.
func keywords_in_play(r: Dictionary) -> Dictionary:
	var out := {}
	for id in [r.config.starting.territory] + r.config.territory_deck.keys():
		for k in r.cards[id].keywords:
			out[k] = true
	for id in r.config.territory_resources:
		if r.config.territory_deck.has(id):
			for option in r.config.territory_resources[id]:
				for k in option.keywords:
					out[k] = true
	return out


func test_every_territory_can_take_a_building_from_the_start() -> void:
	var r := load_real()
	var early: Array[CardDef] = []
	for id in r.config.deck:
		if r.cards[id].type == CardDef.BUILDING:
			early.append(r.cards[id])
	for id in r.config.supply:
		if r.cards[id].type == CardDef.BUILDING and not r.config.supply[id].get("locked", false):
			early.append(r.cards[id])
	for id in [r.config.starting.territory] + r.config.territory_deck.keys():
		var land: CardDef = r.cards[id]
		var fits := early.filter(func(b): return b.requires.is_empty() or b.requires.any(func(k): return land.keywords.has(k)))
		check(not fits.is_empty(), "territory %s %s can take a starting-deck or open-supply building" % [id, land.keywords])


func test_every_building_requirement_is_met_by_a_territory_in_play() -> void:
	var r := load_real()
	var in_play := keywords_in_play(r)
	var unmet: Array[String] = []
	for def in real_buildings(r):
		if not def.requires.is_empty() and not def.requires.any(func(k): return in_play.has(k)):
			unmet.append("%s %s" % [def.id, def.requires])
	eq(unmet, [] as Array[String], "buildings whose requires no starting or territory_deck territory meets")


func test_every_gain_per_keyword_keyword_is_on_a_territory_in_play() -> void:
	var r := load_real()
	var in_play := keywords_in_play(r)
	var missing: Array[String] = []
	for id in r.cards:
		for effect in r.cards[id].effects:
			if effect.op == "gain_per_keyword":
				for k in effect.get("keywords"):
					if not in_play.has(k):
						missing.append("%s: %s" % [id, k])
	eq(missing, [] as Array[String], "gain_per_keyword keywords no territory in play has")
