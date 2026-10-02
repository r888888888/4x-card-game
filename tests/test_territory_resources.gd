extends "res://tests/lib/test_case.gd"
## Rolled territory resources (backlog 036): each territory copy rolls resource keywords from a weighted
## per-terrain table (config `territory_resources`), on top of its printed terrain keywords.
## Fixtures: Hills prints ["mountain"], River ["fresh_water", "flood_plain"], Homeland nothing.

const RESOURCE_KEYWORDS := ["gold"]
## Buildings that care about gold: Mint needs it, Goldsmith makes +1 wealth at upkeep on it.
const GOLD_CARDS := [
	{"id": "mint", "name": "Mint", "type": "building", "requires": ["gold"]},
	{"id": "goldsmith", "name": "Goldsmith", "type": "building", "effects": [
		{"op": "gain", "resource": "wealth", "amount": 1, "trigger": "upkeep", "keyword": "gold"}]},
]
const ALWAYS_GOLD := {"hills": [{"keywords": ["gold"], "weight": 1}]}
const HALF_GOLD := {"hills": [{"keywords": ["gold"], "weight": 1}, {"keywords": [], "weight": 1}]}


func gold_resource_keywords() -> Array[String]:
	var k: Array[String] = []
	k.assign(RESOURCE_KEYWORDS)
	return k


## A game with the given territory_resources tables and territory deck; the Capital on starting.
func resource_engine(tables: Dictionary, territory_deck: Dictionary, deck := {"scout": 10}, seed_value := 1, starting := "homeland") -> GameEngine:
	var errors: Array[String] = []
	var warnings: Array[String] = []
	var cards := cards_of(fixture_load(GOLD_CARDS, [], [], gold_resource_keywords()), errors, warnings)
	var config := DataLoader.parse_config(raw_config(deck, {
		"resource_keywords": RESOURCE_KEYWORDS,
		"territory_resources": tables,
		"territory_deck": territory_deck,
		"starting": {"resources": {"food": 2}, "tableau": ["capital"], "territory": starting},
	}), resources(), cards, "test", errors, warnings)
	check(errors.is_empty(), "test data should load: %s" % [errors])
	var engine := GameEngine.new(cards, config)
	engine.new_game(seed_value)
	return engine


## Loader errors for a config with resource_keywords ["gold"] plus overrides.
func gold_config_errors(overrides: Dictionary) -> Array[String]:
	return config_errors_for(fixture_load(GOLD_CARDS, [], [], gold_resource_keywords()).cards, {"resource_keywords": RESOURCE_KEYWORDS}.merged(overrides, true))


func kw(list: Array) -> Array[String]:
	var out: Array[String] = []
	out.assign(list)
	return out


## Moves every territory in the territory deck to the tableau (settled) and returns them.
func settle_all(e: GameEngine) -> Array[CardInstance]:
	var out: Array[CardInstance] = []
	for c in e.zone("territory_deck").take_all():
		e.zone("tableau").add(c)
		out.append(c)
	return out


func first_with(e: GameEngine, territories: Array[CardInstance], has_gold: bool) -> CardInstance:
	for t in territories:
		if e.territory_keywords(t.uid).has("gold") == has_gold:
			return t
	return null


# --- AC1: each copy rolls from its terrain's table ---

func test_each_copy_rolls_its_only_option() -> void:
	var e := resource_engine(ALWAYS_GOLD, {"hills": 3})
	eq(e.zone("territory_deck").size(), 3, "3 Hills")
	for c in e.zone("territory_deck").cards:
		eq(e.territory_keywords(c.uid), kw(["mountain", "gold"]), "Hills %d: printed then rolled" % c.uid)


func test_empty_only_option_keeps_printed_keywords() -> void:
	var e := resource_engine({"hills": [{"keywords": [], "weight": 1}]}, {"hills": 3})
	for c in e.zone("territory_deck").cards:
		eq(e.territory_keywords(c.uid), kw(["mountain"]), "Hills %d" % c.uid)


# --- AC2: rolls are random but follow the seed ---

