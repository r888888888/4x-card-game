extends "res://tests/lib/test_case.gd"
## The sim's result cache key (backlog 292): SimStats.source_hash over the code that plays a game. The cached runs on
## the real data are in tests/balance/test_sim_cache_runs.gd.


## A temp tree with engine/, sim/, autoload/ and ui/ scripts (and a .uid) under name; its root.
func fixture_tree(name: String, changes := {}) -> String:
	var root := OS.get_temp_dir().path_join("test-292-%d-%s" % [OS.get_process_id(), name])
	var files := {"engine/a.gd": "var a := 1\n", "engine/deep/b.gd": "var b := 2\n", "sim/c.gd": "var c := 3\n",
		"autoload/d.gd": "var d := 4\n", "ui/e.gd": "var e := 5\n", "engine/a.gd.uid": "uid://abc\n"}
	files.merge(changes, true)
	for path in files:
		DirAccess.make_dir_recursive_absolute(root.path_join(path).get_base_dir())
		var f := FileAccess.open(root.path_join(path), FileAccess.WRITE)
		f.store_string(files[path])
		f.close()
	return root



## source_hash of the fixture tree with changes against the plain one: whether they hash the same.
func same_hash(changes: Dictionary) -> bool:
	var stats: Object = SimStats.new()
	var a := fixture_tree("a")
	var b := fixture_tree("b", changes)
	var same: bool = stats.source_hash(a) == stats.source_hash(b)
	remove_tree(a)
	remove_tree(b)
	return same


# --- AC4: source_hash ---

func test_identical_trees_hash_the_same() -> void:
	check(same_hash({}), "identical trees")


func test_a_changed_line_in_the_game_code_changes_the_hash() -> void:
	check(not same_hash({"engine/a.gd": "var a := 2\n"}), "engine/")
	check(not same_hash({"engine/deep/b.gd": "var b := 3\n"}), "a folder under engine/")
	check(not same_hash({"sim/c.gd": "var c := 4\n"}), "sim/")
	check(not same_hash({"autoload/d.gd": "var d := 5\n"}), "autoload/")


func test_a_new_script_changes_the_hash() -> void:
	check(not same_hash({"engine/f.gd": "var f := 6\n"}), "a new engine script")


func test_other_files_leave_the_hash_alone() -> void:
	check(same_hash({"ui/e.gd": "var e := 6\n"}), "a ui/ script")
	check(same_hash({"engine/a.gd.uid": "uid://xyz\n"}), "a .uid file")
	check(same_hash({"docs/notes.md": "hello\n"}), "a file outside the code folders")
