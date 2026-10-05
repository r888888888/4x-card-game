extends Effect
## { "op": "lose_pct", "resource": "food", "pct": 25 }
## Takes pct% of the stored resource, rounded up (as Anarchy's drain does), never below 0 (268). pct is 1 to 100.

var resource: String
var pct: int


## Changes only resources, bonus score or pop, which upkeep_forecast can report (see Effect.upkeep_ok).
func upkeep_ok() -> bool:
	return true


func fields() -> Array[String]:
	return ["resource", "pct"]


func configure(data: Dictionary, ctx: Dictionary, errors: Array[String]) -> void:
	resource = Fields.read_string(data, "resource", errors, ctx.resources)
	if not data.has("pct"):
		errors.append("missing 'pct'")
		return
	var v: Variant = Fields.as_int(data.pct)
	if typeof(v) != TYPE_INT or v < 1 or v > 100:
		errors.append("'pct' must be an integer from 1 to 100")
		return
	pct = v


func apply(engine: GameEngine, source: CardInstance) -> void:
	var n := ceili(maxi(0, engine.resources.get(resource, 0)) * pct / 100.0)
	if n > 0:
		engine.lose(resource, n, source)


func describe(_card_db: Dictionary) -> String:
	return "−%d%% %s" % [pct, resource]


func describe_long(_card_db: Dictionary) -> String:
	return "Lose %d%% of stored %s (rounded up)" % [pct, resource]
