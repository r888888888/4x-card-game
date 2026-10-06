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


# --- Military from turn 1 (285; recruited from the build menu since 296) ---

## Backlog 296 (replaces 285's "the starting deck holds a military unit" and 160's "every unit has a supply pile or a
## tech that creates it"): units are recruited from the build menu, never dealt or bought, and every unit has an entry.
func test_units_are_in_the_build_menu_not_the_deck_or_supply() -> void:
	var r := load_real()
	var menu: Dictionary = r.config.get("build_menu", {})
	var units := 0
	for id in r.cards:
		if r.cards[id].type == CardDef.UNIT:
			units += 1
			check(not r.config.deck.has(id) and not r.config.supply.has(id), "%s isn't in the deck or supply" % id)
			check(menu.has(id), "%s has a build-menu entry" % id)
	check(units > 0, "the real data has units")


## Backlog 296 (replaces 285's "a new game deals a military unit"): the early raids have an answer: on turn 1 a
## military unit can be recruited on the home with the starting resources.
func test_a_military_unit_can_be_recruited_on_turn_1() -> void:
	var e := real_engine(5)
	var home := home_uid(e)
	var recruitable: Array = e.build_menu().filter(func(id): return e.card_db[id].type == CardDef.UNIT \
		and e.card_db[id].has_tag("military") and e.build_error(id, home) == "")
	check(not recruitable.is_empty(), "a military unit can be recruited on turn 1 (menu %s)" % [e.build_menu()])


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


## Backlog 144: gaining unrest is the only harm an era-1 event deals; an event may also calm it (lose unrest). A raid's
## repel and pillage effects are exempt (162): announced a turn ahead, its harm can be answered. Harsher harm arrives
## with the later eras (270).
func test_real_era_1_events_harm_only_by_unrest() -> void:
	var r := load_real()
	var blank := 0
	var active := 0
	var bad_ops: Array[String] = []
	for id in r.config.get("event_deck", {}):
		var def: CardDef = r.cards[id]
		if def.era != 1:
			continue
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


# --- Era-1 unrest cap (backlog 267) ---

## The most unrest the event def can add (267): its play gains, plus its upkeep gains times its turns, plus for a raid
## the larger of what its pillage and its repel effects gain, plus for a choice event the option that gains most (269).
func unrest_added(def: CardDef) -> int:
	var by_trigger := {}
	for effect in def.effects:
		if effect.op == "gain" and effect.get("resource") == "unrest":
			by_trigger[effect.trigger] = by_trigger.get(effect.trigger, 0) + effect.get("amount")
	var most_by_option := 0
	for option in def.choices:
		var n := 0
		for effect in option.effects:
			if effect.op == "gain" and effect.get("resource") == "unrest":
				n += effect.get("amount")
		most_by_option = maxi(most_by_option, n)
	return by_trigger.get("play", 0) + by_trigger.get("upkeep", 0) * def.discard_turns \
		+ maxi(by_trigger.get("pillage", 0), by_trigger.get("repel", 0)) + most_by_option


func test_no_era_1_event_adds_more_than_1_unrest() -> void:
	var r := load_real()
	var over: Array[String] = []
	var adding := 0
	for id in r.config.get("event_deck", {}):
		var def: CardDef = r.cards[id]
		if def.era != 1:
			continue
		var n := unrest_added(def)
		if n > 0:
			adding += 1
		if n > 1:
			over.append("%s: +%d" % [id, n])
	eq(over, [] as Array[String], "era-1 events that add more than 1 unrest")
	check(adding >= 1, "some era-1 event still adds unrest")


func test_every_event_era_can_be_reached() -> void:
	var r := load_real()
	var reachable := {1: true}
	for tech in techs_in_research_deck(r):
		for effect in tech.effects:
			if effect.op == "add_era":
				reachable[effect.era] = true
	for era in r.config.era_unlocks:
		reachable[era] = true
	for id in r.config.get("event_deck", {}):
		var era: int = r.cards[id].era
		check(reachable.has(era), "%s is an era-%d event, but nothing adds era %d" % [id, era, era])



# --- Era 2 and 3 events (backlog 270) ---

## The ops that take food, wealth or insight from the realm, flat or scaled (268).
const LOSS_OPS: Array[String] = ["lose", "lose_pct", "lose_per_keyword"]
## The ops that give a resource.
const GAIN_OPS: Array[String] = ["gain", "gain_per_tag", "gain_per_keyword"]
## The ops whose amount scales with the realm.
const SCALING_OPS: Array[String] = ["gain_per_tag", "gain_per_keyword", "lose_per_keyword", "lose_pct"]
## The modifiers that change the turn itself; their sign says whether an event helps or harms.
const TURN_MODIFIERS: Array[String] = [Modifiers.ACTIONS, Modifiers.HAND_SIZE]


