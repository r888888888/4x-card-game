extends RefCounted
## Splits the test files between the runner's parallel processes (223): scripts/test.sh starts one per shard. The slow
## files are dealt first, one per shard in turn, so no two land together (335).

## The slowest test files, slowest first (335: per-file times with Godot's start; re-measure when the suite changes).
const SLOW: Array[String] = ["test_generic_bot_cache.gd", "test_knowledge_screen.gd", "test_sim_anarchy.gd",
	"test_ui_smoke.gd", "test_start_screen.gd"]


## files with those in slow (matched by file name) first, in slow's order, then the rest in their order.
static func slow_first(files: Array[String], slow: Array[String] = SLOW) -> Array[String]:
	var out: Array[String] = []
	for name in slow:
		for f in files:
			if f.get_file() == name:
				out.append(f)
	for f in files:
		if not out.has(f):
			out.append(f)
	return out


## The files shard index (0-based) of count runs: files index, index + count, index + 2 * count, …
static func pick(files: Array[String], index: int, count: int) -> Array[String]:
	var picked: Array[String] = []
	for i in range(index, files.size(), count):
		picked.append(files[i])
	return picked
