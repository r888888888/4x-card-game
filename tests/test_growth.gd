extends "res://tests/lib/test_case.gd"
## Buying growth (backlog 010): grow / grow_error / grow_cost spend (pop + 1) food for +1 pop on a
## settled territory, up to its housing.


## A game with population on (no food upkeep, so food only changes by growing), Homeland pop start,
## and food set to food.
func grow_engine(start: int, food: int, deck := {"farm": 10}, overrides := {}) -> GameEngine:
	var o := {"population": {"start": start, "food_upkeep": 0, "vp_per_pop": 1}}
	o.merge(overrides, true)
	var e := make_engine(deck, o)
	e.resources.food = food
	return e


# --- AC1: growth costs pop + 1 food ---

func test_grow_adds_1_pop_for_pop_plus_1_food() -> void:
	var e := grow_engine(2, 5)
	var home := home_uid(e)
	eq(e.grow_cost(home), 3, "cost at pop 2")
	var changes := []
	e.changed.connect(func(): changes.append(true))
	check(e.grow(home), "grow succeeds")
	eq(e.pop(home), 3, "pop 2 + 1")
	eq(e.resources.food, 2, "food 5 - 3")
	eq(changes.size(), 1, "changed emitted once")


func test_grow_emits_no_card_played() -> void:
	var e := grow_engine(2, 5)
	var played := []
	e.card_played.connect(func(o): played.append(o))
	e.grow(home_uid(e))
	eq(played.size(), 0, "grow is not a card play")


# --- AC2: each step costs more; no limit per turn ---

func test_grow_rejected_when_food_is_short() -> void:
	var e := grow_engine(2, 5)
	var home := home_uid(e)
	e.grow(home)  # pop 3, food 2
	check("needs 4 food (you have 2)" in e.grow_error(home), "error names cost and food: '%s'" % e.grow_error(home))
	check(not e.grow(home), "grow refused")
	eq(e.pop(home), 3, "pop unchanged")
	eq(e.resources.food, 2, "food unchanged")


func test_grow_has_no_per_turn_limit() -> void:
	var e := grow_engine(2, 7)
	var home := home_uid(e)
	check(e.grow(home), "first grow: 3 food")
	check(e.grow(home), "second grow: 4 food")
	eq(e.pop(home), 4, "pop 2 + 2")
	eq(e.resources.food, 0, "food 7 - 3 - 4")


# --- AC3: capped by housing ---

func test_grow_rejected_at_housing() -> void:
	var e := grow_engine(7, 100)  # homeland housing 7
	var home := home_uid(e)
	check(e.grow_error(home) != "", "error at housing")
	check(not e.grow(home), "grow refused")
	eq(e.pop(home), 7, "pop unchanged")
	eq(e.resources.food, 100, "food unchanged")


# --- AC4: other rejections ---

func assert_refused(e: GameEngine, uid: int, what: String) -> void:
	var food: int = e.resources.food
	var total := e.total_pop()
	check(e.grow_error(uid) != "", "%s: grow_error gives a reason" % what)
	check(not e.grow(uid), "%s: grow refused" % what)
	eq(e.resources.food, food, "%s: food unchanged" % what)
	eq(e.total_pop(), total, "%s: total pop unchanged" % what)


func test_grow_refused_on_non_settled_targets() -> void:
	var e := grow_engine(2, 50, {"farm": 10}, {"territory_deck": {"grassland": 1}})
	e.zone("frontier").add(e.zone("territory_deck").take_top())
	assert_refused(e, e.zone("frontier").cards[0].uid, "frontier territory")
	var capital: int = -1
	for c in e.zone("tableau").cards:
		if c.def.id == "capital":
			capital = c.uid
	assert_refused(e, capital, "city")
	assert_refused(e, 9999, "unknown uid")


func test_grow_refused_while_a_choice_is_pending() -> void:
	var e := grow_engine(2, 50, {"explorer": 10}, {"territory_deck": {"grassland": 2}})
	check(e.play_card(first_in_hand(e)), "explore")
	check(e.pending().get("kind") == GameEngine.PENDING_EXPLORE, "choice pending")
	assert_refused(e, home_uid(e), "pending choice")


func test_grow_refused_when_game_is_over() -> void:
	var e := grow_engine(2, 50, {"farm": 10}, {"turn_limit": 1})
	e.end_turn()
	check(e.is_over, "game over")
	e.resources.food = 50
	assert_refused(e, home_uid(e), "game over")


func test_grow_refused_without_population() -> void:
	var e := make_engine({"farm": 10})
	e.resources.food = 50
	assert_refused(e, home_uid(e), "population off")


# --- AC5: legal growth has no error ---

func test_grow_error_is_empty_when_legal() -> void:
	var e := grow_engine(2, 3)
	eq(e.grow_error(home_uid(e)), "", "3 food is enough at pop 2")
