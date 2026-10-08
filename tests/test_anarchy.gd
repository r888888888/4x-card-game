extends "res://tests/lib/anarchy_case.gd"
## Anarchy (backlog 145): a turn that starts with unrest at the limit falls into Anarchy, the config's unrest.anarchy
## government. While it rules only action cards play (384), nothing is grown, bought or researched, and when it ends a
## government is chosen from the government deck (154; its length: 384, test_anarchy_length.gd). It eats no stores,
## sets no action limit and can't be bought out (384). Each new era adds era_unrest. Fixtures: tests/lib/anarchy_case.gd,
## and Levy (a unit).

const LEVY := {"id": "levy", "name": "Levy", "type": "unit", "cost": {"food": 1}, "strength": 2}


# --- AC1: the config block ---

func test_the_unrest_block_loads_with_its_defaults() -> void:
	var raw := anarchy_raw()
	raw.unrest = {"anarchy": "anarchy", "anarchy_turns": 3}
	check_loads([
		["normalized, era_unrest 0 by default (384: anarchy_turns, no max_counters or allowed_tag)", raw,
			{"config.unrest": {"anarchy": "anarchy", "anarchy_turns": 3, "era_unrest": 0}}],
	], raw_config_load)


func test_unrest_block_validation() -> void:
	var with_block := func(block: Dictionary) -> Dictionary: return anarchy_raw(block)
	check_cases([
		["anarchy not an event", with_block.call({"anarchy": "farm"}), ["config.json: unrest.anarchy", "farm", "event"]],
		["anarchy unknown", with_block.call({"anarchy": "nobody"}), ["config.json: unrest.anarchy:", "nobody"]],
		["era_unrest -1", with_block.call({"era_unrest": -1}), ["config.json: unrest.era_unrest:", ">= 0"]],
		["anarchy_turns missing (384)", with_block.call({"anarchy_turns": null}), ["config.json: unrest.anarchy_turns"]],
		["anarchy_turns 0 (384)", with_block.call({"anarchy_turns": 0}), ["config.json: unrest.anarchy_turns", ">= 1"]],
		["anarchy_turns a fraction (384)", with_block.call({"anarchy_turns": 2.5}), ["config.json: unrest.anarchy_turns"]],
		["anarchy_turns a string (384)", with_block.call({"anarchy_turns": "3"}), ["config.json: unrest.anarchy_turns"]],
		["without unrest in resources", anarchy_raw({}, {"resources": ["food", "wealth", "insight"],
			"starting": {"resources": {"food": 2}, "tableau": ["capital"], "territory": "homeland", "government": "chiefs"}}),
			["config.json: unrest:", "resources"]],
		["fallback is no longer read", with_block.call({"fallback": "chiefs"}),
			"config.json: unrest: unknown field 'fallback'", "warning_only"],
		["relief is no longer read", with_block.call({"relief": {"wealth": 6}}),
			"config.json: unrest: unknown field 'relief'", "warning_only"],
		["max_counters is no longer read (384)", with_block.call({"max_counters": 4}),
			"config.json: unrest: unknown field 'max_counters'", "warning_only"],
		["drain_pct is no longer read (384)", with_block.call({"drain_pct": 20}),
			"config.json: unrest: unknown field 'drain_pct'", "warning_only"],
		["allowed_tag is no longer read (384)", with_block.call({"allowed_tag": "order"}),
			"config.json: unrest: unknown field 'allowed_tag'", "warning_only"],
	], raw_config_load)


# --- AC2: falling into Anarchy ---

func test_a_turn_starting_at_the_limit_falls_into_anarchy() -> void:
	var e := anarchy_engine()
	var recorded := record_messages(e)
	var deck_before: int = e.zone("deck").size()
	e.resources["unrest"] = 5
	e.end_turn()
	check(e.anarchy() != -1, "Anarchy rules")
	check(uid_of(e.zone("governments"), "chiefs") != -1, "Chiefs goes to the government deck (154)")
	eq(e.zone("deck").size(), deck_before, "not into the deck (a full hand draws none)")
	check_noticed(recorded, "Anarchy!", GameEngine.NOTICE_URGENT)


func test_no_anarchy_ahead_while_anarchy_rules() -> void:
	var e := fallen_engine()
	e.resources["unrest"] = 9
	eq(e.anarchy_ahead(), false, "Anarchy sets no limit to reach (228)")


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

