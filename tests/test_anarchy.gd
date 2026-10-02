extends "res://tests/lib/anarchy_case.gd"
## Anarchy (backlog 145): a turn that starts with unrest at the limit falls into Anarchy, the config's unrest.anarchy
## government. While it rules only allowed_tag cards play, nothing is grown, bought or researched, and when it ends a
## government is chosen from the government deck (154; its length: 155, test_anarchy_length.gd). Each new era adds
## era_unrest. Fixtures: tests/lib/anarchy_case.gd.


# --- AC1: the config block ---

func test_the_unrest_block_loads_with_its_defaults() -> void:
	var errors: Array[String] = []
	var warnings: Array[String] = []
	var raw := anarchy_raw()
	raw.unrest = {"anarchy": "anarchy", "max_counters": 4}
	var config := DataLoader.parse_config(raw, RESOURCES, anarchy_db(), "config.json", errors, warnings)
	eq(errors, [] as Array[String], "errors")
	eq(warnings, [] as Array[String], "warnings")
	eq(config.get("unrest"), {"anarchy": "anarchy", "max_counters": 4, "era_unrest": 0,
		"allowed_tag": ""}, "normalized, era_unrest 0 and allowed_tag \"\" by default")


func test_unrest_block_validation() -> void:
	var with_block := func(block: Dictionary) -> Dictionary: return anarchy_raw(block)
	check_cases([
		["anarchy not a government", with_block.call({"anarchy": "farm"}), ["config.json: unrest.anarchy:", "farm", "government"]],
		["anarchy unknown", with_block.call({"anarchy": "nobody"}), ["config.json: unrest.anarchy:", "nobody"]],
		["max_counters 0", with_block.call({"max_counters": 0}), ["config.json: unrest.max_counters:", ">= 1"]],
		["era_unrest -1", with_block.call({"era_unrest": -1}), ["config.json: unrest.era_unrest:", ">= 0"]],
		["allowed_tag not a string", with_block.call({"allowed_tag": 3}), ["config.json: unrest.allowed_tag:", "string"]],
		["anarchy starts", anarchy_raw({}, {"starting": {"resources": {"food": 2}, "tableau": ["capital"],
			"territory": "homeland", "government": "anarchy"}}), ["config.json: unrest.anarchy:", "starting.government"]],
		["anarchy sets a limit", with_block.call({"anarchy": "kings"}), ["config.json: unrest.anarchy:", "unrest_limit"]],
		["without unrest in resources", anarchy_raw({}, {"resources": ["food", "wealth", "insight"],
			"starting": {"resources": {"food": 2}, "tableau": ["capital"], "territory": "homeland", "government": "chiefs"}}),
			["config.json: unrest:", "resources"]],
	], raw_config_errors)


func test_unrest_fallback_is_no_longer_read() -> void:
	var errors: Array[String] = []
	var warnings: Array[String] = []
	var config := DataLoader.parse_config(anarchy_raw({"fallback": "chiefs"}), RESOURCES, anarchy_db(), "config.json",
		errors, warnings)
	eq(errors, [] as Array[String], "errors")
	has_msg(warnings, "config.json: unrest: unknown field 'fallback'")
	check(not config.unrest.has("fallback"), "not in the normalized block")


# --- AC2: falling into Anarchy ---

func test_a_turn_starting_at_the_limit_falls_into_anarchy() -> void:
	var e := anarchy_engine()
	var recorded := record_messages(e)
	var deck_before: int = e.zone("deck").size()
	e.resources["unrest"] = 5
	e.end_turn()
	eq(ruling(e), "anarchy", "Anarchy rules")
	eq(e.anarchy(), e.government(), "anarchy() is its uid")
	check(uid_of(e.zone("governments"), "chiefs") != -1, "Chiefs goes to the government deck (154)")
	eq(e.zone("deck").size(), deck_before, "not into the deck (a full hand draws none)")
	check_noticed(recorded, "Anarchy!", GameEngine.NOTICE_URGENT)


func test_unrest_below_the_limit_doesnt_fall() -> void:
	var e := anarchy_engine()
	e.resources["unrest"] = 4
	e.end_turn()
	eq(ruling(e), "chiefs", "Chiefs still rules")
	eq(e.anarchy(), -1, "no anarchy")


func test_an_upkeep_that_calms_below_the_limit_prevents_anarchy() -> void:
	var e := anarchy_engine()
	build_on(e, home_uid(e), ["calm"])
	e.resources["unrest"] = 5
	e.end_turn()
	eq(e.resources.get("unrest"), 4, "Calm ⟳ −1 at upkeep")
	eq(ruling(e), "chiefs", "the check comes after upkeep")


func test_without_an_unrest_block_the_limit_only_caps() -> void:
	var e := anarchy_engine({}, {"unrest": null})
	e.resources["unrest"] = 5
	e.end_turn()
	eq(ruling(e), "chiefs", "no Anarchy without the config block")


func test_unrest_has_no_limit_under_anarchy() -> void:
	eq(fallen_engine().unrest_limit(), -1, "unrest_limit under Anarchy")


