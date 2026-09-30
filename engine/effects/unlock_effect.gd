extends Effect
## { "op": "unlock", "card": "guildhall" }
## Opens a locked supply pile so the card can be bought (backlog 057). The card must have a supply pile (checked by
## the loader's config pass). Play only (not upkeep_ok): the lock isn't restored by the upkeep forecast.

var card_id: String


func fields() -> Array[String]:
	return ["card"]


func configure(data: Dictionary, _ctx: Dictionary, errors: Array[String]) -> void:
	card_id = Fields.read_string(data, "card", errors)


func apply(engine: GameEngine, source: CardInstance) -> void:
	engine.unlock_supply(card_id, source)


func describe(card_db: Dictionary) -> String:
	return "Unlock %s" % _card_name(card_db)


func describe_long(card_db: Dictionary) -> String:
	return "%s can now be bought in the supply." % _card_name(card_db)


func _card_name(card_db: Dictionary) -> String:
	return card_db[card_id].name if card_db.has(card_id) else card_id


func referenced_cards() -> Array[String]:
	return [card_id]
