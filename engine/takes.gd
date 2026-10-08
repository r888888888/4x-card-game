class_name Takes
extends RefCounted
## The take decision (370): cards wait in the offered zone while the player takes one of them into the hand; the rest
## go to the discard. recall offers the discard pile, look the top of the deck (371).


## Offers every card in the discard pile (recall): several owe a take, one goes to the hand at once.
static func recall(e: GameEngine, source: CardInstance) -> void:
	var offered := e.zone("offered")
	for card in e.zone("discard").take_all():
		offered.add(card)
	_offer(e, source)


## Offers the top n cards of the deck (look), reshuffling the discard in when the deck runs out, as a draw does.
static func look(e: GameEngine, n: int, source: CardInstance) -> void:
	var deck := e.zone("deck")
	var offered := e.zone("offered")
	for i in n:
		if deck.is_empty() and not e.reshuffle():
			break
		offered.add_bottom(deck.take_top())  # the top card stays first: options are top first
	_offer(e, source)


## The offered cards: none do nothing, one goes to the hand at once, several owe a take (options top first).
static func _offer(e: GameEngine, source: CardInstance) -> void:
	var offered := e.zone("offered")
	if offered.is_empty():
		return
	if offered.size() == 1:
		var card := offered.take_top()
		e.zone("hand").add(card)
		e._log("  %s: took %s into the hand." % [source.def.name, card.def.name])
		return
	var options: Array[int] = []
	for card in offered.cards:
		options.append(card.uid)
	options.reverse()  # top first
	e.state.pending = {"kind": GameEngine.PENDING_TAKE, "options": options, "source": source.uid}
	e._log("  %s: choose a card to take into your hand." % source.def.name)


## Why card uid can't be taken now, or "".
static func take_error(e: GameEngine, uid: int) -> String:
	var owed := e._owed_error(GameEngine.PENDING_TAKE, "There is no card to take.")
	if owed != "":
		return owed
	if not e.state.pending.options.has(uid):
		return "That card isn't one of the choices."
	return ""


static func take(e: GameEngine, uid: int) -> bool:
	if take_error(e, uid) != "":
		return false
	var offered := e.zone("offered")
	var taken := offered.find(uid)
	offered.remove(taken)
	e.zone("hand").add(taken)
	for card in offered.take_all():
		e.zone("discard").add(card)
	e._log("  Took %s into the hand." % taken.def.name)
	e.state.pending = {}
	e.changed.emit()
	return true
