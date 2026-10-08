extends "res://tests/lib/anarchy_case.gd"
## Choice events (backlog 269): an event with `choices` (2–3 options, each {cost?, effects}, one free) owes a choice
## when it is drawn, after its own play effects: pending() is PENDING_EVENT_CHOICE until choose_option(i) pays the
## option's cost and resolves its effects, emitting option_chosen. Another decision owed at the draw comes first.
## Fixtures: tests/lib/anarchy_case.gd (Envoys, Boons, Twins, Dear; choice_engine).


## TEST_CARDS, TEST_GOVS, FIXTURES and extra, parsed with unrest a resource: {cards, errors, warnings}.
func choice_load(extra := [ENVOYS]) -> Dictionary:
	return fixture_load(extra, [TEST_GOVS, FIXTURES], RESOURCES)


## An event "x" with choices (and any other fields in more).
func event_with(choices: Variant, more := {}) -> Array:
	return [{"id": "x", "name": "X", "type": "event", "choices": choices}.merged(more, true)]


const FREE := {"effects": [{"op": "gain", "resource": "unrest", "amount": 1}]}
const PAID := {"cost": {"wealth": 2}, "effects": [{"op": "score", "amount": 1}]}


## A choice_engine game with wealth set to wealth at the end of turn 1, then ended: Envoys drawn at turn 2's start.
func drawn(wealth := 3) -> GameEngine:
	var e := choice_engine()
	e.end_turn()
	e.resources["wealth"] = wealth
	return e


# --- AC1: loading ---

func test_choices_load_on_an_event() -> void:
	check_loads([
		["Envoys and a plain event", [ENVOYS], {
			"cards.envoys.choices.size()": 2,
			"cards.envoys.choices.0.cost": {"wealth": 2},
			"cards.envoys.choices.0.effects.size()": 1,
			"cards.envoys.choices.0.effects.0.op": "score",
			"cards.envoys.choices.1.cost": {},
			"cards.envoys.choices.1.effects.size()": 1,
			"cards.envoys.choices.1.effects.0.op": "gain",
			"cards.fleeting.choices": [],
		}],
	], choice_load)


func test_bad_choices_are_a_load_error() -> void:
	check_cases([
		["one option", event_with([FREE]), ["cards.json", "card 'x'", "choices", "2"], "one_error"],
		["four options", event_with([FREE, FREE, FREE, FREE]), ["card 'x'", "choices", "3"], "one_error"],
		["no free option", event_with([PAID, PAID]), ["card 'x'", "choices", "free"], "one_error"],
		["an option effect with a trigger", event_with([FREE, {"effects": [
			{"op": "gain", "resource": "food", "amount": 1, "trigger": "upkeep"}]}]),
			["card 'x'", "choices[1]", "trigger"], "one_error"],
		["an option effect that opens a choice", event_with([FREE, {"effects": [{"op": "explore"}]}]),
			["card 'x'", "choices[1]", "explore"], "one_error"],
		["an unknown resource in a cost", event_with([FREE, {"cost": {"gold": 2}, "effects": []}]),
			["card 'x'", "choices[1]", "gold"], "one_error"],
		["not a list", event_with("pay"), ["card 'x'", "choices"], "one_error"],
		["on a building", [{"id": "x", "name": "X", "type": "building", "choices": [FREE, PAID]}],
			["card 'x'", "choices", "event"], "one_error"],
		["on a raid", event_with([FREE, PAID], {"raid": {"strength": 2}}), ["card 'x'", "choices", "raid"], "one_error"],
	], choice_load)


# --- AC2: owed when drawn ---

func test_a_drawn_choice_event_resolves_its_own_effects_then_owes_the_choice() -> void:
	var e := choice_engine()
	var seen := []
	e.event_drawn.connect(func(o): seen.append(o))
	e.end_turn()
	var uid := uid_of(e.zone("active_events"), "envoys")
	check(uid != -1, "Envoys active")
	eq(seen.size(), 1, "event_drawn once")
	if seen.size() == 1:
		eq(seen[0].gained, {"food": 1}, "its own play effects resolved")
	eq(e.pending(), {"kind": GameEngine.PENDING_EVENT_CHOICE, "uid": uid, "options": [0, 1]}, "the choice is owed")
	eq(e.zone("active_events").find(uid).turns_left, 2, "it stays active for its discard turns")


