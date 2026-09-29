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
	for r in card.def.cost:
		var need: int = card.def.cost[r]
		var have: int = e.resources.get(r, 0)
		if have < need:
			return "%s needs %d %s (you have %d)." % [card.def.name, need, r, have]
	for effect in card.def.effects:
		if effect.trigger == "play":
			var blocked := effect.play_block_error(e)
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
	var permanent := card.def.is_permanent()
	e._outcome = _new_outcome(uid, "tableau" if permanent else "discard", target)
	e.play_target = target
	for r in card.def.cost:
		e.resources[r] -= card.def.cost[r]
		if card.def.cost[r] > 0:
			e._outcome.paid[r] = card.def.cost[r]
	e._log("Played %s." % card.def.name)
	if permanent:
		if card.def.type == CardDef.BUILDING:
			card.territory_uid = target
		e.zone("tableau").add(card)
	e._resolve(card, "play")
	if not permanent:
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


static func _new_outcome(uid: int, to_zone: String, target: int) -> Dictionary:
	var drawn: Array[int] = []
	var created: Array[int] = []
	return {"uid": uid, "to_zone": to_zone, "target": target, "paid": {}, "gained": {}, "vp": 0, "drawn": drawn, "created": created}
