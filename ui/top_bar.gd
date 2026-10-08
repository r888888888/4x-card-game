class_name TopBar
extends HBoxContainer
## The top bar: turn, food, wealth, insight (139) and unrest (144, out of its limit) (with next upkeep's change), score
## and pop, then
## (115) Buy Cards, Knowledge, Log and Menu (the civilization, the government and End turn are in the Sidebar: 202, 203). Any
## change to Food, Wealth, Insight, Unrest, Score or Pop rolls that counter's figure in place (181, 218). The turn plate
## and the counters sit Tokens.SPACE_5 apart in a row of their own, the mock's strip (218); the buttons SPACE_3.
## Clicking a resource counter, or Enter on it, opens its breakdown popover: next upkeep's change by source (379).

const GLYPH := Tokens.TYPE_NUMERAL  # a counter's glyph (180): the size of its figure (242)
# Keys for counter() beside the resources (GameEngine.FOOD, WEALTH, INSIGHT, UNREST) (177).
const SCORE := "score"
const POP := "pop"
const TURN := "turn"
## The counters whose click opens a breakdown popover (379).
const BREAKDOWNS: Array[String] = [GameEngine.FOOD, GameEngine.WEALTH, GameEngine.INSIGHT, GameEngine.UNREST]

var menu_button: Button  # "Menu" (its key, Esc, is in its tooltip: 120)
var log_button: Button  # "Log": opens the log drawer (115); its key, L, is in its tooltip (120)
var _turn_label: Label  # the turn plate, "T 001" (201)
var _counters := {}  # key -> Counter: food, wealth, insight, unrest (hidden while off, 144), score, pop (hidden while off)
var _knowledge: Button  # opens the tech tree (059), where techs are learned (140)
var _knowledge_lamp: ReadyLamp  # lit while a tech can be learned that wasn't seen (288)
var _supply_lamp: ReadyLamp  # on Buy Cards: lit while a pile can be bought from that wasn't seen (288)
var popover := Popover.new()  # the open counter's breakdown (379); main adds it above the board
var _popover_key := ""  # the counter whose breakdown is open, or ""
var _fresh := true  # a new game's first refresh shows its values at once, without rolling (126)


## on_knowledge opens the tech tree, on_log toggles the log drawer.
func _init(on_menu: Callable, on_knowledge: Callable, on_log: Callable) -> void:
	add_theme_constant_override("separation", Tokens.SPACE_3)  # tight: the stats and six buttons share 1920 px (115, 139, 144)
	var stats := HBoxContainer.new()
	stats.add_theme_constant_override("separation", Tokens.SPACE_5)
	add_child(stats)
	_turn_label = Label.new()
	_turn_label.theme_type_variation = &"Plate"  # the mono numerals on a well (201)
	_turn_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_turn_label.mouse_filter = Control.MOUSE_FILTER_PASS  # for the tooltip
	stats.add_child(_turn_label)
	for key in [GameEngine.FOOD, GameEngine.WEALTH, GameEngine.INSIGHT, GameEngine.UNREST, SCORE, POP]:
		var counter := Counter.new(key, "", &"Stat")  # figures at TYPE_NUMERAL (201)
		stats.add_child(counter)
		_counters[key] = counter
		if key in BREAKDOWNS:
			counter.focus_mode = Control.FOCUS_ALL  # Enter opens its breakdown (379)
			counter.gui_input.connect(_on_counter_input.bind(key))
	_counters[SCORE].tooltip_text = "Score: victory points."
	_counters[POP].tooltip_text = "Pop: your people. They live and work in your territories."
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(spacer)
	_knowledge = UIKit.button("Knowledge", on_knowledge)
	_knowledge_lamp = ReadyLamp.attach(_knowledge)
	add_child(_knowledge)
	log_button = UIKit.button("Log", on_log)
	log_button.tooltip_text = "Shortcut: L. The game log: everything that happened."
	add_child(log_button)
	menu_button = UIKit.button("Menu", on_menu)
	menu_button.tooltip_text = "Shortcut: Esc. New game, restart with a seed, reduce motion, exit."
	add_child(menu_button)


## The counter for key (a resource, SCORE, POP or TURN), or null for an unknown key (177).
func counter(key: String) -> Control:
	return _turn_label if key == TURN else _counters.get(key)