## Every effect on an event: its own (any trigger, raids' included) and each choice option's (269).
func event_effects(def: CardDef) -> Array:
	var out: Array = def.effects.duplicate()
	for option in def.choices:
		out.append_array(option.effects)
	return out


## Era -> the event defs of that era in event_deck.
func events_by_era(r: Dictionary) -> Dictionary:
	var out := {}
	for id in r.config.get("event_deck", {}):
		var def: CardDef = r.cards[id]
		if not out.has(def.era):
			out[def.era] = []
		out[def.era].append(def)
	return out


## The eras the game can reach: those of the techs in research_deck and those they add.
func research_eras(r: Dictionary) -> Array[int]:
	var eras: Array[int] = []
	for tech in techs_in_research_deck(r):
		var reached := [tech.era]
		for effect in tech.effects:
			if effect.op == "add_era":
				reached.append(effect.era)
		for era in reached:
			if not eras.has(era):
				eras.append(era)
	eras.sort()
	return eras


func harms(def: CardDef) -> bool:
	for effect in event_effects(def):
		var resource: Variant = effect.get("resource")
		if effect.op == "gain" and resource == GameEngine.UNREST:
			return true
		if LOSS_OPS.has(effect.op) and resource != GameEngine.UNREST:
			return true
		if effect.op == "lose_pop":
			return true
	return TURN_MODIFIERS.any(func(k): return def.modifiers.get(k, 0) < 0)


func helps(def: CardDef) -> bool:
	for effect in event_effects(def):
		if GAIN_OPS.has(effect.op) and effect.get("resource") != GameEngine.UNREST:
			return true
		if effect.op == "score" or effect.op == "grow":
			return true
	return TURN_MODIFIERS.any(func(k): return def.modifiers.get(k, 0) > 0)


func test_every_era_the_research_deck_reaches_has_events() -> void:
	var r := load_real()
	var by_era := events_by_era(r)
	var missing: Array[int] = []
	for era in research_eras(r):
		if not by_era.has(era):
			missing.append(era)
	eq(missing, [] as Array[int], "eras the research deck reaches with no event in event_deck")


func test_every_later_era_has_a_harmful_and_a_helpful_event() -> void:
	var r := load_real()
	var by_era := events_by_era(r)
	for era in research_eras(r):
		if era < 2:
			continue
		var defs: Array = by_era.get(era, [])
		check(defs.any(harms), "era %d has a harmful event" % era)
		check(defs.any(helps), "era %d has a helpful event" % era)


func test_every_later_era_has_an_event_that_scales_with_the_realm() -> void:
	var r := load_real()
	var by_era := events_by_era(r)
	for era in research_eras(r):
		if era < 2:
			continue
		var scales := (by_era.get(era, []) as Array).any(func(def):
			return event_effects(def).any(func(effect): return SCALING_OPS.has(effect.op)))
		check(scales, "era %d has an event that scales with the realm (%s)" % [era, ", ".join(SCALING_OPS)])


func test_every_per_keyword_and_per_tag_event_effect_can_fire() -> void:
	var r := load_real()
	var keywords := keywords_in_play(r)
	var tagged: Array = r.config.deck.keys() + r.config.supply.keys()
	for id in r.cards:
		for effect in r.cards[id].effects:
			if effect.op == "create":
				tagged.append(effect.card_id)
	var tags := {}
	for id in tagged:
		for tag in r.cards[id].tags:
			tags[tag] = true
	var dead: Array[String] = []
	for id in r.config.get("event_deck", {}):
		for effect in event_effects(r.cards[id]):
			if effect.op == "gain_per_keyword" or effect.op == "lose_per_keyword":
				for k in effect.get("keywords"):
					if not keywords.has(k):
						dead.append("%s: keyword %s" % [id, k])
			if effect.op == "gain_per_tag" and not tags.has(effect.get("tag")):
				dead.append("%s: tag %s" % [id, effect.get("tag")])
	eq(dead, [] as Array[String], "event effects that count a keyword or tag nothing in play has")


