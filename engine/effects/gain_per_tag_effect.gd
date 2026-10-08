extends Effect
## { "op": "gain_per_tag", "resource": "food", "amount": 1, "tag": "farm", "zone": "tableau", "per": 1 }
## Gains amount x (number of cards with the tag in the zone / per, rounded down). zone defaults to tableau, per to 1
## (367: Sailing's +1 insight per 2 ports).

var resource: String
var amount: int
var tag: String
var zone: String
var per: int


## Changes only resources, bonus score or pop, which upkeep_forecast can report (see Effect.upkeep_ok).
func upkeep_ok() -> bool:
	return true


## The zone it counts tagged cards in (336).
func reads_zones() -> Array[String]:
	return [zone]


func fields() -> Array[String]:
	return ["resource", "amount", "tag", "zone", "per"]


func configure(data: Dictionary, ctx: Dictionary, errors: Array[String]) -> void:
	resource = Fields.read_string(data, "resource", errors, ctx.resources)
	amount = Fields.read_int(data, "amount", errors, 1)
	tag = Fields.read_string(data, "tag", errors)
	zone = Fields.read_string(data, "zone", errors, ctx.zones, "tableau")
	per = Fields.read_int(data, "per", errors, 1, 1)


func apply(engine: GameEngine, source: CardInstance) -> void:
	engine.gain(resource, amount * (engine.count_tag(tag, zone) / per), source)


func describe(_card_db: Dictionary) -> String:
	return "+%d %s per %s%s%s" % [amount, resource, _per(), tag, _where()]


func describe_long(_card_db: Dictionary) -> String:
	return "+%d %s per %s%s card%s%s" % [amount, resource, _per(), tag, "" if per == 1 else "s", _where()]


func _per() -> String:
	return "" if per == 1 else "%d " % per


func _where() -> String:
	return "" if zone == "tableau" else " in %s" % zone
