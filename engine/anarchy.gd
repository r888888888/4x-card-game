class_name Anarchy
extends RefCounted
## Anarchy (backlog 145): a turn that starts with unrest at the limit falls into Anarchy (after upkeep), and a revolution
## declared any time falls at the next turn's start, before upkeep (155). The config's unrest.anarchy government takes
## over and the fallen government goes to the government deck (154). While it rules only cards tagged
## unrest.allowed_tag can be played, and nothing is grown, bought or researched. It gets ⌈max_counters × unrest ÷ L⌉
## counters (1 to max_counters, L the fallen government's limit); calming lowers the counters left for good, and one
## comes off at the end of each Anarchy turn (155). At 0, or when order is bought from its second turn for c × (c + 1)
## wealth, a government is chosen from the government deck and unrest drops to at most half its limit (154). Each new
## era adds unrest.era_unrest. Renewal (147): each turn that starts under Anarchy, after the draw, you must trash
## unrest.renewal + (its turn − 1) + the renewal modifier cards from the discard (governments aside), each calming 1
## unrest. Static functions on the engine's state.

const PLAY_ERROR := "Anarchy: only an order card can be played."
const BUILD_ERROR := "Anarchy: nothing can be grown, bought or researched."
const RENEW_ERROR := "Trash a card from your discard (not a government)."


## The ruling Anarchy card, or null.
static func active(e: GameEngine) -> CardInstance:
	var id: String = e.config.get("unrest", {}).get("anarchy", "")
	var gov := e.zone("government")
	return gov.cards[0] if id != "" and not gov.is_empty() and gov.cards[0].def.id == id else null


## The start of a turn, before upkeep (155): a turn under Anarchy counts as its next; otherwise a revolution declared
## last turn falls now.
static func before_upkeep(e: GameEngine) -> void:
	if active(e) != null:
		e.state.anarchy_turn += 1
	elif e.state.revolt_pending:
		_fall(e)


## The start of a turn, after upkeep, feeding and era unlocks, before the draw: unrest at the limit falls into Anarchy.
static func start_of_turn(e: GameEngine) -> void:
	if active(e) == null and not e.config.get("unrest", {}).is_empty() and e.at_unrest_limit():
		_fall(e)


## A turn that starts under Anarchy, after any fall, before the draw (156): it loses drain_of of its stores.
static func drain(e: GameEngine) -> void:
	var anarchy := active(e)
	if anarchy == null:
		return
	var lost := drain_of(e, e.resources)
	for r in lost:
		e.lose(r, lost[r], anarchy)


## What Anarchy's drain takes from stores ({resource: amount}) (156): config unrest.drain_pct % of food and wealth,
## rounded up; {} with no drain.
static func drain_of(e: GameEngine, stores: Dictionary) -> Dictionary:
	var pct: int = e.config.get("unrest", {}).get("drain_pct", 0)
	var out := {}
	for r in [GameEngine.FOOD, GameEngine.WEALTH]:
		var n := ceili(maxi(0, stores.get(r, 0)) * pct / 100.0)
		if n > 0:
			out[r] = n
	return out


## Whether Anarchy will rule at the next turn's start (156): a revolution is pending, or it rules with 2+ counters
## left.
static func rules_next_turn(e: GameEngine) -> bool:
	return e.state.revolt_pending or (active(e) != null and counters_left(e) >= 2)


## The end of a turn under Anarchy, after any hand-limit discard (155): one counter comes off; at 0 Anarchy ends and
## the government choice is owed before the next turn. Returns whether it is owed.
static func end_of_turn(e: GameEngine) -> bool:
	var anarchy := active(e)
	if anarchy == null:
		return false
	anarchy.counters = counters_left(e) - 1
	if anarchy.counters > 0:
		return false
	_end(e, anarchy)
	e.state.pending.ends_turn = true
	e._notice("Anarchy burns out and order returns: choose a government.")
	return true


## The counters left on the ruling Anarchy, 0 without one (155): never more than its counters for the unrest now
## (calming shortens it), never below 1 while it rules.
static func counters_left(e: GameEngine) -> int:
	var anarchy := active(e)
	if anarchy == null:
		return 0
	return maxi(1, mini(anarchy.counters, counters_for(e, e.state.anarchy_limit)))


