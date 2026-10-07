extends "res://tests/lib/anarchy_case.gd"
## Unit upgrades (backlog 166): a unit with `upgrades_to` (another unit's id) can be re-equipped in place once that
## unit's build-menu entry is unlocked, for the difference in printed cost (`upgrade_cost`): `upgrade_unit` /
## `upgrade_unit_error`. The new card keeps the old one's home, station, veteran counters and tableau place; the old
## one goes to `removed`. No action is used.

## Levy: cost 1 food, upgrades to Pikes. Pikes: cost 3 food 1 wealth, strength 3. Club: cost 2 food 2 wealth, upgrades
## to Pikes (it costs more wealth than Pikes). Hut: a building.
const LEVY := {"id": "levy", "name": "Levy", "type": "unit", "cost": {"food": 1}, "strength": 2, "upgrades_to": "pikes"}
const PIKES := {"id": "pikes", "name": "Pikes", "type": "unit", "cost": {"food": 3, "wealth": 1}, "strength": 3}
const CLUB := {"id": "club", "name": "Club", "type": "unit", "cost": {"food": 2, "wealth": 2}, "strength": 2,
	"upgrades_to": "pikes"}
const UNITS := [LEVY, PIKES, CLUB]
const OPEN := {"build_menu": {"pikes": {}}, "territory_deck": {"hills": 1, "grassland": 1}}


## TEST_CARDS plus UNITS and extra, parsed: {cards, errors, warnings}.
func unit_load(extra := []) -> Dictionary:
	return fixture_load(extra, [UNITS])


## An anarchy game (Chiefs ruling, home pop 6, 10 food, wealth and insight) with UNITS loaded, Pikes on the build menu
## and Hills to settle (overrides last: {"build_menu": {"pikes": {"locked": true}}} locks it), and a Levy recruited on
## Homeland.
func upgrade_engine(overrides := OPEN, unrest := {}) -> GameEngine:
	var e := anarchy_engine(unrest, overrides, UNITS)
	var levy := put_in_hand(e, "levy")
	check(e.play_card(levy, home_uid(e)), "Levy recruited on Homeland: %s" % e.play_error(levy, home_uid(e)))
	return e


## The first Levy's uid in e's tableau.
func levy_of(e: GameEngine) -> int:
	return uid_of(e.zone("tableau"), "levy")


# --- AC1: the loader ---

func test_upgrades_to_loads_on_units() -> void:
	check_loads([
		["Levy, Pikes and Club", [], {"cards.levy.upgrades_to": "pikes", "cards.club.upgrades_to": "pikes",
			"cards.pikes.upgrades_to": ""}],
	], unit_load)


func test_bad_upgrades_to_is_a_load_error() -> void:
	check_cases([
		["unknown card", [{"id": "x", "name": "X", "type": "unit", "strength": 1, "upgrades_to": "dragon"}],
			"cards.json: card 'x': upgrades_to: unknown card 'dragon'"],
		["not a unit", [{"id": "x", "name": "X", "type": "unit", "strength": 1, "upgrades_to": "farm"}],
			"cards.json: card 'x': upgrades_to: 'farm' is not a unit"],
		["not a string", [{"id": "x", "name": "X", "type": "unit", "strength": 1, "upgrades_to": 3}],
			"cards.json: card 'x': 'upgrades_to' must be a string"],
		["on a building", [{"id": "x", "name": "X", "type": "building", "upgrades_to": "pikes"}],
			"cards.json: card 'x': 'upgrades_to' only applies to units (ignored)", "warning_only"],
	], unit_load)


func test_upgrades_to_text() -> void:
	var db: Dictionary = unit_load().cards
	check(db.has("levy"), "levy loaded")
	if not db.has("levy"):
		return
	check("Upgrades to Pikes." in db.levy.rules_text(db), "face: %s" % db.levy.rules_text(db))
	check("Upgrades to Pikes." in db.levy.rules_tooltip(db), "tooltip: %s" % db.levy.rules_tooltip(db))
	check("Upgrades" not in db.pikes.rules_tooltip(db), "Pikes has no upgrade: %s" % db.pikes.rules_tooltip(db))


# --- AC2: the upgrade ---

func test_upgrading_a_unit_replaces_it_in_place_for_the_difference() -> void:
	var e := upgrade_engine()
	var levy := levy_of(e)
	settle(e, ["hills"])
	var hills := uid_of(e.zone("tableau"), "hills")
	check(e.move_unit(levy, hills), "the Levy marches to Hills: %s" % e.move_unit_error(levy, hills))
	e.zone("tableau").find(levy).counters = 1  # a veteran (165)
	e.resources["food"] = 2
	e.resources["wealth"] = 1
	var actions := e.actions_left()
	var place := e.zone("tableau").cards.find(e.zone("tableau").find(levy))
	eq(e.upgrade_unit_error(levy), "", "legal")
	check(e.upgrade_unit(levy), "upgraded")
	eq([e.resources.food, e.resources.wealth], [0, 0], "paid 2 food and 1 wealth")
	check(e.zone("removed").find(levy) != null, "the Levy is in removed")
	check(e.zone("tableau").find(levy) == null, "and not in the tableau")
	var pikes := uid_of(e.zone("tableau"), "pikes")
	check(pikes != -1, "a Pikes in the tableau")
	if pikes == -1:
		return
	var card: CardInstance = e.zone("tableau").find(pikes)
	eq([card.territory_uid, e.unit_station(pikes), e.unit_veterancy(pikes)], [home_uid(e), hills, 1],
		"home, station and veteran counters kept")
	eq(e.zone("tableau").cards.find(card), place, "the Levy's place in the tableau")
	eq(e.actions_left(), actions, "no action used")
	eq(e.build_menu(), ["pikes"] as Array[String], "the build menu is unchanged")


# --- AC3: the price ---

func test_upgrade_cost_is_the_printed_difference_never_below_0() -> void:
	var e := upgrade_engine()
	eq(e.upgrade_cost(levy_of(e)), {"food": 2, "wealth": 1}, "Levy → Pikes: 3 − 1 food, 1 − 0 wealth")
	var club := put_in_hand(e, "club")
	check(e.play_card(club, home_uid(e)), "Club recruited: %s" % e.play_error(club, home_uid(e)))
	eq(e.upgrade_cost(club), {"food": 1}, "Club → Pikes: 3 − 2 food; wealth 1 − 2 costs nothing")
	var pikes := put_in_hand(e, "pikes")
	eq(e.upgrade_cost(pikes), {}, "a unit in hand")
	eq(e.upgrade_cost(home_uid(e)), {}, "a territory")


# --- AC4: errors ---

func test_upgrade_unit_errors() -> void:
	var e := upgrade_engine()
	var levy := levy_of(e)
	var pikes_hand := put_in_hand(e, "pikes")
	eq(e.upgrade_unit_error(home_uid(e)), "That isn't a unit in your realm.", "a territory")
	eq(e.upgrade_unit_error(pikes_hand), "That isn't a unit in your realm.", "a unit in hand")
	var club := put_in_hand(e, "club")
	check(e.play_card(club, home_uid(e)), "Club recruited")
	var pikes := put_in_hand(e, "pikes")
	e.resources["food"] = 10
	e.resources["wealth"] = 10
	check(e.play_card(pikes, home_uid(e)), "Pikes recruited: %s" % e.play_error(pikes, home_uid(e)))
	eq(e.upgrade_unit_error(pikes), "Pikes can't be upgraded.", "no upgrades_to")
	e.resources["food"] = 1
	eq(e.upgrade_unit_error(levy), "Upgrading Levy needs 2 food (you have 1).", "short of food only")
	e.resources["food"] = 0
	e.resources["wealth"] = 0
	eq(e.upgrade_unit_error(levy), "Upgrading Levy needs 2 food, 1 wealth (you have 0 food, 0 wealth).",
		"short of both")


func test_a_locked_or_missing_entry_cant_be_upgraded_to() -> void:
	for overrides in [{"build_menu": {"pikes": {"locked": true}}}, {"build_menu": {"farm": {}}}]:
		var e := upgrade_engine(overrides)
		eq(e.upgrade_unit_error(levy_of(e)), "Pikes isn't unlocked yet.", "%s" % [overrides])


func test_no_upgrade_under_anarchy() -> void:
	var e := upgrade_engine()
	var levy := levy_of(e)
	e.resources["unrest"] = 5
	e.end_turn()
	check(e.zone("active_events").find_id("anarchy") != null, "Anarchy rules")
	e.resources["food"] = 10
	e.resources["wealth"] = 10
	var build := e.build_error("pikes", home_uid(e))
	check(build.begins_with("Anarchy"), "building is refused: %s" % build)
	eq(e.upgrade_unit_error(levy), build, "the build message")


func test_no_upgrade_while_a_decision_is_owed_or_after_the_game() -> void:
	var e := upgrade_engine(OPEN.merged({"hand_limit": 5}))
	for i in 3:
		put_in_hand(e, "farm")
	e.end_turn()
	check(e.discard_needed() > 0, "a discard is owed")
	eq(e.upgrade_unit_error(levy_of(e)), "Discard down to 5 cards first.", "discard owed")
	var over := upgrade_engine()
	over.is_over = true
	eq(over.upgrade_unit_error(levy_of(over)), "The game is over.", "game over")


func test_a_refused_upgrade_changes_nothing() -> void:
	var e := upgrade_engine()
	var levy := levy_of(e)
	e.resources["food"] = 1
	var food: int = e.resources.food
	var tableau := e.zone("tableau").cards.map(func(c): return c.uid)
	check(not e.upgrade_unit(levy), "refused")
	eq(e.resources.food, food, "food")
	eq(e.zone("tableau").cards.map(func(c): return c.uid), tableau, "tableau")
	eq(e.zone("removed").size(), 0, "nothing removed")


# --- AC5: idle ---

func test_an_upgraded_unit_keeps_its_place_among_the_workers() -> void:
	var e := upgrade_engine()
	var first := levy_of(e)
	var second := put_in_hand(e, "levy")
	check(e.play_card(second, home_uid(e)), "a second Levy recruited")
	for pop in range(6, -1, -1):
		set_home_pop(e, pop)
		if e.is_idle(second) and not e.is_idle(first):
			break
	check(e.is_idle(second) and not e.is_idle(first), "the second Levy idle, the first working")
	e.resources["food"] = 10
	check(e.upgrade_unit(second), "the idle Levy upgraded: %s" % e.upgrade_unit_error(second))
	var idle_pikes := uid_of(e.zone("tableau"), "pikes")
	check(e.is_idle(idle_pikes), "its Pikes is idle")
	check(not e.is_idle(first), "the first Levy still works")
	check(e.upgrade_unit(first), "the working Levy upgraded: %s" % e.upgrade_unit_error(first))
	var working := e.zone("tableau").cards.filter(func(c): return c.def.id == "pikes" and c.uid != idle_pikes)
	check(working.size() == 1 and not e.is_idle(working[0].uid), "its Pikes works")
	check(e.is_idle(idle_pikes), "the other Pikes is still idle")
