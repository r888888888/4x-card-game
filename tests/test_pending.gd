extends "res://tests/lib/tech_case.gd"
## The pending-decision model (backlog 050): pending() describes what the player owes (an explore choice,
## open research, a hand-limit discard), and one blocking rule applies to every action.

const POP_ON := {"population": {"start": 2, "food_upkeep": 0, "vp_per_pop": 1}}


## pending() with options as a plain Array, for comparing.
func pending_of(e: Object) -> Dictionary:
	var p: Dictionary = e.pending().duplicate()
	if p.has("options"):
		p.options = Array(p.options)
	return p


## A game (population on) with pottery and writing on top of the research deck and a territory deck of
## hills, grassland, jungle (top first). deck is the main deck; overrides replace config keys.
func pending_engine(deck := {"farm": 10}, overrides := {}) -> Object:
	var config := {"territory_deck": {"hills": 1, "grassland": 1, "jungle": 1}}
	config.merge(POP_ON)
	config.merge(overrides, true)
	var e: Object = tech_engine(["pottery", "writing"], deck, config)
	arrange(e.zone("territory_deck"), ["hills", "grassland", "jungle"])
	return e


## A game with an explore choice open.
func explore_engine() -> Object:
	var e := pending_engine()
	check(e.play_card(put_in_hand(e, "explorer")), "play Explorer")
	return e


## A game with pottery and writing revealed.
func pending_research_engine() -> Object:
	var e := pending_engine()
	check(play_research(e), "research should open")
	return e


## A game with hand limit 5 and 7 cards in hand at end_turn: 2 to discard.
func discard_engine() -> Object:
	var e := pending_engine({"scout": 10}, {"hand_limit": 5})
	for i in 2:
		check(e.play_card(first_in_hand(e)), "play Scout %d" % i)
	eq(e.zone("hand").size(), 7, "hand")
	e.end_turn()
	return e


func hand_uids(e: Object) -> Array:
	return e.zone("hand").cards.map(func(c): return c.uid)


# --- AC1: nothing owed ---

func test_pending_is_empty_when_nothing_is_owed() -> void:
	eq(pending_of(pending_engine()), {}, "pending")


# --- AC2: explore ---

## Options come top of the reveal zone first, as in pending_choice: Grassland (drawn last) before Hills.
func test_pending_explore_lists_the_revealed_territories_top_first() -> void:
	var e := pending_engine()
	var hills := uid_of(e.zone("territory_deck"), "hills")
	var grassland := uid_of(e.zone("territory_deck"), "grassland")
	var explorer := put_in_hand(e, "explorer")
	check(e.play_card(explorer), "play Explorer")
	eq(pending_of(e), {"kind": "explore", "options": [grassland, hills], "source": explorer}, "pending")


# --- AC3: research ---

func test_pending_research_lists_the_revealed_techs() -> void:
	var e := pending_research_engine()
	var r: Zone = e.zone("research_reveal")
	eq(pending_of(e), {"kind": "research", "options": [uid_of(r, "pottery"), uid_of(r, "writing")]}, "pending")


# --- AC4: discard ---

func test_pending_discard_counts_down_and_offers_the_hand() -> void:
	var e := discard_engine()
	eq(pending_of(e), {"kind": "discard", "count": 2, "options": hand_uids(e)}, "pending at end_turn")
	check(e.discard_card(first_in_hand(e)), "discard one")
	eq(pending_of(e), {"kind": "discard", "count": 1, "options": hand_uids(e)}, "pending after one discard")


# --- AC5: one blocking rule ---

func test_each_pending_kind_blocks_actions_as_before() -> void:
	var discard_msg := "Discard down to 5 cards first."
	var cases := [
		["explore", explore_engine(), "Choose a territory first.", "Choose a territory first.", false],
		["research", pending_research_engine(), "Buy a tech or decline first.", "Buy a tech or decline first.", false],
		["discard", discard_engine(), discard_msg, "", true],
	]
	for row in cases:
		var kind: String = row[0]
		var e: Object = row[1]
		var msg: String = row[2]
		eq(e.pending().get("kind", ""), kind, "%s: pending kind" % kind)
		eq(e.play_error(first_in_hand(e)), msg, "%s: play_error" % kind)
		eq(e.grow_error(home_uid(e)), msg, "%s: grow_error" % kind)
		eq(e.buy_error("scout"), msg, "%s: buy_error" % kind)
		eq(e.end_turn_error(), msg, "%s: end_turn_error" % kind)
		eq(e.supply_error(), row[3], "%s: supply_error" % kind)
		eq(e.discard_error(first_in_hand(e)), "" if row[4] else msg, "%s: discard_error (093)" % kind)
		eq(e.discard_card(first_in_hand(e)), row[4], "%s: discard_card" % kind)
