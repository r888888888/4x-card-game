class_name Anarchy
extends RefCounted
## Anarchy (backlog 145): a turn that starts with unrest at the limit falls into Anarchy. The config's unrest.anarchy
## government takes over and the fallen government goes to the government deck (154). While it rules only governments and
## cards tagged unrest.allowed_tag can be played, nothing is grown, bought or researched, and each turn that starts
## under it adds a counter; at unrest.max_counters it burns out. Each new era adds unrest.era_unrest. Ways out sooner
## (146): a government the people accept (unrest at most half its limit), or paying unrest.relief to restore order.
## When it burns out or order is restored, a government is chosen from the government deck and unrest drops to at
## most half its limit (154). Static functions on the
## engine's state. Revolution (148): while an event with revolt is active you may revolt, falling into Anarchy at once
## with renewal owed. Renewal (147): each turn that starts under Anarchy, after the draw, you must trash unrest.renewal +
## counters + the renewal modifier cards from the discard (governments aside), each calming 1 unrest.

const PLAY_ERROR := "Anarchy: only a government or an order card can be played."
const BUILD_ERROR := "Anarchy: nothing can be grown, bought or researched."
const RENEW_ERROR := "Trash a card from your discard (not a government)."


## The ruling Anarchy card, or null.
static func active(e: GameEngine) -> CardInstance:
	var id: String = e.config.get("unrest", {}).get("anarchy", "")
	var gov := e.zone("government")
	return gov.cards[0] if id != "" and not gov.is_empty() and gov.cards[0].def.id == id else null


## The start of a turn, after upkeep, feeding and era unlocks, before the draw: a turn under Anarchy adds a counter
## (burning out at max_counters); otherwise unrest at the limit falls into Anarchy.
static func start_of_turn(e: GameEngine) -> void:
	var anarchy := active(e)
	if anarchy != null:
		anarchy.counters += 1
		if anarchy.counters >= e.config.unrest.max_counters:
			_burn_out(e, anarchy)
		return
	if not e.config.get("unrest", {}).is_empty() and e.at_unrest_limit():
		_fall(e)


## After the draw: how many cards renewal asks for this turn, capped at the options (0 outside Anarchy, and with no
## unrest.renewal in the config: renewal off).
static func start_renewal(e: GameEngine) -> void:
	var anarchy := active(e)
	if anarchy == null or not e.config.unrest.has("renewal"):
		return
	var n: int = e.config.unrest.renewal + anarchy.counters + e.modifier(Modifiers.RENEWAL)
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


## Why hand card can't be played under Anarchy, or "": only a government or an allowed_tag card can, and a government
## only while unrest is at most half its limit (146; the unrest_limit modifier added before halving).
static func play_error(e: GameEngine, card: CardInstance) -> String:
	if active(e) == null:
		return ""
	if card.def.type == CardDef.GOVERNMENT:
		return accept_error(e, card.def)
	var tag: String = e.config.unrest.allowed_tag
	return "" if tag != "" and card.def.tags.has(tag) else PLAY_ERROR


## Why government def wouldn't be accepted to end an Anarchy now, or "" (146): unrest must be at most half its limit,
## the unrest_limit modifier added before halving; one with no limit is always accepted.
static func accept_error(e: GameEngine, def: CardDef) -> String:
	if def.unrest_limit == 0:
		return ""
	var accepts := (def.unrest_limit + e.modifier(Modifiers.UNREST_LIMIT)) / 2
	if e.resources.get(GameEngine.UNREST, 0) > accepts:
		return "The people won't accept %s until unrest is %d or less." % [def.name, accepts]
	return ""


## Why revolt would refuse, or "" (148): game over or a pending decision, Anarchy already ruling, or no active event
## with revolt.
static func revolt_error(e: GameEngine) -> String:
	var blocked := e._blocked_error("revolt")
	if blocked != "":
		return blocked
	if active(e) != null:
		return "Anarchy already rules."
	if not e.zone("active_events").cards.any(func(c): return c.def.revolt):
		return "Only a revolutionary event lets you revolt."
	return ""