func test_every_other_action_refuses_while_the_choice_is_owed() -> void:
	var e := drawn()
	const OWED := "Choose how to answer Envoys first."
	eq(e.end_turn_error(), OWED, "end turn")
	eq(e.play_error(first_in_hand(e)), OWED, "play")
	eq(e.buy_error("farm"), OWED, "buy")
	eq(e.discard_error(first_in_hand(e)), OWED, "discard")
	eq(e.hand_input_error(), OWED, "picking up a hand card")


# --- AC3: choosing ---

func test_choosing_a_paid_option_pays_its_cost_and_resolves_its_effects() -> void:
	var e := drawn(3)
	var score: int = e.score()
	check(e.choose_option(0) == true, "choose_option(0) succeeds")
	eq(e.resources.wealth, 1, "paid 2 wealth")
	eq(e.score() - score, 1, "+1 VP")
	eq(e.pending(), {}, "nothing owed")


func test_choosing_a_free_option_changes_nothing_else() -> void:
	var e := drawn(3)
	var before: Dictionary = e.resources.duplicate()
	var score: int = e.score()
	var hand := card_ids(e.zone("hand"))
	check(e.choose_option(1) == true, "choose_option(1) succeeds")
	before.unrest += 1
	eq(e.resources, before, "+1 unrest, nothing else")
	eq(e.score(), score, "score")
	eq(card_ids(e.zone("hand")), hand, "hand")
	eq(e.pending(), {}, "nothing owed")


func test_choosing_emits_what_the_option_did() -> void:
	for i in 2:
		var e := drawn(3)
		var seen := []
		e.option_chosen.connect(func(o): seen.append(o))
		e.choose_option(i)
		eq(seen.size(), 1, "option %d: option_chosen once" % i)
		if seen.size() != 1:
			continue
		var o: Dictionary = seen[0]
		eq(o.get("uid"), uid_of(e.zone("active_events"), "envoys"), "option %d: the event's uid" % i)
		eq(o.get("id"), "envoys", "option %d: its id" % i)
		eq(o.get("index"), i, "option %d: the index" % i)
		eq(e.outcome_summary(o), ["−2 wealth, +1 VP", "+1 unrest"][i], "option %d: the summary" % i)


# --- AC4: refusals ---

func test_choose_option_error_gives_the_reason_and_choose_option_changes_nothing() -> void:
	var poor := drawn(1)
	var nothing := choice_engine()
	var over := choice_engine([], {"envoys": 1, "fleeting": 1}, {}, {"turn_limit": 1})
	over.end_turn()
	var cases := [
		["too poor", poor, 0, "Not enough wealth: needs 2."],
		["past the end", poor, 2, "No such option."],
		["below 0", poor, -1, "No such option."],
		["nothing owed", nothing, 0, "No event choice is waiting."],
		["game over", over, 0, "The game is over."],
	]
	for row in cases:
		var e: GameEngine = row[1]
		eq(e.choose_option_error(row[2]), row[3], row[0])
		var before: GameState = e.state.copy()
		check(e.choose_option(row[2]) == false, "%s: choose_option refuses" % row[0])
		eq(state_diff(e.state, before), "", "%s: changes nothing; changed" % row[0])
	eq(poor.choose_option_error(1), "", "the free option is legal")


# --- AC5: other decisions first ---

## A choice_engine game whose turn 2 fell into Anarchy with renewal 1 (a Farm in the discard), Envoys drawn.
func renewal_first() -> GameEngine:
	var e := choice_engine(["envoys"], {"envoys": 1, "fleeting": 1}, {"renewal": 1})
	put_in(e, "farm", "discard")
	e.resources["unrest"] = 5
	e.end_turn()
	return e


