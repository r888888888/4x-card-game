extends "res://tests/lib/anarchy_case.gd"
## The generic bot's forecast cache (backlog 315): value() looks each position's turn_forecast up by what the forecast
## reads, so a position it has already forecast this turn costs nothing, and the games played don't change. A fixture
## game of 10 turns (anarchy_case: Chiefs ruling, unrest on, home pop 6) with Kings in the government deck (so revolts
## are weighed by rollouts), Farms and Temples in the supply, explorable land and an event deck with a choice event.
## 335: the full games are played once per run (shared_games) and the tests read their results and counters.


## Scribe: creates a Farm in the discard. Tally: ⟳ +1 food per farm in the discard.
const SCRIBE := {"id": "scribe", "name": "Scribe", "type": "action",
	"effects": [{"op": "create", "card": "farm", "zone": "discard"}]}
const TALLY := {"id": "tally", "name": "Tally", "type": "building",
	"effects": [{"op": "gain_per_tag", "resource": "food", "amount": 1, "tag": "farm", "zone": "discard",
		"trigger": "upkeep"}]}


## The fixture game for seed, not yet played, with extra cards in its card db.
func cache_game(seed_value := 1, extra := []) -> GameEngine:
	var o := {"turn_limit": 10, "deck": {"farm": 3, "temple": 2, "pioneer": 2, "explorer": 2, "forager": 3, "feast": 1},
		"supply": {"farm": {"price": 1, "count": 3}, "temple": {"price": 2, "count": 3}},
		"territory_deck": {"hills": 2, "grassland": 2, "jungle": 1}, "event_deck": {"envoys": 2, "fleeting": 2}}
	var cards := anarchy_db(CHOICE_EVENTS + extra)
	var errors: Array[String] = []
	var warnings: Array[String] = []
	var raw := anarchy_raw({}, o)
	var listed: Array[String] = []
	listed.assign(raw.resources)
	var config := DataLoader.parse_config(raw, listed, cards, "config.json", errors, warnings)
	check(errors.is_empty(), "test config should load: %s" % [errors])
	var e := GameEngine.new(cards, config)
	e.new_game(seed_value)
	put_in(e, "kings", "governments")
	return e


## The fixture games, played once per run in this order (335): seed 2 alone, seed 1's generic and wide games with the
## cache off then on (generic's in check mode, which changes nothing but its counts), then seed 2 again after them.
## Keys "seed/strategy/cache" ("2/generic/on/after" for the second seed 2); each holds [score, zones, log] and the
## bot's counters after the game.
static var _shared := {}
## How many bot games shared_games has played this run.
static var game_plays := 0


## Plays seed's fixture game to its end with strategy, the cache on or off; returns [score, zones (ids in order), log],
## then the bot's counters {lookups, computed, checks, mismatches}.
func played_game(cache_on: bool, seed_value := 1, strategy := "generic") -> Array:
	var e := cache_game(seed_value)
	GenericBot.forecast_cache = cache_on
	check(GenericBot.play(e, strategy), "the game ends")
	GenericBot.forecast_cache = true
	game_plays += 1
	var zones := {}
	for name in GameEngine.ZONES:
		zones[name] = card_ids(e.zone(name))
	var counts := {"lookups": GenericBot.forecast_lookups, "computed": GenericBot.forecasts_computed,
		"checks": GenericBot.forecast_checks, "mismatches": GenericBot.forecast_mismatches}
	return [e.score(), zones, e.log_lines.duplicate(), counts]


## The shared fixture games (see _shared), played on the first call.
func shared_games() -> Dictionary:
	if _shared.is_empty():
		_shared["2/generic/on"] = played_game(true, 2)
		for strategy in ["generic", "wide"]:
			_shared["1/%s/off" % strategy] = played_game(false, 1, strategy)
			GenericBot.check_forecasts = strategy == "generic"
			_shared["1/%s/on" % strategy] = played_game(true, 1, strategy)
			GenericBot.check_forecasts = false
		_shared["2/generic/on/after"] = played_game(true, 2)
	return _shared


## The shared game under key (see _shared).
func shared(key: String) -> Array:
	return shared_games()[key]


# --- 335: each fixture game played once per run ---

func test_the_shared_games_are_played_once_per_run() -> void:
	var first := shared_games()
	var second := shared_games()
	check(first == second, "the same games both times")
	eq(game_plays, 6, "6 bot games: seed 1 generic and wide, cache off and on; seed 2 alone and after seed 1")

# --- AC1: the same games ---

func test_the_cache_plays_the_same_game_as_without_it() -> void:
	for strategy in ["generic", "wide"]:
		var off := shared("1/%s/off" % strategy)
		var on := shared("1/%s/on" % strategy)
		eq(on[0], off[0], "%s: score" % strategy)
		eq(on[1], off[1], "%s: zones" % strategy)
		eq(on[2], off[2], "%s: log" % strategy)


# --- AC2: every cached forecast is right ---

func test_every_cached_forecast_equals_a_fresh_one() -> void:
	var counts: Dictionary = shared("1/generic/on")[3]
	check(counts.checks > 0, "check mode compared cached forecasts: %d" % counts.checks)
	eq(counts.mismatches, 0, "cached forecasts that differ from a fresh turn_forecast()")


# --- AC3: fewer forecasts computed than looked up ---

func test_the_cache_computes_fewer_forecasts_than_it_looks_up() -> void:
	var counts: Dictionary = shared("1/generic/on")[3]
	check(counts.computed > 0 and counts.computed < counts.lookups,
		"computed %d of %d looked up" % [counts.computed, counts.lookups])


