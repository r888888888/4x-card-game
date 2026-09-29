extends "res://tests/lib/test_case.gd"
## The explore op: reveal territories, keep one in the frontier, the rest to the bottom (backlog 002).
## Hands are all Explorers. Territory decks are written top first.


## A game whose territory deck is ids, top first, and whose hand is 5 Explorers.
func explore_engine(ids_top_first: Array) -> GameEngine:
	var counts := {}
	for id in ids_top_first:
		counts[id] = counts.get(id, 0) + 1
	var e := make_engine({"explorer": 10}, {"territory_deck": counts})
	arrange(e.zone("territory_deck"), ids_top_first)
	return e


func top_first(zone: Zone) -> Array[String]:
	var ids := card_ids(zone)
	ids.reverse()
	return ids


## Plays the first Explorer from [hills, grassland, jungle]; returns the engine with the choice pending.
func pending_engine() -> GameEngine:
	var e := explore_engine(["hills", "grassland", "jungle"])
	check(e.play_card(first_in_hand(e)), "play Explorer")
	return e


# --- AC1: reveal 2 ---

func test_explore_reveals_top_two_as_a_choice() -> void:
	var e := explore_engine(["hills", "grassland", "jungle"])
	var hills := uid_of(e.zone("territory_deck"), "hills")
	var grassland := uid_of(e.zone("territory_deck"), "grassland")
	var explorer := first_in_hand(e)
	check(e.play_card(explorer), "play Explorer")
	eq(sorted(e.pending_choice.get("options", [])), sorted([hills, grassland]), "options")
	eq(sorted(card_ids(e.zone("reveal"))), ["grassland", "hills"], "reveal zone")
	eq(top_first(e.zone("territory_deck")), ["jungle"] as Array[String], "territory deck")
	eq(card_ids(e.zone("discard")), ["explorer"] as Array[String], "Explorer discarded")
	var source: CardInstance = e.pending_choice.get("source")
	eq(source.uid if source != null else -1, explorer, "pending_choice source")


# --- AC2: choose ---

func test_choose_keeps_pick_in_frontier_and_buries_the_rest() -> void:
	var e := pending_engine()
	check(e.choose(uid_of(e.zone("reveal"), "hills")), "choose returns true")
	eq(card_ids(e.zone("frontier")), ["hills"] as Array[String], "frontier")
	eq(e.zone("reveal").size(), 0, "reveal empty")
	eq(top_first(e.zone("territory_deck")), ["jungle", "grassland"] as Array[String], "Grassland at the bottom")
	eq(e.pending_choice, {}, "nothing pending")


func test_choose_emits_changed_but_not_card_played() -> void:
	var e := pending_engine()
	var events := []
	e.changed.connect(func(): events.append("changed"))
	e.card_played.connect(func(_o): events.append("card_played"))
	e.choose(uid_of(e.zone("reveal"), "hills"))
	eq(events, ["changed"], "signals from choose")


# --- AC3: a pending choice blocks play and end turn ---

func test_pending_choice_blocks_play() -> void:
	var e := pending_engine()
	for c in e.zone("hand").cards:
		eq(e.play_error(c.uid), "Choose a territory first.", "play_error for hand card %d" % c.uid)
	var hand_before := card_ids(e.zone("hand"))
	check(not e.play_card(first_in_hand(e)), "play_card refused")
	eq(card_ids(e.zone("hand")), hand_before, "hand unchanged")


func test_pending_choice_blocks_end_turn() -> void:
	var e := pending_engine()
	var hand_before := card_ids(e.zone("hand"))
	var food_before: int = e.resources.food
	e.end_turn()
	eq(e.turn, 1, "turn unchanged")
	eq(card_ids(e.zone("hand")), hand_before, "hand unchanged")
	eq(e.resources.food, food_before, "food unchanged")


# --- AC4: invalid choices ---

func test_choose_non_option_is_refused() -> void:
	var e := pending_engine()
	var options: Array = e.pending_choice.get("options", []).duplicate()
	check(not e.choose(uid_of(e.zone("territory_deck"), "jungle")), "choosing Jungle refused")
	check(not e.choose(first_in_hand(e)), "choosing a hand card refused")
	eq(e.pending_choice.get("options", []), options, "still pending")
	eq(sorted(card_ids(e.zone("reveal"))), ["grassland", "hills"], "reveal unchanged")
	eq(top_first(e.zone("territory_deck")), ["jungle"] as Array[String], "territory deck unchanged")
	eq(e.zone("frontier").size(), 0, "frontier empty")


func test_choose_with_nothing_pending_is_refused() -> void:
	var e := explore_engine(["hills", "grassland"])
	var hills := uid_of(e.zone("territory_deck"), "hills")
	check(not e.choose(hills), "choose refused")
	eq(top_first(e.zone("territory_deck")), ["hills", "grassland"] as Array[String], "territory deck unchanged")
	eq(e.zone("frontier").size(), 0, "frontier empty")


# --- AC5: fewer territories than revealed ---

func test_explore_last_territory_goes_straight_to_frontier() -> void:
	var e := explore_engine(["hills"])
	check(e.play_card(first_in_hand(e)), "play Explorer")
	eq(card_ids(e.zone("frontier")), ["hills"] as Array[String], "frontier")
	eq(e.pending_choice, {}, "nothing pending")
	eq(e.zone("reveal").size(), 0, "reveal empty")
	eq(e.zone("territory_deck").size(), 0, "territory deck empty")


func test_explore_empty_territory_deck_does_nothing() -> void:
	var e := explore_engine([])
	check(e.play_card(first_in_hand(e)), "play Explorer")
	eq(e.pending_choice, {}, "nothing pending")
	eq(e.zone("reveal").size(), 0, "reveal empty")
	eq(e.zone("frontier").size(), 0, "frontier empty")
	eq(e.play_error(first_in_hand(e)), "", "play continues")


# --- Loader: the explore op ---

func test_explore_defaults_to_reveal_2() -> void:
	var errors: Array[String] = []
	var warnings: Array[String] = []
	var cards := DataLoader.parse_cards({"cards": [{"id": "x", "name": "X", "type": "action",
		"effects": [{"op": "explore"}]}]}, resources(), "t", errors, warnings)
	eq(errors, [] as Array[String], "errors")
	eq(warnings, [] as Array[String], "warnings")
	if cards.has("x"):
		eq(cards.x.rules_tooltip(cards), "Explore: reveal 2 territories, keep 1", "card text")


func test_explore_reveal_0_is_error() -> void:
	var errors: Array[String] = []
	var warnings: Array[String] = []
	DataLoader.parse_cards({"cards": [{"id": "x", "name": "X", "type": "action",
		"effects": [{"op": "explore", "reveal": 0}]}]}, resources(), "t", errors, warnings)
	has_msg(errors, "card 'x': effects[0]: 'reveal' must be an integer >= 1")
