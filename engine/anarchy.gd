class_name Anarchy
extends RefCounted
## Anarchy (backlog 145): a turn that starts with unrest at the limit falls into Anarchy. The config's unrest.anarchy
## government takes over and the fallen government is shuffled into the deck. While it rules only governments and
## cards tagged unrest.allowed_tag can be played, nothing is grown, bought or researched, and each turn that starts
## under it adds a counter; at unrest.max_counters the unrest.fallback government restores order and unrest drops to
## half its limit. Each new era adds unrest.era_unrest. Ways out sooner (146): a government the people accept (unrest
## at most half its limit), or paying unrest.relief to restore order under the fallback. Static functions on the
## engine's state.

const PLAY_ERROR := "Anarchy: only a government or an order card can be played."
const BUILD_ERROR := "Anarchy: nothing can be grown, bought or researched."


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


## Why hand card can't be played under Anarchy, or "": only a government or an allowed_tag card can, and a government
## only while unrest is at most half its limit (146; the unrest_limit modifier added before halving).
static func play_error(e: GameEngine, card: CardInstance) -> String:
	if active(e) == null:
		return ""
	if card.def.type == CardDef.GOVERNMENT:
		if card.def.unrest_limit == 0:
			return ""
		var accepts := (card.def.unrest_limit + e.modifier(Modifiers.UNREST_LIMIT)) / 2
		if e.resources.get(GameEngine.UNREST, 0) > accepts:
			return "The people won't accept %s until unrest is %d or less." % [card.def.name, accepts]
		return ""
	var tag: String = e.config.unrest.allowed_tag
	return "" if tag != "" and card.def.tags.has(tag) else PLAY_ERROR


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
	for r in price:
		if e.resources.get(r, 0) < price[r]:
			return "Restoring order needs %s (you have %d)." % [Famine._amounts(price), e.resources.get(r, 0)]
	return ""


## Pays unrest.relief and the fallback government restores order (146). False (and no change) if restore_error says no.
static func restore(e: GameEngine) -> bool:
	if restore_error(e) != "":
		return false
	var price := relief(e)
	for r in price:
		e.resources[r] -= price[r]
	var fallback := _install_fallback(e, active(e))
	e._notice("Order restored (%s): %s rules." % [Famine._amounts(price), fallback.def.name])
	e.changed.emit()
	return true


## A new era was added (Research.add_era): unrest.era_unrest more unrest, up to the limit, with a notice.
static func stir(e: GameEngine) -> void:
	var n: int = e.config.get("unrest", {}).get("era_unrest", 0)
	if n == 0:
		return
	var have: int = e.resources.get(GameEngine.UNREST, 0)
	var limit := e.unrest_limit()
	var added := n if limit < 0 else clampi(limit - have, 0, n)
	e.resources[GameEngine.UNREST] = have + added
	e._notice("  A new era stirs the people: +%d unrest." % added)


## The government falls: it is shuffled into the deck, to be drawn again, and the Anarchy card rules.
static func _fall(e: GameEngine) -> void:
	var gov := e.zone("government")
	var fallen := ""
	for old in gov.take_all():
		fallen = old.def.name
		e.zone("deck").add(old)
	e.rng.shuffle(e.zone("deck").cards)
	gov.add(e._make_card(e.config.unrest.anarchy))
	e._notice("Unrest boils over: Anarchy!%s" % (" %s falls and goes into your deck." % fallen if fallen != "" else ""))


## Anarchy burns out: the fallback government restores order.
static func _burn_out(e: GameEngine, anarchy: CardInstance) -> void:
	var fallback := _install_fallback(e, anarchy)
	e._notice("Anarchy burns out and order returns: %s rules." % fallback.def.name)


## The fallback government rules, the Anarchy card leaves the game, and unrest drops to at most half the new limit.
## Returns the fallback card.
static func _install_fallback(e: GameEngine, anarchy: CardInstance) -> CardInstance:
	var gov := e.zone("government")
	gov.remove(anarchy)
	e.zone("removed").add(anarchy)
	var fallback := e._make_card(e.config.unrest.fallback)
	gov.add(fallback)
	var limit := e.unrest_limit()
	if limit >= 0:
		e.resources[GameEngine.UNREST] = mini(e.resources.get(GameEngine.UNREST, 0), limit / 2)
	return fallback
