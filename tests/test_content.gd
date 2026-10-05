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


# --- Terrains and features (131) ---

## The territory types in play: the starting territory and every territory_deck entry.
func territories_in_play(r: Dictionary) -> Array[String]:
	var out: Array[String] = [r.config.starting.territory]
	for id in r.config.territory_deck:
		if not out.has(id):
			out.append(id)
	return out


func test_real_config_names_at_least_5_terrains() -> void:
	var terrains: Array = load_real().config.get("terrains", [])
	check(terrains.size() >= 5, "config names %d terrains (need >= 5): %s" % [terrains.size(), terrains])


func test_every_keyword_is_on_at_least_2_territory_types() -> void:
	var r := load_real()
	var types := {}
	for id in territories_in_play(r):
		for k in r.cards[id].keywords:
			types[k] = types.get(k, 0) + 1
	var thin: Array[String] = []
	for k in r.config.keywords:
		if types.get(k, 0) < 2:
			thin.append("%s (%d)" % [k, types.get(k, 0)])
	eq(thin, [] as Array[String], "keywords on fewer than 2 territory types in play")


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


# --- Growth cards (262) ---

## The action cards among ids whose effects include a grow op that ok accepts.
func growth_actions(r: Dictionary, ids: Array, ok: Callable) -> Array:
	return ids.filter(func(id): return r.cards[id].type == CardDef.ACTION \
		and r.cards[id].effects.any(func(effect): return effect.op == "grow" and ok.call(effect)))


func test_the_deck_and_supply_hold_both_kinds_of_growth_action() -> void:
	var r := load_real()
	var best := func(effect): return effect.where == "best"
	var counted := func(effect): return effect.where == "each" and effect.count > 0
	var deck: Array = r.config.deck.keys()
	var supply: Array = r.config.get("supply", {}).keys()
	check(not growth_actions(r, deck, best).is_empty(), "the starting deck has a 'best' growth action")
	check(not growth_actions(r, supply, best).is_empty(), "the supply has a 'best' growth action")
	check(not growth_actions(r, supply, counted).is_empty(), "the supply has an 'each' growth action with a count")


func test_every_growth_card_costs_food() -> void:
	var r := load_real()
	var ids: Array = r.config.deck.keys() + r.config.get("supply", {}).keys()
	var growth := growth_actions(r, ids, func(_effect): return true)
	check(not growth.is_empty(), "the deck and supply have growth cards")
	for id in growth:
		check(r.cards[id].cost.get(GameEngine.FOOD, 0) > 0, "%s costs food" % id)


# --- Starter events (backlog 069) ---

## The ops a real event may use: they only give (see 072 for harmful ops).
const EVENT_OPS: Array[String] = ["gain", "gain_per_tag", "score", "grow"]  # and lose of unrest (144)


func test_every_real_event_is_in_the_event_deck() -> void:
	var r := load_real()
	check(not r.config.get("event_deck", {}).is_empty(), "the real event deck is not empty")
	var unused: Array[String] = []
	for id in r.cards:
		if id == r.config.famine.get("card", ""):  # 083: the Famine comes from hunger, never from the deck
			continue
		if id == r.config.get("unrest", {}).get("anarchy", ""):  # 253: Anarchy comes from unrest, never from the deck
			continue
		if r.cards[id].type == CardDef.EVENT and not r.config.get("event_deck", {}).has(id):
			unused.append(id)
	eq(unused, [] as Array[String], "events not in event_deck")


## Backlog 144: gaining unrest is the only harm an event deals; an event may also calm it (lose unrest). A raid's
## repel and pillage effects are exempt (162): announced a turn ahead, its harm can be answered.
func test_real_events_harm_only_by_unrest() -> void:
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
			if Effect.RAID_TRIGGERS.has(effect.trigger):
				continue
			if not EVENT_OPS.has(effect.op) and not (effect.op == "lose" and effect.get("resource") == "unrest"):
				bad_ops.append("%s: %s" % [id, effect.op])
	eq(bad_ops, [] as Array[String], "event effects that aren't gain, gain_per_tag, score, grow or lose of unrest")
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


## Backlog 107 (was at least 3, 064): six ancient civilizations, all different, the default among them.
func test_real_config_lists_at_least_6_different_civilizations() -> void:
	var r := load_real()
	var civs: Array = r.config.get("civilizations", [])
	check(civs.size() >= 6, "at least 6 civilizations (got %s)" % [civs])
	check(civs.has(r.config.starting.civilization), "starting.civilization %s is listed" % r.config.starting.civilization)
	var seen := {}  # effect text -> civilization id
	for id in civs:
		var def: CardDef = r.cards[id]
		check(not def.effects.is_empty(), "%s has an effect" % id)
		var text := def.rules_tooltip(r.cards)
		check(not seen.has(text), "%s has the same effects as %s" % [id, seen.get(text, "")])
		seen[text] = id


