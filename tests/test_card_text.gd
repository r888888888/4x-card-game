extends "res://tests/lib/test_case.gd"
## Card text: the short form on the card (rules_text) and the full wording on hover (rules_tooltip).

const KEYWORDS: Array[String] = ["mountain", "fresh_water", "flood_plain", "desert", "forest", "jungle"]
const CITY := {"id": "city", "name": "City", "type": "city"}


## Loads the given cards (plus a City) and returns them by id; fails the test on loader errors.
func text_db(cards: Array) -> Dictionary:
	var errors: Array[String] = []
	var warnings: Array[String] = []
	var db := DataLoader.parse_cards({"cards": [CITY] + cards}, resources(), "t", errors, warnings, KEYWORDS)
	eq(errors, [] as Array[String], "loader errors")
	return db


## Short text of a one-card building or action with these effects (and optional requires).
func short_text(effects: Array, requires: Array = [], type := "building") -> String:
	var card := {"id": "x", "name": "X", "type": type, "effects": effects}
	if not requires.is_empty():
		card.requires = requires
	var db := text_db([card])
	return db.x.rules_text(db) if db.has("x") else "<not loaded>"


func long_text(effects: Array, requires: Array = [], type := "building") -> String:
	var card := {"id": "x", "name": "X", "type": type, "effects": effects}
	if not requires.is_empty():
		card.requires = requires
	var db := text_db([card])
	return db.x.rules_tooltip(db) if db.has("x") else "<not loaded>"


const FOOD_UPKEEP := {"op": "gain", "resource": "food", "amount": 1, "trigger": "upkeep"}
const FOOD_UPKEEP_FLOOD := {"op": "gain", "resource": "food", "amount": 1, "trigger": "upkeep", "keyword": "flood_plain"}
const VP_UPKEEP := {"op": "score", "amount": 1, "trigger": "upkeep"}
const VP_UPKEEP_MOUNTAIN := {"op": "score", "amount": 1, "trigger": "upkeep", "keyword": "mountain"}


# --- AC1: upkeep mark and merged keyword bonus ---

func test_upkeep_line_starts_with_cycle_mark() -> void:
	eq(short_text([FOOD_UPKEEP]), "⟳ +1 food", "upkeep gain")


func test_keyword_bonus_merges_onto_matching_line() -> void:
	eq(short_text([FOOD_UPKEEP, FOOD_UPKEEP_FLOOD]), "⟳ +1 food (+1 Flood Plain)", "Paddy-like")
	eq(short_text([VP_UPKEEP, VP_UPKEEP_MOUNTAIN]), "⟳ +1 VP (+1 Mountain)", "Temple-like")


func test_keyword_bonus_merges_with_a_different_amount() -> void:
	var bonus := {"op": "score", "amount": 2, "trigger": "upkeep", "keyword": "mountain"}
	eq(short_text([VP_UPKEEP, bonus]), "⟳ +1 VP (+2 Mountain)", "amount differs")


# --- AC2: keyword effects that can't merge ---

func test_lone_keyword_effect_gets_its_own_line() -> void:
	eq(short_text([{"op": "score", "amount": 3, "keyword": "desert"}]), "Desert: +3 VP", "play")
	eq(short_text([VP_UPKEEP_MOUNTAIN]), "Mountain: ⟳ +1 VP", "upkeep")


func test_keyword_effect_after_a_different_effect_does_not_merge() -> void:
	var text := short_text([FOOD_UPKEEP, VP_UPKEEP_MOUNTAIN])
	eq(text, "⟳ +1 food\nMountain: ⟳ +1 VP", "different op")
	var play_food := {"op": "gain", "resource": "food", "amount": 1, "keyword": "flood_plain"}
	eq(short_text([FOOD_UPKEEP, play_food]), "⟳ +1 food\nFlood Plain: +1 food", "different trigger")


func test_keyword_effect_after_a_keyword_effect_does_not_merge() -> void:
	var text := short_text([VP_UPKEEP_MOUNTAIN, {"op": "score", "amount": 1, "trigger": "upkeep", "keyword": "desert"}])
	eq(text, "Mountain: ⟳ +1 VP\nDesert: ⟳ +1 VP", "previous has a keyword")


# --- AC3: short forms ---

func test_explore_and_settle_short_forms() -> void:
	eq(short_text([{"op": "explore", "reveal": 2}], [], "action"), "Explore 2", "explore")
	eq(short_text([{"op": "settle", "card": "city"}], [], "action"), "Settle: City", "settle")


func test_per_tag_short_form() -> void:
	var tableau := {"op": "gain_per_tag", "resource": "food", "amount": 2, "tag": "city"}
	eq(short_text([tableau], [], "action"), "+2 food per city", "tableau")
	var hand := {"op": "gain_per_tag", "resource": "food", "amount": 1, "tag": "farm", "zone": "hand"}
	eq(short_text([hand], [], "action"), "+1 food per farm in hand", "hand")


func test_grow_short_forms() -> void:
	eq(short_text([{"op": "grow", "amount": 1, "where": "each"}], [], "action"), "+1 pop everywhere", "each")
	eq(short_text([{"op": "grow", "amount": 1, "where": "here"}]), "+1 pop here", "here")


