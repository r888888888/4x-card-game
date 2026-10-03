class_name TableauView
extends ScrollContainer
## The Realm (backlog 102): one wrapping row of cards. The active events and the frontier territories come first (137:
## what wants a decision stays at the top), then each settled territory as a card with its slots and pop on it, then
## the tableau cards on no territory. A territory's city and buildings show only in its territory view
## (101). The ghost is the outline of the slot a dragged permanent with no target will land in. The scroll box is
## the drop zone.

## The zones whose cards lead the row, in order, each with the explanation its cards' tooltips end with.
const LEADING_ZONES := {
	"active_events": "One event is drawn at the start of each turn from turn 2. It stays active until its turns run out.",
	"frontier": "Territories discovered, not yet settled. Play a city card on one to settle it.",
}

var ghost: Panel
var row: HFlowContainer  # the leading cards, the Realm's card slots, then the ghost; wraps within its width (078)


func _init() -> void:
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	custom_minimum_size.y = CardView.TABLEAU_SIZE.y + 20  # room for one row of cards before it scrolls
	row = HFlowContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("h_separation", UIKit.CARD_GAP)
	row.add_theme_constant_override("v_separation", UIKit.CARD_GAP)
	add_child(row)
	ghost = UIKit.slot_outline()
	ghost.hide()
	row.add_child(ghost)


## The uids the Realm shows in engine e, in order: the settled territories, then the tableau cards on no territory.
static func realm_uids(e: GameEngine) -> Array[int]:
	var out: Array[int] = []
	var loose: Array[int] = []
	for group in e.territory_groups():
		if group.territory == -1:
			loose.assign(group.cards)
		else:
			out.append(group.territory)
	return out + loose


## The board face (CardView.board_kind) for a card in the row whose leading zone is leading ("" for a Realm card).
static func board_kind(leading: String) -> String:
	return {"active_events": CardView.BOARD_EVENT, "frontier": CardView.BOARD_FRONTIER}.get(leading, CardView.BOARD_REALM)


## The leading zone (a key of LEADING_ZONES) card uid is in, or "" for a Realm card.
static func leading_zone(e: GameEngine, uid: int) -> String:
	var zone_name := e.zone_of(uid)
	return zone_name if LEADING_ZONES.has(zone_name) else ""


## Lays out engine e's row, calling place(card, row, index) for each card it shows except those in skip (resting
## in the territory view): the leading zones' cards, then the Realm's.
func refresh(e: GameEngine, place: Callable, skip: Array[int] = []) -> void:
	var index := 0
	for zone_name in LEADING_ZONES:
		for card in e.zone(zone_name).cards:
			place.call(card, row, index)
			index += 1
	var tableau := e.zone("tableau")
	for uid in realm_uids(e):
		if not skip.has(uid):
			place.call(tableau.find(uid), row, index)
			index += 1
	row.move_child(ghost, -1)


## Shows the ghost at the end of the Realm (a permanent with no target).
func show_ghost_at_end() -> void:
	ghost.show()
	row.move_child(ghost, -1)


func hide_ghost() -> void:
	ghost.hide()
