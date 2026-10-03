extends "res://tests/lib/anarchy_case.gd"
## The pending-decision block (backlog 171): while a decision is owed (explore, hand-limit discard, renewal, the
## government choice) or the game is over, every player action refuses, with a reason from its *_error query, and
## changes nothing; only the decision's own actions go on. The table of actions is checked against GameEngine's
## methods, so a new action needs a row. Games from tests/lib/anarchy_case.gd (unrest, Anarchy, renewal, a supply and
## a research deck), with Explorers and three territories to explore.

## Actions with an error query that no decision blocks.
const NOT_BLOCKED := ["new_game"]
## Actions whose error query isn't named <action>_error.
const ERROR_OF := {"play_card": "play_error", "discard_card": "discard_error"}


## A uid from options, or -1 when it is empty.
func first_of(options: Array) -> int:
	return options[0] if not options.is_empty() else -1


## A uid from zone, or -1 when it is empty.
func first_in(e: GameEngine, zone_name: String) -> int:
	var z := e.zone(zone_name)
	return z.cards[0].uid if not z.is_empty() else -1


## Every player action: [name, its error query on e, the action on e (its result, or null for end_turn)], each with
## the argument it would most likely take now (the decision's option, else a hand card, the home, a supply pile …).
func actions() -> Array:
	var option := func(e: GameEngine) -> int: return first_of(e.pending().get("options", []))
	return [
		["play_card", func(e): return e.play_error(first_in(e, "hand")), func(e): return e.play_card(first_in(e, "hand"))],
		["grow", func(e): return e.grow_error(home_uid(e)), func(e): return e.grow(home_uid(e))],
		["buy", func(e): return e.buy_error("farm"), func(e): return e.buy("farm")],
		["buy_tech", func(e): return e.buy_tech_error(first_in(e, "research_deck")),
			func(e): return e.buy_tech(first_in(e, "research_deck"))],
		["end_turn", func(e): return e.end_turn_error(), func(e): return e.end_turn()],
		["discard_card", func(e): return e.discard_error(first_in(e, "hand")),
			func(e): return e.discard_card(first_in(e, "hand"))],
		["choose", func(e): return e.choose_error(option.call(e)), func(e): return e.choose(option.call(e))],
		["renew", func(e): return e.renew_error(option.call(e)), func(e): return e.renew(option.call(e))],
		["choose_government", func(e): return e.choose_government_error(option.call(e)),
			func(e): return e.choose_government(option.call(e))],
		["relieve_famine", func(e): return e.relieve_famine_error(), func(e): return e.relieve_famine()],
		["restore_order", func(e): return e.restore_order_error(), func(e): return e.restore_order()],
		["revolt", func(e): return e.revolt_error(), func(e): return e.revolt()],
		["rename_territory", func(e): return e.call("rename_territory_error", home_uid(e), "Delta"),
			func(e): return e.call("rename_territory", home_uid(e), "Delta")],
		["supply", func(e): return e.supply_error(), func(_e): return false],  # the supply screen: a query only
	]


## An anarchy game with Explorers to play and Hills, Grassland and Jungle (top first) to explore.
func blocking_engine(unrest := {}, overrides := {}) -> GameEngine:
	var e := anarchy_engine(unrest, {"territory_deck": {"hills": 1, "grassland": 1, "jungle": 1}}.merged(overrides))
	arrange(e.zone("territory_deck"), ["hills", "grassland", "jungle"])
	return e


## Each decision owed, and game over: [label, the game, the actions it lets go on].
func scenarios() -> Array:
	var explore := blocking_engine()
	check(explore.play_card(put_in_hand(explore, "explorer")), "play Explorer")
	var discard := blocking_engine({}, {"hand_limit": 5})
	for i in 2:
		put_in_hand(discard, "farm")
	discard.end_turn()
	var renewal := blocking_engine({"renewal": 1})
	put_in(renewal, "farm", "discard")
	renewal.resources["unrest"] = 5
	renewal.end_turn()  # falls into Anarchy: renewal owed
	var government := blocking_engine()
	government.resources["unrest"] = 5
	government.end_turn()
	government.end_turn()  # 155: order can be restored from Anarchy's second turn
	government.resources["wealth"] = 30
	check(government.restore_order(), "restore order: the government choice is owed")
	var over := blocking_engine({}, {"turn_limit": 1})
	over.end_turn()
	eq(explore.pending().get("kind"), GameEngine.PENDING_EXPLORE, "explore owed")
	eq(discard.pending().get("kind"), GameEngine.PENDING_DISCARD, "discard owed")
	eq(renewal.pending().get("kind"), GameEngine.PENDING_RENEWAL, "renewal owed")
	eq(government.pending().get("kind"), GameEngine.PENDING_GOVERNMENT, "government choice owed")
	check(over.is_over, "the game is over")
	return [
		["explore", explore, ["choose"]],
		["discard", discard, ["discard_card", "buy", "buy_tech", "supply"]],
		["renewal", renewal, ["renew"]],
		["government", government, ["choose_government"]],
		["game over", over, []],
	]


