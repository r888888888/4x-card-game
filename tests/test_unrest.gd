extends "res://tests/lib/test_case.gd"
## Unrest (backlog 144): a built-in resource, on when config resources lists it, that gain caps at unrest_limit()
## (the ruling government's unrest_limit plus the unrest_limit modifier; -1 for none). It can't be paid. The forecast
## and the top bar show it; ScriptedBot plays around the limit. Local fixtures, loaded with TEST_CARDS and TEST_GOVS:
## Chiefs (government, unrest limit 5), Riot (action, +3 unrest), Colonist (+1), Feast (−1), Brazier (building,
## ⟳ +1 unrest); the modifier cards Altar (+1 limit) and Curse (−10) are in MODIFIER_FIXTURES. Engines are held as
## Object so the file parses before the API.

var BOT: Variant = load("res://sim/bot.gd")
const RESOURCES: Array[String] = ["food", "wealth", "insight", "unrest"]
const CHIEFS := {"id": "chiefs", "name": "Chiefs", "type": "government", "unrest_limit": 5}
const RIOT := {"id": "riot", "name": "Riot", "type": "action",
	"effects": [{"op": "gain", "resource": "unrest", "amount": 3}]}
const COLONIST := {"id": "colonist", "name": "Colonist", "type": "action",
	"effects": [{"op": "gain", "resource": "unrest", "amount": 1}]}
const FEAST := {"id": "feast", "name": "Feast", "type": "action",
	"effects": [{"op": "lose", "resource": "unrest", "amount": 1}]}
const BRAZIER := {"id": "brazier", "name": "Brazier", "type": "building",
	"effects": [{"op": "gain", "resource": "unrest", "amount": 1, "trigger": "upkeep"}]}
const FIXTURES := [CHIEFS, RIOT, COLONIST, FEAST, BRAZIER]
const ALTAR := {"id": "altar", "name": "Altar", "type": "building", "modifiers": {"unrest_limit": 1}}
const CURSE := {"id": "curse", "name": "Curse", "type": "building", "modifiers": {"unrest_limit": -10}}
const MODIFIER_FIXTURES := [ALTAR, CURSE]
const POP := {"start": 2, "food_upkeep": 0, "vp_per_pop": 0, "famine": FAMINE}
const UNPAYABLE := "unrest can't be paid (it is only gained and lost)"


## Loader result {cards, errors, warnings} for TEST_CARDS, TEST_GOVS, FIXTURES and extra, with unrest a resource.
func load_cards(extra: Array) -> Dictionary:
	var errors: Array[String] = []
	var warnings: Array[String] = []
	var cards := DataLoader.parse_cards({"cards": TEST_CARDS.cards + TEST_GOVS + FIXTURES + extra}, RESOURCES,
		"cards.json", errors, warnings, keywords())
	return {"cards": cards, "errors": errors, "warnings": warnings}


## A game on load_cards(extra) with unrest listed, gov ruling ("" for none), population on (home pop 2), 10 food and
## unrest on hand, main deck deck; overrides replace config keys.
func unrest_engine(gov: String, unrest: int, extra := [], deck := {"farm": 10}, overrides := {}) -> Object:
	var r := load_cards(extra)
	check(r.errors.is_empty(), "test cards should load: %s" % [r.errors])
	var starting := {"resources": {"food": 10, "unrest": unrest}, "tableau": ["capital"], "territory": "homeland"}
	if gov != "":
		starting["government"] = gov
	var o := {"resources": RESOURCES, "starting": starting, "population": POP}
	o.merge(overrides, true)
	var listed: Array[String] = []
	listed.assign(o.resources)  # the loader's resource list is the config's, as DataLoader.load_all reads it
	var errors: Array[String] = []
	var warnings: Array[String] = []
	var config := DataLoader.parse_config(raw_config(deck, o), listed, r.cards, "config.json", errors, warnings)
	check(errors.is_empty(), "test config should load: %s" % [errors])
	var e := GameEngine.new(r.cards, config)
	e.new_game(1)
	return e


