extends "res://tests/lib/test_case.gd"
## The insight_per_gain modifier (backlog 157): each gain of insight (a play, an upkeep, one gain_per_tag,
## gain_per_keyword or trade) adds the summed modifier, never below 0. Fixtures: Creed (government, insight −1), Dogma
## (tech, insight −1), Lecture (+3 insight), Spark (+1 insight), Academy (building, ⟳ +3 insight), Survey (3 insight per
## city), Prospect (3 insight per mountain territory), Barter (insight trade: 3 × ⌊√cities⌋), Forget (−2 insight),
## Reap (+3 food).

const CREED := {"id": "creed", "name": "Creed", "type": "government", "modifiers": {"insight_per_gain": -1}}
const DOGMA := {"id": "dogma", "name": "Dogma", "type": "tech", "cost": {"insight": 1},
	"modifiers": {"insight_per_gain": -1}}
const BOON := {"id": "boon", "name": "Boon", "type": "tech", "cost": {"insight": 1}, "modifiers": {"insight_per_gain": 1}}
const LECTURE := {"id": "lecture", "name": "Lecture", "type": "action",
	"effects": [{"op": "gain", "resource": "insight", "amount": 3}]}
const SPARK := {"id": "spark", "name": "Spark", "type": "action",
	"effects": [{"op": "gain", "resource": "insight", "amount": 1}]}
const ACADEMY := {"id": "academy", "name": "Academy", "type": "building",
	"effects": [{"op": "gain", "resource": "insight", "amount": 3, "trigger": "upkeep"}]}
const SURVEY := {"id": "survey", "name": "Survey", "type": "action",
	"effects": [{"op": "gain_per_tag", "resource": "insight", "amount": 3, "tag": "city"}]}
const PROSPECT := {"id": "prospect", "name": "Prospect", "type": "action",
	"effects": [{"op": "gain_per_keyword", "resource": "insight", "amount": 3, "keywords": ["mountain"]}]}
const BARTER := {"id": "barter", "name": "Barter", "type": "action",
	"effects": [{"op": "trade", "resource": "insight", "per_root_city": 3, "pop_per": 100, "min_cities": 1}]}
const FORGET := {"id": "forget", "name": "Forget", "type": "action",
	"effects": [{"op": "lose", "resource": "insight", "amount": 2}]}
const REAP := {"id": "reap", "name": "Reap", "type": "action",
	"effects": [{"op": "gain", "resource": "food", "amount": 3}]}
const FIXTURES := [CREED, DOGMA, BOON, LECTURE, SPARK, ACADEMY, SURVEY, PROSPECT, BARTER, FORGET, REAP]


## A game ruled by government (TEST_GOVS' Council has no modifiers), 10 food, wealth and insight, Hills in the
## territory deck, the fixtures loaded.
func creed_engine(government := "creed") -> GameEngine:
	var r := fixture_load(FIXTURES, [TEST_GOVS])
	check(r.errors.is_empty(), "test data should load: %s" % [r.errors])
	var errors: Array[String] = []
	var warnings: Array[String] = []
	var o := {"starting": {"resources": {"food": 10, "wealth": 10, "insight": 10}, "tableau": ["capital"],
		"territory": "homeland", "government": government}, "territory_deck": {"hills": 1}}
	var config := DataLoader.parse_config(raw_config({"farm": 10}, o), resources(), r.cards, "config.json", errors,
		warnings)
	check(errors.is_empty(), "config should load: %s" % [errors])
	var e := GameEngine.new(r.cards, config)
	e.new_game(1)
	return e


## How much resource playing id from hand changes it by; the outcome's gained is checked to match.
func play_change(e: GameEngine, id: String, resource := "insight") -> int:
	var before: int = e.resources.get(resource, 0)
	var outcomes: Array = []
	e.card_played.connect(func(o): outcomes.append(o))
	var uid := put_in_hand(e, id)
	check(e.play_card(uid), "play %s: %s" % [id, e.play_error(uid)])
	var change: int = e.resources.get(resource, 0) - before
	if change >= 0 and outcomes.size() == 1:
		eq(outcomes[0].gained.get(resource, 0), change, "%s: the outcome's gained" % id)
	return change


# --- AC1: the key and its text ---

func test_insight_per_gain_loads_with_its_text() -> void:
	var r := fixture_load(FIXTURES, [TEST_GOVS])
	eq(r.errors, [] as Array[String], "errors")
	eq(r.warnings, [] as Array[String], "warnings")
	if not r.cards.has("creed"):
		return
	eq(r.cards.creed.modifiers, {"insight_per_gain": -1}, "Creed's modifiers")
	check(r.cards.creed.rules_text(r.cards).contains("Each insight gain −1"), "−1: %s" % r.cards.creed.rules_text(r.cards))
	check(r.cards.boon.rules_text(r.cards).contains("Each insight gain +1"), "+1: %s" % r.cards.boon.rules_text(r.cards))


func test_insight_per_gain_validation() -> void:
	var zero := {"id": "x", "name": "X", "type": "government", "modifiers": {"insight_per_gain": 0}}
	has_msg(fixture_load([zero], [TEST_GOVS]).errors, "modifiers.insight_per_gain")


# --- AC2: each insight gain is lowered ---

func test_a_gain_of_3_insight_adds_2_and_a_gain_of_1_adds_0() -> void:
	var e := creed_engine()
	eq(play_change(e, "lecture"), 2, "Lecture's +3 under Creed")
	var f := creed_engine()
	eq(play_change(f, "spark"), 0, "Spark's +1 under Creed: never below 0")


func test_an_upkeep_gain_of_insight_is_lowered_too() -> void:
	var e := creed_engine()
	build_on(e, home_uid(e), ["academy"])
	var insight: int = e.resources.insight
	e.end_turn()
	eq(e.resources.insight, insight + 2, "Academy ⟳ +3 under Creed")


func test_the_log_reports_what_was_added() -> void:
	var e := creed_engine()
	play_change(e, "lecture")
	check(e.state.log_lines.any(func(l): return l.contains("Lecture: +2 insight")), "log: %s" % [e.state.log_lines.slice(-3)])


# --- AC3: modifiers add up; per-count gains are one gain ---

func test_two_modifiers_add_up() -> void:
	var e := creed_engine()
	e.create_card("dogma", "researched", null)
	eq(play_change(e, "lecture"), 1, "3 − 1 − 1")


func test_gain_per_tag_per_keyword_and_trade_are_one_gain_each() -> void:
	eq(play_change(creed_engine(), "survey"), 2, "gain_per_tag: 3 for 1 city, − 1")
	var prospect := creed_engine()
	settle(prospect, ["hills"])
	eq(play_change(prospect, "prospect"), 2, "gain_per_keyword: 3 for 1 mountain, − 1")
	eq(play_change(creed_engine(), "barter"), 2, "trade: 3 × ⌊√1⌋, − 1")


# --- AC4: the forecast; other gains and losses unchanged ---

func test_the_forecast_reflects_the_modifier() -> void:
	var e := creed_engine()
	build_on(e, home_uid(e), ["academy"])
	eq(e.upkeep_forecast().insight, 2, "Academy ⟳ +3 under Creed")


func test_other_resources_and_insight_losses_are_unchanged() -> void:
	eq(play_change(creed_engine(), "reap", "food"), 3, "+3 food")
	eq(play_change(creed_engine(), "forget"), -2, "−2 insight")
	eq(play_change(creed_engine("council"), "lecture"), 3, "no modifier: +3")
