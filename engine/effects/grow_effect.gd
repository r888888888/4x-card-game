extends Effect
## { "op": "grow", "amount": 1, "where": "here" }
## Adds pop, capped by housing and free of food: "here" on the card's own territory, "each" on every
## settled territory. Does nothing when the population rules are off.

const WHERE: Array[String] = ["here", "each"]

var amount: int
var where: String


func fields() -> Array[String]:
	return ["amount", "where"]


func configure(data: Dictionary, _ctx: Dictionary, errors: Array[String]) -> void:
	amount = read_int(data, "amount", errors, 1)
	where = read_string(data, "where", errors, WHERE, "here")


func apply(engine: GameEngine, source: CardInstance) -> void:
	if where == "here":
		engine.add_pop(source.territory_uid, amount, source)
		return
	for card in engine.zone("tableau").cards:
		if card.def.type == "territory":
			engine.add_pop(card.uid, amount, source)


func describe(_card_db: Dictionary) -> String:
	return "+%d pop %s" % [amount, "here" if where == "here" else "everywhere"]


func describe_long(_card_db: Dictionary) -> String:
	return "+%d pop %s" % [amount, "here" if where == "here" else "in each territory"]