# --- AC3: owed decisions block every other action ---

func test_every_action_refuses_while_a_decision_is_owed_or_the_game_is_over() -> void:
	for scenario in scenarios():
		var label: String = scenario[0]
		var e: GameEngine = scenario[1]
		for row in actions():
			var action: String = row[0]
			if scenario[2].has(action):
				continue
			var before := e.state.copy()
			var error: String = row[1].call(e)
			check(error != "", "%s: %s_error gives a reason" % [label, action])
			var result: Variant = row[2].call(e)
			check(result == null or result == false, "%s: %s returns false" % [label, action])
			eq(state_diff(e.state, before), "", "%s: %s changes nothing; changed" % [label, action])


# --- AC4: the table covers every action ---

func test_the_action_table_names_every_action_with_an_error_query() -> void:
	var methods: Array[String] = []
	for m in (GameEngine as Script).get_script_method_list():
		methods.append(m.name)
	var expected: Array[String] = []
	for name in methods:
		if name.ends_with("_error") or name.begins_with("_") or expected.has(name):
			continue
		if methods.has(ERROR_OF.get(name, name + "_error")):
			expected.append(name)
	var listed: Array[String] = []
	for row in actions():
		listed.append(row[0])
	listed.append_array(NOT_BLOCKED)
	eq(sorted(listed), sorted(expected), "actions with an error query")


# --- 172 AC2: each decision's own action: game over, then another owed decision, then nothing owed ---

func test_each_decision_action_names_game_over_then_the_owed_decision_then_nothing_owed() -> void:
	const OVER := "The game is over."
	const EXPLORE := "Choose a territory first."
	const DISCARD := "Discard down to 5 cards first."
	const RENEWAL := "Anarchy: trash 1 card from your discard first."
	const GOVERNMENT := "Choose a government first."
	var states := {"nothing owed": blocking_engine()}
	for scenario in scenarios():
		states[scenario[0]] = scenario[1]
	# Each row: the action's error query for uid -1, then its message in each state, in the order of states' keys.
	var rows := [
		["choose", func(e): return e.choose_error(-1),
			["There is no territory to choose.", "That territory isn't an option.", DISCARD, RENEWAL, GOVERNMENT, OVER]],
		["renew", func(e): return e.renew_error(-1),
			["Nothing to renew.", EXPLORE, DISCARD, Anarchy.RENEW_ERROR, GOVERNMENT, OVER]],
		["choose_government", func(e): return e.choose_government_error(-1),
			["No government to choose.", EXPLORE, DISCARD, RENEWAL,
			"That government isn't in your government deck.", OVER]],
		["discard_card", func(e): return e.discard_error(-1),
			["That card is not in your hand.", EXPLORE, "That card is not in your hand.", RENEWAL, GOVERNMENT, OVER]],
	]
	eq(states.keys(), ["nothing owed", "explore", "discard", "renewal", "government", "game over"], "states")
	for row in rows:
		var labels: Array = states.keys()
		for i in labels.size():
			eq(row[1].call(states[labels[i]]), row[2][i], "%s_error while %s" % [row[0], labels[i]])


# --- 172 AC4: every action under # --- Actions ---, beside its error query ---

func test_every_action_sits_under_actions_beside_its_error_query() -> void:
	var lines := FileAccess.get_file_as_string("res://engine/game_engine.gd").split("\n")
	var start := lines.find("# --- Actions ---")
	check(start != -1, "an Actions section")
	var funcs: Array[String] = []  # the function names in the Actions section, in order
	for i in range(start + 1, lines.size()):
		if lines[i].begins_with("# --- "):
			break
		if lines[i].begins_with("func "):
			funcs.append(lines[i].trim_prefix("func ").get_slice("(", 0))
	var names: Array = actions().map(func(row): return row[0]).filter(func(n): return n != "supply")
	names.append_array(NOT_BLOCKED)
	for name in names:
		var query: String = ERROR_OF.get(name, name + "_error")
		var at := funcs.find(name)
		check(at != -1, "%s under # --- Actions ---" % name)
		check(at != -1 and (funcs.find(query) == at - 1 or funcs.find(query) == at + 1),
			"%s beside %s: %s" % [query, name, funcs])


# --- 175 AC1: whether hand cards can be picked up ---

func test_hand_input_error_names_what_blocks_picking_up_a_hand_card() -> void:
	var expected := {
		"explore": "Choose a territory first.",
		"discard": "",
		"renewal": "Anarchy: trash 1 card from your discard first.",
		"government": "Choose a government first.",
		"game over": "The game is over.",
	}
	var free := blocking_engine()
	eq(free.hand_input_error(), "", "nothing owed")
	for scenario in scenarios():
		var e: GameEngine = scenario[1]
		eq(e.hand_input_error(), expected[scenario[0]], "while %s" % scenario[0])
