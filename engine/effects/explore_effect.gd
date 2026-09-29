extends Effect
## { "op": "explore", "reveal": 2 }
## Reveals the top territories; the player keeps one in the frontier, the rest go to the bottom.

var reveal: int


func fields() -> Array[String]:
	return ["reveal"]


func configure(data: Dictionary, _ctx: Dictionary, errors: Array[String]) -> void:
	reveal = Fields.read_int(data, "reveal", errors, 1, 2)


func apply(engine: GameEngine, source: CardInstance) -> void:
	engine.explore(reveal, source)


func describe(_card_db: Dictionary) -> String:
	return "Explore %d" % reveal


func describe_long(_card_db: Dictionary) -> String:
	return "Explore: reveal %d territor%s, keep 1" % [reveal, "y" if reveal == 1 else "ies"]
