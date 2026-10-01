extends "res://tests/lib/test_case.gd"
## Anarchy (backlog 145): a turn that starts with unrest at the limit falls into Anarchy, the config's unrest.anarchy
## government. While it rules only governments and allowed_tag cards play, nothing is grown, bought or researched, each
## turn adds a counter, and at max_counters the fallback government restores order. Each new era adds era_unrest.
## Local fixtures, with TEST_CARDS and TEST_GOVS: Chiefs (government, limit 5), Kings (limit 8), Anarchy (government,
## 1 action, ⟳ −1 pop), Feast (order, −2 unrest), Calm (building, ⟳ −1 unrest), Dawn (adds era 2) and Lore (a tech).
## Engines are held as Object so the file parses before the API.

const RESOURCES: Array[String] = ["food", "wealth", "insight", "unrest"]
const CHIEFS := {"id": "chiefs", "name": "Chiefs", "type": "government", "unrest_limit": 5}
const KINGS := {"id": "kings", "name": "Kings", "type": "government", "unrest_limit": 8}
const ANARCHY := {"id": "anarchy", "name": "Anarchy", "type": "government", "actions": 1,
	"effects": [{"op": "lose_pop", "amount": 1, "trigger": "upkeep"}]}
const FEAST := {"id": "feast", "name": "Feast", "type": "action", "tags": ["order"],
	"effects": [{"op": "lose", "resource": "unrest", "amount": 2}]}
const CALM := {"id": "calm", "name": "Calm", "type": "building",
	"effects": [{"op": "lose", "resource": "unrest", "amount": 1, "trigger": "upkeep"}]}
const DAWN := {"id": "dawn", "name": "Dawn", "type": "action", "effects": [{"op": "add_era", "era": 2}]}
const LORE := {"id": "lore", "name": "Lore", "type": "tech", "cost": {"insight": 1}}
const FIXTURES := [CHIEFS, KINGS, ANARCHY, FEAST, CALM, DAWN, LORE]
const UNREST_BLOCK := {"anarchy": "anarchy", "fallback": "chiefs", "max_counters": 4, "era_unrest": 3,
	"allowed_tag": "order"}
const POP := {"start": 6, "food_upkeep": 0, "vp_per_pop": 0, "famine": FAMINE}
const ONLY_ORDER := "Anarchy: only a government or an order card can be played."
const NOTHING_BUILT := "Anarchy: nothing can be grown, bought or researched."


## TEST_CARDS, TEST_GOVS and FIXTURES, parsed with unrest a resource.
func anarchy_db() -> Dictionary:
	var errors: Array[String] = []
	var warnings: Array[String] = []
	var cards := DataLoader.parse_cards({"cards": TEST_CARDS.cards + TEST_GOVS + FIXTURES}, RESOURCES, "cards.json",
		errors, warnings, keywords())
	check(errors.is_empty(), "test cards should load: %s" % [errors])
	return cards


## The raw config for an anarchy game: Chiefs ruling, unrest listed, the unrest block (merged with unrest), population
## on (home pop 6), 10 food, wealth and insight, Lore in the research deck and Farms in the supply; overrides last (a
## null value drops that key).
func anarchy_raw(unrest := {}, overrides := {}) -> Dictionary:
	var o := {"resources": RESOURCES, "population": POP, "unrest": UNREST_BLOCK.merged(unrest, true),
		"research_deck": {"lore": 1}, "supply": {"farm": {"price": 1, "count": 3}},
		"starting": {"resources": {"food": 10, "wealth": 10, "insight": 10}, "tableau": ["capital"],
			"territory": "homeland", "government": "chiefs"}}
	o.merge(overrides, true)
	var raw := raw_config({"farm": 10}, o)
	for key in overrides:
		if overrides[key] == null:
			raw.erase(key)
	return raw