func test_positions_that_differ_only_in_the_hand_share_one_forecast() -> void:
	eq(lookups_for_a_discard(cache_game()), [2, 1], "[looked up, computed]: the hand isn't read by the forecast")


## [looked up, computed] for valuing e and then e with its first hand card discarded, without card values.
func lookups_for_a_discard(e: GameEngine) -> Array:
	var f := e.fork()
	f.discard_card(first_in_hand(f))
	var ctx := GenericBot.Context.new("generic")
	ctx.valuing = true  # no card values: measuring one forecasts its own forks
	GenericBot.reset_forecast_counts()
	GenericBot.value(e, ctx)
	GenericBot.value(f, ctx)
	return [GenericBot.forecast_lookups, GenericBot.forecasts_computed]


func test_a_card_that_creates_into_the_discard_doesnt_put_the_discard_in_the_key() -> void:
	eq(lookups_for_a_discard(cache_game(1, [SCRIBE])), [2, 1], "[looked up, computed] with Scribe in the card db")


func test_an_upkeep_that_counts_the_discard_puts_it_in_the_key() -> void:
	var e := cache_game(1, [TALLY])
	build_on(e, home_uid(e), ["tally"])
	eq(lookups_for_a_discard(e), [2, 2], "[looked up, computed]: the discard changes Tally's upkeep")


func test_without_the_cache_every_lookup_is_computed() -> void:
	var counts: Dictionary = shared("1/generic/off")[3]
	check(counts.lookups > 0, "forecasts were looked up")
	eq(counts.computed, counts.lookups, "computed every one")


# --- AC4: nothing carries over between games ---

func test_a_game_plays_the_same_after_another_as_alone() -> void:
	var alone := shared("2/generic/on")
	var after := shared("2/generic/on/after")
	eq(after[0], alone[0], "score")
	eq(after[1], alone[1], "zones")
	eq(after[2], alone[2], "log")


# --- 336: the key reads what the forecast reads ---

## GenericBot's constant name ([] or {} until it exists).
func bot_list(name: String) -> Variant:
	return (GenericBot as Script).get_script_constant_map().get(name, [])


## The fields of o (a GameState or CardInstance) that are neither in the key's list nor in the unread list (with a
## reason), and those in both.
func unclassified(o: Object, key_list: String, unread_list: String) -> Array[String]:
	var key: Array = bot_list(key_list)
	var unread: Variant = bot_list(unread_list)
	var out: Array[String] = []
	for field in script_vars(o):
		var reason: String = unread.get(field, "") if unread is Dictionary else ""
		if key.has(field) == (reason != ""):
			out.append(field)
	return out


func test_every_game_state_field_is_in_the_key_or_listed_as_unread() -> void:
	eq(unclassified(GameState.new(), "KEY_STATE_FIELDS", "UNREAD_STATE_FIELDS"), [] as Array[String],
		"GameState fields neither in GenericBot.KEY_STATE_FIELDS nor in UNREAD_STATE_FIELDS with a reason, or in both")


func test_every_card_instance_field_is_in_the_key_or_listed_as_unread() -> void:
	var card := CardInstance.new(1, cache_game().card_db["farm"])
	eq(unclassified(card, "KEY_CARD_FIELDS", "UNREAD_CARD_FIELDS"), [] as Array[String],
		"CardInstance fields neither in GenericBot.KEY_CARD_FIELDS nor in UNREAD_CARD_FIELDS with a reason, or in both")


func test_the_key_reads_every_field_its_lists_name() -> void:
	var source := FileAccess.get_file_as_string("res://sim/generic_bot.gd")
	var at := source.find("static func forecast_key(")
	var body := source.substr(at, source.find("\n\n\n", at) - at)
	var fields: Array = bot_list("KEY_STATE_FIELDS") + bot_list("KEY_CARD_FIELDS")
	check(fields.size() >= 15, "the key's lists: %s" % [fields])
	for field in fields:
		check(body.contains("." + field), "forecast_key reads %s" % field)


func test_the_key_uses_the_engines_forecast_zones_and_names_no_op() -> void:
	var source := FileAccess.get_file_as_string("res://sim/generic_bot.gd")
	check(source.contains("forecast_zones()"), "GenericBot asks the engine for forecast_zones()")
	check(not source.contains("\"gain_per_tag\""), "GenericBot names no op")


## The forecast keys of e and of its fork after change(fork).
func keys_after(e: GameEngine, change: Callable) -> Array:
	var f := e.fork()
	change.call(f)
	return [GenericBot.forecast_key(e, GenericBot.Context.new("generic")),
		GenericBot.forecast_key(f, GenericBot.Context.new("generic"))]


func test_positions_differing_in_eras_added_keywords_or_base_have_different_keys() -> void:
	var e := cache_game()
	var home := home_uid(e)
	var eras := keys_after(e, func(f: GameEngine): f.state.eras_added.append(3))
	check(eras[0] != eras[1], "eras added (an era unlock's check reads them)")
	var keywords := keys_after(e, func(f: GameEngine): f.zone("tableau").find(home).keywords.append("river"))
	check(keywords[0] != keywords[1], "a territory's keywords (keyword effects and raids read them)")
	var base := keys_after(e, func(f: GameEngine): f.zone("tableau").find(home).base_uid = 99)
	check(base[0] != base[1], "a card's base (a pillage's fallback reads it)")