func test_events_both_give_and_take_food_wealth_and_insight() -> void:
	var r := load_real()
	var gained := {}
	var lost := {}
	for id in r.config.get("event_deck", {}):
		for effect in event_effects(r.cards[id]):
			if GAIN_OPS.has(effect.op):
				gained[effect.get("resource")] = true
			if LOSS_OPS.has(effect.op):
				lost[effect.get("resource")] = true
	for resource in [GameEngine.FOOD, GameEngine.WEALTH, GameEngine.INSIGHT]:
		check(gained.has(resource), "some event gains %s" % resource)
		check(lost.has(resource), "some event takes %s" % resource)


func test_the_most_unrest_an_event_adds_never_falls_from_one_era_to_the_next() -> void:
	var r := load_real()
	var by_era := events_by_era(r)
	var most := {}
	for era in by_era:
		for def in by_era[era]:
			most[era] = maxi(most.get(era, 0), unrest_added(def))
	for era in research_eras(r):
		if era < 2:
			continue
		check(most.get(era, 0) >= most.get(era - 1, 0), "era %d's events add at most +%d unrest, era %d's +%d"
			% [era, most.get(era, 0), era - 1, most.get(era - 1, 0)])

# --- Wealth content (backlog 022) ---

## Whether any effect on def produces wealth (gain or gain_per_tag with resource "wealth").
func makes_wealth(def: CardDef) -> bool:
	for effect in def.effects:
		if effect.get("resource") == "wealth":
			return true
	return false


## Since 295 what costs wealth from the start may be an open build-menu entry rather than a deck card.
func test_real_deck_has_wealth_costs_and_the_starting_tableau_makes_wealth() -> void:
	var r := load_real()
	var costs_wealth := 0
	for id in r.config.deck.keys() + open_entries(r):
		if r.cards[id].cost.get("wealth", 0) > 0:
			costs_wealth += 1
	check(costs_wealth >= 1, "at least 1 deck card or open build-menu entry costs wealth (got %d)" % costs_wealth)
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


## Backlog 263: a building holds a slot and a worker for good, so it gives something that lasts too: printed VP, an
## upkeep effect, or a standing field. Scoring once on play isn't enough.
func test_every_building_gives_something_lasting() -> void:
	var r := load_real()
	var fleeting: Array[String] = []
	for def in real_buildings(r):
		var lasting := def.vp >= 1 or not def.modifiers.is_empty() or def.housing > 0 or def.famine_guard > 0 \
				or def.defense > 0 or def.training > 0 or def.effects.any(func(e): return e.trigger == "upkeep")
		if not lasting:
			fleeting.append(def.id)
	eq(fleeting, [] as Array[String], "buildings that give nothing lasting")


## Backlog 295 (replaces 263's every starting-deck building has a supply pile): buildings are built from the build
## menu, never dealt or bought, and every building has an entry.
func test_buildings_are_in_the_build_menu_not_the_deck_or_supply() -> void:
	var r := load_real()
	var menu: Dictionary = r.config.get("build_menu", {})
	var dealt: Array[String] = []
	var missing: Array[String] = []
	for def in real_buildings(r):
		if r.config.deck.has(def.id) or r.config.supply.has(def.id):
			dealt.append(def.id)
		if not menu.has(def.id):
			missing.append(def.id)
	eq(dealt, [] as Array[String], "buildings in the deck or supply")
	eq(missing, [] as Array[String], "buildings with no build-menu entry")


## Backlog 295: a locked entry opens through a tech, and every building a tech unlocks is a locked entry.
func test_every_locked_build_menu_entry_is_unlocked_by_a_tech_and_back() -> void:
	var r := load_real()
	var menu: Dictionary = r.config.get("build_menu", {})
	var opened := {}
	for tech in techs_in_research_deck(r):
		for id in unlocked_by(tech):
			opened[id] = true
			if r.cards[id].type == CardDef.BUILDING:
				check(menu.get(id, {}).get("locked", false), "%s (from %s) is a locked build-menu entry" % [id, tech.id])
	for id in menu:
		if menu[id].locked:
			check(opened.has(id), "locked entry %s is unlocked by a tech in research_deck" % id)
	check(not menu.is_empty(), "the real config has a build menu")


## Backlog 305: the real buildings with upgrade_of, checked to be there so the upgrade invariants aren't empty.
func real_upgrades(r: Dictionary) -> Array[CardDef]:
	var out := real_buildings(r).filter(func(def: CardDef) -> bool: return def.is_upgrade())
	check(not out.is_empty(), "the real data has building upgrades")
	return out


