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


# --- AC3: scripted smoke test (the bot is sim/bot.gd, backlog 042) ---

## Plays seeds 1-20 with the scripted bot and checks every game ends, wealth never goes below 0, and that
## Cities, wealth costs and techs all come up in some seeds.
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
		if count_id(e.zone("tableau"), "city") >= 1:
			founded += 1
		if state.spent:
			spent_in += 1
		if not e.zone("researched").is_empty():
			bought_in += 1
	# 9, not 11, since 038: home housing 5 lets pop eat the food the bot would save for a Settler.
	check(founded >= 9, "a City beyond the Capital was founded in %d of 20 seeds (need >= 9)" % founded)
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


func test_forage_and_harvest_festival_are_events() -> void:
	var r := load_real()
	for id in ["forage", "harvest_festival"]:
		eq(r.cards[id].type, CardDef.EVENT, "%s type" % id)
		check(r.config.get("event_deck", {}).has(id), "%s in event_deck" % id)
		check(not r.config.deck.has(id), "%s not in deck" % id)
		check(not r.config.get("supply", {}).has(id), "%s not in supply" % id)
	var effects: Array = r.cards.harvest_festival.effects
	eq(effects.size(), 1, "Harvest Festival has one effect")
	if effects.size() == 1:
		eq([effects[0].op, effects[0].trigger], ["gain_per_tag", "upkeep"], "Harvest Festival op and trigger")
		if effects[0].op == "gain_per_tag":
			eq([effects[0].resource, effects[0].tag], [GameEngine.FOOD, "farm"], "food per farm")


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

## The cards moved out of the starting deck, each now unlocked by a tech.
const UNLOCKED := ["pasture", "harbor", "monument", "pyramids", "forge", "caravan", "temple", "mine", "market", "granary"]
## Era-3 techs kept in cards.json but out of the game for now (058).
const ERA_3_TECHS := ["philosophy", "iron_working", "mathematics", "monarchy", "astronomy", "engineering"]


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


func test_research_card_is_named_insight() -> void:
	var r := load_real()
	eq(r.cards.research.name if r.cards.has("research") else "", "Insight", "the research card's name")


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


func test_no_era_3_tech_is_researchable_or_added() -> void:
	var r := load_real()
	for tech in techs_in_research_deck(r):
		check(tech.era < 3, "%s in research_deck is era %d" % [tech.id, tech.era])
	for id in r.cards:
		for effect in r.cards[id].effects:
			if effect.op == "add_era":
				check(effect.era < 3, "%s adds era %d" % [id, effect.era])


func test_era_3_techs_are_defined_but_not_in_the_research_deck() -> void:
	var r := load_real()
	for id in ERA_3_TECHS:
		check(r.cards.has(id) and r.cards[id].type == CardDef.TECH, "%s is still a tech in cards.json" % id)
		if r.cards.has(id):
			eq(r.cards[id].era, 3, "%s era" % id)
		check(not r.config.research_deck.has(id), "%s is not in research_deck" % id)


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


func test_every_card_moved_out_of_the_deck_is_unlocked_by_a_tech() -> void:
	var r := load_real()
	var unlocks := {}
	for tech in techs_in_research_deck(r):
		for id in created_by(tech):
			unlocks[id] = tech.id
	for id in UNLOCKED:
		check(not r.config.deck.has(id), "%s is no longer in the main deck" % id)
		check(unlocks.has(id), "a tech in research_deck creates %s" % id)


# --- Supply (backlog 032) ---

## Replaces test_every_supply_card_also_starts_in_the_deck (057): a locked pile is reached through a tech instead.
func test_every_supply_pile_starts_in_the_deck_or_is_unlocked_by_a_tech() -> void:
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
		elif r.cards[id].type != CardDef.BUILDING:  # 080: a building may be on sale from turn 1 without a deck copy
			check(r.config.deck.get(id, 0) >= 1, "unlocked pile %s still starts in the deck" % id)


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


