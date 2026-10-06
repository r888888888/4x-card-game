class_name Upgrades
extends RefCounted
## Building upgrades (300): a building with upgrade_of is built from the build menu onto a building already in play
## (its base), on the base's territory, taking no slot and no worker. A base carries any number of different upgrades,
## and an upgrade can itself be a base. An upgrade counts only while the building at the root of its chain works;
## otherwise it has fallen back and counts for nothing. Static functions on the engine's state; GameEngine's public
## methods and the build menu call them.


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
			return "No %s to build %s on." % [base_name, card.def.name]
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
	return ""


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


## The building at the root of upgrade card's chain (card itself when it is no upgrade).
static func root(e: GameEngine, card: CardInstance) -> CardInstance:
	var at := card
	while at.base_uid >= 0:
		var base := e.zone("tableau").find(at.base_uid)
		if base == null:
			break
		at = base
	return at


## Whether card is an upgrade that counts for nothing now: the building at the root of its chain is idle.
static func fallen_back(e: GameEngine, card: CardInstance) -> bool:
	return card.base_uid >= 0 and e.is_idle(card.uid)


## Why upgrade uid counts for nothing ("Its Farm is idle."), or "" while it counts or isn't an upgrade.
static func fallen_back_reason(e: GameEngine, uid: int) -> String:
	var card := e.zone("tableau").find(uid)
	if card == null or card.base_uid < 0:
		return ""
	var base := root(e, card)
	return "Its %s is idle." % base.def.name if e.is_idle(base.uid) else ""