## Backlog 305: the era a build-menu entry opens in: 1 if it is open from turn 1, else the lowest era of a research-deck
## tech that unlocks it (0 if none does).
func entry_era(r: Dictionary, id: String) -> int:
	if not r.config.get("build_menu", {}).get(id, {}).get("locked", false):
		return 1
	var era := 0
	for tech in techs_in_research_deck(r):
		if unlocked_by(tech).has(id):
			era = tech.era if era == 0 else mini(era, tech.era)
	return era


## Backlog 305: the keyword sets a territory a game can hold may have (the starting territory, the territory deck and
## every listed civilization's home): its printed keywords, alone and with each resource it may roll.
func land_keyword_sets(r: Dictionary) -> Array:
	var ids: Array = [r.config.starting.territory] + r.config.territory_deck.keys()
	for civ in r.config.get("civilizations", []):
		if r.cards[civ].home != "":
			ids.append(r.cards[civ].home)
	var out := []
	for id in ids:
		var land: CardDef = r.cards[id]
		out.append(land.keywords)
		for option in Territories.resource_table(r.config, land):
			out.append(land.keywords + option.keywords)
	return out


## Whether a territory with keywords meets requires (any of them; an empty list meets anything).
func meets(keywords: Array, requires: Array) -> bool:
	return requires.is_empty() or requires.any(func(k): return keywords.has(k))


## Backlog 305: an upgrade and its base are both built from the build menu, and a locked upgrade opens through a tech.
func test_every_upgrade_and_its_base_are_build_menu_entries_opened_by_a_tech() -> void:
	var r := load_real()
	var menu: Dictionary = r.config.get("build_menu", {})
	for def in real_upgrades(r):
		check(menu.has(def.id), "upgrade %s is a build-menu entry" % def.id)
		check(menu.has(def.upgrade_of), "%s's base %s is a build-menu entry" % [def.id, def.upgrade_of])
		if menu.get(def.id, {}).get("locked", false):
			check(entry_era(r, def.id) > 0, "locked upgrade %s is unlocked by a tech in research_deck" % def.id)


## Backlog 305: some territory a game can hold meets both an upgrade's base's requires and its own.
func test_every_upgrade_can_stand_on_some_territory() -> void:
	var r := load_real()
	var lands := land_keyword_sets(r)
	var homeless: Array[String] = []
	for def in real_upgrades(r):
		var base: CardDef = r.cards[def.upgrade_of]
		if not lands.any(func(k: Array) -> bool: return meets(k, base.requires) and meets(k, def.requires)):
			homeless.append("%s %s on %s %s" % [def.id, def.requires, base.id, base.requires])
	eq(homeless, [] as Array[String], "upgrades no territory can hold together with their base")


## Backlog 305: an upgrade never opens in an earlier era than the building it goes on.
func test_no_upgrade_opens_before_its_base() -> void:
	var r := load_real()
	var early: Array[String] = []
	for def in real_upgrades(r):
		var era := entry_era(r, def.id)
		var base_era := entry_era(r, def.upgrade_of)
		if era < base_era:
			early.append("%s (era %d) on %s (era %d)" % [def.id, era, def.upgrade_of, base_era])
	eq(early, [] as Array[String], "upgrades that open before their base")


## Backlog 305: restructuring buildings into upgrades leaves every terrain a building of its own that isn't an upgrade:
## one whose requires names it.
func test_every_terrain_keeps_a_building_that_is_not_an_upgrade() -> void:
	var r := load_real()
	var reachable := reachable_cards(r)
	var missing: Array[String] = []
	for terrain in r.config.terrains:
		if not real_buildings(r).any(func(def: CardDef) -> bool:
				return reachable.has(def.id) and not def.is_upgrade() and def.requires.has(terrain)):
			missing.append(terrain)
	eq(missing, [] as Array[String], "terrains whose only buildings are upgrades")


## Backlog 295: a wonder is built once a game.
func test_every_wonder_is_a_once_entry() -> void:
	var r := load_real()
	for def in real_wonders(r):
		check(r.config.get("build_menu", {}).get(def.id, {}).get("once", false), "%s is a once entry" % def.id)


## Backlog 295: techs open buildings rather than hand them out; only a start gift may put one straight into play.
func test_no_tech_creates_a_building_outside_the_tableau() -> void:
	var r := load_real()
	for tech in techs_in_research_deck(r):
		for effect in tech.effects:
			if effect.op == "create" and r.cards[effect.card_id].type == CardDef.BUILDING:
				eq(effect.zone, "tableau", "%s creates %s into" % [tech.id, effect.card_id])