func rolled_by_uid(e: GameEngine) -> Dictionary:
	var out := {}
	for c in e.zone("territory_deck").cards:
		out[c.uid] = e.territory_keywords(c.uid)
	return out


func test_rolls_follow_the_seed() -> void:
	var a := rolled_by_uid(resource_engine(HALF_GOLD, {"hills": 20}, {"scout": 10}, 7))
	var b := rolled_by_uid(resource_engine(HALF_GOLD, {"hills": 20}, {"scout": 10}, 7))
	eq(a.size(), 20, "20 Hills")
	eq(a, b, "same seed, same keywords per uid")


func test_rolls_vary_between_copies() -> void:
	var e := resource_engine(HALF_GOLD, {"hills": 20})
	var with_gold := 0
	for c in e.zone("territory_deck").cards:
		if e.territory_keywords(c.uid).has("gold"):
			with_gold += 1
	check(with_gold > 0 and with_gold < 20, "some Hills have gold and some don't (%d of 20 have it)" % with_gold)


# --- AC3: no table means printed keywords only; the starting territory rolls too ---

func test_territory_without_table_keeps_printed_keywords() -> void:
	var e := resource_engine(ALWAYS_GOLD, {"river": 1})
	var river: CardInstance = e.zone("territory_deck").cards[0]
	eq(e.territory_keywords(river.uid), kw(["fresh_water", "flood_plain"]), "River")
	eq(e.territory_keywords(home_uid(e)), kw([]), "Homeland")


func test_starting_territory_rolls_from_its_table() -> void:
	var e := resource_engine({"homeland": [{"keywords": ["gold"], "weight": 1}]}, {})
	eq(e.territory_keywords(home_uid(e)), kw(["gold"]), "Homeland rolled gold")


# --- AC4: rolled keywords count like printed ones ---

func test_rolled_keyword_limits_building_targets() -> void:
	var e := resource_engine(HALF_GOLD, {"hills": 20}, {"mint": 10})
	var hills := settle_all(e)
	var gold_uids: Array[int] = []
	for t in hills:
		if e.territory_keywords(t.uid).has("gold"):
			gold_uids.append(t.uid)
	var mint := first_in_hand(e)
	eq(e.valid_targets(mint), gold_uids, "Mint can go only on Hills that rolled gold")
	var plain := first_with(e, hills, false)
	eq(e.play_error(mint, plain.uid), "Mint needs a territory with Gold.", "play_error on a Hills without gold")


func test_rolled_keyword_effect_applies_on_that_copy() -> void:
	var e := resource_engine(HALF_GOLD, {"hills": 20}, {"goldsmith": 10})
	var gold := first_with(e, settle_all(e), true)
	check(e.play_card(first_in_hand(e), gold.uid), "Goldsmith on a Hills with gold")
	e.end_turn()
	eq(e.resources.wealth, 1, "Goldsmith +1 wealth on gold")


func test_rolled_keyword_effect_skipped_on_copy_without_it() -> void:
	var e := resource_engine(HALF_GOLD, {"hills": 20}, {"goldsmith": 10})
	var plain := first_with(e, settle_all(e), false)
	check(e.play_card(first_in_hand(e), plain.uid), "Goldsmith on a Hills without gold")
	e.end_turn()
	eq(e.resources.wealth, 0, "no wealth without gold")


# --- AC5: territory_keywords in every zone ---

func test_territory_keywords_in_every_zone() -> void:
	var e := resource_engine(ALWAYS_GOLD, {"hills": 4})
	var cards: Array[CardInstance] = []
	cards.assign(e.zone("territory_deck").cards)
	var moves := {"reveal": cards[1], "frontier": cards[2], "tableau": cards[3]}
	for zone_name in moves:
		e.zone("territory_deck").remove(moves[zone_name])
		e.zone(zone_name).add(moves[zone_name])
	eq(e.territory_keywords(cards[0].uid), kw(["mountain", "gold"]), "in territory_deck")
	for zone_name in moves:
		eq(e.territory_keywords(moves[zone_name].uid), kw(["mountain", "gold"]), "in " + zone_name)


