extends "res://tests/lib/raid_case.gd"
## Raid pacing (backlog 257): raids wait until the realm is large enough (`realm_size`, config `territory_value` and
## `raid_min_size`), strike two event phases after they are drawn (`raid_turns_left`), come at least `raid_gap` turns
## after the last strike, and only one is active at a time. A raid drawn too soon goes to the event deck's bottom and
## the next event is drawn in its place.

## Homeland and Hills settled, the Capital costs nothing: 6 with territory_value 3.
const BASE_SIZE := 6


## A raid_engine game with territory_value 3 and these overrides.
func paced_engine(ids_on_top: Array, overrides := {}, event_deck := {"raiders": 1, "horde": 1, "omen": 6}) -> GameEngine:
	var o := {"territory_value": 3}
	o.merge(overrides, true)
	return raid_engine(ids_on_top, event_deck, o)


## The config errors for raid_load's cards with the config keywords and overrides.
func pacing_config_errors(overrides: Dictionary) -> Array[String]:
	var o := {"keywords": keywords()}
	o.merge(overrides, true)
	return config_errors_for(raid_load().cards, o)


## Records every event_drawn outcome e emits into the returned array.
func record_events(e: GameEngine) -> Array[Dictionary]:
	var outcomes: Array[Dictionary] = []
	e.event_drawn.connect(func(o: Dictionary): outcomes.append(o))
	return outcomes


## The ids of the active events in e.
func active_ids(e: GameEngine) -> Array[String]:
	return card_ids(e.zone("active_events"))


## The id of the card at the bottom of e's event deck, or "".
func deck_bottom(e: GameEngine) -> String:
	var deck: Zone = e.zone("event_deck")
	return deck.cards[0].def.id if not deck.is_empty() else ""


# --- config ---

func test_raid_pacing_config_defaults_to_0_and_rejects_negatives() -> void:
	var e: GameEngine = raid_engine()
	if e == null:
		return
	eq([e.config.get("territory_value"), e.config.get("raid_min_size"), e.config.get("raid_gap")], [0, 0, 0], "defaults")
	eq(pacing_config_errors({"territory_value": 3, "raid_min_size": 12, "raid_gap": 4}), [] as Array[String], "valid")
	check_cases([
		["territory_value below 0", {"territory_value": -1}, "'territory_value' must be an integer >= 0"],
		["raid_min_size not an int", {"raid_min_size": "big"}, "'raid_min_size' must be an integer >= 0"],
		["raid_gap below 0", {"raid_gap": -2}, "'raid_gap' must be an integer >= 0"],
	], pacing_config_errors)


# --- AC1: the realm's size ---

func test_realm_size_counts_territories_and_the_cost_of_cities_buildings_and_units() -> void:
	var e: GameEngine = paced_engine(["omen"])
	if e == null:
		return
	eq(e.realm_size(), BASE_SIZE, "Homeland and Hills at 3 each; the Capital costs nothing")
	var capital: CardInstance = e.zone("tableau").find_id("capital")
	e.zone("tableau").remove(capital)
	build_on(e, hills_of(e), ["fort"])
	build_on(e, home_uid(e), ["stockade"])
	e.create_card("spearmen", "tableau", null)
	eq(e.realm_size(), 13, "3 + 3 + Fort 2 + Stockade 3 + Spearmen 2")
	e.create_card("stockade", "hand", null)
	e.create_card("spearmen", "discard", null)
	e.zone("tableau").find(hills_of(e)).pop = 4
	e.resources.wealth = 30
	eq(e.realm_size(), 13, "cards outside the tableau, pop and resources add nothing")


# --- AC2: a raid waits for a large enough realm ---

func test_a_raid_drawn_while_the_realm_is_too_small_goes_to_the_bottom_and_the_next_event_is_drawn() -> void:
	var e: GameEngine = paced_engine(["raiders", "omen"], {"raid_min_size": BASE_SIZE + 1})
	if e == null:
		return
	var events := record_events(e)
	e.end_turn()
	eq(active_ids(e), ["omen"] as Array[String], "Omen drawn in its place")
	eq(deck_bottom(e), "raiders", "Raiders at the event deck's bottom")
	eq(events.size(), 1, "one event_drawn")
	if events.size() == 1:
		eq(events[0].id, "omen", "for the Omen")