## Plays hand card uid in e and returns its card_played outcome ({} if it didn't play).
func play_outcome(e: Object, uid: int) -> Dictionary:
	var outcomes: Array[Dictionary] = []
	var record := func(o: Dictionary): outcomes.append(o)
	e.card_played.connect(record)
	check(e.play_card(uid), "play: %s" % e.play_error(uid))
	e.card_played.disconnect(record)
	return outcomes[0] if not outcomes.is_empty() else {}


# --- AC1: the government field, the modifier key and their text ---

func test_a_government_unrest_limit_loads_and_shows_in_its_text() -> void:
	var r := load_cards([])
	eq(r.errors, [] as Array[String], "errors")
	eq(r.warnings, [] as Array[String], "warnings")
	var chiefs: CardDef = r.cards.chiefs
	eq(chiefs.get("unrest_limit"), 5, "Chiefs' unrest_limit")
	check(chiefs.rules_text(r.cards).contains("Unrest limit 5."), "face: %s" % chiefs.rules_text(r.cards))
	check(chiefs.rules_tooltip(r.cards).contains("Unrest limit 5."), "tooltip: %s" % chiefs.rules_tooltip(r.cards))


func test_unrest_limit_validation() -> void:
	var message := "cards.json: card 'x': 'unrest_limit' must be an integer >= 1"
	check_cases([
		["0", [{"id": "x", "name": "X", "type": "government", "unrest_limit": 0}], message, "one_error"],
		["-1", [{"id": "x", "name": "X", "type": "government", "unrest_limit": -1}], message, "one_error"],
		["a string", [{"id": "x", "name": "X", "type": "government", "unrest_limit": "5"}], message, "one_error"],
		["on a building", [{"id": "x", "name": "X", "type": "building", "unrest_limit": 5}],
			"'unrest_limit' only applies to governments (ignored)", "warning_only"],
	], load_cards)


func test_the_unrest_limit_modifier_loads_with_its_text() -> void:
	var r := load_cards(MODIFIER_FIXTURES + [{"id": "x", "name": "X", "type": "building", "modifiers": {"unrest_limit": -1}}])
	eq(r.errors, [] as Array[String], "errors")
	if not r.cards.has("altar"):
		return
	eq(r.cards.altar.modifiers, {"unrest_limit": 1}, "Altar's modifiers")
	eq(r.cards.altar.rules_text(r.cards), "Unrest limit +1", "Altar's face")
	eq(r.cards.x.rules_text(r.cards), "Unrest limit −1", "a negative modifier")


# --- AC2: unrest_limit() ---

func test_the_unrest_limit_is_the_governments() -> void:
	var e := unrest_engine("chiefs", 0)
	eq(e.unrest_limit(), 5, "Chiefs' limit")


func test_a_working_modifier_adds_to_the_limit_and_an_idle_one_does_not() -> void:
	var e := unrest_engine("chiefs", 0, MODIFIER_FIXTURES)
	var home := home_uid(e)
	build_on(e, home, ["lookout", "lookout", "altar"])
	check(e.is_idle(uid_of(e.zone("tableau"), "altar")), "Altar is the third building on 2 pop")
	eq(e.unrest_limit(), 5, "idle Altar: 5")
	check(e.grow(home), "grow: %s" % e.grow_error(home))
	eq(e.unrest_limit(), 6, "working Altar: 5 + 1")


func test_the_unrest_limit_never_goes_below_0() -> void:
	var e := unrest_engine("chiefs", 0, MODIFIER_FIXTURES)
	build_on(e, home_uid(e), ["curse"])
	eq(e.unrest_limit(), 0, "5 − 10, floored at 0")


func test_no_unrest_limit_without_a_government_that_sets_one() -> void:
	for gov in ["council", ""]:
		var e := unrest_engine(gov, 0)
		eq(e.unrest_limit(), -1, "%s: no limit" % gov)