## 385 AC5: renewal is an action, so a choice drawn under Anarchy is owed at once.
func test_under_anarchy_a_choice_drawn_at_turn_start_is_owed_at_once() -> void:
	var e := renewal_first()
	var uid := uid_of(e.zone("active_events"), "envoys")
	check(e.anarchy() != -1, "precondition: Anarchy rules")
	eq(e.pending(), {"kind": GameEngine.PENDING_EVENT_CHOICE, "uid": uid, "options": [0, 1]}, "the choice, at once")


func test_the_choice_follows_a_government_chosen_at_the_turns_end() -> void:
	var e := choice_engine(["fleeting", "envoys"])
	e.resources["unrest"] = 5
	e.end_turn()  # Anarchy falls at turn 2's start; Fleeting drawn
	Anarchy.active(e).counters = 1
	e.end_turn()  # its last counter comes off: the government choice is owed before turn 3
	eq(e.pending().get("kind"), GameEngine.PENDING_GOVERNMENT, "the government first")
	check(e.choose_government(e.pending().options[0]), "choose a government")
	eq(e.turn, 3, "turn 3 started")
	eq(e.pending().get("kind"), GameEngine.PENDING_EVENT_CHOICE, "then the choice")


func test_a_copy_keeps_an_owed_or_waiting_choice() -> void:
	var owed := drawn()
	eq(owed.fork().pending(), owed.pending(), "an owed choice")
	var anarchy := renewal_first()
	eq(anarchy.fork().pending(), anarchy.pending(), "a choice owed under Anarchy")


# --- AC6: text ---

func test_card_text_lists_the_options_after_its_other_effects() -> void:
	var db: Dictionary = choice_load().cards
	var lines: Array = Array(db.envoys.rules_text(db).split("\n"))
	var choose := "Choose: pay 2 wealth for +1 VP; or +1 unrest."
	check(lines.has(choose), "'%s' in %s" % [choose, lines])
	check(lines.find(choose) > lines.find("+1 food"), "after its own effects: %s" % [lines])


func test_option_text_gives_one_options_text() -> void:
	var e := drawn()
	var uid := uid_of(e.zone("active_events"), "envoys")
	eq(e.option_text(uid, 0), "Pay 2 wealth: +1 VP", "the paid option")
	eq(e.option_text(uid, 1), "+1 unrest", "the free option")


## Backlog 270: an option that does nothing reads as a payment alone, or as "nothing".
func test_an_option_without_effects_reads_as_its_cost_or_nothing() -> void:
	var r := choice_load(event_with([{"cost": {"wealth": 4}, "effects": []}, {"effects": []}]))
	eq(r.errors, [] as Array[String], "errors")
	if not r.cards.has("x"):
		return
	var def: CardDef = r.cards.x
	var lines: Array = Array(def.rules_text(r.cards).split("\n"))
	var choose := "Choose: pay 4 wealth; or nothing."
	check(lines.has(choose), "'%s' in %s" % [choose, lines])
	eq(def.option_text(0, r.cards), "Pay 4 wealth", "the paid option")
	eq(def.option_text(1, r.cards), "Nothing", "the free option")

# --- AC7: the bot ---

## A choice_engine game with event id drawn at turn 2's start.
func bot_drawn(id: String) -> GameEngine:
	var e := choice_engine([id], {id: 1, "fleeting": 1})
	e.end_turn()
	return e


func test_the_bot_answers_the_choice_in_its_turn() -> void:
	var e := bot_drawn("boons")
	var score := e.score()
	GenericBot.take_turn(e)
	eq(e.pending().get("kind", ""), "", "answered")
	check(e.score() - score >= 2, "with Boons' +2 VP (score %d → %d)" % [score, e.score()])


func test_a_bot_game_of_choice_events_plays_to_its_last_turn() -> void:
	var e := choice_engine([], {"envoys": 2, "boons": 2, "twins": 2, "dear": 2}, {}, {"turn_limit": 8})
	check(GenericBot.play(e), "the game ends")
	eq(e.turn, 8, "on its last turn")