func test_a_raid_is_drawn_once_the_realm_reaches_the_minimum() -> void:
	var e: GameEngine = paced_engine(["raiders", "omen"], {"raid_min_size": BASE_SIZE + 3})
	if e == null:
		return
	build_on(e, home_uid(e), ["stockade"])
	e.end_turn()
	var raid := active_uid(e, "raiders")
	check(raid != -1, "Raiders active at size %d" % e.realm_size())
	eq(e.raid_target(raid), hills_of(e), "and announced")


# --- AC3: only raids left ---

func test_with_only_raids_left_and_none_allowed_no_event_is_drawn() -> void:
	var e: GameEngine = paced_engine(["raiders", "horde"], {"raid_min_size": 99}, {"raiders": 1, "horde": 1})
	if e == null:
		return
	var events := record_events(e)
	e.end_turn()
	eq(active_ids(e), [] as Array[String], "no event active")
	eq(events.size(), 0, "no event_drawn")
	eq(sorted(card_ids(e.zone("event_deck"))), ["horde", "raiders"], "both raids still in the event deck")
	eq(e.zone("event_discard").size(), 0, "none in the event discard")
	e.end_turn()
	eq(e.zone("event_deck").size() + e.zone("event_discard").size(), 2, "still both a turn later")


# --- AC4: two turns' warning ---

func test_raid_turns_left_counts_down_from_2() -> void:
	var e: GameEngine = paced_engine(["raiders", "omen", "omen"])
	if e == null:
		return
	e.end_turn()
	var raid := active_uid(e, "raiders")
	eq(e.raid_turns_left(raid), 2, "on the turn it is drawn")
	e.end_turn()
	eq(e.raid_turns_left(raid), 1, "the turn after")
	eq(e.raid_turns_left(active_uid(e, "omen")), 0, "an Omen")
	eq(e.raid_turns_left(9999), 0, "no card")
	e.end_turn()
	eq(e.raid_turns_left(raid), 0, "struck and discarded")


func test_a_raid_drawn_on_the_turn_before_the_final_turn_never_strikes() -> void:
	var e: GameEngine = paced_engine(["raiders", "omen"], {"turn_limit": 3})
	if e == null:
		return
	var outcomes := record_raids(e)
	e.end_turn()
	e.end_turn()
	e.end_turn()
	check(e.is_over, "game over")
	eq(outcomes.size(), 0, "Raiders, drawn on turn 2, never struck")


# --- AC5: the gap after a strike ---

func test_no_raid_is_drawn_until_raid_gap_turns_after_the_last_strike() -> void:
	var e: GameEngine = paced_engine(["raiders", "omen", "omen"], {"raid_gap": 4})
	if e == null:
		return
	var outcomes := record_raids(e)
	e.end_turn()
	check(active_uid(e, "raiders") != -1, "no gap before the first strike: Raiders drawn on turn 2")
	e.end_turn()
	for turn in [4, 5, 6, 7]:
		arrange(e.zone("event_deck"), ["horde"])
		e.end_turn()
		eq(e.state.turn, turn, "turn")
		eq(active_uid(e, "horde"), -1, "Horde deferred on turn %d" % turn)
		eq(deck_bottom(e), "horde", "Horde at the bottom on turn %d" % turn)
	eq(outcomes.size(), 1, "Raiders struck on turn 4")
	arrange(e.zone("event_deck"), ["horde"])
	e.end_turn()
	check(active_uid(e, "horde") != -1, "Horde drawn on turn 8, 4 turns after the strike")


func test_a_fork_keeps_the_gap() -> void:
	var e: GameEngine = paced_engine(["raiders", "omen", "omen"], {"raid_gap": 4})
	if e == null:
		return
	e.end_turn()
	e.end_turn()
	e.end_turn()
	var f: GameEngine = e.fork()
	arrange(f.zone("event_deck"), ["horde"])
	f.end_turn()
	eq(active_uid(f, "horde"), -1, "Horde deferred in the fork on turn 5")


# --- AC5b: one raid at a time ---

func test_a_raid_drawn_while_another_is_active_is_deferred() -> void:
	var e: GameEngine = paced_engine(["raiders", "horde", "omen"])
	if e == null:
		return
	e.end_turn()
	var raiders := active_uid(e, "raiders")
	e.end_turn()
	eq(active_uid(e, "horde"), -1, "Horde not drawn while Raiders is active")
	eq(deck_bottom(e), "horde", "Horde at the bottom")
	check("omen" in active_ids(e), "Omen drawn in its place")
	eq(active_uid(e, "raiders"), raiders, "Raiders still the one active raid")


# --- AC6: what the UI says ---

