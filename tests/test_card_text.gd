extends "res://tests/lib/test_case.gd"
## Card text: the face (CardDef.face: a ledger of figures, the rules with one Unlocks line, gates as fine print, 382;
## rules_text is it in one string) and the full wording on hover and in the details (rules_tooltip).

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
	eq(short_text([FOOD_UPKEEP], ["forest", "jungle"]), "⟳ +1 food\nNeeds Forest/Jungle", "two keywords: the gate is fine print, last (382)")


func test_gain_score_draw_create_keep_their_text() -> void:
	eq(short_text([{"op": "gain", "resource": "food", "amount": 2}], [], "action"), "+2 food", "gain")
	eq(short_text([{"op": "score", "amount": 1}], [], "action"), "+1 VP", "score")
	eq(short_text([{"op": "draw", "amount": 2}], [], "action"), "Draw 2 cards", "draw")
	eq(short_text([{"op": "create", "card": "city"}], [], "action"), "Create a City", "create")



## A TEST_CARDS card by id, for text tests that create it.
func fixture_card(id: String) -> Dictionary:
	return TEST_CARDS.cards.filter(func(c: Dictionary) -> bool: return c.id == id)[0]


## Short text of an action that creates `card` (from `cards`) in `zone`.
func create_text(cards: Array, card: String, zone := "tableau") -> String:
	var x := {"id": "x", "name": "X", "type": "action", "effects": [{"op": "create", "card": card, "zone": zone}]}
	var db := text_db(cards + [x])
	return db.x.rules_text(db) if db.has("x") else "<not loaded>"


func test_bug_279_create_uses_an_before_a_vowel() -> void:
	eq(create_text([fixture_card("explorer")], "explorer", "discard"), "Add an Explorer to your discard", "AC1 discard")
	eq(create_text([fixture_card("explorer")], "explorer"), "Create an Explorer", "AC2 tableau")


func test_a_unique_create_says_it_adds_only_when_you_have_none() -> void:
	var unique := [{"op": "create", "card": "city", "zone": "deck", "unique": true}]
	eq(short_text(unique, [], "action"), "Add a City to your deck if you have none", "short")
	eq(long_text(unique, [], "action"), "Add a City to your deck, unless you already have one", "long")
	var plain := [{"op": "create", "card": "city", "zone": "deck"}]
	eq(short_text(plain, [], "action"), "Add a City to your deck", "short without unique")
	eq(long_text(plain, [], "action"), "Add a City to your deck", "long without unique")


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


# --- 329: modifier lines and plurals ---

## Short text of a one-card building with these modifiers.
func modifier_text(modifiers: Dictionary) -> String:
	var db := text_db([{"id": "x", "name": "X", "type": "building", "modifiers": modifiers, "effects": []}])
	return db.x.rules_text(db) if db.has("x") else "<not loaded>"


func test_bug_329_unrest_limit_line_has_no_plural() -> void:
	eq(modifier_text({Modifiers.UNREST_LIMIT: 2}), "Unrest limit +2", "+2")
	eq(modifier_text({Modifiers.UNREST_LIMIT: -2}), "Unrest limit −2", "−2")


func test_bug_329_housing_line_has_no_plural() -> void:
	eq(modifier_text({Modifiers.HOUSING: 2}), "Every territory houses 2 more pop", "+2")
	eq(modifier_text({Modifiers.HOUSING: -2}), "Every territory houses 2 less pop", "−2")


func test_bug_329_insight_and_administration_lines_have_no_plural() -> void:
	eq(modifier_text({Modifiers.INSIGHT_PER_GAIN: 2}), "Each insight gain +2", "insight per gain")
	eq(modifier_text({Modifiers.ADMINISTERS: 2}), "Administration cap +2", "administers")


