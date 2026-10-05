extends Effect
## { "op": "unlock", "card": "guildhall" }
## Opens a locked supply pile so the card can be bought (backlog 057), or a locked build-menu entry so it can be built
## (295). The card must have one or the other (checked by the loader's config pass). Play only (not upkeep_ok): an unlock isn't a resource, bonus score or pop, so
## upkeep_forecast couldn't report it.

var card_id: String


func fields() -> Array[String]:
	return ["card"]


func configure(data: Dictionary, _ctx: Dictionary, errors: Array[String]) -> void:
	card_id = Fields.read_string(data, "card", errors)


func apply(engine: GameEngine, source: CardInstance) -> void:
	if engine.config.get("build_menu", {}).has(card_id):
		BuildMenu.unlock(engine, card_id, source)
	else:
		engine.unlock_supply(card_id, source)


func describe(card_db: Dictionary) -> String:
	return "Unlock %s" % _card_name(card_db)


## A building or unit is built from the build menu (295); anything else is bought in the supply.
func describe_long(card_db: Dictionary) -> String:
	if card_db.has(card_id) and (card_db[card_id] as CardDef).uses_worker():
		return "%s can now be built." % _card_name(card_db)
	return "%s can now be bought in the supply." % _card_name(card_db)


func _card_name(card_db: Dictionary) -> String:
	return card_db[card_id].name if card_db.has(card_id) else card_id


func referenced_cards() -> Array[String]:
	return [card_id]
