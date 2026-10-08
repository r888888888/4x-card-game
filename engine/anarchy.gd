class_name Anarchy
extends RefCounted
## Anarchy (backlog 145): a turn that starts with unrest at the limit falls into Anarchy (after upkeep), and a revolution
## declared any time falls at the next turn's start, before upkeep (155). The config's unrest.anarchy event joins the
## active events (253: its counters on show, never counted down or discarded by upkeep), the fallen government goes to
## the government deck (154) and none rules until Anarchy ends. While it lasts only action cards can be played, and
## nothing is grown, bought or researched (384). It gets unrest.anarchy_turns counters, whatever the unrest, and one
## comes off at the end of each Anarchy turn (384). At 0 a government is chosen from the government deck and unrest
## drops to 0 (154, 384). Each new era adds unrest.era_unrest. Renewal (147, 385): each Anarchy turn you may trash up to
## unrest.renewal + the renewal modifier cards from the hand, deck or discard (governments aside), an action that owes
## nothing and uses no action. Static functions on the engine's state.

const PLAY_ERROR := "Anarchy: only action cards can be played."
const BUILD_ERROR := "Anarchy: nothing can be grown, bought or researched."
const RENEW_ERROR := "Trash a card from your hand, deck or discard (not a government)."
const RENEWAL_ZONES: Array[String] = ["hand", "deck", "discard"]  # what renewal may trash from (255)


## The active Anarchy event (253), or null.
static func active(e: GameEngine) -> CardInstance:
	return Events.find_active(e, e.config.get("unrest", {}).get("anarchy", ""))


## Whether event is the active Anarchy (Events.resolve_upkeep resolves it without counting it down, 253).
static func is_anarchy(e: GameEngine, event: CardInstance) -> bool:
	return event != null and event == active(e)


## The start of a turn, before upkeep (155): a revolution declared last turn falls now.
static func before_upkeep(e: GameEngine) -> void:
	if active(e) == null and e.state.revolt_pending:
		_fall(e)


## The start of a turn, after upkeep, feeding and era unlocks, before the draw: unrest at the limit falls into Anarchy.
static func start_of_turn(e: GameEngine) -> void:
	if active(e) == null and not e.config.get("unrest", {}).is_empty() and e.at_unrest_limit():
		_fall(e)


## The end of a turn under Anarchy, after any hand-limit discard (155): one counter comes off; at 0 Anarchy ends and
## the government choice is owed before the next turn. Returns whether it is owed.
static func end_of_turn(e: GameEngine) -> bool:
	var anarchy := active(e)
	if anarchy == null:
		return false
	anarchy.counters -= 1
	if anarchy.counters > 0:
		return false
	_end(e, anarchy)
	e.state.pending.ends_turn = true
	e._notice("Anarchy burns out and order returns: choose a government.")
	return true


## The cards renewal may still trash this turn (385): unrest.renewal + the renewal modifier − those renewed this turn,
## never below 0; 0 outside Anarchy or with no unrest.renewal in the config (renewal off).
static func renewals_left(e: GameEngine) -> int:
	if active(e) == null or not e.config.unrest.has("renewal"):
		return 0
	return maxi(0, e.config.unrest.renewal + e.modifier(Modifiers.RENEWAL) - e.state.renewed)


## The cards renewal may trash (255): the hand, deck and discard but governments, by name then uid (so the draw
## order stays hidden).
static func renewal_options(e: GameEngine) -> Array[int]:
	var cards: Array[CardInstance] = []
	for zone_name in RENEWAL_ZONES:
		cards.append_array(e.zone(zone_name).cards.filter(func(c): return c.def.type != CardDef.GOVERNMENT))
	cards.sort_custom(func(a: CardInstance, b: CardInstance):
		return a.def.name < b.def.name or (a.def.name == b.def.name and a.uid < b.uid))
	var out: Array[int] = []
	out.assign(cards.map(func(c): return c.uid))
	return out


## Why renew(uids) would refuse, or "" (255, 385): blocked, no Anarchy, nothing chosen, no renewals left, a uid that
## isn't an option, a uid twice, or more than are left.
static func renew_error(e: GameEngine, uids: Array) -> String:
	var blocked := e._blocked_error("renew")
	if blocked != "":
		return blocked
	if active(e) == null:
		return "Renewal is only possible during Anarchy."
	if uids.is_empty():
		return "Choose a card to trash."
	var left := renewals_left(e)
	if left == 0:
		return "No renewals left this turn."
	var options := renewal_options(e)
	if uids.any(func(u): return not options.has(u)):
		return RENEW_ERROR
	if uids.any(func(u): return uids.count(u) > 1):
		return "Each card can be trashed once."
	return "" if uids.size() <= left else "Trash at most %d card%s this turn." % [left, "" if left == 1 else "s"]


## Trashes the cards uids from wherever they are (255, 385): no action used, unrest unchanged. False (and no change) if
## renew_error says no.
static func renew(e: GameEngine, uids: Array) -> bool:
	if renew_error(e, uids) != "":
		return false
	for uid in uids:
		var zone := e.zone(e.zone_of(uid))
		var card := zone.find(uid)
		zone.remove(card)
		e.zone("trashed").add(card)
		e._log("Renewal: trashed %s." % card.def.name)
	e.state.renewed += uids.size()
	e.changed.emit()
	return true


## Why hand card can't be played under Anarchy, or "": only an action card can (384).
static func play_error(e: GameEngine, card: CardInstance) -> String:
	return PLAY_ERROR if active(e) != null and card.def.type != CardDef.ACTION else ""


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


## What a revolution declared now would bring (205, 384), one line each, with this game's numbers: when Anarchy falls,
## how long it lasts (unrest.anarchy_turns), what may be played and what stops, renewal (unrest.renewal, left out
## without it) and how it ends. [] when revolt_error says no.
static func revolt_summary(e: GameEngine) -> Array[String]:
	var out: Array[String] = []
	if revolt_error(e) != "":
		return out
	var unrest: Dictionary = e.config.unrest
	var n: int = unrest.anarchy_turns
	out.append("Anarchy falls at the start of next turn.")
	out.append("It lasts %d turn%s." % [n, "" if n == 1 else "s"])
	out.append("You can play action cards; nothing can be grown, bought or researched.")
	if unrest.has("renewal"):
		var r: int = unrest.renewal
		out.append("Each turn: you may trash %d card%s from your hand, deck or discard." % [r, "" if r == 1 else "s"])
	out.append("When it ends, choose a government; unrest drops to 0.")
	return out


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


## A new era was added (Research.add_era): unrest.era_unrest more unrest, up to the limit, with a notice.
static func stir(e: GameEngine) -> void:
	var n: int = e.config.get("unrest", {}).get("era_unrest", 0)
	if n == 0:
		return
	var added := e.set_unrest(e.resources.get(GameEngine.UNREST, 0) + n)
	e._notice("  A new era stirs the people: +%d unrest." % added, GameEngine.NOTICE_CAUTION)


## The government falls into the government deck (154), to be chosen again, and the Anarchy card rules with
## unrest.anarchy_turns counters (384).
static func _fall(e: GameEngine) -> void:
	e.state.revolt_pending = false
	var gov := e.zone("government")
	var fallen := ""
	for old in gov.take_all():
		fallen = old.def.name
		e.zone("governments").add(old)
	var anarchy := e._make_card(e.config.unrest.anarchy)
	e.zone("active_events").add(anarchy)
	anarchy.counters = e.config.unrest.anarchy_turns
	e._notice("Anarchy!%s It lasts %d turn%s." % [" %s falls into your government deck." % fallen if fallen != ""
		else "", anarchy.counters, "" if anarchy.counters == 1 else "s"], GameEngine.NOTICE_URGENT)


## The Anarchy card leaves the game and no government rules until one is chosen from the government deck (154).
static func _end(e: GameEngine, anarchy: CardInstance) -> void:
	e.zone("active_events").remove(anarchy)
	e.zone("removed").add(anarchy)
	e.state.pending = {"kind": GameEngine.PENDING_GOVERNMENT}


## The government choice's default (254): the config's starting government when it's in the government deck, else the
## deck's first; -1 when no choice is owed.
static func default_government(e: GameEngine) -> int:
	if e.state.pending.get("kind", "") != GameEngine.PENDING_GOVERNMENT or e.zone("governments").is_empty():
		return -1
	var start: String = e.config.get("starting", {}).get("government", "")
	var card := e.zone("governments").find_id(start) if start != "" else null
	return card.uid if card != null else e.zone("governments").cards[0].uid


## The government deck's uids for the choice (254): the default first, the rest in deck order.
static func government_options(e: GameEngine) -> Array:
	var first := default_government(e)
	var rest: Array = e.zone("governments").cards.map(func(c): return c.uid).filter(func(u): return u != first)
	return ([first] if first != -1 else []) + rest


## Why choose_government(uid) would refuse, or "" (154).
static func choose_government_error(e: GameEngine, uid: int) -> String:
	var owed := e._owed_error(GameEngine.PENDING_GOVERNMENT, "No government to choose.")
	if owed != "":
		return owed
	return "" if e.zone("governments").find(uid) != null else "That government isn't in your government deck."


## Government uid rules: it leaves the government deck, its play effects resolve (its cost isn't paid), and unrest
## drops to 0 (384). When Anarchy ran out at the end of a turn, the turn then finishes (155). False (and no change) if choose_government_error says no.
static func choose_government(e: GameEngine, uid: int) -> bool:
	if choose_government_error(e, uid) != "":
		return false
	var card := e.zone("governments").find(uid)
	e.zone("governments").remove(card)
	e.zone("government").add(card)
	var ends_turn: bool = e.state.pending.get("ends_turn", false)
	e.state.pending = {}
	e.set_unrest(0)
	e._resolve(card, "play")
	e._notice("%s rules." % card.def.name)
	if ends_turn:
		TurnLoop.finish_turn(e)  # emits changed
	else:
		e.changed.emit()
	return true