## The whole reading counter(key) shows ("3 (+1)", "Turn 1 / 100"), or "" for an unknown key (177): at once, while the
## figure still rolls (181).
func counter_text(key: String) -> String:
	if key == TURN:
		return _turn_label.text
	return (_counters[key] as Counter).text() if _counters.has(key) else ""


## Makes the next refresh show its values at once, without rolling, and light its lamps without a burst: a new game
## (126, 288).
func reset_counters() -> void:
	_fresh = true
	close_breakdown()


## The resource whose breakdown popover is open, or "" (379).
func breakdown_key() -> String:
	return _popover_key if popover.is_open() else ""


## Test hook (379): the open popover's lines as [left, right], or [] while closed.
func breakdown_rows() -> Array:
	return popover.lines() if popover.is_open() else []


## Opens key's breakdown under its counter, or closes it if it is the one open (379).
func toggle_breakdown(key: String) -> void:
	if breakdown_key() == key:
		close_breakdown()
		return
	_popover_key = key
	popover.open(_counters[key], _breakdown(Game.engine, key))


## Closes the breakdown popover (379).
func close_breakdown() -> void:
	_popover_key = ""
	popover.close()


## Whether the screen point at falls on the popover or on a counter that opens one (379): a click there isn't outside.
func breakdown_holds(at: Vector2) -> bool:
	if popover.is_open() and popover.get_global_rect().has_point(at):
		return true
	for key in BREAKDOWNS:
		if _counters[key].is_visible_in_tree() and _counters[key].get_global_rect().has_point(at):
			return true
	return false


## Shows engine e's stats: each counter's figure rolls to its new value (181). The changed counters roll one after
## another, left to right, each starting as the one before registers, so their ticks make one tidy run and their
## registrations come in order (188); quiet (a screen covering the bar shows its own), they roll in silence.
func refresh(e: GameEngine, quiet := false) -> void:
	_turn_label.text = "T %03d" % e.turn
	_turn_label.tooltip_text = "Turn %d of %d" % [e.turn, e.turn_limit()] if e.turn_limit() > 0 else "Turn %d" % e.turn
	var forecast := e.upkeep_forecast()
	var starve: int = forecast.get("starve", 0)
	var limit := e.unrest_limit()
	var readings := {  # key -> value; the unrest limit is in its tooltip (228)
		GameEngine.FOOD: e.resources.get(GameEngine.FOOD, 0),
		GameEngine.WEALTH: e.resources.get(GameEngine.WEALTH, 0),
		GameEngine.INSIGHT: e.resources.get(GameEngine.INSIGHT, 0),
		GameEngine.UNREST: e.resources.get(GameEngine.UNREST, 0),
		SCORE: e.score(),
		POP: e.total_pop(),
	}
	for key in [GameEngine.FOOD, GameEngine.WEALTH, GameEngine.INSIGHT, GameEngine.UNREST]:
		(_counters[key] as Counter).set_forecast("%+d" % forecast[key] if forecast.has(key) else "")
	_counters[GameEngine.UNREST].visible = e.unrest_on()
	_counters[POP].visible = e.population_on()
	var roll_at := 0.0
	for key: String in readings:
		var counter: Counter = _counters[key]
		var change := counter.show_value(readings[key], _fresh, roll_at, not quiet and counter.visible)
		roll_at += mini(absi(change), Anim.ODOMETER_MAX_STEPS) * Anim.ODOMETER_STEP
	_knowledge_lamp.set_lit(e.tech_lamp(), _fresh)
	if _supply_lamp != null:
		_supply_lamp.set_lit(e.supply_lamp(), _fresh)
	_fresh = false
	if breakdown_key() != "":
		popover.set_sections(_breakdown(e, _popover_key))
	_counters[GameEngine.FOOD].set_color(CardView.WARN_COLOR if starve > 0 else Palette.TEXT)
	_counters[GameEngine.FOOD].tooltip_text = "Food: feeds your pop at each upkeep and pays for Grow. " + (
		"Next upkeep: famine, %d pop will die." % starve if starve > 0 else "Beside it: the change at the next upkeep, after pop eats.")
	_counters[GameEngine.WEALTH].tooltip_text = "Wealth: buys cards from the Supply. Beside it: the change at the next upkeep."
	_counters[GameEngine.INSIGHT].tooltip_text = "Insight: pays for techs. Beside it: the change at the next upkeep."
	_counters[GameEngine.UNREST].set_color(CardView.WARN_COLOR if e.at_unrest_limit() else Palette.TEXT)
	var ahead := e.anarchy_ahead()
	_counters[GameEngine.UNREST].set_breathing(ahead)
	_counters[GameEngine.UNREST].tooltip_text = ("Unrest: civil unrest. Your government tolerates at most %d: a turn that starts there falls into Anarchy. " % limit
		if limit >= 0 else "Unrest: civil unrest. Your government sets no limit. ") + "Beside it: the change at the next upkeep." + (
		"\nThe next upkeep brings it to the limit." if ahead else "")
	_knowledge.visible = e.research_on()
	_knowledge.tooltip_text = "Shortcut: T. The tech tree: every tech by era, what it costs now and what it gives.\nEra: %s." % (
		e.era_name(e.era()))  # the era is here, not on the button, to make room for Insight (139)
	if e.research_card_name() != "":
		_knowledge.tooltip_text += "\nPlay %s card for more insight." % UIKit.with_article(e.research_card_name())
	if e.tech_lamp():
		_knowledge.tooltip_text += "\nNew: a tech you can learn."


