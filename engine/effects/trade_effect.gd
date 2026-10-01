extends Effect
## { "op": "trade", "resource": "wealth", "per_root_city": 2, "pop_per": 5, "min_cities": 2 }
## Gains per_root_city × ⌊√cities⌋ plus 1 per pop_per total pop (0 with population off). Cities are the city cards
## in the tableau; with fewer than min_cities the card can't be played. Play only (not upkeep_ok, backlog 055).

var resource: String
var per_root_city: int
var pop_per: int
var min_cities: int


func fields() -> Array[String]:
	return ["resource", "per_root_city", "pop_per", "min_cities"]


func configure(data: Dictionary, ctx: Dictionary, errors: Array[String]) -> void:
	resource = Fields.read_string(data, "resource", errors, ctx.resources)
	if Fields.unpayable(resource) != "":
		errors.append(Fields.unpayable(resource))
	per_root_city = Fields.read_int(data, "per_root_city", errors, 1)
	pop_per = Fields.read_int(data, "pop_per", errors, 1)
	min_cities = Fields.read_int(data, "min_cities", errors, 1)


func apply(engine: GameEngine, source: CardInstance) -> void:
	var cities := city_count(engine)
	engine.gain(resource, per_root_city * int(floor(sqrt(cities))) + engine.total_pop() / pop_per, source)


func play_block_error(engine: GameEngine, card: CardInstance) -> String:
	var cities := city_count(engine)
	if cities < min_cities:
		return "%s needs %d cities (you have %d)." % [card.def.name, min_cities, cities]
	return ""


## City cards in the tableau (the Capital and settled Cities).
static func city_count(engine: GameEngine) -> int:
	var n := 0
	for card in engine.zone("tableau").cards:
		if card.def.type == CardDef.CITY:
			n += 1
	return n


func describe(_card_db: Dictionary) -> String:
	return "Needs %d cities\n+%d %s ×√cities, +1 per %d pop" % [min_cities, per_root_city, resource, pop_per]


func describe_long(_card_db: Dictionary) -> String:
	return "Needs %d cities. Gain %d %s × √cities (rounded down), plus 1 %s per %d pop." % [
		min_cities, per_root_city, resource, resource, pop_per]
