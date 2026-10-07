extends "res://tests/lib/anarchy_case.gd"
## Revolution (backlogs 148, 155): with a government ruling and no Anarchy you may revolt at any time; Anarchy falls at
## the next turn's start, before upkeep, with the unrest it has (its length: 384, test_anarchy_length.gd).
## The summary the civilization modal's confirmation shows (205). The upkeep forecast after a revolt leaves out the
## falling government (332). The bot's revolts: test_bot_lookahead.gd (159).
## Fixtures: tests/lib/anarchy_case.gd (Chiefs, limit 5; Kings, limit 7; TEST_GOVS' Council, no limit).


## An anarchy game with unrest set and governments created into the government deck (154).
func revolt_engine(unrest := 2, governments := []) -> GameEngine:
	var e := anarchy_engine()
	for id in governments:
		e.create_card(id, "discard", null)
	e.resources["unrest"] = unrest
	return e


# --- AC4: revolting at any time ---

func test_revolting_needs_no_event_and_changes_nothing_this_turn() -> void:
	var e := revolt_engine()
	var recorded := record_messages(e)
	var actions: int = e.actions_left()
	eq(e.revolt_error(), "", "revolt_error with Chiefs ruling and no event")
	check(e.revolt(), "revolt: %s" % e.revolt_error())
	eq([ruling(e), e.anarchy(), e.pending(), e.actions_left()], ["chiefs", -1, {}, actions],
		"Chiefs still rules, nothing owed, no action used")
	eq(card_ids(e.zone("governments")), [] as Array[String], "Chiefs hasn't fallen yet")
	check_noticed(recorded, "Revolution! Anarchy begins next turn.", GameEngine.NOTICE_URGENT)


func test_anarchy_falls_at_the_next_turns_start_before_upkeep() -> void:
	var e := revolt_engine()
	var home := home_uid(e)
	e.revolt()
	e.end_turn()
	check(e.anarchy() != -1, "Anarchy rules turn 2")
	check(uid_of(e.zone("governments"), "chiefs") != -1, "Chiefs went to the government deck")
	eq(e.pop(home), 5, "before upkeep: turn 2 has Anarchy's ⟳ −1 pop")


func test_revolt_error_names_each_reason_and_a_refusal_changes_nothing() -> void:
	var twice := revolt_engine()
	twice.revolt()
	eq(twice.revolt_error(), "A revolution is already under way.", "after a revolt this turn")
	var before := twice.state.copy()
	check(not twice.revolt(), "revolt refuses")
	eq(state_diff(twice.state, before), "", "a refusal changes nothing")
	eq(fallen_engine().revolt_error(), "Anarchy already rules.", "during Anarchy")
	var over := revolt_engine()
	over.is_over = true
	eq(over.revolt_error(), "The game is over.", "game over")


func test_revolt_waits_for_a_pending_discard() -> void:
	var e := revolt_engine()
	for i in e.config.hand_limit + 1 - e.zone("hand").size():
		put_in_hand(e, "farm")
	e.end_turn()  # the hand is over its limit: a discard is owed
	eq(e.revolt_error(), "Discard down to %d cards first." % e.config.hand_limit, "pending discard")


func test_bug_155_no_revolt_without_a_government_to_overthrow() -> void:
	var e := anarchy_engine({}, {"starting": {"resources": {"food": 10, "wealth": 10, "insight": 10},
		"tableau": ["capital"], "territory": "homeland"}})
	eq(ruling(e), "", "no government rules")
	eq(e.revolt_error(), "There is no government to overthrow.", "revolt_error")
	check(not e.revolt(), "revolt refuses")
	e.end_turn()
	eq([e.turn, e.anarchy(), e.pending()], [2, -1, {}], "no Anarchy, no government choice from an empty deck")


func test_without_an_unrest_block_there_is_no_revolution() -> void:
	var e := anarchy_engine({}, {"unrest": null})
	eq(e.revolt_error(), "Without unrest there is no revolution.", "revolt_error")
	check(not e.revolt(), "revolt refuses")


# --- The revolt field is gone (Design notes) ---

func test_retired_revolt_field_is_a_load_warning() -> void:
	check_cases([
		["an event's revolt", [{"id": "reform", "name": "Reform", "type": "event", "revolt": true}],
			"unknown field 'revolt'", "warning_only"],
	], fixture_load.bind([], RESOURCES))


# --- 205: the summary the confirmation shows (the board's Revolt button went to the civilization modal) ---

