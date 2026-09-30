extends Effect
## { "op": "lose_pop", "amount": 1 }
## Takes amount pop, one at a time, from the settled territory with the most pop (ties: first in tableau order).
## Nothing happens once no territory has pop, or with population off.

var amount: int


## Changes only what upkeep_forecast restores (see Effect.upkeep_ok).
func upkeep_ok() -> bool:
	return true


func fields() -> Array[String]:
	return ["amount"]


func configure(data: Dictionary, _ctx: Dictionary, errors: Array[String]) -> void:
	amount = Fields.read_int(data, "amount", errors, 1)


func apply(engine: GameEngine, source: CardInstance) -> void:
	engine.lose_pop(amount, source)


func describe(_card_db: Dictionary) -> String:
	return "−%d pop (largest territory)" % amount