## 384 AC3: any action card plays under Anarchy, tagged order or not.
func test_under_anarchy_action_cards_play() -> void:
	var e := fallen_engine()
	var forager := put_in_hand(e, "forager")
	eq(e.play_error(forager), "", "Forager, an untagged action")
	check(e.play_card(forager), "Forager plays")
	var feast := put_in_hand(e, "feast")
	eq(e.play_error(feast), "", "Feast, an order action")
	check(e.play_card(feast), "Feast plays")
	eq(e.resources.get("unrest"), 3, "5 − 2")


## 384 AC3: a unit, a building or a government in hand can't be played under Anarchy, and the refusal changes nothing.
func test_under_anarchy_other_cards_cant_be_played() -> void:
	var e := anarchy_engine({}, {}, [LEVY])
	e.resources["unrest"] = 5
	e.end_turn()
	check(e.anarchy() != -1, "precondition: Anarchy rules")
	for id in ["levy", "farm", "kings"]:
		var uid := put_in_hand(e, id)
		eq(e.play_error(uid), ONLY_ACTIONS, id)
		var before := e.state.copy()
		check(not e.play_card(uid), "%s: play_card refuses" % id)
		eq(state_diff(e.state, before), "", "%s: a refusal changes nothing" % id)


func test_under_anarchy_nothing_is_grown_bought_or_researched() -> void:
	var e := fallen_engine()
	eq(e.buy_error("farm"), NOTHING_BUILT, "buy_error")
	check(not e.buy("farm"), "buy refuses")
	var lore := uid_of(e.zone("research_deck"), "lore")
	eq(e.buy_tech_error(lore), NOTHING_BUILT, "buy_tech_error")
	check(not e.buy_tech(lore), "buy_tech refuses")


## 288 AC4: nothing can be learned or bought under Anarchy, so its lamps stay dark; once a government rules they light
## for what wasn't seen.
func test_under_anarchy_the_ready_lamps_stay_dark_until_a_government_rules() -> void:
	var e := fallen_engine()
	eq(e.ready_techs(), [] as Array[String], "no tech under Anarchy")
	eq(e.ready_supply(), [] as Array[String], "no pile under Anarchy")
	check(not e.tech_lamp() and not e.supply_lamp(), "both lamps dark")
	outlast_anarchy(e)
	check(e.choose_government(uid_of(e.zone("governments"), "chiefs")), "Chiefs chosen")
	e.resources["insight"] = 10
	e.resources["wealth"] = 10
	check(e.tech_lamp(), "Lore learnable and unseen: lit")
	check(e.supply_lamp(), "Farm buyable and unseen: lit")


## 295 AC2: under Anarchy a building can't be built from the build menu, as it can't be played.
func test_under_anarchy_nothing_is_built_from_the_build_menu() -> void:
	var e := anarchy_engine({}, {"build_menu": {"well": {}}, "supply": null})
	e.resources["unrest"] = 5
	e.end_turn()
	check(e.anarchy() != -1, "precondition: Anarchy rules")
	eq(e.build_error("well", home_uid(e)), ONLY_ACTIONS, "build_error")
	check(not e.build("well", home_uid(e)), "build refuses")


## 384 AC6: Anarchy sets no action limit: with no government, cards play without one.
func test_anarchy_sets_no_action_limit() -> void:
	var e := fallen_engine()
	eq([e.actions_per_turn(), e.actions_left()], [-1, -1], "unlimited")
	var feasts := [put_in_hand(e, "feast"), put_in_hand(e, "feast")]
	for feast in feasts:
		check(e.play_card(feast), "Feast: %s" % e.play_error(feast))


func test_under_anarchy_discarding_and_ending_the_turn_work() -> void:
	var e := fallen_engine()
	var card: int = e.zone("hand").cards[0].uid
	eq(e.discard_error(card), "", "discard_error")
	eq(e.end_turn_error(), "", "end_turn_error")


