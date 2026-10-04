class_name GameState
extends RefCounted
## Everything that changes during a game (backlog 051). GameEngine holds one and applies the rules to it;
## copy() makes an independent deep copy, which GameEngine.fork wraps (the upkeep forecast runs on one).

var seed_value := 0
var rng: SeededRng
var zones: Dictionary = {}  # name -> Zone
var resources: Dictionary = {}  # name -> int
var turn := 0
var bonus_score := 0  # VP from effects, on top of VP printed on tableau cards
var is_over := false
var log_lines: Array[String] = []
## The decision the player owes (172), {} when none: {kind: GameEngine.PENDING_EXPLORE, options: territory uids top
## first, source: the exploring card's uid}, {kind: PENDING_DISCARD or PENDING_RENEWAL, count: cards still owed} or
## {kind: PENDING_GOVERNMENT, ends_turn: true when choosing finishes the turn (155)}. GameEngine.pending() adds the options a discard, renewal or government choice has now.
var pending: Dictionary = {}
var era := 1  # the highest era of techs added to the research deck
var eras_added: Array[int] = []  # eras add_era has already shuffled in
var actions_used := 0  # cards played from hand and units moved this turn (127, 163)
var actions_gained := 0  # actions gain_actions effects gave this turn (128)
var supply: Dictionary = {}  # card_id -> copies left to buy, in config order
var locked_supply: Dictionary = {}  # card_id -> true for piles not yet unlocked (057)
var next_uid := 1
var revolt_pending := false  # a revolution was declared: Anarchy falls at the next turn's start (155)
var anarchy_turn := 0  # the ruling Anarchy's turn, 1 the turn it fell; 0 without Anarchy (155)
var anarchy_limit := 1  # the fallen government's unrest_limit(), recorded as Anarchy falls (155)
var moved_units: Array[int] = []  # uids of the units moved this turn (163)
var names_given := 0  # default city names handed out (248): the next settled territory takes the next


## A deep copy: new zones holding new card instances, its own RNG in the same state.
func copy() -> GameState:
	var s := GameState.new()
	s.seed_value = seed_value
	s.rng = rng.copy() if rng != null else null
	for name in zones:
		var z := Zone.new(name)
		for card in zones[name].cards:
			z.add(card.copy())
		s.zones[name] = z
	s.resources = resources.duplicate()
	s.turn = turn
	s.bonus_score = bonus_score
	s.is_over = is_over
	s.log_lines = log_lines.duplicate()
	s.pending = pending.duplicate(true)
	s.era = era
	s.eras_added = eras_added.duplicate()
	s.actions_used = actions_used
	s.actions_gained = actions_gained
	s.supply = supply.duplicate()
	s.locked_supply = locked_supply.duplicate()
	s.next_uid = next_uid
	s.revolt_pending = revolt_pending
	s.anarchy_turn = anarchy_turn
	s.anarchy_limit = anarchy_limit
	s.moved_units = moved_units.duplicate()
	s.names_given = names_given
	return s
