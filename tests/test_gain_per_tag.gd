extends "res://tests/lib/test_case.gd"
## The gain_per_tag op's `per` (367): gains amount × ⌊tagged cards ÷ per⌋, so Sailing pays +1 insight per 2 ports; and a
## play-trigger gain_per_tag (Sea Trade). Fixtures are local: Counter (building, ⟳ +1 insight per 2 t), Hut (building,
## tag t) and Shipper (action, +2 wealth per t). Its "where": "here" (414) counts the other working base buildings with
## the tag on the card's own territory: Canal (⟳ +1 food per other farm here) and Fat Plough (an upgrade tagged farm).

const PER := {"op": "gain_per_tag", "resource": "insight", "amount": 1, "tag": "t", "per": 2, "trigger": "upkeep"}
const COUNTER := {"id": "counter", "name": "Counter", "type": "building", "effects": [PER]}
const HUT := {"id": "hut", "name": "Hut", "type": "building", "tags": ["t"]}
const SHIPPER := {"id": "shipper", "name": "Shipper", "type": "action",
	"effects": [{"op": "gain_per_tag", "resource": "wealth", "amount": 2, "tag": "t"}]}


## A make_engine game (population off) with the fixtures, counter_effect on the Counter, 0 insight and 0 wealth.
func tag_engine(counter_effect := PER) -> GameEngine:
	var counter := COUNTER.duplicate(true)
	counter.effects = [counter_effect]
	var e := make_engine({"farm": 10}, {}, 1, [counter, HUT, SHIPPER])
	e.resources.insight = 0
	e.resources.wealth = 0
	return e


## The resource one upkeep adds from a Counter with counter_effect and huts Huts on Homeland: [forecast, actual].
func upkeep_gain(huts: int, counter_effect := PER) -> Array:
	var e := tag_engine(counter_effect)
	var resource: String = counter_effect.resource
	var base: int = e.upkeep_forecast().get(resource, 0)  # what the other cards make
	var built := ["counter"]
	for i in huts:
		built.append("hut")
	build_on(e, home_uid(e), built)
	var forecast: int = e.upkeep_forecast().get(resource, 0) - base
	var before: int = e.resources[resource]
	e.end_turn()
	return [forecast, e.resources[resource] - before - base]


## PER with key set to value (or removed when value is null).
func per_with(key: String, value: Variant) -> Dictionary:
	var effect := PER.duplicate(true)
	if value == null:
		effect.erase(key)
	else:
		effect[key] = value
	return effect


# --- AC1: amount × ⌊tagged ÷ per⌋, at upkeep and in the forecast ---

func test_per_gains_once_for_every_per_tagged_cards() -> void:
	eq(upkeep_gain(5), [2, 2], "5 Huts, per 2: +2 insight (forecast, upkeep)")
	eq(upkeep_gain(1), [0, 0], "1 Hut, per 2: nothing")
	eq(upkeep_gain(4), [2, 2], "4 Huts, per 2: +2")


# --- AC2: without per, amount per tagged card as today ---

func test_without_per_it_gains_per_tagged_card() -> void:
	var two_each := per_with("per", null)
	two_each.amount = 2
	eq(upkeep_gain(3, two_each), [6, 6], "3 Huts, amount 2, no per: +6")
	var r := card_load(card_with("building", per_with("per", null)))
	if r.cards.has("x"):
		eq(r.cards.x.effects[0].get("per"), 1, "per defaults to 1")


# --- AC3: validation ---

func test_per_validation() -> void:
	var prefix := "cards.json: card 'x': effects[0]: "
	check_cases([
		["per 0", per_with("per", 0), prefix + "'per' must be an integer >= 1"],
		["per negative", per_with("per", -2), prefix + "'per' must be an integer >= 1"],
		["per not an integer", per_with("per", 1.5), prefix + "'per' must be an integer >= 1"],
	], func(effect): return card_load(card_with("building", effect)).errors)


# --- AC4: card text ---

func test_per_card_text() -> void:
	var on_play := per_with("trigger", null)
	var per_two: Dictionary = card_load(card_with("action", on_play)).cards
	var per_one: Dictionary = card_load(card_with("action", on_play.merged({"per": 1}, true))).cards
	if not per_two.has("x") or not per_one.has("x"):
		check(false, "x should load")
		return
	eq(per_two.x.rules_text(per_two), "+1 insight per 2 t", "rules_text, per 2")
	eq(per_two.x.rules_tooltip(per_two), "+1 insight per 2 t cards", "rules_tooltip, per 2")
	eq(per_one.x.rules_text(per_one), "+1 insight per t", "rules_text, per 1")
	eq(per_one.x.rules_tooltip(per_one), "+1 insight per t card", "rules_tooltip, per 1")


# --- AC5: a played gain_per_tag (Sea Trade) ---

func test_a_played_gain_per_tag_gains_per_tagged_card_and_plays_with_none() -> void:
	var e := tag_engine()
	build_on(e, home_uid(e), ["hut", "hut", "hut"])
	var uid := put_in_hand(e, "shipper")
	check(e.play_card(uid), "play Shipper: %s" % e.play_error(uid))
	eq(e.resources.wealth, 6, "3 Huts × 2 wealth")
	var none := tag_engine()
	uid = put_in_hand(none, "shipper")
	check(none.play_card(uid), "play Shipper with no Hut: %s" % none.play_error(uid))
	eq(none.resources.wealth, 0, "no Hut: nothing")


