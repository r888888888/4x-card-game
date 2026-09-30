class_name CardPlay
extends RefCounted
## Playing a hand card: whether it can be played and on which targets, paying for it, moving it and
## resolving its "play" effects. Static functions on the engine's state; GameEngine's public methods call them.


static func error(e: GameEngine, uid: int, target_uid: int) -> String:
	var busy := e._blocked_error("play")
	if busy != "":
		return busy
	var card := e.zone("hand").find(uid)
	if card == null:
		return "That card is not in your hand."
	if card.def.type == CardDef.GOVERNMENT and e.government() != -1 and e.zone("government").cards[0].def.id == card.def.id:
		return "%s is already your government." % card.def.name
	for r in card.def.cost:
		var need: int = card.def.cost[r]
		var have: int = e.resources.get(r, 0)
		if have < need:
			return "%s needs %d %s (you have %d)." % [card.def.name, need, r, have]
	for effect in card.def.effects:
		if effect.trigger == "play":
			var blocked := effect.play_block_error(e, card)
			if blocked != "":
				return blocked
	if not needs_target(card):
		return ""
	var targets := targets_of(e, uid)
	var building := card.def.type == CardDef.BUILDING
	if target_uid != -1:
		if targets.has(target_uid):
			return ""
		var target := e.zone("tableau").find(target_uid)
		if building and target != null and target.def.type == CardDef.TERRITORY and not Territories.meets_requires(card, target):
			return Territories.requires_error(card)
		return "That target isn't valid."
	if targets.is_empty():
		return Territories.no_building_target_error(e, card) if building else target_effect(card).no_target_error()
	if targets.size() > 1:
		return "Choose a territory for %s." % card.def.name if building else target_effect(card).choose_target_error()
	return ""


static func targets_of(e: GameEngine, uid: int) -> Array[int]:
	var out: Array[int] = []
	var card := e.zone("hand").find(uid)
	if card == null or not needs_target(card):
		return out
	if card.def.type == CardDef.BUILDING:
		return Territories.building_targets(e, card)
	for target in e.zone(target_effect(card).target_zone()).cards:
		out.append(target.uid)
	return out


static func play(e: GameEngine, uid: int, target_uid: int) -> bool:
	if error(e, uid, target_uid) != "":
		return false
	var target := -1
	if e.needs_target(uid):
		target = target_uid if target_uid != -1 else targets_of(e, uid)[0]
	var hand := e.zone("hand")
	var card := hand.find(uid)
	hand.remove(card)
	var to_zone := _destination(card)
	e._outcome = _new_outcome(uid, to_zone, target)
	e.play_target = target
	for r in card.def.cost:
		e.resources[r] -= card.def.cost[r]
		if card.def.cost[r] > 0:
			e._outcome.paid[r] = card.def.cost[r]
	e._log("Played %s." % card.def.name)
	if card.def.type == CardDef.BUILDING:
		card.territory_uid = target
	if to_zone == "government":
		_replace_government(e, card)
	elif to_zone == "tableau":
		e.zone("tableau").add(card)
	e._resolve(card, "play")
	if to_zone == "discard":
		e.zone("discard").add(card)
	var outcome := e._outcome
	e._outcome = {}
	e.play_target = -1
	e.card_played.emit(outcome)
	e.changed.emit()
	return true


## Buildings target a territory; other cards need a target if a "play" effect does.
static func needs_target(card: CardInstance) -> bool:
	return card.def.type == CardDef.BUILDING or target_effect(card) != null


## The card's first "play" effect that needs a target, or null.
static func target_effect(card: CardInstance) -> Effect:
	for effect in card.def.effects_for("play"):
		if effect.target_zone() != "":
			return effect
	return null


## Where a played card goes: a government rules, other permanents join the tableau, actions are discarded.
static func _destination(card: CardInstance) -> String:
	if card.def.type == CardDef.GOVERNMENT:
		return "government"
	return "tableau" if card.def.is_permanent() else "discard"


## Makes card the government; the one it replaces leaves the game.
static func _replace_government(e: GameEngine, card: CardInstance) -> void:
	var gov := e.zone("government")
	for old in gov.cards.duplicate():
		gov.remove(old)
		e.zone("removed").add(old)
		e._log("%s replaces %s." % [card.def.name, old.def.name])
	gov.add(card)


static func _new_outcome(uid: int, to_zone: String, target: int) -> Dictionary:
	var drawn: Array[int] = []
	var created: Array[int] = []
	return {"uid": uid, "to_zone": to_zone, "target": target, "paid": {}, "gained": {}, "vp": 0, "drawn": drawn, "created": created}