func test_bug_329_countable_modifiers_keep_their_plural() -> void:
	eq(modifier_text({Modifiers.ACTIONS: 2}), "+2 actions each turn", "2 actions")
	eq(modifier_text({Modifiers.RENEWAL: 2}), "Renew up to 2 more cards each Anarchy turn", "2 cards (385)")
	eq(modifier_text({Modifiers.ACTIONS: 1}), "+1 action each turn", "1 action")


# --- 382: the face: one Unlocks line, a ledger of figures, gates as fine print ---

const HARBOR := {"id": "harbor", "name": "Harbor", "type": "building"}
const SHIPYARD := {"id": "shipyard", "name": "Shipyard", "type": "building"}
const SEA_TRADE := {"id": "sea_trade", "name": "Sea Trade", "type": "action"}
const FISHING_HUTS := {"id": "fishing_huts", "name": "Fishing Huts", "type": "building"}
const WEAVING := {"id": "weaving", "name": "Weaving", "type": "tech", "cost": {"insight": 2}}
const DELTA_MARSH := {"id": "delta_marsh", "name": "Delta Marsh", "type": "territory", "slots": 2, "housing": 3}
const SAILING := {"id": "sailing", "name": "Sailing", "type": "tech", "cost": {"insight": 2}, "effects": [
	{"op": "unlock", "card": "harbor"}, {"op": "unlock", "card": "shipyard"},
	{"op": "create", "card": "sea_trade", "zone": "discard"}, {"op": "unlock", "card": "sea_trade"},
	{"op": "gain", "resource": "insight", "amount": 1, "trigger": "upkeep"}]}
const ASSEMBLY := {"id": "assembly", "name": "Assembly", "type": "government", "actions": 3, "unrest_limit": 13,
	"tolerates": "town", "administers": 6, "effects": [{"op": "score", "amount": 1, "trigger": "upkeep"}]}


## The face cards: SAILING, ASSEMBLY, the cards they name, and extra; Assembly's tolerated tier named as ConfigLoader would.
func face_db(extra: Array = []) -> Dictionary:
	var db := text_db([HARBOR, SHIPYARD, SEA_TRADE, FISHING_HUTS, WEAVING, DELTA_MARSH, SAILING, ASSEMBLY] + extra)
	if db.has("assembly"):
		(db.assembly as CardDef).tolerates_name = "Town"
	return db


func test_every_unlock_joins_one_line_at_the_first() -> void:
	var db := face_db()
	var face: Dictionary = (db.sailing as CardDef).face(db)
	eq(face.rules, PackedStringArray(["Unlocks Harbor, Shipyard, Sea Trade", "Add a Sea Trade to your discard",
		"⟳ +1 insight"]), "Sailing's rules")
	eq([face.ledger, face.fine], [[], PackedStringArray()], "no ledger, no fine print")


func test_a_single_unlock_reads_unlocks_and_its_card() -> void:
	var db := face_db([{"id": "pottery", "name": "Pottery", "type": "tech", "cost": {"insight": 2}, "effects": [{"op": "unlock", "card": "harbor"}]}])
	eq((db.pottery as CardDef).face(db).rules, PackedStringArray(["Unlocks Harbor"]), "one unlock")


func test_a_governments_figures_are_a_ledger() -> void:
	var db := face_db()
	var face: Dictionary = (db.assembly as CardDef).face(db)
	eq(face.ledger, [["Actions", "3"], ["Unrest limit", "13"], ["Tolerates", "Town"], ["Administers", "6"]], "the ledger")
	eq(face.rules, PackedStringArray(["⟳ +1 VP"]), "the rules: its upkeep")


func test_a_field_the_card_lacks_has_no_ledger_row() -> void:
	var db := face_db([{"id": "band", "name": "Band", "type": "government", "actions": 2},
		{"id": "chiefs", "name": "Chiefs", "type": "government"}])
	eq((db.band as CardDef).face(db).ledger, [["Actions", "2"]], "only Actions")
	eq((db.chiefs as CardDef).face(db).ledger, [], "none")


