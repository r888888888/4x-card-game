class_name ScriptedBot
extends RefCounted
## A fixed-policy bot for smoke tests and the balance simulator (backlog 042). Each step it resolves an
## explore choice with its first option, buys the cheapest revealed tech it can afford (or declines),
## otherwise plays the first playable hand card on its first valid target (Research cards last),
## otherwise discards the hand (dead cards never cycle otherwise, backlog 024) and ends the turn. After
## MAX_PLAYS_PER_TURN plays it ends the turn anyway: free cards that draw can redraw each other forever (058).

const MAX_STEPS := 2000
const MAX_PLAYS_PER_TURN := 40


## Plays engine's game to the end. Returns whether it ended within MAX_STEPS.
static func play(engine: GameEngine) -> bool:
	var steps := 0
	var turn := engine.turn
	var plays := 0
	while not engine.is_over and steps < MAX_STEPS:
		steps += 1
		if engine.turn != turn:
			turn = engine.turn
			plays = 0
		if not engine.pending_choice.is_empty():
			engine.choose(engine.pending_choice.options[0])
		elif not engine.research_options().is_empty():
			_buy_cheapest_tech(engine)
		elif plays >= MAX_PLAYS_PER_TURN or not _play_first_playable(engine):
			for card in engine.zone("hand").cards.duplicate():
				engine.discard_card(card.uid)
			engine.end_turn()
		else:
			plays += 1
	return engine.is_over


## Buys the cheapest revealed tech the engine allows, or declines when none is affordable.
static func _buy_cheapest_tech(engine: GameEngine) -> void:
	var best := -1
	for uid in engine.research_options():
		if engine.buy_tech_error(uid) == "" and (best == -1 or engine.tech_cost(uid) < engine.tech_cost(best)):
			best = uid
	if best == -1:
		engine.decline_research()
	else:
		engine.buy_tech(best)


## Plays the first hand card that can be played, on its first valid target. Returns whether one was played.
static func _play_first_playable(engine: GameEngine) -> bool:
	var hand := engine.zone("hand").cards.duplicate()
	hand.sort_custom(func(a, b): return a.def.id != "research" and b.def.id == "research")
	for card in hand:
		var targets := engine.valid_targets(card.uid)
		var target: int = targets[0] if engine.needs_target(card.uid) and not targets.is_empty() else -1
		if engine.play_error(card.uid, target) == "":
			return engine.play_card(card.uid, target)
	return false
