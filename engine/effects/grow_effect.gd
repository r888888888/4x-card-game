extends Effect
## { "op": "grow", "amount": 1, "where": "here" }
## Adds pop, capped by housing and free of food: "here" on the card's own territory, "each" on every
## settled territory (with "count": on that many of the smallest with room), "best" on the one territory where it
## helps most (Population.best_to_grow, 261). Does nothing when the population rules are off.

const WHERE: Array[String] = ["here", "each", "best"]

var amount: int
var where: String
var count: int  # with "each": at most this many territories (0: every one)


## Changes only resources, bonus score or pop, which upkeep_forecast can report (see Effect.upkeep_ok).
func upkeep_ok() -> bool:
	return true


## "here" grows the card's own territory.
func needs_own_territory() -> bool:
	return where == "here"


func fields() -> Array[String]:
	return ["amount", "where", "count"]


func configure(data: Dictionary, _ctx: Dictionary, errors: Array[String]) -> void:
	amount = Fields.read_int(data, "amount", errors, 1)
	where = Fields.read_string(data, "where", errors, WHERE, "here")
	count = Fields.read_int(data, "count", errors, 1, 0)
	if data.has("count") and where != "each":
		errors.append("'count' only applies with 'where': 'each' (got '%s')" % where)


func apply(engine: GameEngine, source: CardInstance) -> void:
	if where == "here":
		engine.add_pop(source.territory_uid, amount, source)
		return
	if where == "best":
		var best := Population.best_to_grow(engine)
		if best != null:
			engine.add_pop(best.uid, amount, source)
		return
	if count > 0:
		for card in Population.smallest_with_room(engine).slice(0, count):
			engine.add_pop(card.uid, amount, source)
		return
	for card in engine.zone("tableau").cards:
		if card.def.type == CardDef.TERRITORY:
			engine.add_pop(card.uid, amount, source)


## A card whose play effects are all grows can't be played when it would add no pop (276): during a Famine, or with no
## territory below its housing. "here" and the population rules being off are left alone.
func play_block_error(engine: GameEngine, card: CardInstance) -> String:
	if where == "here" or not engine.population_on():
		return ""
	if card.def.effects.any(func(e: Effect) -> bool: return e.trigger == "play" and e.op != op):
		return ""
	var famine := Famine.growth_error(engine)
	if famine != "":
		return famine
	if Population.smallest_with_room(engine).is_empty():
		return "No territory has room to grow."
	return ""


func terms() -> Array[String]:
	var out := super()
	out.append_array(["Grow"])
	return out

func describe(_card_db: Dictionary) -> String:
	if where == "best":
		return "+%d pop" % amount
	if count > 0:
		return "+%d pop on %d territories" % [amount, count]
	return "+%d pop %s" % [amount, "here" if where == "here" else "everywhere"]


func describe_long(_card_db: Dictionary) -> String:
	if where == "best":
		return "+%d pop where it's needed most" % amount
	if count > 0:
		return "+%d pop on each of your %d smallest territories with room" % [amount, count]
	return "+%d pop %s" % [amount, "here" if where == "here" else "in each territory"]