func test_gates_are_fine_print_in_order() -> void:
	var db := face_db([
		{"id": "mill", "name": "Mill", "type": "building", "requires": ["fresh_water"],
			"effects": [{"op": "gain", "resource": "food", "amount": 1, "trigger": "upkeep"}]},
		{"id": "tower", "name": "Tower", "type": "building", "tier": "metropolis"},
		{"id": "dyeing", "name": "Dyeing", "type": "tech", "cost": {"insight": 2}, "prereq": "weaving",
			"eureka": {"card": "fishing_huts", "count": 1, "off": 4}},
		{"id": "nile", "name": "Nile", "type": "civilization", "home": "delta_marsh"},
		{"id": "colossus", "name": "Colossus", "type": "building", "cost": {"wealth": 10}, "project": true}])
	(db.tower as CardDef).tier_name = "Metropolis"
	var cases := {
		"mill": ["Needs Fresh Water"],
		"tower": ["Needs a Metropolis"],
		"dyeing": ["Needs Weaving", "Eureka: -4 insight with 1 Fishing Huts"],
		"nile": ["Starts on Delta Marsh"],
		"colossus": ["Built over turns"],
	}
	for id: String in cases:
		var face: Dictionary = (db[id] as CardDef).face(db)
		eq(face.fine, PackedStringArray(cases[id]), "%s's fine print" % id)
		for line: String in cases[id]:
			check(not face.rules.has(line), "%s: '%s' isn't a rule" % [id, line])
	eq((db.mill as CardDef).face(db).rules, PackedStringArray(["⟳ +1 food"]), "the Mill's rule stays")


func test_an_upgrades_face_has_no_builds_on_line() -> void:
	var db := face_db([{"id": "farm", "name": "Farm", "type": "building"},
		{"id": "plough", "name": "Plough", "type": "building", "upgrade_of": "farm", "tier": "town",
			"effects": [{"op": "gain", "resource": "food", "amount": 1, "trigger": "upkeep"}]}])
	(db.plough as CardDef).tier_name = "Town"
	var face: Dictionary = (db.plough as CardDef).face(db)
	eq(face.rules, PackedStringArray(["⟳ +1 food"]), "what it adds")
	eq(face.fine, PackedStringArray(["Needs a Town"]), "its tier as fine print")


func test_a_cards_own_text_is_its_rules_split_into_lines() -> void:
	var db := face_db([{"id": "anarchy", "name": "Anarchy", "type": "government", "actions": 2,
		"text": "No laws hold.\nRenew to end it."}])
	var face: Dictionary = (db.anarchy as CardDef).face(db)
	eq(face.rules, PackedStringArray(["No laws hold.", "Renew to end it."]), "its text's lines")
	eq([face.ledger, face.fine], [[], PackedStringArray()], "no ledger, no fine print")


func test_the_long_form_keeps_every_line() -> void:
	var db := face_db([{"id": "dyeing", "name": "Dyeing", "type": "tech", "cost": {"insight": 2}, "prereq": "weaving"},
		{"id": "colossus", "name": "Colossus", "type": "building", "cost": {"wealth": 10}, "project": true}])
	var sailing := (db.sailing as CardDef).rules_tooltip(db).split("\n")
	eq(Array(sailing).filter(func(l: String): return l.contains("can now be bought")).size(), 1, "Sea Trade's own line")
	check(sailing.size() >= 4, "an unlock per line: %s" % [sailing])
	var assembly := (db.assembly as CardDef).rules_tooltip(db)
	for line in [(db.assembly as CardDef).actions_text(), (db.assembly as CardDef).unrest_limit_text(),
			(db.assembly as CardDef).tolerates_text(), (db.assembly as CardDef).administers_text()]:
		check(assembly.contains(line), "the Assembly's '%s'" % line)
	check((db.dyeing as CardDef).rules_tooltip(db).contains("Needs Weaving researched first."), "the prereq sentence")
	check((db.colossus as CardDef).rules_tooltip(db).contains(CardDef.PROJECT_TEXT), "the project sentence")
