extends Effect
## { "op": "gain", "resource": "food", "amount": 2 }

var resource: String
var amount: int


## Changes only what upkeep_forecast restores (see Effect.upkeep_ok).
func upkeep_ok() -> bool:
	return true


func fields() -> Array[String]:
	return ["resource", "amount"]


func configure(data: Dictionary, ctx: Dictionary, errors: Array[String]) -> void:
	resource = Fields.read_string(data, "resource", errors, ctx.resources)
	amount = Fields.read_int(data, "amount", errors, 1)


func apply(engine: GameEngine, source: CardInstance) -> void:
	engine.gain(resource, amount, source)


func describe(_card_db: Dictionary) -> String:
	return "+%d %s" % [amount, resource]
