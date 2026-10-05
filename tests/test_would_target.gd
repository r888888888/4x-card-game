extends "res://tests/lib/test_case.gd"
## would_need_target and would_target (310): what a card in any zone would target if it were in the hand, so a bot can
## tell a card with nothing to act on (a settler and no frontier) from one with something.


## e.would_target(uid), held as Object until the query exists (red phase).
func targets(e: GameEngine, uid: int) -> Variant:
	var o: Object = e
	return o.call("would_target", uid)


## e.would_need_target(uid), held as Object until the query exists (red phase).
func needs(e: GameEngine, uid: int) -> Variant:
	var o: Object = e
	return o.call("would_need_target", uid)


# --- AC1: a building in the deck ---

func test_a_farm_in_the_deck_would_target_the_territory_with_a_free_slot() -> void:
	var e := make_engine({"farm": 10})
	var farm := uid_of(e.zone("deck"), "farm")
	check(farm != -1, "a Farm in the deck")
	var in_hand := first_in_hand(e)
	eq(e.valid_targets(in_hand), [home_uid(e)], "a Farm in the hand targets the homeland")
	eq(needs(e, farm), true, "a Farm needs a target")
	eq(targets(e, farm), [home_uid(e)], "the deck's Farm would target the homeland too")


# --- AC2: a settler and the frontier ---

func test_a_pioneer_in_the_discard_has_a_target_once_a_territory_is_discovered() -> void:
	var e := make_engine({"explorer": 10}, {"territory_deck": {"hills": 1, "grassland": 1}})
	var pioneer := put_in(e, "pioneer", "discard")
	eq(needs(e, pioneer), true, "settling needs a frontier territory")
	eq(targets(e, pioneer), [], "the frontier is empty")
	check(e.play_card(first_in_hand(e)), "play Explorer")
	var option: int = e.pending().options[0]
	check(e.choose(option), "choose a territory")
	eq(targets(e, pioneer), [option], "the chosen territory, now in the frontier")


# --- AC3: the hand's answer, and a card that needs no target ---

func test_for_a_hand_card_the_answers_match_needs_target_and_valid_targets() -> void:
	var e := make_engine({"farm": 3, "forager": 3}, {}, 1)
	for card in e.zone("hand").cards:
		eq(needs(e, card.uid), e.needs_target(card.uid), "%s needs a target" % card.def.id)
		eq(targets(e, card.uid), e.valid_targets(card.uid), "%s targets" % card.def.id)


func test_a_forager_anywhere_needs_no_target() -> void:
	var e := make_engine({"farm": 10})
	for zone_name in ["hand", "deck", "discard"]:
		var forager := put_in(e, "forager", zone_name)
		eq(needs(e, forager), false, "Forager in the %s" % zone_name)
		eq(targets(e, forager), [], "Forager in the %s" % zone_name)


# --- AC4: no card, game over, nothing changes ---

func test_a_uid_in_no_zone_or_a_finished_game_has_no_targets() -> void:
	var e := make_engine({"farm": 10})
	eq(needs(e, 9999), false, "no card 9999")
	eq(targets(e, 9999), [], "no card 9999")
	var over := over_engine()
	var farm := uid_of(over.zone("discard"), "farm")
	check(farm != -1, "a Farm in the finished game's discard")
	eq(needs(over, farm), false, "game over")
	eq(targets(over, farm), [], "game over")


func test_asking_changes_nothing() -> void:
	var e := make_engine({"farm": 10})
	var farm := uid_of(e.zone("deck"), "farm")
	var deck: Array = e.zone("deck").cards.map(func(c): return c.uid)
	var log_size: int = e.log_lines.size()
	var emitted := []
	for s in ["changed", "logged", "noticed"]:
		e.connect(s, func(_a = null, _b = null): emitted.append(s))
	needs(e, farm)
	targets(e, farm)
	eq(e.zone_of(farm), "deck", "the Farm stays in the deck")
	eq(e.zone("deck").cards.map(func(c): return c.uid), deck, "the deck's order")
	eq(e.log_lines.size(), log_size, "nothing logged")
	eq(emitted, [], "no signals")
