extends RefCounted
## Splits the test files between the runner's parallel processes (223): scripts/test.sh starts one per shard.


## The files shard index (0-based) of count runs: files index, index + count, index + 2 * count, …
static func pick(files: Array[String], index: int, count: int) -> Array[String]:
	var picked: Array[String] = []
	for i in range(index, files.size(), count):
		picked.append(files[i])
	return picked
