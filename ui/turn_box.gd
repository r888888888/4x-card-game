class_name TurnBox
extends VBoxContainer
## Beside the hand (backlog 115): the deck and discard counts, and End turn, which says how many cards to discard
## while the hand is over its limit. Dealt cards come from the deck count; discarded ones fly to the discard count.

var end_turn: Button
var _piles: Label


func _init() -> void:
	alignment = BoxContainer.ALIGNMENT_CENTER
	add_theme_constant_override("separation", UIKit.HEADING_GAP)
	_piles = UIKit.stat(self, Palette.PILES)
	_piles.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	end_turn = UIKit.button("End turn  (E)", func(): Game.engine.end_turn())
	end_turn.custom_minimum_size.y = 60
	end_turn.size_flags_horizontal = Control.SIZE_SHRINK_END  # against the right edge, under the counts
	end_turn.add_theme_font_size_override("font_size", 24)
	end_turn.theme_type_variation = "AccentButton"
	add_child(end_turn)


func refresh(e: GameEngine) -> void:
	UIKit.set_stat(_piles, "Deck %d  ·  Discard %d" % [e.zone("deck").size(), e.zone("discard").size()])
	var pending := e.pending()
	end_turn.disabled = e.end_turn_error() != ""
	if pending.get("kind", "") == GameEngine.PENDING_DISCARD:
		end_turn.text = "Discard %d (hand limit %d)" % [pending.count, e.config.hand_limit]
	else:
		end_turn.text = "End turn  (E)"


## A point on the "Deck N · Discard M" label: 0.25 is roughly the deck, 0.75 the discard pile.
func pile_point(fraction: float) -> Vector2:
	var r := _piles.get_global_rect()
	return Vector2(r.position.x + r.size.x * fraction, r.get_center().y)
