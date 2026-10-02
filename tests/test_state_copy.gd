extends "res://tests/lib/test_case.gd"
## State copies (backlog 171): GameState.copy() and CardInstance.copy() carry every script variable and share nothing
## that can change. The tests read the variables from the property list, so a variable added without a copy line
## fails here (the forecast and the bot's lookahead run on copies).


## Gives each of o's script variables a value other than its value on fresh (a new instance of the same class): an
## int or bool changed, an empty array or dictionary given an element, anything else kept when it already differs.
## Fails the test for a variable it can't change.
func set_off_default(o: Object, fresh: Object) -> void:
	for name in script_vars(o):
		var value: Variant = o.get(name)
		var default: Variant = fresh.get(name)
		if state_dump(value) != state_dump(default):
			continue
		match typeof(default):
			TYPE_INT:
				o.set(name, default + 5)
			TYPE_BOOL:
				o.set(name, not default)
			TYPE_STRING:
				o.set(name, default + "x")
			TYPE_ARRAY, TYPE_DICTIONARY:
				scribble(value)
			_:
				check(false, "%s: no off-default value for a %s" % [name, type_string(typeof(default))])
		check(state_dump(o.get(name)) != state_dump(default), "%s is set off its default" % name)


## Asserts copy has original's value for every script variable, and that scribbling over the copy leaves the original
## as it was.
func check_copy(original: Object, copy: Object) -> void:
	var names := script_vars(original)
	check(names.size() > 3, "script variables read: %s" % [names])
	for name in names:
		eq(state_dump(copy.get(name)), state_dump(original.get(name)), "copy of %s" % name)
	eq(shared_refs(original, copy), [] as Array[String], "nothing shared with the copy")
	var before := {}
	for name in names:
		before[name] = state_dump(original.get(name))
	scribble(copy)
	var changed: Array[String] = []
	for name in names:
		if state_dump(original.get(name)) != before[name]:
			changed.append(name)
	eq(changed, [] as Array[String], "the original's variables changed by changing the copy")


# --- AC1: GameState.copy ---

func test_game_state_copy_carries_every_variable_and_shares_nothing() -> void:
	var e := explore_engine()  # a pending explore choice, whose source is a card
	put_in(e, "farm", "discard")
	var s := e.state
	set_off_default(s, GameState.new())
	check_copy(s, s.copy())


# --- AC2: CardInstance.copy ---

func test_card_instance_copy_carries_every_variable_and_shares_nothing() -> void:
	var cards := fixture_db()
	var card := CardInstance.new(7, cards.hills)  # printed keywords
	set_off_default(card, CardInstance.new(0, cards.farm))
	check_copy(card, card.copy())
