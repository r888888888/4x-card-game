class_name UpkeepBreakdown
extends RefCounted
## Where next upkeep's change of each resource comes from (379): rows {label, count, amount}, one per source, in upkeep
## resolution order (crowding, overextension, working cards, events), then what pop eats, then Anarchy's drain. Each
## row is what its step actually changed, so clamps (the unrest limit, the 0 floors) fall on the step they hit and the
## rows sum to upkeep_forecast, which is built from them. Copies of one card are one row (count: the copies). Plays on
## a fork: nothing here changes, is logged or emitted.

const POP_EATS := "Pop eats"


## Next upkeep on a fork of e: {rows: {resource: [{label, count, amount}]}, starve: the pop feeding would starve}.
## {} on the last turn or after game over.
static func ledger(e: GameEngine) -> Dictionary:
	if e.is_over or e.turn >= e.turn_limit():
		return {}
	var f := e.fork()
	Anarchy.before_upkeep(f)  # a declared revolution falls first, as at the turn's start (332)
	var books := {}  # resource -> {key: {label, uids, amount}}, in the order the keys first change
	for r in e.resources:
		books[r] = {}
	var last := {"resources": f.resources.duplicate(), "gains": f._insight_gains}
	TurnLoop.resolve_upkeep(f, func(label: String, card: CardInstance) -> void:
		for r in e.resources:
			var delta: int = f.resources.get(r, 0) - last.resources.get(r, 0)
			if r == GameEngine.INSIGHT and f._insight_gains > last.gains:
				delta -= _credit_per_gain(f, books[r], f._insight_gains - last.gains)
			_add(books[r], label, card, delta)
		last.resources = f.resources.duplicate()
		last.gains = f._insight_gains)
	if e.population_on():
		_add(books[GameEngine.FOOD], POP_EATS, null, -f.total_pop() * e.config.population.food_upkeep)
	var pop_before := f.total_pop()
	if e.population_on():
		Population.feed(f)
	if Anarchy.rules_next_turn(e):
		var stores := {}
		for r in [GameEngine.FOOD, GameEngine.WEALTH]:
			stores[r] = e.resources.get(r, 0) + _sum(books.get(r, {}))
		var lost := Anarchy.drain_of(e, stores)
		var anarchy: String = e.card_db[e.anarchy_id()].name
		for r in lost:
			books[r]["drain"] = {"label": anarchy, "uids": {-1: true}, "amount": -lost[r]}
	var rows := {}
	for r in books:
		rows[r] = _rows(books[r])
	return {"rows": rows, "starve": pop_before - f.total_pop()}


## The unrest limit's sources (379): the ruling government's unrest_limit, then each card whose unrest_limit modifier
## counts, as rows {label, count, amount} summing to e.unrest_limit() (the government's row absorbs its floor at 0);
## [] when there is no limit.
static func limit_rows(e: GameEngine) -> Array[Dictionary]:
	var limit := e.unrest_limit()
	if limit < 0:
		return []
	var book := {}
	var gov: CardInstance = e.zone("government").cards[0]
	_add(book, gov.def.name, gov, gov.def.unrest_limit)
	for card in Modifiers.working_cards(e) + e.zone("active_events").cards:
		_add(book, card.def.name, card, card.def.modifiers.get(Modifiers.UNREST_LIMIT, 0))
	book[_key(gov.def.name, gov)].amount += limit - _sum(book)
	return _rows(book)


## Credits each working card and active event with an insight_per_gain modifier that modifier per gain in book (AC4),
## as the step that made the gains ends, and returns the total credited; the gaining card's row takes the rest of the
## step's change, where the 0 floor bit too.
static func _credit_per_gain(f: GameEngine, book: Dictionary, gains: int) -> int:
	var credited := 0
	for card in Modifiers.working_cards(f) + f.zone("active_events").cards:
		var amount: int = card.def.modifiers.get(Modifiers.INSIGHT_PER_GAIN, 0) * gains
		_add(book, card.def.name, card, amount)
		credited += amount
	return credited


## Adds amount to label's entry in book (card's id's when card isn't null), counting card among its copies; 0 adds
## nothing.
static func _add(book: Dictionary, label: String, card: CardInstance, amount: int) -> void:
	if amount == 0:
		return
	var key := _key(label, card)
	if not book.has(key):
		book[key] = {"label": label, "uids": {}, "amount": 0}
	book[key].amount += amount
	book[key].uids[card.uid if card != null else -1] = true


static func _key(label: String, card: CardInstance) -> String:
	return "card:" + card.def.id if card != null else label


static func _sum(book: Dictionary) -> int:
	var total := 0
	for key in book:
		total += book[key].amount
	return total


## book's entries as rows, in order, leaving out those that came to 0.
static func _rows(book: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for key in book:
		if book[key].amount != 0:
			out.append({"label": book[key].label, "count": book[key].uids.size(), "amount": book[key].amount})
	return out
