extends Node
## Global "Game" singleton: loads the data once and owns the engine.
## If the data has errors, load_errors is filled and engine stays null.

const CARDS_PATH := "res://data/cards.json"
const CONFIG_PATH := "res://data/config.json"

var engine: GameEngine
var load_errors: Array[String] = []


func _ready() -> void:
	var result := DataLoader.load_all(CARDS_PATH, CONFIG_PATH)
	for w in result.warnings:
		push_warning(w)
	if not result.errors.is_empty():
		load_errors.assign(result.errors)
		for e in load_errors:
			push_error(e)
		return
	engine = GameEngine.new(result.cards, result.config)


func new_game(seed_value: int) -> void:
	engine.new_game(seed_value)
