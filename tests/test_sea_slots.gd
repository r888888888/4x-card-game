extends "res://tests/lib/test_case.gd"
## Sea slots (366): config sea_slots {keyword, tag, slots} gives every settled territory with the keyword that many
## extra slots only a building with the tag may fill. sea_slots / free_sea_slots; allocation in placement order (a
## tagged building takes a sea slot first); the build refusal, idling, status and tooltip; the loader.

const KEYWORDS: Array[String] = ["mountain", "fresh_water", "flood_plain", "coastal"]
const SEA := {"keyword": "coastal", "tag": "port", "slots": 1}
const TIERS := [
	{"id": "hamlet", "name": "Hamlet", "pop": 0, "slots": 0},
	{"id": "village", "name": "Village", "pop": 4, "slots": 1},
]
## Cove (coastal, 1 slot); Dock and Quay (port buildings); Shed (no tag).
const SEA_CARDS := [
	{"id": "cove", "name": "Cove", "type": "territory", "slots": 1, "keywords": ["coastal"]},
	{"id": "dock", "name": "Dock", "type": "building", "tags": ["port"]},
	{"id": "quay", "name": "Quay", "type": "building", "tags": ["port"]},
	{"id": "shed", "name": "Shed", "type": "building"},
]


## TEST_CARDS + SEA_CARDS parsed with the coastal keyword.
func sea_load() -> Dictionary:
	var errors: Array[String] = []
	var warnings: Array[String] = []
	var cards := DataLoader.parse_cards({"cards": TEST_CARDS.cards + SEA_CARDS}, resources(), "test", errors, warnings,
		KEYWORDS)
	return {"cards": cards, "errors": errors, "warnings": warnings}


## A game with population on (no tiers unless given), Cove and Jungle (1 slot, no keyword) settled at pop 3 each, the
## fixture buildings in the build menu and sea_slots (none when null); null after a failed check.
func sea_engine(sea: Variant = SEA, tiers: Variant = null) -> Object:  # scaffolding: sea_slots is new
	var errors: Array[String] = []
	var warnings: Array[String] = []
	var cards := cards_of(sea_load(), errors, warnings)
	var population := {"start": 1, "food_upkeep": 0, "vp_per_pop": 0}
	if tiers != null:
		population["tiers"] = tiers
	var o := {"population": population, "keywords": KEYWORDS, "territory_deck": {"cove": 1, "jungle": 1},
		"build_menu": {"dock": {}, "quay": {}, "shed": {}}}
	if sea != null:
		o["sea_slots"] = sea
	var config := DataLoader.parse_config(raw_config({"farm": 10}, o), resources(), cards, "config.json", errors, warnings)
	check(errors.is_empty(), "test data should load: %s" % [errors])
	if not errors.is_empty():
		return null
	var e := GameEngine.new(cards, config)
	e.new_game(1)
	settle(e, ["cove", "jungle"])
	for id in ["cove", "jungle"]:
		e.zone("tableau").find(uid_of(e.zone("tableau"), id)).pop = 3
	return e


func cove(e: Object) -> int:
	return uid_of(e.zone("tableau"), "cove")


func jungle(e: Object) -> int:
	return uid_of(e.zone("tableau"), "jungle")


## Builds each id on territory t in order, checking each build succeeds; returns their uids.
func build_all(e: Object, t: int, ids: Array) -> Array[int]:
	var out: Array[int] = []
	for id in ids:
		check(e.build(id, t), "build %s: %s" % [id, e.build_error(id, t)])
		out.append(e.zone("tableau").cards.back().uid)
	return out


## [total_slots, free_slots, sea_slots, free_sea_slots] of territory t.
func slots_of(e: Object, t: int) -> Array:
	return [e.total_slots(t), e.free_slots(t), e.sea_slots(t), e.free_sea_slots(t)]


# --- AC1: the sea slot on a territory with the keyword ---

func test_a_territory_with_the_keyword_has_a_sea_slot() -> void:
	var e := sea_engine()
	if e == null:
		return
	eq(slots_of(e, cove(e)), [1, 1, 1, 1], "Cove: 1 slot and 1 sea slot, both free")
	eq(slots_of(e, jungle(e)), [1, 1, 0, 0], "Jungle: no sea slot")
	var none := sea_engine(null)
	if none != null:
		eq(slots_of(none, cove(none)), [1, 1, 0, 0], "no sea_slots in the config: no sea slot")