# --- AC3: what Anarchy locks ---

func test_under_anarchy_only_order_cards_play() -> void:
	var e := fallen_engine()
	var shrine := put_in_hand(e, "shrine")
	eq(e.play_error(shrine), ONLY_ORDER, "Shrine")
	check(not e.play_card(shrine), "play_card refuses")
	var feast := put_in_hand(e, "feast")
	check(e.play_card(feast), "Feast (order) plays: %s" % e.play_error(feast))
	eq(e.resources.get("unrest"), 3, "5 − 2")


func test_under_anarchy_a_government_in_hand_cant_be_played() -> void:
	var e := fallen_engine()
	e.resources["unrest"] = 0
	var kings := put_in_hand(e, "kings")
	eq(e.play_error(kings), "A government is chosen, not played.", "155 AC9")
	check(not e.play_card(kings), "play_card refuses")
	eq(ruling(e), "anarchy", "Anarchy still rules")


func test_anarchy_has_its_cards_actions() -> void:
	eq(fallen_engine().actions_per_turn(), 1, "Anarchy's 1 action")


func test_under_anarchy_nothing_is_grown_bought_or_researched() -> void:
	var e := fallen_engine()
	eq(e.grow_error(home_uid(e)), NOTHING_BUILT, "grow_error")
	check(not e.grow(home_uid(e)), "grow refuses")
	eq(e.buy_error("farm"), NOTHING_BUILT, "buy_error")
	check(not e.buy("farm"), "buy refuses")
	var lore := uid_of(e.zone("research_deck"), "lore")
	eq(e.buy_tech_error(lore), NOTHING_BUILT, "buy_tech_error")
	check(not e.buy_tech(lore), "buy_tech refuses")


func test_under_anarchy_discarding_and_ending_the_turn_work() -> void:
	var e := fallen_engine()
	var card: int = e.zone("hand").cards[0].uid
	eq(e.discard_error(card), "", "discard_error")
	eq(e.end_turn_error(), "", "end_turn_error")


# --- AC4: Anarchy's upkeep and its end (counters: 155) ---

func test_each_turn_of_anarchy_takes_a_pop() -> void:
	var e := fallen_engine()
	var home := home_uid(e)
	eq(e.pop(home), 6, "no Anarchy upkeep the turn it falls at the limit")
	e.end_turn()
	eq(e.pop(home), 5, "Anarchy ⟳ −1 pop")
	e.end_turn()
	eq(e.pop(home), 4, "−1 pop again")


func test_when_anarchy_burns_out_the_government_choice_is_owed() -> void:
	var e := fallen_engine()
	var recorded := record_messages(e)
	var anarchy_uid: int = e.anarchy()
	for i in 3:
		e.end_turn()
	eq(ruling(e), "anarchy", "3 turns ended: still Anarchy")
	e.end_turn()
	eq(e.anarchy(), -1, "the 4th: no anarchy")
	check(e.zone("removed").find(anarchy_uid) != null, "the Anarchy card is removed")
	eq(e.pending().get("kind"), GameEngine.PENDING_GOVERNMENT, "a government is to be chosen (154)")
	eq(e.turn, 5, "owed at the end of turn 5 (155)")
	check(e.choose_government(uid_of(e.zone("governments"), "chiefs")), "choose Chiefs")
	eq([e.turn, ruling(e)], [6, "chiefs"], "Chiefs restores order and turn 6 starts")
	eq(e.resources.get("unrest"), 2, "min(5, 5 / 2)")
	check_noticed(recorded, "order returns", GameEngine.NOTICE_INFO)
	check_noticed(recorded, "Chiefs rules.", GameEngine.NOTICE_INFO)


func test_burning_out_keeps_unrest_below_half_the_limit() -> void:
	var e := fallen_engine()
	e.set_unrest(1)  # 1 counter left
	e.end_turn()
	check(e.choose_government(uid_of(e.zone("governments"), "chiefs")), "burned out, Chiefs chosen")
	eq(ruling(e), "chiefs", "Chiefs rules")
	eq(e.resources.get("unrest"), 1, "min(1, 2)")


# --- AC5: a new era stirs unrest ---

func test_a_new_era_adds_era_unrest_up_to_the_limit() -> void:
	var e := anarchy_engine()
	var recorded := record_messages(e)
	e.resources["unrest"] = 3
	var dawn := put_in_hand(e, "dawn")
	check(e.play_card(dawn), "Dawn: %s" % e.play_error(dawn))
	eq(e.resources.get("unrest"), 5, "3 + 3, capped at 5")
	check_noticed(recorded, "unrest", GameEngine.NOTICE_CAUTION)
	e.end_turn()
	eq(ruling(e), "anarchy", "the next turn falls into Anarchy")


func test_era_unrest_0_adds_nothing() -> void:
	var e := anarchy_engine({"era_unrest": 0})
	e.resources["unrest"] = 3
	e.play_card(put_in_hand(e, "dawn"))
	eq(e.resources.get("unrest"), 3, "no era unrest")