func test_territory_keywords_empty_for_non_territory() -> void:
	var e := resource_engine(ALWAYS_GOLD, {"hills": 1})
	var capital: CardInstance = null
	for c in e.zone("tableau").cards:
		if c.def.id == "capital":
			capital = c
	eq(e.territory_keywords(capital.uid), kw([]), "Capital")
	eq(e.territory_keywords(9999), kw([]), "unknown uid")


# --- AC6: loader validation ---

func test_valid_resource_config_loads_cleanly() -> void:
	var errors: Array[String] = []
	var warnings: Array[String] = []
	var cards := cards_of(fixture_load(GOLD_CARDS, [], [], gold_resource_keywords()), errors, warnings)
	var config := DataLoader.parse_config(raw_config({"farm": 1}, {
		"keywords": keywords(), "resource_keywords": RESOURCE_KEYWORDS, "territory_resources": HALF_GOLD,
	}), resources(), cards, "config.json", errors, warnings)
	eq(errors, [] as Array[String], "errors")
	eq(warnings, [] as Array[String], "warnings (requires and effect keyword accept resource keywords)")
	eq(config.resource_keywords, kw(["gold"]), "resource_keywords")
	eq(config.territory_resources.hills.size(), 2, "Hills has 2 options")
	eq(config.territory_resources.hills[0].keywords, kw(["gold"]), "option 0 keywords")
	eq(config.territory_resources.hills[0].weight, 1, "option 0 weight")
	eq(config.territory_resources.hills[1].keywords, kw([]), "option 1 keywords")


func test_resource_config_validation() -> void:
	var tr := func(tables): return {"territory_resources": tables}
	var weight := func(w): return {"territory_resources": {"hills": [{"keywords": ["gold"], "weight": w}]}}
	var weight_error := "config.json: territory_resources: 'hills'[0]: 'weight' must be an integer >= 1"
	check_cases([
		["keyword in both lists", {"keywords": ["mountain", "gold"]}, "config.json: resource_keywords: 'gold' is also in 'keywords'"],
		["resource_keywords not an array", {"resource_keywords": "gold"}, "config.json: 'resource_keywords' must be an array of keyword ids"],
		["table for an unknown card", tr.call({"nowhere": ALWAYS_GOLD.hills}), "config.json: territory_resources: unknown card 'nowhere'"],
		["table for a non-territory", tr.call({"farm": ALWAYS_GOLD.hills}), "config.json: territory_resources: 'farm' is not a territory"],
		["option with a terrain keyword", tr.call({"hills": [{"keywords": ["mountain"], "weight": 1}]}),
			"config.json: territory_resources: 'hills'[0]: 'mountain' is not a resource keyword"],
		["weight 0", weight.call(0), weight_error],
		["weight -1", weight.call(-1), weight_error],
		["weight 1.5", weight.call(1.5), weight_error],
		["weight \"2\"", weight.call("2"), weight_error],
		["empty table", tr.call({"hills": []}), "config.json: territory_resources: 'hills' must be a non-empty array"],
		["option not an object", tr.call({"hills": ["gold"]}),
			"config.json: territory_resources: 'hills'[0] must be an object like {\"keywords\": [\"gold\"], \"weight\": 1}"],
		["option keywords not an array", tr.call({"hills": [{"keywords": "gold", "weight": 1}]}),
			"config.json: territory_resources: 'hills'[0]: 'keywords' must be an array"],
		["territory_resources not an object", tr.call([]), "config.json: 'territory_resources' must be an object"],
	], gold_config_errors)


func test_territory_printing_resource_keyword_is_error() -> void:
	var errors: Array[String] = []
	var warnings: Array[String] = []
	var card := {"id": "gold_hills", "name": "Gold Hills", "type": "territory", "slots": 2, "keywords": ["mountain", "gold"]}
	DataLoader.parse_cards({"cards": [card]}, resources(), "cards.json", errors, warnings, keywords(), gold_resource_keywords())
	has_msg(errors, "cards.json: card 'gold_hills': keywords: 'gold' is a resource keyword")
