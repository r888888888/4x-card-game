extends "res://tests/lib/anarchy_case.gd"
## The bot's government lookahead (backlog 159): when the government choice is owed, ScriptedBot plays each option out
## on a fork for LOOKAHEAD_TURNS turns and chooses the best scoring (ties: zone order); every REVOLT_EVERY turns, at the
## end of a turn, it revolts when a fork that revolts to some government in the deck outscores one that doesn't (never
## in the last LOOKAHEAD_TURNS ÷ 2 turns). ScriptedBot.lookahead plays one such fork. Fixtures: tests/lib/anarchy_case.gd
## plus Glory (⟳ +3 VP, limit 5), Dull (nothing, limit 9) and Plain (nothing, limit 6): 154's ranking prefers Dull.
## No card in these games scores, so a game's score only grows under Glory.

const GLORY := {"id": "glory", "name": "Glory", "type": "government", "unrest_limit": 5,
	"effects": [{"op": "score", "amount": 3, "trigger": "upkeep"}]}
const DULL := {"id": "dull", "name": "Dull", "type": "government", "unrest_limit": 9}
const PLAIN := {"id": "plain", "name": "Plain", "type": "government", "unrest_limit": 6}
const GOVS := [GLORY, DULL, PLAIN]


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


## sim/bot.gd as an Object, so calls to its new statics parse before they exist (red phase).
func bot() -> Object:
	return load("res://sim/bot.gd")


## LOOKAHEAD_TURNS, read the same way.
func lookahead_turns() -> int:
	return bot().get_script_constant_map().get("LOOKAHEAD_TURNS", -1)


## Whether the bot has revolted in e this turn.
func revolted(e: GameEngine) -> bool:
	return e.revolt_error() == "A revolution is already under way."


# --- AC1: choosing by lookahead ---

func test_the_bot_chooses_the_government_whose_lookahead_scores_most() -> void:
	var e := choice_game(["glory", "dull"], true)
	ScriptedBot.take_turn(e, "baseline")
	eq(ruling(e), "glory", "Glory's ⟳ +3 VP beats Dull's limit 9 and Chiefs")


func test_with_one_option_the_bot_chooses_it() -> void:
	var e := choice_game(["dull"])
	ScriptedBot.take_turn(e, "baseline")
	eq(ruling(e), "dull", "the only option")


func test_lookahead_ties_go_to_zone_order() -> void:
	var e := choice_game(["plain", "dull"])
	ScriptedBot.take_turn(e, "baseline")
	eq(ruling(e), "plain", "both score nothing: Plain is first (the ranking would take Dull)")


# --- AC2: revolting by lookahead ---

func test_the_bot_revolts_every_4_turns_when_a_revolution_scores_more() -> void:
	var e := deck_game(["glory"], 4)
	ScriptedBot.take_turn(e, "baseline")
	check(revolted(e), "turn 4: a revolution to Glory outscores Chiefs")
	var early := deck_game(["glory"], 3)
	ScriptedBot.take_turn(early, "baseline")
	check(not revolted(early), "turn 3: not weighed")


func test_the_bot_doesnt_revolt_when_no_revolution_scores_more() -> void:
	var e := deck_game(["dull", "plain"], 4)
	ScriptedBot.take_turn(e, "baseline")
	check(not revolted(e), "Dull and Plain score no more than Chiefs")


func test_the_bot_doesnt_weigh_a_revolt_in_the_last_half_lookahead() -> void:
	var e := deck_game(["glory"], 4, 8)
	ScriptedBot.take_turn(e, "baseline")
	check(not revolted(e), "turn 4 of 8 is within the last 6 turns")


# --- AC3: a lookahead ---

func test_a_lookahead_changes_nothing_in_the_real_game() -> void:
	var e := choice_game(["glory", "dull"])
	var before := e.state.copy()
	var signals := [0]
	for s in ["changed", "noticed", "logged", "card_played", "game_over", "event_drawn"]:
		e.connect(s, func(_a = null): signals[0] += 1)
	bot().lookahead(e, "baseline", "glory")
	bot().lookahead(deck_game(["glory"], 4), "baseline", "glory", true)
	bot().lookahead(e, "baseline", "dull", true)
	eq(state_diff(e.state, before), "", "the real game's state")
	eq(signals[0], 0, "no signal from the real game")


func test_a_lookahead_chooses_the_government_it_was_opened_for() -> void:
	var e := choice_game(["glory", "dull"])
	var glory: int = bot().lookahead(e, "baseline", "glory")
	var dull: int = bot().lookahead(e, "baseline", "dull")
	eq(dull, e.score(), "under Dull nothing scores")
	eq(glory, e.score() + 3 * lookahead_turns(), "Glory's ⟳ +3 for each of the 12 turns played")


func test_inside_a_lookahead_the_bot_never_revolts() -> void:
	var e := deck_game(["glory"], 4)
	eq(bot().lookahead(e, "baseline"), e.score(), "staying on Chiefs for 12 turns, never revolting to Glory")
	check(bot().lookahead(e, "baseline", "glory", true) > e.score(), "the revolting fork does reach Glory")


func test_a_lookahead_stops_at_the_games_end() -> void:
	var short := deck_game([], 1, 3)
	eq(bot().lookahead(short, "baseline"), short.score(), "a 3-turn game plays out to its end")


# --- 154's ranking, now used inside a lookahead ---

func test_the_ranking_prefers_most_actions_then_highest_limit_then_deck_order() -> void:
	var e := anarchy_engine({}, {}, GOVS)
	for id in ["kings", "band", "court", "dull", "plain"]:
		e.create_card(id, "discard", null)
	var deck := e.zone("governments").cards
	eq(bot().best_government(deck).def.id, "court", "Court's 3 actions")
	var no_actions := deck.filter(func(c): return c.def.actions == 0)
	eq(bot().best_government(no_actions).def.id, "dull", "Dull's limit 9")
	var council := anarchy_engine({}, {}, GOVS)
	for id in ["council", "kingdom"]:
		council.create_card(id, "discard", null)
	eq(bot().best_government(council.zone("governments").cards).def.id, "council", "a tie: the first")
