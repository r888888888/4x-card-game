class_name TurnNews
extends RefCounted
## What a turn's start brings, each in its modal once the board has caught up (main's refresh): the event drawn (079)
## and the raid that struck (271), the raid above the event since it struck first. Nothing opens once the game is over.

var event_modal: EventModal
var raid_modal: RaidModal
var _drawn := {}  # the last event_drawn outcome, shown by the next show(); {} when none
var _raid := {}  # the last raid_resolved outcome, likewise


## Builds both modals on stack, hidden.
func _init(stack: ModalStack) -> void:
	event_modal = EventModal.new(stack)
	raid_modal = RaidModal.new(stack)


## Hears engine's events and raids.
func listen(engine: GameEngine) -> void:
	engine.event_drawn.connect(func(outcome: Dictionary): _drawn = outcome)
	engine.raid_resolved.connect(func(outcome: Dictionary): _raid = outcome)


## Forgets what hasn't been shown (a new game).
func clear() -> void:
	_drawn = {}
	_raid = {}


## Opens what e's turn start brought, unless e is over, and forgets it.
func show(e: GameEngine) -> void:
	if not e.is_over:
		if not _drawn.is_empty():
			event_modal.open(_drawn)
		if not _raid.is_empty():
			raid_modal.open(_raid)
	clear()