# --- AC4: Anarchy's upkeep and its end (its length: 384) ---

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
	outlast_anarchy(e)
	check(e.zone("removed").find(anarchy_uid) != null, "the Anarchy card is removed")
	eq(e.pending().get("kind"), GameEngine.PENDING_GOVERNMENT, "a government is to be chosen (154)")
	check(e.choose_government(uid_of(e.zone("governments"), "chiefs")), "choose Chiefs")
	eq(ruling(e), "chiefs", "Chiefs restores order")
	check_noticed(recorded, "order returns", GameEngine.NOTICE_INFO)
	check_noticed(recorded, "Chiefs rules.", GameEngine.NOTICE_INFO)


# --- 384 AC4: no buying out ---

func test_there_is_no_buying_out_of_anarchy() -> void:
	var e := fallen_engine()
	e.end_turn()  # its second turn
	e.set_unrest(4)
	e.resources["wealth"] = 30
	var actions: Array = e.legal_actions().map(func(entry): return entry[0])
	check(not actions.has("restore_order"), "no action ends Anarchy: %s" % [actions])
	e.end_turn()
	eq([e.anarchy() != -1, e.resources.wealth], [true, 30], "Anarchy goes on, nothing paid")
	var methods: Array = e.get_method_list().map(func(m): return m.name)
	for gone in ["restore_order", "restore_order_error", "order_relief"]:
		check(not methods.has(gone), "the engine has no %s" % gone)


## 384 AC4: the board has no Restore order button.
func test_the_board_has_no_restore_order_button() -> void:
	await with_main(fallen_engine(), func(main: Node):
		await wait_frames()
		var restore := main.find_children("*", "Button", true, false).filter(
			func(b: Button): return b.text.begins_with("Restore order"))
		eq(restore.size(), 0, "no Restore order button"))


# --- 384 AC5: no drain ---

## A game where nothing changes food or wealth at upkeep: no Capital (⟳ +2 food) on the tableau, no food upkeep.
func still_stores_engine() -> GameEngine:
	return anarchy_engine({"drain_pct": 20}, {"starting": {"resources": {"food": 10, "wealth": 10, "insight": 10},
		"tableau": [], "territory": "homeland", "government": "chiefs"}})


func test_anarchy_eats_no_stores_even_with_a_retired_drain_pct() -> void:
	var e := still_stores_engine()
	e.resources["unrest"] = 5
	e.end_turn()
	check(e.anarchy() != -1, "precondition: Anarchy rules")
	eq([e.resources.food, e.resources.wealth], [10, 10], "the turn it falls: nothing eaten")
	eq([e.upkeep_forecast().get("food", 0), e.upkeep_forecast().get("wealth", 0)], [0, 0], "upkeep_forecast: no loss")
	eq([e.turn_forecast().get("food", 0), e.turn_forecast().get("wealth", 0)], [0, 0], "turn_forecast: no loss")
	e.end_turn()
	eq([e.resources.food, e.resources.wealth], [10, 10], "its second turn: nothing eaten")


func test_a_pending_revolution_forecasts_no_drain() -> void:
	var e := still_stores_engine()
	e.resources["unrest"] = 2
	check(e.revolt(), "revolt: %s" % e.revolt_error())
	eq([e.upkeep_forecast().get("food", 0), e.upkeep_forecast().get("wealth", 0)], [0, 0], "upkeep_forecast: no loss")
	eq([e.turn_forecast().get("food", 0), e.turn_forecast().get("wealth", 0)], [0, 0], "turn_forecast: no loss")


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
	check(e.anarchy() != -1, "the next turn falls into Anarchy")


func test_turn_forecast_counts_the_unrest_of_an_era_arriving_at_the_next_turn_start() -> void:  # 309
	var e := anarchy_engine({}, {"era_unlocks": {"2": {"wealth": 12}}})
	eq(e.era(), 1, "era 1 at the start")
	e.resources["unrest"] = 0
	e.resources["wealth"] = 12
	var upkeep := e.upkeep_forecast()
	var f := e.turn_forecast()
	eq(f.get("unrest"), upkeep.get("unrest", 0) + 3, "era 2 arrives at the next start: +3 unrest")
	eq(e.era(), 1, "still era 1")


func test_era_unrest_0_adds_nothing() -> void:
	var e := anarchy_engine({"era_unrest": 0})
	e.resources["unrest"] = 3
	e.play_card(put_in_hand(e, "dawn"))
	eq(e.resources.get("unrest"), 3, "no era unrest")