## The build menu's entries open from turn 1 (295).
func open_entries(r: Dictionary) -> Array[String]:
	var out: Array[String] = []
	var menu: Dictionary = r.config.get("build_menu", {})
	for id in menu:
		if not menu[id].locked:
			out.append(id)
	return out


## Card ids a tech's unlock effects open a supply pile or build-menu entry for.
func unlocked_by(tech: CardDef) -> Array[String]:
	var out: Array[String] = []
	for effect in tech.effects:
		if effect.op == "unlock":
			out.append(effect.card_id)
	return out


## Backlog 264: building ids the player can get in era 1: the starting deck, an open supply pile or build-menu entry
## (295), or a card an era-1 tech in the research deck creates or unlocks.
func era_1_building_ids(r: Dictionary) -> Dictionary:
	var ids: Array = r.config.deck.keys() + open_entries(r)
	for id in r.config.supply:
		if not r.config.supply[id].get("locked", false):
			ids.append(id)
	for tech in techs_in_research_deck(r):
		if tech.era == 1:
			ids += created_by(tech) + unlocked_by(tech)
	var out := {}
	for id in ids:
		if r.cards[id].type == CardDef.BUILDING:
			out[id] = true
	return out


## Backlog 264: insight has a building from the first era, not only the Capital and Research cards.
func test_a_building_making_insight_is_obtainable_in_era_1() -> void:
	var r := load_real()
	var makers: Array[String] = []
	for id in era_1_building_ids(r):
		if r.cards[id].effects.any(func(e): return e.trigger == "upkeep" and e.get("resource") == GameEngine.INSIGHT):
			makers.append(id)
	check(not makers.is_empty(), "an era-1 building makes insight each upkeep (era-1 buildings: %s)" % [era_1_building_ids(r).keys()])


## Backlog 264: every terrain has a building of its own: one whose requires names it.
func test_every_terrain_is_required_by_a_reachable_building() -> void:
	var r := load_real()
	var reachable := reachable_cards(r)
	var required := {}
	for def in real_buildings(r):
		if reachable.has(def.id):
			for k in def.requires:
				required[k] = true
	var missing: Array[String] = []
	for terrain in r.config.terrains:
		if not required.has(terrain):
			missing.append(terrain)
	eq(missing, [] as Array[String], "terrains no reachable building requires")


## Backlog 264: every researchable era opens a building no earlier era's tech opened.
func test_every_era_unlocks_a_new_building() -> void:
	var r := load_real()
	var first_era := {}  # building id -> lowest era of a tech that unlocks it
	for tech in techs_in_research_deck(r):
		for id in unlocked_by(tech):
			if r.cards[id].type == CardDef.BUILDING:
				first_era[id] = mini(first_era.get(id, tech.era), tech.era)
	var missing: Array[int] = []
	for era in [1, 2, 3]:
		var opens_new := false
		for tech in techs_in_research_deck(r):
			if tech.era == era and unlocked_by(tech).any(func(id): return first_era.get(id, 0) == era):
				opens_new = true
		if not opens_new:
			missing.append(era)
	eq(missing, [] as Array[int], "eras with no tech unlocking a building first")


## Backlog 264: housing and calm each have several buildings, not just the Granary and the Temple.
func test_several_buildings_add_housing_and_calm_unrest() -> void:
	var r := load_real()
	var reachable := reachable_cards(r)
	var housing: Array[String] = []
	var calming: Array[String] = []
	for def in real_buildings(r):
		if not reachable.has(def.id) or def.has_tag("wonder"):
			continue
		if def.housing > 0:
			housing.append(def.id)
		if def.effects.any(func(e): return e.trigger == "upkeep" and e.op == "lose" and e.get("resource") == GameEngine.UNREST):
			calming.append(def.id)
	check(housing.size() >= 3, "at least 3 buildings add housing (got %s)" % [housing])
	check(calming.size() >= 3, "at least 3 buildings lose unrest each upkeep (got %s)" % [calming])


# --- Wonders (backlog 265) ---

func real_wonders(r: Dictionary) -> Array[CardDef]:
	return real_buildings(r).filter(func(def): return def.has_tag("wonder"))


func test_eras_1_and_2_each_have_2_wonders_from_their_techs() -> void:
	var r := load_real()
	var per_era := {1: [], 2: []}
	for tech in techs_in_research_deck(r):
		if per_era.has(tech.era):
			for id in unlocked_by(tech):  # 295: unlocked, was created
				if r.cards[id].has_tag("wonder"):
					per_era[tech.era].append(id)
	for era in per_era:
		check(per_era[era].size() >= 2, "era %d techs unlock at least 2 wonders (got %s)" % [era, per_era[era]])


