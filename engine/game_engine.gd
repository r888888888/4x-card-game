class_name GameEngine
extends RefCounted
## Game rules and player actions. Uses no scene nodes: the UI (or a headless
## script) calls the action methods and listens to the signals.
##
## Turn loop: upkeep -> draw -> play (player) -> event -> cleanup.

signal changed
signal logged(message: String)
signal game_over(final_score: int)
## Emitted by play_card, before changed. outcome: {uid, to_zone, target, paid, gained, vp, drawn, created};
## target is the uid the card was played on (-1 if none), paid and gained map resource -> amount,
## drawn and created are card uids.
signal card_played(outcome: Dictionary)

const ZONES: Array[String] = ["deck", "hand", "discard", "tableau", "territory_deck", "frontier", "reveal"]

var card_db: Dictionary  # id -> CardDef
var config: Dictionary  # normalized by DataLoader.parse_config
var seed_value := 0
var rng: SeededRng
var zones: Dictionary = {}  # name -> Zone
var resources: Dictionary = {}  # name -> int
var turn := 0
var bonus_score := 0  # VP from effects, on top of VP printed on tableau cards
var is_over := false
var log_lines: Array[String] = []
var play_target := -1  # target uid of the card being played; -1 outside play_card
var pending_choice: Dictionary = {}  # {options: Array[int], source: CardInstance}; empty = none
var _next_uid := 1
var _outcome: Dictionary = {}  # the card_played outcome being built; empty outside play_card


func _init(p_card_db: Dictionary, p_config: Dictionary) -> void:
	card_db = p_card_db
	config = p_config


# --- Queries ---

func zone(zone_name: String) -> Zone:
	return zones[zone_name]


func turn_limit() -> int:
	return config.turn_limit


func score() -> int:
	var total := bonus_score
	for card in zone("tableau").cards:
		total += card.def.vp
	return total


func count_tag(tag: String, zone_name: String) -> int:
	return zone(zone_name).count_tag(tag)


## Why the card can't be played right now, or "" if it can.
func play_error(uid: int, target_uid := -1) -> String:
	if is_over:
		return "The game is over."
	if not pending_choice.is_empty():
		return "Choose a territory first."
	var card := zone("hand").find(uid)
	if card == null:
		return "That card is not in your hand."
	for r in card.def.cost:
		var need: int = card.def.cost[r]
		var have: int = resources.get(r, 0)
		if have < need:
			return "%s needs %d %s (you have %d)." % [card.def.name, need, r, have]
	if not _needs_target(card):
		return ""
	var targets := valid_targets(uid)
	if target_uid != -1:
		return "" if targets.has(target_uid) else "That target isn't valid."
	if targets.is_empty():
		return _no_target_error(card)
	if targets.size() > 1:
		return _choose_target_error(card)
	return ""


## The uids hand card uid can be played on; [] if it needs no target. A building's targets are the
## settled territories with a free slot; a targeting effect's are the cards in its target zone.
func valid_targets(uid: int) -> Array[int]:
	var out: Array[int] = []
	var card := zone("hand").find(uid)
	if card == null or not _needs_target(card):
		return out
	if _is_building(card):
		for territory in zone("tableau").cards:
			if territory.def.type == "territory" and free_slots(territory.uid) > 0:
				out.append(territory.uid)
	else:
		for target in zone(_target_effect(card).target_zone()).cards:
			out.append(target.uid)
	return out


## Building slots left on settled territory territory_uid (0 if it isn't settled). Cities don't use slots.
func free_slots(territory_uid: int) -> int:
	var tableau := zone("tableau")
	var territory := tableau.find(territory_uid)
	if territory == null or territory.def.type != "territory":
		return 0
	var used := 0
	for card in tableau.cards:
		if _is_building(card) and card.territory_uid == territory_uid:
			used += 1
	return territory.def.slots - used


func needs_target(uid: int) -> bool:
	var card := zone("hand").find(uid)
	return card != null and _needs_target(card)


## The settled territory card sits on, or null.
func territory_of(card: CardInstance) -> CardInstance:
	if card.territory_uid < 0:
		return null
	return zone("tableau").find(card.territory_uid)


