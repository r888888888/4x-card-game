class_name LegalActions
extends RefCounted
## Every action the engine would allow now (312), for bots: GameEngine.legal_actions calls of(). Each entry is
## [action, args…]: the method to call and its arguments, kept only when the action's error query (ERROR_OF, else
## <action>_error) returns "" for them. An area's action is named "<area>.<action>" ("military.move", 394), called on
## that area. A renewal is one entry, [renew, options, count]: 1 to count of the options (385). apply() calls an entry.

## Actions whose error query isn't named <action>_error.
const ERROR_OF := {"play_card": "play_error", "discard_card": "discard_error"}
## Each owed decision's action, taking one of pending()'s options.
const DECISIONS := {
	GameEngine.PENDING_EXPLORE: "choose",
	GameEngine.PENDING_EVENT_CHOICE: "choose_option",
	GameEngine.PENDING_GOVERNMENT: "choose_government",
	GameEngine.PENDING_TAKE: "take",
}


## The legal actions in e, in order: the owed decision's options, then play_card (each hand card on each target, -1
## when it needs none), build (each entry on each of its build_targets), buy (each open pile), buy_tech (each tech in the
## research deck), contribute (each site, at its contribute_limit), military.move (each unit to each move target),
## military.upgrade (each unit, 166), discard_card (each hand card), renew (385), relieve_famine, revolt, abandon (each
## site or building, 412), military.disband (each unit) and end_turn. [] after game over.
static func of(e: GameEngine) -> Array:
	if e.is_over:
		return []
	var raw := _decision(e)
	var hand: Array = e.zone("hand").cards
	var tableau: Array = e.zone("tableau").cards
	for card in hand:
		for target in (e.valid_targets(card.uid) if e.needs_target(card.uid) else [-1]):
			raw.append(["play_card", card.uid, target])
	for id in e.build_menu():
		for target in e.build_targets(id):
			raw.append(["build", id, target])
	for id in e.open_supply_piles():
		raw.append(["buy", id])
	for tech in e.zone("research_deck").cards:
		raw.append(["buy_tech", tech.uid])
	for card in tableau:
		if e.is_site(card.uid):
			raw.append(["contribute", card.uid, e.contribute_limit(card.uid)])
	for card in tableau:
		if card.def.type == CardDef.UNIT:
			for target in e.military.move_targets(card.uid):
				raw.append(["military.move", card.uid, target])
	for card in tableau:
		if card.def.type == CardDef.UNIT:
			raw.append(["military.upgrade", card.uid])
	for card in hand:
		raw.append(["discard_card", card.uid])
	raw.append(["renew", e.renewal_options(), e.renewals_left()])
	raw.append_array([["relieve_famine"], ["revolt"]])
	for card in tableau:
		if card.def.type == CardDef.BUILDING:
			raw.append(["abandon", card.uid])
	for card in tableau:
		if card.def.type == CardDef.UNIT:
			raw.append(["military.disband", card.uid])
	raw.append(["end_turn"])
	return raw.filter(func(entry): return error(e, entry) == "")


## The owed decision's options as entries ([] with none owed; a hand-limit discard's are the discard_card entries).
static func _decision(e: GameEngine) -> Array:
	var p := e.pending()
	var kind: String = p.get("kind", "")
	if not DECISIONS.has(kind):
		return []
	return p.options.map(func(option): return [DECISIONS[kind], option])


## What entry's error query says on e: "" when it is legal. A renewal entry is checked with its first option.
static func error(e: GameEngine, entry: Array) -> String:
	if entry[0] == "renew":
		return e.renew_error(entry[1].slice(0, 1))
	return _call(e, ERROR_OF.get(entry[0], entry[0] + "_error"), entry.slice(1))


## Takes entry's action on e (a bot's move): its result, false when it refused.
static func apply(e: GameEngine, entry: Array) -> bool:
	return _call(e, entry[0], entry.slice(1)) != false


## Calls method on e, or on its area for "<area>.<method>" (394), with args.
static func _call(e: GameEngine, method: String, args: Array) -> Variant:
	var dot := method.find(".")
	if dot < 0:
		return e.callv(method, args)
	return (e.get(method.left(dot)) as Object).callv(method.substr(dot + 1), args)