## The errors from parsing raw against anarchy_db.
func config_errors(raw: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var warnings: Array[String] = []
	var listed: Array[String] = []
	listed.assign(raw.resources)
	DataLoader.parse_config(raw, listed, anarchy_db(), "config.json", errors, warnings)
	return errors


## A new anarchy game (see anarchy_raw).
func anarchy_engine(unrest := {}, overrides := {}) -> Object:
	var cards := anarchy_db()
	var errors: Array[String] = []
	var warnings: Array[String] = []
	var raw := anarchy_raw(unrest, overrides)
	var listed: Array[String] = []
	listed.assign(raw.resources)
	var config := DataLoader.parse_config(raw, listed, cards, "config.json", errors, warnings)
	check(errors.is_empty(), "test config should load: %s" % [errors])
	var e := GameEngine.new(cards, config)
	e.new_game(1)
	return e


## An anarchy game that fell into Anarchy at the start of turn 2 (unrest 5 of 5 at the end of turn 1).
func fallen_engine(unrest := {}) -> Object:
	var e: Object = anarchy_engine(unrest)
	e.resources["unrest"] = 5
	e.end_turn()
	return e


## The ruling government's card id ("" for none).
func ruling(e: Object) -> String:
	return "" if e.zone("government").is_empty() else e.zone("government").cards[0].def.id


# --- AC1: the config block ---

func test_the_unrest_block_loads_with_its_defaults() -> void:
	var errors: Array[String] = []
	var warnings: Array[String] = []
	var raw := anarchy_raw()
	raw.unrest = {"anarchy": "anarchy", "fallback": "chiefs", "max_counters": 4}
	var config := DataLoader.parse_config(raw, RESOURCES, anarchy_db(), "config.json", errors, warnings)
	eq(errors, [] as Array[String], "errors")
	eq(warnings, [] as Array[String], "warnings")
	eq(config.get("unrest"), {"anarchy": "anarchy", "fallback": "chiefs", "max_counters": 4, "era_unrest": 0,
		"allowed_tag": ""}, "normalized, era_unrest 0 and allowed_tag \"\" by default")


func test_unrest_block_validation() -> void:
	var with_block := func(block: Dictionary) -> Dictionary: return anarchy_raw(block)
	check_cases([
		["anarchy not a government", with_block.call({"anarchy": "farm"}), ["config.json: unrest.anarchy:", "farm", "government"]],
		["anarchy unknown", with_block.call({"anarchy": "nobody"}), ["config.json: unrest.anarchy:", "nobody"]],
		["fallback not a government", with_block.call({"fallback": "farm"}), ["config.json: unrest.fallback:", "farm", "government"]],
		["max_counters 0", with_block.call({"max_counters": 0}), ["config.json: unrest.max_counters:", ">= 1"]],
		["era_unrest -1", with_block.call({"era_unrest": -1}), ["config.json: unrest.era_unrest:", ">= 0"]],
		["allowed_tag not a string", with_block.call({"allowed_tag": 3}), ["config.json: unrest.allowed_tag:", "string"]],
		["anarchy starts", anarchy_raw({}, {"starting": {"resources": {"food": 2}, "tableau": ["capital"],
			"territory": "homeland", "government": "anarchy"}}), ["config.json: unrest.anarchy:", "starting.government"]],
		["anarchy sets a limit", with_block.call({"anarchy": "kings"}), ["config.json: unrest.anarchy:", "unrest_limit"]],
		["without unrest in resources", anarchy_raw({}, {"resources": ["food", "wealth", "insight"],
			"starting": {"resources": {"food": 2}, "tableau": ["capital"], "territory": "homeland", "government": "chiefs"}}),
			["config.json: unrest:", "resources"]],
	], config_errors)


# --- AC2: falling into Anarchy ---

func test_a_turn_starting_at_the_limit_falls_into_anarchy() -> void:
	var e: Object = anarchy_engine()
	var recorded := record_messages(e)
	var deck_before: int = e.zone("deck").size()
	e.resources["unrest"] = 5
	e.end_turn()
	eq(ruling(e), "anarchy", "Anarchy rules")
	eq(e.anarchy(), e.government(), "anarchy() is its uid")
	check(uid_of(e.zone("deck"), "chiefs") != -1, "Chiefs is shuffled into the deck")
	eq(e.zone("deck").size(), deck_before + 1, "the deck gains Chiefs (a full hand draws none)")
	check_noticed(recorded, "Anarchy")


func test_unrest_below_the_limit_doesnt_fall() -> void:
	var e: Object = anarchy_engine()
	e.resources["unrest"] = 4
	e.end_turn()
	eq(ruling(e), "chiefs", "Chiefs still rules")
	eq(e.anarchy(), -1, "no anarchy")


func test_an_upkeep_that_calms_below_the_limit_prevents_anarchy() -> void:
	var e: Object = anarchy_engine()
	build_on(e, home_uid(e), ["calm"])
	e.resources["unrest"] = 5
	e.end_turn()
	eq(e.resources.get("unrest"), 4, "Calm ⟳ −1 at upkeep")
	eq(ruling(e), "chiefs", "the check comes after upkeep")


func test_without_an_unrest_block_the_limit_only_caps() -> void:
	var e: Object = anarchy_engine({}, {"unrest": null})
	e.resources["unrest"] = 5
	e.end_turn()
	eq(ruling(e), "chiefs", "no Anarchy without the config block")


func test_unrest_has_no_limit_under_anarchy() -> void:
	eq(fallen_engine().unrest_limit(), -1, "unrest_limit under Anarchy")


# --- AC3: what Anarchy locks ---

func test_under_anarchy_only_governments_and_order_cards_play() -> void:
	var e: Object = fallen_engine()
	var shrine := put_in_hand(e, "shrine")
	eq(e.play_error(shrine), ONLY_ORDER, "Shrine")
	check(not e.play_card(shrine), "play_card refuses")
	eq(e.play_error(put_in_hand(e, "kings")), "", "a government plays")
	var feast := put_in_hand(e, "feast")
	check(e.play_card(feast), "Feast (order) plays: %s" % e.play_error(feast))
	eq(e.resources.get("unrest"), 3, "5 − 2")


func test_anarchy_has_its_cards_actions() -> void:
	eq(fallen_engine().actions_per_turn(), 1, "Anarchy's 1 action")


func test_under_anarchy_nothing_is_grown_bought_or_researched() -> void:
	var e: Object = fallen_engine()
	eq(e.grow_error(home_uid(e)), NOTHING_BUILT, "grow_error")
	check(not e.grow(home_uid(e)), "grow refuses")
	eq(e.buy_error("farm"), NOTHING_BUILT, "buy_error")
	check(not e.buy("farm"), "buy refuses")
	var lore := uid_of(e.zone("research_deck"), "lore")
	eq(e.buy_tech_error(lore), NOTHING_BUILT, "buy_tech_error")
	check(not e.buy_tech(lore), "buy_tech refuses")


func test_under_anarchy_discarding_and_ending_the_turn_work() -> void:
	var e: Object = fallen_engine()
	var card: int = e.zone("hand").cards[0].uid
	eq(e.discard_error(card), "", "discard_error")
	eq(e.end_turn_error(), "", "end_turn_error")


# --- AC4: counters and burning out ---

func test_each_turn_of_anarchy_adds_a_counter_and_takes_a_pop() -> void:
	var e: Object = fallen_engine()
	var home := home_uid(e)
	eq(e.anarchy_counters(), 0, "the turn it falls")
	eq(e.pop(home), 6, "no Anarchy upkeep yet")
	e.end_turn()
	eq(e.anarchy_counters(), 1, "next turn")
	eq(e.pop(home), 5, "Anarchy ⟳ −1 pop")
	e.end_turn()
	eq(e.anarchy_counters(), 2, "the turn after")
	eq(e.pop(home), 4, "−1 pop again")


func test_anarchy_burns_out_at_max_counters_and_the_fallback_restores_order() -> void:
	var e: Object = fallen_engine()
	var recorded := record_messages(e)
	var anarchy_uid: int = e.anarchy()
	for i in 3:
		e.end_turn()
	eq(ruling(e), "anarchy", "3 counters: still Anarchy")
	e.end_turn()
	eq(ruling(e), "chiefs", "the 4th counter: Chiefs restores order")
	eq(e.anarchy(), -1, "no anarchy")
	check(e.zone("removed").find(anarchy_uid) != null, "the Anarchy card is removed")
	eq(e.resources.get("unrest"), 2, "min(5, 5 / 2)")
	check_noticed(recorded, "order")


func test_burning_out_keeps_unrest_below_half_the_limit() -> void:
	var e: Object = fallen_engine()
	var feast := put_in_hand(e, "feast")
	e.play_card(feast)
	e.resources["unrest"] = 1
	for i in 3:
		e.end_turn()
	eq(ruling(e), "anarchy", "3 counters: still Anarchy")
	e.end_turn()
	eq(ruling(e), "chiefs", "burned out")
	eq(e.resources.get("unrest"), 1, "min(1, 2)")


# --- AC5: a new era stirs unrest ---

func test_a_new_era_adds_era_unrest_up_to_the_limit() -> void:
	var e: Object = anarchy_engine()
	var recorded := record_messages(e)
	e.resources["unrest"] = 3
	var dawn := put_in_hand(e, "dawn")
	check(e.play_card(dawn), "Dawn: %s" % e.play_error(dawn))
	eq(e.resources.get("unrest"), 5, "3 + 3, capped at 5")
	check_noticed(recorded, "unrest")
	e.end_turn()
	eq(ruling(e), "anarchy", "the next turn falls into Anarchy")


func test_era_unrest_0_adds_nothing() -> void:
	var e: Object = anarchy_engine({"era_unrest": 0})
	e.resources["unrest"] = 3
	e.play_card(put_in_hand(e, "dawn"))
	eq(e.resources.get("unrest"), 3, "no era unrest")


# --- AC6: the bot ---

func test_the_bot_plays_a_government_first_under_anarchy() -> void:
	var e: Object = fallen_engine()
	put_in_hand(e, "feast")
	put_in_hand(e, "kings")
	var played: Array[String] = []
	var ids := {}
	for c in e.zone("hand").cards:
		ids[c.uid] = c.def.id
	e.card_played.connect(func(o: Dictionary): played.append(ids.get(o.uid, "?")))
	ScriptedBot.take_turn(e, "baseline")
	check(not played.is_empty() and played[0] == "kings", "Kings before Feast: %s" % [played])
