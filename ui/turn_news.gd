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


## Hears engine's events and raids, and calls notify(text) with what a chosen option did (269).
func listen(engine: GameEngine, notify: Callable) -> void:
	engine.event_drawn.connect(func(outcome: Dictionary): _drawn = outcome)
	engine.option_chosen.connect(func(outcome: Dictionary):
		var summary := engine.outcome_summary(outcome)
		if summary != "" and notify.is_valid():  # the engine outlives a closed main scene and its toasts
			notify.call("%s: %s" % [engine.card_db[outcome.id].name, summary]))
	engine.raid_resolved.connect(func(outcome: Dictionary): _raid = outcome)


## Forgets what hasn't been shown (a new game).
func clear() -> void:
	_drawn = {}
	_raid = {}


## Opens what e's turn start brought, unless e is over, and forgets it. A choice event waits, still remembered, while
## another decision is owed before its choice (269).
func show(e: GameEngine) -> void:
	var drawn := _drawn
	var raid := _raid
	clear()
	if e.is_over:
		return
	if not drawn.is_empty():
		if _choice_waits(e, drawn):
			_drawn = drawn
		else:
			event_modal.open(drawn)
	if not raid.is_empty():
		raid_modal.open(raid)


## Whether drawn is a choice event whose choice isn't owed yet.
func _choice_waits(e: GameEngine, drawn: Dictionary) -> bool:
	var pending := e.pending()
	return not e.card_db[drawn.id].choices.is_empty() \
		and not (pending.get("kind", "") == GameEngine.PENDING_EVENT_CHOICE and pending.uid == drawn.uid)
