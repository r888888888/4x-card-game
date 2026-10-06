extends "res://tests/lib/test_case.gd"
## Buildings that need a settlement tier (301): a building or upgrade with tier is built only on a territory at that
## tier or larger, falls back (counts for nothing, keeping its slot and worker) while its territory is smaller, and
## works again by itself when it grows back; the tier notices name the cards that fall back or come back. The loader.

const TIERS := [
	{"id": "hamlet", "name": "Hamlet", "pop": 0, "slots": 0},
	{"id": "village", "name": "Village", "pop": 4, "slots": 1},
	{"id": "town", "name": "Town", "pop": 8, "slots": 2},
	{"id": "metropolis", "name": "Metropolis", "pop": 13, "slots": 3},
]
const CHAPEL := {"id": "chapel", "name": "Chapel", "type": "building", "cost": {"food": 1}}
const SANCTUM := {"id": "sanctum", "name": "Sanctum", "type": "building", "cost": {"food": 1}, "upgrade_of": "chapel",
	"tier": "village", "modifiers": {"hand_size": 1}}
const CATHEDRAL := {"id": "cathedral", "name": "Cathedral", "type": "building", "cost": {"food": 1},
	"upgrade_of": "sanctum", "tier": "town", "vp": 2}
const FORUM := {"id": "forum", "name": "Forum", "type": "building", "cost": {"food": 1}, "tier": "town", "vp": 1,
	"effects": [{"op": "gain", "resource": "food", "amount": 1, "trigger": "upkeep"}]}
## Not in the item's fixture: an upgrade on the Sanctum with no tier of its own, so two cards fall back at once.
const BELL := {"id": "bell", "name": "Bell", "type": "building", "upgrade_of": "sanctum"}
const CARDS := [CHAPEL, SANCTUM, CATHEDRAL, FORUM, BELL]
const MENU := {"farm": {}, "chapel": {}, "sanctum": {}, "cathedral": {}, "forum": {}, "bell": {}}


## A game with population on (the fixture tiers, or none when tiers is null), build_menu MENU, no government (unlimited
## actions), plenty of food and Homeland at pop.
func tier_engine(pop: int, tiers: Variant = TIERS) -> GameEngine:
	var population := {"start": 2, "food_upkeep": 0, "vp_per_pop": 0}
	if tiers != null:
		population["tiers"] = tiers
	var e := make_engine({"scout": 10}, {"build_menu": MENU, "population": population,
		"starting": {"resources": {"food": 50}, "tableau": ["capital"], "territory": "homeland"}}, 1, CARDS)
	set_home_pop(e, pop)
	return e


## A new copy of building id straight on Homeland, unpaid: its uid.
func put_home(e: GameEngine, id: String) -> int:
	build_on(e, home_uid(e), [id])
	return e.zone("tableau").cards.back().uid


## Builds id on target, failing the test if it refuses: the new card's uid.
func build_it(e: GameEngine, id: String, target: int) -> int:
	check(e.build(id, target), "build %s: %s" % [id, e.build_error(id, target)])
	return e.zone("tableau").cards.back().uid


## The Capital, as the source of a pop change.
func source(e: GameEngine) -> CardInstance:
	return e.zone("tableau").find(uid_of(e.zone("tableau"), "capital"))


func food_forecast(e: GameEngine) -> int:
	return e.upkeep_forecast().get(GameEngine.FOOD, 0)


# --- AC1: the loader and the text ---

## The cards and the config's errors and warnings: CARDS plus extra, population with tiers (none when tiers is null).
func tier_load(extra := [], tiers: Variant = TIERS) -> Dictionary:
	var r := fixture_load(CARDS + extra)
	var errors: Array[String] = []
	var warnings: Array[String] = []
	errors.append_array(r.errors)
	warnings.append_array(r.warnings)
	var population := {"start": 2, "food_upkeep": 0, "vp_per_pop": 0}
	if tiers != null:
		population["tiers"] = tiers
	DataLoader.parse_config(raw_config({"farm": 1}, {"population": population}), resources(), r.cards, "config.json",
		errors, warnings)
	return {"cards": r.cards, "errors": errors, "warnings": warnings}


func test_a_building_loads_its_tier() -> void:
	var r := tier_load()
	eq(r.errors, [] as Array[String], "errors")
	eq(r.warnings, [] as Array[String], "warnings")
	eq(r.cards["forum"].get("tier"), "town", "Forum's tier")
	eq(r.cards["sanctum"].get("tier"), "village", "Sanctum's tier")
	eq(r.cards["chapel"].get("tier"), "", "a Chapel needs none")


