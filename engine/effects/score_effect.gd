extends Effect
## { "op": "score", "amount": 1 }
## Adds victory points directly (on top of the VP printed on tableau cards).

var amount: int


func fields() -> Array[String]:
	return ["amount"]


func configure(data: Dictionary, _ctx: Dictionary, errors: Array[String]) -> void:
	amount = read_int(data, "amount", errors, 1)


func apply(engine: GameEngine, source: CardInstance) -> void:
	engine.add_score(amount, source)


func describe(_card_db: Dictionary) -> String:
	return "+%d VP" % amount
