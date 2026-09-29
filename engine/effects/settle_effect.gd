extends Effect
## { "op": "settle", "card": "city" }
## Moves the target frontier territory into the tableau and founds a new copy of a city card on it.

var card_id: String


func fields() -> Array[String]:
	return ["card"]


func configure(data: Dictionary, _ctx: Dictionary, errors: Array[String]) -> void:
	card_id = Fields.read_string(data, "card", errors)


func apply(engine: GameEngine, source: CardInstance) -> void:
	engine.settle(engine.play_target, card_id, source)


func describe(card_db: Dictionary) -> String:
	return "Settle: %s" % _card_name(card_db)


func describe_long(card_db: Dictionary) -> String:
	return "Settle a discovered territory with a %s" % _card_name(card_db)


func _card_name(card_db: Dictionary) -> String:
	return card_db[card_id].name if card_db.has(card_id) else card_id


func referenced_cards() -> Array[String]:
	return [card_id]


func check_references(card_db: Dictionary, errors: Array[String]) -> void:
	if card_db.has(card_id) and card_db[card_id].type != "city":
		errors.append("'card' must be a city card (got '%s')" % card_id)


func target_zone() -> String:
	return "frontier"


func no_target_error() -> String:
	return "No discovered territory to settle."


func choose_target_error() -> String:
	return "Choose a territory to settle."