# --- Actions ---

func new_game(p_seed: int) -> void:
	seed_value = p_seed
	rng = SeededRng.new(p_seed)
	zones = {}
	for z in ZONES:
		zones[z] = Zone.new(z)
	resources = {}
	for r in config.resources:
		resources[r] = 0
	for r in config.starting.resources:
		resources[r] = config.starting.resources[r]
	turn = 0
	bonus_score = 0
	is_over = false
	pending_choice = {}
	_next_uid = 1
	log_lines.clear()

	var deck := zone("deck")
	for id in config.deck:
		for i in config.deck[id]:
			deck.add(_make_card(id))
	rng.shuffle(deck.cards)
	var territory_deck := zone("territory_deck")
	for id in config.territory_deck:
		for i in config.territory_deck[id]:
			territory_deck.add(_make_card(id))
	rng.shuffle(territory_deck.cards)
	var home: CardInstance = null
	if config.starting.territory != "":
		home = _make_card(config.starting.territory)
		zone("tableau").add(home)
	for id in config.starting.tableau:
		var card := _make_card(id)
		if home != null:
			card.territory_uid = home.uid
		zone("tableau").add(card)

	_log("New game — seed %d, %d cards in deck." % [p_seed, deck.size()])
	_start_turn()
	changed.emit()


## Pays the cost, moves the card (permanents to the tableau), resolves its "play" effects on
## target_uid, then emits card_played with what happened. A card that needs a target and has only
## one valid target uses it when target_uid is -1; a card that needs none ignores target_uid.
func play_card(uid: int, target_uid := -1) -> bool:
	if play_error(uid, target_uid) != "":
		return false
	var target := -1
	if needs_target(uid):
		target = target_uid if target_uid != -1 else valid_targets(uid)[0]
	var hand := zone("hand")
	var card := hand.find(uid)
	hand.remove(card)
	var permanent := card.def.is_permanent()
	_outcome = _new_outcome(uid, "tableau" if permanent else "discard", target)
	play_target = target
	for r in card.def.cost:
		resources[r] -= card.def.cost[r]
		if card.def.cost[r] > 0:
			_outcome.paid[r] = card.def.cost[r]
	_log("Played %s." % card.def.name)
	if permanent:
		if _is_building(card):
			card.territory_uid = target
		zone("tableau").add(card)
	_resolve(card, "play")
	if not permanent:
		zone("discard").add(card)
	var outcome := _outcome
	_outcome = {}
	play_target = -1
	card_played.emit(outcome)
	changed.emit()
	return true


## Resolves the pending choice: keeps territory uid in the frontier and puts the other revealed
## territories at the bottom of the territory deck. False (and no change) if uid isn't an option.
func choose(uid: int) -> bool:
	if pending_choice.is_empty() or not pending_choice.options.has(uid):
		return false
	var reveal := zone("reveal")
	var kept := reveal.find(uid)
	reveal.remove(kept)
	zone("frontier").add(kept)
	for card in reveal.take_all():
		zone("territory_deck").add_bottom(card)
	_log("  %s: kept %s." % [pending_choice.source.def.name, kept.def.name])
	pending_choice = {}
	changed.emit()
	return true


func end_turn() -> void:
	if is_over or not pending_choice.is_empty():
		return
	_event_phase()
	var discard := zone("discard")
	for card in zone("hand").take_all():
		discard.add(card)
	if turn >= turn_limit():
		is_over = true
		var final_score := score()
		_log("Game over after %d turns. Final score: %d." % [turn, final_score])
		changed.emit()
		game_over.emit(final_score)
		return
	_start_turn()
	changed.emit()


# --- Helpers called by effects ---

func gain(resource: String, amount: int, source: CardInstance) -> void:
	resources[resource] = resources.get(resource, 0) + amount
	if not _outcome.is_empty():
		_outcome.gained[resource] = _outcome.gained.get(resource, 0) + amount
	_log("  %s: +%d %s" % [source.def.name, amount, resource])