func test_raid_text_says_in_2_turns_then_next_turn() -> void:
	var e: GameEngine = paced_engine(["raiders", "omen", "omen"])
	if e == null:
		return
	e.end_turn()
	var raid := active_uid(e, "raiders")
	var hills := hills_of(e)
	eq(e.raid_line(raid), "Raiders will strike Hills in 2 turns: 3 against your 0.", "the line on turn 2")
	eq(e.raid_warning(hills), "Raiders strike in 2 turns: 3 vs 0", "the target's mark on turn 2")
	e.end_turn()
	eq(e.raid_line(raid), "Raiders will strike Hills next turn: 3 against your 0.", "the line on turn 3")
	eq(e.raid_warning(hills), "Raiders strike next turn: 3 vs 0", "the target's mark on turn 3")
	var db: Dictionary = raid_load().cards
	var tip: String = db.raiders.rules_tooltip(db)
	check("Raid 3: strikes your least defended mountain territory 2 turns after it is drawn" in tip, tip)


# --- 266: the discard comes back when only blocked raids are left in the deck ---

## Moves every id card from e's event deck to its event discard.
func discard_events(e: GameEngine, id: String) -> void:
	var deck: Zone = e.zone("event_deck")
	for c in deck.cards.duplicate():
		if c.def.id == id:
			deck.remove(c)
			e.zone("event_discard").add(c)


func test_bug_266_a_deck_of_raids_too_soon_to_draw_shuffles_the_discard_back_in() -> void:
	var e: GameEngine = paced_engine(["raiders"], {"raid_min_size": 99}, {"raiders": 1, "omen": 1})
	if e == null:
		return
	discard_events(e, "omen")
	var events := record_events(e)
	e.end_turn()
	eq(active_ids(e), ["omen"] as Array[String], "the Omen from the discard drawn")
	eq(events.size(), 1, "one event_drawn")
	if events.size() == 1:
		eq(events[0].id, "omen", "for the Omen")
	eq(card_ids(e.zone("event_deck")), ["raiders"] as Array[String], "Raiders still in the event deck")
	eq(e.zone("event_discard").size(), 0, "the event discard shuffled in")


func test_bug_266_raids_held_back_by_the_gap_dont_stop_the_events() -> void:
	var e: GameEngine = paced_engine(["raiders", "omen", "omen"], {"raid_gap": 4}, {"raiders": 1, "horde": 1, "omen": 3})
	if e == null:
		return
	var outcomes := record_raids(e)
	for i in 3:
		e.end_turn()
	eq(outcomes.size(), 1, "Raiders struck on turn 4")
	discard_events(e, "omen")
	eq(card_ids(e.zone("event_deck")), ["horde"] as Array[String], "only Horde left in the event deck")
	e.end_turn()
	eq(e.state.turn, 5, "turn 5, a turn after the strike")
	check("omen" in active_ids(e), "an Omen drawn from the discard: %s" % [active_ids(e)])
	eq(active_uid(e, "horde"), -1, "Horde not drawn inside the gap")
	check(e.zone("event_deck").find_id("horde") != null, "Horde back in the event deck")


func test_bug_266_with_only_raids_in_both_piles_none_is_drawn_or_lost() -> void:
	var e: GameEngine = paced_engine(["raiders"], {"raid_min_size": 99}, {"raiders": 1, "horde": 1})
	if e == null:
		return
	discard_events(e, "horde")
	var events := record_events(e)
	for i in 2:
		e.end_turn()
		eq(active_ids(e), [] as Array[String], "no event active on turn %d" % e.state.turn)
		eq(e.zone("event_deck").size() + e.zone("event_discard").size(), 2, "both raids kept on turn %d" % e.state.turn)
	eq(events.size(), 0, "no event_drawn")


func test_bug_266_a_drawable_event_in_the_deck_leaves_the_discard_alone() -> void:
	var e: GameEngine = paced_engine(["raiders", "omen"], {"raid_min_size": 99}, {"raiders": 1, "omen": 2})
	if e == null:
		return
	var spare: CardInstance = e.zone("event_deck").cards[0]
	e.zone("event_deck").remove(spare)
	e.zone("event_discard").add(spare)
	e.end_turn()
	eq(active_ids(e), ["omen"] as Array[String], "the Omen under Raiders drawn")
	eq(e.zone("event_discard").cards, [spare], "the discard not shuffled in")
	eq(card_ids(e.zone("event_deck")), ["raiders"] as Array[String], "Raiders at the bottom")
