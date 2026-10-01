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
var pending_choice: Dictionary = {}  # {options: Array[int], source: CardInstance}; empty = none
var era := 1  # the highest era of techs added to the research deck
var eras_added: Array[int] = []  # eras add_era has already shuffled in
var discard_left := 0  # cards still to discard before the turn can end; 0 = none pending
var actions_used := 0  # cards played from hand this turn (127)
var actions_gained := 0  # actions gain_actions effects gave this turn (128)
var supply: Dictionary = {}  # card_id -> copies left to buy, in config order
var locked_supply: Dictionary = {}  # card_id -> true for piles not yet unlocked (057)
var next_uid := 1


## A deep copy: new zones holding new card instances, its own RNG in the same state, and a pending choice
## whose source is the copy's instance of the same card.
func copy() -> GameState:
	var s := GameState.new()
	s.seed_value = seed_value
	s.rng = rng.copy() if rng != null else null
	var copies := {}  # CardInstance -> its copy
	for name in zones:
		var z := Zone.new(name)
		for card in zones[name].cards:
			copies[card] = card.copy()
			z.add(copies[card])
		s.zones[name] = z
	s.resources = resources.duplicate()
	s.turn = turn
	s.bonus_score = bonus_score
	s.is_over = is_over
	s.log_lines = log_lines.duplicate()
	if not pending_choice.is_empty():
		var source: CardInstance = pending_choice.source
		s.pending_choice = {"options": pending_choice.options.duplicate(), "source": copies.get(source, source.copy())}
	s.era = era
	s.eras_added = eras_added.duplicate()
	s.discard_left = discard_left
	s.actions_used = actions_used
	s.actions_gained = actions_gained
	s.supply = supply.duplicate()
	s.locked_supply = locked_supply.duplicate()
	s.next_uid = next_uid
	return s