## Backlog 107: every offered civilization has a flavor paragraph and a quote with its source.
func test_every_listed_civilization_has_flavor_and_a_quote() -> void:
	var r := load_real()
	for id in r.config.get("civilizations", []):
		var def: CardDef = r.cards[id]
		check(def.flavor != "", "%s has flavor" % id)
		check(def.quote_text != "" and def.quote_by != "", "%s has a quote and its source" % id)


## Backlog 248: every offered civilization names its cities: at least 8 distinct, non-empty city names.
func test_every_listed_civilization_has_at_least_8_city_names() -> void:
	var r := load_real()
	for id in r.config.get("civilizations", []):
		var def: CardDef = r.cards[id]
		check(def.get("city_names") != null and def.city_names.size() >= 8, "%s has at least 8 city names" % id)


## Backlog 107: no civilization card is left in the data without being offered.
func test_every_civilization_card_is_listed() -> void:
	var r := load_real()
	var civs: Array = r.config.get("civilizations", [])
	for id in r.cards:
		if r.cards[id].type == CardDef.CIVILIZATION:
			check(civs.has(id), "civilization %s is listed in config civilizations" % id)


## Card ids the player can get without a civilization: the starting deck, the supply, and what techs create.
func obtainable_cards(r: Dictionary) -> Dictionary:
	var out := {}
	for id in r.config.deck:
		out[id] = true
	for id in r.config.get("supply", {}):
		out[id] = true
	for tech in techs_in_research_deck(r):
		for id in created_by(tech):
			out[id] = true
	return out


## Backlog 107: a civilization's start gift is a card for the discard that the game also hands out otherwise; since 133
## a building may instead start on the home (a create into the tableau).
func test_civilization_start_gifts_are_obtainable_cards_in_the_discard() -> void:
	var r := load_real()
	var obtainable := obtainable_cards(r)
	var gifts := 0
	for id in r.config.get("civilizations", []):
		for effect in r.cards[id].effects:
			if effect.op == "create" and effect.trigger == "start":
				gifts += 1
				var on_home: bool = effect.zone == "tableau" and r.cards[effect.card_id].type == CardDef.BUILDING
				check(effect.zone == "discard" or on_home,
					"%s puts %s into the discard, or a building on its home (got %s)" % [id, effect.card_id, effect.zone])
				check(obtainable.has(effect.card_id), "%s gives %s, which the game also hands out" % [id, effect.card_id])
	check(gifts > 0, "some civilization starts with a card")


## Backlog 107: a game starts as each listed civilization.
func test_every_listed_civilization_has_its_own_home_that_takes_most_starting_buildings() -> void:
	var r := load_real()
	var buildings: Array[CardDef] = []
	var copies := 0
	for id in r.config.deck:
		if r.cards[id].type == CardDef.BUILDING:
			buildings.append(r.cards[id])
			copies += r.config.deck[id]
	var homes := {}
	for civ in r.config.civilizations:
		var home: String = r.cards[civ].home
		check(home != "", "%s has a home" % civ)
		if home == "":
			continue
		check(not homes.has(home), "%s's home %s is also %s's" % [civ, home, homes.get(home, "")])
		homes[home] = civ
		var land: CardDef = r.cards[home]
		var fit := 0
		for b in buildings:
			if b.requires.is_empty() or b.requires.any(func(k): return land.keywords.has(k)):
				fit += r.config.deck[b.id]
		check(fit * 2 > copies, "%s's home %s takes %d of %d starting building copies" % [civ, home, fit, copies])


func test_a_new_game_starts_as_each_listed_civilization() -> void:
	var r := load_real()
	for id in r.config.get("civilizations", []):
		var e := GameEngine.new(r.cards, r.config)
		eq(e.new_game_error(id), "", "%s is playable" % id)
		e.new_game(3, id)
		var z := e.zone("civilization")
		eq(z.cards.map(func(c): return c.def.id), [id], "playing as %s" % id)


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


## Backlog 143: a prereq never sits in a later era than the tech that needs it.
func test_every_tech_prereq_is_in_the_same_era_or_an_earlier_one() -> void:
	var r := load_real()
	for tech in techs_in_research_deck(r):
		if tech.prereq != "" and r.cards.has(tech.prereq):
			var prereq: CardDef = r.cards[tech.prereq]
			check(prereq.era <= tech.era, "%s (era %d) needs %s from era %d" % [tech.id, tech.era, prereq.id, prereq.era])


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


## Backlog 160: every unit can be had, from a supply pile or a tech that creates it; the data has some.
func test_every_unit_has_a_supply_pile_or_a_tech_that_creates_it() -> void:
	var r := load_real()
	var from_techs := {}
	for tech in techs_in_research_deck(r):
		for id in created_by(tech):
			from_techs[id] = true
	var units := 0
	for id in r.cards:
		if r.cards[id].type == CardDef.UNIT:
			units += 1
			check(r.config.supply.has(id) or from_techs.has(id), "%s has a supply pile or a tech creates it" % id)
	check(units > 0, "the real data has units")


