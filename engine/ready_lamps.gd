class_name ReadyLamps
extends RefCounted
## Ready lamps (288): what can be learned or bought now, and whether any of it is new since the player last looked.
## A lamp is lit while its ready list holds an id not in its seen set (GameState.seen_techs, seen_supply); seeing
## replaces the seen set with the ready list. Static functions on the engine's state; GameEngine's public methods
## call them.


static func ready_techs(e: GameEngine) -> Array[String]:
	var out: Array[String] = []
	var deck := e.zone("research_deck").cards
	for i in range(deck.size() - 1, -1, -1):  # top first: the top is the last card
		var tech: CardInstance = deck[i]
		if not out.has(tech.def.id) and e.buy_tech_error(tech.uid) == "":
			out.append(tech.def.id)
	return out


static func ready_supply(e: GameEngine) -> Array[String]:
	var out: Array[String] = []
	for id in e.config.get("supply", {}):
		if e.buy_error(id) == "":
			out.append(id)
	return out


## Whether ready holds an id not in seen.
static func lit(ready: Array[String], seen: Array[String]) -> bool:
	return ready.any(func(id): return not seen.has(id))