# --- Fresh Water (054) ---

func test_starting_territory_has_fresh_water() -> void:
	var r := load_real()
	var def: CardDef = r.cards[r.config.starting.territory]
	check(def.keywords.has("fresh_water"), "the starting territory %s has fresh_water" % def.id)


func test_farm_requires_fresh_water_and_the_deck_has_it() -> void:
	var r := load_real()
	eq(r.cards.farm.requires, ["fresh_water"] as Array[String], "farm requires")
	var wet := 0
	for id in r.config.territory_deck:
		if r.cards[id].keywords.has("fresh_water"):
			wet += 1
	check(wet >= 2, "at least 2 territories in the territory deck have fresh_water (got %d)" % wet)


func test_farm_can_target_the_capitals_territory() -> void:
	var e := real_engine(1)
	var capital_territory := -1
	for c in e.zone("tableau").cards:
		if c.def.id == "capital":
			capital_territory = c.territory_uid
	var farm := put_in_hand(e, "farm")
	check(capital_territory != -1, "the Capital is on a territory")
	check(e.valid_targets(farm).has(capital_territory), "a Farm can go on the Capital's territory")


# --- Caravan trade (055) ---

func test_caravan_trades_between_at_least_2_cities() -> void:
	var r := load_real()
	var trades: Array = r.cards.caravan.effects.filter(func(e): return e.op == "trade")
	eq(trades.size(), 1, "Caravan has one trade effect")
	if trades.size() == 1:
		check(trades[0].min_cities >= 2, "Caravan needs at least 2 cities (min_cities %d)" % trades[0].min_cities)


# --- Early-game cards (backlog 080) ---

const EARLY_CARDS := ["barter", "storyteller", "fishing_huts", "quarry", "shrine"]


## The real card id, or null with a failed check when it's missing.
func real_card(r: Dictionary, id: String) -> CardDef:
	check(r.cards.has(id), "the real data has a '%s' card" % id)
	return r.cards.get(id)


## Whether def costs food only, at least 1.
func costs_food_only(def: CardDef) -> bool:
	return def.cost.keys() == [GameEngine.FOOD] and def.cost[GameEngine.FOOD] >= 1


func test_barter_trades_food_for_wealth() -> void:
	var def := real_card(load_real(), "barter")
	if def == null:
		return
	eq(def.type, CardDef.ACTION, "Barter type")
	check(costs_food_only(def), "Barter costs food only (>= 1): %s" % [def.cost])
	eq(def.effects.size(), 1, "Barter has one effect")
	if def.effects.size() == 1:
		var effect := def.effects[0]
		check(effect.op == "gain" and effect.trigger == "play" and effect.get("resource") == GameEngine.WEALTH,
			"Barter's effect is a play gain of wealth (got %s %s)" % [effect.op, effect.trigger])


func test_storyteller_draws_cards_for_food() -> void:
	var def := real_card(load_real(), "storyteller")
	if def == null:
		return
	eq(def.type, CardDef.ACTION, "Storyteller type")
	check(costs_food_only(def), "Storyteller costs food only (>= 1): %s" % [def.cost])
	eq(def.effects.size(), 1, "Storyteller has one effect")
	if def.effects.size() == 1:
		var effect := def.effects[0]
		check(effect.op == "draw" and effect.trigger == "play" and effect.get("amount") >= 2,
			"Storyteller's effect is a play draw of 2+ (got %s %s)" % [effect.op, effect.trigger])


