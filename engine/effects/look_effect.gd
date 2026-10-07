extends Effect
## { "op": "look", "count": 3 }
## Takes the top count cards of the deck (2–5, default 3; the discard reshuffles in when the deck runs out, as on a
## draw) and owes a take of one into the hand, the rest to the discard (371). One card goes to the hand at once; none,
## and nothing happens. The card being played is never one of them.

const MIN_COUNT := 2
const MAX_COUNT := 5

var count: int


func fields() -> Array[String]:
	return ["count"]


func configure(data: Dictionary, _ctx: Dictionary, errors: Array[String]) -> void:
	count = Fields.read_int(data, "count", errors, MIN_COUNT, 3)
	if count > MAX_COUNT:
		errors.append("'count' must be an integer from %d to %d, not %d" % [MIN_COUNT, MAX_COUNT, count])


func apply(engine: GameEngine, source: CardInstance) -> void:
	engine.look(count, source)


func opens_choice() -> bool:
	return true


func describe(_card_db: Dictionary) -> String:
	return "Look at the top %d cards of your deck: take 1 into your hand, discard the rest" % count
