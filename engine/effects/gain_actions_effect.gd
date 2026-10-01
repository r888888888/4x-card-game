extends Effect
## { "op": "gain_actions", "amount": 1 }
## Gives amount more actions this turn (backlog 128); amount defaults to 1. Play only: an upkeep or start has no turn
## to spend them in, and an event resolves after the player's plays. Does nothing while actions are unlimited.

var amount: int


func fields() -> Array[String]:
	return ["amount"]


func needs_a_turn() -> bool:
	return true


func configure(data: Dictionary, _ctx: Dictionary, errors: Array[String]) -> void:
	amount = Fields.read_int(data, "amount", errors, 1, 1)


func apply(engine: GameEngine, source: CardInstance) -> void:
	engine.gain_actions(amount, source)


func describe(_card_db: Dictionary) -> String:
	return "+%d action%s" % [amount, "" if amount == 1 else "s"]


func describe_long(card_db: Dictionary) -> String:
	return describe(card_db) + " this turn"