func test_every_wonder_comes_only_from_one_tech() -> void:
	var r := load_real()
	for def in real_wonders(r):
		var creators := techs_in_research_deck(r).filter(func(t): return unlocked_by(t).has(def.id))  # 295: was create
		eq(creators.size(), 1, "techs that unlock %s" % def.id)
		check(not r.config.supply.has(def.id), "%s has no supply pile" % def.id)
		check(not r.config.deck.has(def.id), "%s isn't in the starting deck" % def.id)


func test_every_wonder_outcosts_and_outscores_every_other_building() -> void:
	var r := load_real()
	var top_cost := 0
	var top_vp := 0
	for def in real_buildings(r):
		if not def.has_tag("wonder"):
			top_cost = maxi(top_cost, def.cost.get(GameEngine.WEALTH, 0))
			top_vp = maxi(top_vp, def.vp)
	for def in real_wonders(r):
		check(def.cost.get(GameEngine.WEALTH, 0) > top_cost, "%s costs more than %d wealth" % [def.id, top_cost])
		check(def.vp > top_vp, "%s prints more than %d VP" % [def.id, top_vp])


func test_every_wonder_counts_as_culture() -> void:
	var r := load_real()
	var missing: Array[String] = []
	for def in real_wonders(r):
		if not def.has_tag("culture"):
			missing.append(def.id)
	eq(missing, [] as Array[String], "wonders without the culture tag")


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


## Backlog 295 (replaces "starting resources afford a starting-deck building"): on turn 1 each listed civilization can
## build some open entry on its home with what it starts with.
func test_every_civilization_can_build_on_its_home_on_turn_1() -> void:
	var r := load_real()
	var start: Dictionary = r.config.starting.get("resources", {})
	check(start.get(GameEngine.WEALTH, 0) >= 1, "start with at least 1 wealth (got %d)" % start.get(GameEngine.WEALTH, 0))
	for civ in r.config.civilizations:
		var e := GameEngine.new(r.cards, r.config)
		e.new_game(1, civ)
		var home := home_uid(e)
		var buildable: Array = e.build_menu().filter(func(id): return e.build_error(id, home) == "")
		check(not buildable.is_empty(), "%s can build nothing on its home on turn 1 (menu %s)" % [civ, e.build_menu()])


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


## Card ids the player can get without a civilization: the starting deck, the supply, the build menu (295), and what
## techs create.
func obtainable_cards(r: Dictionary) -> Dictionary:
	var out := {}
	for id in r.config.deck.keys() + r.config.get("build_menu", {}).keys():
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


## Backlog 107: a game starts as each listed civilization. Since 295 its home takes most of the build menu's open
## entries (was: most starting-deck building copies).
func test_every_listed_civilization_has_its_own_home_that_takes_most_open_entries() -> void:
	var r := load_real()
	var buildings: Array[CardDef] = []
	for id in open_entries(r):
		buildings.append(r.cards[id])
	var copies := buildings.size()
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
				fit += 1
		check(fit * 2 > copies, "%s's home %s takes %d of %d open build-menu entries" % [civ, home, fit, copies])


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


## Backlog 272: only the first era's techs stand alone; every later one builds on an earlier advance.
func test_every_tech_above_era_1_has_a_prereq() -> void:
	var r := load_real()
	var missing: Array[String] = []
	for tech in techs_in_research_deck(r):
		if tech.era > 1 and tech.prereq == "":
			missing.append(tech.id)
	eq(missing, [] as Array[String], "techs above era 1 with no prereq")


## Backlog 272: every tech in the research deck has a eureka.
func test_every_tech_has_a_eureka() -> void:
	var r := load_real()
	var missing: Array[String] = []
	for tech in techs_in_research_deck(r):
		if tech.eureka.is_empty():
			missing.append(tech.id)
	eq(missing, [] as Array[String], "techs with no eureka")


## Backlog 272: era 1 grows the food supply in several ways: at least 3 farm buildings unlock from era-1 techs.
func test_era_1_techs_unlock_at_least_3_farm_buildings() -> void:
	var r := load_real()
	var farms := {}
	for tech in techs_in_research_deck(r):
		if tech.era != 1:
			continue
		for effect in tech.effects:
			if effect.op == "unlock" and r.cards[effect.card_id].type == CardDef.BUILDING \
					and r.cards[effect.card_id].has_tag("farm"):
				farms[effect.card_id] = true
	check(farms.size() >= 3, "era-1 techs unlock %d farm buildings (%s), want at least 3" % [farms.size(), farms.keys()])


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


