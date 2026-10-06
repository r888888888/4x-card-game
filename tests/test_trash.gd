extends "res://tests/lib/test_case.gd"
## The trash op (backlog 082): the first effect that targets a card in hand, moving it to the `trashed` zone for the
## rest of the game. The fixture Purge (cost 1 food, trash) is local, not in TEST_CARDS, so other tests load while
## the op is missing.

const PURGE := {"id": "purge", "name": "Purge", "type": "action", "cost": {"food": 1}, "effects": [{"op": "trash"}]}


## A game on TEST_CARDS plus Purge whose hand holds exactly ids (in order, as new copies) and 1 food. Returns
## [engine, uids in the order of ids].
func hand_of(ids: Array) -> Array:
	var r := fixture_load([PURGE])
	check(r.errors.is_empty(), "test data should load: %s" % [r.errors])
	var errors: Array[String] = []
	var warnings: Array[String] = []
	var config := DataLoader.parse_config(raw_config({"farm": 10}), resources(), r.cards, "config.json", errors, warnings)
	check(errors.is_empty(), "config should load: %s" % [errors])
	var e := GameEngine.new(r.cards, config)
	e.new_game(1)
	for card in e.zone("hand").take_all():
		e.zone("deck").add(card)
	var uids: Array[int] = []
	for id in ids:
		uids.append(put_in_hand(e, id))
	e.resources.food = 1
	return [e, uids]


## Zone name -> ids in it, for the zones a play can change.
func snapshot(e: GameEngine) -> Dictionary:
	var out := {"food": e.resources.food}
	for z in ["hand", "deck", "discard", "trashed"]:
		out[z] = card_ids(e.zone(z))
	return out


# --- AC1: trash ---

func test_trash_moves_the_target_to_trashed() -> void:
	var h := hand_of(["purge", "scout"])
	var e: GameEngine = h[0]
	var purge: int = h[1][0]
	var scout: int = h[1][1]
	check(e.play_card(purge, scout), "play Purge on the Scout: %s" % e.play_error(purge, scout))
	eq(e.resources.food, 0, "paid 1 food")
	eq(card_ids(e.zone("trashed")), ["scout"] as Array[String], "trashed")
	for z in GameEngine.ZONES:
		if z != "trashed":
			check(e.zone(z).find(scout) == null, "the Scout is not in %s" % z)
	check(e.zone("discard").find(purge) != null, "Purge is in the discard")


func test_trash_outcome_names_the_trashed_card() -> void:
	var h := hand_of(["purge", "scout"])
	var e: GameEngine = h[0]
	var outcomes: Array = []
	e.card_played.connect(func(o): outcomes.append(o))
	e.play_card(h[1][0], h[1][1])
	eq(outcomes.size(), 1, "one card_played")
	if outcomes.size() == 1:
		eq(outcomes[0].get("trashed"), h[1][1], "outcome.trashed is the Scout's uid")


# --- AC2: targets ---

func test_valid_targets_are_the_other_hand_cards() -> void:
	var h := hand_of(["purge", "scout", "farm"])
	var e: GameEngine = h[0]
	eq(sorted(e.valid_targets(h[1][0])), sorted([h[1][1], h[1][2]]), "Scout and Farm, not Purge")
	check(e.needs_target(h[1][0]), "Purge needs a target")


# --- AC3: errors ---

func test_trash_with_no_other_hand_card_is_refused() -> void:
	var h := hand_of(["purge"])
	var e: GameEngine = h[0]
	var before := snapshot(e)
	eq(e.play_error(h[1][0]), "There is no other card in hand to trash.", "play_error")
	check(not e.play_card(h[1][0]), "play_card refuses")
	eq(snapshot(e), before, "nothing changed")


func test_trash_with_several_choices_needs_a_target() -> void:
	var h := hand_of(["purge", "scout", "farm"])
	var e: GameEngine = h[0]
	var before := snapshot(e)
	eq(e.play_error(h[1][0]), "Choose a card to trash.", "play_error")
	check(not e.play_card(h[1][0]), "play_card refuses")
	eq(snapshot(e), before, "nothing changed")


func test_trash_refuses_itself_or_a_card_not_in_hand() -> void:
	var h := hand_of(["purge", "scout"])
	var e: GameEngine = h[0]
	var purge: int = h[1][0]
	var in_deck: int = e.zone("deck").cards[0].uid
	var before := snapshot(e)
	for target in [purge, in_deck]:
		check(e.play_error(purge, target) != "", "target %d is refused" % target)
		check(not e.play_card(purge, target), "play_card refuses target %d" % target)
	eq(snapshot(e), before, "nothing changed")


# --- AC4: one target auto-picked ---

func test_the_only_other_hand_card_is_picked() -> void:
	var h := hand_of(["purge", "scout"])
	var e: GameEngine = h[0]
	eq(e.play_error(h[1][0]), "", "no target needed")
	check(e.play_card(h[1][0]), "play Purge without a target")
	eq(card_ids(e.zone("trashed")), ["scout"] as Array[String], "the Scout was trashed")


# --- AC5: never returns ---

func test_trashed_card_is_not_reshuffled() -> void:
	var h := hand_of(["purge", "scout"])
	var e: GameEngine = h[0]
	e.play_card(h[1][0], h[1][1])
	for card in e.zone("deck").take_all():
		e.zone("discard").add(card)
	e.draw(3)  # the empty deck reshuffles the discard
	eq(card_ids(e.zone("trashed")), ["scout"] as Array[String], "the Scout stays trashed")
	for z in ["deck", "hand", "discard"]:
		check(e.zone(z).find(h[1][1]) == null, "the Scout is not in %s" % z)


func test_fork_copies_the_trashed_zone() -> void:
	var h := hand_of(["purge", "scout"])
	var e: GameEngine = h[0]
	e.play_card(h[1][0], h[1][1])
	var f: GameEngine = e.fork()
	eq(card_ids(f.zone("trashed")), ["scout"] as Array[String], "fork trashed zone")
	check(f.zone("trashed").cards[0] != e.zone("trashed").cards[0], "a copy, not the same card")


# --- AC6: loader and text ---

func test_trash_loads() -> void:
	var r := fixture_load([PURGE])
	eq(r.errors, [] as Array[String], "errors")
	eq(r.warnings, [] as Array[String], "warnings")


func test_trash_validation() -> void:
	var prefix := "cards.json: card 'x': effects[0]: "
	check_cases([
		["on upkeep", [card_with("building", {"op": "trash", "trigger": "upkeep"})],
			prefix + "'trash' only works on play (got trigger 'upkeep')"],
		["on a tech", [card_with("tech", {"op": "trash"})], prefix + "a tech effect can't need a target"],
		["on an event", [card_with("event", {"op": "trash"})], prefix + "an event effect can't need a target"],
	], fixture_load)
	has_msg(fixture_load([card_with("action", {"op": "trash", "amount": 2})]).warnings, "unknown field 'amount' in 'trash' effect")


func test_trash_card_text() -> void:
	var cards: Dictionary = fixture_load([PURGE]).cards
	if not cards.has("purge"):
		check(false, "purge should load")
		return
	eq(cards.purge.rules_text(cards), "Remove a card in hand from the game", "rules_text")