## Draws up to n cards, reshuffling the discard pile into the deck when it runs out.
func draw(n: int) -> int:
	var deck := zone("deck")
	var drawn := 0
	for i in n:
		if deck.is_empty():
			var discard := zone("discard")
			if discard.is_empty():
				break
			for card in discard.take_all():
				deck.add(card)
			rng.shuffle(deck.cards)
			_log("  Reshuffled discard pile into deck (%d cards)." % deck.size())
		var card := deck.take_top()
		zone("hand").add(card)
		if not _outcome.is_empty():
			_outcome.drawn.append(card.uid)
		drawn += 1
	return drawn


func create_card(card_id: String, zone_name: String, source: CardInstance) -> CardInstance:
	var card := _make_card(card_id)
	zone(zone_name).add(card)
	if not _outcome.is_empty():
		_outcome.created.append(card.uid)
	_log("  %s: created %s." % [source.def.name, card.def.name])
	return card


## Reveals up to n territories. Several start a choice (see choose); a single one goes
## straight to the frontier.
func explore(n: int, source: CardInstance) -> void:
	var territory_deck := zone("territory_deck")
	var reveal := zone("reveal")
	for i in n:
		if territory_deck.is_empty():
			break
		reveal.add(territory_deck.take_top())
	if reveal.is_empty():
		_log("  %s: no territories left to explore." % source.def.name)
	elif reveal.size() == 1:
		var card := reveal.take_top()
		zone("frontier").add(card)
		_log("  %s: discovered %s." % [source.def.name, card.def.name])
	else:
		var options: Array[int] = []
		for card in reveal.cards:
			options.append(card.uid)
		options.reverse()  # top first
		pending_choice = {"options": options, "source": source}
		_log("  %s: choose a territory to keep." % source.def.name)


## Moves frontier territory territory_uid to the tableau and founds a new city_id on it.
func settle(territory_uid: int, city_id: String, source: CardInstance) -> void:
	var territory := zone("frontier").find(territory_uid)
	zone("frontier").remove(territory)
	zone("tableau").add(territory)
	var city := create_card(city_id, "tableau", source)
	city.territory_uid = territory.uid
	_log("  %s: settled %s." % [source.def.name, territory.def.name])


func add_score(amount: int, source: CardInstance) -> void:
	bonus_score += amount
	if not _outcome.is_empty():
		_outcome.vp += amount
	_log("  %s: +%d VP" % [source.def.name, amount])


# --- Internals ---

func _start_turn() -> void:
	turn += 1
	_log("— Turn %d —" % turn)
	for card in zone("tableau").cards.duplicate():
		_resolve(card, "upkeep")
	draw(config.hand_size)


func _event_phase() -> void:
	pass  # Threat design deferred: the event/barbarian deck will resolve here.


func _resolve(card: CardInstance, trigger: String) -> void:
	for e in card.def.effects_for(trigger):
		e.apply(self, card)


func _new_outcome(uid: int, to_zone: String, target: int) -> Dictionary:
	var drawn: Array[int] = []
	var created: Array[int] = []
	return {"uid": uid, "to_zone": to_zone, "target": target, "paid": {}, "gained": {}, "vp": 0, "drawn": drawn, "created": created}


func _is_building(card: CardInstance) -> bool:
	return card.def.type == "building"


## Buildings target a territory; other cards need a target if a "play" effect does.
func _needs_target(card: CardInstance) -> bool:
	return _is_building(card) or _target_effect(card) != null


func _no_target_error(card: CardInstance) -> String:
	if _is_building(card):
		return "No territory with a free slot."
	return _target_effect(card).no_target_error()


func _choose_target_error(card: CardInstance) -> String:
	if _is_building(card):
		return "Choose a territory for %s." % card.def.name
	return _target_effect(card).choose_target_error()


## The card's first "play" effect that needs a target, or null.
func _target_effect(card: CardInstance) -> Effect:
	for e in card.def.effects_for("play"):
		if e.target_zone() != "":
			return e
	return null


func _make_card(card_id: String) -> CardInstance:
	var card := CardInstance.new(_next_uid, card_db[card_id])
	_next_uid += 1
	return card


func _log(message: String) -> void:
	log_lines.append(message)
	logged.emit(message)
