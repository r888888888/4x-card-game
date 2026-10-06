class_name Upgrades
extends RefCounted
## Building upgrades (300): a building with upgrade_of is built from the build menu onto a building already in play
## (its base), on the base's territory, taking no slot and no worker. A base carries any number of different upgrades,
## and an upgrade can itself be a base. Whether one counts is Fallback's. Static functions on the engine's state;
## GameEngine's public methods and the build menu call them.


## The bases upgrade card (a new copy to build) could go on now, in tableau order: each building it upgrades that
## doesn't carry one already and stands on a territory with what it requires.
static func targets(e: GameEngine, card: CardInstance) -> Array[int]:
	var out: Array[int] = []
	for base in e.zone("tableau").cards:
		if target_error(e, card, base.uid) == "":
			out.append(base.uid)
	return out


## Why upgrade card can't go on target_uid (-1: the one base that takes it), or "".
static func target_error(e: GameEngine, card: CardInstance, target_uid: int) -> String:
	var base_name: String = e.card_db[card.def.upgrade_of].name
	if target_uid == -1:
		var options := targets(e, card)
		if options.is_empty():
			return _none_error(e, card, base_name)
		if options.size() > 1:
			return "Choose %s for %s." % [Population.with_article(base_name), card.def.name]
		return ""
	var base := e.zone("tableau").find(target_uid)
	if base == null or base.def.id != card.def.upgrade_of:
		return "%s builds on %s." % [card.def.name, Population.with_article(base_name)]
	for uid in on(e, target_uid):
		if e.zone("tableau").find(uid).def.id == card.def.id:
			return "That %s already has %s." % [base_name, Population.with_article(card.def.name)]
	var territory := Territories.territory_of(e, base)
	if territory != null and not Territories.meets_requires(card, territory):
		return Territories.requires_error(card)
	return Fallback.tier_error(e, card.def, base.territory_uid)


## Why upgrade card has no base to go on: none at its tier ("Sanctum needs a Village.") while a base without one stands
## below it, else "No Chapel to build Sanctum on.".
static func _none_error(e: GameEngine, card: CardInstance, base_name: String) -> String:
	for base in e.zone("tableau").cards:
		var problem := target_error(e, card, base.uid)
		if problem != "" and problem == Fallback.tier_error(e, card.def, base.territory_uid):
			return Fallback.short_tier_error(card.def)
	return "No %s to build %s on." % [base_name, card.def.name]


## Puts upgrade card onto base_uid: on its base's territory.
static func attach(e: GameEngine, card: CardInstance, base_uid: int) -> void:
	card.base_uid = base_uid
	card.territory_uid = e.zone("tableau").find(base_uid).territory_uid


## The upgrades built onto uid, in build order.
static func on(e: GameEngine, uid: int) -> Array[int]:
	var out: Array[int] = []
	for card in e.zone("tableau").cards:
		if card.base_uid == uid:
			out.append(card.uid)
	return out


## Upgrade uid's upgrades and theirs, depth first in build order (302): what a base's card shows as ribbons.
static func tree(e: GameEngine, uid: int) -> Array[int]:
	var out: Array[int] = []
	for u in on(e, uid):
		out.append(u)
		out.append_array(tree(e, u))
	return out


## The unlocked upgrade entries building base_uid could take now, in menu order, whatever they cost (302).
static func for_base(e: GameEngine, base_uid: int) -> Array[String]:
	var out: Array[String] = []
	for id in BuildMenu.entries(e):
		if e.card_db[id].is_upgrade() and BuildMenu.targets(e, id).has(base_uid):
			out.append(id)
	return out


## Each pair of an unlocked upgrade entry and a building on settled territory t it builds on, {card_id, base}: by
## building in tableau order, then menu order, whether it could be built now or not (302).
static func options(e: GameEngine, t: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var entries := BuildMenu.entries(e)
	for base in e.zone("tableau").cards:
		if base.def.type != CardDef.BUILDING or base.territory_uid != t:
			continue
		for id in entries:
			if e.card_db[id].upgrade_of == base.def.id:
				out.append({"card_id": id, "base": base.uid})
	return out
