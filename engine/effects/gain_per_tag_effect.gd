extends Effect
## { "op": "gain_per_tag", "resource": "food", "amount": 1, "tag": "farm", "zone": "tableau" }
## Gains amount x (number of cards with the tag in the zone). zone defaults to tableau.

var resource: String
var amount: int
var tag: String
var zone: String


## Changes only resources, bonus score or pop, which upkeep_forecast can report (see Effect.upkeep_ok).
func upkeep_ok() -> bool:
	return true


func fields() -> Array[String]:
	return ["resource", "amount", "tag", "zone"]


func configure(data: Dictionary, ctx: Dictionary, errors: Array[String]) -> void:
	resource = Fields.read_string(data, "resource", errors, ctx.resources)
	amount = Fields.read_int(data, "amount", errors, 1)
	tag = Fields.read_string(data, "tag", errors)
	zone = Fields.read_string(data, "zone", errors, ctx.zones, "tableau")


func apply(engine: GameEngine, source: CardInstance) -> void:
	engine.gain(resource, amount * engine.count_tag(tag, zone), source)


func describe(_card_db: Dictionary) -> String:
	return "+%d %s per %s%s" % [amount, resource, tag, _where()]


func describe_long(_card_db: Dictionary) -> String:
	return "+%d %s per %s card%s" % [amount, resource, tag, _where()]


func _where() -> String:
	return "" if zone == "tableau" else " in %s" % zone
