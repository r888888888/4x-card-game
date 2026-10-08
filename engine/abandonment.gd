class_name Abandonment
extends RefCounted
## Abandoning (286, 412): abandon takes an unfinished site (Sites) or a finished building or upgrade out of play for no
## action and no refund. A building takes every upgrade built on it along; a build-menu building is gone, to be built
## again, and one dealt from a deck goes to the discard (as a disbanded unit does, 296). Wonders, once entries and a
## building whose housing its territory's pop needs stay. Static functions on the engine's state; GameEngine's public
## methods call them.

const NOT_IN_PLAY := "That isn't a building in play."


## See GameEngine.abandon_error.
static func error(e: GameEngine, uid: int) -> String:
	var blocked := e._blocked_error("abandon")
	if blocked != "":
		return blocked
	if Sites.site(e, uid) != null:
		return ""
	var card := e.zone("tableau").find(uid)
	if card == null or card.def.type != CardDef.BUILDING:
		return NOT_IN_PLAY
	if card.def.project or e.config.get("build_menu", {}).get(card.def.id, {}).get("once", false):
		return "%s can't be abandoned." % card.def.name
	return _housing_error(e, card)


## See GameEngine.abandon.
static func abandon(e: GameEngine, uid: int) -> bool:
	if error(e, uid) != "":
		return false
	var card := e.zone("tableau").find(uid)
	if Sites.unfinished(e, card):
		Sites.discard(e, card)
	else:
		_take_out(e, card)
	e._log("Abandoned %s." % card.def.name)
	e.changed.emit()
	return true


## Why card's territory can't do without it: its pop would be over its housing once card and its upgrades are gone; "".
## Only a tree with housing or a housing modifier can lower it, so only that is tried out on a fork.
static func _housing_error(e: GameEngine, card: CardInstance) -> String:
	if not e.population_on() or not _touches_housing(e, card):
		return ""
	var f := e.fork()
	_take_out(f, f.zone("tableau").find(card.uid))
	var pop := e.pop(card.territory_uid)
	if pop <= f.housing(card.territory_uid):
		return ""
	return "%s's %d pop need %s's housing." % [e.territory_name(card.territory_uid), pop, card.def.name]


## Whether card or an upgrade on it sets housing or a housing modifier.
static func _touches_housing(e: GameEngine, card: CardInstance) -> bool:
	if card.def.housing != 0 or card.def.modifiers.get(Modifiers.HOUSING, 0) != 0:
		return true
	for uid in Upgrades.on(e, card.uid):
		if _touches_housing(e, e.zone("tableau").find(uid)):
			return true
	return false


## Takes card out of the tableau, the upgrades on it first: each to the discard when dealt from a deck, else gone.
static func _take_out(e: GameEngine, card: CardInstance) -> void:
	for uid in Upgrades.on(e, card.uid):
		_take_out(e, e.zone("tableau").find(uid))
	var to_discard := e.disbands_to_discard(card.uid)
	e.zone("tableau").remove(card)
	card.territory_uid = -1
	card.base_uid = -1
	if to_discard:
		e.zone("discard").add(card)
