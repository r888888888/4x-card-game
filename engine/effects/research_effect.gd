extends Effect
## { "op": "research", "amount": 1 }
## Grants research actions for this turn (see GameEngine.research). On upkeep, a Library's extra research.

var amount: int


func fields() -> Array[String]:
	return ["amount"]


func configure(data: Dictionary, _ctx: Dictionary, errors: Array[String]) -> void:
	amount = read_int(data, "amount", errors, 1, 1)


func apply(engine: GameEngine, source: CardInstance) -> void:
	engine.add_research(amount, source)


func describe(_card_db: Dictionary) -> String:
	return "+%d research" % amount
