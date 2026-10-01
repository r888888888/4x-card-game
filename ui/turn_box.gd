class_name TurnBox
extends VBoxContainer
## Beside the hand (backlog 115): the deck and discard counts (End turn moved to the top bar in 120). Dealt cards come
## from the deck count; discarded ones fly to the discard count.

var _piles: Label


func _init() -> void:
	alignment = BoxContainer.ALIGNMENT_CENTER
	_piles = UIKit.stat(self, Palette.PILES)
	_piles.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT


func refresh(e: GameEngine) -> void:
	UIKit.set_stat(_piles, "Deck %d  ·  Discard %d" % [e.zone("deck").size(), e.zone("discard").size()])


## A point on the "Deck N · Discard M" label: 0.25 is roughly the deck, 0.75 the discard pile.
func pile_point(fraction: float) -> Vector2:
	var r := _piles.get_global_rect()
	return Vector2(r.position.x + r.size.x * fraction, r.get_center().y)