## Test hooks (288): whether the Knowledge and Buy Cards keys' lamps are lit.
func knowledge_lamp_lit() -> bool:
	return _knowledge_lamp.is_lit()


func supply_lamp_lit() -> bool:
	return _supply_lamp != null and _supply_lamp.is_lit()


## Where the deck and discard are on screen (121): the Log button, whose drawer shows their counts. Dealt cards come
## from it; cards going to the deck or discard fly to it.
func pile_point() -> Vector2:
	return log_button.get_global_rect().get_center()


## "Log •" while the log has lines not yet seen (116).
func set_log_unread(unread: bool) -> void:
	log_button.text = "Log •" if unread else "Log"


## Puts the Supply button before Knowledge, with its ready lamp (288).
func add_supply_button(button: Button) -> void:
	_supply_lamp = ReadyLamp.attach(button)
	add_child(button)
	move_child(button, _knowledge.get_index())


## Next upkeep's change counter key shows beside its figure ("+1"), or "" (none, or no such counter) (201).
func forecast_text(key: String) -> String:
	return (_counters[key] as Counter).forecast_text() if _counters.has(key) else ""


## The popover's sections for resource key (379): next upkeep's rows and their net; Unrest adds its limit's rows and
## total. On the last turn, one line saying there is no next upkeep.
func _breakdown(e: GameEngine, key: String) -> Array:
	var forecast := e.upkeep_forecast()
	if forecast.is_empty():
		return [{"heading": "Next upkeep", "rows": [["No next upkeep: this is the last turn.", ""]], "total": []}]
	var rows := []
	for row: Dictionary in e.upkeep_breakdown(key):
		rows.append([_row_label(row), _signed(row.amount)])
	var sections := [{"heading": "Next upkeep", "rows": rows, "total": ["Net", _signed(forecast[key])]}]
	if key == GameEngine.UNREST and e.unrest_limit() >= 0:
		var limit := []
		for row: Dictionary in e.unrest_limit_breakdown():
			limit.append([_row_label(row), str(row.amount) if limit.is_empty() else _signed(row.amount)])
		sections.append({"heading": "Limit", "rows": limit, "total": ["Limit", str(e.unrest_limit())]})
	return sections


## While a breakdown is open, Esc closes it (and opens no menu) and a click anywhere but on it or a counter closes it
## (379).
func _input(event: InputEvent) -> void:
	if breakdown_key() == "":
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		close_breakdown()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed and not breakdown_holds(event.global_position):
		close_breakdown()


func _on_counter_input(event: InputEvent, key: String) -> void:
	var click: bool = event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	var enter: bool = event is InputEventKey and event.pressed and not event.echo \
		and (event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER)
	if click or enter:
		toggle_breakdown(key)
		accept_event()


## "Farm ×2", or the label alone for one copy.
static func _row_label(row: Dictionary) -> String:
	return row.label + (" ×%d" % row.count if row.count > 1 else "")


## n with its sign, a real minus for a loss ("+2", "−1", "+0").
static func _signed(n: int) -> String:
	return ("%+d" % n).replace("-", "−")
