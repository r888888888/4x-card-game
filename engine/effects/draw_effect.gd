extends Effect
## { "op": "draw", "amount": 2 }

var amount: int


func fields() -> Array[String]:
	return ["amount"]


func configure(data: Dictionary, _ctx: Dictionary, errors: Array[String]) -> void:
	amount = read_int(data, "amount", errors, 1)


func apply(engine: GameEngine, _source: CardInstance) -> void:
	engine.draw(amount)


func describe(_card_db: Dictionary) -> String:
	return "Draw %d card%s" % [amount, "" if amount == 1 else "s"]