## Resolved at the red checkpoint: a game whose config doesn't list unrest has no limit, and no counter in the bar.
func test_without_unrest_in_the_config_there_is_no_limit() -> void:
	var e := unrest_engine("chiefs", 0, [], {"farm": 10}, {"resources": ["food", "wealth", "insight"],
		"starting": {"resources": {"food": 10}, "tableau": ["capital"], "territory": "homeland", "government": "chiefs"}})
	eq(e.unrest_on(), false, "unrest_on")
	eq(e.unrest_limit(), -1, "no limit while unrest is off")
	eq(unrest_engine("chiefs", 0).unrest_on(), true, "unrest_on when listed")


# --- AC3: gain stops at the limit ---

func test_gaining_unrest_stops_at_the_limit() -> void:
	var e := unrest_engine("chiefs", 4)
	var o := play_outcome(e, put_in_hand(e, "riot"))
	eq(e.resources.get("unrest"), 5, "4 + 3, capped at 5")
	eq(o.get("gained"), {"unrest": 1}, "the outcome reports what was added")


func test_gaining_unrest_without_a_limit_is_uncapped() -> void:
	var e := unrest_engine("council", 4)
	play_outcome(e, put_in_hand(e, "riot"))
	eq(e.resources.get("unrest"), 7, "4 + 3")


func test_losing_unrest_never_goes_below_0() -> void:
	var e := unrest_engine("chiefs", 0)
	play_outcome(e, put_in_hand(e, "feast"))
	eq(e.resources.get("unrest"), 0, "0 − 1, floored at 0")


# --- AC4: unrest can't be paid ---

func test_unrest_cant_be_paid() -> void:
	check_cases([
		["in a cost", [{"id": "x", "name": "X", "type": "action", "cost": {"unrest": 1}}],
			"cards.json: card 'x': cost: " + UNPAYABLE, "one_error"],
		["in a civilization discount", [{"id": "x", "name": "X", "type": "civilization",
			"discounts": [{"type": "tech", "unrest": 1}]}], "cards.json: card 'x': discounts[0]: " + UNPAYABLE, "one_error"],
		["traded", [{"id": "x", "name": "X", "type": "action", "effects": [
			{"op": "trade", "resource": "unrest", "per_root_city": 2, "pop_per": 5, "min_cities": 2}]}],
			"cards.json: card 'x': effects[0]: " + UNPAYABLE, "one_error"],
	], load_cards)


func test_unrest_cant_be_famine_relief() -> void:
	var errors: Array[String] = []
	var warnings: Array[String] = []
	var famine := {"card": "famine", "max_counters": 3, "relief": {"unrest": 1}}
	var raw := raw_config({"farm": 1}, {"resources": RESOURCES, "population": POP.merged({"famine": famine}, true)})
	DataLoader.parse_config(raw, RESOURCES, load_cards([]).cards, "config.json", errors, warnings)
	eq(errors, ["config.json: population.famine.relief: " + UNPAYABLE] as Array[String], "errors")


# --- AC5: the forecast and the top bar ---

func test_the_forecast_includes_unrest() -> void:
	var e := unrest_engine("chiefs", 2)
	build_on(e, home_uid(e), ["brazier"])
	eq(e.upkeep_forecast().get("unrest"), 1, "Brazier ⟳ +1 unrest")


## The one visible label under root whose text starts with prefix, or null.
func shown_label(root: Node, prefix: String) -> Label:
	for node in root.find_children("*", "Label", true, false):
		var label := node as Label
		if label.is_visible_in_tree() and label.text.begins_with(prefix):
			return label
	return null


## Opens main on an unrest_engine game with gov ruling and a Brazier at home; unrest set to unrest.
func open_unrest_main(gov: String, unrest: int, overrides := {}) -> Node:
	Game.engine = unrest_engine(gov, 0, [], {"farm": 10}, overrides)
	var main := open_main()
	main.start_game(1)
	build_on(Game.engine, home_uid(Game.engine), ["brazier"])
	set_unrest(unrest)
	return main