## 286: wonders are built over turns, and only wonders are.
func test_every_wonder_is_a_project_and_every_project_a_wonder() -> void:
	var r := load_real()
	for id in r.cards:
		var def: CardDef = r.cards[id]
		eq(def.get("project") == true, def.has_tag("wonder"), "%s: project iff wonder" % id)


## 282: each government names the largest settlement tier it keeps calm.
func test_every_government_sets_tolerates() -> void:
	var r := load_real()
	for id in r.cards:
		if r.cards[id].type == CardDef.GOVERNMENT:
			check(r.cards[id].get("tolerates") is String and r.cards[id].get("tolerates") != "", "government %s sets tolerates" % id)


## 319: each government administers some territories.
func test_every_government_sets_administers() -> void:
	var r := load_real()
	for id in r.cards:
		if r.cards[id].type == CardDef.GOVERNMENT:
			check(r.cards[id].get("administers") is int and r.cards[id].get("administers") >= 1,
				"government %s sets administers" % id)


## 320: every card that settles costs more for each territory held.
func test_every_settling_card_costs_more_per_territory() -> void:
	var r := load_real()
	for id in r.cards:
		var def: CardDef = r.cards[id]
		if def.effects.any(func(effect): return effect.op == "settle"):
			check(def.get("cost_per_territory") is Dictionary and not def.get("cost_per_territory").is_empty(),
				"%s settles but sets no cost_per_territory" % id)


## 319: only cards a player holds one of raise the admin cap; copies of a building would stack it without end.
func test_only_unique_cards_raise_the_admin_cap() -> void:
	var r := load_real()
	var unique: Array[String] = [CardDef.TECH, CardDef.GOVERNMENT, CardDef.CIVILIZATION]
	for id in r.cards:
		var def: CardDef = r.cards[id]
		if def.modifiers.has("administers"):
			check(unique.has(def.type) or def.tags.has("wonder"), "%s raises the admin cap but isn't unique" % id)


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


## Backlog 263: a rolled resource is worth wealth: each one is the keyword of a reachable building's upkeep wealth gain.
func test_every_resource_keyword_raises_a_buildings_upkeep_wealth() -> void:
	var r := load_real()
	var reachable := reachable_cards(r)
	var paid := {}
	for def in real_buildings(r):
		if not reachable.has(def.id):
			continue
		for e in def.effects:
			if e.trigger == "upkeep" and e.keyword != "" and e.get("resource") == GameEngine.WEALTH:
				paid[e.keyword] = true
	var unpaid: Array[String] = []
	for k in r.config.resource_keywords:
		if not paid.has(k):
			unpaid.append(k)
	eq(unpaid, [] as Array[String], "resource keywords no reachable building's upkeep wealth gain uses")


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
	for id in open_entries(r):  # 295
		early.append(r.cards[id])
	for id in [r.config.starting.territory] + r.config.territory_deck.keys():
		var land: CardDef = r.cards[id]
		var fits := early.filter(func(b): return b.requires.is_empty() or b.requires.any(func(k): return land.keywords.has(k)))
		check(not fits.is_empty(), "territory %s %s can take an open build-menu entry" % [id, land.keywords])


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
	for key in ["deck", "supply", "build_menu", "territory_deck", "event_deck", "research_deck"]:
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


## Backlog 273: a tech's gain_per_tag counts a tag at least 3 reachable buildings carry, so it grows as you build.
func test_every_tech_gain_per_tag_counts_a_tag_on_3_buildings() -> void:
	var r := load_real()
	var reachable := reachable_cards(r)
	var buildings := {}
	for id in reachable:
		if r.cards[id].type == CardDef.BUILDING:
			for tag in r.cards[id].tags:
				buildings[tag] = buildings.get(tag, 0) + 1
	var thin: Array[String] = []
	for tech in techs_in_research_deck(r):
		for effect in tech.effects:
			if effect.op == "gain_per_tag" and buildings.get(effect.get("tag"), 0) < 3:
				thin.append("%s: %s on %d" % [tech.id, effect.get("tag"), buildings.get(effect.get("tag"), 0)])
	eq(thin, [] as Array[String], "tech gain_per_tag tags fewer than 3 reachable buildings carry")


## Backlog 274: famine has more than one answer: at least 2 reachable buildings guard pop from starving.
func test_at_least_2_reachable_buildings_guard_against_famine() -> void:
	var r := load_real()
	var guards: Array[String] = []
	for id in reachable_cards(r):
		var def: CardDef = r.cards[id]
		if def.type == CardDef.BUILDING and def.famine_guard > 0:
			guards.append(id)
	check(guards.size() >= 2, "only %s set famine_guard" % [guards])


