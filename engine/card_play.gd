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
	if card.def.type == CardDef.GOVERNMENT:  # chosen from the government deck (154, 155)
		return "A government is chosen, not played."
	if actions_left(e) == 0:
		return "No actions left this turn."
	var anarchy := Anarchy.play_error(e, card)
	if anarchy != "":
		return anarchy
	var cost := Discounts.cost(e, card.def)
	if not e.can_pay(cost):  # names the first resource it is short of
		for r in cost:
			if not e.can_pay({r: cost[r]}):
				return "%s needs %d %s (you have %d)." % [card.def.name, cost[r], r, e.resources.get(r, 0)]
	for effect in card.def.effects:
		if effect.trigger == "play":
			var blocked := effect.play_block_error(e, card)
			if blocked != "":
				return blocked
	if not needs_target(card):
		return ""
	var targets := targets_of(e, uid)
	var building := card.def.type == CardDef.BUILDING
	var placed := building or card.def.type == CardDef.UNIT  # goes on a territory (160)
	if target_uid != -1:
		if targets.has(target_uid):
			return ""
		var target := e.zone("tableau").find(target_uid)
		if building and target != null and target.def.type == CardDef.TERRITORY and not Territories.meets_requires(card, target):
			return Territories.requires_error(card)
		return "That target isn't valid."
	if targets.is_empty():
		if card.def.type == CardDef.UNIT:
			return "No territory with a free worker."
		return Territories.no_building_target_error(e, card) if building else target_effect(card).no_target_error()
	if targets.size() > 1:
		return "Choose a territory for %s." % card.def.name if placed else target_effect(card).choose_target_error()
	return ""


static func targets_of(e: GameEngine, uid: int) -> Array[int]:
	var out: Array[int] = []
	var card := e.zone("hand").find(uid)
	if card == null or not needs_target(card):
		return out
	if card.def.type == CardDef.BUILDING:
		return Territories.building_targets(e, card)
	if card.def.type == CardDef.UNIT:
		return Territories.unit_targets(e)
	for target in e.zone(target_effect(card).target_zone()).cards:
		if target != card:  # a hand target is never the card being played
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
	e.state.actions_used += 1
	var to_zone := _destination(card)
	e._outcome = _new_outcome(uid, to_zone, target)
	e.play_target = target
	var cost := Discounts.cost(e, card.def)
	e.pay(cost)
	for r in cost:
		if cost[r] > 0:
			e._outcome.paid[r] = cost[r]
	e._log("Played %s." % card.def.name)
	if card.def.type == CardDef.BUILDING:
		card.territory_uid = target
	if card.def.type == CardDef.UNIT:  # homed and stationed where it is recruited (160)
		card.territory_uid = target
		card.station_uid = target
	if to_zone == "tableau":
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


## Actions each turn: the ruling government's `actions` (127) plus the "actions" modifier (129), never below 1; under
## Anarchy with no government, the modifier alone (Anarchy's +1 included, 253); -1 (unlimited) when no government rules
## or it sets none.
static func actions_per_turn(e: GameEngine) -> int:
	var gov := e.zone("government")
	if gov.is_empty() and Anarchy.active(e) != null:
		return maxi(1, Modifiers.total(e, Modifiers.ACTIONS))  # Anarchy's +1 action and the rest (253)
	if gov.is_empty() or gov.cards[0].def.actions == 0:
		return -1
	return maxi(1, gov.cards[0].def.actions + Modifiers.total(e, Modifiers.ACTIONS))


## Actions left this turn: actions_per_turn plus those gain_actions gave (128), less the cards played from hand, never
## below 0; -1 when unlimited.
static func actions_left(e: GameEngine) -> int:
	var per_turn := actions_per_turn(e)
	return -1 if per_turn < 0 else maxi(0, per_turn + e.state.actions_gained - e.state.actions_used)


## Whether hand card uid is playable, needs a target and has more than one valid target, so the player picks one.
static func needs_target_choice(e: GameEngine, uid: int) -> bool:
	return e.needs_target(uid) and targets_of(e, uid).size() > 1 and e.playable_error(uid) == ""


## Buildings and units target a territory; other cards need a target if a "play" effect does.
static func needs_target(card: CardInstance) -> bool:
	return card.def.uses_worker() or target_effect(card) != null


## The card's first "play" effect that needs a target, or null.
static func target_effect(card: CardInstance) -> Effect:
	for effect in card.def.effects_for("play"):
		if effect.target_zone() != "":
			return effect
	return null


## Where a played card goes: permanents join the tableau, actions are discarded.
static func _destination(card: CardInstance) -> String:
	return "tableau" if card.def.is_permanent() else "discard"


static func _new_outcome(uid: int, to_zone: String, target: int) -> Dictionary:
	var outcome := new_outcome(uid)
	outcome.merge({"to_zone": to_zone, "target": target, "paid": {}})
	return outcome


## The outcome effects fill in while a card or event resolves: {uid, gained, lost, vp, drawn, created}.
static func new_outcome(uid: int) -> Dictionary:
	var drawn: Array[int] = []
	var created: Array[int] = []
	return {"uid": uid, "gained": {}, "lost": {}, "vp": 0, "drawn": drawn, "created": created}
