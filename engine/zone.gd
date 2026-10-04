class_name Zone
extends RefCounted
## A named, ordered pile of cards (deck, hand, discard, tableau, ...).
## For the deck, the top card is the last element.

var name: String
var cards: Array[CardInstance] = []


func _init(p_name: String) -> void:
	name = p_name


func size() -> int:
	return cards.size()


func is_empty() -> bool:
	return cards.is_empty()


func add(card: CardInstance) -> void:
	cards.append(card)


func take_top() -> CardInstance:
	return cards.pop_back()


## The first card here with card id id, or null.
func find_id(id: String) -> CardInstance:
	for card in cards:
		if card.def.id == id:
			return card
	return null


## Puts card at the bottom (the deck's top is the last element).
func add_bottom(card: CardInstance) -> void:
	cards.push_front(card)


func take_all() -> Array[CardInstance]:
	var out: Array[CardInstance] = []
	out.assign(cards)
	cards.clear()
	return out


func remove(card: CardInstance) -> void:
	cards.erase(card)


func find(uid: int) -> CardInstance:
	for card in cards:
		if card.uid == uid:
			return card
	return null


func count_tag(tag: String) -> int:
	var n := 0
	for card in cards:
		if card.def.has_tag(tag):
			n += 1
	return n