func test_fishing_huts_quarry_and_shrine_are_early_buildings() -> void:
	var r := load_real()
	var huts := real_card(r, "fishing_huts")
	if huts != null:
		eq(huts.type, CardDef.BUILDING, "Fishing Huts type")
		eq(huts.requires, ["coastal"] as Array[String], "Fishing Huts requires")
		check(huts.effects.any(func(e): return e.op == "gain" and e.trigger == "upkeep" and e.get("resource") == GameEngine.FOOD),
			"Fishing Huts has an upkeep gain of food")
	var quarry := real_card(r, "quarry")
	if quarry != null:
		eq(quarry.type, CardDef.BUILDING, "Quarry type")
		check(not quarry.requires.is_empty() and quarry.requires.all(func(k): return k in ["hills", "mountain"]),
			"Quarry requires hills and/or mountain (got %s)" % [quarry.requires])
	var shrine := real_card(r, "shrine")
	if shrine != null:
		eq(shrine.type, CardDef.BUILDING, "Shrine type")
		eq(shrine.requires, [] as Array[String], "Shrine requires")
		check(shrine.has_tag("culture"), "Shrine is tagged culture")
		check(shrine.vp >= 1, "Shrine has printed VP (got %d)" % shrine.vp)


func test_early_cards_start_in_the_deck_or_an_open_supply_pile() -> void:
	var r := load_real()
	check(r.config.deck.get("barter", 0) >= 1, "Barter in the starting deck")
	check(r.config.deck.get("storyteller", 0) >= 1, "Storyteller in the starting deck")
	for id in ["fishing_huts", "quarry", "shrine"]:
		var pile: Dictionary = r.config.supply.get(id, {})
		check(not pile.is_empty(), "%s has a supply pile" % id)
		check(not pile.get("locked", false), "%s's pile is not locked" % id)
	for tech in techs_in_research_deck(r):
		for effect in tech.effects:
			if effect.op in ["create", "unlock"]:
				check(not EARLY_CARDS.has(effect.card_id), "%s doesn't %s early card %s" % [tech.id, effect.op, effect.card_id])


func test_every_territory_can_take_a_building_from_the_start() -> void:
	var r := load_real()
	var early: Array[CardDef] = []
	for id in r.config.deck:
		if r.cards[id].type == CardDef.BUILDING:
			early.append(r.cards[id])
	for id in r.config.supply:
		if r.cards[id].type == CardDef.BUILDING and not r.config.supply[id].get("locked", false):
			early.append(r.cards[id])
	for id in r.config.territory_deck:
		var land: CardDef = r.cards[id]
		var fits := early.filter(func(b): return b.requires.is_empty() or b.requires.any(func(k): return land.keywords.has(k)))
		check(not fits.is_empty(), "territory %s %s can take a starting-deck or open-supply building" % [id, land.keywords])


# --- Hunt (backlog 081) ---

func test_hunt_gains_food_per_keyword_and_is_available_from_the_start() -> void:
	var r := load_real()
	var hunt := real_card(r, "hunt")
	if hunt == null:
		return
	eq(hunt.type, CardDef.ACTION, "Hunt type")
	var effects := hunt.effects.filter(func(e): return e.op == "gain_per_keyword" and e.get("resource") == GameEngine.FOOD)
	eq(effects.size(), 1, "Hunt has a gain_per_keyword food effect")
	var pile: Dictionary = r.config.supply.get("hunt", {})
	check(r.config.deck.get("hunt", 0) >= 1 or (not pile.is_empty() and not pile.get("locked", false)),
		"Hunt is in the starting deck or an unlocked supply pile")
	var on_land := {}
	for id in r.config.territory_deck:
		for k in r.cards[id].keywords:
			on_land[k] = true
	for effect in effects:
		for k in effect.get("keywords"):
			check(on_land.has(k), "Hunt's keyword %s is on a territory in territory_deck" % k)


# --- Rite of Passage (backlog 082) ---

func test_rite_of_passage_trashes_and_is_on_sale() -> void:
	var r := load_real()
	var rite := real_card(r, "rite_of_passage")
	if rite == null:
		return
	eq(rite.type, CardDef.ACTION, "Rite of Passage type")
	check(rite.effects.any(func(e): return e.op == "trash"), "Rite of Passage has a trash effect")
	var pile: Dictionary = r.config.supply.get("rite_of_passage", {})
	check(not pile.is_empty() and not pile.get("locked", false), "Rite of Passage is in an unlocked supply pile")
