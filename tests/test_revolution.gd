extends "res://tests/lib/anarchy_case.gd"
## Revolution events (backlog 148): an active event with `"revolt": true` lets the player revolt, starting Anarchy at
## once (145's fall) with renewal owed at once (147). The Revolt button sits below the Realm; the bot revolts when a
## government in hand ends the Anarchy at once. Fixtures: tests/lib/anarchy_case.gd, plus Reform (event, revolt,
## renewal +1, 2 turns) and Quiet (event, no revolt).

const REFORM := {"id": "reform", "name": "Reform", "type": "event", "revolt": true, "discard": {"turns": 2},
	"modifiers": {"renewal": 1}}
const QUIET := {"id": "quiet", "name": "Quiet", "type": "event"}
const EVENTS := [REFORM, QUIET]
const RENEWAL := {"renewal": 1}
const REVOLT_TEXT := "While active, you may revolt."


## A renewal game (unrest.renewal 1) with event_id active ("" for none), discard_ids in the discard and unrest.
func revolt_engine(event_id: String, discard_ids := ["farm", "scout", "shrine"], unrest := 2) -> GameEngine:
	var e := anarchy_engine(RENEWAL, {}, EVENTS)
	if event_id != "":
		e.create_card(event_id, "active_events", null).turns_left = 2
	for id in discard_ids:
		e.create_card(id, "discard", null)
	e.resources["unrest"] = unrest
	return e


# --- AC1: the event field and its text ---

func test_an_event_with_revolt_loads_and_says_so() -> void:
	var errors: Array[String] = []
	var warnings: Array[String] = []
	var cards := DataLoader.parse_cards({"cards": TEST_CARDS.cards + EVENTS}, RESOURCES, "cards.json", errors, warnings,
		keywords())
	eq(warnings, [] as Array[String], "warnings")
	eq(cards.reform.get("revolt"), true, "Reform's revolt")
	eq(cards.quiet.get("revolt"), false, "Quiet's revolt")
	check(cards.reform.rules_text(cards).contains(REVOLT_TEXT), "face: %s" % cards.reform.rules_text(cards))
	check(cards.reform.rules_tooltip(cards).contains(REVOLT_TEXT), "tooltip: %s" % cards.reform.rules_tooltip(cards))
	check(not cards.quiet.rules_tooltip(cards).contains(REVOLT_TEXT), "not on Quiet")


func test_revolt_validation() -> void:
	var load_cards := func(extra: Array) -> Dictionary:
		var errors: Array[String] = []
		var warnings: Array[String] = []
		DataLoader.parse_cards({"cards": TEST_CARDS.cards + extra}, RESOURCES, "cards.json", errors, warnings, keywords())
		return {"errors": errors, "warnings": warnings}
	check_cases([
		["not a boolean", [{"id": "x", "name": "X", "type": "event", "revolt": "yes"}], ["cards.json: card 'x'", "revolt"],
			"one_error"],
		["on an action", [{"id": "x", "name": "X", "type": "action", "revolt": true}],
			"'revolt' only applies to events (ignored)", "warning_only"],
	], load_cards)


# --- AC2: revolting ---

func test_revolting_starts_anarchy_with_renewal_owed_at_once() -> void:
	var e := revolt_engine("reform")
	var recorded := record_messages(e)
	eq(e.revolt_error(), "", "revolt_error")
	check(e.revolt(), "revolt: %s" % e.revolt_error())
	eq(ruling(e), "anarchy", "Anarchy rules")
	check(uid_of(e.zone("governments"), "chiefs") != -1, "Chiefs goes to the government deck (154)")
	eq(e.anarchy_counters(), 0, "0 counters")
	check_noticed(recorded, "Anarchy")
	var p: Dictionary = e.pending()
	eq([p.get("kind"), p.get("count")], ["renewal", 2], "renewal owed: 1 + 0 counters + Reform 1")
	eq(e.actions_left(), e.actions_per_turn(), "revolting uses no action: Anarchy's 1 of 1 left")


# --- AC3: revolt_error ---

func test_revolt_error_names_each_reason_and_a_refusal_changes_nothing() -> void:
	var quiet := revolt_engine("quiet")
	eq(quiet.revolt_error(), "Only a revolutionary event lets you revolt.", "a non-revolutionary event")
	eq(revolt_engine("").revolt_error(), "Only a revolutionary event lets you revolt.", "no event")
	check(not quiet.revolt(), "revolt refuses")
	eq([ruling(quiet), quiet.pending()], ["chiefs", {}], "unchanged")
	var over := revolt_engine("reform")
	over.is_over = true
	eq(over.revolt_error(), "The game is over.", "game over")
	var anarchy := revolt_engine("reform")
	anarchy.revolt()
	for uid in anarchy.pending().options.duplicate():
		anarchy.renew(uid)
	eq(anarchy.revolt_error(), "Anarchy already rules.", "during Anarchy")


func test_revolt_waits_for_a_pending_discard() -> void:
	var e := revolt_engine("reform")
	for i in e.config.hand_limit + 1 - e.zone("hand").size():
		put_in_hand(e, "farm")
	e.end_turn()  # the hand is over its limit: a discard is owed
	eq(e.revolt_error(), "Discard down to %d cards first." % e.config.hand_limit, "pending discard")


# --- AC4: the Revolt button ---

func test_the_revolt_button_shows_while_you_may_revolt() -> void:
	await with_main(anarchy_engine(RENEWAL, {}, EVENTS), func(main: Node):
		var e := Game.engine
		var revolt: Button = main.revolt_button()
		await wait_frames()
		check(not revolt.is_visible_in_tree(), "hidden with no revolutionary event")
		e.create_card("reform", "active_events", null).turns_left = 2
		e.create_card("farm", "discard", null)
		e.changed.emit()
		await wait_frames()
		check(revolt.is_visible_in_tree(), "shown while Reform is active")
		check(revolt.tooltip_text.contains("Anarchy"), "the tooltip says what revolting does: %s" % revolt.tooltip_text)
		revolt.pressed.emit()
		await wait_frames()
		eq(ruling(e), "anarchy", "pressing it revolts")
		check(not revolt.is_visible_in_tree(), "hidden during Anarchy"))


# --- AC5: the bot ---

func test_the_bot_revolts_when_a_government_in_hand_ends_it_at_once() -> void:
	var e := revolt_engine("reform", ["farm", "scout"], 2)
	put_in_hand(e, "kings")
	ScriptedBot.take_turn(e, "baseline")
	eq(ruling(e), "kings", "revolted, renewed and played Kings (accepted at 3 or less)")
	check(not e.zone("trashed").is_empty(), "renewal trashed a card")


func test_the_bot_doesnt_revolt_without_such_a_government() -> void:
	var none := revolt_engine("reform")
	ScriptedBot.take_turn(none, "baseline")
	eq(ruling(none), "chiefs", "no government in hand")
	var restless := revolt_engine("reform", ["farm"], 4)
	put_in_hand(restless, "kings")
	ScriptedBot.take_turn(restless, "baseline")
	check(ruling(restless) != "anarchy", "unrest 4 > Kings' 7 / 2: no revolt (got %s)" % ruling(restless))
	eq(restless.zone("trashed").size(), 0, "no renewal")
