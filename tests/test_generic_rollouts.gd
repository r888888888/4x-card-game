extends "res://tests/lib/anarchy_case.gd"
## The generic bot's rollouts (314, porting 159): when the government choice is owed it plays each option out for
## ROLLOUT_TURNS turns on a sample fork in cheap mode and chooses the one whose fork values most (ties: deck order; one
## option: no rollout); every REVOLT_EVERY turns, at the end of a turn, it revolts when a rollout that revolts to some
## government in the deck values more than one that doesn't (never in the last ROLLOUT_TURNS ÷ 2 turns). Inside a
## rollout it never revolts and chooses the government the rollout was opened for. Fixtures: tests/lib/anarchy_case.gd
## plus Glory (⟳ +3 VP, limit 5), Dull (nothing, limit 9), Plain (nothing, limit 6) and Twin (Plain's copy).

const GLORY := {"id": "glory", "name": "Glory", "type": "government", "unrest_limit": 5,
	"effects": [{"op": "score", "amount": 3, "trigger": "upkeep"}]}
const DULL := {"id": "dull", "name": "Dull", "type": "government", "unrest_limit": 9}
const PLAIN := {"id": "plain", "name": "Plain", "type": "government", "unrest_limit": 6}
const TWIN := {"id": "twin", "name": "Twin", "type": "government", "unrest_limit": 6}
const GOVS := [GLORY, DULL, PLAIN, TWIN]


## A Chiefs game of turn_limit turns with governments created into the government deck, played (by end_turn alone)
## to the start of turn.
func deck_game(governments: Array, turn := 1, turn_limit := 30) -> GameEngine:
	var e := anarchy_engine({}, {"turn_limit": turn_limit}, GOVS)
	for id in governments:
		e.create_card(id, "discard", null)
	while e.turn < turn:
		e.end_turn()
	return e


## A game whose forced Anarchy has just burned out (turn 5) with governments in the deck (Chiefs dropped unless
## keep_chiefs): the government choice is owed.
func choice_game(governments: Array, keep_chiefs := false) -> GameEngine:
	var e := deck_game(governments)
	e.resources["unrest"] = 5
	for i in 5:
		e.end_turn()
	eq(e.pending().get("kind"), GameEngine.PENDING_GOVERNMENT, "the choice is owed")
	if not keep_chiefs:
		e.zone("governments").remove(e.zone("governments").find(uid_of(e.zone("governments"), "chiefs")))
	return e


## Whether the bot has revolted in e this turn.
func revolted(e: GameEngine) -> bool:
	return e.revolt_error() == "A revolution is already under way."


## GenericBot's take_turn as the generic strategy, with its rollout turn count reset first.
func bot_turn(e: GameEngine) -> void:
	GenericBot.lookahead_turns = 0
	GenericBot.take_turn(e, "generic")


# --- choosing a government by rollout ---

func test_the_bot_chooses_the_government_whose_rollout_values_most() -> void:
	var e := choice_game(["glory", "dull"], true)
	bot_turn(e)
	eq(ruling(e), "glory", "Glory's ⟳ +3 VP beats Dull and Chiefs")


func test_with_one_option_the_bot_chooses_it_without_a_rollout() -> void:
	var e := choice_game(["dull"])
	bot_turn(e)
	eq(ruling(e), "dull", "the only option")
	eq(GenericBot.lookahead_turns, 0, "no rollout for one option")


func test_rollout_ties_go_to_deck_order() -> void:
	var e := choice_game(["plain", "twin"])
	bot_turn(e)
	eq(ruling(e), "plain", "Plain and Twin are the same: Plain is first")


# --- revolting by rollout ---

func test_the_bot_revolts_every_revolt_every_turns_when_a_revolution_values_more() -> void:
	var every := GenericBot.REVOLT_EVERY
	check(every > 0, "REVOLT_EVERY: %d" % every)
	var e := deck_game(["glory"], every)
	bot_turn(e)
	check(revolted(e), "turn %d: a revolution to Glory beats Chiefs" % e.turn)
	var early := deck_game(["glory"], every - 1)
	bot_turn(early)
	check(not revolted(early), "turn %d: not weighed" % early.turn)


func test_the_bot_doesnt_revolt_when_no_revolution_values_more() -> void:
	var e := deck_game(["dull", "plain"], maxi(1, GenericBot.REVOLT_EVERY))
	bot_turn(e)
	check(not revolted(e), "Dull and Plain do no better than Chiefs, and Anarchy costs")


func test_the_bot_doesnt_weigh_a_revolt_in_the_last_half_rollout() -> void:
	var every := GenericBot.REVOLT_EVERY
	var last := every + GenericBot.ROLLOUT_TURNS / 2 - 2
	var e := deck_game(["glory"], maxi(1, every), maxi(2, last))
	bot_turn(e)
	check(not revolted(e), "turn %d of %d is within the last ROLLOUT_TURNS ÷ 2 turns" % [e.turn, last])


# --- a rollout ---

func test_a_rollout_changes_nothing_in_the_real_game() -> void:
	var e := choice_game(["glory", "dull"])
	var before := e.state.copy()
	var signals := [0]
	for s in ["changed", "noticed", "logged", "card_played", "game_over", "event_drawn"]:
		e.connect(s, func(_a = null, _b = null): signals[0] += 1)
	GenericBot.rollout(e, "generic", "glory")
	GenericBot.rollout(deck_game(["glory"], 4), "generic", "glory", true)
	GenericBot.rollout(e, "generic", "dull", true)
	eq(state_diff(e.state, before), "", "the real game's state")
	eq(signals[0], 0, "no signal from the real game")


func test_a_rollout_chooses_the_government_it_was_opened_for() -> void:
	var e := choice_game(["glory", "dull"])
	var glory: float = GenericBot.rollout(e, "generic", "glory")
	var dull: float = GenericBot.rollout(e, "generic", "dull")
	check(glory > dull, "Glory's fork scores 3 a turn more: %s vs %s" % [glory, dull])


func test_a_rollout_plays_rollout_turns_never_revolting_inside() -> void:
	var e := deck_game(["glory"], maxi(1, GenericBot.REVOLT_EVERY))
	GenericBot.lookahead_turns = 0
	GenericBot.rollout(e, "generic")
	eq(GenericBot.lookahead_turns, GenericBot.ROLLOUT_TURNS, "one rollout of ROLLOUT_TURNS turns: no revolt weighed inside")


func test_a_rollout_stops_at_the_games_end() -> void:
	var short := deck_game([], 1, 3)
	GenericBot.lookahead_turns = 0
	GenericBot.rollout(short, "generic")
	eq(GenericBot.lookahead_turns, 2, "turns 1 to 3: 2 turns played")


func test_weighing_a_revolution_plays_a_rollout_for_staying_and_for_each_government() -> void:
	var every := maxi(1, GenericBot.REVOLT_EVERY)
	var e := deck_game(["dull", "plain"], every, every + GenericBot.ROLLOUT_TURNS)
	bot_turn(e)
	check(not revolted(e), "no revolution")
	eq(GenericBot.lookahead_turns, 3 * GenericBot.ROLLOUT_TURNS, "staying, Dull and Plain, ROLLOUT_TURNS turns each")


func test_a_game_with_no_government_deck_plays_no_rollout_turns() -> void:
	var e := deck_game([], 1, 3 * maxi(1, GenericBot.REVOLT_EVERY))
	e.zone("governments").cards.clear()
	GenericBot.lookahead_turns = 0
	check(GenericBot.play(e, "generic"), "the game ends")
	eq(GenericBot.lookahead_turns, 0, "nothing to weigh")
