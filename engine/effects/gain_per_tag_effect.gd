extends Effect
## { "op": "gain_per_tag", "resource": "food", "amount": 1, "tag": "farm", "zone": "tableau", "per": 1 }
## Gains amount x (number of cards with the tag in the zone / per, rounded down). zone defaults to tableau, per to 1
## (367: Sailing's +1 insight per 2 ports). "where": "here" (414) counts instead the other working base buildings with
## the tag on the card's own territory (Irrigation Canals: +1 food per other farm here), so only a building can use it.

var resource: String
var amount: int
var tag: String
var zone: String
var per: int
var where: String  # "here" or "" (the whole zone)


## Changes only resources, bonus score or pop, which upkeep_forecast can report (see Effect.upkeep_ok).
func upkeep_ok() -> bool:
	return true


## The zone it counts tagged cards in (336).
func reads_zones() -> Array[String]:
	return [zone]


## A here count reads its own card's territory.
func needs_own_territory() -> bool:
	return where == "here"


func type_problem(type: String) -> String:
	return "'where': 'here' only works on a building" if where == "here" and type != CardDef.BUILDING else ""


func fields() -> Array[String]:
	return ["resource", "amount", "tag", "zone", "per", "where"]


func configure(data: Dictionary, ctx: Dictionary, errors: Array[String]) -> void:
	resource = Fields.read_string(data, "resource", errors, ctx.resources)
	amount = Fields.read_int(data, "amount", errors, 1)
	tag = Fields.read_string(data, "tag", errors)
	zone = Fields.read_string(data, "zone", errors, ctx.zones, "tableau")
	per = Fields.read_int(data, "per", errors, 1, 1)
	where = Fields.read_string(data, "where", errors, ["here"], "")
	if where == "here" and data.has("zone"):
		errors.append("'where': 'here' counts the tableau, so it can't take 'zone'")


func apply(engine: GameEngine, source: CardInstance) -> void:
	var n := _count_here(engine, source) if where == "here" else engine.count_tag(tag, zone)
	engine.gain(resource, amount * (n / per), source)


func describe(_card_db: Dictionary) -> String:
	if where == "here":
		return "+%d %s per %sother %s here" % [amount, resource, _per(), tag]
	return "+%d %s per %s%s%s" % [amount, resource, _per(), tag, _where()]


func describe_long(_card_db: Dictionary) -> String:
	var cards := "%s card%s" % [tag, "" if per == 1 else "s"]
	if where == "here":
		return "+%d %s per %sother %s on its territory" % [amount, resource, _per(), cards]
	return "+%d %s per %s%s%s" % [amount, resource, _per(), cards, _where()]


## The working base buildings with the tag on source's territory, other than source (414).
func _count_here(engine: GameEngine, source: CardInstance) -> int:
	var n := 0
	for card in Modifiers.working_cards(engine):
		if card != source and card.territory_uid == source.territory_uid and card.def.type == CardDef.BUILDING \
				and not card.def.is_upgrade() and card.def.has_tag(tag):
			n += 1
	return n


func _per() -> String:
	return "" if per == 1 else "%d " % per


func _where() -> String:
	return "" if zone == "tableau" else " in %s" % zone
