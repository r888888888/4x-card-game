class_name Sites
extends RefCounted
## Wonders built over turns (backlog 286): a building with `project` is played for just the action as an unfinished
## site on its territory. It takes a slot and a worker but has no effect, modifier or VP until its wealth cost (after
## discounts) is paid in with contribute, at most 1 wealth per pop on its territory each turn; then its play effects
## resolve and it works like any building. An abandoned site (Abandonment) goes to the discard, its progress lost.
## Static functions on the engine's state; GameEngine's public methods call them.

const NOT_A_SITE := "That isn't a wonder being built."


## Whether card is a project on the tableau not yet paid off.
static func unfinished(e: GameEngine, card: CardInstance) -> bool:
	return card != null and card.def.project and card.progress < cost_of(e, card.def)


## The tableau card uid when it is an unfinished site, else null.
static func site(e: GameEngine, uid: int) -> CardInstance:
	var card := e.zone("tableau").find(uid)
	return card if unfinished(e, card) else null


## The wealth def's site needs in all: its cost's wealth after discounts.
static func cost_of(e: GameEngine, def: CardDef) -> int:
	return Discounts.cost(e, def).get(GameEngine.WEALTH, 0)


## See GameEngine.site_cost.
static func cost(e: GameEngine, uid: int) -> int:
	var card := e.zone("tableau").find(uid)
	return cost_of(e, card.def) if card != null and card.def.project else 0


## See GameEngine.site_progress.
static func progress(e: GameEngine, uid: int) -> int:
	var card := e.zone("tableau").find(uid)
	return card.progress if card != null and card.def.project else 0


## See GameEngine.contribute_limit.
static func limit(e: GameEngine, uid: int) -> int:
	var card := site(e, uid)
	if card == null or e.is_idle(uid):
		return 0
	var room: int = e.pop(card.territory_uid) - card.given_this_turn if e.population_on() else cost_of(e, card.def)
	return maxi(0, mini(room, mini(cost_of(e, card.def) - card.progress, e.resources.get(GameEngine.WEALTH, 0))))


## See GameEngine.contribute_error.
static func contribute_error(e: GameEngine, uid: int, amount: int) -> String:
	var blocked := e._blocked_error("contribute")
	if blocked != "":
		return blocked
	var card := site(e, uid)
	if card == null:
		return NOT_A_SITE
	if e.is_idle(uid):
		return "%s has no worker: nothing can go in while it is idle." % card.def.name
	if amount < 1:
		return "Put in at least 1 wealth."
	var wealth: int = e.resources.get(GameEngine.WEALTH, 0)
	if amount > wealth:
		return "%s needs %d wealth (you have %d)." % [card.def.name, amount, wealth]
	var most := limit(e, uid)
	if amount > most:
		return "At most %d more wealth can go into %s this turn." % [most, card.def.name]
	return ""


## See GameEngine.contribute.
static func contribute(e: GameEngine, uid: int, amount: int) -> bool:
	if contribute_error(e, uid, amount) != "":
		return false
	var card := site(e, uid)
	e.pay({GameEngine.WEALTH: amount})
	card.progress += amount
	card.given_this_turn += amount
	e._log("Put %d wealth into %s (%d / %d)." % [amount, card.def.name, card.progress, cost_of(e, card.def)])
	if not unfinished(e, card):
		e._log("Completed %s." % card.def.name)
		e._resolve(card, "play")
	e.changed.emit()
	return true


## Site card leaves the tableau for the discard, its progress lost (abandoned: Abandonment).
static func discard(e: GameEngine, card: CardInstance) -> void:
	e.zone("tableau").remove(card)
	card.progress = 0
	card.given_this_turn = 0
	card.territory_uid = -1
	e.zone("discard").add(card)


## A new turn: nothing has gone into any site yet.
static func start_turn(e: GameEngine) -> void:
	for card in e.zone("tableau").cards:
		card.given_this_turn = 0