## Backlog 065: the game starts with a government, and every other government comes from a researchable tech (but
## the config's unrest.anarchy, 145).
func test_starting_government_and_every_other_government_comes_from_a_tech() -> void:
	var r := load_real()
	var start: String = r.config.starting.government
	check(start != "", "config has a starting.government")
	var given := {}
	for tech in techs_in_research_deck(r):
		for id in created_by(tech):
			given[id] = true
	var others := 0
	var anarchy: String = r.config.get("unrest", {}).get("anarchy", "")  # 145: the rule creates it, no tech
	for id in r.cards:
		if r.cards[id].type == CardDef.GOVERNMENT and id != start and id != anarchy:
			others += 1
			check(given.has(id), "a tech in research_deck creates government %s" % id)
	check(others >= 2, "at least 2 governments besides the starting one (got %d)" % others)


## 127: actions per turn come from the government, so every government sets them.
func test_every_government_sets_actions() -> void:
	var r := load_real()
	for id in r.cards:
		if r.cards[id].type == CardDef.GOVERNMENT:
			check(r.cards[id].get("actions") > 0, "government %s sets actions" % id)


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
	for id in r.config.territory_deck:
		for option in Territories.resource_table(r.config, r.cards[id]):
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
	for id in r.config.territory_deck:
		for option in Territories.resource_table(r.config, r.cards[id]):
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


## Card ids that can reach a game: the starting deck, tableau, territory, civilizations and government, the supply,
## the territory, event and research decks, the config's unrest.anarchy (145), and every card those
## cards' effects create or settle.
func reachable_cards(r: Dictionary) -> Dictionary:
	var start: Array = [r.config.starting.territory, r.config.starting.government]
	start.append(r.config.get("unrest", {}).get("anarchy", ""))
	start += r.config.starting.tableau + r.config.get("civilizations", [])
	for key in ["deck", "supply", "territory_deck", "event_deck", "research_deck"]:
		start += r.config.get(key, {}).keys()
	var out := {}
	while not start.is_empty():
		var id: String = start.pop_back()
		if out.has(id) or not r.cards.has(id):
			continue
		out[id] = true
		for effect in r.cards[id].effects:
			start += effect.referenced_cards()
	return out


## Backlog 132: removing a card from the deck can't leave its definition behind (techs past the research deck and the
## Famine, which hunger brings, aside).
func test_every_real_card_can_reach_a_game() -> void:
	var r := load_real()
	var reachable := reachable_cards(r)
	var orphans: Array[String] = []
	for id in r.cards:
		if r.cards[id].type != CardDef.TECH and id != r.config.famine.get("card", "") and not reachable.has(id):
			orphans.append(id)
	eq(orphans, [] as Array[String], "cards nothing puts into a game")


## Backlog 132: every tag a gain_per_tag counts is on a card that can reach a game.
func test_every_gain_per_tag_tag_is_on_a_reachable_card() -> void:
	var r := load_real()
	var reachable := reachable_cards(r)
	var tags := {}
	for id in reachable:
		for tag in r.cards[id].tags:
			tags[tag] = true
	var missing: Array[String] = []
	for id in reachable:
		for effect in r.cards[id].effects:
			if effect.op == "gain_per_tag" and not tags.has(effect.get("tag")):
				missing.append("%s: %s" % [id, effect.get("tag")])
	eq(missing, [] as Array[String], "gain_per_tag tags no reachable card carries")


## Backlog 143: a eureka only counts cards the player can get: its card can reach a game, its tag is on such a card.
func test_every_eureka_counts_cards_the_player_can_get() -> void:
	var r := load_real()
	var reachable := reachable_cards(r)
	var tags := {}
	for id in reachable:
		for tag in r.cards[id].tags:
			tags[tag] = true
	var missing: Array[String] = []
	for tech in techs_in_research_deck(r):
		var eureka: Dictionary = tech.eureka
		if eureka.has("card") and not reachable.has(eureka.card):
			missing.append("%s: card %s" % [tech.id, eureka.card])
		if eureka.has("tag") and not tags.has(eureka.tag):
			missing.append("%s: tag %s" % [tech.id, eureka.tag])
	eq(missing, [] as Array[String], "eurekas no card the player can get satisfies")



func test_the_anarchy_event_has_flavor_and_a_quote() -> void:
	var anarchy: String = Game.engine.config.get("unrest", {}).get("anarchy", "")
	check(anarchy != "", "the config names an Anarchy event")
	if anarchy != "":
		var def: CardDef = Game.engine.card_db[anarchy]
		check(def.flavor != "", "Anarchy has flavor (205: the revolution's confirmation shows it)")
		check(def.quote_text != "" and def.quote_by != "", "and a quote")


## Backlog 215: every tech has a flavor line and a quote with its source, and every event a flavor line.
func test_every_tech_has_flavor_and_a_quote_and_every_event_flavor() -> void:
	var r := load_real()
	for def: CardDef in r.cards.values():
		if def.type in [CardDef.TECH, CardDef.EVENT]:
			check(def.flavor != "", "%s has flavor" % def.id)
		if def.type == CardDef.TECH:
			check(def.quote_text != "" and def.quote_by != "", "%s has a quote and its source" % def.id)