## Unrest dropped: the ruling Anarchy keeps the counters left for good (155).
static func calm(e: GameEngine) -> void:
	var anarchy := active(e)
	if anarchy != null:
		anarchy.counters = counters_left(e)


## The counters an Anarchy gets at the unrest now against limit (155): ⌈max_counters × unrest ÷ limit⌉, between 1 and
## max_counters.
static func counters_for(e: GameEngine, limit: int) -> int:
	var most: int = e.config.unrest.max_counters
	var unrest: int = e.resources.get(GameEngine.UNREST, 0)
	return clampi(ceili(most * unrest / float(maxi(1, limit))), 1, most)


## The counters a revolution declared now would bring (155), 0 when revolt_error says no.
static func revolt_forecast(e: GameEngine) -> int:
	return counters_for(e, e.unrest_limit()) if revolt_error(e) == "" else 0


## After the draw: how many cards renewal asks for this turn, capped at the options (0 outside Anarchy, and with no
## unrest.renewal in the config: renewal off).
static func start_renewal(e: GameEngine) -> void:
	var anarchy := active(e)
	if anarchy == null or not e.config.unrest.has("renewal"):
		return
	var n: int = e.config.unrest.renewal + e.state.anarchy_turn - 1 + e.modifier(Modifiers.RENEWAL)
	n = clampi(n, 0, renewal_options(e).size())
	if n > 0:
		e.state.pending = {"kind": GameEngine.PENDING_RENEWAL, "count": n}


## The discard cards renewal may trash, in discard order: all but governments.
static func renewal_options(e: GameEngine) -> Array[int]:
	var out: Array[int] = []
	for card in e.zone("discard").cards:
		if card.def.type != CardDef.GOVERNMENT:
			out.append(card.uid)
	return out


static func renew_error(e: GameEngine, uid: int) -> String:
	var owed := e._owed_error(GameEngine.PENDING_RENEWAL, "Nothing to renew.")
	if owed != "":
		return owed
	return "" if renewal_options(e).has(uid) else RENEW_ERROR


static func renew(e: GameEngine, uid: int) -> bool:
	if renew_error(e, uid) != "":
		return false
	var card := e.zone("discard").find(uid)
	e.zone("discard").remove(card)
	e.zone("trashed").add(card)
	e.state.pending.count -= 1
	if e.state.pending.count == 0:
		e.state.pending = {}
	e._log("Renewal: trashed %s." % card.def.name)
	e.lose(GameEngine.UNREST, 1, card)
	e.changed.emit()
	return true


## Why hand card can't be played under Anarchy, or "": only an allowed_tag card can.
static func play_error(e: GameEngine, card: CardInstance) -> String:
	if active(e) == null:
		return ""
	var tag: String = e.config.unrest.allowed_tag
	return "" if tag != "" and card.def.tags.has(tag) else PLAY_ERROR


## Why revolt would refuse, or "" (148, 155): game over or a pending decision, no unrest block in the config, Anarchy
## already ruling, a revolution already declared, or no government to overthrow.
static func revolt_error(e: GameEngine) -> String:
	var blocked := e._blocked_error("revolt")
	if blocked != "":
		return blocked
	if e.config.get("unrest", {}).is_empty():
		return "Without unrest there is no revolution."
	if active(e) != null:
		return "Anarchy already rules."
	if e.state.revolt_pending:
		return "A revolution is already under way."
	if e.government() == -1:
		return "There is no government to overthrow."
	return ""


## Declares a revolution (155): Anarchy falls at the next turn's start. Uses no action and changes nothing else this
## turn. False (and no change) if revolt_error says no.
static func revolt(e: GameEngine) -> bool:
	if revolt_error(e) != "":
		return false
	e.state.revolt_pending = true
	e._notice("Revolution! Anarchy begins next turn.", GameEngine.NOTICE_URGENT)
	e.revolted.emit()
	e.changed.emit()
	return true


## Why growing, buying or learning a tech is refused under Anarchy, or "".
static func build_error(e: GameEngine) -> String:
	return BUILD_ERROR if active(e) != null else ""