## Backlog 274: some tech trades unrest for income: an upkeep gain of wealth or insight and an upkeep gain of unrest.
func test_some_tech_pays_income_for_unrest_each_upkeep() -> void:
	var r := load_real()
	var found: Array[String] = []
	for tech in techs_in_research_deck(r):
		var upkeep_gains: Array = tech.effects.filter(func(e): return e.trigger == "upkeep" and e.op == "gain")
		var income := upkeep_gains.any(func(e): return e.get("resource") in [GameEngine.WEALTH, GameEngine.INSIGHT])
		var unrest := upkeep_gains.any(func(e): return e.get("resource") == GameEngine.UNREST)
		if income and unrest:
			found.append(tech.id)
	check(not found.is_empty(), "no tech in the research deck gains wealth or insight and unrest each upkeep")


## Backlog 274: hills take more than one building: at least 2 reachable non-wonder buildings require hills.
func test_at_least_2_reachable_buildings_require_hills() -> void:
	var r := load_real()
	var hill_buildings: Array[String] = []
	for id in reachable_cards(r):
		var def: CardDef = r.cards[id]
		if def.type == CardDef.BUILDING and not def.has_tag("wonder") and def.requires.has("hills"):
			hill_buildings.append(id)
	check(hill_buildings.size() >= 2, "only %s require hills" % [hill_buildings])


## Backlog 275: some tech or building makes every insight gain bigger (modifiers.insight_per_gain above 0).
func test_some_tech_or_building_raises_insight_per_gain() -> void:
	var r := load_real()
	var sources: Array[CardDef] = techs_in_research_deck(r)
	for id in reachable_cards(r):
		if r.cards[id].type == CardDef.BUILDING:
			sources.append(r.cards[id])
	var found: Array[String] = []
	for def in sources:
		if def.modifiers.get(Modifiers.INSIGHT_PER_GAIN, 0) > 0:
			found.append(def.id)
	check(not found.is_empty(), "no tech or reachable building sets insight_per_gain above 0")


## Backlog 275: dry desert and dry hills can feed people: for each, some reachable building with an upkeep food gain
## can be built on a territory in the deck that has that terrain and no fresh water.
func test_dry_desert_and_hills_each_take_a_food_building() -> void:
	var r := load_real()
	var reachable := reachable_cards(r)
	for terrain in ["desert", "hills"]:
		var fed: Array[String] = []
		for territory_id in r.config.territory_deck:
			var keywords: Array[String] = r.cards[territory_id].keywords
			if not keywords.has(terrain) or keywords.has("fresh_water"):
				continue
			for id in reachable:
				var def: CardDef = r.cards[id]
				if def.type != CardDef.BUILDING or not (def.requires.is_empty() or def.requires.any(func(k): return keywords.has(k))):
					continue
				if def.effects.any(func(e): return e.op == "gain" and e.trigger == "upkeep" \
						and e.get("resource") == GameEngine.FOOD and (e.keyword == "" or keywords.has(e.keyword))):
					fed.append("%s on %s" % [id, territory_id])
		check(not fed.is_empty(), "no food building fits a dry %s territory" % terrain)


## Backlog 275: a gain_per_tag counts a tag at least 2 reachable cards carry, on any reachable card or research tech.
func test_every_gain_per_tag_tag_is_on_2_reachable_cards() -> void:
	var r := load_real()
	var reachable := reachable_cards(r)
	var carriers := {}
	for id in reachable:
		for tag in r.cards[id].tags:
			carriers[tag] = carriers.get(tag, 0) + 1
	var counters: Array[CardDef] = techs_in_research_deck(r)
	for id in reachable:
		counters.append(r.cards[id])
	var thin: Array[String] = []
	for def in counters:
		for effect in def.effects:
			if effect.op == "gain_per_tag" and carriers.get(effect.get("tag"), 0) < 2:
				thin.append("%s: %s on %d" % [def.id, effect.get("tag"), carriers.get(effect.get("tag"), 0)])
	eq(thin, [] as Array[String], "gain_per_tag tags fewer than 2 reachable cards carry")


## Backlog 281: the real data has settlement tiers, at least 2 of them.
func test_population_has_at_least_2_tiers() -> void:
	var r := load_real()
	check(r.config.population.get("tiers", []).size() >= 2, "population.tiers: %s" % [r.config.population.get("tiers")])


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
