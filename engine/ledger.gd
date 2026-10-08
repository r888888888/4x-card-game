class_name Ledger
extends RefCounted
## A breakdown being built (379, 380): amounts added under sources, read back as rows {label, count, amount} in the
## order the sources first changed. A card's copies share one row (keyed by its id; count: the copies); any other source
## is keyed by its label unless given a key of its own. Lives only while a query builds it.

var _book := {}  # key -> {label, uids: {uid: true}, amount}


## Adds amount to label's row (card's id's when card isn't null; key's when given), counting card among its copies;
## 0 adds nothing.
func add(label: String, card: CardInstance, amount: int, key := "") -> void:
	if amount == 0:
		return
	if key == "":
		key = _key(label, card)
	if not _book.has(key):
		_book[key] = {"label": label, "uids": {}, "amount": 0}
	_book[key].amount += amount
	_book[key].uids[card.uid if card != null else -1] = true


## Adds amount to the row card (or label) already has, even when that makes it 0: where a floor's difference goes.
func absorb(label: String, card: CardInstance, amount: int) -> void:
	_book[_key(label, card)].amount += amount


## The amounts added so far.
func sum() -> int:
	var total := 0
	for key in _book:
		total += _book[key].amount
	return total


## The rows in order, leaving out those that came to 0.
func rows() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for key in _book:
		if _book[key].amount != 0:
			out.append({"label": _book[key].label, "count": _book[key].uids.size(), "amount": _book[key].amount})
	return out


static func _key(label: String, card: CardInstance) -> String:
	return "card:" + card.def.id if card != null else label
