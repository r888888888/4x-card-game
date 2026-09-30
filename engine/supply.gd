class_name Supply
extends RefCounted
## The card supply (backlog 032): buying copies of cards with wealth. Static functions on the engine's state;
## GameEngine's public methods call them.


static func price(e: GameEngine, card_id: String) -> int:
	return e.config.get("supply", {}).get(card_id, {}).get("price", 0)


static func buy_error(e: GameEngine, card_id: String) -> String:
	var busy := e._blocked_error("buy")
	if busy != "":
		return busy
	var card_name: String = e.card_db[card_id].name if e.card_db.has(card_id) else card_id
	if not e.state.supply.has(card_id):
		return "%s isn't in the supply." % card_name
	if e.state.locked_supply.has(card_id):
		return "%s isn't unlocked yet." % card_name
	if e.state.supply[card_id] <= 0:
		return "No %ss left in the supply." % card_name
	var cost := price(e, card_id)
	var have: int = e.resources.get(GameEngine.WEALTH, 0)
	if have < cost:
		return "%s costs %d wealth (you have %d)." % [card_name, cost, have]
	return ""


static func buy(e: GameEngine, card_id: String) -> bool:
	if buy_error(e, card_id) != "":
		return false
	var cost := price(e, card_id)
	e.resources.wealth -= cost
	e.state.supply[card_id] -= 1
	var card := e._make_card(card_id)
	e.zone("discard").add(card)
	e._log("Bought %s (%d wealth)." % [card.def.name, cost])
	e.changed.emit()
	return true