# --- 414: "where": "here" counts the other working farms on the card's own territory ---

const HERE := {"op": "gain_per_tag", "resource": "food", "amount": 1, "tag": "farm", "where": "here", "trigger": "upkeep"}
const CANAL := {"id": "canal", "name": "Canal", "type": "building", "tags": ["farm"], "effects": [HERE]}
const FAT_PLOUGH := {"id": "fat_plough", "name": "Fat Plough", "type": "building", "tags": ["farm"],
	"upgrade_of": "farm"}


## A game with population on (no food upkeep), the 414 fixtures, Homeland at home_pop pop holding home_ids (in order),
## and Grassland settled.
func here_engine(home_pop: int, home_ids: Array) -> GameEngine:
	var o := {"population": {"start": home_pop, "food_upkeep": 0, "vp_per_pop": 0},
		"territory_deck": {"grassland": 1}}
	var e := make_engine({"scout": 10}, o, 1, [CANAL, FAT_PLOUGH])
	set_home_pop(e, home_pop)
	build_on(e, home_uid(e), home_ids)
	settle(e, ["grassland"])
	return e


## The food row of card name in e's next upkeep breakdown, or 0 when it has none.
func food_row(e: GameEngine, name: String) -> int:
	for row in e.upkeep_breakdown("food"):
		if row.label == name:
			return row.amount
	return 0


## AC1: the Canal counts the two other farms on Homeland, not itself and not Grassland's Farm.
func test_here_counts_the_other_farms_on_its_own_territory() -> void:
	var e := here_engine(3, ["farm", "farm", "canal"])
	var grassland := uid_of(e.zone("tableau"), "grassland")
	e.zone("tableau").find(grassland).pop = 1
	build_on(e, grassland, ["farm"])
	eq(food_row(e, "Canal"), 2, "the Canal's row: the two other Homeland farms")
	var food: int = e.resources.food
	e.end_turn()
	eq(e.resources.food - food, 2 + 3 + 2, "Canal 2 + three Farms 3 + Capital 2")


## AC2: an idle farm and an upgrade on a farm don't count.
func test_here_counts_only_working_base_buildings() -> void:
	var e := here_engine(2, ["canal", "farm", "farm"])  # 2 pop: the second Farm is idle
	upgrade_on(e, "fat_plough", uid_of(e.zone("tableau"), "farm"))
	eq(food_row(e, "Canal"), 1, "the working Farm alone")


## AC2: an idle Canal makes nothing.
func test_an_idle_here_card_makes_nothing() -> void:
	var e := here_engine(2, ["farm", "farm", "canal"])  # 2 pop: the Canal is idle
	eq(food_row(e, "Canal"), 0, "an idle Canal has no row")
	var food: int = e.resources.food
	e.end_turn()
	eq(e.resources.food - food, 2 + 2, "two Farms + Capital, nothing from the Canal")


## AC3: the forecast's Canal row and total match what upkeep then does.
func test_the_forecast_counts_the_farms_here() -> void:
	var e := here_engine(3, ["farm", "farm", "canal"])
	var forecast: int = e.upkeep_forecast().food
	eq(food_row(e, "Canal"), 2, "the Canal's row")
	var food: int = e.resources.food
	e.end_turn()
	eq(e.resources.food - food, forecast, "upkeep did what the forecast said")


## AC4: where takes only "here", on the tableau, on a building.
func test_where_here_is_a_building_count_on_the_tableau() -> void:
	var building := func(effect: Dictionary) -> Dictionary: return card_load(card_with("building", effect))
	check_cases([
		["where not here", HERE.merged({"where": "there"}, true),
			"cards.json: card 'x': effects[0]: 'where' must be one of: here (got 'there')"],
		["here off the tableau", HERE.merged({"zone": "hand"}, true),
			"cards.json: card 'x': effects[0]: 'where': 'here' counts the tableau, so it can't take 'zone'"],
	], building)
	check_cases([
		["here on an action", card_with("action", HERE.merged({"trigger": "play"}, true)),
			"cards.json: card 'x': effects[0]: 'where': 'here' only works on a building"],
		["here on a tech", card_with("tech", HERE.merged({"trigger": "play"}, true)).merged({"cost": {"insight": 1}}),
			"cards.json: card 'x': effects[0]: a tech effect can't act on its own territory"],
	], card_load)
	check_loads([["no where", card_with("building", PER), {"cards.x.effects.size()": 1}]], card_load)


## AC5: the face and details text.
func test_here_text_names_the_other_farms_here() -> void:
	var db := fixture_db([CANAL, COUNTER])
	var effect: Effect = db.canal.effects[0]
	eq(effect.describe(db), "+1 food per other farm here", "face")
	eq(effect.describe_long(db), "+1 food per other farm card on its territory", "details")
	eq((db.counter.effects[0] as Effect).describe(db), "+1 insight per 2 t", "without where: unchanged")
