extends "res://tests/lib/test_case.gd"
## The gain_per_tag op's `per` (367): gains amount × ⌊tagged cards ÷ per⌋, so Sailing pays +1 insight per 2 ports; and a
## play-trigger gain_per_tag (Sea Trade). Fixtures are local: Counter (building, ⟳ +1 insight per 2 t), Hut (building,
## tag t) and Shipper (action, +2 wealth per t).

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
