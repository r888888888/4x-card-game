extends "res://tests/lib/test_case.gd"
## Base class for raid tests (backlog 162 on): fixture raid cards and a game whose event deck holds raids.

const RESOURCES: Array[String] = ["food", "wealth", "insight", "unrest"]
## Levy: a unit of strength 2; Town: a city with defense 1. Raiders: strength 3 aimed at mountains, +1 insight when
## drawn; repelled +2 wealth −1 unrest, pillaged −2 food +1 unrest. Horde: strength 1, any territory, pop 1 by default.
## Stockade (1 food 2 wealth), Fort (a city, 2 wealth) and Spearmen (a unit, 2 food) for realm sizes (257).
const RAID_CARDS := [
	{"id": "levy", "name": "Levy", "type": "unit", "cost": {"food": 1}, "strength": 2},
	{"id": "town", "name": "Town", "type": "city", "vp": 1, "tags": ["city"], "defense": 1},
	{"id": "raiders", "name": "Raiders", "type": "event", "raid": {"strength": 3, "targets": ["mountain"]}, "effects": [
		{"op": "gain", "resource": "insight", "amount": 1},
		{"op": "gain", "resource": "wealth", "amount": 2, "trigger": "repel"},
		{"op": "lose", "resource": "unrest", "amount": 1, "trigger": "repel"},
		{"op": "lose", "resource": "food", "amount": 2, "trigger": "pillage"},
		{"op": "gain", "resource": "unrest", "amount": 1, "trigger": "pillage"}]},
	{"id": "horde", "name": "Horde", "type": "event", "raid": {"strength": 1}},
	{"id": "stockade", "name": "Stockade", "type": "building", "cost": {"food": 1, "wealth": 2}},
	{"id": "fort", "name": "Fort", "type": "city", "tags": ["city"], "cost": {"wealth": 2}},
	{"id": "spearmen", "name": "Spearmen", "type": "unit", "cost": {"food": 2}, "strength": 1},
]


## TEST_CARDS, TEST_EVENTS and RAID_CARDS plus extra, parsed with unrest listed: {cards, errors, warnings}.
func raid_load(extra := []) -> Dictionary:
	return fixture_load(extra, [TEST_EVENTS, RAID_CARDS], RESOURCES)


## A raid_load card "x" of type event with a raid and these fields merged in, for loader cases.
func raid_with(fields: Dictionary) -> Array:
	var card := {"id": "x", "name": "X", "type": "event", "raid": {"strength": 2}}
	card.merge(fields, true)
	return [card]


## A game on raid_load's cards: Levies in the deck, population on (Homeland at 3 pop, no food upkeep), Hills settled
## at 1 pop, 50 food and 1 unrest, and the event deck event_deck with ids_on_top arranged on top (the turn-2 event
## first). Still turn 1. null (after a failed check) when the data doesn't load.
func raid_engine(ids_on_top := ["raiders"], event_deck := {"raiders": 1, "horde": 1, "omen": 3}, overrides := {}) -> GameEngine:
	var r := raid_load()
	check(r.errors.is_empty(), "test cards should load: %s" % [r.errors])
	if not r.errors.is_empty():
		return null
	var o := {"resources": RESOURCES, "keywords": keywords(), "event_deck": event_deck,
		"population": {"start": 3, "food_upkeep": 0, "vp_per_pop": 0},
		"territory_deck": {"hills": 1, "grassland": 1, "river": 1}}
	o.merge(overrides, true)
	var errors: Array[String] = []
	var warnings: Array[String] = []
	var config := DataLoader.parse_config(raw_config({"levy": 10}, o), RESOURCES, r.cards, "config.json", errors, warnings)
	check(errors.is_empty(), "test config should load: %s" % [errors])
	if not errors.is_empty():
		return null
	var e := GameEngine.new(r.cards, config)
	e.new_game(1)
	settle(e, ["hills"])
	e.zone("tableau").find(hills_of(e)).pop = 1
	e.resources.food = 50
	e.resources.unrest = 1
	arrange(e.zone("event_deck"), ids_on_top)
	return e


## Hills' uid in e's tableau.
func hills_of(e: GameEngine) -> int:
	return uid_of(e.zone("tableau"), "hills")


## The uid of the active event id, or -1.
func active_uid(e: GameEngine, id: String) -> int:
	return uid_of(e.zone("active_events"), id)


## Recruits a Levy from e's hand onto territory uid.
func recruit(e: GameEngine, uid: int) -> void:
	var levy := uid_of(e.zone("hand"), "levy")
	check(e.play_card(levy, uid), "Levy recruited: %s" % e.play_error(levy, uid))


## Records every raid_resolved outcome e emits into the returned array.
func record_raids(e: GameEngine) -> Array[Dictionary]:
	var outcomes: Array[Dictionary] = []
	e.raid_resolved.connect(func(o: Dictionary): outcomes.append(o))
	return outcomes