## Falls into Anarchy now, by choice, with renewal owed at once (148). Uses no action. False (and no change) if
## revolt_error says no.
static func revolt(e: GameEngine) -> bool:
	if revolt_error(e) != "":
		return false
	_fall(e)
	start_renewal(e)
	e.changed.emit()
	return true


## Why growing, buying or learning a tech is refused under Anarchy, or "".
static func build_error(e: GameEngine) -> String:
	return BUILD_ERROR if active(e) != null else ""


## What restore_order pays (146): config unrest.relief, {} when order can't be bought.
static func relief(e: GameEngine) -> Dictionary:
	return e.config.get("unrest", {}).get("relief", {}).duplicate()


## Why restore_order would refuse, or "".
static func restore_error(e: GameEngine) -> String:
	var blocked := e._blocked_error("restore_order")
	if blocked != "":
		return blocked
	if active(e) == null:
		return "There is no anarchy."
	var price := relief(e)
	if price.is_empty():
		return "Order can't be bought."
	return e.price_error("Restoring order", price)


## Pays unrest.relief and Anarchy ends: a government is to be chosen (146, 154). False (and no change) if restore_error
## says no.
static func restore(e: GameEngine) -> bool:
	if restore_error(e) != "":
		return false
	var price := relief(e)
	e.pay(price)
	_end(e, active(e))
	e._notice("Order restored (%s): choose a government." % Fields.amounts_text(price))
	e.changed.emit()
	return true


## A new era was added (Research.add_era): unrest.era_unrest more unrest, up to the limit, with a notice.
static func stir(e: GameEngine) -> void:
	var n: int = e.config.get("unrest", {}).get("era_unrest", 0)
	if n == 0:
		return
	var added := e.set_unrest(e.resources.get(GameEngine.UNREST, 0) + n)
	e._notice("  A new era stirs the people: +%d unrest." % added)


## The government falls into the government deck (154), to be chosen again, and the Anarchy card rules.
static func _fall(e: GameEngine) -> void:
	var gov := e.zone("government")
	var fallen := ""
	for old in gov.take_all():
		fallen = old.def.name
		e.zone("governments").add(old)
	gov.add(e._make_card(e.config.unrest.anarchy))
	e._notice("Unrest boils over: Anarchy!%s" % (" %s falls into your government deck." % fallen if fallen != "" else ""))


## Anarchy burns out: order returns and a government is to be chosen (154).
static func _burn_out(e: GameEngine, anarchy: CardInstance) -> void:
	_end(e, anarchy)
	e._notice("Anarchy burns out and order returns: choose a government.")


## The Anarchy card leaves the game and no government rules until one is chosen from the government deck (154).
static func _end(e: GameEngine, anarchy: CardInstance) -> void:
	e.zone("government").remove(anarchy)
	e.zone("removed").add(anarchy)
	e.state.pending = {"kind": GameEngine.PENDING_GOVERNMENT}


## Why choose_government(uid) would refuse, or "" (154).
static func choose_government_error(e: GameEngine, uid: int) -> String:
	var owed := e._owed_error(GameEngine.PENDING_GOVERNMENT, "No government to choose.")
	if owed != "":
		return owed
	return "" if e.zone("governments").find(uid) != null else "That government isn't in your government deck."


## Government uid rules: it leaves the government deck, its play effects resolve (its cost isn't paid), and unrest
## drops to at most half its limit (the unrest_limit modifier added first). False (and no change) if
## choose_government_error says no.
static func choose_government(e: GameEngine, uid: int) -> bool:
	if choose_government_error(e, uid) != "":
		return false
	var card := e.zone("governments").find(uid)
	e.zone("governments").remove(card)
	e.zone("government").add(card)
	e.state.pending = {}
	var limit := e.unrest_limit()
	if limit >= 0:
		e.set_unrest(mini(e.resources.get(GameEngine.UNREST, 0), limit / 2))
	e._resolve(card, "play")
	e._notice("%s rules." % card.def.name)
	e.changed.emit()
	return true