func test_tier_validation() -> void:
	check_cases([
		["unknown tier", [[{"id": "x", "name": "X", "type": "building", "tier": "dragon"}], TIERS],
			"config.json: card 'x': tier: unknown tier 'dragon'"],
		["not a string", [[{"id": "x", "name": "X", "type": "building", "tier": 2}], TIERS],
			"cards.json: card 'x': 'tier' must be a string"],
		["tiers off", [[], null], "config.json: card 'forum': 'tier' needs population.tiers (ignored)", "warning_only"],
		["on an action", [[{"id": "x", "name": "X", "type": "action", "tier": "town"}], TIERS],
			"cards.json: card 'x': 'tier' only applies to buildings (ignored)", "warning_only"],
	], func(args): return tier_load(args[0], args[1]))


func test_a_tiers_text_names_it_after_the_upgrade_line() -> void:
	var e := tier_engine(4)
	var sanctum: CardDef = e.card_db["sanctum"]
	var forum: CardDef = e.card_db["forum"]
	eq(Array(sanctum.rules_text(e.card_db).split("\n")).slice(0, 2), ["Builds on a Chapel.", "Needs a Village."],
		"the Sanctum's face text")
	eq(Array(sanctum.rules_tooltip(e.card_db).split("\n")).slice(0, 2), ["Builds on a Chapel.", "Needs a Village."],
		"the Sanctum's tooltip")
	eq(forum.rules_text(e.card_db).split("\n")[0], "Needs a Town.", "the Forum's face text")
	eq(e.def_details("forum").rules[0], "Needs a Town.", "the Forum's details")


func test_with_tiers_off_a_tier_is_ignored() -> void:
	var e := tier_engine(1, null)
	eq(e.build_error("forum", home_uid(e)), "", "a Forum builds on a pop 1 Homeland")
	var forum := build_it(e, "forum", home_uid(e))
	eq(e.fallen_back_reason(forum), "", "and works")
	check(not (e.card_db["forum"] as CardDef).rules_text(e.card_db).contains("Needs"), "no tier line")


# --- AC2: built only at the tier ---

func test_an_upgrade_with_a_tier_builds_only_where_its_base_stands_at_that_tier() -> void:
	var e := tier_engine(3)
	var chapel := put_home(e, "chapel")
	eq(e.build_error("sanctum", chapel), "Sanctum needs a Village (Homeland is a Hamlet).", "at pop 3")
	eq(e.build_targets("sanctum"), [] as Array[int], "no target at pop 3")
	eq(e.build_error("sanctum"), "Sanctum needs a Village.", "no target named")
	check(not e.build("sanctum", chapel), "refused")
	set_home_pop(e, 4)
	eq(e.build_error("sanctum", chapel), "", "at pop 4")
	eq(e.build_targets("sanctum"), [chapel] as Array[int], "the Chapel at pop 4")
	build_it(e, "sanctum", chapel)


func test_a_building_with_a_tier_builds_only_on_a_territory_at_that_tier() -> void:
	var e := tier_engine(4)
	var home := home_uid(e)
	eq(e.build_error("forum", home), "Forum needs a Town (Homeland is a Village).", "at pop 4")
	check(not e.build_targets("forum").has(home), "Homeland isn't a target")
	eq(e.build_error("forum"), "Forum needs a Town.", "no target named")
	check(not e.build("forum", home), "refused")
	set_home_pop(e, 8)
	var slots: int = e.free_slots(home)
	var workers: int = e.free_workers(home)
	eq(e.build_targets("forum"), [home] as Array[int], "Homeland at pop 8")
	build_it(e, "forum", home)
	eq([e.free_slots(home), e.free_workers(home)], [slots - 1, workers - 1], "a slot and a worker, like any building")


# --- AC3: falls back ---

func test_an_upgrade_below_its_tier_falls_back_and_its_upgrades_with_it() -> void:
	var e := tier_engine(4)
	var chapel := put_home(e, "chapel")
	var hand: int = e.hand_size()
	var sanctum := build_it(e, "sanctum", chapel)
	var bell := build_it(e, "bell", sanctum)
	eq(e.hand_size(), hand + 1, "precondition: the Sanctum works")
	e.lose_pop(1, source(e))
	eq(e.pop(home_uid(e)), 3, "Homeland at 3")
	eq(e.hand_size(), hand, "the Sanctum counts for nothing")
	eq(e.fallen_back_reason(sanctum), "Needs a Village.", "the Sanctum's reason")
	eq(e.fallen_back_reason(bell), "Its Sanctum has fallen back.", "the Bell's reason")
	eq(e.fallen_back_reason(chapel), "", "the Chapel still works")
	check(not e.is_idle(chapel), "the Chapel isn't idle")


func test_a_cathedral_falls_back_with_its_sanctum() -> void:
	var e := tier_engine(8)
	var chapel := put_home(e, "chapel")
	var sanctum := build_it(e, "sanctum", chapel)
	var cathedral := build_it(e, "cathedral", sanctum)
	var score: int = e.score()
	set_home_pop(e, 7)
	eq(e.fallen_back_reason(cathedral), "Needs a Town.", "at a Village: its own tier")
	eq(e.score(), score - 2, "its VP leaves the score")
	set_home_pop(e, 3)
	eq(e.fallen_back_reason(cathedral), "Its Sanctum has fallen back.", "at a Hamlet: its base's")