func test_needs_line() -> void:
	eq(short_text([], ["fresh_water"]), "Needs Fresh Water", "one keyword")
	eq(short_text([FOOD_UPKEEP], ["forest", "jungle"]), "Needs Forest/Jungle\n⟳ +1 food", "two keywords")


func test_gain_score_draw_create_keep_their_text() -> void:
	eq(short_text([{"op": "gain", "resource": "food", "amount": 2}], [], "action"), "+2 food", "gain")
	eq(short_text([{"op": "score", "amount": 1}], [], "action"), "+1 VP", "score")
	eq(short_text([{"op": "draw", "amount": 2}], [], "action"), "Draw 2 cards", "draw")
	eq(short_text([{"op": "create", "card": "city"}], [], "action"), "Create a City", "create")



## A TEST_CARDS card by id, for text tests that create it.
func test_card(id: String) -> Dictionary:
	return TEST_CARDS.cards.filter(func(c: Dictionary) -> bool: return c.id == id)[0]


## Short text of an action that creates `card` (from `cards`) in `zone`.
func create_text(cards: Array, card: String, zone := "tableau") -> String:
	var x := {"id": "x", "name": "X", "type": "action", "effects": [{"op": "create", "card": card, "zone": zone}]}
	var db := text_db(cards + [x])
	return db.x.rules_text(db) if db.has("x") else "<not loaded>"


func test_bug_279_create_uses_an_before_a_vowel() -> void:
	eq(create_text([test_card("explorer")], "explorer", "discard"), "Add an Explorer to your discard", "AC1 discard")
	eq(create_text([test_card("explorer")], "explorer"), "Create an Explorer", "AC2 tableau")


func test_bug_279_create_keeps_a_before_a_consonant() -> void:
	eq(create_text([], "city"), "Create a City", "tableau")
	eq(create_text([], "city", "discard"), "Add a City to your discard", "discard")


func test_bug_279_article_is_by_first_letter_either_case() -> void:
	for name: String in ["Aqueduct", "Ear", "idol", "Ox", "urn"]:
		eq(create_text([{"id": "v", "name": name, "type": "action"}], "v"), "Create an " + name, name)
	for name: String in ["Bank", "yurt", "Zen"]:
		eq(create_text([{"id": "c", "name": name, "type": "action"}], "c"), "Create a " + name, name)

# --- AC4: full wording ---

func test_tooltip_is_the_full_unmerged_wording() -> void:
	eq(long_text([FOOD_UPKEEP, FOOD_UPKEEP_FLOOD]), "Each upkeep: +1 food\nEach upkeep: +1 food (on Flood Plain)", "Paddy-like")
	eq(long_text([{"op": "score", "amount": 3, "keyword": "desert"}]), "+3 VP (on Desert)", "lone keyword")


func test_tooltip_long_forms() -> void:
	eq(long_text([{"op": "explore", "reveal": 2}], [], "action"), "Explore: reveal 2 territories, keep 1", "explore 2")
	eq(long_text([{"op": "explore", "reveal": 1}], [], "action"), "Explore: reveal 1 territory, keep 1", "explore 1")
	eq(long_text([{"op": "settle", "card": "city"}], [], "action"), "Settle a discovered territory with a City", "settle")
	eq(long_text([{"op": "gain_per_tag", "resource": "food", "amount": 2, "tag": "city"}], [], "action"),
		"+2 food per city card", "per tag")
	eq(long_text([{"op": "grow", "amount": 1, "where": "each"}], [], "action"), "+1 pop in each territory", "grow each")
	eq(long_text([FOOD_UPKEEP], ["forest", "jungle"]), "Requires Forest or Jungle\nEach upkeep: +1 food", "requires")


func test_text_override_is_used_for_both() -> void:
	var db := text_db([{"id": "x", "name": "X", "type": "action", "text": "Something odd",
		"effects": [{"op": "draw", "amount": 1}]}])
	if db.has("x"):
		eq(db.x.rules_text(db), "Something odd", "short")
		eq(db.x.rules_tooltip(db), "Something odd", "tooltip")


# --- AC5: territories ---

func test_territory_tooltip_explains_slots_housing_keywords() -> void:
	var db := text_db([
		{"id": "river", "name": "River", "type": "territory", "slots": 2, "housing": 4, "keywords": ["fresh_water", "flood_plain"]},
		{"id": "rock", "name": "Rock", "type": "territory", "slots": 1, "housing": 3},
	])
	if db.has("river") and db.has("rock"):
		eq(db.river.rules_text(db), "", "short text stays empty")
		eq(db.river.rules_tooltip(db), "2 building slots, holds up to 4 pop\nKeywords: Fresh Water, Flood Plain", "river")
		eq(db.rock.rules_tooltip(db), "1 building slot, holds up to 3 pop", "rock")


func test_city_with_slots_tooltip_mentions_them() -> void:
	var db := text_db([{"id": "hub", "name": "Hub", "type": "city", "slots": 4,
		"effects": [{"op": "gain", "resource": "food", "amount": 2, "trigger": "upkeep"}]}])
	if db.has("hub"):
		eq(db.hub.rules_tooltip(db), "Each upkeep: +2 food\n+4 building slots on its territory", "tooltip")
