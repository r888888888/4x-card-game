extends "res://tests/lib/test_case.gd"
## The gain_per_tag op's `here` (364): with it, the op counts only the working cards with the tag on its own card's
## territory (Salt Pans and the Fishing Huts in its city). Fixtures are local: Salter (building, ⟳ +1 food per t here)
## and Hut (building, tag t).

const HERE := {"op": "gain_per_tag", "resource": "food", "amount": 1, "tag": "t", "here": true, "trigger": "upkeep"}
const SALTER := {"id": "salter", "name": "Salter", "type": "building", "effects": [HERE]}
const HUT := {"id": "hut", "name": "Hut", "type": "building", "tags": ["t"]}


## A make_engine game with the fixtures and salter_effect on the Salter, population on (no food upkeep, no pop VP),
## Hills settled with pop 3, Homeland's pop home_pop and 0 food.
func tag_engine(home_pop: int, salter_effect := HERE) -> GameEngine:
	var salter := SALTER.duplicate(true)
	salter.effects = [salter_effect]
	var o := {"territory_deck": {"hills": 1}, "population": {"start": 2, "food_upkeep": 0, "vp_per_pop": 0}}
	var e := make_engine({"farm": 10}, o, 1, [salter, HUT])
	settle(e, ["hills"])
	e.zone("tableau").find(uid_of(e.zone("tableau"), "hills")).pop = 3
	set_home_pop(e, home_pop)
	e.resources.food = 0
	return e


## The food one upkeep adds from a Salter then home_huts Huts on Homeland and 3 Huts on Hills: [forecast, actual].
func upkeep_food(home_pop: int, home_huts: int, salter_effect := HERE) -> Array:
	var e := tag_engine(home_pop, salter_effect)
	var base: int = e.upkeep_forecast().food  # what the other cards make, without the Salter and Huts
	var huts := []
	for i in home_huts:
		huts.append("hut")
	build_on(e, home_uid(e), ["salter"] + huts)
	build_on(e, uid_of(e.zone("tableau"), "hills"), ["hut", "hut", "hut"])
	var forecast: int = e.upkeep_forecast().food - base
	e.end_turn()
	return [forecast, e.resources.food - base]


## HERE with key set to value (or removed when value is null).
func here_with(key: String, value: Variant) -> Dictionary:
	var effect := HERE.duplicate(true)
	if value == null:
		effect.erase(key)
	else:
		effect[key] = value
	return effect


# --- AC2: here counts the working tagged cards on its own territory ---

func test_here_counts_only_the_tagged_cards_on_its_own_territory() -> void:
	eq(upkeep_food(5, 2), [2, 2], "2 Huts on Homeland count; the 3 on Hills don't (forecast, upkeep)")


func test_here_skips_an_idle_tagged_card() -> void:
	eq(upkeep_food(2, 2), [1, 1], "pop 2 works the Salter and one Hut; the second Hut is idle")


func test_without_here_every_tagged_card_counts() -> void:
	eq(upkeep_food(5, 2, here_with("here", null)), [5, 5], "no here: all 5 Huts, as before")
	eq(upkeep_food(5, 2, here_with("here", false)), [5, 5], "here false: all 5 Huts")


# --- AC3: validation ---

func test_here_validation() -> void:
	var prefix := "cards.json: card 'x': effects[0]: "
	check_cases([
		["here not a boolean", here_with("here", "yes"), [prefix, "'here'"]],
		["here as a number", here_with("here", 1), [prefix, "'here'"]],
		["here outside the tableau", here_with("zone", "hand"), [prefix, "'here'", "'zone'"]],
	], func(effect): return card_load(card_with("building", effect)).errors)


# --- AC4: card text ---

func test_here_card_text() -> void:
	var here: Dictionary = card_load(card_with("action", here_with("trigger", null))).cards
	var on_play := here_with("trigger", null)
	on_play.erase("here")
	var plain: Dictionary = card_load(card_with("action", on_play)).cards
	if not here.has("x") or not plain.has("x"):
		check(false, "x should load")
		return
	eq(here.x.rules_text(here), "+1 food per t here", "rules_text")
	eq(here.x.rules_tooltip(here), "+1 food per t card on this territory", "rules_tooltip")
	eq(plain.x.rules_text(plain), "+1 food per t", "rules_text without here")
	eq(plain.x.rules_tooltip(plain), "+1 food per t card", "rules_tooltip without here")


func test_here_on_a_card_with_no_territory_is_a_load_error() -> void:
	var tech := card_with("tech", here_with("trigger", null))
	tech.cost = {"insight": 2}
	check_cases([
		["tech", tech, ["card 'x'", "can't act on its own territory"]],
		["event", card_with("event", here_with("trigger", null)), ["card 'x'", "can't act on its own territory"]],
	], func(card): return card_load(card).errors)