func test_a_building_below_its_tier_falls_back_but_keeps_its_slot_and_worker() -> void:
	var e := tier_engine(8)
	var home := home_uid(e)
	var food := food_forecast(e)
	var score: int = e.score()
	var forum := build_it(e, "forum", home)
	eq([food_forecast(e), e.score()], [food + 1, score + 1], "precondition: the Forum works")
	set_home_pop(e, 7)
	eq(food_forecast(e), food, "no food from the Forum")
	eq(e.score(), score, "its VP leaves the score")
	eq(e.total_slots(home) - e.free_slots(home), 1, "it still takes its slot")
	eq(e.free_workers(home), 6, "and its worker")
	check(not e.is_idle(forum), "it isn't idle")
	eq(e.fallen_back_reason(forum), "Needs a Town.", "why")
	var held: int = e.resources.food
	e.end_turn()
	eq(e.resources.food, held + food, "the upkeep that follows matches the forecast")


# --- AC4: returns by itself ---

func test_fallen_back_cards_work_again_when_the_territory_grows_back() -> void:
	var e := tier_engine(8)
	var home := home_uid(e)
	var food := food_forecast(e)
	var score: int = e.score()
	var hand: int = e.hand_size()
	var forum := build_it(e, "forum", home)
	var sanctum := build_it(e, "sanctum", put_home(e, "chapel"))
	var tableau := card_ids(e.zone("tableau"))
	var held: Dictionary = e.resources.duplicate()
	var actions: int = e.actions_left()
	set_home_pop(e, 3)
	eq(card_ids(e.zone("tableau")), tableau, "nothing leaves the tableau")
	set_home_pop(e, 4)
	eq([e.fallen_back_reason(sanctum), e.hand_size()], ["", hand + 1], "the Sanctum works again at 4")
	eq(e.fallen_back_reason(forum), "Needs a Town.", "the Forum not yet")
	set_home_pop(e, 8)
	eq(e.fallen_back_reason(forum), "", "the Forum works again at 8")
	eq([food_forecast(e), e.score()], [food + 1, score + 1], "its food and VP are back")
	eq(card_ids(e.zone("tableau")), tableau, "nothing left the tableau")
	eq([e.resources, e.actions_left()], [held, actions], "no cost and no action")


# --- AC5: notices ---

func test_shrinking_names_the_cards_that_fall_back() -> void:
	var e := tier_engine(4)
	build_it(e, "sanctum", put_home(e, "chapel"))
	var recorded := record_messages(e)
	e.lose_pop(1, source(e))
	check_noticed(recorded, "Homeland shrinks to a Hamlet. Sanctum falls back.", GameEngine.NOTICE_CAUTION)
	var two := tier_engine(4)
	build_it(two, "bell", build_it(two, "sanctum", put_home(two, "chapel")))
	var heard := record_messages(two)
	two.lose_pop(1, source(two))
	check_noticed(heard, "Homeland shrinks to a Hamlet. Sanctum and Bell fall back.", GameEngine.NOTICE_CAUTION)


func test_growing_names_the_cards_that_work_again() -> void:
	var e := tier_engine(4)
	build_it(e, "bell", build_it(e, "sanctum", put_home(e, "chapel")))
	set_home_pop(e, 3)
	var recorded := record_messages(e)
	e.add_pop(home_uid(e), 1, source(e))
	check_noticed(recorded, "Homeland grows into a Village. Sanctum and Bell work again.", GameEngine.NOTICE_INFO)


func test_a_tier_change_that_affects_no_such_card_keeps_its_notice() -> void:
	var e := tier_engine(4)
	put_home(e, "chapel")
	var recorded := record_messages(e)
	e.lose_pop(1, source(e))
	eq(notices_in(recorded), ["Homeland shrinks to a Hamlet."] as Array[String], "281's notice alone")
	recorded.clear()
	e.add_pop(home_uid(e), 1, source(e))
	eq(notices_in(recorded), ["Homeland grows into a Village."] as Array[String], "and growing")


# --- Backlog 302: what the upgrade's face asks ---

func test_card_tier_name_names_the_tier_a_card_needs() -> void:
	var e: Object = tier_engine(4)
	eq([e.card_tier_name("sanctum"), e.card_tier_name("forum")], ["Village", "Town"], "cards with a tier")
	eq([e.card_tier_name("chapel"), e.card_tier_name("dragon")], ["", ""], "none, an unknown id")
	eq((tier_engine(4, null) as Object).card_tier_name("forum"), "", "with tiers off")


func test_upgrade_rules_text_leaves_out_the_tier_line_too() -> void:
	var e: Object = tier_engine(4)
	eq(e.upgrade_rules_text("sanctum"), "Draw up to 1 more card each turn", "the Sanctum")
	eq(e.upgrade_rules_text("cathedral"), "", "the Cathedral adds only VP")
