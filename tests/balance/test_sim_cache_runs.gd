extends "res://tests/lib/test_case.gd"
## The sim's result cache on the real data (backlog 292): run_files reads a game from cache_dir when the same code, data,
## seed, strategy, civ and turn limit played it before, and writes each game it plays. Short games.

const CARDS := "res://data/cards.json"
const CONFIG := "res://data/config.json"


func cache_dir(name := "cache") -> String:
	return OS.get_temp_dir().path_join("test-292-%d-%s" % [OS.get_process_id(), name])


## Removes this file's temp directories: each test starts with an empty cache and leaves none.
func clean() -> void:
	for name in ["cache", "fresh", "data"]:
		remove_tree(cache_dir(name))


## run_files' result for seed_count seeds of strategy, sumer for 4 turns unless options say otherwise, with the cache.
func run_with(seed_count: int, strategy := "baseline", options := {}, config := CONFIG) -> Dictionary:
	var o := {"civ": "sumer", "turns": 4, "seed": -1, "procs": 1, "cache_dir": cache_dir()}
	o.merge(options, true)
	return SimStats.run_files(CARDS, config, seed_count, strategy, o)



## Every file in the cache, by path.
func cache_files(dir := cache_dir()) -> Array:
	var out := []
	if not DirAccess.dir_exists_absolute(dir):
		return out
	for sub in DirAccess.get_directories_at(dir):
		out.append_array(cache_files(dir.path_join(sub)))
	for f in DirAccess.get_files_at(dir):
		out.append(dir.path_join(f))
	out.sort()
	return out


## A copy of the real config at path, with text replaced by with (none: byte-identical).
func config_copy(name: String, text := "", with := "") -> String:
	var source := FileAccess.get_file_as_string(CONFIG)
	if text != "":
		check(source.contains(text), "the config has %s" % text)
		source = source.replace(text, with)
	DirAccess.make_dir_recursive_absolute(cache_dir("data"))
	var path := cache_dir("data").path_join(name)
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(source)
	f.close()
	return path


# --- AC1: a second run reads the cache ---

func test_a_second_run_reads_every_game_from_the_cache() -> void:
	clean()
	var first := run_with(2)
	eq([first.get("played"), first.get("cached")], [2, 0], "first run: played, cached")
	var second := run_with(2)
	eq([second.get("played"), second.get("cached")], [0, 2], "second run: played, cached")
	eq(second.get("lines", []).slice(1), first.get("lines", []).slice(1), "the same report")
	eq(first.get("lines", [""])[0], "2 seeds (1-2)", "first header")
	eq(second.get("lines", [""])[0], "2 seeds (1-2), 2 of 2 games cached", "second header")
	clean()


# --- AC2: the key ---

func test_a_different_turn_limit_civ_strategy_or_seed_misses() -> void:
	clean()
	run_with(2)
	eq(run_with(2, "baseline", {"turns": 5}).get("played"), 2, "--turns 5")
	eq(run_with(2, "baseline", {"civ": "greece"}).get("played"), 2, "--civ greece")
	eq(run_with(2, "wealth").get("played"), 2, "wealth")
	var three := run_with(3)
	eq([three.get("played"), three.get("cached")], [1, 2], "seeds 1-3: seed 3 played")
	clean()


# --- AC3: the data's contents, not its path ---

func test_changed_data_misses_and_a_byte_identical_copy_hits() -> void:
	clean()
	run_with(2)
	var changed := config_copy("changed.json", "\"turn_limit\": 100", "\"turn_limit\": 99")
	eq(run_with(2, "baseline", {}, changed).get("played"), 2, "a config with one value changed")
	var same := config_copy("same.json")
	var out := run_with(2, "baseline", {}, same)
	eq([out.get("played"), out.get("cached")], [0, 2], "a byte-identical copy at another path")
	clean()


# --- AC5: a parallel run sends only the uncached games to its workers ---

func test_a_parallel_run_plays_only_the_uncached_games() -> void:
	clean()
	var plain := run_with(4, "baseline", {"cache_dir": ""})
	run_with(2)
	var mixed := run_with(4, "baseline", {"procs": 2})
	eq([mixed.get("played"), mixed.get("cached")], [2, 2], "seeds 3-4 played, 1-2 cached")
	eq(mixed.get("games_per_proc", []).reduce(func(a, b): return a + b, 0), 2, "the workers played 2 games")
	eq(mixed.get("lines", []).slice(1), plain.get("lines", []).slice(1), "the report equals an uncached run")
	var all := run_with(4, "baseline", {"procs": 2})
	eq([all.get("played"), all.get("cached")], [0, 4], "all 4 cached")
	eq(all.get("games_per_proc"), [], "no worker started")
	clean()


# --- AC6: a bad entry, and no cache ---

func test_a_bad_cache_entry_is_played_again_and_overwritten() -> void:
	clean()
	run_with(2)
	var files := cache_files()
	eq(files.size(), 2, "2 entries")
	for i in files.size():
		var f := FileAccess.open(files[i], FileAccess.WRITE)
		f.store_string("not json" if i == 0 else JSON.stringify({"score": 1}))
		f.close()
	var out := run_with(2)
	eq([out.get("code"), out.get("played"), out.get("cached")], [0, 2, 0], "both played again")
	var again := run_with(2)
	eq(again.get("cached"), 2, "the entries were overwritten")
	clean()


func test_with_the_cache_off_every_game_is_played_and_nothing_written() -> void:
	clean()
	run_with(2)
	var out := run_with(2, "baseline", {"cache": false})
	eq([out.get("played"), out.get("cached")], [2, 0], "played, cached")
	var fresh := run_with(2, "baseline", {"cache": false, "cache_dir": cache_dir("fresh")})
	eq(fresh.get("played"), 2, "played")
	eq(cache_files(cache_dir("fresh")), [], "nothing written")
	clean()