# --- AC2: a port building takes the sea slot first ---

func test_a_port_building_takes_the_sea_slot_first_then_a_regular_one() -> void:
	var e := sea_engine()
	if e == null:
		return
	var dock := build_all(e, cove(e), ["dock"])
	eq(slots_of(e, cove(e)), [1, 1, 1, 0], "the Dock took the sea slot")
	var quay := build_all(e, cove(e), ["quay"])
	eq(slots_of(e, cove(e)), [1, 0, 1, 0], "the Quay took the regular slot")
	eq((dock + quay).map(func(uid): return e.is_idle(uid)), [false, false], "neither is idle")


# --- AC3: a port building fits beside a full regular slot ---

func test_a_port_building_fits_the_sea_slot_beside_a_full_regular_slot() -> void:
	var e := sea_engine()
	if e == null:
		return
	build_all(e, cove(e), ["shed"])
	check(e.build_targets("dock").has(cove(e)), "Cove is a target for the Dock: %s" % [e.build_targets("dock")])
	var dock := build_all(e, cove(e), ["dock"])
	check(not e.is_idle(dock[0]), "the Dock works")


# --- AC4: the sea slot refuses other buildings ---

func test_the_sea_slot_refuses_a_building_without_the_tag() -> void:
	var e := sea_engine()
	if e == null:
		return
	build_all(e, cove(e), ["shed"])
	eq(e.build_error("shed", cove(e)), "Its sea slot takes only port buildings.", "build_error")
	check(not e.build_targets("shed").has(cove(e)), "Cove isn't a target for a second Shed")
	var before: int = e.zone("tableau").size()
	check(not e.build("shed", cove(e)), "build refuses")
	eq(e.zone("tableau").size(), before, "nothing built")


# --- AC5: idling keeps tagged buildings in the sea slot ---

func test_losing_a_slot_idles_the_untagged_building_not_the_ones_in_the_sea_slot() -> void:
	var e := sea_engine(SEA, TIERS)
	if e == null:
		return
	var c := cove(e)
	e.zone("tableau").find(c).pop = 4  # a Village: 1 printed + 1 tier slot, and the sea slot
	var built := build_all(e, c, ["dock", "quay", "shed"])
	eq(built.map(func(uid): return e.is_idle(uid)), [false, false, false], "all three work at pop 4")
	e.zone("tableau").find(c).pop = 3  # a Hamlet: the tier slot is gone, 3 workers stay
	eq(built.map(func(uid): return e.is_idle(uid)), [false, false, true], "the Shed is idle; Dock and Quay work")


# --- AC6: status and tooltip ---

func test_the_status_and_tooltip_show_the_sea_slot() -> void:
	var e := sea_engine()
	if e == null:
		return
	var s: Dictionary = e.territory_status(cove(e))
	eq([s.get("sea_slots"), s.get("free_sea_slots")], [1, 1], "Cove's status")
	var lines: PackedStringArray = e.territory_tooltip(cove(e)).split("\n")
	var at := lines.find("Sea slot: 1 free of 1 (port buildings only)")
	check(at > 0 and lines[at - 1].begins_with("Building slots:"), "the sea slot line follows the slots line: %s" % [lines])
	var j: Dictionary = e.territory_status(jungle(e))
	check(not j.has("sea_slots") and not j.has("free_sea_slots"), "Jungle's status has no sea slot keys: %s" % [j])
	check(not e.territory_tooltip(jungle(e)).contains("Sea slot"), "Jungle's tooltip has no sea slot line")


# --- AC7: the loader ---

func test_sea_slots_validation() -> void:
	var cards: Dictionary = sea_load().cards
	check_cases([
		["unknown keyword", SEA.merged({"keyword": "swamp"}, true), ["sea_slots", "keyword"]],
		["slots 0", SEA.merged({"slots": 0}, true), ["sea_slots", "slots"]],
		["slots not an integer", SEA.merged({"slots": 1.5}, true), ["sea_slots", "slots"]],
	], func(sea): return config_errors_for(cards, {"keywords": KEYWORDS, "sea_slots": sea}))