## Sets Game.engine's unrest and tells the UI.
func set_unrest(n: int) -> void:
	Game.engine.resources["unrest"] = n
	Game.engine.changed.emit()


func test_the_top_bar_shows_unrest_out_of_the_limit_and_floats_its_change() -> void:
	var real := Game.engine
	var main := open_unrest_main("chiefs", 2)
	await wait_frames()
	var counter := shown_label(main, "Unrest:")
	check(counter != null, "an Unrest counter in the top bar")
	if counter != null:
		eq(counter.text, "Unrest: 2 / 5 (+1)", "unrest, the limit and the forecast")
		eq(counter.get_theme_color("font_color"), load("res://ui/palette.gd").get_script_constant_map().get("UNREST"),
			"below the limit: Palette.UNREST")
	set_unrest(5)
	await wait_frames()
	check(shown_label(main, "+3 unrest") != null, "a +3 unrest token floats up")
	if counter != null:
		eq(counter.get_theme_color("font_color"), Palette.WARN, "at the limit: the warning colour")
	close_main(main)
	Game.engine = real


func test_the_top_bar_shows_unrest_alone_without_a_limit() -> void:
	var real := Game.engine
	var main := open_unrest_main("council", 2)
	await wait_frames()
	var counter := shown_label(main, "Unrest:")
	check(counter != null, "an Unrest counter in the top bar")
	if counter != null:
		eq(counter.text, "Unrest: 2 (+1)", "unrest and the forecast, no limit")
	close_main(main)
	Game.engine = real


func test_the_top_bar_has_no_unrest_counter_when_unrest_is_off() -> void:
	var real := Game.engine
	Game.engine = make_engine({"farm": 10})
	var main := open_main()
	main.start_game(1)
	await wait_frames()
	check(shown_label(main, "Score:") != null, "the top bar is up")
	check(shown_label(main, "Unrest:") == null, "no Unrest counter")
	close_main(main)
	Game.engine = real


# --- AC6: the bot plays around the limit ---

## An unrest_engine game with gov ruling, unrest on hand and a hand of unplayable Pioneers (no frontier) plus card_id.
func bot_engine(gov: String, unrest: int, card_id: String) -> Object:
	var e := unrest_engine(gov, unrest, [], {"pioneer": 10}, {"territory_deck": {"grassland": 2}})
	put_in_hand(e, card_id)
	return e


func test_the_bot_doesnt_gain_unrest_that_would_reach_the_limit() -> void:
	for strategy in BOT.STRATEGIES:
		var near := bot_engine("chiefs", 3, "colonist")
		BOT.take_turn(near, strategy)
		eq(uid_of(near.zone("hand"), "colonist") != -1, true, "%s at 3 of 5: 3 + 0 + 1 + 1 reaches 5, Colonist kept" % strategy)
		eq(near.resources.get("unrest"), 3, "%s at 3 of 5: unrest unchanged" % strategy)
		var calm := bot_engine("chiefs", 2, "colonist")
		BOT.take_turn(calm, strategy)
		eq(calm.resources.get("unrest"), 3, "%s at 2 of 5: 2 + 0 + 1 + 1 < 5, Colonist played" % strategy)
		var unlimited := bot_engine("council", 3, "colonist")
		BOT.take_turn(unlimited, strategy)
		eq(unlimited.resources.get("unrest"), 4, "%s with no limit: Colonist played" % strategy)


func test_the_bot_doesnt_calm_unrest_far_below_the_limit() -> void:
	for strategy in BOT.STRATEGIES:
		var low := bot_engine("chiefs", 1, "feast")
		BOT.take_turn(low, strategy)
		eq(uid_of(low.zone("hand"), "feast") != -1, true, "%s at 1 of 5: 1 + 0 + 1 < 3, Feast kept" % strategy)
		var high := bot_engine("chiefs", 2, "feast")
		BOT.take_turn(high, strategy)
		eq(high.resources.get("unrest"), 1, "%s at 2 of 5: 2 + 0 + 1 reaches 3, Feast played" % strategy)
