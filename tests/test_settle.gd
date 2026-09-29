extends "res://tests/lib/test_case.gd"
## The settle op and card targets: play_card/play_error with a target, valid_targets,
## needs_target, and the outcome's target (backlog 003). Hands are all Pioneers (cost 3 food).


## A game whose frontier holds territories ids (in order) and whose hand is 5 Pioneers.
func frontier_engine(ids: Array[String], deck := {"pioneer": 10}) -> GameEngine:
	var counts := {}
	for id in ids:
		counts[id] = counts.get(id, 0) + 1
	var e := make_engine(deck, {"territory_deck": counts})
	to_frontier(e, ids)
	eq(card_ids(e.zone("frontier")), ids, "frontier arranged")
	return e


func card_in(zone: Zone, id: String) -> CardInstance:
	return zone.find(uid_of(zone, id))


## Plays uid (with target) and returns the emitted card_played outcomes.
func play_and_capture(e: GameEngine, uid: int, target := -1) -> Array:
	var outcomes := []
	e.card_played.connect(func(o): outcomes.append(o))
	e.play_card(uid, target)
	return outcomes


# --- AC1: one frontier territory ---

func test_settle_founds_city_on_only_frontier_territory() -> void:
	var e := frontier_engine(["hills"])
	e.resources.food = 3
	check(e.play_card(first_in_hand(e)), "play returns true")
	var tableau := e.zone("tableau")
	check(card_ids(tableau).has("hills"), "Hills in tableau: %s" % [card_ids(tableau)])
	check(card_ids(tableau).has("city"), "City in tableau: %s" % [card_ids(tableau)])
	var city := card_in(tableau, "city")
	if city != null:
		check(e.territory_of(city) == card_in(tableau, "hills"), "City is on Hills")
	eq(e.zone("frontier").size(), 0, "frontier empty")
	eq(e.resources.food, 0, "food 3 - 3")


# --- AC2: several frontier territories ---

func test_settle_needs_a_target_when_several_territories() -> void:
	var e := frontier_engine(["hills", "grassland"])
	var pioneer := first_in_hand(e)
	eq(e.play_error(pioneer), "Choose a territory to settle.", "play_error")
	check(not e.play_card(pioneer), "play without target fails")
	eq(e.zone("hand").size(), 5, "Pioneer still in hand")


func test_settle_chosen_territory() -> void:
	var e := frontier_engine(["hills", "grassland"])
	var grassland := uid_of(e.zone("frontier"), "grassland")
	check(e.play_card(first_in_hand(e), grassland), "play on Grassland")
	var city := card_in(e.zone("tableau"), "city")
	check(city != null and e.territory_of(city) != null and e.territory_of(city).uid == grassland, "City is on Grassland")
	eq(card_ids(e.zone("frontier")), ["hills"] as Array[String], "Hills stays in the frontier")


# --- AC3: empty frontier ---

func test_settle_with_empty_frontier_fails() -> void:
	var e := frontier_engine([])
	var pioneer := first_in_hand(e)
	var food: int = e.resources.food
	eq(e.play_error(pioneer), "No discovered territory to settle.", "play_error")
	check(not e.play_card(pioneer), "play fails")
	eq(e.zone("hand").size(), 5, "Pioneer still in hand")
	eq(e.resources.food, food, "food unchanged")


func test_cost_is_checked_before_target() -> void:
	var e := frontier_engine([])
	e.resources.food = 0
	eq(e.play_error(first_in_hand(e)), "Pioneer needs 3 food (you have 0).", "cost error first")


# --- AC4: invalid target ---

func test_settle_on_invalid_target_fails() -> void:
	var e := frontier_engine(["hills"])
	var pioneer := first_in_hand(e)
	var capital := uid_of(e.zone("tableau"), "capital")
	var food: int = e.resources.food
	eq(e.play_error(pioneer, capital), "That target isn't valid.", "play_error")
	check(not e.play_card(pioneer, capital), "play fails")
	eq(card_ids(e.zone("frontier")), ["hills"] as Array[String], "frontier unchanged")
	eq(card_ids(e.zone("tableau")), ["homeland", "capital"] as Array[String], "tableau unchanged")
	eq(e.zone("hand").size(), 5, "hand unchanged")
	eq(e.resources.food, food, "food unchanged")


# --- AC5: valid_targets and needs_target ---

func test_valid_targets_are_frontier_territories() -> void:
	var e := frontier_engine(["hills", "grassland"])
	var pioneer := first_in_hand(e)
	var expected: Array[int] = [uid_of(e.zone("frontier"), "hills"), uid_of(e.zone("frontier"), "grassland")]
	eq(e.valid_targets(pioneer), expected, "valid_targets")
	check(e.needs_target(pioneer), "Pioneer needs a target")


func test_untargeted_card_has_no_targets_and_ignores_one() -> void:
	var e := make_engine({"shrine": 10})
	var shrine := first_in_hand(e)
	var capital := uid_of(e.zone("tableau"), "capital")
	eq(e.valid_targets(shrine), [] as Array[int], "valid_targets")
	check(not e.needs_target(shrine), "Shrine needs no target")
	eq(e.play_error(shrine, capital), "", "target ignored by play_error")
	check(e.play_card(shrine, capital), "target ignored by play_card")
	eq(card_ids(e.zone("discard")), ["shrine"] as Array[String], "Shrine played")


# --- AC7: outcome target ---

func test_outcome_target_is_given_target() -> void:
	var e := frontier_engine(["hills", "grassland"])
	var grassland := uid_of(e.zone("frontier"), "grassland")
	var outcomes := play_and_capture(e, first_in_hand(e), grassland)
	eq(outcomes.size(), 1, "one outcome")
	if outcomes.size() == 1:
		eq(outcomes[0].get("target"), grassland, "target")


func test_outcome_target_is_engine_pick() -> void:
	var e := frontier_engine(["hills"])
	var hills := uid_of(e.zone("frontier"), "hills")
	var outcomes := play_and_capture(e, first_in_hand(e))
	eq(outcomes.size(), 1, "one outcome")
	if outcomes.size() == 1:
		eq(outcomes[0].get("target"), hills, "target")


func test_outcome_target_for_untargeted_card() -> void:
	var e := make_engine({"shrine": 10})
	var outcomes := play_and_capture(e, first_in_hand(e))
	eq(outcomes.size(), 1, "one outcome")
	if outcomes.size() == 1:
		eq(outcomes[0].get("target"), -1, "target")