const SUMMARY := ["Anarchy falls at the start of next turn.",
	"It lasts until unrest reaches 0, with −1 unrest at the end of each of its turns.",
	"Only order cards can be played.", "Nothing can be grown, bought or researched.",
	"Each turn: trash 1 card, +1 per turn so far, from your hand, deck or discard (−1 unrest each).",
	"When it ends, choose a government from your government deck."]


func test_revolt_summary_describes_the_coming_anarchy_with_this_games_numbers() -> void:
	var e := anarchy_engine({"renewal": 1})
	e.resources["unrest"] = 3
	eq(e.revolt_summary(), SUMMARY, "the lines, in order: no actions, drain or buying order (384)")


func test_a_summary_leaves_out_what_the_config_lacks() -> void:
	var e := anarchy_engine({"renewal": null})
	e.resources["unrest"] = 3
	var lines: Array = e.revolt_summary()
	eq(lines, [SUMMARY[0], SUMMARY[1], SUMMARY[2], SUMMARY[3], SUMMARY[5]], "no renewal")


func test_no_summary_while_revolt_is_refused() -> void:
	var e := anarchy_engine({"renewal": 1})
	check(e.revolt(), "revolt")
	check(e.revolt_error() != "", "precondition: refused now")
	eq(e.revolt_summary(), [], "nothing to confirm")


func test_anarchy_id_names_the_configs_anarchy_government() -> void:
	var e := anarchy_engine()
	eq(e.anarchy_id(), "anarchy", "the config's unrest.anarchy (the revolution's confirmation shows its flavor, 205)")
	eq(make_engine({"farm": 5}).anarchy_id(), "", "none without an unrest block")


# --- 332: the upkeep forecast after a revolution leaves out the falling government ---

## Tithes (government, limit 5, ⟳ +3 wealth), Creed (government, limit 5, insight −1 per gain) and Academy (building,
## ⟳ +2 insight).
const TITHES := {"id": "tithes", "name": "Tithes", "type": "government", "unrest_limit": 5,
	"effects": [{"op": "gain", "resource": "wealth", "amount": 3, "trigger": "upkeep"}]}
const CREED := {"id": "creed", "name": "Creed", "type": "government", "unrest_limit": 5,
	"modifiers": {"insight_per_gain": -1}}
const ACADEMY := {"id": "academy", "name": "Academy", "type": "building",
	"effects": [{"op": "gain", "resource": "insight", "amount": 2, "trigger": "upkeep"}]}


## An anarchy game ruled by gov (one of the 332 fixtures), no drain.
func ruled_by(gov: String) -> GameEngine:
	var starting := {"resources": {"food": 10, "wealth": 10, "insight": 10}, "tableau": ["capital"],
		"territory": "homeland", "government": gov}
	var e := anarchy_engine({}, {"starting": starting}, [TITHES, CREED, ACADEMY])
	eq(ruling(e), gov, "ruling")
	return e


func test_bug_332_forecast_leaves_out_the_upkeep_of_a_government_about_to_fall() -> void:
	var e := ruled_by("tithes")
	eq(e.upkeep_forecast().wealth, 3, "before the revolt: Tithes' +3 wealth")
	check(e.revolt(), "revolt: %s" % e.revolt_error())
	eq(e.upkeep_forecast().wealth, 0, "after the revolt: Tithes falls before upkeep")
	var wealth: int = e.resources.wealth
	e.end_turn()
	eq(e.resources.wealth, wealth, "turn 2's upkeep gained no wealth")


func test_bug_332_forecast_leaves_out_the_modifiers_of_a_government_about_to_fall() -> void:
	var e := ruled_by("creed")
	build_on(e, home_uid(e), ["academy"])
	eq(e.upkeep_forecast().insight, 1, "before the revolt: Academy's 2 less Creed's 1")
	e.revolt()
	eq(e.upkeep_forecast().insight, 2, "after the revolt: Academy's 2")


func test_bug_332_forecast_after_a_revolt_changes_nothing() -> void:
	var e := ruled_by("tithes")
	e.revolt()
	var recorded := record_messages(e)
	var resources := e.resources.duplicate()
	var log_lines := e.log_lines.duplicate()
	var zone_uids := {}
	for z in GameEngine.ZONES:
		zone_uids[z] = e.zone(z).cards.map(func(c): return c.uid)
	e.upkeep_forecast()
	eq([ruling(e), e.anarchy(), e.state.revolt_pending], ["tithes", -1, true], "Tithes rules, revolt still pending")
	eq(e.resources, resources, "resources")
	for z in GameEngine.ZONES:
		eq(e.zone(z).cards.map(func(c): return c.uid), zone_uids[z], "%s uids" % z)
	eq(e.log_lines, log_lines, "log")
	eq(recorded, [] as Array[String], "no messages")