## What restore_order pays (155): c × (c + 1) wealth for c counters left; {} without Anarchy.
static func relief(e: GameEngine) -> Dictionary:
	var c := counters_left(e)
	return {} if c == 0 else {GameEngine.WEALTH: c * (c + 1)}


## Why restore_order would refuse, or "".
static func restore_error(e: GameEngine) -> String:
	var blocked := e._blocked_error("restore_order")
	if blocked != "":
		return blocked
	if active(e) == null:
		return "There is no anarchy."
	if e.state.anarchy_turn <= 1:
		return "Order can't be restored on Anarchy's first turn."
	return e.price_error("Restoring order", relief(e))


## Pays relief and Anarchy ends: a government is to be chosen at once, the turn going on (146, 154, 155). False (and
## no change) if restore_error says no.
static func restore(e: GameEngine) -> bool:
	if restore_error(e) != "":
		return false
	var price := relief(e)
	e.pay(price)
	_end(e, active(e))
	e._notice("Order restored (%s): choose a government." % Fields.amounts_text(price))
	e.order_restored.emit()
	e.changed.emit()
	return true


## A new era was added (Research.add_era): unrest.era_unrest more unrest, up to the limit, with a notice.
static func stir(e: GameEngine) -> void:
	var n: int = e.config.get("unrest", {}).get("era_unrest", 0)
	if n == 0:
		return
	var added := e.set_unrest(e.resources.get(GameEngine.UNREST, 0) + n)
	e._notice("  A new era stirs the people: +%d unrest." % added, GameEngine.NOTICE_CAUTION)


## The government falls into the government deck (154), to be chosen again, and the Anarchy card rules with its
## counters by the unrest share of the fallen government's limit (155).
static func _fall(e: GameEngine) -> void:
	e.state.revolt_pending = false
	e.state.anarchy_limit = e.unrest_limit()
	var gov := e.zone("government")
	var fallen := ""
	for old in gov.take_all():
		fallen = old.def.name
		e.zone("governments").add(old)
	var anarchy := e._make_card(e.config.unrest.anarchy)
	gov.add(anarchy)
	anarchy.counters = counters_for(e, e.state.anarchy_limit)
	e.state.anarchy_turn = 1
	e._notice("Anarchy!%s It lasts up to %d turn%s." % [" %s falls into your government deck." % fallen if fallen != ""
		else "", anarchy.counters, "" if anarchy.counters == 1 else "s"], GameEngine.NOTICE_URGENT)


## The Anarchy card leaves the game and no government rules until one is chosen from the government deck (154).
static func _end(e: GameEngine, anarchy: CardInstance) -> void:
	e.zone("government").remove(anarchy)
	e.zone("removed").add(anarchy)
	e.state.anarchy_turn = 0
	e.state.pending = {"kind": GameEngine.PENDING_GOVERNMENT}


## Why choose_government(uid) would refuse, or "" (154).
static func choose_government_error(e: GameEngine, uid: int) -> String:
	var owed := e._owed_error(GameEngine.PENDING_GOVERNMENT, "No government to choose.")
	if owed != "":
		return owed
	return "" if e.zone("governments").find(uid) != null else "That government isn't in your government deck."


## Government uid rules: it leaves the government deck, its play effects resolve (its cost isn't paid), and unrest
## drops to at most half its limit (the unrest_limit modifier added first). When Anarchy ran out at the end of a turn,
## the turn then finishes (155). False (and no change) if choose_government_error says no.
static func choose_government(e: GameEngine, uid: int) -> bool:
	if choose_government_error(e, uid) != "":
		return false
	var card := e.zone("governments").find(uid)
	e.zone("governments").remove(card)
	e.zone("government").add(card)
	var ends_turn: bool = e.state.pending.get("ends_turn", false)
	e.state.pending = {}
	var limit := e.unrest_limit()
	if limit >= 0:
		e.set_unrest(mini(e.resources.get(GameEngine.UNREST, 0), limit / 2))
	e._resolve(card, "play")
	e._notice("%s rules." % card.def.name)
	if ends_turn:
		TurnLoop.finish_turn(e)  # emits changed
	else:
		e.changed.emit()
	return true
