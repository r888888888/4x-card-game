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


## A building is built (an upgrade onto its base, 300) and a unit recruited from the build menu (295, 296); anything else is bought in the supply.
func describe_long(card_db: Dictionary) -> String:
	if card_db.has(card_id) and (card_db[card_id] as CardDef).type in [CardDef.BUILDING, CardDef.UNIT]:
		return BuildMenu.now_text(card_db, card_id)
	return "%s can now be bought in the supply." % _card_name(card_db)


func unlocked_name(card_db: Dictionary) -> String:
	return _card_name(card_db)


func _card_name(card_db: Dictionary) -> String:
	return card_db[card_id].name if card_db.has(card_id) else card_id


func referenced_cards() -> Array[String]:
	return [card_id]
