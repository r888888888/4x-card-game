extends Effect
## { "op": "gain", "resource": "food", "amount": 2 }

var resource: String
var amount: int


func fields() -> Array[String]:
	return ["resource", "amount"]


func configure(data: Dictionary, ctx: Dictionary, errors: Array[String]) -> void:
	resource = read_string(data, "resource", errors, ctx.resources)
	amount = read_int(data, "amount", errors, 1)


func apply(engine: GameEngine, source: CardInstance) -> void:
	engine.gain(resource, amount, source)


func describe(_card_db: Dictionary) -> String:
	return "+%d %s" % [amount, resource]
