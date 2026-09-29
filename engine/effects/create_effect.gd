extends Effect
## { "op": "create", "card": "city", "zone": "tableau" }
## Puts a new copy of a card into a zone (default tableau), e.g. a Settler founding a City.

var card_id: String
var zone: String


func fields() -> Array[String]:
	return ["card", "zone"]


func configure(data: Dictionary, ctx: Dictionary, errors: Array[String]) -> void:
	card_id = Fields.read_string(data, "card", errors)
	zone = Fields.read_string(data, "zone", errors, GameEngine.CREATE_ZONES, "tableau")


func apply(engine: GameEngine, source: CardInstance) -> void:
	engine.create_card(card_id, zone, source)


func describe(card_db: Dictionary) -> String:
	var card_name: String = card_db[card_id].name if card_db.has(card_id) else card_id
	return "Create a %s" % card_name if zone == "tableau" else "Add a %s to your %s" % [card_name, zone]


func referenced_cards() -> Array[String]:
	return [card_id]
