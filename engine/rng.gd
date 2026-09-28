class_name SeededRng
extends RefCounted
## Seeded random source. Every random decision in the engine goes through
## this, so the same seed always replays the same game.

var seed_value: int
var _rng := RandomNumberGenerator.new()


func _init(p_seed: int) -> void:
	seed_value = p_seed
	_rng.seed = p_seed


func randi_range(from: int, to: int) -> int:
	return _rng.randi_range(from, to)


## In-place Fisher-Yates shuffle.
func shuffle(arr: Array) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp
