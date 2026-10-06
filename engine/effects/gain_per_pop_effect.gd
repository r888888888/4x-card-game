extends Effect
## { "op": "gain_per_pop", "resource": "wealth", "amount": 1, "per": 3 }
## Gains amount x (pop on the card's own territory / per, rounded down) (304). amount and per default to 1. Gains
## nothing with no territory or with the population rules off.

var resource: String
var amount: int
var per: int


## Changes only resources, bonus score or pop, which upkeep_forecast can report (see Effect.upkeep_ok).
func upkeep_ok() -> bool:
	return true


## It counts the pop on its own card's territory.
func needs_own_territory() -> bool:
	return true


func fields() -> Array[String]:
	return ["resource", "amount", "per"]


func configure(data: Dictionary, ctx: Dictionary, errors: Array[String]) -> void:
	resource = Fields.read_string(data, "resource", errors, ctx.resources)
	amount = Fields.read_int(data, "amount", errors, 1, 1)
	per = Fields.read_int(data, "per", errors, 1, 1)


func apply(engine: GameEngine, source: CardInstance) -> void:
	if not engine.population_on():
		return
	engine.gain(resource, amount * (engine.pop(source.territory_uid) / per), source)


func describe(_card_db: Dictionary) -> String:
	return "+%d %s per %spop here" % [amount, resource, _per()]


func describe_long(_card_db: Dictionary) -> String:
	return "+%d %s for every %spop on this territory" % [amount, resource, _per()]


func _per() -> String:
	return "" if per == 1 else "%d " % per
