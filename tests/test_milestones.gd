extends "res://tests/lib/tech_case.gd"
## Milestones (191): the engine's milestone(kind) signal for a tech learned, a territory settled into a city and each
## era added, emitted before changed, never for a failed action or during a new game's setup.

const ERA_CARDS := [
	{"id": "philosophy", "name": "Philosophy", "type": "tech", "cost": {"insight": 3},
	 "effects": [{"op": "add_era", "era": 2}]},
	{"id": "optics", "name": "Optics", "type": "tech", "cost": {"insight": 4}, "era": 2},
	{"id": "astronomy", "name": "Astronomy", "type": "tech", "cost": {"insight": 5}, "era": 2},
	{"id": "academy", "name": "Academy", "type": "building", "cost": {"food": 1},
	 "effects": [{"op": "add_era", "era": 2}]},
]


## A game whose research deck holds the era-1 techs ids and whose era-2 techs wait in future_techs.
func era_engine(ids: Array, deck := {"farm": 10}, overrides := {}) -> GameEngine:
	var counts := {"optics": 1, "astronomy": 1}
	for id in ids:
		counts[id] = counts.get(id, 0) + 1
	var config := {"research_deck": counts}
	config.merge(overrides, true)
	return tech_engine(ids, deck, config, ERA_CARDS)


## Records e's milestones as "milestone: <kind>" and its changed signals as "changed", in order.
func record_milestones(e: GameEngine) -> Array:
	var out := []
	e.connect("milestone", func(kind: StringName): out.append("milestone: %s" % kind))
	e.changed.connect(func(): out.append("changed"))
	return out


# --- AC1 ---

func test_the_milestone_kinds() -> void:
	eq([GameEngine.MILESTONE_TECH, GameEngine.MILESTONE_CITY, GameEngine.MILESTONE_ERA], [&"tech", &"city", &"era"],
		"tech, city, era")


func test_learning_a_tech_is_a_milestone_before_changed() -> void:
	var e := era_engine(["pottery", "writing"])
	var got := record_milestones(e)
	check(e.buy_tech(uid_of(e.zone("research_deck"), "pottery")), "learn Pottery")
	eq(got, ["milestone: tech", "changed"], "one tech milestone, then changed")


func test_a_failed_buy_is_no_milestone() -> void:
	var e := era_engine(["pottery", "iron"])
	var got := record_milestones(e)
	check(not e.buy_tech(uid_of(e.zone("research_deck"), "iron")), "Iron needs Bronze Working")
	eq(got, [], "nothing")


func test_settling_a_territory_is_a_city_milestone() -> void:
	var e := make_engine({"pioneer": 10}, {"territory_deck": {"hills": 1}})
	to_frontier(e, ["hills"])
	e.resources.food = 3
	var got := record_milestones(e)
	check(e.play_card(first_in_hand(e)), "a Pioneer settles the Hills")
	eq(got.filter(func(s): return s.begins_with("milestone")), ["milestone: city"], "a city")
	eq(got.back(), "changed", "before changed")


func test_each_era_added_is_a_milestone_once() -> void:
	var e := era_engine(["philosophy", "pottery"], {"academy": 10})
	var got := record_milestones(e)
	check(e.buy_tech(uid_of(e.zone("research_deck"), "philosophy")), "learn Philosophy: era 2")
	eq(got, ["milestone: tech", "milestone: era", "changed"], "the tech and the era it adds")
	got.clear()
	check(e.play_card(first_in_hand(e)), "Academy: era 2 again")
	eq(got.filter(func(s): return s.begins_with("milestone")), [], "an era already added: nothing")


# --- AC2 ---

func test_starting_and_restarting_a_game_emits_no_milestone() -> void:
	var e := era_engine(["pottery"], {"farm": 10},
		{"population": {"start": 2, "food_upkeep": 0, "vp_per_pop": 1}, "era_unlocks": {"2": {"pop": 1}}})
	eq(e.era(), 2, "the setup's first turn adds era 2")
	var got := record_milestones(e)
	e.new_game(2)
	eq(e.era(), 2, "again")
	eq(got.filter(func(s): return s.begins_with("milestone")), [], "no milestone")
