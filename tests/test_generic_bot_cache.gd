extends "res://tests/lib/anarchy_case.gd"
## The generic bot's forecast cache (backlog 315): value() looks each position's turn_forecast up by what the forecast
## reads, so a position it has already forecast this turn costs nothing, and the games played don't change. A fixture
## game of 10 turns (anarchy_case: Chiefs ruling, unrest on, home pop 6) with Kings in the government deck (so revolts
## are weighed by rollouts), Farms and Temples in the supply, explorable land and an event deck with a choice event.
## The bot is loaded untyped so this file parses before its new members exist.

var BOT: Variant = load("res://sim/generic_bot.gd")


## The fixture game for seed, not yet played.
func cache_game(seed_value := 1) -> GameEngine:
	var o := {"turn_limit": 10, "deck": {"farm": 3, "temple": 2, "pioneer": 2, "explorer": 2, "forager": 3, "feast": 1},
		"supply": {"farm": {"price": 1, "count": 3}, "temple": {"price": 2, "count": 3}},
		"territory_deck": {"hills": 2, "grassland": 2, "jungle": 1}, "event_deck": {"envoys": 2, "fleeting": 2}}
	var cards := anarchy_db(CHOICE_EVENTS)
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


## Plays seed's fixture game to its end with strategy, the cache on or off; returns [score, zones (ids in order), log].
func played_game(cache_on: bool, seed_value := 1, strategy := "generic") -> Array:
	var e := cache_game(seed_value)
	if BOT == null:
		check(false, "sim/generic_bot.gd exists")
		return []
	BOT.forecast_cache = cache_on
	check(BOT.play(e, strategy), "the game ends")
	BOT.forecast_cache = true
	var zones := {}
	for name in GameEngine.ZONES:
		zones[name] = card_ids(e.zone(name))
	return [e.score(), zones, e.log_lines.duplicate()]


# --- AC1: the same games ---

func test_the_cache_plays_the_same_game_as_without_it() -> void:
	for strategy in ["generic", "wide"]:
		var off := played_game(false, 1, strategy)
		var on := played_game(true, 1, strategy)
		eq(on[0], off[0], "%s: score" % strategy)
		eq(on[1], off[1], "%s: zones" % strategy)
		eq(on[2], off[2], "%s: log" % strategy)


# --- AC2: every cached forecast is right ---

func test_every_cached_forecast_equals_a_fresh_one() -> void:
	if BOT == null:
		check(false, "sim/generic_bot.gd exists")
		return
	BOT.check_forecasts = true
	played_game(true)
	BOT.check_forecasts = false
	check(BOT.forecast_checks > 0, "check mode compared cached forecasts: %d" % BOT.forecast_checks)
	eq(BOT.forecast_mismatches, 0, "cached forecasts that differ from a fresh turn_forecast()")


# --- AC3: fewer forecasts computed than looked up ---

func test_the_cache_computes_fewer_forecasts_than_it_looks_up() -> void:
	played_game(true)
	if BOT != null:
		check(BOT.forecasts_computed > 0 and BOT.forecasts_computed < BOT.forecast_lookups,
			"computed %d of %d looked up" % [BOT.forecasts_computed, BOT.forecast_lookups])


func test_positions_that_differ_only_in_the_hand_share_one_forecast() -> void:
	if BOT == null:
		check(false, "sim/generic_bot.gd exists")
		return
	var e := cache_game()
	var f := e.fork()
	f.discard_card(first_in_hand(f))  # the hand isn't read by the forecast
	var ctx: Variant = BOT.Context.new("generic")
	ctx.valuing = true  # no card values: measuring one forecasts its own forks
	BOT.reset_forecast_counts()
	BOT.value(e, ctx)
	BOT.value(f, ctx)
	eq([BOT.forecast_lookups, BOT.forecasts_computed], [2, 1], "[looked up, computed]")


func test_without_the_cache_every_lookup_is_computed() -> void:
	played_game(false)
	if BOT != null:
		check(BOT.forecast_lookups > 0, "forecasts were looked up")
		eq(BOT.forecasts_computed, BOT.forecast_lookups, "computed every one")


# --- AC4: nothing carries over between games ---

func test_a_game_plays_the_same_after_another_as_alone() -> void:
	var alone := played_game(true, 2)
	played_game(true, 1)
	var after := played_game(true, 2)
	eq(after[0], alone[0], "score")
	eq(after[1], alone[1], "zones")
	eq(after[2], alone[2], "log")
